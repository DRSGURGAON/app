package `in`.docsafe.app.reminders

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import `in`.docsafe.app.MainActivity
import `in`.docsafe.app.R
import java.io.File
import java.util.Locale

/**
 * Reminder notifications that work while DocSafe is locked or not running.
 *
 * The encrypted database cannot be read in the background, so the Dart side
 * (while unlocked) hands over only the list of times at which a reminder is
 * due. That list — epoch milliseconds, nothing else — is the only reminder data
 * stored outside the encrypted database (`no_backup/reminders/schedule.v1`).
 * Notifications are generic ("A document in DocSafe needs your attention"):
 * no title, category, date or other document content, and they are hidden
 * on the lock screen.
 *
 * One inexact alarm ([AlarmManager.setAndAllowWhileIdle], no exact-alarm
 * permission) is set for the earliest future time; when it fires the
 * notification is posted and the next alarm is set. Boot, app update and
 * clock / time-zone changes re-arm it ([RescheduleReceiver]).
 */
class ReminderScheduler(context: Context, private val clock: () -> Long = System::currentTimeMillis) {
    private val appContext = context.applicationContext
    private val dir = File(appContext.noBackupFilesDir, "reminders")
    private val file = File(dir, "schedule.v1")

    @Synchronized
    fun setSchedule(times: List<Long>) {
        require(times.size <= MAX_TIMES) { "Too many reminders" }
        val now = clock()
        val clean = times.filter { it > now && it < now + MAX_AHEAD_MS }.distinct().sorted()
        write(clean)
        arm(clean)
    }

    @Synchronized
    fun schedule(): List<Long> = read()

    /** Erase all data: forget every time and cancel the alarm. */
    @Synchronized
    fun clear() {
        alarmIntent().let { alarmManager().cancel(it); it.cancel() }
        file.delete()
        notificationManager().cancel(NOTIFICATION_ID)
    }

    /** Alarm fired: post one generic notification if anything is due, then re-arm. */
    @Synchronized
    fun onAlarm() {
        val now = clock()
        val all = read()
        val due = all.filter { it <= now + DUE_SLACK_MS }
        val rest = all - due.toSet()
        write(rest)
        if (due.isNotEmpty()) postNotification()
        arm(rest)
    }

    /** Re-arms after boot / update / clock change; due-but-missed times notify now. */
    @Synchronized
    fun rearm() {
        val now = clock()
        if (read().any { it <= now }) onAlarm() else arm(read())
    }

    fun notificationsAllowed(): Boolean =
        (Build.VERSION.SDK_INT < 33 ||
            appContext.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            notificationManager().areNotificationsEnabled()

    private fun arm(times: List<Long>) {
        val am = alarmManager()
        val pi = alarmIntent()
        val next = times.firstOrNull()
        if (next == null) {
            am.cancel(pi)
            pi.cancel()
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi)
        }
    }

    private fun postNotification() {
        if (!notificationsAllowed()) return
        val nm = notificationManager()
        val res = localized()
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, res.getString(R.string.reminder_channel_name), NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = res.getString(R.string.reminder_channel_description)
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            },
        )
        val open = PendingIntent.getActivity(
            appContext,
            0,
            Intent(appContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_OPEN, OPEN_REMINDERS)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val title = res.getString(R.string.reminder_notification_title)
        val text = res.getString(R.string.reminder_notification_text)
        val public = Notification.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_docsafe)
            .setContentTitle(title)
            .build()
        val n = Notification.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_docsafe)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(public)
            .setCategory(Notification.CATEGORY_REMINDER)
            .build()
        try {
            nm.notify(NOTIFICATION_ID, n)
        } catch (_: SecurityException) {
            // Permission revoked between the check and the post.
        }
    }

    /** Strings in the app's chosen language (stored outside the encrypted DB). */
    private fun localized(): android.content.res.Resources {
        val lang = appContext.getSharedPreferences("docsafe_ui", Context.MODE_PRIVATE).getString("language", null) ?: "hi"
        val config = Configuration(appContext.resources.configuration).apply { setLocale(Locale.forLanguageTag(lang)) }
        return appContext.createConfigurationContext(config).resources
    }

    private fun alarmIntent(): PendingIntent = PendingIntent.getBroadcast(
        appContext,
        0,
        Intent(appContext, ReminderAlarmReceiver::class.java).setAction(ACTION_ALARM),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** For tests: whether an alarm is currently armed. */
    fun isArmed(): Boolean = PendingIntent.getBroadcast(
        appContext,
        0,
        Intent(appContext, ReminderAlarmReceiver::class.java).setAction(ACTION_ALARM),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE,
    ) != null

    private fun alarmManager() = appContext.getSystemService(AlarmManager::class.java)

    private fun notificationManager() = appContext.getSystemService(NotificationManager::class.java)

    private fun read(): List<Long> = try {
        if (!file.exists()) emptyList() else file.readLines().mapNotNull { it.trim().toLongOrNull() }.sorted()
    } catch (_: Exception) {
        emptyList()
    }

    private fun write(times: List<Long>) {
        dir.mkdirs()
        if (times.isEmpty()) {
            file.delete()
            return
        }
        val tmp = File(dir, "schedule.v1.tmp")
        tmp.writeText(times.joinToString("\n"))
        if (!tmp.renameTo(file)) {
            file.delete()
            tmp.renameTo(file)
        }
    }

    companion object {
        const val CHANNEL_ID = "reminders"
        const val NOTIFICATION_ID = 7001
        const val ACTION_ALARM = "in.docsafe.app.REMINDER_ALARM"
        const val EXTRA_OPEN = "docsafe.open"
        const val OPEN_REMINDERS = "reminders"
        const val MAX_TIMES = 5000
        private const val DUE_SLACK_MS = 60_000L
        private const val MAX_AHEAD_MS = 20L * 366 * 24 * 3600 * 1000
    }
}

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderScheduler.ACTION_ALARM) return
        ReminderScheduler(context).onAlarm()
    }
}

class RescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> ReminderScheduler(context).rearm()
        }
    }
}

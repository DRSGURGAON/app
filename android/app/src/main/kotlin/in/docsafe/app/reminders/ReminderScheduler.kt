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
import android.util.Base64
import `in`.docsafe.app.MainActivity
import `in`.docsafe.app.R
import `in`.docsafe.app.security.KeystoreKeys
import java.io.File
import java.util.Locale
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec

/**
 * Reminder notifications that work while DocSafe is locked or not running.
 *
 * The encrypted database cannot be read in the background, so the Dart side
 * (while unlocked) hands over the times at which a reminder is due
 * (`no_backup/reminders/schedule.v1`, one line per time). Notifications are
 * generic ("A document in DocSafe needs your attention") unless the user
 * turned on "Show document names in notifications": then each time carries a
 * short label (e.g. "Driving Licence expires on 10 Dec 2026"), stored on the
 * same line encrypted with the Keystore key [KeystoreKeys.NOTIFY_ALIAS]
 * (AES-GCM, usable while locked). Notifications are hidden on the lock screen
 * either way (public version = title only).
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

    /** A time with an optional plaintext label (encrypted before it is stored). */
    data class Alarm(val at: Long, val label: String? = null)

    private data class Entry(val at: Long, val sealedLabel: String?)

    /** Times only (no labels). */
    @Synchronized
    fun setSchedule(times: List<Long>) = setAlarms(times.map { Alarm(it) })

    @Synchronized
    fun setAlarms(alarms: List<Alarm>) {
        require(alarms.size <= MAX_TIMES) { "Too many reminders" }
        val now = clock()
        val clean = alarms
            .filter { it.at > now && it.at < now + MAX_AHEAD_MS }
            .groupBy { it.at }
            .map { (at, same) ->
                val labels = same.mapNotNull { it.label?.take(MAX_LABEL) }.distinct()
                Entry(at, if (labels.isEmpty()) null else seal(labels.joinToString("\n")))
            }
            .sortedBy { it.at }
        write(clean)
        arm(clean.map { it.at })
    }

    @Synchronized
    fun schedule(): List<Long> = read().map { it.at }

    /** For tests: the labels stored for each time (decrypted), null where none. */
    @Synchronized
    fun labels(): List<String?> = read().map { e -> e.sealedLabel?.let { open(it) } }

    /** Erase all data: forget every time and cancel the alarm. */
    @Synchronized
    fun clear() {
        alarmIntent().let { alarmManager().cancel(it); it.cancel() }
        file.delete()
        notificationManager().cancel(NOTIFICATION_ID)
    }

    /** Alarm fired: post one notification if anything is due, then re-arm. */
    @Synchronized
    fun onAlarm() {
        val now = clock()
        val all = read()
        val due = all.filter { it.at <= now + DUE_SLACK_MS }
        val rest = all - due.toSet()
        write(rest)
        if (due.isNotEmpty()) postNotification(due.mapNotNull { e -> e.sealedLabel?.let { open(it) } })
        arm(rest.map { it.at })
    }

    /** Re-arms after boot / update / clock change; due-but-missed times notify now. */
    @Synchronized
    fun rearm() {
        val now = clock()
        val all = read()
        if (all.any { it.at <= now }) onAlarm() else arm(all.map { it.at })
    }

    private fun seal(label: String): String? = try {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, KeystoreKeys.notifyKey())
        val ct = cipher.doFinal(label.toByteArray(Charsets.UTF_8))
        Base64.encodeToString(cipher.iv + ct, Base64.NO_WRAP)
    } catch (_: Exception) {
        null // No label rather than a plaintext one: the notification stays generic.
    }

    private fun open(sealed: String): String? = try {
        val raw = Base64.decode(sealed, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, KeystoreKeys.notifyKey(), GCMParameterSpec(128, raw, 0, 12))
        String(cipher.doFinal(raw, 12, raw.size - 12), Charsets.UTF_8)
    } catch (_: Exception) {
        null
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

    private fun postNotification(labels: List<String>) {
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
        val text = if (labels.isEmpty()) res.getString(R.string.reminder_notification_text) else labels.joinToString("\n")
        val public = Notification.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_docsafe)
            .setContentTitle(title)
            .build()
        val n = Notification.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_docsafe)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
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
        // Same rule as the Dart side: the user's choice, else Hindi on a Hindi phone, else English.
        val lang = appContext.getSharedPreferences("docsafe_ui", Context.MODE_PRIVATE).getString("language", null)
            ?: if (Locale.getDefault().language == "hi") "hi" else "en"
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

    private fun read(): List<Entry> = try {
        if (!file.exists()) {
            emptyList()
        } else {
            file.readLines().mapNotNull { line ->
                val parts = line.trim().split('\t', limit = 2)
                parts[0].toLongOrNull()?.let { Entry(it, parts.getOrNull(1)?.takeIf { s -> s.isNotEmpty() }) }
            }.sortedBy { it.at }
        }
    } catch (_: Exception) {
        emptyList()
    }

    private fun write(entries: List<Entry>) {
        dir.mkdirs()
        if (entries.isEmpty()) {
            file.delete()
            return
        }
        val tmp = File(dir, "schedule.v1.tmp")
        tmp.writeText(entries.joinToString("\n") { e -> if (e.sealedLabel == null) "${e.at}" else "${e.at}\t${e.sealedLabel}" })
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
        const val MAX_LABEL = 300
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

package com.seedhachat.app

import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.text.format.DateUtils
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

class MainActivity : Activity() {
    private lateinit var ccInput: EditText
    private lateinit var numberInput: EditText
    private lateinit var messageInput: EditText
    private lateinit var errorText: TextView
    private lateinit var btnWhatsApp: Button
    private lateinit var btnBusiness: Button
    private lateinit var historyTitle: TextView
    private lateinit var historyList: LinearLayout
    private lateinit var history: HistoryStore

    private val prefs by lazy { getSharedPreferences("settings", Context.MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        history = HistoryStore(this)

        ccInput = findViewById(R.id.country_code)
        numberInput = findViewById(R.id.number)
        messageInput = findViewById(R.id.message)
        errorText = findViewById(R.id.error)
        btnWhatsApp = findViewById(R.id.btn_whatsapp)
        btnBusiness = findViewById(R.id.btn_business)
        historyTitle = findViewById(R.id.history_title)
        historyList = findViewById(R.id.history_list)

        ccInput.setText(prefs.getString("cc", "91"))

        findViewById<Button>(R.id.btn_paste).setOnClickListener { pasteFromClipboard() }
        findViewById<Button>(R.id.btn_clear).setOnClickListener {
            numberInput.text.clear(); messageInput.text.clear(); errorText.visibility = View.GONE
        }
        btnWhatsApp.setOnClickListener { openChat(PhoneUtils.PKG_WHATSAPP) }
        btnBusiness.setOnClickListener { openChat(PhoneUtils.PKG_WHATSAPP_BUSINESS) }
        findViewById<Button>(R.id.btn_share_link).setOnClickListener { shareLink() }
        numberInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_GO) { openChat(preferredPackage()); true } else false
        }
        setupTemplates()

        if (savedInstanceState == null) handleIncoming(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncoming(intent)
    }

    override fun onResume() {
        super.onResume()
        refreshAppButtons()
        renderHistory()
    }

    /** Text shared to the app, or selected text via the "Seedha Chat" option in the copy/paste menu. */
    private fun handleIncoming(intent: Intent?) {
        val text = when (intent?.action) {
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
            Intent.ACTION_PROCESS_TEXT -> intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            else -> null
        } ?: return
        fillFromText(text)
    }

    private fun pasteFromClipboard() {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val text = cm.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(this)?.toString()
        if (text.isNullOrBlank()) toast(R.string.clipboard_empty) else fillFromText(text)
    }

    private fun fillFromText(text: String) {
        val found = PhoneUtils.extractFirst(text)
        if (found == null) { toast(R.string.no_number_found); return }
        numberInput.setText(found)
        numberInput.setSelection(found.length)
        errorText.visibility = View.GONE
    }

    private fun setupTemplates() {
        val row = findViewById<LinearLayout>(R.id.templates)
        resources.getStringArray(R.array.templates).forEach { t ->
            val b = layoutInflater.inflate(R.layout.item_template, row, false) as Button
            b.text = t
            b.setOnClickListener { messageInput.setText(t); messageInput.setSelection(t.length) }
            row.addView(b)
        }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0); true
    } catch (e: PackageManager.NameNotFoundException) { false }

    private fun preferredPackage(): String? = when {
        isInstalled(PhoneUtils.PKG_WHATSAPP) -> PhoneUtils.PKG_WHATSAPP
        isInstalled(PhoneUtils.PKG_WHATSAPP_BUSINESS) -> PhoneUtils.PKG_WHATSAPP_BUSINESS
        else -> null
    }

    private fun refreshAppButtons() {
        val wa = isInstalled(PhoneUtils.PKG_WHATSAPP)
        val biz = isInstalled(PhoneUtils.PKG_WHATSAPP_BUSINESS)
        btnWhatsApp.isEnabled = wa
        btnBusiness.isEnabled = biz
        btnWhatsApp.setText(if (wa) R.string.open_whatsapp else R.string.whatsapp_not_installed)
        btnBusiness.setText(if (biz) R.string.open_business else R.string.business_not_installed)
        findViewById<TextView>(R.id.none_installed).visibility = if (wa || biz) View.GONE else View.VISIBLE
    }

    /** Validates the input; shows the error under the field and returns null if invalid. */
    private fun currentNumber(): String? {
        val cc = ccInput.text.toString().filter(Char::isDigit)
        val number = PhoneUtils.normalize(numberInput.text.toString(), cc)
        if (number == null) {
            errorText.setText(if (numberInput.text.isBlank()) R.string.error_empty else R.string.error_invalid)
            errorText.visibility = View.VISIBLE
            numberInput.requestFocus()
            return null
        }
        errorText.visibility = View.GONE
        prefs.edit().putString("cc", cc).apply()
        return number
    }

    /** pkg == null opens the wa.me link in whatever handles it (browser / WhatsApp Web). */
    private fun openChat(pkg: String?) {
        val number = currentNumber() ?: return
        val uri = Uri.parse(PhoneUtils.waLink(number, messageInput.text.toString()))
        val intent = Intent(Intent.ACTION_VIEW, uri).apply { if (pkg != null) setPackage(pkg) }
        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            try { startActivity(Intent(Intent.ACTION_VIEW, uri)) } catch (e2: ActivityNotFoundException) {
                toast(R.string.cannot_open); return
            }
        }
        history.add(number, if (pkg == PhoneUtils.PKG_WHATSAPP_BUSINESS) "B" else "W")
        renderHistory()
    }

    private fun shareLink() {
        val number = currentNumber() ?: return
        val link = PhoneUtils.waLink(number, messageInput.text.toString())
        startActivity(Intent.createChooser(
            Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, link),
            getString(R.string.share_link),
        ))
    }

    private fun renderHistory() {
        historyList.removeAllViews()
        val entries = history.all()
        historyTitle.visibility = if (entries.isEmpty()) View.GONE else View.VISIBLE
        entries.forEach { e ->
            val row = layoutInflater.inflate(R.layout.item_history, historyList, false)
            row.findViewById<TextView>(R.id.h_number).text = PhoneUtils.pretty(e.number)
            val ago = DateUtils.getRelativeTimeSpanString(e.time, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS)
            val app = getString(if (e.app == "B") R.string.label_business else R.string.label_whatsapp)
            row.findViewById<TextView>(R.id.h_meta).text = getString(R.string.history_meta, app, ago)
            row.setOnClickListener {
                numberInput.setText(getString(R.string.plus) + e.number)
                numberInput.setSelection(numberInput.text.length)
                errorText.visibility = View.GONE
            }
            row.setOnLongClickListener {
                AlertDialog.Builder(this)
                    .setMessage(getString(R.string.delete_entry, PhoneUtils.pretty(e.number)))
                    .setPositiveButton(R.string.delete) { _, _ -> history.remove(e.number); renderHistory() }
                    .setNegativeButton(android.R.string.cancel, null)
                    .show()
                true
            }
            historyList.addView(row)
        }
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.main, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean = when (item.itemId) {
        R.id.menu_clear_history -> {
            AlertDialog.Builder(this)
                .setMessage(R.string.clear_history_confirm)
                .setPositiveButton(R.string.delete) { _, _ -> history.clear(); renderHistory() }
                .setNegativeButton(android.R.string.cancel, null)
                .show()
            true
        }
        R.id.menu_about -> {
            AlertDialog.Builder(this)
                .setTitle(R.string.app_name)
                .setMessage(getString(R.string.about_text, packageManager.getPackageInfo(packageName, 0).versionName))
                .setPositiveButton(android.R.string.ok, null)
                .show()
            true
        }
        else -> super.onOptionsItemSelected(item)
    }

    private fun toast(res: Int) = Toast.makeText(this, res, Toast.LENGTH_SHORT).show()
}

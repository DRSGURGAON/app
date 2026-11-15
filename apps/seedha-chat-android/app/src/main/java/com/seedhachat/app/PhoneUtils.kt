package com.seedhachat.app

import java.net.URLEncoder

/** Pure-Kotlin helpers (no Android imports) so they run in plain JVM unit tests. */
object PhoneUtils {
    /** E.164 allows at most 15 digits including the country code. */
    const val MIN_DIGITS = 8
    const val MAX_DIGITS = 15

    const val PKG_WHATSAPP = "com.whatsapp"
    const val PKG_WHATSAPP_BUSINESS = "com.whatsapp.w4b"

    private val CANDIDATE = Regex("""\+?\d[\d\s\-().]{6,}\d""")

    /**
     * Turns whatever the user typed/pasted into international digits without "+"
     * (the format wa.me expects), or null if it can't be a valid number.
     *
     *  "+91 98765-43210" -> "919876543210"   (explicit + wins over the default code)
     *  "0091 9876543210" -> "919876543210"   (00 international prefix)
     *  "09876543210"     -> "919876543210"   (leading trunk 0 dropped, default code added)
     *  "919876543210"    -> "919876543210"   (already has the default code)
     */
    fun normalize(raw: String, defaultCountryCode: String): String? {
        val text = raw.trim()
        if (text.isEmpty()) return null
        val cc = defaultCountryCode.filter(Char::isDigit)
        val digits = text.filter(Char::isDigit)
        if (digits.isEmpty()) return null

        val result = when {
            text.startsWith("+") -> digits
            digits.startsWith("00") -> digits.drop(2)
            else -> {
                val national = digits.trimStart('0')
                // Longer than a 10-digit national number and already starts with the code.
                if (cc.isNotEmpty() && national.startsWith(cc) && national.length > 10) national
                else cc + national
            }
        }
        if (result.length !in MIN_DIGITS..MAX_DIGITS || result.startsWith("0")) return null
        return result
    }

    /**
     * Finds the most phone-like number in free text (an SMS, a shared page, a selection).
     * Prefers candidates with 10-15 digits over shorter ones (which are often dates/codes).
     * Returns the candidate with only "+" and digits kept, or null.
     */
    fun extractFirst(text: String): String? {
        val candidates = CANDIDATE.findAll(text)
            .map { m ->
                val plus = if (m.value.startsWith("+")) "+" else ""
                plus + m.value.filter(Char::isDigit)
            }
            .filter { it.count(Char::isDigit) in MIN_DIGITS..MAX_DIGITS }
            .toList()
        return candidates.firstOrNull { it.count(Char::isDigit) >= 10 } ?: candidates.firstOrNull()
    }

    /** Official click-to-chat link. The message is only pre-filled; the user still taps send. */
    fun waLink(internationalDigits: String, message: String?): String {
        val base = "https://wa.me/$internationalDigits"
        if (message.isNullOrBlank()) return base
        val encoded = URLEncoder.encode(message, "UTF-8").replace("+", "%20")
        return "$base?text=$encoded"
    }

    /** "919876543210" -> "+91 98765 43210" for Indian numbers, "+<digits>" otherwise. */
    fun pretty(internationalDigits: String): String =
        if (internationalDigits.length == 12 && internationalDigits.startsWith("91"))
            "+91 ${internationalDigits.substring(2, 7)} ${internationalDigits.substring(7)}"
        else "+$internationalDigits"
}

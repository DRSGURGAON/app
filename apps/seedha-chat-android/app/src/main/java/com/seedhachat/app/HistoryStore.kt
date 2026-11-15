package com.seedhachat.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Recent chats, kept only on this phone (SharedPreferences). Nothing leaves the device. */
class HistoryStore(context: Context) {
    data class Entry(val number: String, val time: Long, val app: String)

    private val prefs = context.getSharedPreferences("history", Context.MODE_PRIVATE)

    fun all(): List<Entry> {
        val arr = runCatching { JSONArray(prefs.getString(KEY, "[]")) }.getOrElse { JSONArray() }
        return (0 until arr.length()).mapNotNull { i ->
            arr.optJSONObject(i)?.let { Entry(it.optString("n"), it.optLong("t"), it.optString("a")) }
        }.filter { it.number.isNotEmpty() }
    }

    /** Adds to the top; the same number moves up instead of being duplicated. */
    fun add(number: String, app: String) {
        val list = listOf(Entry(number, System.currentTimeMillis(), app)) +
            all().filter { it.number != number }
        save(list.take(MAX))
    }

    fun remove(number: String) = save(all().filter { it.number != number })

    fun clear() = prefs.edit().remove(KEY).apply()

    private fun save(list: List<Entry>) {
        val arr = JSONArray()
        list.forEach { arr.put(JSONObject().put("n", it.number).put("t", it.time).put("a", it.app)) }
        prefs.edit().putString(KEY, arr.toString()).apply()
    }

    private companion object {
        const val KEY = "entries"
        const val MAX = 50
    }
}

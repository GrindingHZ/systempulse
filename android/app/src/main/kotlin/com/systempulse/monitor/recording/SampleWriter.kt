package com.systempulse.monitor.recording

import org.json.JSONObject
import java.io.BufferedWriter
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter

/**
 * Append-only writer for recorded samples, one JSON object per line (JSON Lines).
 *
 * Durability is the point. An earlier version accumulated every sample in memory and re-encoded the
 * entire session to SharedPreferences on each tick, which meant a process death lost whatever had
 * not yet been flushed, and cost grew with the square of the session length. Appending one line per
 * sample makes each write O(1) and bounds any loss to the samples since the last flush.
 *
 * JSON Lines is also recoverable: a file truncated mid-write by a process kill loses at most its
 * final line, and every complete line before it still parses.
 */
class SampleWriter(private val file: File) {

    private var writer: BufferedWriter? = null
    private var sinceFlush = 0

    @Synchronized
    fun open() {
        if (writer != null) return
        file.parentFile?.mkdirs()
        writer = BufferedWriter(OutputStreamWriter(FileOutputStream(file, /* append = */ true), Charsets.UTF_8))
    }

    @Synchronized
    fun append(sample: JSONObject) {
        val target = writer ?: run { open(); writer } ?: return
        target.write(sample.toString())
        target.newLine()
        // Flushing on a small cadence keeps the cost of an unexpected process death bounded to a
        // few seconds of samples without paying for a syscall on every single one.
        if (++sinceFlush >= FLUSH_EVERY) {
            target.flush()
            sinceFlush = 0
        }
    }

    @Synchronized
    fun flush() {
        runCatching { writer?.flush() }
        sinceFlush = 0
    }

    @Synchronized
    fun close() {
        runCatching {
            writer?.flush()
            writer?.close()
        }
        writer = null
        sinceFlush = 0
    }

    private companion object {
        const val FLUSH_EVERY = 5
    }
}

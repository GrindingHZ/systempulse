package com.systempulse.monitor.recording

import java.io.File
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Covers the durability guarantees the recorder depends on.
 *
 * The sample objects built here mirror exactly what RecordingService appends, so this test doubles
 * as the reference for the format the Dart side parses.
 */
class SampleWriterTest {

    private fun tempFile(): File = File.createTempFile("samples", ".jsonl").apply { delete() }

    private fun sample(timestamp: Long, cpu: Double?): JSONObject = JSONObject().apply {
        put("t", timestamp)
        put("cpuPercent", cpu ?: 0.0)
        put("cpuAvailable", cpu != null)
        put("cpuPerCorePercent", (cpu ?: 0.0) * 8)
        put("deviceMemoryPercent", 61.5)
        put("deviceMemoryUsedBytes", 8100000000L)
        put("deviceMemoryTotalBytes", 12884901888L)
        put("deviceLowMemory", false)
        put("appMemoryBytes", 148000000L)
        put("memoryAvailable", true)
        put("batteryPercent", 77.0)
        put("batteryTemperatureC", 30.5)
        put("batteryStatus", "Discharging")
        put("batteryCharging", false)
        put("batteryAvailable", true)
    }

    @Test
    fun `writes one complete JSON object per line`() {
        val file = tempFile()
        val writer = SampleWriter(file)
        writer.open()
        repeat(3) { writer.append(sample(1_700_000_000_000L + it * 1000L, 12.5)) }
        writer.close()

        val lines = file.readLines().filter { it.isNotBlank() }
        assertEquals(3, lines.size)
        lines.forEach { line ->
            val parsed = JSONObject(line)
            assertEquals(12.5, parsed.getDouble("cpuPercent"), 0.0001)
            assertTrue(parsed.getBoolean("cpuAvailable"))
        }
        file.delete()
    }

    @Test
    fun `appends to an existing file rather than truncating it`() {
        // A recording that outlives one writer instance must not lose what came before.
        val file = tempFile()

        SampleWriter(file).apply {
            open()
            append(sample(1L, 1.0))
            close()
        }
        SampleWriter(file).apply {
            open()
            append(sample(2L, 2.0))
            close()
        }

        assertEquals(2, file.readLines().count { it.isNotBlank() })
        file.delete()
    }

    @Test
    fun `flush makes samples readable before the writer is closed`() {
        // This is what bounds data loss when the process is killed mid-recording.
        val file = tempFile()
        val writer = SampleWriter(file)
        writer.open()
        writer.append(sample(1L, 5.0))
        writer.flush()

        assertEquals(1, file.readLines().count { it.isNotBlank() })
        writer.close()
        file.delete()
    }

    @Test
    fun `an unavailable metric is recorded as unavailable, not as zero`() {
        val file = tempFile()
        val writer = SampleWriter(file)
        writer.open()
        writer.append(sample(1L, null))
        writer.close()

        val parsed = JSONObject(file.readLines().first())
        // The Dart side keys off cpuAvailable and maps this to null, so a failed reading can never
        // be mistaken for a measured 0%.
        assertEquals(false, parsed.getBoolean("cpuAvailable"))
        file.delete()
    }

    @Test
    fun `open is idempotent so a redundant call cannot reset the stream`() {
        val file = tempFile()
        val writer = SampleWriter(file)
        writer.open()
        writer.append(sample(1L, 1.0))
        writer.open()
        writer.append(sample(2L, 2.0))
        writer.close()

        assertEquals(2, file.readLines().count { it.isNotBlank() })
        file.delete()
    }
}

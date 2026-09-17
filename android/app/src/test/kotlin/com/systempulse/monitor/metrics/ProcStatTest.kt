package com.systempulse.monitor.metrics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ProcStatTest {

    /** A realistic line; utime=1234 (field 14) and stime=567 (field 15). */
    private val ordinaryStatLine =
        "4242 (systempulse) S 1 4242 4242 0 -1 4194560 9001 0 12 0 1234 567 0 0 20 0 24 0 900123 " +
            "5000000 3000 18446744073709551615 1 1 0 0 0 0 0 4096 0 0 0 0 17 3 0 0 0 0 0"

    @Test
    fun `sums utime and stime`() {
        assertEquals(1234L + 567L, ProcStat.parseCpuTicks(ordinaryStatLine))
    }

    @Test
    fun `handles a process name containing spaces and parentheses`() {
        // The kernel does not escape comm. Splitting this line on whitespace shifts every field
        // after it, which is exactly the bug this parser exists to avoid.
        val line = ordinaryStatLine.replace("(systempulse)", "(my app (beta) v2)")
        assertEquals(1234L + 567L, ProcStat.parseCpuTicks(line))
    }

    @Test
    fun `handles a trailing newline as read from the filesystem`() {
        assertEquals(1234L + 567L, ProcStat.parseCpuTicks("$ordinaryStatLine\n"))
    }

    @Test
    fun `returns null for malformed input rather than a wrong number`() {
        assertNull(ProcStat.parseCpuTicks(""))
        assertNull(ProcStat.parseCpuTicks("no parenthesis here at all"))
        assertNull(ProcStat.parseCpuTicks("4242 (systempulse) S 1 2 3"))
        assertNull(ProcStat.parseCpuTicks("4242 (systempulse) S 1 2 3 4 5 6 7 8 9 10 x y"))
    }

    @Test
    fun `converts ticks to milliseconds`() {
        assertEquals(10_000L, ProcStat.ticksToMillis(1000L, 100L))
        assertEquals(1_000L, ProcStat.ticksToMillis(1000L, 1000L))
        assertEquals(0L, ProcStat.ticksToMillis(1000L, 0L))
    }

    @Test
    fun `one fully busy thread is one core of work`() {
        // 1000ms of CPU across a 1000ms window on a quad-core device: 100% of one core, 25% of
        // the device.
        assertEquals(25.0, ProcStat.utilisationPercent(1000L, 1000L, 4), 0.001)
        assertEquals(100.0, ProcStat.perCorePercent(1000L, 1000L, 4), 0.001)
    }

    @Test
    fun `an idle process reports exactly zero`() {
        // The frequency-ratio approach this replaced reported roughly 10-20% here, because idle
        // cores idle at their minimum frequency rather than at zero.
        assertEquals(0.0, ProcStat.utilisationPercent(0L, 1000L, 8), 0.001)
        assertEquals(0.0, ProcStat.perCorePercent(0L, 1000L, 8), 0.001)
    }

    @Test
    fun `multithreaded work exceeds one core but never exceeds the device`() {
        // Four threads busy for a full second on an 8-core device.
        assertEquals(50.0, ProcStat.utilisationPercent(4000L, 1000L, 8), 0.001)
        assertEquals(400.0, ProcStat.perCorePercent(4000L, 1000L, 8), 0.001)

        // More CPU time than the device can physically supply is clamped, not reported as >100%.
        assertEquals(100.0, ProcStat.utilisationPercent(99_000L, 1000L, 8), 0.001)
        assertEquals(800.0, ProcStat.perCorePercent(99_000L, 1000L, 8), 0.001)
    }

    @Test
    fun `degenerate windows report zero instead of dividing by zero`() {
        assertEquals(0.0, ProcStat.utilisationPercent(500L, 0L, 4), 0.001)
        assertEquals(0.0, ProcStat.utilisationPercent(500L, -10L, 4), 0.001)
        assertEquals(0.0, ProcStat.utilisationPercent(-5L, 1000L, 4), 0.001)
        assertEquals(0.0, ProcStat.utilisationPercent(500L, 1000L, 0), 0.001)
    }
}

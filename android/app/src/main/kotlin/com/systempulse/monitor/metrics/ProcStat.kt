package com.systempulse.monitor.metrics

/**
 * Pure parsing and arithmetic behind [ProcessCpuSampler], separated so it can be unit tested on the
 * JVM without an Android device or emulator.
 */
object ProcStat {

    private val WHITESPACE = Regex("\\s+")

    /** Offsets relative to field 3 (`state`), which is the first field after the `comm` group. */
    private const val UTIME_OFFSET = 11
    private const val STIME_OFFSET = 12

    /**
     * Sums `utime` and `stime` from a `/proc/<pid>/stat` line, in clock ticks.
     *
     * Field 2 (`comm`) is the executable name wrapped in parentheses, and the kernel does not
     * escape it — a process named `my app (beta)` produces both spaces and nested parentheses
     * inside that field. Splitting the line on whitespace therefore misaligns every subsequent
     * field. proc(5) guarantees the fields after `comm` are well formed, so we index from the
     * *last* ')' instead.
     *
     * @return combined ticks, or null if the line is malformed.
     */
    fun parseCpuTicks(statLine: String): Long? {
        val closingParen = statLine.lastIndexOf(')')
        if (closingParen < 0 || closingParen + 2 > statLine.length) return null

        val fields = statLine.substring(closingParen + 1).trim().split(WHITESPACE)
        if (fields.size <= STIME_OFFSET) return null

        val utime = fields[UTIME_OFFSET].toLongOrNull() ?: return null
        val stime = fields[STIME_OFFSET].toLongOrNull() ?: return null
        if (utime < 0L || stime < 0L) return null

        return utime + stime
    }

    /** Converts clock ticks to milliseconds for a given `SC_CLK_TCK`. */
    fun ticksToMillis(ticks: Long, clockTicksPerSecond: Long): Long =
        if (clockTicksPerSecond <= 0L) 0L else ticks * 1000L / clockTicksPerSecond

    /**
     * CPU utilisation over a sampling window.
     *
     * `cpuDelta / wallDelta` is the number of cores kept busy over the window. One fully busy
     * thread gives 1.0, which is 100% of a core and `100 / coreCount` percent of the device.
     *
     * @return percent of total device CPU capacity, clamped to 0..100.
     */
    fun utilisationPercent(cpuDeltaMillis: Long, wallDeltaMillis: Long, coreCount: Int): Double {
        if (wallDeltaMillis <= 0L || cpuDeltaMillis < 0L || coreCount <= 0) return 0.0
        val busyCores = cpuDeltaMillis.toDouble() / wallDeltaMillis.toDouble()
        return (busyCores / coreCount * 100.0).coerceIn(0.0, 100.0)
    }

    /**
     * The same measurement expressed against a single core, so a value above 100 means more than
     * one core's worth of work. Clamped to the total capacity of the device.
     */
    fun perCorePercent(cpuDeltaMillis: Long, wallDeltaMillis: Long, coreCount: Int): Double {
        if (wallDeltaMillis <= 0L || cpuDeltaMillis < 0L || coreCount <= 0) return 0.0
        val busyCores = cpuDeltaMillis.toDouble() / wallDeltaMillis.toDouble()
        return (busyCores * 100.0).coerceIn(0.0, coreCount * 100.0)
    }
}

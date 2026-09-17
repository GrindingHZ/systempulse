package com.systempulse.monitor.metrics

import android.os.Process
import android.os.SystemClock
import android.system.Os
import android.system.OsConstants
import java.io.File

/**
 * Measures CPU time actually consumed by this process.
 *
 * This replaces an earlier implementation that averaged `scaling_cur_freq / cpuinfo_max_freq`
 * across cores. That value is the DVFS clock ratio, not utilisation: an idle device reports a
 * large non-zero number because idle cores park at their minimum frequency, and a fully busy but
 * thermally throttled process reports a *smaller* number than an idle one. It was also read from
 * global sysfs, so it described the whole SoC rather than this app.
 *
 * Here we sample monotonically increasing CPU time for our own process and divide the delta by the
 * elapsed wall-clock time. That is the standard definition of CPU utilisation and is the same thing
 * `top` reports.
 *
 *   utilisation = (cpuTimeNow - cpuTimeBefore) / (wallClockNow - wallClockBefore)
 *
 * A single fully busy thread yields 1.0 core (`perCorepercent` = 100). Dividing by the number of
 * cores expresses the same figure as a share of total device capacity (`percent`).
 */
class ProcessCpuSampler {

    /** Number of CPU cores the measurement is normalised against. */
    val coreCount: Int = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)

    private val clockTicksPerSecond: Long = runCatching {
        Os.sysconf(OsConstants._SC_CLK_TCK).takeIf { it > 0 } ?: DEFAULT_CLOCK_TICKS
    }.getOrDefault(DEFAULT_CLOCK_TICKS)

    private var previousCpuMillis: Long = -1L
    private var previousElapsedMillis: Long = -1L

    /**
     * Result of one sample.
     *
     * @param available false when CPU time could not be read at all. Callers must surface this
     *   rather than substituting 0, so that "no reading" is never mistaken for "idle".
     * @param warmingUp true for the very first sample, where no previous reading exists to diff
     *   against. A utilisation figure needs two points in time; the first call only primes them.
     */
    data class Sample(
        val percent: Double,
        val perCorePercent: Double,
        val available: Boolean,
        val warmingUp: Boolean,
    )

    /**
     * Takes a reading. Call at a steady interval; each call measures the window since the previous
     * call, so the caller's sampling period defines the averaging window.
     */
    @Synchronized
    fun sample(): Sample {
        val cpuMillis = readProcessCpuMillis() ?: return unavailable()
        val elapsedMillis = SystemClock.elapsedRealtime()

        val previousCpu = previousCpuMillis
        val previousElapsed = previousElapsedMillis
        previousCpuMillis = cpuMillis
        previousElapsedMillis = elapsedMillis

        if (previousCpu < 0L || previousElapsed < 0L) {
            return Sample(0.0, 0.0, available = true, warmingUp = true)
        }

        val wallDelta = elapsedMillis - previousElapsed
        val cpuDelta = cpuMillis - previousCpu

        // A non-positive window carries no information, and a negative CPU delta should be
        // impossible for a monotonic counter. Report the sample as still warming up rather than
        // emitting a meaningless or negative utilisation.
        if (wallDelta <= 0L || cpuDelta < 0L) {
            return Sample(0.0, 0.0, available = true, warmingUp = true)
        }

        return Sample(
            percent = ProcStat.utilisationPercent(cpuDelta, wallDelta, coreCount),
            perCorePercent = ProcStat.perCorePercent(cpuDelta, wallDelta, coreCount),
            available = true,
            warmingUp = false,
        )
    }

    /** Discards accumulated state so the next sample starts a fresh window. */
    @Synchronized
    fun reset() {
        previousCpuMillis = -1L
        previousElapsedMillis = -1L
    }

    private fun unavailable(): Sample = Sample(0.0, 0.0, available = false, warmingUp = false)

    /**
     * Total CPU time (user + system) consumed by this process, in milliseconds.
     *
     * `/proc/self/stat` is preferred because it is always readable for a process's own entry
     * regardless of SELinux policy, and it covers every thread in the process. If parsing fails for
     * any reason we fall back to the public [Process.getElapsedCpuTime].
     */
    private fun readProcessCpuMillis(): Long? = readFromProcSelfStat() ?: readFromProcessApi()

    private fun readFromProcSelfStat(): Long? = runCatching {
        val ticks = ProcStat.parseCpuTicks(File("/proc/self/stat").readText())
            ?: return@runCatching null
        ProcStat.ticksToMillis(ticks, clockTicksPerSecond)
    }.getOrNull()

    private fun readFromProcessApi(): Long? =
        runCatching { Process.getElapsedCpuTime().takeIf { it >= 0L } }.getOrNull()

    private companion object {
        const val DEFAULT_CLOCK_TICKS = 100L
    }
}

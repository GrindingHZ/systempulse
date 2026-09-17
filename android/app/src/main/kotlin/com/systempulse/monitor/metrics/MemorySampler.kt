package com.systempulse.monitor.metrics

import android.app.ActivityManager
import android.content.Context
import android.os.Debug
import android.os.Process

/**
 * Reads memory figures for both the device as a whole and this process specifically.
 *
 * These are two genuinely different measurements and the UI labels them separately. Reporting only
 * one under the generic name "memory usage" (as an earlier version did) is misleading: device-wide
 * usage barely moves in response to anything the app does, while process usage says nothing about
 * memory pressure on the device.
 */
class MemorySampler(private val context: Context) {

    private val activityManager: ActivityManager? =
        context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager

    /**
     * @param deviceUsedBytes physical RAM in use device-wide. Derived from `totalMem - availMem`.
     *   Note that Linux counts reclaimable page cache as "used", so this figure sits high (often
     *   70-90%) on a healthy device and should not be read as memory pressure. [deviceLowMemory]
     *   is the signal that actually indicates pressure.
     * @param appPssBytes proportional set size for this process: private memory plus this process's
     *   share of anything mapped by several processes. This is the figure Android itself uses to
     *   compare app footprints.
     */
    data class Sample(
        val deviceTotalBytes: Long,
        val deviceAvailableBytes: Long,
        val deviceUsedBytes: Long,
        val deviceUsedPercent: Double,
        val deviceLowMemory: Boolean,
        val appPssBytes: Long,
        val appPssPercentOfDevice: Double,
        val appJavaHeapUsedBytes: Long,
        val appJavaHeapMaxBytes: Long,
        val available: Boolean,
    )

    fun sample(): Sample {
        val manager = activityManager ?: return unavailable()

        val info = ActivityManager.MemoryInfo()
        runCatching { manager.getMemoryInfo(info) }.getOrElse { return unavailable() }

        val total = info.totalMem
        if (total <= 0L) return unavailable()

        val available = info.availMem.coerceIn(0L, total)
        val used = (total - available).coerceAtLeast(0L)

        val appPssBytes = readAppPssBytes(manager)
        val runtime = Runtime.getRuntime()

        return Sample(
            deviceTotalBytes = total,
            deviceAvailableBytes = available,
            deviceUsedBytes = used,
            deviceUsedPercent = used * 100.0 / total,
            deviceLowMemory = info.lowMemory,
            appPssBytes = appPssBytes,
            appPssPercentOfDevice = if (appPssBytes > 0L) appPssBytes * 100.0 / total else 0.0,
            appJavaHeapUsedBytes = (runtime.totalMemory() - runtime.freeMemory()).coerceAtLeast(0L),
            appJavaHeapMaxBytes = runtime.maxMemory().coerceAtLeast(0L),
            available = true,
        )
    }

    /**
     * PSS for this process, in bytes, or 0 when it cannot be determined.
     *
     * `getProcessMemoryInfo` is a binder call to system_server and is comparatively expensive, so
     * callers should sample at a modest interval rather than per frame.
     */
    private fun readAppPssBytes(manager: ActivityManager): Long = runCatching {
        val stats: Array<Debug.MemoryInfo>? =
            manager.getProcessMemoryInfo(intArrayOf(Process.myPid()))
        val totalPssKb = stats?.firstOrNull()?.totalPss ?: return@runCatching 0L
        if (totalPssKb <= 0) 0L else totalPssKb.toLong() * BYTES_PER_KB
    }.getOrDefault(0L)

    private fun unavailable(): Sample = Sample(
        deviceTotalBytes = 0L,
        deviceAvailableBytes = 0L,
        deviceUsedBytes = 0L,
        deviceUsedPercent = 0.0,
        deviceLowMemory = false,
        appPssBytes = 0L,
        appPssPercentOfDevice = 0.0,
        appJavaHeapUsedBytes = 0L,
        appJavaHeapMaxBytes = 0L,
        available = false,
    )

    private companion object {
        const val BYTES_PER_KB = 1024L
    }
}

package com.systempulse.monitor.metrics

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.util.DisplayMetrics
import java.io.File

/**
 * Reports device hardware facts.
 *
 * Every value here is read from the device. Where something cannot be determined the field is
 * omitted so the UI can say so, because an earlier version guessed: any 8-core device was labelled
 * "MediaTek Dimensity 8300-Ultra @ 3.35 GHz with 8.0 GB", which is simply invented and was shown to
 * users as their own hardware. Absent data is reported as absent.
 */
class DeviceInfoProvider(private val context: Context) {

    fun collect(): Map<String, Any?> {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo().also { info ->
            runCatching { activityManager?.getMemoryInfo(info) }
        }
        val metrics: DisplayMetrics = context.resources.displayMetrics

        return mapOf(
            "deviceModel" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "device" to Build.DEVICE,
            "board" to Build.BOARD,
            "hardware" to Build.HARDWARE,
            "androidRelease" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            // SUPPORTED_ABIS supersedes the long-deprecated CPU_ABI and reports every ABI the
            // device can run, most-preferred first.
            "abis" to Build.SUPPORTED_ABIS.toList(),
            "coreCount" to Runtime.getRuntime().availableProcessors(),
            // Null rather than a guess when the kernel does not expose cpufreq to apps.
            "maxCpuFrequencyMhz" to readMaxCpuFrequencyMhz(),
            "totalRamBytes" to memoryInfo.totalMem.takeIf { it > 0L },
            "screenWidthPx" to metrics.widthPixels,
            "screenHeightPx" to metrics.heightPixels,
            "screenDensityDpi" to metrics.densityDpi,
        )
    }

    /**
     * Highest `cpuinfo_max_freq` across cores, in MHz, or null when unreadable.
     *
     * This is a static hardware capability, which is the one thing cpufreq sysfs is actually
     * suitable for. It is deliberately *not* used to infer utilisation. Many devices restrict these
     * nodes to system apps, in which case null is returned and the UI omits the row.
     */
    private fun readMaxCpuFrequencyMhz(): Int? {
        val cores = Runtime.getRuntime().availableProcessors()
        var best = 0L
        for (core in 0 until cores) {
            val khz = runCatching {
                File("/sys/devices/system/cpu/cpu$core/cpufreq/cpuinfo_max_freq")
                    .readText()
                    .trim()
                    .toLong()
            }.getOrNull() ?: continue
            if (khz > best) best = khz
        }
        return if (best > 0L) (best / 1000L).toInt() else null
    }
}

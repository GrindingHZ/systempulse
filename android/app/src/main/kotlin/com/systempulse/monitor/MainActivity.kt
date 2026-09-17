package com.systempulse.monitor

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.systempulse.monitor.export.MediaStoreExporter
import com.systempulse.monitor.metrics.BatterySampler
import com.systempulse.monitor.metrics.DeviceInfoProvider
import com.systempulse.monitor.metrics.MemorySampler
import com.systempulse.monitor.metrics.ProcessCpuSampler
import com.systempulse.monitor.recording.RecordingService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and exposes the native metrics surface over a single method channel.
 *
 * An earlier version registered five channels — `performance`, `performance_tracker`,
 * `system_performance_tracker`, `device_hardware_info` and `sensors` — three of which served
 * byte-identical copies of the same handler, plus a sensors channel nothing consumed. There is one
 * channel here and one implementation behind it.
 */
class MainActivity : FlutterActivity() {

    private lateinit var cpuSampler: ProcessCpuSampler
    private lateinit var memorySampler: MemorySampler
    private lateinit var batterySampler: BatterySampler
    private lateinit var deviceInfoProvider: DeviceInfoProvider
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val context = applicationContext
        cpuSampler = ProcessCpuSampler()
        memorySampler = MemorySampler(context)
        batterySampler = BatterySampler(context)
        deviceInfoProvider = DeviceInfoProvider(context)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result -> handle(context, call, result) }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sample" -> result.success(sample())
            "deviceInfo" -> result.success(deviceInfoProvider.collect())
            "startRecording" -> result.success(startRecording(context, call))
            "stopRecording" -> result.success(stopRecording(context))
            "sessionsDirectory" -> result.success(RecordingService.sessionsDirectory(context).absolutePath)
            "saveToDownloads" -> result.success(saveToDownloads(context, call))
            else -> result.notImplemented()
        }
    }

    /**
     * One live reading for the UI.
     *
     * Availability flags travel with the values so the UI can render "—" for a metric the device
     * will not report, instead of a zero that reads as a real measurement.
     */
    private fun sample(): Map<String, Any?> {
        val cpu = cpuSampler.sample()
        val memory = memorySampler.sample()
        val battery = batterySampler.sample()

        return mapOf(
            "t" to System.currentTimeMillis(),
            "cpuPercent" to cpu.percent,
            "cpuPerCorePercent" to cpu.perCorePercent,
            "cpuAvailable" to (cpu.available && !cpu.warmingUp),
            "coreCount" to cpuSampler.coreCount,
            "deviceMemoryPercent" to memory.deviceUsedPercent,
            "deviceMemoryUsedBytes" to memory.deviceUsedBytes,
            "deviceMemoryTotalBytes" to memory.deviceTotalBytes,
            "deviceLowMemory" to memory.deviceLowMemory,
            "appMemoryBytes" to memory.appPssBytes,
            "memoryAvailable" to memory.available,
            "batteryPercent" to battery.levelPercent,
            "batteryTemperatureC" to battery.temperatureCelsius,
            "batteryStatus" to battery.status,
            "batteryCharging" to battery.isCharging,
            "batteryAvailable" to battery.available,
        )
    }

    private fun startRecording(context: Context, call: MethodCall): Boolean {
        val sessionId = call.argument<String>("sessionId") ?: return false
        val interval = call.argument<Int>("intervalSeconds") ?: 1

        // A foreground service must post a notification, and from API 33 that needs a runtime
        // grant. Requesting it here rather than at launch means the prompt appears at the moment
        // its purpose is obvious. Recording proceeds either way — a denied notification does not
        // stop the service, it only hides its status — so the result is not awaited.
        requestNotificationPermissionIfNeeded()

        val intent = Intent(context, RecordingService::class.java).apply {
            action = RecordingService.ACTION_START
            putExtra(RecordingService.EXTRA_SESSION_ID, sessionId)
            putExtra(RecordingService.EXTRA_INTERVAL_SECONDS, interval)
        }

        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        }.getOrDefault(false)
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED

        if (!granted) {
            runCatching {
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST,
                )
            }
        }
    }

    private fun stopRecording(context: Context): Boolean = runCatching {
        context.startService(
            Intent(context, RecordingService::class.java).setAction(RecordingService.ACTION_STOP)
        )
        true
    }.getOrDefault(false)

    private fun saveToDownloads(context: Context, call: MethodCall): String? {
        val name = call.argument<String>("fileName") ?: return null
        val content = call.argument<String>("content") ?: return null
        val mimeType = call.argument<String>("mimeType") ?: "text/csv"
        return MediaStoreExporter.saveToDownloads(context, name, content, mimeType)
    }

    private companion object {
        const val CHANNEL = "com.systempulse.monitor/metrics"
        const val NOTIFICATION_PERMISSION_REQUEST = 9001
    }
}

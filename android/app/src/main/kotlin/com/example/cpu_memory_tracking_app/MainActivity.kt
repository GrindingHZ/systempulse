package com.example.cpu_memory_tracking_app

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Binder
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.FileReader
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterFragmentActivity(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var brightness: Sensor? = null
    private var accelerometer: Sensor? = null
    private var lightVal: Int = 0

    private var acceleroReading: FloatArray = FloatArray(0)
    private var status: String = ""
    private var sensorData = HashMap<String, Int>()

    // System monitoring constants
    private val SYSTEM_PERFORMANCE_CHANNEL = "system_performance_tracker"
    private val CHANNEL = "com.example.cpu_memory_tracking_app/performance"
    private val PERFORMANCE_TRACKER_CHANNEL = "performance_tracker"
    private val HARDWARE_CHANNEL = "device_hardware_info"

    // --- Service related variables ---
    private var cpuMonitoringService: CpuMonitoringService? = null
    private var isServiceBound = false

    // Defines callbacks for service binding, passed to bindService()
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as CpuMonitoringService.LocalBinder
            cpuMonitoringService = binder.getService()
            isServiceBound = true
            Log.d("MainActivity", "CpuMonitoringService bound successfully.")
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            cpuMonitoringService = null
            isServiceBound = false
            Log.d("MainActivity", "CpuMonitoringService unbound.")
        }
    }
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Start and bind to the service when the activity is created
        val serviceIntent = Intent(this, CpuMonitoringService::class.java)
        // For Android O and above, services started in the background must use startForegroundService()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Unbind and stop the service when the activity is destroyed
        if (isServiceBound) {
            unbindService(serviceConnection)
            isServiceBound = false
        }
        val serviceIntent = Intent(this, CpuMonitoringService::class.java)
        stopService(serviceIntent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        setUpSensor()
        super.configureFlutterEngine(flutterEngine)

        // Original performance channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentPerformance" -> {
                    if (isServiceBound && cpuMonitoringService != null) {
                        val cpuUsage = cpuMonitoringService!!.getCurrentCpuUsage()
                        val memoryInfo = getCurrentMemoryUsage()
                        val performanceData = mapOf(
                            "cpuUsage" to cpuUsage,
                            "memoryUsage" to (memoryInfo["memoryPercentage"] as Double),
                            "memoryUsedMB" to ((memoryInfo["usedMemory"] as Long) / (1024 * 1024)),
                            "memoryTotalMB" to ((memoryInfo["totalMemory"] as Long) / (1024 * 1024))
                        )
                        result.success(performanceData)
                    } else {
                        result.error("SERVICE_NOT_BOUND", "CPU monitoring service not bound.", null)
                    }
                }
                "getCpuUsage" -> {
                    if (isServiceBound && cpuMonitoringService != null) {
                        val cpuUsage = cpuMonitoringService!!.getCurrentCpuUsage()
                        result.success(cpuUsage)
                    } else {
                        result.error("SERVICE_NOT_BOUND", "CPU monitoring service not bound.", null)
                    }
                }
                "getMemoryUsage" -> {
                    val memoryUsage = getCurrentMemoryUsage()
                    result.success(memoryUsage)
                }
                else -> result.notImplemented()
            }
        }

        // Performance tracker channel (used by PerformanceProvider)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERFORMANCE_TRACKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentPerformance" -> {
                    if (isServiceBound && cpuMonitoringService != null) {
                        val cpuUsage = cpuMonitoringService!!.getCurrentCpuUsage()
                        val memoryInfo = getCurrentMemoryUsage()
                        val performanceData = mapOf(
                            "cpuUsage" to cpuUsage,
                            "memoryUsage" to (memoryInfo["memoryPercentage"] as Double),
                            "memoryUsedMB" to ((memoryInfo["usedMemory"] as Long) / (1024 * 1024)),
                            "memoryTotalMB" to ((memoryInfo["totalMemory"] as Long) / (1024 * 1024))
                        )
                        result.success(performanceData)
                    } else {
                        result.error("SERVICE_NOT_BOUND", "CPU monitoring service not bound.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Device hardware info channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HARDWARE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidHardwareInfo" -> {
                    try {
                        val hardwareInfo = getBasicHardwareInfo()
                        result.success(hardwareInfo)
                    } catch (e: Exception) {
                        result.error("HARDWARE_ERROR", "Failed to get hardware info: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // System performance monitoring channel (additional compatibility)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_PERFORMANCE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentPerformance" -> {
                    if (isServiceBound && cpuMonitoringService != null) {
                        val cpuUsage = cpuMonitoringService!!.getCurrentCpuUsage()
                        val memoryInfo = getCurrentMemoryUsage()
                        val performanceData = mapOf(
                            "cpuUsage" to cpuUsage,
                            "memoryUsage" to (memoryInfo["memoryPercentage"] as Double),
                            "memoryUsedMB" to ((memoryInfo["usedMemory"] as Long) / (1024 * 1024)),
                            "memoryTotalMB" to ((memoryInfo["totalMemory"] as Long) / (1024 * 1024))
                        )
                        result.success(performanceData)
                    } else {
                        result.error("SERVICE_NOT_BOUND", "CPU monitoring service not bound.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Sensor channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.cpu_memory_tracking_app/sensors").setMethodCallHandler { call, result ->
            if (call.method == "getLightLevel") {
                sensorData[status] = lightVal
                result.success(sensorData)
            } else if (call.method == "getAccelerometerReading") {
                result.success(acceleroReading)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun setUpSensor() {
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        brightness = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        if (accelerometer == null) {
            status = "accelerometer not available"
        } else {
            status = "accelerometer available"
        }

        if (brightness == null) {
            // Handle case where sensor is not available
            status = "ls not available"
        } else {
            status = "ls available"
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_LIGHT) {
            lightVal = event.values[0].toInt()
        }

        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
            acceleroReading = event.values
        }
    }

    override fun onAccuracyChanged(p0: Sensor?, p1: Int) {
        // Not used for these sensors, but required by SensorEventListener interface
        return
    }

    override fun onResume() {
        super.onResume()
        // Register listeners for the sensors when the activity resumes
        sensorManager.registerListener(this, brightness, SensorManager.SENSOR_DELAY_NORMAL)
        sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_NORMAL)
        // CPU monitoring is now handled by the service, no need to start/stop here
    }

    override fun onPause() {
        super.onPause()
        // Unregister sensor listeners when the activity pauses
        sensorManager.unregisterListener(this)
        // CPU monitoring is now handled by the service, no need to start/stop here
    }

    // Memory usage is still gathered by MainActivity as it's less performance-critical
    private fun getCurrentMemoryUsage(): Map<String, Any> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        val runtime = Runtime.getRuntime()
        val usedMemory = runtime.totalMemory() - runtime.freeMemory()
        val maxMemory = runtime.maxMemory()

        val nativeHeapSize = Debug.getNativeHeapSize()
        val nativeHeapFreeSize = Debug.getNativeHeapFreeSize()
        val nativeHeapAllocatedSize = Debug.getNativeHeapAllocatedSize()

        return mapOf(
            "totalMemory" to memoryInfo.totalMem,
            "availableMemory" to memoryInfo.availMem,
            "usedMemory" to (memoryInfo.totalMem - memoryInfo.availMem),
            "memoryPercentage" to ((memoryInfo.totalMem - memoryInfo.availMem) * 100.0 / memoryInfo.totalMem),
            "appUsedMemory" to usedMemory,
            "appMaxMemory" to maxMemory,
            "appMemoryPercentage" to (usedMemory * 100.0 / maxMemory),
            "nativeHeapSize" to nativeHeapSize,
            "nativeHeapFree" to nativeHeapFreeSize,
            "nativeHeapAllocated" to nativeHeapAllocatedSize,
            "lowMemoryThreshold" to memoryInfo.threshold,
            "isLowMemory" to memoryInfo.lowMemory
        )
    }

    private fun getBasicHardwareInfo(): Map<String, Any> {
        val hardwareInfo = mutableMapOf<String, Any>()
        
        try {
            // Device model and manufacturer
            hardwareInfo["deviceModel"] = Build.MODEL
            hardwareInfo["manufacturer"] = Build.MANUFACTURER
            
            // Android version  
            hardwareInfo["osVersion"] = "${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})"
            
            // CPU ABI and architecture
            hardwareInfo["architecture"] = Build.CPU_ABI
            hardwareInfo["processorName"] = "${Build.MANUFACTURER} ${Build.HARDWARE}"
            
            // Core count
            hardwareInfo["coreCount"] = Runtime.getRuntime().availableProcessors()
            
            // RAM size (approximate)
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            val totalRamMB = memoryInfo.totalMem / (1024 * 1024) // Convert to MB
            hardwareInfo["totalRamGB"] = String.format("%.1f GB", totalRamMB / 1024.0)
            
            // Screen resolution
            val displayMetrics = resources.displayMetrics
            hardwareInfo["screenWidth"] = displayMetrics.widthPixels
            hardwareInfo["screenHeight"] = displayMetrics.heightPixels
            
        } catch (e: Exception) {
            hardwareInfo["error"] = e.message ?: "Unknown error retrieving hardware info"
        }
        return hardwareInfo
    }
}

// CpuMonitoringService class
class CpuMonitoringService : Service() {

    private val TAG = "CpuMonitoringService"
    private val NOTIFICATION_CHANNEL_ID = "cpu_monitoring_channel"
    private val NOTIFICATION_ID = 101

    private lateinit var cpuFrequencyMonitor: CpuFrequencyMonitor
    private val cpuScheduler = Executors.newSingleThreadScheduledExecutor()
    private var cpuMonitorFuture: ScheduledFuture<*>? = null

    @Volatile private var currentCpuUsagePercentage: Double = 0.0 // Volatile for thread-safe access

    // Binder for clients to interact with the service
    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): CpuMonitoringService = this@CpuMonitoringService
    }

    override fun onBind(intent: Intent?): IBinder {
        Log.d(TAG, "Service bound.")
        return binder
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate.")
        cpuFrequencyMonitor = CpuFrequencyMonitor(TAG)
        startForeground()
        startCpuMonitoring()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand.")
        // If the service is killed by the system, it will be restarted.
        // The intent will be null, so we handle that case.
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service onDestroy.")
        stopCpuMonitoring()
        stopForeground(true) // Remove notification
        cpuScheduler.shutdown() // Shut down the executor service
    }

    /**
     * Starts the service as a foreground service, displaying a persistent notification.
     */
    private fun startForeground() {
        createNotificationChannel()

        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE // Use FLAG_IMMUTABLE for security
        )

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("SystemPulse CPU Monitoring")
            .setContentText("Monitoring CPU usage in the background.")
            .setSmallIcon(android.R.drawable.ic_menu_info_details) // Generic info icon
            .setContentIntent(pendingIntent)
            .setOngoing(true) // Makes the notification non-dismissible
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    /**
     * Creates a notification channel for Android O and above.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "SystemPulse CPU Monitoring Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    /**
     * Starts monitoring CPU usage at a fixed interval.
     * This method initializes the CpuFrequencyMonitor and schedules the calculation task.
     */
    private fun startCpuMonitoring() {
        stopCpuMonitoring() // Ensure any previous task is stopped before starting a new one

        cpuMonitorFuture = cpuScheduler.scheduleAtFixedRate({
            currentCpuUsagePercentage = cpuFrequencyMonitor.getAppCpuUsagePercentage()
            Log.d(TAG, "Service Calculated CPU Usage: ${"%.2f".format(currentCpuUsagePercentage)}%")
        }, 0, 1000, TimeUnit.MILLISECONDS) // Initial delay of 0, then repeat every 1 second

        Log.d(TAG, "CPU monitoring started in service.")
    }

    /**
     * Stops the CPU usage monitoring task.
     * Cancels the scheduled task and clears relevant state variables.
     */
    private fun stopCpuMonitoring() {
        cpuMonitorFuture?.cancel(true) // Attempt to interrupt the task if running, then cancel
        cpuMonitorFuture = null
        currentCpuUsagePercentage = 0.0 // Reset CPU usage percentage
        Log.d(TAG, "CPU monitoring stopped in service.")
    }

    /**
     * Returns the last calculated CPU usage percentage.
     * This method is called by bound clients (like MainActivity).
     */
    fun getCurrentCpuUsage(): Double {
        return currentCpuUsagePercentage
    }
}

/**
 * A helper class to calculate approximate CPU usage percentage for the current process
 * by reading CPU core frequencies from the /sys filesystem.
 */
class CpuFrequencyMonitor(private val tag: String) {

    private val numCores: Int = Runtime.getRuntime().availableProcessors()

    /**
     * Calculates the approximate CPU usage percentage for the app process based on core frequencies.
     * The percentage is capped at 100% to represent total system utilization.
     *
     * @return The approximate CPU usage percentage (capped at 100%).
     */
    fun getAppCpuUsagePercentage(): Double {
        var sumOfCoreUtilizations = 0.0
        var activeCoresCount = 0 // Count cores that provide valid frequency data

        for (i in 0 until numCores) {
            val currentFreq = getCurrentFreq(i)
            val minMaxFreq = getMinMaxFreq(i)
            val maxFreq = minMaxFreq.second // Get max frequency

            if (currentFreq != -1L && maxFreq > 0) {
                // Calculate individual core utilization (0.0 to 1.0)
                val coreUtilization = currentFreq.toDouble() / maxFreq
                sumOfCoreUtilizations += coreUtilization
                activeCoresCount++
            }
        }

        // Calculate average utilization across active cores, then convert to percentage.
        // If no active cores, return 0.0 to avoid division by zero.
        val averageUtilization = if (activeCoresCount > 0) {
            sumOfCoreUtilizations / activeCoresCount
        } else {
            0.0
        }

        // Cap the final percentage at 100%
        return min(averageUtilization * 100.0, 100.0)
    }

    /**
     * Reads the current frequency of a specific CPU core from /sys filesystem.
     *
     * @param coreNumber The index of the CPU core (e.g., 0 for cpu0).
     * @return Current frequency in MHz, or -1 if reading fails.
     */
    private fun getCurrentFreq(coreNumber: Int): Long {
        val currentFreqPath = "${CPU_INFO_DIR}cpu$coreNumber/cpufreq/scaling_cur_freq"
        return try {
            readSysFsFile(currentFreqPath).toLong() / 1000 // Convert to MHz
        } catch (e: Exception) {
            Log.e(tag, "getCurrentFreq() - cannot read file $currentFreqPath", e)
            -1
        }
    }

    /**
     * Reads min/max frequencies for a specific CPU core from /sys filesystem.
     *
     * @param coreNumber The index of the CPU core (e.g., 0 for cpu0).
     * @return Pair of (minFreqMhz, maxFreqMhz), or (-1, -1) if reading fails.
     */
    private fun getMinMaxFreq(coreNumber: Int): Pair<Long, Long> {
        val minPath = "${CPU_INFO_DIR}cpu$coreNumber/cpufreq/cpuinfo_min_freq"
        val maxPath = "${CPU_INFO_DIR}cpu$coreNumber/cpufreq/cpuinfo_max_freq"
        return try {
            val minMhz = readSysFsFile(minPath).toLong() / 1000
            val maxMhz = readSysFsFile(maxPath).toLong() / 1000
            Pair(minMhz, maxMhz)
        } catch (e: Exception) {
            Log.e(tag, "getMinMaxFreq() - cannot read files for core $coreNumber", e)
            Pair(-1, -1)
        }
    }

    /**
     * Helper function to read content from a /sys filesystem file.
     *
     * @param filePath The full path to the file.
     * @return The content of the file as a String.
     * @throws IOException if the file cannot be read.
     * @throws NumberFormatException if the content is not a valid number.
     */
    private fun readSysFsFile(filePath: String): String {
        BufferedReader(FileReader(filePath)).use { reader ->
            return reader.readLine().trim()
        }
    }

    companion object {
        private const val CPU_INFO_DIR = "/sys/devices/system/cpu/"
    }
}

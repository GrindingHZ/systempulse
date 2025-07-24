package com.example.cpu_memory_tracking_app

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Debug
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.cpu_memory_tracking_app/performance"
    private val PERFORMANCE_TRACKER_CHANNEL = "performance_tracker"
    private val HARDWARE_CHANNEL = "device_hardware_info"
    private val FLOATING_OVERLAY_CHANNEL = "floating_overlay"
    
    private var overlayService: OverlayService? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Main performance channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentPerformance" -> {
                    val cpuUsage = getCurrentCpuUsage()
                    val memoryInfo = getCurrentMemoryUsage()
                    val performanceData = mapOf(
                        "cpuUsage" to cpuUsage,
                        "memoryUsage" to (memoryInfo["memoryPercentage"] as Double),
                        "memoryUsedMB" to ((memoryInfo["usedMemory"] as Long) / (1024 * 1024)),
                        "memoryTotalMB" to ((memoryInfo["totalMemory"] as Long) / (1024 * 1024))
                    )
                    result.success(performanceData)
                }
                "getCpuUsage" -> {
                    val cpuUsage = getCurrentCpuUsage()
                    result.success(cpuUsage)
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
                    val cpuUsage = getCurrentCpuUsage()
                    val memoryInfo = getCurrentMemoryUsage()
                    val performanceData = mapOf(
                        "cpuUsage" to cpuUsage,
                        "memoryUsage" to (memoryInfo["memoryPercentage"] as Double),
                        "memoryUsedMB" to ((memoryInfo["usedMemory"] as Long) / (1024 * 1024)),
                        "memoryTotalMB" to ((memoryInfo["totalMemory"] as Long) / (1024 * 1024))
                    )
                    result.success(performanceData)
                }
                else -> result.notImplemented()
            }
        }
        
        // Floating overlay channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (!Settings.canDrawOverlays(this)) {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, 
                                               Uri.parse("package:$packageName"))
                            startActivity(intent)
                            result.success(false) // User needs to grant permission manually
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "startOverlay" -> {
                    if (overlayService == null) {
                        overlayService = OverlayService(this)
                    }
                    val started = overlayService!!.startOverlay()
                    result.success(started)
                }
                "stopOverlay" -> {
                    val stopped = overlayService?.stopOverlay() ?: true
                    result.success(stopped)
                }
                "updateOverlayData" -> {
                    val cpuUsage = call.argument<Double>("cpuUsage") ?: 0.0
                    val memoryUsage = call.argument<Double>("memoryUsage") ?: 0.0
                    println("DEBUG: MainActivity received overlay data - CPU: $cpuUsage%, Memory: $memoryUsage%")
                    overlayService?.updateData(cpuUsage, memoryUsage)
                    result.success(null)
                }
                "setOverlayPosition" -> {
                    val x = call.argument<Double>("x") ?: 0.0
                    val y = call.argument<Double>("y") ?: 0.0
                    overlayService?.setPosition(x.toFloat(), y.toFloat())
                    result.success(null)
                }
                "toggleOverlayExpanded" -> {
                    overlayService?.toggleExpanded()
                    result.success(null)
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
    }

    private fun getCurrentCpuUsage(): Double {
        return try {
            val cpuTime = Process.getElapsedCpuTime() // milliseconds
            val elapsedTime = SystemClock.elapsedRealtime() // milliseconds
            
            if (elapsedTime > 0) {
                val cpuUsage = (cpuTime * 100.0) / elapsedTime
                val coreCount = Runtime.getRuntime().availableProcessors()
                val normalizedUsage = cpuUsage / coreCount
                return max(0.0, normalizedUsage.coerceAtMost(100.0))
            }
            0.0
        } catch (e: Exception) {
            0.0
        }
    }

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

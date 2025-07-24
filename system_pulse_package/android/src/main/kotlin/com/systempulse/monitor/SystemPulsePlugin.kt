package com.systempulse.monitor

import android.app.ActivityManager
import android.content.Context
import android.os.Process
import android.os.SystemClock
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SystemPulsePlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var performanceChannel: MethodChannel
    private lateinit var overlayChannel: MethodChannel
    private var context: Context? = null
    private var overlayService: OverlayService? = null
    
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        performanceChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "performance_tracker")
        performanceChannel.setMethodCallHandler(this)
        
        overlayChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "floating_overlay")
        overlayChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPerformanceData" -> {
                val cpuUsage = getCurrentCpuUsage()
                val memoryUsage = getCurrentMemoryUsage()
                val performanceData = mapOf(
                    "cpuUsage" to cpuUsage,
                    "memoryUsage" to memoryUsage
                )
                result.success(performanceData)
            }
            "startOverlay" -> {
                if (overlayService == null && context != null) {
                    overlayService = OverlayService(context!!)
                }
                val started = overlayService?.startOverlay() ?: false
                result.success(started)
            }
            "stopOverlay" -> {
                val stopped = overlayService?.stopOverlay() ?: true
                result.success(stopped)
            }
            "updateOverlayData" -> {
                val cpuUsage = call.argument<Double>("cpuUsage") ?: 0.0
                val memoryUsage = call.argument<Double>("memoryUsage") ?: 0.0
                overlayService?.updateData(cpuUsage, memoryUsage)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun getCurrentCpuUsage(): Double {
        return try {
            val cpuTime = Process.getElapsedCpuTime()
            val elapsedTime = SystemClock.elapsedRealtime()
            
            if (elapsedTime > 0) {
                val cpuUsage = (cpuTime.toDouble() / elapsedTime.toDouble()) * 100.0
                kotlin.math.min(100.0, kotlin.math.max(0.0, cpuUsage))
            } else {
                0.0
            }
        } catch (e: Exception) {
            0.0
        }
    }

    private fun getCurrentMemoryUsage(): Double {
        return try {
            val activityManager = context?.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager?.getMemoryInfo(memoryInfo)
            
            val totalMemory = memoryInfo.totalMem
            val availableMemory = memoryInfo.availMem
            val usedMemory = totalMemory - availableMemory
            (usedMemory.toDouble() / totalMemory.toDouble()) * 100.0
        } catch (e: Exception) {
            0.0
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        performanceChannel.setMethodCallHandler(null)
        overlayChannel.setMethodCallHandler(null)
        overlayService?.stopOverlay()
    }
}

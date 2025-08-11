package com.example.cpu_memory_tracking_app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.os.Build
import android.view.*
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

class OverlayService(private val context: Context) {
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var isExpanded = false
    private var cpuUsage = 0.0
    private var memoryUsage = 0.0
    
    private lateinit var cpuText: TextView
    private lateinit var memoryText: TextView

    @SuppressLint("ClickableViewAccessibility")
    fun startOverlay(): Boolean {
        return try {
            if (overlayView != null) return true

            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            
            // Create overlay layout programmatically
            overlayView = createOverlayViewProgrammatically()
            
            // Set up window parameters
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )
            
            params.gravity = Gravity.TOP or Gravity.START
            params.x = 100
            params.y = 200

            // Add touch listener for dragging
            var initialX = 0
            var initialY = 0
            var initialTouchX = 0f
            var initialTouchY = 0f

            overlayView!!.setOnTouchListener { view, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        val deltaX = event.rawX - initialTouchX
                        val deltaY = event.rawY - initialTouchY
                        
                        // If it's just a tap (small movement), toggle expanded state
                        if (Math.abs(deltaX) < 10 && Math.abs(deltaY) < 10) {
                            toggleExpanded()
                        }
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager?.updateViewLayout(overlayView, params)
                        true
                    }
                    else -> false
                }
            }

            windowManager?.addView(overlayView, params)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun stopOverlay(): Boolean {
        return try {
            overlayView?.let { view ->
                windowManager?.removeView(view)
                overlayView = null
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun updateData(cpu: Double, memory: Double) {
        cpuUsage = cpu
        memoryUsage = memory
        
        // println("DEBUG: OverlayService updating data - CPU: $cpu%, Memory: $memory%")
        
        overlayView?.post {
            // Show more precision for CPU since values are very small
            cpuText.text = "CPU: ${String.format("%.2f", cpu)}%"
            memoryText.text = "MEM: ${String.format("%.1f", memory)}%"
            // println("DEBUG: OverlayService UI updated - CPU text: ${cpuText.text}, Memory text: ${memoryText.text}")
        }
    }

    fun setPosition(x: Float, y: Float) {
        overlayView?.let { view ->
            val params = view.layoutParams as WindowManager.LayoutParams
            params.x = x.toInt()
            params.y = y.toInt()
            windowManager?.updateViewLayout(view, params)
        }
    }

    fun toggleExpanded() {
        isExpanded = !isExpanded
        // For now, just update the text to show expanded/collapsed state
        overlayView?.post {
            if (isExpanded) {
                cpuText.text = "CPU: ${String.format("%.1f", cpuUsage)}% [EXPANDED]"
            } else {
                cpuText.text = "CPU: ${String.format("%.1f", cpuUsage)}%"
            }
        }
    }

    private fun createOverlayViewProgrammatically(): View {
        val layout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#E6000000"))
            setPadding(20, 10, 20, 10)
        }

        // Create CPU text
        cpuText = TextView(context).apply {
            text = "CPU: 0.0%"
            setTextColor(Color.WHITE)
            textSize = 12f
        }

        // Create Memory text  
        memoryText = TextView(context).apply {
            text = "MEM: 0.0%"
            setTextColor(Color.WHITE)
            textSize = 12f
        }

        layout.addView(cpuText)
        layout.addView(memoryText)

        return layout
    }
}

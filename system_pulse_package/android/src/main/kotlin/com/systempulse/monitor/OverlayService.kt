package com.systempulse.monitor

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
    private var cpuUsage = 0.0
    private var memoryUsage = 0.0
    
    private lateinit var cpuText: TextView
    private lateinit var memoryText: TextView

    @SuppressLint("ClickableViewAccessibility")
    fun startOverlay(): Boolean {
        return try {
            if (overlayView != null) return true

            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            overlayView = createOverlayView()
            
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
            false
        }
    }

    fun updateData(cpuUsage: Double, memoryUsage: Double) {
        this.cpuUsage = cpuUsage
        this.memoryUsage = memoryUsage
        
        overlayView?.post {
            cpuText.text = "CPU: %.1f%%".format(cpuUsage)
            memoryText.text = "MEM: %.1f%%".format(memoryUsage)
        }
    }

    private fun createOverlayView(): View {
        val layout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 15, 20, 15)
            background = createBackground()
        }

        cpuText = TextView(context).apply {
            text = "CPU: 0.0%"
            textSize = 12f
            setTextColor(Color.WHITE)
        }

        memoryText = TextView(context).apply {
            text = "MEM: 0.0%"
            textSize = 12f
            setTextColor(Color.WHITE)
        }

        layout.addView(cpuText)
        layout.addView(memoryText)
        
        return layout
    }

    private fun createBackground(): android.graphics.drawable.Drawable {
        val shape = android.graphics.drawable.GradientDrawable()
        shape.shape = android.graphics.drawable.GradientDrawable.RECTANGLE
        shape.setColor(Color.parseColor("#AA000000"))
        shape.cornerRadius = 12f
        return shape
    }
}

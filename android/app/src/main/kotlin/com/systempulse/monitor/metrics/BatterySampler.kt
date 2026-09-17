package com.systempulse.monitor.metrics

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager

/**
 * Reads battery level, temperature and charge state from the sticky ACTION_BATTERY_CHANGED
 * broadcast.
 *
 * Registering a null receiver against the sticky intent returns the last broadcast value without
 * subscribing to updates, which is the documented way to poll battery state.
 */
class BatterySampler(private val context: Context) {

    data class Sample(
        val levelPercent: Double,
        val temperatureCelsius: Double,
        val status: String,
        val isCharging: Boolean,
        val available: Boolean,
    )

    fun sample(): Sample {
        val intent: Intent = runCatching {
            context.applicationContext.registerReceiver(
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED),
            )
        }.getOrNull() ?: return unavailable()

        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        // Without a usable level/scale pair there is no battery reading to report. Returning 0%
        // here would be indistinguishable from a genuinely flat battery.
        if (level < 0 || scale <= 0) return unavailable()

        val rawTemperature = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN)
        val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)

        return Sample(
            levelPercent = (level * 100.0 / scale).coerceIn(0.0, 100.0),
            // EXTRA_TEMPERATURE is reported in tenths of a degree Celsius.
            temperatureCelsius = if (rawTemperature == Int.MIN_VALUE) 0.0 else rawTemperature / 10.0,
            status = statusLabel(status),
            isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL ||
                plugged != 0,
            available = true,
        )
    }

    private fun statusLabel(status: Int): String = when (status) {
        BatteryManager.BATTERY_STATUS_CHARGING -> "Charging"
        BatteryManager.BATTERY_STATUS_DISCHARGING -> "Discharging"
        BatteryManager.BATTERY_STATUS_FULL -> "Full"
        BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Not Charging"
        else -> "Unknown"
    }

    private fun unavailable(): Sample =
        Sample(0.0, 0.0, "Unknown", isCharging = false, available = false)
}

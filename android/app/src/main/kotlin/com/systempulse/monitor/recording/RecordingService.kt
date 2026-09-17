package com.systempulse.monitor.recording

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import com.systempulse.monitor.MainActivity
import com.systempulse.monitor.R
import com.systempulse.monitor.metrics.BatterySampler
import com.systempulse.monitor.metrics.MemorySampler
import com.systempulse.monitor.metrics.ProcessCpuSampler
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/**
 * Foreground service that owns the sampling loop for the duration of a recording.
 *
 * The service runs *only while recording*. An earlier version started an always-on foreground
 * service from `MainActivity.onCreate` and stopped it in `onDestroy`, which produced the worst of
 * both worlds: a permanent notification and battery cost even when idle, yet recording that died
 * as soon as the activity went away. Here the lifetime matches the user-visible activity it exists
 * for, which is also what Android's foreground-service policy expects.
 *
 * Sampling happens here rather than in Dart so that it survives the UI being backgrounded, and each
 * sample is appended to disk immediately so a process death costs at most a few seconds of data.
 */
class RecordingService : Service() {

    private val scheduler: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor { runnable ->
        Thread(runnable, "systempulse-sampler").apply { priority = Thread.NORM_PRIORITY - 1 }
    }

    private lateinit var cpuSampler: ProcessCpuSampler
    private lateinit var memorySampler: MemorySampler
    private lateinit var batterySampler: BatterySampler

    private var future: ScheduledFuture<*>? = null
    private var writer: SampleWriter? = null

    private val running = AtomicBoolean(false)
    private val sampleCount = AtomicInteger(0)
    private val latest = AtomicReference<JSONObject?>(null)
    private var sessionId: String = ""
    private var startedAtWallMillis: Long = 0L
    private var startedAtElapsedMillis: Long = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        cpuSampler = ProcessCpuSampler()
        memorySampler = MemorySampler(applicationContext)
        batterySampler = BatterySampler(applicationContext)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                // startForeground() must be called before this method returns, and within a few
                // seconds of startForegroundService(), or the system throws
                // ForegroundServiceDidNotStartInTimeException and kills the process. It is called
                // here rather than inside start() so that the contract is satisfied even when
                // start() bails out early — for instance on a duplicate ACTION_START, or when the
                // session id is missing.
                startInForeground()

                val id = intent.getStringExtra(EXTRA_SESSION_ID).orEmpty()
                val interval = intent.getIntExtra(EXTRA_INTERVAL_SECONDS, DEFAULT_INTERVAL_SECONDS)
                start(id, interval)
            }
            ACTION_STOP -> {
                stop()
                return START_NOT_STICKY
            }
        }
        // Deliberately not START_STICKY: a restarted service would have no session to resume and
        // would begin appending to a recording the user believes has ended. Data already written is
        // recoverable from disk on next launch instead.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopSampling()
        scheduler.shutdownNow()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // The user swiped the app away. Flush what we have so the session is recoverable, then let
        // the service continue: a recording is explicitly user-initiated work.
        writer?.flush()
        super.onTaskRemoved(rootIntent)
    }

    private fun start(id: String, intervalSeconds: Int) {
        if (running.get()) return
        if (id.isEmpty()) {
            // Nothing to record. The service has already entered the foreground above, so it must
            // leave it explicitly rather than just stopping.
            stopForegroundCompat()
            stopSelf()
            return
        }

        sessionId = id
        startedAtWallMillis = System.currentTimeMillis()
        startedAtElapsedMillis = SystemClock.elapsedRealtime()
        sampleCount.set(0)
        latest.set(null)
        cpuSampler.reset()

        writer = SampleWriter(sessionFile(applicationContext, id)).also { it.open() }
        running.set(true)

        // Refresh the notification now that there is a session to describe.
        updateNotification()

        val periodMillis = intervalSeconds.coerceIn(MIN_INTERVAL_SECONDS, MAX_INTERVAL_SECONDS) * 1000L
        // The first sample is scheduled one full period out rather than immediately: CPU
        // utilisation is a rate and the very first reading only primes the counters, so firing it
        // at t=0 would record a guaranteed-meaningless 0% as the session's opening data point.
        future = scheduler.scheduleWithFixedDelay(
            ::takeSample,
            periodMillis,
            periodMillis,
            TimeUnit.MILLISECONDS,
        )
        // Prime the CPU counters now so the first real sample covers a full interval.
        cpuSampler.sample()
    }

    private fun stop() {
        stopSampling()
        stopForegroundCompat()
        stopSelf()
    }

    private fun stopSampling() {
        if (!running.getAndSet(false)) return
        future?.cancel(false)
        future = null
        writer?.close()
        writer = null
    }

    /**
     * Takes one sample and appends it.
     *
     * Runs on the single sampler thread. `scheduleWithFixedDelay` (rather than `AtFixedRate`) means
     * a slow sample delays the next one instead of queueing a burst of catch-up executions, so the
     * loop degrades gracefully under load. Each sample records its own wall-clock timestamp, so a
     * delayed sample is still labelled with the instant it was actually taken.
     */
    private fun takeSample() {
        if (!running.get()) return
        runCatching {
            val cpu = cpuSampler.sample()
            val memory = memorySampler.sample()
            val battery = batterySampler.sample()

            val sample = JSONObject().apply {
                put("t", System.currentTimeMillis())
                put("cpuPercent", cpu.percent)
                put("cpuPerCorePercent", cpu.perCorePercent)
                put("cpuAvailable", cpu.available && !cpu.warmingUp)
                put("deviceMemoryPercent", memory.deviceUsedPercent)
                put("deviceMemoryUsedBytes", memory.deviceUsedBytes)
                put("deviceMemoryTotalBytes", memory.deviceTotalBytes)
                put("deviceLowMemory", memory.deviceLowMemory)
                put("appMemoryBytes", memory.appPssBytes)
                put("memoryAvailable", memory.available)
                put("batteryPercent", battery.levelPercent)
                put("batteryTemperatureC", battery.temperatureCelsius)
                put("batteryStatus", battery.status)
                put("batteryCharging", battery.isCharging)
                put("batteryAvailable", battery.available)
            }

            writer?.append(sample)
            latest.set(sample)
            val count = sampleCount.incrementAndGet()
            if (count % NOTIFICATION_UPDATE_EVERY == 0) updateNotification()
        }
    }

    private fun startInForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification() {
        runCatching {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.notify(NOTIFICATION_ID, buildNotification())
        }
    }

    private fun buildNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, RecordingService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val elapsed = SystemClock.elapsedRealtime() - startedAtElapsedMillis
        val snapshot = latest.get()
        val detail = if (snapshot == null) {
            "Starting…"
        } else {
            val cpu = snapshot.optDouble("cpuPercent", 0.0)
            val memory = snapshot.optDouble("deviceMemoryPercent", 0.0)
            "CPU ${"%.1f".format(cpu)}%  ·  Memory ${"%.0f".format(memory)}%"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Recording  ·  ${formatDuration(elapsed)}")
            .setContentText(detail)
            .setSmallIcon(R.drawable.ic_stat_recording)
            .setContentIntent(contentIntent)
            .addAction(R.drawable.ic_stop, "Stop", stopIntent)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Recording",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while a performance recording is in progress."
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.createNotificationChannel(channel)
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    private fun formatDuration(millis: Long): String {
        val totalSeconds = (millis / 1000L).coerceAtLeast(0L)
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) {
            "%d:%02d:%02d".format(hours, minutes, seconds)
        } else {
            "%d:%02d".format(minutes, seconds)
        }
    }

    companion object {
        const val ACTION_START = "com.systempulse.monitor.action.START_RECORDING"
        const val ACTION_STOP = "com.systempulse.monitor.action.STOP_RECORDING"
        const val EXTRA_SESSION_ID = "sessionId"
        const val EXTRA_INTERVAL_SECONDS = "intervalSeconds"

        const val MIN_INTERVAL_SECONDS = 1
        const val MAX_INTERVAL_SECONDS = 300
        private const val DEFAULT_INTERVAL_SECONDS = 1
        private const val NOTIFICATION_ID = 4711
        private const val CHANNEL_ID = "recording"
        private const val NOTIFICATION_UPDATE_EVERY = 5

        /** Directory holding raw sample streams, shared with the Dart side by convention. */
        fun sessionsDirectory(context: Context): File =
            File(context.filesDir, "sessions").apply { mkdirs() }

        fun sessionFile(context: Context, sessionId: String): File =
            File(sessionsDirectory(context), "$sessionId.jsonl")
    }
}

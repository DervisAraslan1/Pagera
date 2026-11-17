package com.pagera.pagera

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Ön plandaki uygulamayı kullanım istatistiklerinden izler; seçili bir uygulama açılınca
 * Pagera'yı "Reels yerine" ekranıyla öne getirir. "Yine de devam et" denirse o uygulama
 * bir süre serbest kalır.
 */
class InterceptService : Service() {
    companion object {
        const val EXTRA_PKG = "intercept_pkg"
        private const val PREFS = "pagera_intercept"
        private const val CHANNEL = "intercept"
        private const val NOTIF_ID = 77

        fun saveApps(ctx: Context, apps: List<String>) {
            ctx.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putStringSet("apps", apps.toSet()).apply()
        }

        /** Ayarlardaki anahtar. Kapalıyken servis hiçbir koşulda çalışmaz. */
        fun setEnabled(ctx: Context, on: Boolean) {
            ctx.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean("enabled", on).apply()
        }

        fun allowFor(ctx: Context, pkg: String, minutes: Int) {
            ctx.getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                .putLong("allow_$pkg", System.currentTimeMillis() + minutes * 60_000L).apply()
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastForeground: String? = null
    private var lastFired = 0L

    private val tick = object : Runnable {
        override fun run() {
            try {
                check()
            } catch (_: Exception) {
            }
            handler.postDelayed(this, 1500)
        }
    }

    // Pil: ekran kapalıyken kimse uygulama açamaz; izlemeyi tamamen durdur, ekran açılınca sürdür.
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            handler.removeCallbacks(tick)
            if (intent?.action == Intent.ACTION_SCREEN_ON) handler.post(tick)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        registerReceiver(screenReceiver, IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        })
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Reels yerine kitap", NotificationManager.IMPORTANCE_MIN)
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val n: Notification = builder
            .setSmallIcon(R.drawable.ic_stat_pagera)
            .setContentTitle("Pagera nöbette")
            .setContentText("Kaydırmaya başlamadan önce bir sayfa hatırlatırım.")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handler.removeCallbacks(tick)
        // Ayar kapalıysa ya da izlenecek uygulama yoksa (Android yeniden başlatmış olsa bile) hemen kapan.
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false) || prefs.getStringSet("apps", emptySet()).isNullOrEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        if (pm.isInteractive) handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        unregisterReceiver(screenReceiver)
        super.onDestroy()
    }

    private fun foregroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - 15_000, now)
        val e = UsageEvents.Event()
        val resumed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            UsageEvents.Event.ACTIVITY_RESUMED
        } else {
            @Suppress("DEPRECATION")
            UsageEvents.Event.MOVE_TO_FOREGROUND
        }
        var pkg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            if (e.eventType == resumed) pkg = e.packageName
        }
        return pkg ?: lastForeground
    }

    private fun check() {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val apps = prefs.getStringSet("apps", emptySet()) ?: emptySet()
        val fg = foregroundPackage() ?: return
        val changed = fg != lastForeground
        lastForeground = fg
        if (!changed || fg !in apps) return
        val now = System.currentTimeMillis()
        if (prefs.getLong("allow_$fg", 0) > now) return
        if (now - lastFired < 4000) return
        lastFired = now
        val i = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            .putExtra(EXTRA_PKG, fg)
        startActivity(i)
    }
}

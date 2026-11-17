package com.pagera.pagera

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Ana ekran widget'ı: şu an okunan kitap, ilerleme, seri ve günlük hedef.
 * Dokununca Pagera açılır. Veriyi Flutter tarafı "updateWidget" ile yazar; widget kendi başına hiç çalışmaz (pil yemez).
 */
class PageraWidget : AppWidgetProvider() {
    private class Look(val bg: Int, val text: Int, val muted: Int, val accent: Int)

    companion object {
        private const val PREFS = "pagera_widget"

        fun save(ctx: Context, data: Map<String, String>) {
            val e = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            for ((k, v) in data) e.putString(k, v)
            e.apply()
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, PageraWidget::class.java))
            for (id in ids) render(ctx, mgr, id)
        }

        private fun look(theme: String?): Look = when (theme) {
            "mese" -> Look(R.drawable.widget_bg_mese, 0xFF2B2118.toInt(), 0xFF6E5A45.toInt(), 0xFF2F5D46.toInt())
            "lacivert" -> Look(R.drawable.widget_bg_lacivert, 0xFFE8ECF2.toInt(), 0xFF9AA7BA.toInt(), 0xFFD4B06A.toInt())
            else -> Look(R.drawable.widget_bg_gece, 0xFFEFE4D0.toInt(), 0xFFB8A184.toInt(), 0xFFE8A75D.toInt())
        }

        private fun render(ctx: Context, mgr: AppWidgetManager, id: Int) {
            val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val v = RemoteViews(ctx.packageName, R.layout.pagera_widget)
            val l = look(p.getString("theme", "gece"))
            v.setInt(R.id.widget_root, "setBackgroundResource", l.bg)
            v.setTextViewText(R.id.widget_title, p.getString("title", "Rafın seni bekliyor"))
            v.setTextViewText(R.id.widget_progress, p.getString("progress", ""))
            v.setTextViewText(R.id.widget_streak, p.getString("streak", "0 gün"))
            v.setTextViewText(R.id.widget_goal, p.getString("goal", ""))
            v.setTextColor(R.id.widget_label, l.accent)
            v.setTextColor(R.id.widget_title, l.text)
            v.setTextColor(R.id.widget_progress, l.muted)
            v.setTextColor(R.id.widget_streak, l.accent)
            v.setTextColor(R.id.widget_goal, l.muted)
            val open = PendingIntent.getActivity(
                ctx, 1, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            v.setOnClickPendingIntent(R.id.widget_root, open)
            mgr.updateAppWidget(id, v)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }
}

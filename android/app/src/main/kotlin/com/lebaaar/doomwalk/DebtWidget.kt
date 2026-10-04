package com.lebaaar.doomwalk

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widgets. Dart writes display strings into the home_widget
 * plugin's SharedPreferences file and triggers an update; these providers
 * just render them. The system's updatePeriodMillis tick re-renders too.
 */
abstract class DebtWidgetBase(private val layout: Int) : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val p = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        for (id in ids) {
            val v = RemoteViews(context.packageName, layout)
            v.setTextViewText(R.id.w_debt, p.getString("debt_text", "0 m"))
            v.setTextViewText(R.id.w_caption, p.getString("caption_text", "left to scroll"))
            v.setProgressBar(R.id.w_progress, 100, p.getInt("progress", 100), false)
            v.setTextViewText(R.id.w_scrolled, p.getString("scrolled_text", "0 m scrolled today"))
            v.setTextViewText(R.id.w_landmark, p.getString("landmark_text", ""))
            v.setOnClickPendingIntent(R.id.w_root, open)
            manager.updateAppWidget(id, v)
        }
    }
}

class DebtWidgetSmall : DebtWidgetBase(R.layout.widget_small)

class DebtWidgetLarge : DebtWidgetBase(R.layout.widget_large)

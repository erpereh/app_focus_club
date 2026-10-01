package es.focusclub.clientes.app_focus_club

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
    }

    /**
     * Channel used by every customer push. Its id must match
     * `ANDROID_NOTIFICATION_CHANNEL_ID` in web_focus_club
     * (functions/src/notifications/push.ts) and the
     * `default_notification_channel_id` meta-data in the manifest.
     */
    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            DEFAULT_NOTIFICATION_CHANNEL_ID,
            getString(R.string.default_notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.default_notification_channel_description)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val DEFAULT_NOTIFICATION_CHANNEL_ID = "focus_club_default"
    }
}

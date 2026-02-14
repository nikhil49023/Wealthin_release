package com.example.wealthin_flutter

import android.app.Notification
import android.content.ComponentName
import android.content.Intent
import android.os.IBinder
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.text.TextUtils
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Android NotificationListenerService that captures banking / fintech
 * notifications and forwards them to Flutter for transaction parsing.
 *
 * Requires the user to grant "Notification Access" via system Settings (special
 * access, NOT a runtime permission).
 */
class TransactionNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "TxnNotifListener"

        // Known banking / fintech package prefixes we care about
        private val BANK_PACKAGES = setOf(
            // Major Indian banks
            "com.sbi", "com.sbi.lotusintouch",
            "com.csam.icici.bank.imobile",
            "com.hdfc", "com.snapwork.hdfc",
            "com.axis.mobile",
            "com.msf.koenig.bank.kotak",
            "com.csbankapp",
            // UPI / fintech
            "com.google.android.apps.nbu.paisa.user", // GPay
            "net.one97.paytm",
            "com.phonepe.app",
            "com.dreamplug.androidapp", // CRED
            "in.amazon.mShop.android.shopping", // Amazon Pay
            // Add more as needed
        )

        // Fallback: if package isn't in set, check notification text
        private val BANK_CONTENT_PATTERN = Regex(
            "(debited|credited|debit|credit|a/c|acct|avl\\.?\\s*bal|" +
            "avail(?:able)?\\s*bal|txn|transaction|UPI|NEFT|RTGS|IMPS|" +
            "withdrawn|transferred|received|payment\\s+of\\s+rs)",
            RegexOption.IGNORE_CASE
        )

        // EventChannel sink – set by the Flutter side
        @Volatile
        var eventSink: EventChannel.EventSink? = null

        /**
         * Check whether the user has granted Notification Listener access.
         */
        fun isListenerEnabled(context: android.content.Context): Boolean {
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            ) ?: return false
            val myComponent = ComponentName(context, TransactionNotificationListener::class.java)
            return flat.contains(myComponent.flattenToString())
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

        // Use bigText if available (more details), fall back to text
        val body = if (bigText.isNotEmpty()) bigText else text

        if (body.isEmpty()) return

        // Filter: only banking / fintech notifications
        val isKnownBank = BANK_PACKAGES.any { pkg.startsWith(it) }
        val hasFinanceContent = BANK_CONTENT_PATTERN.containsMatchIn(body)

        if (!isKnownBank && !hasFinanceContent) return

        Log.d(TAG, "Banking notification from $pkg: $title | ${body.take(120)}")

        val payload = JSONObject().apply {
            put("title", title)
            put("text", body)
            put("package", pkg)
            put("timestamp", sbn.postTime) // epoch millis
        }

        // Forward to Flutter via EventChannel sink
        try {
            eventSink?.success(payload.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Error sending notification to Flutter: ${e.message}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Not needed for transaction tracking
    }
}

package com.kodetech.mobiboss

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        var onSmsReceived: ((sender: String, body: String, timestamp: Long) -> Unit)? = null
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            try {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (messages.isNullOrEmpty()) return

                val sender = messages[0].originatingAddress ?: ""
                val bodyBuilder = StringBuilder()
                var timestamp = System.currentTimeMillis()

                for (msg in messages) {
                    bodyBuilder.append(msg.messageBody)
                    timestamp = msg.timestampMillis
                }

                val fullBody = bodyBuilder.toString()
                Log.d(TAG, "Incoming SMS captured from '$sender': $fullBody")

                onSmsReceived?.invoke(sender, fullBody, timestamp)
            } catch (e: Exception) {
                Log.e(TAG, "Error in SmsReceiver onReceive", e)
            }
        }
    }
}

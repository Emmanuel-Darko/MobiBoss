package com.kodetech.momo.momo_pos_reconcile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.text.TextUtils
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.kodetech.momo/ussd"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Setup real-time callback from UssdAccessibilityService
        UssdAccessibilityService.onUssdCallback = { rawResponse, isSuccess ->
            runOnUiThread {
                val data = mapOf(
                    "rawResponse" to rawResponse,
                    "isSuccess" to isSuccess,
                    "timestamp" to System.currentTimeMillis()
                )
                methodChannel?.invokeMethod("onUssdTransactionComplete", data)
            }
        }

        // Setup real-time callback from SmsReceiver for incoming carrier SMS
        SmsReceiver.onSmsReceived = { sender, body, timestamp ->
            runOnUiThread {
                val data = mapOf(
                    "sender" to sender,
                    "body" to body,
                    "timestamp" to timestamp
                )
                methodChannel?.invokeMethod("onSmsReceived", data)
            }
        }

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled(this, UssdAccessibilityService::class.java))
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "initiateMultiStepUssd" -> {
                    val rootCode = call.argument<String>("rootCode") ?: "*171#"
                    val steps = call.argument<List<String>>("steps") ?: emptyList()
                    val simSlot = call.argument<Int>("simSlot") ?: 0

                    try {
                        // Queue steps in accessibility service
                        UssdAccessibilityService.startAutomation(steps)

                        // Dial initial root USSD code (e.g., *171#) with SIM slot routing
                        val encoded = Uri.encode(rootCode)
                        val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$encoded"))
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

                        // Dual SIM intent extras for Samsung One UI & Android
                        intent.putExtra("com.android.phone.extra.slot", simSlot)
                        intent.putExtra("simSlot", simSlot)
                        intent.putExtra("android.telephony.extra.SLOT_INDEX", simSlot)
                        intent.putExtra("subscription", simSlot)

                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val encoded = Uri.encode(rootCode)
                            val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$encoded"))
                            dialIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(dialIntent)
                            result.success(false)
                        } catch (e2: Exception) {
                            result.error("USSD_FAILED", e2.message, null)
                        }
                    }
                }
                "initiateUssd" -> {
                    val ussdCode = call.argument<String>("ussdCode")
                    val simSlot = call.argument<Int>("simSlot") ?: 0
                    if (ussdCode != null) {
                        try {
                            val encoded = Uri.encode(ussdCode)
                            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$encoded"))
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

                            intent.putExtra("com.android.phone.extra.slot", simSlot)
                            intent.putExtra("simSlot", simSlot)
                            intent.putExtra("android.telephony.extra.SLOT_INDEX", simSlot)
                            intent.putExtra("subscription", simSlot)

                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val encoded = Uri.encode(ussdCode)
                                val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$encoded"))
                                dialIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(dialIntent)
                                result.success(false)
                            } catch (e2: Exception) {
                                result.error("USSD_FAILED", e2.message, null)
                            }
                        }
                    } else {
                        result.error("INVALID_CODE", "USSD code was null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context, service: Class<*>): Boolean {
        val expectedComponentName = "${context.packageName}/${service.name}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)

        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedComponentName, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}

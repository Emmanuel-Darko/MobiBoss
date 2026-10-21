package com.kodetech.mobiboss

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.text.TextUtils
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.kodetech.mobiboss/ussd"
    private var methodChannel: MethodChannel? = null
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

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
                "hasPhonePermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.CALL_PHONE
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestPhonePermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.CALL_PHONE, Manifest.permission.READ_PHONE_STATE),
                        101
                    )
                    result.success(true)
                }
                "initiateMultiStepUssd" -> {
                    val rootCode = call.argument<String>("rootCode") ?: "*171#"
                    val steps = call.argument<List<String>>("steps") ?: emptyList()
                    val simSlot = call.argument<Int>("simSlot") ?: 0

                    try {
                        // Queue steps in accessibility service
                        UssdAccessibilityService.startAutomation(steps)

                        val hasCallPermission = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.CALL_PHONE
                        ) == PackageManager.PERMISSION_GRANTED

                        if (hasCallPermission) {
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
                        } else {
                            // Request CALL_PHONE runtime permission so subsequent calls auto-dial directly
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.CALL_PHONE, Manifest.permission.READ_PHONE_STATE),
                                101
                            )

                            // Fallback to ACTION_DIAL immediately so user is never blocked
                            val encoded = Uri.encode(rootCode)
                            val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$encoded"))
                            dialIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(dialIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        try {
                            val encoded = Uri.encode(rootCode)
                            val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$encoded"))
                            dialIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(dialIntent)
                            result.success(true)
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
                            val hasCallPermission = ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.CALL_PHONE
                            ) == PackageManager.PERMISSION_GRANTED

                            if (hasCallPermission) {
                                val encoded = Uri.encode(ussdCode)
                                val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$encoded"))
                                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

                                intent.putExtra("com.android.phone.extra.slot", simSlot)
                                intent.putExtra("simSlot", simSlot)
                                intent.putExtra("android.telephony.extra.SLOT_INDEX", simSlot)
                                intent.putExtra("subscription", simSlot)

                                startActivity(intent)
                                result.success(true)
                            } else {
                                ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(Manifest.permission.CALL_PHONE, Manifest.permission.READ_PHONE_STATE),
                                    101
                                )
                                val encoded = Uri.encode(ussdCode)
                                val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$encoded"))
                                dialIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(dialIntent)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            try {
                                val encoded = Uri.encode(ussdCode)
                                val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$encoded"))
                                dialIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(dialIntent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("USSD_FAILED", e2.message, null)
                            }
                        }
                    } else {
                        result.error("INVALID_CODE", "USSD code was null", null)
                    }
                }
                // ==========================================
                // BLUETOOTH THERMAL PRINTER
                // ==========================================
                "isBluetoothEnabled" -> {
                    try {
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        result.success(adapter != null && adapter.isEnabled)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getPairedBluetoothPrinters" -> {
                    try {
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        if (adapter == null || !adapter.isEnabled) {
                            result.success(emptyList<Map<String, Any>>())
                            return@setMethodCallHandler
                        }

                        val bondedDevices: Set<BluetoothDevice>? = adapter.bondedDevices
                        val list = mutableListOf<Map<String, Any>>()
                        bondedDevices?.forEach { device ->
                            list.add(
                                mapOf(
                                    "name" to (device.name ?: "Unknown Printer"),
                                    "address" to device.address
                                )
                            )
                        }
                        result.success(list)
                    } catch (e: Exception) {
                        result.error("BT_ERROR", e.message, null)
                    }
                }
                "printRawEscPos" -> {
                    val address = call.argument<String>("address")
                    val rawBytes = call.argument<ByteArray>("bytes")

                    if (address.isNullOrEmpty() || rawBytes == null) {
                        result.error("INVALID_ARGS", "Device address or bytes was null", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        var socket: BluetoothSocket? = null
                        var outputStream: OutputStream? = null
                        try {
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            val device = adapter.getRemoteDevice(address)
                            adapter.cancelDiscovery()

                            socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                            socket.connect()
                            outputStream = socket.outputStream

                            outputStream.write(rawBytes)
                            outputStream.flush()
                            Thread.sleep(150)

                            runOnUiThread {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("PRINT_FAILED", e.message, null)
                            }
                        } finally {
                            try {
                                outputStream?.close()
                                socket?.close()
                            } catch (_: Exception) {}
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context, service: Class<*>): Boolean {
        // Fast-path: Service is connected and active in memory
        if (UssdAccessibilityService.isServiceEnabled) {
            return true
        }

        val expectedComponentName = "${context.packageName}/${service.name}"
        val shortComponentName = "${context.packageName}/.${service.simpleName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)

        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedComponentName, ignoreCase = true) ||
                componentName.equals(shortComponentName, ignoreCase = true) ||
                componentName.contains(service.simpleName, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}

package com.nbekdev.otter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val robokassaChannelName = "com.nbekdev.otter/robokassa"
    private var robokassaPendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.let(::forwardRuStoreBillingIntent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, robokassaChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startPay" -> {
                        if (robokassaPendingResult != null) {
                            result.error("busy", "Оплата уже запущена", null)
                            return@setMethodCallHandler
                        }
                        val args = call.arguments as? Map<*, *>
                        if (args == null) {
                            result.error("bad_args", "sdk params required", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(this, RobokassaPayActivity::class.java).apply {
                            putExtra(
                                RobokassaPayActivity.EXTRA_MERCHANT_LOGIN,
                                args["merchant_login"] as? String,
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_INVOICE_ID,
                                when (val v = args["invoice_id"]) {
                                    is Int -> v
                                    is Long -> v.toInt()
                                    is Double -> v.toInt()
                                    else -> "$v".toIntOrNull() ?: 0
                                },
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_OUT_SUM,
                                "${args["out_sum"] ?: ""}",
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_DESCRIPTION,
                                args["description"] as? String,
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_SIGNATURE,
                                args["signature_value"] as? String,
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_CULTURE,
                                args["culture"] as? String ?: "ru",
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_ENCODING,
                                args["encoding"] as? String ?: "utf-8",
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_EMAIL,
                                args["email"] as? String,
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_RECEIPT_JSON,
                                RobokassaPayActivity.receiptJsonFromArgs(args),
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_IS_TEST,
                                args["is_test"] as? Boolean ?: false,
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_IS_RECURRING,
                                args["is_recurring"] as? Boolean ?: false,
                            )
                            putExtra(
                                RobokassaPayActivity.EXTRA_PAYMENT_URL,
                                args["payment_url"] as? String,
                            )
                        }
                        robokassaPendingResult = result
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQUEST_ROBOKASSA_PAY)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_ROBOKASSA_PAY) return
        val pending = robokassaPendingResult ?: return
        robokassaPendingResult = null
        val status = data?.getStringExtra(RobokassaPayActivity.EXTRA_RESULT_STATUS)
            ?: if (resultCode == Activity.RESULT_OK) "success" else "cancelled"
        val invoiceId = data?.getIntExtra(RobokassaPayActivity.EXTRA_INVOICE_ID, 0) ?: 0
        val message = data?.getStringExtra(RobokassaPayActivity.EXTRA_RESULT_MESSAGE)
        pending.success(
            mapOf(
                "status" to status,
                "invoice_id" to invoiceId,
                "message" to message,
            ),
        )
    }

    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        forwardRuStoreBillingIntent(intent)
        super.onNewIntent(intent)
    }

    /**
     * flutter_rustore_billing implements NewIntentListener but never registers
     * it, and its onNewIntent rebuilds an uninitialized client. Forward the
     * Pay-return intent to the already-initialized RuStoreBillingClient.
     */
    private fun forwardRuStoreBillingIntent(intent: Intent) {
        val data = intent.dataString ?: return
        if (!isBillingReturn(data)) return
        try {
            @Suppress("UNCHECKED_CAST")
            val pluginClass = Class.forName(
                "ru.rustore.flutter_rustore_billing.FlutterRustoreBillingPlugin",
            ) as Class<out FlutterPlugin>
            val plugin = flutterEngine?.plugins?.get(pluginClass) ?: return
            val wrapperField = pluginClass.getDeclaredField("client")
            wrapperField.isAccessible = true
            val wrapper = wrapperField.get(plugin) ?: return
            val sdkField = wrapper.javaClass.getDeclaredField("client")
            sdkField.isAccessible = true
            val sdkClient = sdkField.get(wrapper) ?: return
            sdkClient.javaClass
                .getMethod("onNewIntent", Intent::class.java)
                .invoke(sdkClient, intent)
            Log.i(TAG, "Forwarded RuStore billing intent")
        } catch (e: Throwable) {
            Log.w(TAG, "RuStore onNewIntent forward failed: ${e.message}")
        }
    }

    private fun isBillingReturn(data: String): Boolean {
        val s = data.lowercase()
        return s.startsWith("com.nbekdev.otter.rustore:") ||
            s.contains("rustore.sdk.billingclient") ||
            s.contains("iamback") ||
            s.contains("paylib_sp=")
    }

    companion object {
        private const val TAG = "OtterRuStore"
        private const val REQUEST_ROBOKASSA_PAY = 7101
    }
}

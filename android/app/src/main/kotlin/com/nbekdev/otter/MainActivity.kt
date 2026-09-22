package com.nbekdev.otter

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.let(::forwardRuStoreBillingIntent)
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
    }
}

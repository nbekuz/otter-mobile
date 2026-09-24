package com.nbekdev.otter

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.util.Log
import android.view.ViewGroup
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import org.json.JSONObject
import java.net.URLEncoder
import java.nio.charset.Charset

/**
 * Pays via Robokassa Index.aspx using backend-pre-signed `sdk` fields.
 * Never recomputes SignatureValue (that causes Robokassa error 29).
 */
class RobokassaPayActivity : Activity() {
    private var finished = false
    private var invoiceId = 0

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        invoiceId = intent.getIntExtra(EXTRA_INVOICE_ID, 0)
        val merchantLogin = intent.getStringExtra(EXTRA_MERCHANT_LOGIN).orEmpty()
        val outSum = intent.getStringExtra(EXTRA_OUT_SUM).orEmpty()
        val description = intent.getStringExtra(EXTRA_DESCRIPTION).orEmpty()
        val signature = intent.getStringExtra(EXTRA_SIGNATURE).orEmpty()
        val culture = intent.getStringExtra(EXTRA_CULTURE) ?: "ru"
        val encoding = intent.getStringExtra(EXTRA_ENCODING) ?: "utf-8"
        val email = intent.getStringExtra(EXTRA_EMAIL)
        val receiptJson = intent.getStringExtra(EXTRA_RECEIPT_JSON)
        val isTest = intent.getBooleanExtra(EXTRA_IS_TEST, false)
        val isRecurring = intent.getBooleanExtra(EXTRA_IS_RECURRING, false)
        val paymentUrl = intent.getStringExtra(EXTRA_PAYMENT_URL)
            ?.takeIf { it.isNotBlank() }
            ?: DEFAULT_PAYMENT_URL

        if (merchantLogin.isBlank() || outSum.isBlank() || signature.isBlank()) {
            finishWith(RESULT_CANCELED, "error", "Некорректные параметры оплаты")
            return
        }

        val webView = WebView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?,
                ): Boolean {
                    val url = request?.url?.toString() ?: return false
                    return handleNav(url)
                }

                @Deprecated("Deprecated in Java")
                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                    return handleNav(url)
                }

                override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                    handleNav(url)
                    super.onPageStarted(view, url, favicon)
                }
            }
        }
        setContentView(webView)

        val body = buildPostBody(
            merchantLogin = merchantLogin,
            outSum = outSum,
            invoiceId = invoiceId,
            description = description,
            signature = signature,
            culture = culture,
            encoding = encoding,
            email = email,
            receiptJson = receiptJson,
            isTest = isTest,
            isRecurring = isRecurring,
        )
        val charset = runCatching { Charset.forName(encoding) }.getOrDefault(Charsets.UTF_8)
        Log.i(TAG, "POST Robokassa invoiceId=$invoiceId (signature from backend)")
        webView.postUrl(paymentUrl, body.toByteArray(charset))
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        finishWith(RESULT_CANCELED, "cancelled", null)
    }

    private fun handleNav(url: String?): Boolean {
        if (url.isNullOrBlank() || finished) return false
        val lower = url.lowercase()
        if (lower.startsWith("robokassa://") ||
            lower.contains("/merchant/state/") ||
            (lower.contains("success") && lower.contains("robokassa")) ||
            lower.contains("ipol.ru/") ||
            lower.contains("ipol.tech/")
        ) {
            // Success/return pages — premium still confirmed via backend poll.
            finishWith(RESULT_OK, "success", null)
            return true
        }
        if (lower.contains("fail") && (lower.contains("robokassa") || lower.contains("merchant"))) {
            finishWith(RESULT_CANCELED, "cancelled", "Оплата не завершена")
            return true
        }
        return false
    }

    private fun finishWith(resultCode: Int, status: String, message: String?) {
        if (finished) return
        finished = true
        setResult(
            resultCode,
            Intent().apply {
                putExtra(EXTRA_RESULT_STATUS, status)
                putExtra(EXTRA_INVOICE_ID, invoiceId)
                if (!message.isNullOrBlank()) putExtra(EXTRA_RESULT_MESSAGE, message)
            },
        )
        finish()
    }

    companion object {
        private const val TAG = "OtterRobokassa"
        const val DEFAULT_PAYMENT_URL = "https://auth.robokassa.ru/Merchant/Index.aspx"

        const val EXTRA_MERCHANT_LOGIN = "merchant_login"
        const val EXTRA_INVOICE_ID = "invoice_id"
        const val EXTRA_OUT_SUM = "out_sum"
        const val EXTRA_DESCRIPTION = "description"
        const val EXTRA_SIGNATURE = "signature_value"
        const val EXTRA_CULTURE = "culture"
        const val EXTRA_ENCODING = "encoding"
        const val EXTRA_EMAIL = "email"
        const val EXTRA_RECEIPT_JSON = "receipt_json"
        const val EXTRA_IS_TEST = "is_test"
        const val EXTRA_IS_RECURRING = "is_recurring"
        const val EXTRA_PAYMENT_URL = "payment_url"
        const val EXTRA_RESULT_STATUS = "status"
        const val EXTRA_RESULT_MESSAGE = "message"

        fun buildPostBody(
            merchantLogin: String,
            outSum: String,
            invoiceId: Int,
            description: String,
            signature: String,
            culture: String,
            encoding: String,
            email: String?,
            receiptJson: String?,
            isTest: Boolean,
            isRecurring: Boolean,
        ): String {
            fun enc(value: String): String =
                URLEncoder.encode(value, encoding).replace("+", "%20")

            val parts = mutableListOf(
                "MerchantLogin=${enc(merchantLogin)}",
                "OutSum=${enc(outSum)}",
                "SignatureValue=${enc(signature)}",
            )
            if (invoiceId > 0) {
                // Official field name is InvId — never InvoiceID.
                parts += "InvId=${enc(invoiceId.toString())}"
            }
            if (description.isNotBlank()) {
                parts += "Description=${enc(description)}"
            }
            if (culture.isNotBlank()) {
                parts += "Culture=${enc(culture)}"
            }
            if (!email.isNullOrBlank()) {
                parts += "Email=${enc(email)}"
            }
            val receipt = receiptJson?.takeIf { it.isNotBlank() }
            if (receipt != null) {
                // Backend already provides JSON; encode once for form body.
                parts += "Receipt=${enc(receipt)}"
            }
            if (isTest) {
                parts += "IsTest=1"
            }
            if (isRecurring) {
                parts += "Recurring=true"
            }
            if (encoding.isNotBlank()) {
                parts += "Encoding=${enc(encoding)}"
            }
            return parts.joinToString("&")
        }

        fun receiptJsonFromArgs(args: Map<*, *>): String? {
            val direct = args["receipt_json"] as? String
            if (!direct.isNullOrBlank()) return direct
            val receipt = args["receipt"] ?: return null
            return when (receipt) {
                is Map<*, *> -> JSONObject(receipt).toString()
                is String -> receipt.takeIf { it.isNotBlank() }
                else -> null
            }
        }
    }
}

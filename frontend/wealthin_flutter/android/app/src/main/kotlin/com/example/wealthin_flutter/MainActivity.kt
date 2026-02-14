package com.example.wealthin_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import android.content.Intent
import android.provider.Settings
import android.util.Log
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "wealthin/python"
    private val SECRETS_CHANNEL = "wealthin/secrets"
    private val NOTIF_CHANNEL = "wealthin/notification_listener"
    private val NOTIF_EVENT_CHANNEL = "wealthin/notification_events"
    private val TAG = "WealthInPython"
    
    // Background executor for Python calls to avoid ANR on main thread
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Python if needed
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(applicationContext))
        }
        
        val py = Python.getInstance()
        val module = py.getModule("flutter_bridge")
        
        // ─── Python method channel ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "callPython" -> {
                    // Extract args on main thread (MethodChannel requirement)
                    val functionName = call.argument<String>("function") ?: ""
                    val args = call.argument<Map<String, Any>>("args") ?: emptyMap()
                    
                    Log.d(TAG, "Dispatching Python function to background: $functionName")
                    
                    // Run Python on background thread to prevent ANR
                    executor.execute {
                        try {
                            val pyResult = when (functionName) {
                                "init_python_backend" -> module.callAttr("init_python_backend")
                                "get_available_tools" -> module.callAttr("get_available_tools")
                                "health_check" -> module.callAttr("health_check")
                                "set_config" -> {
                                    val configJson = args["config_json"] as? String ?: "{}"
                                    module.callAttr("set_config", configJson)
                                }
                                "chat_with_llm" -> {
                                    val query = args["query"] as? String ?: ""
                                    Log.d(TAG, "chat_with_llm query: ${query.take(200)}")
                                    
                                    val historyList = args["conversation_history"]
                                    val historyJson = if (historyList != null) {
                                        try { org.json.JSONArray(historyList as List<*>).toString() } 
                                        catch (e: Exception) { "[]" }
                                    } else "[]"
                                    
                                    val contextMap = args["user_context"]
                                    val contextJson = if (contextMap != null) {
                                        try { org.json.JSONObject(contextMap as Map<*, *>).toString() }
                                        catch (e: Exception) { "{}" }
                                    } else "{}"
                                    
                                    val apiKey = args["api_key"] as? String
                                    
                                    Log.d(TAG, "chat_with_llm history: ${historyJson.take(100)}")
                                    Log.d(TAG, "chat_with_llm context: ${contextJson.take(200)}")
                                    
                                    module.callAttr("chat_with_llm", query, historyJson, contextJson, apiKey)
                                }
                                "brainstorm_chat" -> {
                                    val message = args["message"] as? String ?: ""
                                    Log.d(TAG, "brainstorm_chat: ${message.take(200)}")
                                    
                                    val historyList = args["conversation_history"]
                                    val historyJson = if (historyList != null) {
                                        try { org.json.JSONArray(historyList as List<*>).toString() }
                                        catch (e: Exception) { "[]" }
                                    } else "[]"
                                    
                                    val contextMap = args["user_context"]
                                    val contextJson = if (contextMap != null) {
                                        try { org.json.JSONObject(contextMap as Map<*, *>).toString() }
                                        catch (e: Exception) { "{}" }
                                    } else "{}"
                                    
                                    module.callAttr("chat_with_llm", message, historyJson, contextJson, null)
                                }
                                "parse_bank_statement" -> {
                                    val imageB64 = args["image_b64"] as? String ?: ""
                                    Log.d(TAG, "parse_bank_statement image length: ${imageB64.length}")
                                    module.callAttr("parse_bank_statement", imageB64)
                                }
                                "extract_receipt_from_path" -> {
                                    val filePath = args["file_path"] as? String ?: ""
                                    module.callAttr("extract_receipt_from_path", filePath)
                                }
                                "execute_tool" -> {
                                    val toolName = args["tool_name"] as? String ?: ""
                                    val toolArgs = args["tool_args"] as? Map<*, *> ?: emptyMap<String, Any>()
                                    val toolArgsJson = org.json.JSONObject(toolArgs).toString()
                                    module.callAttr("execute_tool", toolName, toolArgsJson)
                                }
                                "calculate_emi" -> {
                                    val principal = (args["principal"] as? Number)?.toDouble() ?: 0.0
                                    val annualRate = (args["annual_rate"] as? Number)?.toDouble() ?: 0.0
                                    val tenureMonths = (args["tenure_months"] as? Number)?.toInt() ?: 12
                                    module.callAttr("calculate_emi", principal, annualRate, tenureMonths)
                                }
                                "analyze_spending" -> {
                                    val transactionsJson = args["transactions"] as? String ?: "[]"
                                    module.callAttr("analyze_spending", transactionsJson)
                                }
                                "generate_ai_analysis" -> {
                                    val financialDataJson = args["financial_data_json"] as? String ?: "{}"
                                    Log.d(TAG, "generate_ai_analysis data: ${financialDataJson.take(200)}")
                                    module.callAttr("generate_ai_analysis", financialDataJson)
                                }
                                else -> {
                                    Log.d(TAG, "Calling generic function: $functionName")
                                    module.callAttr(functionName)
                                }
                            }
                            
                            // Convert PyObject to String properly
                            val resultString = pyResult?.toString() ?: "{\"success\": false, \"error\": \"No result\"}"
                            Log.d(TAG, "Python result for $functionName: ${resultString.take(500)}")
                            
                            // Return result on main thread (MethodChannel requirement)
                            mainHandler.post { result.success(resultString) }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error calling Python: ${e.message}", e)
                            val errorMsg = e.message?.replace("\"", "'") ?: "Unknown error"
                            mainHandler.post { result.success("{\"success\": false, \"error\": \"$errorMsg\"}") }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ─── Build secret channel ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECRETS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBuildSecrets" -> {
                    val secrets = mutableMapOf<String, String>()
                    if (BuildConfig.SARVAM_API_KEY.isNotBlank()) {
                        secrets["sarvam_api_key"] = BuildConfig.SARVAM_API_KEY
                    }
                    if (BuildConfig.GOV_MSME_API_KEY.isNotBlank()) {
                        secrets["gov_msme_api_key"] = BuildConfig.GOV_MSME_API_KEY
                    }
                    if (BuildConfig.GROQ_API_KEY.isNotBlank()) {
                        secrets["groq_api_key"] = BuildConfig.GROQ_API_KEY
                    }
                    result.success(secrets)
                }
                else -> result.notImplemented()
            }
        }

        // ─── Notification Listener method channel ───────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isListenerEnabled" -> {
                    val enabled = TransactionNotificationListener.isListenerEnabled(applicationContext)
                    result.success(enabled)
                }
                "openListenerSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open listener settings: ${e.message}")
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ─── Notification event stream ──────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    TransactionNotificationListener.eventSink = events
                    Log.d(TAG, "Notification event stream opened")
                }
                override fun onCancel(arguments: Any?) {
                    TransactionNotificationListener.eventSink = null
                    Log.d(TAG, "Notification event stream closed")
                }
            }
        )
    }
}

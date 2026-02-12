package com.example.wealthin_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "wealthin/python"
    private val TAG = "WealthInPython"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Python if needed
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(applicationContext))
        }
        
        val py = Python.getInstance()
        val module = py.getModule("flutter_bridge")
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "callPython" -> {
                    try {
                        val functionName = call.argument<String>("function") ?: ""
                        val args = call.argument<Map<String, Any>>("args") ?: emptyMap()
                        
                        Log.d(TAG, "Calling Python function: $functionName")
                        
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
                                Log.d(TAG, "chat_with_llm query: $query")
                                // Pass all expected parameters
                                module.callAttr("chat_with_llm", query, null, null, null)
                            }
                            "brainstorm_chat" -> {
                                val message = args["message"] as? String ?: ""
                                val persona = args["persona"] as? String ?: "neutral"
                                Log.d(TAG, "brainstorm_chat: $message")
                                module.callAttr("chat_with_llm", message, null, null, null)
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
                                // Convert map to JSON string for Python
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
                            else -> {
                                Log.d(TAG, "Calling generic function: $functionName")
                                module.callAttr(functionName)
                            }
                        }
                        
                        // Convert PyObject to String properly
                        val resultString = pyResult?.toString() ?: "{\"success\": false, \"error\": \"No result\"}"
                        Log.d(TAG, "Python result for $functionName: ${resultString.take(500)}")
                        result.success(resultString)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error calling Python: ${e.message}", e)
                        val errorMsg = e.message?.replace("\"", "'") ?: "Unknown error"
                        result.success("{\"success\": false, \"error\": \"$errorMsg\"}")
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

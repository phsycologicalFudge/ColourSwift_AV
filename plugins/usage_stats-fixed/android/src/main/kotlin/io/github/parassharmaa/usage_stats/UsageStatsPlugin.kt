package io.github.parassharmaa.usage_stats

import android.content.Context
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext


/** UsageStatsPlugin */
public class UsageStatsPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    private var mContext: Context? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "usage_stats")
        channel.setMethodCallHandler(this)
        setContext(flutterPluginBinding.applicationContext)
    }

    private fun setContext(context: Context) {
        this.mContext = context
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "queryEvents" -> {
                var start: Long = call.argument<Long>("start") as Long
                var end: Long = call.argument<Long>("end") as Long
                result.success(UsageStats.queryEvents(mContext!!, start, end))
            }
            "isUsagePermission" -> {
                result.success(Utils.isUsagePermission(mContext!!))
            }
            "grantUsagePermission" -> {
                Utils.grantUsagePermission(mContext!!)
            }
            "queryConfiguration" -> {
                var start: Long = call.argument<Long>("start") as Long
                var end: Long = call.argument<Long>("end") as Long
                result.success(UsageStats.queryConfig(mContext!!, start, end))
            }
            "queryEventStats" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    var start: Long = call.argument<Long>("start") as Long
                    var end: Long = call.argument<Long>("end") as Long
                    result.success(UsageStats.queryEventStats(mContext!!, start, end))
                } else {
                    result.error("API Error",
                        "Requires API Level 28",
                        "Target should be set to 28 to use this API"
                    )
                }
            }
            "queryAndAggregateUsageStats" -> {
                var start: Long = call.argument<Long>("start") as Long
                var end: Long = call.argument<Long>("end") as Long
                result.success(UsageStats.queryAndAggregateUsageStats(mContext!!, start, end))
            }
            "queryUsageStats" -> {
                var start: Long = call.argument<Long>("start") as Long
                var end: Long = call.argument<Long>("end") as Long
                result.success(UsageStats.queryUsageStats(mContext!!, start, end))
            }
            "queryNetworkUsageStats" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val start: Long = call.argument<Long>("start") as Long
                    val end: Long = call.argument<Long>("end") as Long
                    val type: Int = call.argument<Int>("type") as Int

                    GlobalScope.launch(Dispatchers.Main) {
                        val netResult = withContext(Dispatchers.IO) {
                            NetworkStats.queryNetworkUsageStats(
                                context = mContext!!,
                                startDate = start,
                                endDate = end,
                                type = type
                            )
                        }
                        result.success(netResult)
                    }
                } else {
                    result.error(
                        "API Error",
                        "Requires API Level 23",
                        "Target should be set to 23 to use this API"
                    )
                }

            }
            "queryNetworkUsageStatsByPackage" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val start: Long = call.argument<Long>("start") as Long
                    val end: Long = call.argument<Long>("end") as Long
                    val type: Int = call.argument<Int>("type") as Int
                    val packageName: String = call.argument<String>("packageName") as String

                    GlobalScope.launch(Dispatchers.Main) {
                        val netResult = withContext(Dispatchers.IO) {
                            NetworkStats.queryNetworkUsageStatsByPackage(
                                context = mContext!!,
                                startDate = start,
                                endDate = end,
                                type = type,
                                packageName = packageName
                            )
                        }
                        result.success(netResult)
                    }
                } else {
                    result.error(
                        "API Error",
                        "Requires API Level 23",
                        "Target should be set to 23 to use this API"
                    )
                }

            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

package io.github.parassharmaa.usage_stats

import android.app.usage.ConfigurationStats
import android.content.Context
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi

object UsageStats {


    fun queryConfig(context: Context, startDate: Long, endDate: Long): ArrayList<Map<String, String>> {
        var usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        var configs: List<ConfigurationStats> = usm.queryConfigurations(UsageStatsManager.INTERVAL_BEST, startDate, endDate)

        var configList: ArrayList<Map<String, String>> = arrayListOf()

        for (config in configs) {
            var c: Map<String, String> = mapOf(
                    "activationCount" to config.activationCount.toString(),
                    "totalTimeActive" to config.totalTimeActive.toString(),
                    "configuration" to config.configuration.toString(),
                    "lastTimeActive" to config.lastTimeActive.toString(),
                    "firstTimeStamp" to config.firstTimeStamp.toString(),
                    "lastTimeStamp" to config.lastTimeStamp.toString()
            )
            configList.add(c)
        }
        return configList
    }

    fun queryEvents(context: Context, startDate: Long, endDate: Long): ArrayList<Map<String, String>> {
        var usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        var events: UsageEvents = usm.queryEvents(startDate, endDate)
        var eventsList: ArrayList<Map<String, String>> = arrayListOf()

        while (events.hasNextEvent()) {
            var event: UsageEvents.Event = UsageEvents.Event()
            events.getNextEvent(event)
            var e: Map<String, String> = mapOf(
                    "eventType" to event.eventType.toString(),
                    "timeStamp" to event.timeStamp.toString(),
                    "packageName" to event.packageName.toString(),
                    "className" to event.className
            )

            eventsList.add(e)

        }
        return eventsList
    }

    @RequiresApi(Build.VERSION_CODES.P)
    fun queryEventStats(context: Context, startDate: Long, endDate: Long): ArrayList<Map<String, String>> {
        var usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        var eventStats = usm.queryEventStats(UsageStatsManager.INTERVAL_BEST, startDate, endDate)

        var eventList: ArrayList<Map<String, String>> = arrayListOf()

        for (event in eventStats) {
            var u: Map<String, String> = mapOf(
                    "firstTimeStamp" to event.firstTimeStamp.toString(),
                    "lastTimeStamp" to event.lastTimeStamp.toString(),
                    "totalTime" to event.totalTime.toString(),
                    "lastEventTime" to event.lastEventTime.toString(),
                    "eventType" to event.eventType.toString(),
                    "count" to event.count.toString()
            )
            eventList.add(u)
        }
        return eventList
    }

    fun queryUsageStats(context: Context, startDate: Long, endDate: Long): ArrayList<Map<String, String>> {
        var usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        var usageStats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, startDate, endDate)


        var usageList: ArrayList<Map<String, String>> = arrayListOf()

        for (usage in usageStats) {
            var u: Map<String, String> = mapOf(
                    "firstTimeStamp" to usage.firstTimeStamp.toString(),
                    "lastTimeStamp" to usage.lastTimeStamp.toString(),
                    "lastTimeUsed" to usage.lastTimeUsed.toString(),
                    "packageName" to usage.packageName.toString(),
                    "totalTimeInForeground" to usage.totalTimeInForeground.toString()
            )
            usageList.add(u)
        }
        return usageList
    }


    fun queryAndAggregateUsageStats(context: Context, startDate: Long, endDate: Long): Map<String, Map<String, String>> {
        var usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        var usageStats = usm.queryAndAggregateUsageStats(startDate, endDate)

        var usageList = mutableMapOf<String, Map<String, String>>()

        for (packageName in usageStats.keys) {
            var packageUsage = usageStats[packageName]
            usageList[packageName] = mapOf(
                    "firstTimeStamp" to packageUsage?.firstTimeStamp.toString(),
                    "lastTimeStamp" to packageUsage?.lastTimeStamp.toString(),
                    "lastTimeUsed" to packageUsage?.lastTimeUsed.toString(),
                    "packageName" to packageUsage?.packageName.toString(),
                    "totalTimeInForeground" to packageUsage?.totalTimeInForeground.toString()
            )
        }
        return usageList
    }
}
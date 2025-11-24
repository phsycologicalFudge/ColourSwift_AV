import 'dart:async';

import 'src/usage_info.dart';
import 'src/event_info.dart';
import 'src/configuration_info.dart';
import 'src/event_usage_info.dart';
import 'package:flutter/services.dart';

import 'src/network_info.dart';
export 'src/usage_info.dart';
export 'src/event_info.dart';
export 'src/network_info.dart';
export 'src/configuration_info.dart';
export 'src/event_usage_info.dart';

class UsageStats {
  static const MethodChannel _channel = const MethodChannel('usage_stats');

  static Future<bool?> checkUsagePermission() async {
    bool? isPermission = await _channel.invokeMethod('isUsagePermission');
    return isPermission;
  }

  static Future<void> grantUsagePermission() async {
    await _channel.invokeMethod('grantUsagePermission');
  }

  static Future<List<EventUsageInfo>> queryEvents(
      DateTime startDate, DateTime endDate) async {
    int end = endDate.millisecondsSinceEpoch;
    int start = startDate.millisecondsSinceEpoch;
    Map<String, int> interval = {'start': start, 'end': end};
    List events = await _channel.invokeMethod('queryEvents', interval);
    List<EventUsageInfo> result =
        events.map((item) => EventUsageInfo.fromMap(item)).toList();
    return result;
  }

  static Future<List<ConfigurationInfo>> queryConfiguration(
      DateTime startDate, DateTime endDate) async {
    int end = endDate.millisecondsSinceEpoch;
    int start = startDate.millisecondsSinceEpoch;
    Map<String, int> interval = {'start': start, 'end': end};
    List configs = await _channel.invokeMethod('queryConfiguration', interval);
    List<ConfigurationInfo> result =
        configs.map((item) => ConfigurationInfo.fromMap(item)).toList();
    return result;
  }

  static Future<List<EventInfo>> queryEventStats(
      DateTime startDate, DateTime endDate) async {
    int end = endDate.millisecondsSinceEpoch;
    int start = startDate.millisecondsSinceEpoch;
    Map<String, int> interval = {'start': start, 'end': end};
    List eventsStats = await _channel.invokeMethod('queryEventStats', interval);

    List<EventInfo> result =
        eventsStats.map((item) => EventInfo.fromMap(item)).toList();
    return result;
  }

  static Future<List<UsageInfo>> queryUsageStats(
      DateTime startDate, DateTime endDate) async {
    int end = endDate.millisecondsSinceEpoch;
    int start = startDate.millisecondsSinceEpoch;
    Map<String, int> interval = {'start': start, 'end': end};
    List usageStats = await _channel.invokeMethod('queryUsageStats', interval);

    List<UsageInfo> result =
        usageStats.map((item) => UsageInfo.fromMap(item)).toList();
    return result;
  }

  static Future<Map<String, UsageInfo>> queryAndAggregateUsageStats(
      DateTime startDate, DateTime endDate) async {
    int end = endDate.millisecondsSinceEpoch;
    int start = startDate.millisecondsSinceEpoch;
    Map<String, int> interval = {'start': start, 'end': end};
    Map usageAggStats =
        await _channel.invokeMethod('queryAndAggregateUsageStats', interval);
    Map<String, UsageInfo> result = usageAggStats
        .map((key, value) => MapEntry(key as String, UsageInfo.fromMap(value)));
    return result;
  }

  static Future<List<NetworkInfo>> queryNetworkUsageStats(
    DateTime startDate,
    DateTime endDate, {
    NetworkType networkType = NetworkType.all,
  }) async {
    int end = endDate.millisecondsSinceEpoch;
    int start = startDate.millisecondsSinceEpoch;
    Map<String, int> interval = {
      'start': start,
      'end': end,
      'type': networkType.value,
    };
    List events =
        await _channel.invokeMethod('queryNetworkUsageStats', interval);
    List<NetworkInfo> result =
        events.map((item) => NetworkInfo.fromMap(item)).toList();
    return result;
  }

  static Future<NetworkInfo> queryNetworkUsageStatsByPackage(
    DateTime startDate,
    DateTime endDate, {
    required String packageName,
    NetworkType networkType = NetworkType.all,
  }) async {
    int end = endDate.millisecondsSinceEpoch;
    int start = startDate.millisecondsSinceEpoch;
    Map<String, dynamic> interval = {
      'start': start,
      'end': end,
      'type': networkType.value,
      'packageName': packageName,
    };
    Map response = await _channel.invokeMethod(
        'queryNetworkUsageStatsByPackage', interval);
    return NetworkInfo.fromMap(response);
  }
}

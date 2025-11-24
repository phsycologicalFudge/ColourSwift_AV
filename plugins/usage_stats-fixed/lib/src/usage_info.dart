class UsageInfo {
  UsageInfo(
      {this.firstTimeStamp,
      this.lastTimeStamp,
      this.lastTimeUsed,
      this.packageName,
      this.totalTimeInForeground});

  /// Construct class from the json map
  factory UsageInfo.fromMap(Map map) => UsageInfo(
        firstTimeStamp: map['firstTimeStamp'],
        lastTimeStamp: map['lastTimeStamp'],
        lastTimeUsed: map['lastTimeUsed'],
        totalTimeInForeground: map['totalTimeInForeground'],
        packageName: map['packageName'],
      );

  final String? packageName;
  final String? firstTimeStamp;
  final String? lastTimeStamp;
  final String? lastTimeUsed;
  final String? totalTimeInForeground;
}

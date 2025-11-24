class ConfigurationInfo {
  ConfigurationInfo({
    this.activationCount,
    this.totalTimeActive,
    this.configuration,
    this.lastTimeActive,
    this.firstTimeStamp,
    this.lastTimeStamp,
  });

  /// Construct class from the json map
  factory ConfigurationInfo.fromMap(Map map) => ConfigurationInfo(
        activationCount: map['activationCount'],
        totalTimeActive: map['totalTimeActive'],
        configuration: map['configuration'],
        lastTimeActive: map['lastTimeActive'],
        firstTimeStamp: map['firstTimeStamp'],
        lastTimeStamp: map['lastTimeStamp'],
      );

  final String? activationCount;
  final String? totalTimeActive;
  final String? configuration;
  final String? lastTimeActive;
  final String? firstTimeStamp;
  final String? lastTimeStamp;
}

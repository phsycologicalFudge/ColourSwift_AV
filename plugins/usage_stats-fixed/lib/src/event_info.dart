class EventInfo {
  EventInfo(
      {this.firstTimeStamp,
      this.lastTimeStamp,
      this.totalTime,
      this.lastEventTime,
      this.eventType,
      this.count});

  /// Construct class from the json map
  factory EventInfo.fromMap(Map map) => EventInfo(
        firstTimeStamp: map['firstTimeStamp'],
        lastTimeStamp: map['lastTimeStamp'],
        totalTime: map['totalTime'],
        lastEventTime: map['lastEventTime'],
        eventType: map['eventType'],
        count: map['count'],
      );

  final String? firstTimeStamp;
  final String? lastTimeStamp;
  final String? totalTime;
  final String? lastEventTime;
  final String? eventType;
  final String? count;
}

class LogBuffer {
  static final List<String> _messages = [];

  static void add(String msg) {
    final time = DateTime.now().toIso8601String();
    _messages.add('[$time] $msg');
    if (_messages.length > 500) _messages.removeAt(0);
  }

  static List<String> get all => List.unmodifiable(_messages);
  static void clear() => _messages.clear();
}

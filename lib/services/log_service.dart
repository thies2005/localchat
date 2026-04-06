import 'dart:developer' as devtools;

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String tag;
  final String message;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _entries = [];
  static const int _maxEntries = 200;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void _add(String level, String tag, String message,
      {Object? error, StackTrace? stackTrace}) {
    _entries.add(LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    ));
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    devtools.log(message, name: tag, error: error, stackTrace: stackTrace);
  }

  void info(String tag, String message) => _add('INFO', tag, message);

  void warning(String tag, String message) => _add('WARN', tag, message);

  void error(String tag, String message,
      {Object? error, StackTrace? stackTrace}) {
    _add('ERROR', tag, message, error: error, stackTrace: stackTrace);
  }

  String getFullLog() {
    final buffer = StringBuffer();
    buffer.writeln('=== LocalChat Log ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Entries: ${_entries.length}');
    buffer.writeln();
    for (final entry in _entries) {
      buffer.writeln(
          '[${entry.timestamp.toIso8601String()}] [${entry.level}] [${entry.tag}] ${entry.message}');
      if (entry.error != null) {
        buffer.writeln('  ERROR: ${entry.error}');
      }
      if (entry.stackTrace != null) {
        buffer.writeln('  STACK: ${entry.stackTrace}');
      }
    }
    return buffer.toString();
  }

  void clear() => _entries.clear();
}

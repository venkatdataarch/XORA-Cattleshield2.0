import 'package:flutter/foundation.dart';

class AppLogger {
  final String _tag;

  const AppLogger(this._tag);

  void info(String message, [Object? data]) {
    _log('INFO', message, data);
  }

  void warning(String message, [Object? data]) {
    _log('WARN', message, data);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message, error);
    if (stackTrace != null) {
      debugPrint('[$_tag] STACK: $stackTrace');
    }
  }

  void debug(String message, [Object? data]) {
    _log('DEBUG', message, data);
  }

  void _log(String level, String message, [Object? data]) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final logMessage = '[$timestamp][$level][$_tag] $message';
    debugPrint(logMessage);
    if (data != null) {
      debugPrint('[$_tag] DATA: $data');
    }
  }
}

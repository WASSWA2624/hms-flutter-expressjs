import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_template/core/config/app_config.dart';

typedef AppLogSink = void Function(AppLogRecord record);

final class AppLogRecord {
  const AppLogRecord({
    required this.level,
    required this.message,
    this.context = const <String, Object?>{},
    this.errorType,
    this.stackTrace,
  });

  final AppLogLevel level;
  final String message;
  final Map<String, Object?> context;
  final String? errorType;
  final StackTrace? stackTrace;

  String get formattedMessage {
    final details = <String>[
      if (errorType != null) 'errorType=$errorType',
      for (final entry in context.entries) '${entry.key}=${entry.value}',
    ];

    if (details.isEmpty) {
      return message;
    }

    return '$message ${details.join(' ')}';
  }
}

final class SafeLoggedException implements Exception {
  const SafeLoggedException(this.errorType);

  final String errorType;

  @override
  String toString() {
    return errorType;
  }
}

abstract final class AppLogger {
  static AppLogLevel _minimumLevel = AppLogLevel.info;
  static AppLogSink _sink = _developerLogSink;

  static void initialize(AppLogLevel minimumLevel, {AppLogSink? sink}) {
    _minimumLevel = minimumLevel;
    _sink = sink ?? _developerLogSink;
  }

  static void debug(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    _log(AppLogLevel.debug, message, context: context);
  }

  static void info(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    _log(AppLogLevel.info, message, context: context);
  }

  static void warning(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    _log(AppLogLevel.warn, message, context: context);
  }

  static void error(
    String message,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const <String, Object?>{},
    bool reportToFlutter = true,
  }) {
    if (!_shouldLog(AppLogLevel.error)) {
      return;
    }

    final record = AppLogRecord(
      level: AppLogLevel.error,
      message: _sanitizeText(message),
      context: _safeContext(context),
      errorType: error.runtimeType.toString(),
      stackTrace: stackTrace,
    );

    _sink(record);

    if (!reportToFlutter) {
      return;
    }

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: SafeLoggedException(record.errorType ?? 'Error'),
        stack: stackTrace,
        library: 'flutter_template',
        context: ErrorDescription(record.message),
      ),
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _minimumLevel = AppLogLevel.info;
    _sink = _developerLogSink;
  }

  static void _log(
    AppLogLevel level,
    String message, {
    required Map<String, Object?> context,
  }) {
    if (!_shouldLog(level)) {
      return;
    }

    _sink(
      AppLogRecord(
        level: level,
        message: _sanitizeText(message),
        context: _safeContext(context),
      ),
    );
  }

  static bool _shouldLog(AppLogLevel level) {
    return _priority(level) >= _priority(_minimumLevel);
  }

  static int _priority(AppLogLevel level) {
    return switch (level) {
      AppLogLevel.debug => 0,
      AppLogLevel.info => 1,
      AppLogLevel.warn => 2,
      AppLogLevel.error => 3,
    };
  }

  static int _developerLevel(AppLogLevel level) {
    return switch (level) {
      AppLogLevel.debug => 500,
      AppLogLevel.info => 800,
      AppLogLevel.warn => 900,
      AppLogLevel.error => 1000,
    };
  }

  static void _developerLogSink(AppLogRecord record) {
    developer.log(
      record.formattedMessage,
      level: _developerLevel(record.level),
      error: record.errorType == null
          ? null
          : SafeLoggedException(record.errorType!),
      stackTrace: record.stackTrace,
      name: 'flutter_template',
    );
  }

  static Map<String, Object?> _safeContext(Map<String, Object?> context) {
    if (context.isEmpty) {
      return const <String, Object?>{};
    }

    final safeContext = <String, Object?>{};

    for (final entry in context.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }

      safeContext[key] = _isSensitiveKey(key)
          ? '<redacted>'
          : _safeValue(entry.value);
    }

    return Map<String, Object?>.unmodifiable(safeContext);
  }

  static Object? _safeValue(Object? value) {
    if (value == null || value is num || value is bool) {
      return value;
    }

    if (value is Enum) {
      return value.name;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Duration) {
      return value.toString();
    }

    if (value is Uri) {
      return value.path.isEmpty ? '/' : value.path;
    }

    if (value is String) {
      return _sanitizeText(value);
    }

    return value.runtimeType.toString();
  }

  static String _sanitizeText(String value) {
    final sanitizedValue = value.replaceAllMapped(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      (match) {
        final matchedText = match.group(0)!;
        final suffix = RegExp(r'[.,;:!?)]$').hasMatch(matchedText)
            ? matchedText.substring(matchedText.length - 1)
            : '';

        return 'Bearer <redacted>$suffix';
      },
    );

    if (_looksSensitive(sanitizedValue)) {
      return '<redacted>';
    }

    const maxLength = 240;
    if (sanitizedValue.length <= maxLength) {
      return sanitizedValue;
    }

    return '${sanitizedValue.substring(0, maxLength)}...';
  }

  static bool _isSensitiveKey(String key) {
    return RegExp(
      'authorization|password|token|secret|cookie|credential|api_key|apikey|'
      'session',
      caseSensitive: false,
    ).hasMatch(key);
  }

  static bool _looksSensitive(String value) {
    final lowerValue = value.toLowerCase();

    return lowerValue.contains('password=') ||
        lowerValue.contains('token=') ||
        lowerValue.contains('secret=') ||
        lowerValue.contains('authorization=');
  }
}

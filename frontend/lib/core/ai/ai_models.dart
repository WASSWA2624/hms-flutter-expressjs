import 'package:hosspi_hms/core/network/api_response.dart';

final class AiStatus {
  const AiStatus({
    required this.enabled,
    required this.provider,
    required this.model,
    required this.ready,
  });

  factory AiStatus.fromJson(JsonMap json) {
    return AiStatus(
      enabled: json['enabled'] == true,
      provider: _string(json['provider']),
      model: _string(json['model']),
      ready: json['ready'] == true,
    );
  }

  final bool enabled;
  final String provider;
  final String model;
  final bool ready;

  bool get isAvailable => enabled && ready;
}

final class AiTaskResult {
  const AiTaskResult({
    required this.taskKey,
    required this.output,
    required this.degraded,
    this.model,
    this.provider,
  });

  factory AiTaskResult.fromJson(JsonMap json) {
    final Object? outputValue = json['output'];
    return AiTaskResult(
      taskKey: _string(json['task_key']),
      output: outputValue is Map
          ? Map<String, Object?>.from(outputValue)
          : const <String, Object?>{},
      degraded: json['degraded'] == true,
      model: _nullableString(json['model']),
      provider: _nullableString(json['provider']),
    );
  }

  final String taskKey;
  final Map<String, Object?> output;
  final bool degraded;
  final String? model;
  final String? provider;

  String? get formattedText {
    final Object? value = output['formatted_text'];
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

String _string(Object? value) => value is String ? value.trim() : '';

String? _nullableString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

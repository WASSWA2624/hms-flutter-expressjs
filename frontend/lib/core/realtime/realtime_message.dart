import 'dart:convert';

final class RealtimeMessage {
  const RealtimeMessage({
    required this.event,
    this.payload = const <String, Object?>{},
  });

  final String event;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return <String, Object?>{'event': event, 'payload': payload};
  }

  static RealtimeMessage? tryDecode(Object? value) {
    final String? text = switch (value) {
      final String source => source,
      final List<int> bytes => utf8.decode(bytes),
      _ => null,
    };
    if (text == null || text.trim().isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(text) as Object?;
      if (decoded is! Map<String, Object?>) {
        return null;
      }

      final Object? event = decoded['event'];
      if (event is! String || event.trim().isEmpty) {
        return null;
      }

      return RealtimeMessage(
        event: event,
        payload: _mapFrom(decoded['payload']),
      );
    } on FormatException {
      return null;
    }
  }

  static Map<String, Object?> _mapFrom(Object? value) {
    if (value is Map<String, Object?>) {
      return Map<String, Object?>.unmodifiable(value);
    }
    if (value is Map<Object?, Object?>) {
      final entries = value.entries
          .where((MapEntry<Object?, Object?> entry) => entry.key != null)
          .map(
            (MapEntry<Object?, Object?> entry) =>
                MapEntry<String, Object?>(entry.key.toString(), entry.value),
          );
      return Map<String, Object?>.unmodifiable(
        Map<String, Object?>.fromEntries(entries),
      );
    }
    return const <String, Object?>{};
  }
}

import 'dart:convert';

enum SyncQueueOperation { create, update, delete, upload }

enum SyncQueueStatus { pending, syncing, synced, failed, conflict }

final class SyncQueuePayload {
  factory SyncQueuePayload.fromJsonString(String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Payload JSON is required.');
    }

    jsonDecode(normalizedValue);

    return SyncQueuePayload._(normalizedValue);
  }

  factory SyncQueuePayload.fromMap(Map<String, Object?> value) {
    return SyncQueuePayload.fromJsonString(jsonEncode(value));
  }

  const SyncQueuePayload._(this.value);

  final String value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SyncQueuePayload && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class SyncQueueEnqueueRequest {
  factory SyncQueueEnqueueRequest({
    required String localId,
    required SyncQueueOperation operation,
    required SyncQueuePayload payload,
  }) {
    final normalizedLocalId = localId.trim();
    if (normalizedLocalId.isEmpty) {
      throw ArgumentError.value(localId, 'localId', 'Local id is required.');
    }

    return SyncQueueEnqueueRequest._(
      localId: normalizedLocalId,
      operation: operation,
      payload: payload,
    );
  }

  const SyncQueueEnqueueRequest._({
    required this.localId,
    required this.operation,
    required this.payload,
  });

  final String localId;
  final SyncQueueOperation operation;
  final SyncQueuePayload payload;
}

final class SyncQueueEntry {
  const SyncQueueEntry({
    required this.localId,
    required this.operation,
    required this.payload,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastAttemptAt,
    this.failureCode,
  });

  final String localId;
  final SyncQueueOperation operation;
  final SyncQueuePayload payload;
  final SyncQueueStatus status;
  final int retryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAttemptAt;
  final String? failureCode;

  bool get canRetry {
    return status == SyncQueueStatus.pending ||
        status == SyncQueueStatus.failed;
  }
}

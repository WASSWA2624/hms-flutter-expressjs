import 'dart:math';

import 'package:dio/dio.dart';

/// HTTP header recognized by the backend offline/idempotency middleware.
const String idempotencyHeaderName = 'Idempotency-Key';

/// Creates a new opaque idempotency key for a single logical mutation attempt.
///
/// Retries of the same logical mutation must reuse the same key (see
/// [AppActionRunner]). A new logical action must call this again.
String createIdempotencyKey([Random? random]) {
  final Random rng = random ?? Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  // UUID version 4 variant bits (RFC 4122 shape; not a crypto claim).
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

/// Builds Dio [Options] that attach an [Idempotency-Key] header.
Options idempotentRequestOptions({
  required String idempotencyKey,
  Map<String, dynamic>? headers,
  Map<String, dynamic>? extra,
}) {
  final String key = idempotencyKey.trim();
  assert(key.isNotEmpty, 'Idempotency key must not be empty.');
  return Options(
    headers: <String, dynamic>{
      ...?headers,
      idempotencyHeaderName: key,
    },
    extra: extra == null ? null : <String, dynamic>{...extra},
  );
}

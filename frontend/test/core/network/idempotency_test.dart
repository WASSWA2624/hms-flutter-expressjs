import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/network/idempotency.dart';

void main() {
  group('createIdempotencyKey', () {
    test('returns a UUID-shaped opaque key', () {
      final String key = createIdempotencyKey(Random(1));
      expect(
        key,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('produces distinct keys for successive calls', () {
      final Random random = Random(42);
      final String first = createIdempotencyKey(random);
      final String second = createIdempotencyKey(random);
      expect(first, isNot(equals(second)));
    });
  });

  group('idempotentRequestOptions', () {
    test('attaches Idempotency-Key header', () {
      final options = idempotentRequestOptions(idempotencyKey: 'demo-key-1');
      expect(options.headers?[idempotencyHeaderName], 'demo-key-1');
    });
  });
}

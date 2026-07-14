import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/network/idempotency.dart';

void main() {
  group('OPD front-desk idempotency helpers', () {
    test('createIdempotencyKey returns opaque UUID-shaped values', () {
      final String first = createIdempotencyKey();
      final String second = createIdempotencyKey();

      expect(first, isNot(equals(second)));
      expect(first.split('-'), hasLength(5));
      expect(idempotentRequestOptions(idempotencyKey: first).headers, {
        idempotencyHeaderName: first,
      });
    });
  });
}

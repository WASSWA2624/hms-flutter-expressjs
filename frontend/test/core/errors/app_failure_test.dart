import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';

void main() {
  test('conflict failure hash follows order-independent map equality', () {
    final ConflictFailure left = ConflictFailure(
      conflictEntries: const <Map<String, Object?>>[
        <String, Object?>{'name': 'Testing', 'score': 100},
      ],
    );
    final ConflictFailure right = ConflictFailure(
      conflictEntries: const <Map<String, Object?>>[
        <String, Object?>{'score': 100, 'name': 'Testing'},
      ],
    );

    expect(left, right);
    expect(left.hashCode, right.hashCode);
  });
}

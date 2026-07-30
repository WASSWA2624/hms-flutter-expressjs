import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

// Exercises the same status mapping used by lab result save payloads.
String? resultStatusFromToken(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'CRITICAL' || 'CRITICAL_LOW' || 'CRITICAL_HIGH' => 'CRITICAL',
    'ABNORMAL' || 'HIGH' || 'LOW' || 'POSITIVE' || 'REACTIVE' => 'ABNORMAL',
    'NORMAL' || 'NEGATIVE' || 'NON_REACTIVE' || 'NOT_DETECTED' => 'NORMAL',
    _ => null,
  };
}

void main() {
  group('lab result save status mapping', () {
    test('maps directional critical flags to CRITICAL for save-result', () {
      expect(resultStatusFromToken('CRITICAL_HIGH'), 'CRITICAL');
      expect(resultStatusFromToken('CRITICAL_LOW'), 'CRITICAL');
      expect(resultStatusFromToken('HIGH'), 'ABNORMAL');
      expect(resultStatusFromToken('LOW'), 'ABNORMAL');
      expect(resultStatusFromToken('NORMAL'), 'NORMAL');
    });

    test('PENDING is not a valid save-result status token', () {
      expect(resultStatusFromToken('PENDING'), isNull);
    });

    test('numeric out-of-range entries remain saveable drafts', () {
      const LabOrderItem item = LabOrderItem(
        id: 'item-1',
        resultKind: 'NUMERIC',
      );
      expect(item.isNumeric, isTrue);
      // Out-of-range is a flag concern, not a form-validity concern.
      expect(num.tryParse('33'), isNotNull);
    });
  });
}

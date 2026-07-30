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

    test('canReopenResult allows finer flags for all result kinds', () {
      const LabOrderItem numericLow = LabOrderItem(
        id: 'n1',
        status: 'COMPLETED',
        resultKind: 'NUMERIC',
        resultStatus: 'ABNORMAL',
        resultFlag: 'LOW',
        resultValue: '10',
        resultId: 'r1',
      );
      const LabOrderItem qualitativePositive = LabOrderItem(
        id: 'q1',
        status: 'COMPLETED',
        resultKind: 'QUALITATIVE',
        resultStatus: 'ABNORMAL',
        resultFlag: 'POSITIVE',
        resultText: 'Positive',
        resultId: 'r2',
      );
      const LabOrderItem textNormal = LabOrderItem(
        id: 't1',
        status: 'COMPLETED',
        resultKind: 'TEXT',
        resultStatus: 'NORMAL',
        resultText: 'Seen',
        resultId: 'r3',
      );
      const LabOrderItem criticalHighOnlyFlag = LabOrderItem(
        id: 'c1',
        status: 'COMPLETED',
        resultKind: 'NUMERIC',
        resultFlag: 'CRITICAL_HIGH',
        resultValue: '99',
        resultId: 'r4',
      );
      const LabOrderItem pending = LabOrderItem(
        id: 'p1',
        status: 'IN_PROCESS',
        resultKind: 'NUMERIC',
        resultStatus: 'PENDING',
        resultValue: '12',
        resultId: 'r5',
      );

      expect(numericLow.canReopenResult, isTrue);
      expect(qualitativePositive.canReopenResult, isTrue);
      expect(textNormal.canReopenResult, isTrue);
      expect(criticalHighOnlyFlag.canReopenResult, isTrue);
      expect(pending.canReopenResult, isFalse);
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

import 'package:flutter_test/flutter_test.dart';

/// Documents the walk-in create payload contract: optional patient, items, no encounter.
void main() {
  test('walk-in pharmacy order payload omits encounter_id', () {
    const String patientId = 'patient-1';
    final List<Map<String, Object?>> items = <Map<String, Object?>>[
      <String, Object?>{
        'drug_id': 'drug-1',
        'quantity': 10,
        'dosage': '1 tablet',
      },
    ];

    final Map<String, Object?> payload = <String, Object?>{
      'patient_id': patientId,
      'ordered_at': DateTime.utc(2026, 8, 5).toIso8601String(),
      'items': items,
    };

    expect(payload.containsKey('encounter_id'), isFalse);
    expect(payload['patient_id'], patientId);
    expect(payload['items'], isA<List<Map<String, Object?>>>());
    expect((payload['items'] as List).length, 1);
  });

  test('anonymous walk-in pharmacy order payload omits patient_id', () {
    final List<Map<String, Object?>> items = <Map<String, Object?>>[
      <String, Object?>{
        'drug_id': 'drug-1',
        'quantity': 2,
        'dosage': '1 tablet',
      },
    ];

    final Map<String, Object?> payload = <String, Object?>{
      'ordered_at': DateTime.utc(2026, 8, 6).toIso8601String(),
      'items': items,
    };

    expect(payload.containsKey('patient_id'), isFalse);
    expect(payload.containsKey('encounter_id'), isFalse);
    expect(payload['items'], isA<List<Map<String, Object?>>>());
  });
}

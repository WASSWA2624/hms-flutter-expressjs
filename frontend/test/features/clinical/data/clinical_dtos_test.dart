import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/clinical/data/dtos/clinical_dtos.dart';

void main() {
  group('decodeRelatedRecords', () {
    test('keeps lab order items when backend hides internal item ids', () {
      final records = decodeRelatedRecords(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'LAB0000004',
            'status': 'ORDERED',
            'item_count': 1,
            'items': <Object?>[
              <String, Object?>{
                'id': null,
                'display_id': null,
                'status': 'ORDERED',
                'result_status': null,
                'lab_test_id': 'LBT-4444A9E204',
                'test_display_name': 'Lactate',
                'test_code': 'LACT',
                'category': 'Critical Care',
                'specimen_type': 'Whole blood / Plasma',
                'unit': 'mmol/L',
              },
            ],
          },
        ],
      }, 'lab_order');

      expect(records, hasLength(1));
      expect(records.single.labOrderItems, hasLength(1));
      expect(records.single.labOrderItems.single.id, 'LBT-4444A9E204');
      expect(
        records.single.labOrderItems.single.displayTitle,
        'Lactate | LACT',
      );
      expect(records.single.labOrderItems.single.status, 'ORDERED');
    });

    test('maps lab requested tests fallback into visible order items', () {
      final records = decodeRelatedRecords(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'LAB0000005',
            'status': 'ORDERED',
            'requested_tests': <Object?>[
              <String, Object?>{
                'lab_test_id': 'LBT-CBC',
                'test_display_name': 'Complete blood count',
                'test_code': 'CBC',
              },
            ],
          },
        ],
      }, 'lab_order');

      expect(records, hasLength(1));
      expect(records.single.labOrderItems, hasLength(1));
      expect(records.single.labOrderItems.single.labTestId, 'LBT-CBC');
      expect(
        records.single.labOrderItems.single.displayTitle,
        'Complete blood count | CBC',
      );
    });

    test('maps radiology item request details and nested catalog fields', () {
      final records = decodeRelatedRecords(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'RAD0000001',
            'status': 'ORDERED',
            'requested_tests': <Object?>[
              <String, Object?>{
                'id': 'RADITEM0001',
                'radiology_test_id': 'RDT-CTHEAD',
                'request_details': <String, Object?>{
                  'modality': 'CT',
                  'body_region': 'Head',
                  'laterality': 'LEFT',
                  'priority': 'URGENT',
                  'clinical_note': 'Headache after fall',
                },
                'radiology_test': <String, Object?>{
                  'name': 'CT Head',
                  'modality': 'CT',
                  'body_region': 'Head',
                },
              },
            ],
          },
        ],
      }, 'radiology_order');

      expect(records, hasLength(1));
      expect(records.single.radiologyOrderItems, hasLength(1));
      final item = records.single.radiologyOrderItems.single;
      expect(item.displayTitle, 'CT Head');
      expect(item.modality, 'CT');
      expect(item.bodyRegion, 'Head');
      expect(item.laterality, 'LEFT');
      expect(item.priority, 'URGENT');
      expect(item.clinicalNote, 'Headache after fall');
    });

    test('maps pharmacy order_items fallback into readable medication items', () {
      final records = decodeRelatedRecords(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'PHARM0000001',
            'status': 'ORDERED',
            'order_items': <Object?>[
              <String, Object?>{
                'id': 'PHARMITEM0001',
                'drug': <String, Object?>{'name': 'Amoxicillin'},
                'dosage': '500 mg',
                'route': 'ORAL',
                'frequency': 'TID',
                'duration_value': 5,
                'duration_unit': 'DAYS',
                'quantity': 15,
                'instructions': 'Take after meals',
              },
            ],
          },
        ],
      }, 'pharmacy_order');

      expect(records, hasLength(1));
      expect(records.single.pharmacyOrderItems, hasLength(1));
      final item = records.single.pharmacyOrderItems.single;
      expect(item.displayTitle, 'Amoxicillin');
      expect(item.dosage, '500 mg');
      expect(item.route, 'ORAL');
      expect(item.frequency, 'TID');
      expect(item.durationValue, '5');
      expect(item.durationUnit, 'DAYS');
      expect(item.quantity, '15');
      expect(item.instructions, 'Take after meals');
    });
  });
}

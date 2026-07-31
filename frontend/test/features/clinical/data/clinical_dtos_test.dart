import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/clinical/data/dtos/clinical_dtos.dart';

void main() {
  group('decodeRelatedRecords', () {
    test('prefers diagnosis UUID over human_friendly_id for mutations', () {
      final records = decodeRelatedRecords(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
            'human_friendly_id': 'DX0000042',
            'description': 'Malaria',
            'diagnosis_type': 'PRIMARY',
            'code': 'B54',
            'status': 'ACTIVE',
          },
        ],
      }, 'diagnosis');

      expect(records, hasLength(1));
      expect(records.single.id, 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee');
      expect(records.single.title, 'Malaria');
      expect(records.single.diagnosisType, 'PRIMARY');
      expect(records.single.code, 'B54');
    });

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

    test('maps payment_status from clinical-request-billing fields', () {
      final records = decodeRelatedRecords(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'LAB-PAY-1',
            'status': 'ORDERED',
            'payment_status': 'PENDING',
            'items': <Object?>[],
          },
          <String, Object?>{
            'id': 'RAD-PAY-1',
            'status': 'ORDERED',
            'billing': <String, Object?>{'payment_status': 'PAID'},
            'requested_tests': <Object?>[],
          },
        ],
      }, 'lab_order');

      expect(records.first.paymentStatus, 'PENDING');

      final radiology = decodeRelatedRecords(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'RAD-PAY-1',
            'status': 'ORDERED',
            'billing_snapshot': <String, Object?>{'payment_status': 'PARTIAL'},
            'requested_tests': <Object?>[],
          },
        ],
      }, 'radiology_order');
      expect(radiology.single.paymentStatus, 'PARTIAL');
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

    test(
      'maps pharmacy order_items fallback into readable medication items',
      () {
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
      },
    );

    test('maps lab result value and text fields', () {
      final records = decodeRelatedRecords(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'LAB0000006',
            'status': 'COMPLETED',
            'items': <Object?>[
              <String, Object?>{
                'id': 'ITEM-1',
                'status': 'COMPLETED',
                'result_status': 'NORMAL',
                'result_value': '5.2',
                'result_text': 'Positive',
                'result_flag': 'HIGH',
                'result_unit': 'mg/L',
                'reference_range_summary': 'Adult | ≤ 5 mg/L',
                'panel_display_name': 'Abdominal Pain Panel',
                'panel_code': 'ABDP',
                'panel_id': 'PANEL-1',
                'test_display_name': 'Glucose',
              },
            ],
          },
        ],
      }, 'lab_order');

      final item = records.single.labOrderItems.single;
      expect(item.resultValue, '5.2');
      expect(item.resultText, 'Positive');
      expect(item.resultStatus, 'NORMAL');
      expect(item.resultFlag, 'HIGH');
      expect(item.resultUnit, 'mg/L');
      expect(item.referenceRangeSummary, 'Adult | ≤ 5 mg/L');
      expect(item.panelDisplayName, 'Abdominal Pain Panel');
      expect(item.panelCode, 'ABDP');
      expect(records.single.title, 'Abdominal Pain Panel | ABDP');
    });
  });

  group('decodeClinicalTermOptions', () {
    test(
      'maps catalog unit price and currency from clinical catalog search',
      () {
        final options = decodeClinicalTermOptions(<String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'LBT-BMP',
              'item_id': 'uuid-bmp',
              'term_type': 'LAB_TEST',
              'code': 'BMP',
              'name': 'Basic Metabolic Panel',
              'description': 'Basic Metabolic Panel',
              'category': 'CHEMISTRY',
              'source': 'GLOBAL',
              'unit_price': 18000,
              'currency': 'UGX',
            },
          ],
        });

        expect(options, hasLength(1));
        expect(options.single.apiId, 'LBT-BMP');
        expect(options.single.id, 'uuid-bmp');
        expect(options.single.unitPrice, 18000);
        expect(options.single.currency, 'UGX');
      },
    );

    test('prefers human_friendly_id when catalog search includes it', () {
      final options = decodeClinicalTermOptions(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'LBT-CBC',
            'item_id': '4e73222f-7b32-4a31-a1c1-9c1b59889479',
            'human_friendly_id': 'LBT0000001',
            'term_type': 'LAB_TEST',
            'name': 'Complete Blood Count',
          },
        ],
      });

      expect(options.single.apiId, 'LBT0000001');
      expect(options.single.id, '4e73222f-7b32-4a31-a1c1-9c1b59889479');
    });
  });

  group('decodeCatalogOptions', () {
    test('maps catalog unit price and currency from lab catalog API', () {
      final options = decodeCatalogOptions(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'LBT-BMP',
            'human_friendly_id': 'LBT-BMP',
            'name': 'Basic Metabolic Panel',
            'code': 'BMP',
            'category': 'CHEMISTRY',
            'unit_price': '22000.00',
            'currency': 'UGX',
          },
        ],
      });

      expect(options, hasLength(1));
      expect(options.single.unitPrice, 22000);
      expect(options.single.currency, 'UGX');
    });
  });
}

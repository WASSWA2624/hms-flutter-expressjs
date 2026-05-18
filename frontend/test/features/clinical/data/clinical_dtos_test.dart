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
  });
}

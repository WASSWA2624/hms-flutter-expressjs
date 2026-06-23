import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/data/dtos/lab_dtos.dart';

void main() {
  group('LabOrderSummaryDto', () {
    test('maps requested panel metadata for lab result entry grouping', () {
      const LabOrderSummaryDto dto = LabOrderSummaryDto(<String, Object?>{
        'id': 'LAB0000001',
        'items': <Object?>[
          <String, Object?>{
            'id': 'LIT0000001',
            'lab_order_id': 'LAB0000001',
            'lab_test_id': 'LBT0000001',
            'panel_id': 'LPN0000001',
            'panel_display_name': 'Full blood count',
            'panel_code': 'FBC',
            'panel_sort_order': 2,
            'panel_item_sort_order': 10,
            'test_display_name': 'Hemoglobin',
            'test_code': 'HGB',
            'status': 'ORDERED',
            'result_kind': 'NUMERIC',
          },
        ],
      });

      final item = dto.toEntity().items.single;

      expect(item.panelId, 'LPN0000001');
      expect(item.panelDisplayName, 'Full blood count');
      expect(item.panelCode, 'FBC');
      expect(item.panelSortOrder, 2);
      expect(item.panelItemSortOrder, 10);
      expect(item.panelTitle, 'Full blood count | FBC');
    });
  });

  group('LabOrderItemDto', () {
    test('maps interpretation override fields from API payloads', () {
      const LabOrderItemDto dto = LabOrderItemDto(<String, Object?>{
        'id': 'LIT0000002',
        'interpretation_override': true,
        'reference_range_override': '10 - 18 (manual)',
        'result_flag_override': 'HIGH',
        'reference_range_summary': '12 - 16',
      });

      final item = dto.toEntity();

      expect(item.interpretationOverride, isTrue);
      expect(item.referenceRangeOverride, '10 - 18 (manual)');
      expect(item.resultFlagOverride, 'HIGH');
      expect(item.displayReferenceRange, '10 - 18 (manual)');
    });
  });
}

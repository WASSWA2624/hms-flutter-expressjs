import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/data/dtos/lab_dtos.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

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

    test('maps top-level encounter source and inpatient ward/bed context', () {
      const LabOrderSummaryDto dto = LabOrderSummaryDto(<String, Object?>{
        'id': 'LAB0000010',
        'encounter_id': 'ENC0000010',
        'encounter_type': 'INPATIENT',
        'encounter_source': 'IPD',
        'is_inpatient': true,
        'ward_name': 'Medical Ward',
        'bed_label': 'Bed 4',
        'location_label': 'Medical Ward · Room 2 · Bed 4',
      });

      final summary = dto.toEntity();

      expect(summary.encounterId, 'ENC0000010');
      expect(summary.encounterSource, 'IPD');
      expect(summary.isInpatient, isTrue);
      expect(summary.wardName, 'Medical Ward');
      expect(summary.bedLabel, 'Bed 4');
      expect(summary.encounterSourceLabel, 'IPD');
      expect(summary.encounterLocationLabel, 'Medical Ward · Room 2 · Bed 4');
    });

    test('falls back to nested encounter object for context fields', () {
      const LabOrderSummaryDto dto = LabOrderSummaryDto(<String, Object?>{
        'id': 'LAB0000011',
        'encounter_id': 'ENC0000011',
        'encounter': <String, Object?>{
          'id': 'ENC0000011',
          'type': 'OPD',
          'source': 'OPD',
          'is_inpatient': false,
        },
      });

      final summary = dto.toEntity();

      expect(summary.encounterType, 'OPD');
      expect(summary.encounterSource, 'OPD');
      expect(summary.isInpatient, isFalse);
      expect(summary.encounterSourceLabel, 'OPD');
      expect(summary.encounterLocationLabel, isNull);
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

    test('prefers applied reference range snapshot over live catalog text', () {
      const LabOrderItemDto dto = LabOrderItemDto(<String, Object?>{
        'id': 'LIT0000003',
        'reference_range': 'legacy free text',
        'reference_range_summary': 'catalog summary',
        'applied_reference_range': <String, Object?>{
          'label': 'Adult ISE',
          'summary': 'Adult ISE | Unit mg/dL | 3.6 - 5.2',
          'normal_min_value': '3.6000',
          'normal_max_value': '5.2000',
          'source': 'APPLIED_RULE',
        },
        'reference_ranges': <Object?>[
          <String, Object?>{
            'id': 'range-1',
            'label': 'Changed catalog',
            'summary': 'Changed catalog | 1 - 2',
          },
        ],
      });

      final LabOrderItem item = dto.toEntity();

      expect(
        item.appliedReferenceRange?['summary'],
        'Adult ISE | Unit mg/dL | 3.6 - 5.2',
      );
      expect(item.displayReferenceRange, 'Adult ISE | Unit mg/dL | 3.6 - 5.2');
    });
  });

  group('LabOrderSummary payment gate', () {
    test('treats missing and bill-later statuses as satisfied', () {
      expect(const LabOrderSummary(id: 'LAB1').isPaymentSatisfied, isTrue);
      expect(
        const LabOrderSummary(
          id: 'LAB2',
          paymentStatus: 'NOT_BILLED',
        ).isPaymentSatisfied,
        isTrue,
      );
      expect(
        const LabOrderSummary(
          id: 'LAB3',
          paymentStatus: 'PENDING',
        ).isPaymentSatisfied,
        isFalse,
      );
    });
  });

  group('LabWorkflowNextActionsDto', () {
    test('maps billing gate capabilities from workflow next_actions', () {
      const LabWorkflowNextActionsDto dto =
          LabWorkflowNextActionsDto(<String, Object?>{
            'can_collect': false,
            'billing_gate_blocked': true,
            'payment_status': 'PENDING',
            'can_receive_sample': false,
            'can_enter_result': true,
            'can_enter_all': true,
          });

      final LabWorkflowNextActions actions = dto.toEntity();
      expect(actions.canCollect, isFalse);
      expect(actions.billingGateBlocked, isTrue);
      expect(actions.paymentStatus, 'PENDING');
      expect(actions.canEnterResult, isTrue);
      expect(actions.canEnterAll, isTrue);
    });

    test('falls back from legacy verify/release keys to canEnter*', () {
      const LabWorkflowNextActionsDto dto =
          LabWorkflowNextActionsDto(<String, Object?>{
            'can_verify_result': true,
            'can_verify_all': true,
          });

      final LabWorkflowNextActions actions = dto.toEntity();
      expect(actions.canEnterResult, isTrue);
      expect(actions.canEnterAll, isTrue);
    });
  });

  group('decodeLabTests', () {
    test('maps paginated facility lab catalog payloads', () {
      final List<LabCatalogItem> items = decodeLabTests(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'LAB0000001',
            'name': 'Hemoglobin',
            'is_offered_at_facility': false,
          },
          <String, Object?>{
            'id': 'LAB0000002',
            'name': 'Glucose',
            'is_offered_at_facility': true,
          },
        ],
      });

      expect(items, hasLength(2));
      expect(items.first.name, 'Hemoglobin');
      expect(items.first.isOfferedAtFacility, isFalse);
      expect(items.last.isOfferedAtFacility, isTrue);
    });
  });
}

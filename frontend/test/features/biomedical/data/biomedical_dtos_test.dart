import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/biomedical/data/dtos/biomedical_dtos.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('BiomedicalWorkbenchDto', () {
    test('decodes biomedical workspace responses', () {
      const AppPageRequest request = AppPageRequest(pageIndex: 1);
      final BiomedicalWorkbench workbench = BiomedicalWorkbenchDto.fromResponse(
        <String, Object?>{
          'success': true,
          'data': <String, Object?>{
            'summary': <Object?>[
              <String, Object?>{'id': 'total_equipment', 'value': 12},
              <String, Object?>{'id': 'overdue_pm', 'value': 2},
              <String, Object?>{'id': 'open_work_orders', 'value': 3},
              <String, Object?>{'id': 'critical_downtime', 'value': 1},
              <String, Object?>{'id': 'active_recalls', 'value': 4},
            ],
            'queue_summaries': <Object?>[
              <String, Object?>{
                'queue': 'OPEN_WORK_ORDERS',
                'count': 3,
                'panel': 'work-orders',
                'resource': 'equipment-work-orders',
              },
            ],
            'panel_summaries': <Object?>[
              <String, Object?>{
                'id': 'registry',
                'count': 12,
                'default_resource': 'equipment-registries',
              },
            ],
            'lookups': <String, Object?>{
              'facilities': <Object?>[
                <String, Object?>{
                  'id': 'FAC-001',
                  'label': 'Main hospital',
                  'subtitle': 'Hospital',
                },
              ],
              'equipment': <Object?>[
                <String, Object?>{'id': 'EQ-001', 'label': 'Defibrillator'},
              ],
            },
            'items': <Object?>[
              <String, Object?>{
                'id': 'EQ-001',
                'human_friendly_id': 'EQ-001',
                'resource': BiomedicalResources.registries,
                'title': 'Defibrillator',
                'subtitle': 'DEF-01',
                'status': 'ACTIVE',
                'priority': 'CRITICAL',
                'facility_id': 'FAC-001',
                'facility_label': 'Main hospital',
                'equipment_category_id': 'CAT-001',
                'equipment_category_label': 'Emergency',
                'timeline_at': '2026-05-20T10:00:00.000Z',
              },
            ],
            'pagination': <String, Object?>{
              'page': 2,
              'limit': 20,
              'total': 12,
            },
            'spotlight': <Object?>[
              <String, Object?>{'queue': 'RECALL_ACTIONS', 'count': 4},
            ],
          },
        },
        request,
      ).workbench;

      final BiomedicalAsset asset = workbench.assets.items.single;

      expect(workbench.summary.totalEquipment, 12);
      expect(workbench.summary.openWorkOrders, 3);
      expect(workbench.summary.activeRecalls, 4);
      expect(workbench.queues.single.queue, 'OPEN_WORK_ORDERS');
      expect(
        workbench.panels.single.defaultResource,
        BiomedicalResources.registries,
      );
      expect(
        workbench.lookups.facilities.single.displayLabel,
        'Main hospital | Hospital',
      );
      expect(workbench.assets.request, request);
      expect(workbench.assets.totalItemCount, 12);
      expect(asset.displayId, 'EQ-001');
      expect(asset.displayTitle, 'Defibrillator');
      expect(asset.categoryLabel, 'Emergency');
      expect(asset.timelineAt, DateTime.parse('2026-05-20T10:00:00.000Z'));
      expect(workbench.spotlight.single.queue, 'RECALL_ACTIONS');
    });
  });
}

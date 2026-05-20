import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/operations/data/dtos/operations_dtos.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('Operations DTOs', () {
    test('parses maintenance request metadata from description', () {
      final OperationsWorkItemPageDto
      dto = OperationsWorkItemPageDto.fromResponse(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'MR-001',
            'status': 'OPEN',
            'description':
                'Category: Electrical\nPriority: High\nIssue: ICU power point failed\nLocation: ICU bed 2\nNotes: Check backup socket',
            'facility_label': 'Main hospital',
            'asset_label': 'ICU power outlet',
            'reported_at': '2026-05-20T08:00:00.000Z',
          },
        ],
        'pagination': <String, Object?>{'total': 1},
      }, const AppPageRequest());

      final item = dto.page.items.single;
      expect(item.id, 'MR-001');
      expect(item.metadata.category, 'Electrical');
      expect(item.metadata.priority, 'High');
      expect(item.metadata.issue, 'ICU power point failed');
      expect(item.metadata.location, 'ICU bed 2');
      expect(item.metadata.notes, 'Check backup socket');
    });

    test('applies client-side priority filters without fake statuses', () {
      final OperationsWorkItemPageDto dto =
          OperationsWorkItemPageDto.fromResponse(
            <String, Object?>{
              'data': <Object?>[
                <String, Object?>{
                  'id': 'MR-001',
                  'status': 'OPEN',
                  'description': 'Priority: High\nIssue: Generator alarm',
                },
                <String, Object?>{
                  'id': 'MR-002',
                  'status': 'IN_PROGRESS',
                  'description': 'Priority: Low\nIssue: Store door hinge',
                },
              ],
              'pagination': <String, Object?>{'total': 2},
            },
            const AppPageRequest(),
            priority: 'HIGH',
          );

      expect(dto.page.items, hasLength(1));
      expect(dto.page.items.single.id, 'MR-001');
      expect(dto.page.items.single.status, 'OPEN');
      expect(dto.page.totalItemCount, 1);
    });
  });
}

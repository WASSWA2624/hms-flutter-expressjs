import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/reports/data/dtos/reports_dtos.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('Reports DTOs', () {
    test('decodes workspace summaries, lookups, report items, and totals', () {
      final ReportsWorkspaceOverview overview =
          ReportsWorkspaceOverviewDto.fromResponse(<String, Object?>{
            'data': <String, Object?>{
              'filters': <String, Object?>{'resource': 'report-definitions'},
              'summary': <Object?>[
                <String, Object?>{
                  'id': 'definitions',
                  'label': 'Definitions',
                  'value': '2',
                },
              ],
              'queue_summaries': <Object?>[
                <String, Object?>{
                  'id': 'failed',
                  'label': 'Failed runs',
                  'count': '3',
                  'panel': 'delivery',
                  'resource': 'report-runs',
                },
              ],
              'lookups': <String, Object?>{
                'statuses': <Object?>[
                  <String, Object?>{'id': 'ACTIVE', 'label': 'Active'},
                ],
                'formats': <Object?>[
                  <String, Object?>{'id': 'PDF', 'label': 'PDF'},
                ],
              },
              'items': <Object?>[
                <String, Object?>{
                  'id': 'definition-1',
                  'name': 'Daily census',
                  'description': 'Daily patient census',
                  'status': 'ACTIVE',
                  'default_format': 'PDF',
                  'category': 'OPERATIONS',
                  'dataset_key': 'census',
                  'schedule_count': '2',
                  'updated_at': '2026-05-20T09:00:00.000Z',
                },
              ],
              'timeline': <Object?>[
                <String, Object?>{
                  'id': 'timeline-1',
                  'title': 'Run completed',
                  'resource': 'report-runs',
                  'target_id': 'run-1',
                  'occurred_at': '2026-05-20T10:00:00.000Z',
                },
              ],
              'pagination': <String, Object?>{'total': '1'},
            },
          }, request: const AppPageRequest(pageSize: 12)).toEntity();

      final ReportsWorkspaceItem item = overview.items.items.single;
      expect(overview.summary.single.value, 2);
      expect(overview.queueSummaries.single.count, 3);
      expect(
        overview.queueSummaries.single.panel,
        ReportsWorkspacePanel.delivery,
      );
      expect(overview.lookups.statuses.single.id, 'ACTIVE');
      expect(overview.lookups.formats.single.label, 'PDF');
      expect(overview.items.totalItemCount, 1);
      expect(item.kind, ReportItemKind.definition);
      expect(item.title, 'Daily census');
      expect(item.canRun, isTrue);
      expect(item.count, 2);
      expect(
        overview.timeline.single.resource,
        ReportsWorkspaceResource.reportRuns,
      );
    });

    test('decodes report schedules from paginated responses', () {
      final AppPage<ReportsWorkspaceItem> page =
          ReportsWorkspaceItemPageDto.schedulesFromPaginatedResponse(
            <String, Object?>{
              'data': <Object?>[
                <String, Object?>{
                  'id': 'schedule-1',
                  'name': 'Daily census email',
                  'report_definition_label': 'Daily census',
                  'frequency': 'DAILY',
                  'time_of_day': '07:30',
                  'status': 'ACTIVE',
                  'format': 'PDF',
                  'next_run_at': '2026-05-21T04:30:00.000Z',
                },
              ],
              'pagination': <String, Object?>{'total': 1},
            },
            request: const AppPageRequest(pageSize: 12),
          ).page;

      final ReportsWorkspaceItem schedule = page.items.single;
      expect(page.totalItemCount, 1);
      expect(schedule.kind, ReportItemKind.schedule);
      expect(schedule.isSchedule, isTrue);
      expect(schedule.title, 'Daily census email');
      expect(schedule.subtitle, contains('Daily census'));
      expect(schedule.status, 'ACTIVE');
    });

    test('decodes audit log records with entity references', () {
      final AppPage<ComplianceLogItem> page =
          ComplianceLogItemPageDto.fromPaginatedResponse(
            <String, Object?>{
              'data': <Object?>[
                <String, Object?>{
                  'id': 'audit-1',
                  'action': 'EXPORT',
                  'entity': 'REPORT_RUN',
                  'entity_reference': 'RUN-2026-001',
                  'user_label': 'Nurse Admin',
                  'ip_address': '127.0.0.1',
                  'created_at': '2026-05-20T11:00:00.000Z',
                },
              ],
              'pagination': <String, Object?>{'total': 1},
            },
            request: const AppPageRequest(pageSize: 12),
            kind: ComplianceLogKind.audit,
          ).page;

      final ComplianceLogItem log = page.items.single;
      expect(log.kind, ComplianceLogKind.audit);
      expect(log.title, 'EXPORT | REPORT_RUN');
      expect(log.recordReference, 'RUN-2026-001');
      expect(log.userLabel, 'Nurse Admin');
      expect(log.ipAddress, '127.0.0.1');
    });
  });
}

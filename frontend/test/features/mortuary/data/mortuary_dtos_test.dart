import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/mortuary/data/dtos/mortuary_dtos.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('MortuaryWorkspacePayloadDto', () {
    test('decodes mortuary workspace responses', () {
      const MortuaryWorkspaceQuery query = MortuaryWorkspaceQuery(
        pageRequest: AppPageRequest(pageIndex: 1),
      );

      final MortuaryWorkspacePayload payload =
          MortuaryWorkspacePayloadDto.fromResponse(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'summary': <Object?>[
                <String, Object?>{'id': 'total_cases', 'value': 8},
                <String, Object?>{'id': 'release_ready', 'value': 2},
              ],
              'queue_summaries': <Object?>[
                <String, Object?>{
                  'queue': mortuaryQueueReleaseReady,
                  'count': 2,
                  'panel': mortuaryPanelRelease,
                  'resource': mortuaryResourceReleaseAuthorisations,
                },
              ],
              'panel_summaries': <Object?>[
                <String, Object?>{
                  'id': mortuaryPanelStorage,
                  'count': 4,
                  'default_resource': mortuaryResourceStorageAssignments,
                },
              ],
              'spotlight': <Object?>[
                <String, Object?>{
                  'queue': mortuaryQueuePostMortemPending,
                  'count': 1,
                },
              ],
              'lookups': <String, Object?>{
                'facilities': <Object?>[
                  <String, Object?>{'id': 'FAC-001', 'label': 'Main hospital'},
                ],
                'storage_units': <Object?>[
                  <String, Object?>{'id': 'UNIT-1', 'label': 'Cold room A'},
                ],
                'statuses': <Object?>[
                  <String, Object?>{'id': 'IN_STORAGE', 'label': 'In storage'},
                ],
              },
              'filters': <String, Object?>{
                'panel': mortuaryPanelOverview,
                'resource': mortuaryResourceCases,
                'status': 'IN_STORAGE',
              },
              'items': <Object?>[
                <String, Object?>{
                  'id': 'case-1',
                  'human_friendly_id': 'MOR-001',
                  'resource': mortuaryResourceCases,
                  'status': 'IN_STORAGE',
                  'identification_status': 'VERIFIED',
                  'billing_status': 'UNSETTLED',
                  'deceased_profile_label': 'Amina K.',
                  'patient_label': 'Amina K. | P-001',
                  'source_workflow': 'IPD',
                  'source_reference_id': 'ADM-001',
                  'facility_label': 'Main hospital',
                  'received_at': '2026-05-20T08:30:00.000Z',
                  'timeline_at': '2026-05-20T09:00:00.000Z',
                  'active_storage_assignment': <String, Object?>{
                    'id': 'assign-1',
                    'status': 'ACTIVE',
                    'storage_unit_label': 'Cold room A',
                    'storage_slot_label': 'A-01',
                    'assigned_at': '2026-05-20T09:00:00.000Z',
                  },
                  'custody_events': <Object?>[
                    <String, Object?>{
                      'id': 'custody-1',
                      'event_type': 'RECEIVED',
                      'event_at': '2026-05-20T08:30:00.000Z',
                      'actor_name': 'Mortuary officer',
                    },
                  ],
                  'viewings': <Object?>[
                    <String, Object?>{
                      'id': 'viewing-1',
                      'status': 'SCHEDULED',
                      'scheduled_at': '2026-05-21T10:00:00.000Z',
                    },
                  ],
                  'post_mortem_requests': <Object?>[
                    <String, Object?>{
                      'id': 'pm-1',
                      'status': 'REQUESTED',
                      'requested_by_name': 'Dr. Okello',
                    },
                  ],
                  'release_authorisations': <Object?>[
                    <String, Object?>{
                      'id': 'release-1',
                      'status': 'APPROVED',
                      'recipient_name': 'Family representative',
                    },
                  ],
                  'billable_events': <Object?>[
                    <String, Object?>{
                      'id': 'bill-1',
                      'status': 'PENDING',
                      'event_type': 'STORAGE',
                      'amount': '120000',
                      'currency': 'UGX',
                    },
                  ],
                },
              ],
              'pagination': <String, Object?>{
                'page': 2,
                'limit': 20,
                'total': 8,
              },
              'last_updated_at': '2026-05-20T10:00:00.000Z',
            },
          }, query).payload;

      final MortuaryWorkspaceItem item = payload.items.items.single;

      expect(payload.summary.first.value, 8);
      expect(payload.queues.single.queue, mortuaryQueueReleaseReady);
      expect(
        payload.panels.single.defaultResource,
        mortuaryResourceStorageAssignments,
      );
      expect(payload.spotlight.single.queue, mortuaryQueuePostMortemPending);
      expect(payload.lookups.facilities.single.label, 'Main hospital');
      expect(payload.items.request, query.pageRequest);
      expect(payload.items.totalItemCount, 8);
      expect(payload.filters?.status, 'IN_STORAGE');
      expect(item.effectiveDisplayId, 'MOR-001');
      expect(item.effectiveDeceasedLabel, 'Amina K.');
      expect(item.storageLabel, 'Cold room A / A-01');
      expect(item.custodyEvents.single.eventType, 'RECEIVED');
      expect(item.viewings.single.status, 'SCHEDULED');
      expect(item.postMortemRequests.single.requestedByName, 'Dr. Okello');
      expect(
        item.releaseAuthorisations.single.recipientName,
        'Family representative',
      );
      expect(item.billableEvents.single.currency, 'UGX');
      expect(item.timelineAt, DateTime.parse('2026-05-20T09:00:00.000Z'));
    });
  });
}

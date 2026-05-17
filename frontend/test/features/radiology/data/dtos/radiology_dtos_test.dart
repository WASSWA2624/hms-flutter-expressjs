import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/radiology/data/dtos/radiology_dtos.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('RadiologyWorkbenchDto', () {
    test('decodes radiology workbench responses', () {
      const AppPageRequest request = AppPageRequest(pageIndex: 1);
      final RadiologyWorkbenchDto dto = RadiologyWorkbenchDto.fromResponse(
        <String, Object?>{
          'success': true,
          'data': <String, Object?>{
            'summary': <String, Object?>{
              'total_orders': 3,
              'ordered_queue': 1,
              'processing_queue': 1,
              'draft_reports': 1,
              'finalized_reports': 2,
              'unsynced_studies': 1,
            },
            'worklist': <Object?>[
              <String, Object?>{
                'id': 'RO-001',
                'display_id': 'RAD-001',
                'status': 'IN_PROCESS',
                'patient_id': 'PAT-001',
                'patient_display_name': 'Jane Doe',
                'encounter_id': 'ENC-001',
                'radiology_test_id': 'RT-001',
                'test_display_name': 'Chest X-ray',
                'modality': 'XRAY',
                'payment_status': 'PAID',
                'authorization_status': 'APPROVED',
                'request_details': <String, Object?>{
                  'priority': 'STAT',
                  'body_region': 'Chest',
                  'laterality': 'Bilateral',
                },
                'requested_tests': <Object?>[
                  <String, Object?>{
                    'radiology_test_id': 'RT-001',
                    'test_display_name': 'Chest X-ray',
                    'modality': 'XRAY',
                    'priority': 'STAT',
                    'body_region': 'Chest',
                  },
                ],
                'ordered_at': '2026-05-17T08:00:00.000Z',
                'result_count': 1,
                'study_count': 1,
                'unsynced_study_count': 1,
                'results': <Object?>[
                  <String, Object?>{
                    'id': 'RR-001',
                    'display_id': 'RPT-001',
                    'status': 'FINAL',
                    'report_text': 'No acute cardiopulmonary process.',
                    'finalization': <String, Object?>{
                      'requested': true,
                      'attested': true,
                      'pending_attestation': false,
                    },
                    'reported_at': '2026-05-17T08:40:00.000Z',
                  },
                ],
                'imaging_studies': <Object?>[
                  <String, Object?>{
                    'id': 'IS-001',
                    'display_id': 'STUDY-001',
                    'modality': 'XRAY',
                    'performed_at': '2026-05-17T08:25:00.000Z',
                    'asset_count': 1,
                    'pacs_link_count': 1,
                    'last_pacs_url': 'https://pacs.example/studies/IS-001',
                    'assets': <Object?>[
                      <String, Object?>{
                        'id': 'IA-001',
                        'file_name': 'image-1.dcm',
                        'content_type': 'application/dicom',
                      },
                    ],
                    'pacs_links': <Object?>[
                      <String, Object?>{
                        'id': 'PL-001',
                        'url': 'https://pacs.example/studies/IS-001',
                      },
                    ],
                  },
                ],
              },
            ],
            'pagination': <String, Object?>{'page': 2, 'limit': 20, 'total': 3},
          },
        },
        request,
      );

      final workbench = dto.workbench;
      final order = workbench.orders.items.single;

      expect(workbench.summary.totalOrders, 3);
      expect(workbench.summary.orderedQueue, 1);
      expect(workbench.summary.unsyncedStudies, 1);
      expect(workbench.orders.request, request);
      expect(workbench.orders.totalItemCount, 3);
      expect(order.id, 'RO-001');
      expect(order.patientDisplayName, 'Jane Doe');
      expect(order.priority, 'STAT');
      expect(order.hasBillingGate, isTrue);
      expect(order.latestReleasedResult?.reportText, contains('acute'));
      expect(order.latestStudy?.assets.single.fileName, 'image-1.dcm');
      expect(order.latestStudy?.pacsLinks.single.url, contains('/IS-001'));
    });
  });

  group('RadiologyWorkflowDto', () {
    test('decodes workflow action envelopes', () {
      final workflow = RadiologyWorkflowDto.fromResponse(<String, Object?>{
        'success': true,
        'data': <String, Object?>{
          'workflow': <String, Object?>{
            'order': <String, Object?>{
              'id': 'RO-002',
              'status': 'ORDERED',
              'patient_display_name': 'John Patient',
            },
            'results': <Object?>[
              <String, Object?>{
                'id': 'RR-002',
                'status': 'DRAFT',
                'report_text': 'Draft text',
              },
            ],
            'studies': <Object?>[
              <String, Object?>{'id': 'IS-002', 'modality': 'CT'},
            ],
            'timeline': <Object?>[
              <String, Object?>{
                'type': 'ORDER_CREATED',
                'label': 'Order created',
                'at': '2026-05-17T09:00:00.000Z',
              },
            ],
            'next_actions': <String, Object?>{
              'can_assign': true,
              'can_start': true,
              'can_cancel': true,
            },
          },
        },
      }).toEntity();

      expect(workflow.order.id, 'RO-002');
      expect(workflow.results.single.isDraft, isTrue);
      expect(workflow.studies.single.modality, 'CT');
      expect(workflow.timeline.single.type, 'ORDER_CREATED');
      expect(workflow.nextActions.canAssign, isTrue);
      expect(workflow.nextActions.canStart, isTrue);
      expect(workflow.nextActions.canCancel, isTrue);
    });
  });
}

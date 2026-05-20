import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/communications/data/dtos/communications_dtos.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';

void main() {
  group('Communications DTOs', () {
    test(
      'decodes workspace panels, active thread, notifications, and totals',
      () {
        const CommunicationsWorkspaceQuery query = CommunicationsWorkspaceQuery(
          panel: CommunicationsPanel.notifications,
          notificationId: 'notification-1',
        );
        const NotificationMetrics metrics = NotificationMetrics(
          total: 3,
          unread: 1,
          attentionRequired: 1,
          failedDeliveries: 1,
        );

        final CommunicationsWorkspaceDto dto =
            CommunicationsWorkspaceDto.fromResponse(
              <String, Object?>{
                'data': <String, Object?>{
                  'summary': <Object?>[
                    <String, Object?>{'id': 'unread', 'value': 2},
                    <String, Object?>{'id': 'notifications', 'value': 3},
                    <String, Object?>{'id': 'failed_deliveries', 'value': 1},
                    <String, Object?>{'id': 'templates', 'value': 4},
                  ],
                  'panels': <Object?>[
                    <String, Object?>{'id': 'notifications', 'count': 3},
                  ],
                  'queue_summaries': <Object?>[
                    <String, Object?>{
                      'id': 'failed',
                      'label': 'Failed',
                      'count': 1,
                      'panel': 'deliveries',
                      'filter': 'FAILED',
                    },
                  ],
                  'conversations': <Object?>[
                    <String, Object?>{
                      'id': 'conversation-1',
                      'title': 'Lab result follow-up',
                      'unread': true,
                      'participants': <Object?>[
                        <String, Object?>{
                          'id': 'participant-1',
                          'user_id': 'user-1',
                          'user': <String, Object?>{'name': 'Dr. Jane'},
                        },
                      ],
                      'last_message': <String, Object?>{
                        'id': 'message-1',
                        'content': 'Review potassium result',
                      },
                    },
                  ],
                  'active_conversation': <String, Object?>{
                    'id': 'conversation-1',
                    'title': 'Lab result follow-up',
                    'messages': <Object?>[
                      <String, Object?>{
                        'id': 'message-1',
                        'content': 'Review potassium result',
                        'sent_at': '2026-05-20T08:30:00.000Z',
                        'sender': <String, Object?>{'name': 'Dr. Jane'},
                      },
                    ],
                  },
                  'notifications': <Object?>[
                    <String, Object?>{
                      'id': 'notification-1',
                      'title': 'Critical lab result',
                      'notification_type': 'LAB_RESULT',
                      'priority': 'HIGH',
                      'message': 'Potassium result needs review',
                      'delivery_summary': <String, Object?>{
                        'last_status': 'FAILED',
                      },
                      'deliveries': <Object?>[
                        <String, Object?>{
                          'id': 'delivery-1',
                          'channel': 'EMAIL',
                          'status': 'FAILED',
                          'recipient_target': 'doctor@example.test',
                          'attempt_count': 2,
                          'error_message': 'Mailbox rejected',
                        },
                      ],
                    },
                  ],
                  'deliveries': <Object?>[
                    <String, Object?>{
                      'id': 'delivery-1',
                      'notification_title': 'Critical lab result',
                      'channel': 'EMAIL',
                      'status': 'FAILED',
                      'attempt_count': 2,
                    },
                  ],
                  'templates': <Object?>[
                    <String, Object?>{
                      'id': 'template-1',
                      'name': 'Result ready',
                      'channel': 'EMAIL',
                      'variable_count': 3,
                      'preview': <String, Object?>{
                        'subject': 'Result ready',
                        'body': 'Please review the result.',
                      },
                    },
                  ],
                  'pagination': <String, Object?>{
                    'totals': <String, Object?>{
                      'conversations': 7,
                      'notifications': 3,
                      'deliveries': 2,
                      'templates': 4,
                    },
                  },
                },
              },
              query,
              metrics,
            );

        final CommunicationsWorkspaceState state = dto.state;
        expect(state.summary.unreadThreads, 2);
        expect(state.metrics.failedDeliveries, 1);
        expect(state.conversations.totalItemCount, 7);
        expect(state.notifications.totalItemCount, 3);
        expect(state.deliveries.totalItemCount, 2);
        expect(state.templates.totalItemCount, 4);
        expect(
          state.selectedConversation?.messages.single.content,
          contains('Review'),
        );
        expect(state.selectedNotification?.effectiveDeliveryStatus, 'FAILED');
        expect(state.queueSummaries.single.filter, 'FAILED');
      },
    );

    test('decodes notification metrics response', () {
      final NotificationMetrics metrics = NotificationMetricsDto.fromResponse(
        <String, Object?>{
          'data': <String, Object?>{
            'total': '8',
            'unread': 3,
            'read': 5,
            'attention_required': 2,
            'failed_deliveries': 1,
            'retryable_deliveries': 1,
            'last_received_at': '2026-05-20T09:00:00.000Z',
          },
        },
      ).toEntity();

      expect(metrics.total, 8);
      expect(metrics.unread, 3);
      expect(metrics.attentionRequired, 2);
      expect(metrics.lastReceivedAt, isA<DateTime>());
    });
  });
}

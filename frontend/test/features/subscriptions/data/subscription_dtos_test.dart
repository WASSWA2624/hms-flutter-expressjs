import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/subscriptions/data/dtos/subscription_dtos.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('Subscriptions DTOs', () {
    test('parses workspace summary, lookups, items, and overview', () {
      const SubscriptionsWorkspaceQuery query = SubscriptionsWorkspaceQuery(
        resource: SubscriptionResource.subscriptionInvoices,
        pageRequest: AppPageRequest(pageSize: 10),
      );

      final SubscriptionsWorkspaceData data =
          SubscriptionsWorkspaceDto.fromResponse(<String, Object?>{
            'data': <String, Object?>{
              'summary': <Object?>[
                <String, Object?>{
                  'id': 'active_subscriptions',
                  'label': 'Active subscriptions',
                  'value': '2',
                },
              ],
              'queue_summaries': <Object?>[
                <String, Object?>{
                  'id': 'past_due_billing',
                  'label': 'Past due billing',
                  'count': 1,
                  'panel': 'billing',
                  'resource': 'subscription-invoices',
                  'queue': 'PAST_DUE',
                },
              ],
              'panel_summaries': <Object?>[
                <String, Object?>{
                  'id': 'billing',
                  'count': '1',
                  'default_resource': 'subscription-invoices',
                },
              ],
              'lookups': <String, Object?>{
                'tenants': <Object?>[
                  <String, Object?>{'id': 'tenant-1', 'label': 'IHK Hospital'},
                ],
                'plans': <Object?>[
                  <String, Object?>{'id': 'plan-1', 'label': 'Premium'},
                ],
              },
              'items': <Object?>[
                <String, Object?>{
                  'id': 'subinv-1',
                  'invoice_display_id': 'INV-001',
                  'invoice_status': 'PAID',
                  'tenant_label': 'IHK Hospital',
                  'total_amount': '120000.50',
                  'currency': 'UGX',
                  'issued_at': '2026-05-20T08:00:00.000Z',
                },
              ],
              'pagination': <String, Object?>{'total': '1'},
              'overview': <String, Object?>{
                'current_subscription': <String, Object?>{
                  'id': 'sub-1',
                  'plan_label': 'Premium',
                  'status': 'ACTIVE',
                  'max_modules': 8,
                },
                'current_plan': <String, Object?>{
                  'id': 'plan-1',
                  'label': 'Premium',
                  'tier_code': 'PREMIUM',
                },
                'usage_summary': <String, Object?>{
                  'subscription_id': 'sub-1',
                  'modules_used': '4',
                  'fit_status': 'FIT',
                },
                'next_invoice': <String, Object?>{
                  'id': 'subinv-2',
                  'total_amount': 200000,
                  'currency': 'UGX',
                },
                'license_summary': <String, Object?>{
                  'active_count': '3',
                  'expiring_count': 1,
                  'primary_license': <String, Object?>{
                    'id': 'lic-1',
                    'license_type': 'ENTERPRISE',
                    'status': 'ACTIVE',
                  },
                },
                'recommendations': <Object?>[
                  <String, Object?>{
                    'id': 'rec-1',
                    'title': 'Renew before expiry',
                  },
                ],
                'pending_change': <String, Object?>{
                  'status': 'PENDING',
                  'effective_at': '2026-06-01T00:00:00.000Z',
                },
              },
              'timeline': <Object?>[
                <String, Object?>{
                  'id': 'event-1',
                  'title': 'Invoice paid',
                  'resource': 'subscription-invoices',
                  'status': 'PAID',
                  'occurred_at': '2026-05-20T09:00:00.000Z',
                },
              ],
            },
          }, query).toEntity();

      expect(data.summary.single.value, 2);
      expect(
        data.queueSummaries.single.resource,
        SubscriptionResource.subscriptionInvoices,
      );
      expect(data.panelSummaries.single.panel, SubscriptionPanel.billing);
      expect(data.lookups.tenants.single.label, 'IHK Hospital');
      expect(data.items.totalItemCount, 1);
      expect(data.items.items.single.effectiveDisplayId, 'INV-001');
      expect(data.items.items.single.totalAmount, 120000.50);
      expect(data.overview.currentSubscription?.planLabel, 'Premium');
      expect(data.overview.usageSummary?.modulesUsed, 4);
      expect(
        data.overview.licenseSummary.primaryLicense?.licenseType,
        'ENTERPRISE',
      );
      expect(
        data.timeline.single.resource,
        SubscriptionResource.subscriptionInvoices,
      );
    });

    test('decodes record identifiers from wrapped responses', () {
      expect(
        decodeSubscriptionRecordId(<String, Object?>{
          'data': <String, Object?>{'display_id': 'SUB-001'},
        }),
        'SUB-001',
      );
    });
  });
}

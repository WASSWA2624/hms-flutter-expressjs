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
                'tenant_cohorts': <String, Object?>{
                  'active': <String, Object?>{
                    'count': 2,
                    'accounts': <Object?>[
                      <String, Object?>{
                        'id': 'sub-1',
                        'tenant_id': 'tenant-1',
                        'tenant_label': 'IHK Hospital',
                        'subscription_id': 'sub-1',
                        'status': 'ACTIVE',
                        'plan_label': 'Premium',
                        'start_date': '2026-01-01T00:00:00.000Z',
                        'end_date': '2026-12-31T00:00:00.000Z',
                      },
                    ],
                  },
                  'not_subscribed': <String, Object?>{
                    'count': 1,
                    'accounts': <Object?>[
                      <String, Object?>{
                        'id': 'tenant-2',
                        'tenant_id': 'tenant-2',
                        'tenant_label': 'Clinic B',
                        'status': 'NOT_SUBSCRIBED',
                      },
                    ],
                  },
                  'closed': <String, Object?>{'count': 0, 'accounts': <Object?>[]},
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
      expect(data.overview.activePlanTenants.count, 2);
      expect(data.overview.notSubscribedTenants.accounts.single.tenantLabel, 'Clinic B');
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

    test('parses reference-data lookups and legacy route resolution', () {
      final SubscriptionLookups lookups = SubscriptionLookupsDto.fromResponse(
        <String, Object?>{
          'data': <String, Object?>{
            'tenants': <Object?>[
              <String, Object?>{'id': 'tenant-2', 'label': 'Demo Hospital'},
            ],
            'modules': <Object?>[
              <String, Object?>{
                'id': 'mod-1',
                'label': 'Scheduling and Queue',
                'subtitle': 'scheduling-queue',
              },
            ],
          },
        },
      ).toEntity();

      expect(lookups.tenants.single.label, 'Demo Hospital');
      expect(lookups.modules.single.subtitle, 'scheduling-queue');

      final SubscriptionLegacyRouteResolution resolution =
          SubscriptionLegacyRouteResolutionDto.fromResponse(<String, Object?>{
            'data': <String, Object?>{
              'panel': 'operations',
              'resource': 'subscriptions',
              'id': 'SUB-001',
              'action': 'view',
              'tenantId': 'tenant-2',
            },
          }).toEntity();

      expect(resolution.panel, SubscriptionPanel.operations);
      expect(resolution.resource, SubscriptionResource.subscriptions);
      expect(resolution.id, 'SUB-001');
      expect(resolution.action, 'view');
      expect(resolution.tenantId, 'tenant-2');
    });

    test('builds workspace queries from route URIs', () {
      final SubscriptionsWorkspaceQuery
      query = SubscriptionsWorkspaceQuery.fromUri(
        Uri.parse(
          '/subscriptions?panel=billing&resource=subscription-invoices&id=SINV-001&action=view&queue=PAST_DUE',
        ),
      );

      expect(query.panel, SubscriptionPanel.billing);
      expect(query.resource, SubscriptionResource.subscriptionInvoices);
      expect(query.recordId, 'SINV-001');
      expect(query.action, 'view');
      expect(query.queue, 'PAST_DUE');
      expect(query.hasRouteTargeting, isTrue);
    });
  });
}

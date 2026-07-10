import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';

void main() {
  group('TenantSubscriptionSummary', () {
    test('defaults to unknown before hydration', () {
      expect(
        const TenantSubscriptionSummary().headerState,
        TenantSubscriptionHeaderState.unknown,
      );
      expect(
        TenantSubscriptionHeaderState.fromServer(null),
        TenantSubscriptionHeaderState.unknown,
      );
    });

    test('parses header state from server payload', () {
      final TenantSubscriptionSummary summary =
          TenantSubscriptionSummary.fromJson(<String, Object?>{
            'subscription_id': 'sub-1',
            'status': 'TRIAL',
            'plan_label': 'Trial',
            'days_until_expiry': 7,
            'expiring_soon_days': 14,
            'header_state': 'expiring_soon',
          });

      expect(summary.subscriptionId, 'sub-1');
      expect(summary.headerState, TenantSubscriptionHeaderState.expiringSoon);
      expect(summary.daysUntilExpiry, 7);
    });

    test('parses next upgrade plan fields', () {
      final TenantSubscriptionSummary summary =
          TenantSubscriptionSummary.fromJson(<String, Object?>{
            'subscription_id': 'sub-2',
            'status': 'ACTIVE',
            'plan_label': 'Pro',
            'tier_code': 'PRO',
            'header_state': 'active',
            'next_plan_id': 'plan-advanced',
            'next_plan_label': 'Advanced',
            'next_tier_code': 'ADVANCED',
          });

      expect(summary.planLabel, 'Pro');
      expect(summary.nextPlanLabel, 'Advanced');
      expect(summary.nextTierCode, 'ADVANCED');
      expect(summary.canUpgrade, isTrue);
    });
  });
}

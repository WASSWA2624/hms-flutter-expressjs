import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';

void main() {
  group('TenantSubscriptionSummary', () {
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
  });
}

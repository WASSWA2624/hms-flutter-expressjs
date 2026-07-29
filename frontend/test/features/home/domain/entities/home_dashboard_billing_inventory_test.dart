import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_billing_inventory.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';

void main() {
  group('HomeDashboardBillingInventory', () {
    test('catalogues every billing quick action with a class', () {
      const List<String> billingQuickActionIds = <String>[
        'create_invoice',
        'receive_payment',
        'process_refund',
        'close_shift',
        'review_overdue_invoices',
        'review_pending_payments',
        'review_claims_pending',
        'review_open_patient_balances',
      ];

      for (final String id in billingQuickActionIds) {
        expect(
          HomeDashboardBillingInventory.quickActions.containsKey(id),
          isTrue,
          reason: 'Missing inventory entry for $id',
        );
        expect(homeActionLibrary.containsKey(id), isTrue);
      }
    });

    test('settle/adjust/reverse actions forbid inline home collection', () {
      for (final HomeDashboardBillingAtom atom
          in HomeDashboardBillingInventory.quickActions.values) {
        if (HomeDashboardBillingInventory.isInlineCollectionForbidden(
          atom.actionClass,
        )) {
          expect(
            atom.billingRoute.path,
            AppRoutes.billing.path,
            reason: '${atom.id} must route to Billing workspace',
          );
        }
      }
    });

    test('billing write quick actions require billing:write', () {
      for (final MapEntry<String, HomeDashboardBillingAtom> entry
          in HomeDashboardBillingInventory.quickActions.entries) {
        if (entry.value.actionClass == HomeBillingActionClass.settle ||
            entry.value.actionClass == HomeBillingActionClass.reverse ||
            (entry.value.actionClass == HomeBillingActionClass.createCharge &&
                entry.key != 'add_mortuary_billable_event' &&
                entry.key != 'record_pharmacy_sale' &&
                entry.key != 'dispense_medication' &&
                entry.key != 'order_lab' &&
                entry.key != 'order_radiology')) {
          expect(
            entry.value.requiredPermissions,
            contains(AppPermissions.billingWrite),
            reason: entry.key,
          );
        }
      }
    });

    test('SaaS subscription action is not billable patient ledger', () {
      final HomeDashboardBillingAtom atom =
          HomeDashboardBillingInventory.quickActions['manage_subscription']!;
      expect(atom.actionClass, HomeBillingActionClass.notBillable);
      expect(atom.billingRoute.path, AppRoutes.subscriptions.path);
    });

    test('delegated clinical charges name owning module', () {
      expect(
        HomeDashboardBillingInventory.quickActions['order_lab']!.delegatesToModule,
        'lab',
      );
      expect(
        HomeDashboardBillingInventory.quickActions['record_pharmacy_sale']!
            .delegatesToModule,
        'pharmacy',
      );
    });
  });
}

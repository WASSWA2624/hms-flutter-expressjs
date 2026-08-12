import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_all_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_awaiting_results_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_critical_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_verified_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/widgets/lab_scope_navigation.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Regression locks for `tabs/10-lab/99-convention-gaps.md`.
void main() {
  group('Lab convention gaps — justified unmounted atoms', () {
    test('Open billing / create-additional / edit-order stay unmounted', () {
      expect(LabAllBillingInventory.openBilling.mounted, isFalse);
      expect(LabAllBillingInventory.createAdditional.mounted, isFalse);
      expect(LabAllBillingInventory.editOrder.mounted, isFalse);

      expect(LabAwaitingResultsBillingInventory.openBilling.mounted, isFalse);
      expect(
        LabAwaitingResultsBillingInventory.createAdditionalOrder.mounted,
        isFalse,
      );
      expect(LabAwaitingResultsBillingInventory.editOrder.mounted, isFalse);

      expect(LabCriticalBillingInventory.openBilling.mounted, isFalse);
      expect(LabCriticalBillingInventory.createAdditionalOrder.mounted, isFalse);
      expect(LabCriticalBillingInventory.editOrder.mounted, isFalse);
      expect(LabCriticalBillingInventory.criticalNotify.mounted, isFalse);
      expect(LabCriticalBillingInventory.acknowledge.mounted, isFalse);

      expect(LabVerifiedBillingInventory.openBilling.mounted, isFalse);
      expect(LabVerifiedBillingInventory.createAdditionalOrder.mounted, isFalse);
      expect(LabVerifiedBillingInventory.editOrder.mounted, isFalse);
      expect(LabVerifiedBillingInventory.deleteOrder.mounted, isFalse);
    });
  });

  group('Lab convention gaps — count / tone policy', () {
    test('tones: critical danger, pending warning, others info', () {
      expect(
        labSectionCountTone(LabDeskSection.critical),
        AppTabCountTone.danger,
      );
      expect(
        labSectionCountTone(LabDeskSection.collection),
        AppTabCountTone.warning,
      );
      expect(
        labSectionCountTone(LabDeskSection.completed),
        AppTabCountTone.info,
      );
      expect(
        labSectionCountTone(LabDeskSection.followUps),
        AppTabCountTone.info,
      );
      expect(
        labSectionCountTone(LabDeskSection.worklist),
        AppTabCountTone.info,
      );
    });
  });
}

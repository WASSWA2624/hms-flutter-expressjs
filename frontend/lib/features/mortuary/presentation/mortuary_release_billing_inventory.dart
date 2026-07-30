import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum MortuaryReleaseFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Mortuary Release (`/mortuary?panel=release`).
@immutable
final class MortuaryReleaseFinancialAtom {
  const MortuaryReleaseFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.requirement,
    this.billingPath,
    this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final MortuaryReleaseFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/mortuary?panel=release`.
///
/// Tab role: body-release worklist (release-authorisations). Approve / record
/// release chrome is not mounted — gates kept for helpers. Unsettled billing
/// queue lives on this panel; next-action “Clear billing” defers to Billing.
/// Intake storage, embalming, viewing, and release fees post via
/// `persistMortuaryBillableEventBilling` (MORTUARY source). Settle / adjust /
/// refund stay on the Billing workspace (Open billing). No module cashier.
abstract final class MortuaryReleaseBillingInventory {
  static const MortuaryReleaseFinancialAtom tab = MortuaryReleaseFinancialAtom(
    id: 'tab',
    label: 'Release tab / count badge',
    financialClass: MortuaryReleaseFinancialClass.notRequired,
    requirement: MortuaryReleaseAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const MortuaryReleaseFinancialAtom listChrome =
      MortuaryReleaseFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / pagination',
        financialClass: MortuaryReleaseFinancialClass.notRequired,
        requirement: MortuaryReleaseAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryReleaseFinancialAtom emptyLoadingError =
      MortuaryReleaseFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: MortuaryReleaseFinancialClass.notRequired,
        requirement: MortuaryReleaseAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryReleaseFinancialAtom rowSelect =
      MortuaryReleaseFinancialAtom(
        id: 'row_select',
        label: 'Row select → release detail',
        financialClass: MortuaryReleaseFinancialClass.notRequired,
        requirement: MortuaryReleaseAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryReleaseFinancialAtom nextAction =
      MortuaryReleaseFinancialAtom(
        id: 'next_action',
        label: 'Next action (Clear billing / Approve release guidance)',
        financialClass: MortuaryReleaseFinancialClass.defer,
        requirement: MortuaryReleaseAtomPermissions.nextAction,
        billingPath:
            'case.billing_status parity; Clear billing → Open billing / Billing',
      );

  static const MortuaryReleaseFinancialAtom billingStatusColumn =
      MortuaryReleaseFinancialAtom(
        id: 'billing_status_column',
        label: 'Billing status column (case ledger parity)',
        financialClass: MortuaryReleaseFinancialClass.defer,
        requirement: MortuaryReleaseAtomPermissions.listChrome,
        billingPath:
            'case.billing_status ← Billing invoice / mortuary_billable_event',
      );

  static const MortuaryReleaseFinancialAtom unsettledBillingQueue =
      MortuaryReleaseFinancialAtom(
        id: 'unsettled_billing_queue',
        label: 'Unsettled billing queue (release panel)',
        financialClass: MortuaryReleaseFinancialClass.defer,
        requirement: MortuaryReleaseAtomPermissions.listChrome,
        billingPath:
            'queue UNSETTLED_BILLING → mortuary-billable-events / Billing status',
      );

  static const MortuaryReleaseFinancialAtom detailBillingPanel =
      MortuaryReleaseFinancialAtom(
        id: 'detail_billing_panel',
        label: 'Detail Billing events (read)',
        financialClass: MortuaryReleaseFinancialClass.defer,
        requirement: MortuaryReleaseAtomPermissions.billingPanel,
        billingPath:
            'billable_events.billing_reference_id → Billing invoice rows',
      );

  static const MortuaryReleaseFinancialAtom openBilling =
      MortuaryReleaseFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (settle / refund / adjust — Billing workspace)',
        financialClass: MortuaryReleaseFinancialClass.settle,
        requirement: MortuaryReleaseAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline cashier)',
      );

  static const MortuaryReleaseFinancialAtom printDocuments =
      MortuaryReleaseFinancialAtom(
        id: 'print_documents',
        label: 'Detail Print documents',
        financialClass: MortuaryReleaseFinancialClass.noCharge,
        requirement: MortuaryReleaseAtomPermissions.printDocuments,
        auditCode: 'NO_CHARGE',
      );

  static const MortuaryReleaseFinancialAtom approveRelease =
      MortuaryReleaseFinancialAtom(
        id: 'approve_release',
        label: 'Approve / record body release (blocked when unsettled)',
        financialClass: MortuaryReleaseFinancialClass.defer,
        requirement: MortuaryReleaseAtomPermissions.release,
        billingPath:
            'isMortuaryReleaseBlockedByOutstandingBilling → settle in Billing',
        mounted: false,
      );

  static const MortuaryReleaseFinancialAtom storageFee =
      MortuaryReleaseFinancialAtom(
        id: 'storage_fee',
        label: 'Intake / storage fee (fulfilled elsewhere)',
        financialClass: MortuaryReleaseFinancialClass.createCharge,
        requirement: MortuaryReleaseAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_STORAGE)',
        mounted: false,
      );

  static const MortuaryReleaseFinancialAtom embalmingFee =
      MortuaryReleaseFinancialAtom(
        id: 'embalming_fee',
        label: 'Embalming charge (fulfilled elsewhere)',
        financialClass: MortuaryReleaseFinancialClass.createCharge,
        requirement: MortuaryReleaseAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_EMBALMING)',
        mounted: false,
      );

  static const MortuaryReleaseFinancialAtom viewingFee =
      MortuaryReleaseFinancialAtom(
        id: 'viewing_fee',
        label: 'Viewing charge (fulfilled elsewhere)',
        financialClass: MortuaryReleaseFinancialClass.createCharge,
        requirement: MortuaryReleaseAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_VIEWING)',
        mounted: false,
      );

  static const MortuaryReleaseFinancialAtom releaseFee =
      MortuaryReleaseFinancialAtom(
        id: 'release_fee',
        label: 'Release charge (create-charge via shared Billing)',
        financialClass: MortuaryReleaseFinancialClass.createCharge,
        requirement: MortuaryReleaseAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_RELEASE)',
        mounted: false,
      );

  static const MortuaryReleaseFinancialAtom collectPayment =
      MortuaryReleaseFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / deposit (absent — Billing owns)',
        financialClass: MortuaryReleaseFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment APIs',
        mounted: false,
      );

  static const MortuaryReleaseFinancialAtom adjustRefund =
      MortuaryReleaseFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note (absent)',
        financialClass: MortuaryReleaseFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<MortuaryReleaseFinancialAtom> all =
      <MortuaryReleaseFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextAction,
        billingStatusColumn,
        unsettledBillingQueue,
        detailBillingPanel,
        openBilling,
        printDocuments,
        approveRelease,
        storageFee,
        embalmingFee,
        viewingFee,
        releaseFee,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<MortuaryReleaseFinancialAtom> get mountedAtoms =>
      all.where((MortuaryReleaseFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static Iterable<MortuaryReleaseFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (MortuaryReleaseFinancialAtom atom) =>
            atom.financialClass == MortuaryReleaseFinancialClass.createCharge ||
            atom.financialClass == MortuaryReleaseFinancialClass.settle ||
            atom.financialClass == MortuaryReleaseFinancialClass.adjust ||
            atom.financialClass == MortuaryReleaseFinancialClass.reverse ||
            atom.financialClass == MortuaryReleaseFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final MortuaryReleaseFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden — Billing owns payment.
  static bool forbidsInlineCashier(MortuaryReleaseFinancialClass actionClass) {
    return switch (actionClass) {
      MortuaryReleaseFinancialClass.settle ||
      MortuaryReleaseFinancialClass.adjust ||
      MortuaryReleaseFinancialClass.reverse ||
      MortuaryReleaseFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'Mortuary Release is the body-release worklist. Unsettled billing queue '
      'and Clear billing next-action defer to Billing. Storage / embalming / '
      'viewing / release fees post via persistMortuaryBillableEventBilling. '
      'Open billing navigates Billing. No module cashier.';
}

/// Documents Release financial scope for tests and audits.
const String mortuaryReleaseBillingScopeNote =
    'Mortuary Release is the body-release queue. Approve / record release is '
    'not mounted; unsettled billing blocks release progress via next-action '
    'and UNSETTLED_BILLING queue. Storage, embalming, viewing, and release '
    'charges post via persistMortuaryBillableEventBilling (MORTUARY source / '
    'clinical-request-billing). Open billing navigates the Billing workspace '
    'with patient_id. Settle / adjust / refund are not mounted — Billing owns '
    'payment.';

import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum MortuaryStorageFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Mortuary Storage (`/mortuary?panel=storage`).
@immutable
final class MortuaryStorageFinancialAtom {
  const MortuaryStorageFinancialAtom({
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
  final MortuaryStorageFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/mortuary?panel=storage`.
///
/// Tab role: storage-assignments worklist + Assign storage
/// (`mortuary:manage_storage`). Assignment / slot moves are logistics
/// (`NOT_REQUIRED` / `STORAGE_ASSIGNED`) — they must not invent a cash ledger
/// and must preserve payer + balance continuity on the linked case. Intake
/// storage, embalming, viewing, and release fees post via
/// `persistMortuaryBillableEventBilling` (MORTUARY source) when fulfilled.
/// Settle / adjust / refund stay on the Billing workspace (Open billing). No
/// module cashier on this tab.
abstract final class MortuaryStorageBillingInventory {
  static const MortuaryStorageFinancialAtom tab = MortuaryStorageFinancialAtom(
    id: 'tab',
    label: 'Storage tab / count badge',
    financialClass: MortuaryStorageFinancialClass.notRequired,
    requirement: MortuaryStorageAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const MortuaryStorageFinancialAtom listChrome =
      MortuaryStorageFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / pagination',
        financialClass: MortuaryStorageFinancialClass.notRequired,
        requirement: MortuaryStorageAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryStorageFinancialAtom emptyLoadingError =
      MortuaryStorageFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: MortuaryStorageFinancialClass.notRequired,
        requirement: MortuaryStorageAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryStorageFinancialAtom rowSelect =
      MortuaryStorageFinancialAtom(
        id: 'row_select',
        label: 'Row select → storage detail',
        financialClass: MortuaryStorageFinancialClass.notRequired,
        requirement: MortuaryStorageAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryStorageFinancialAtom nextAction =
      MortuaryStorageFinancialAtom(
        id: 'next_action',
        label: 'Next action (guidance incl. Clear billing)',
        financialClass: MortuaryStorageFinancialClass.notRequired,
        requirement: MortuaryStorageAtomPermissions.nextAction,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryStorageFinancialAtom billingStatusColumn =
      MortuaryStorageFinancialAtom(
        id: 'billing_status_column',
        label: 'Billing status column / detail badge (case ledger parity)',
        financialClass: MortuaryStorageFinancialClass.defer,
        requirement: MortuaryStorageAtomPermissions.listChrome,
        billingPath:
            'case.billing_status ← Billing invoice / mortuary_billable_event',
      );

  static const MortuaryStorageFinancialAtom detailBillingPanel =
      MortuaryStorageFinancialAtom(
        id: 'detail_billing_panel',
        label: 'Detail Billing events (read)',
        financialClass: MortuaryStorageFinancialClass.defer,
        requirement: MortuaryStorageAtomPermissions.billingPanel,
        billingPath:
            'billable_events.billing_reference_id → Billing invoice rows',
      );

  static const MortuaryStorageFinancialAtom openBilling =
      MortuaryStorageFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (settle / refund / adjust — Billing workspace)',
        financialClass: MortuaryStorageFinancialClass.settle,
        requirement: MortuaryStorageAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline cashier)',
      );

  static const MortuaryStorageFinancialAtom printDocuments =
      MortuaryStorageFinancialAtom(
        id: 'print_documents',
        label: 'Detail Print documents',
        financialClass: MortuaryStorageFinancialClass.noCharge,
        requirement: MortuaryStorageAtomPermissions.printDocuments,
        auditCode: 'NO_CHARGE',
      );

  static const MortuaryStorageFinancialAtom assignStorage =
      MortuaryStorageFinancialAtom(
        id: 'assign_storage',
        label: 'Assign storage / slot move (logistics; continuity)',
        financialClass: MortuaryStorageFinancialClass.notRequired,
        requirement: MortuaryStorageAtomPermissions.assignStorage,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const MortuaryStorageFinancialAtom storageFee =
      MortuaryStorageFinancialAtom(
        id: 'storage_fee',
        label: 'Intake / storage fee (create-charge)',
        financialClass: MortuaryStorageFinancialClass.createCharge,
        requirement: MortuaryStorageAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_STORAGE)',
        mounted: false,
      );

  static const MortuaryStorageFinancialAtom embalmingFee =
      MortuaryStorageFinancialAtom(
        id: 'embalming_fee',
        label: 'Embalming charge (create-charge)',
        financialClass: MortuaryStorageFinancialClass.createCharge,
        requirement: MortuaryStorageAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_EMBALMING)',
        mounted: false,
      );

  static const MortuaryStorageFinancialAtom viewingFee =
      MortuaryStorageFinancialAtom(
        id: 'viewing_fee',
        label: 'Viewing charge (create-charge)',
        financialClass: MortuaryStorageFinancialClass.createCharge,
        requirement: MortuaryStorageAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_VIEWING)',
        mounted: false,
      );

  static const MortuaryStorageFinancialAtom releaseFee =
      MortuaryStorageFinancialAtom(
        id: 'release_fee',
        label: 'Release charge (create-charge)',
        financialClass: MortuaryStorageFinancialClass.createCharge,
        requirement: MortuaryStorageAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_RELEASE)',
        mounted: false,
      );

  static const MortuaryStorageFinancialAtom custodyTransfer =
      MortuaryStorageFinancialAtom(
        id: 'custody_transfer',
        label: 'Custody transfer (logistics; continuity)',
        financialClass: MortuaryStorageFinancialClass.notRequired,
        requirement: MortuaryStorageAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const MortuaryStorageFinancialAtom collectPayment =
      MortuaryStorageFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / deposit (absent — Billing owns)',
        financialClass: MortuaryStorageFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment APIs',
        mounted: false,
      );

  static const MortuaryStorageFinancialAtom adjustRefund =
      MortuaryStorageFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note (absent)',
        financialClass: MortuaryStorageFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<MortuaryStorageFinancialAtom> all =
      <MortuaryStorageFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextAction,
        billingStatusColumn,
        detailBillingPanel,
        openBilling,
        printDocuments,
        assignStorage,
        storageFee,
        embalmingFee,
        viewingFee,
        releaseFee,
        custodyTransfer,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<MortuaryStorageFinancialAtom> get mountedAtoms =>
      all.where((MortuaryStorageFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static Iterable<MortuaryStorageFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (MortuaryStorageFinancialAtom atom) =>
            atom.financialClass == MortuaryStorageFinancialClass.createCharge ||
            atom.financialClass == MortuaryStorageFinancialClass.settle ||
            atom.financialClass == MortuaryStorageFinancialClass.adjust ||
            atom.financialClass == MortuaryStorageFinancialClass.reverse ||
            atom.financialClass == MortuaryStorageFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final MortuaryStorageFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden — Billing owns payment.
  static bool forbidsInlineCashier(MortuaryStorageFinancialClass actionClass) {
    return switch (actionClass) {
      MortuaryStorageFinancialClass.settle ||
      MortuaryStorageFinancialClass.adjust ||
      MortuaryStorageFinancialClass.reverse ||
      MortuaryStorageFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'Mortuary Storage is the storage-assignments worklist. Assign storage / '
      'slot moves stay NOT_REQUIRED logistics with payer continuity. Storage / '
      'embalming / viewing / release fees post via '
      'persistMortuaryBillableEventBilling. Open billing navigates Billing. '
      'No module cashier.';
}

/// Documents Storage financial scope for tests and audits.
const String mortuaryStorageBillingScopeNote =
    'Mortuary Storage is the storage-assignments queue. Assign storage and '
    'slot moves are NOT_REQUIRED logistics (STORAGE_ASSIGNED; no patient '
    'ledger; payer and balance continuity on the linked case). Storage, '
    'embalming, viewing, and release charges post via '
    'persistMortuaryBillableEventBilling (MORTUARY source / '
    'clinical-request-billing). Open billing navigates the Billing workspace '
    'with patient_id. Settle / adjust / refund are not mounted — Billing owns '
    'payment.';

import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum MortuaryReportsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Mortuary Reports
/// (`/mortuary?panel=reporting`).
@immutable
final class MortuaryReportsFinancialAtom {
  const MortuaryReportsFinancialAtom({
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
  final MortuaryReportsFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/mortuary?panel=reporting`.
///
/// Tab role: post-mortem / reporting worklist (exports & audit —
/// `mortuary:export` / `mortuary:audit`). Storage, embalming, viewing, and
/// release fees must already post through
/// `persistMortuaryBillableEventBilling` (MORTUARY) when fulfilled elsewhere.
/// Custody transfers are logistics-only (`NOT_REQUIRED`) and preserve payer /
/// balance continuity on the linked case. Settle / adjust / refund stay on the
/// Billing workspace — this tab never mounts a parallel cashier. Print /
/// export documents are `NO_CHARGE`.
abstract final class MortuaryReportsBillingInventory {
  static const MortuaryReportsFinancialAtom tab = MortuaryReportsFinancialAtom(
    id: 'tab',
    label: 'Reports strip tab / count badge',
    financialClass: MortuaryReportsFinancialClass.notRequired,
    requirement: MortuaryReportsAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const MortuaryReportsFinancialAtom listChrome =
      MortuaryReportsFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / pagination',
        financialClass: MortuaryReportsFinancialClass.notRequired,
        requirement: MortuaryReportsAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryReportsFinancialAtom emptyLoadingError =
      MortuaryReportsFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: MortuaryReportsFinancialClass.notRequired,
        requirement: MortuaryReportsAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryReportsFinancialAtom rowSelect =
      MortuaryReportsFinancialAtom(
        id: 'row_select',
        label: 'Row select → post-mortem / case detail',
        financialClass: MortuaryReportsFinancialClass.notRequired,
        requirement: MortuaryReportsAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryReportsFinancialAtom nextAction =
      MortuaryReportsFinancialAtom(
        id: 'next_action',
        label: 'Next action guidance (incl. Clear billing)',
        financialClass: MortuaryReportsFinancialClass.notRequired,
        requirement: MortuaryReportsAtomPermissions.nextAction,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryReportsFinancialAtom billingStatusParity =
      MortuaryReportsFinancialAtom(
        id: 'billing_status_parity',
        label: 'Detail / next-action billing status (case ledger parity)',
        financialClass: MortuaryReportsFinancialClass.defer,
        requirement: MortuaryReportsAtomPermissions.detail,
        billingPath:
            'case.billing_status ← Billing invoice / mortuary_billable_event',
      );

  static const MortuaryReportsFinancialAtom detailBillingPanel =
      MortuaryReportsFinancialAtom(
        id: 'detail_billing_panel',
        label: 'Detail Billing events (read ledger mirror)',
        financialClass: MortuaryReportsFinancialClass.defer,
        requirement: MortuaryReportsAtomPermissions.billingPanel,
        billingPath:
            'billable_events.billing_reference_id → Billing invoice rows',
      );

  static const MortuaryReportsFinancialAtom openBilling =
      MortuaryReportsFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (settle / refund / adjust — Billing workspace)',
        financialClass: MortuaryReportsFinancialClass.settle,
        requirement: MortuaryReportsAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline cashier)',
      );

  static const MortuaryReportsFinancialAtom printDocuments =
      MortuaryReportsFinancialAtom(
        id: 'print_documents',
        label: 'Detail Print documents / export report',
        financialClass: MortuaryReportsFinancialClass.noCharge,
        requirement: MortuaryReportsAtomPermissions.printDocuments,
        auditCode: 'NO_CHARGE',
      );

  static const MortuaryReportsFinancialAtom nestedExport =
      MortuaryReportsFinancialAtom(
        id: 'nested_export',
        label: 'Nested export write entry (export-only ∪)',
        financialClass: MortuaryReportsFinancialClass.noCharge,
        requirement: MortuaryReportsAtomPermissions.nestedWrite,
        auditCode: 'NO_CHARGE',
        mounted: false,
      );

  static const MortuaryReportsFinancialAtom auditPanel =
      MortuaryReportsFinancialAtom(
        id: 'audit_panel',
        label: 'Audit panel (not mounted)',
        financialClass: MortuaryReportsFinancialClass.notRequired,
        requirement: MortuaryReportsAtomPermissions.audit,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const MortuaryReportsFinancialAtom storageFee =
      MortuaryReportsFinancialAtom(
        id: 'storage_fee',
        label: 'Intake / storage fee (fulfilled elsewhere)',
        financialClass: MortuaryReportsFinancialClass.createCharge,
        requirement: MortuaryReportsAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_STORAGE)',
        mounted: false,
      );

  static const MortuaryReportsFinancialAtom embalmingFee =
      MortuaryReportsFinancialAtom(
        id: 'embalming_fee',
        label: 'Embalming charge (fulfilled elsewhere)',
        financialClass: MortuaryReportsFinancialClass.createCharge,
        requirement: MortuaryReportsAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_EMBALMING)',
        mounted: false,
      );

  static const MortuaryReportsFinancialAtom viewingFee =
      MortuaryReportsFinancialAtom(
        id: 'viewing_fee',
        label: 'Viewing charge (fulfilled elsewhere)',
        financialClass: MortuaryReportsFinancialClass.createCharge,
        requirement: MortuaryReportsAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_VIEWING)',
        mounted: false,
      );

  static const MortuaryReportsFinancialAtom releaseFee =
      MortuaryReportsFinancialAtom(
        id: 'release_fee',
        label: 'Release charge (fulfilled elsewhere)',
        financialClass: MortuaryReportsFinancialClass.createCharge,
        requirement: MortuaryReportsAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_RELEASE)',
        mounted: false,
      );

  static const MortuaryReportsFinancialAtom custodyTransfer =
      MortuaryReportsFinancialAtom(
        id: 'custody_transfer',
        label: 'Custody transfer (logistics; payer continuity)',
        financialClass: MortuaryReportsFinancialClass.notRequired,
        requirement: MortuaryReportsAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const MortuaryReportsFinancialAtom collectPayment =
      MortuaryReportsFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / deposit (absent — Billing owns)',
        financialClass: MortuaryReportsFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment APIs',
        mounted: false,
      );

  static const MortuaryReportsFinancialAtom adjustRefund =
      MortuaryReportsFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note (absent)',
        financialClass: MortuaryReportsFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<MortuaryReportsFinancialAtom> all =
      <MortuaryReportsFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextAction,
        billingStatusParity,
        detailBillingPanel,
        openBilling,
        printDocuments,
        nestedExport,
        auditPanel,
        storageFee,
        embalmingFee,
        viewingFee,
        releaseFee,
        custodyTransfer,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<MortuaryReportsFinancialAtom> get mountedAtoms =>
      all.where((MortuaryReportsFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static Iterable<MortuaryReportsFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (MortuaryReportsFinancialAtom atom) =>
            atom.financialClass == MortuaryReportsFinancialClass.createCharge ||
            atom.financialClass == MortuaryReportsFinancialClass.settle ||
            atom.financialClass == MortuaryReportsFinancialClass.adjust ||
            atom.financialClass == MortuaryReportsFinancialClass.reverse ||
            atom.financialClass == MortuaryReportsFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final MortuaryReportsFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden — Billing owns payment.
  static bool forbidsInlineCashier(MortuaryReportsFinancialClass actionClass) {
    return switch (actionClass) {
      MortuaryReportsFinancialClass.settle ||
      MortuaryReportsFinancialClass.adjust ||
      MortuaryReportsFinancialClass.reverse ||
      MortuaryReportsFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'Mortuary Reports is the post-mortem / export-audit worklist. Storage / '
      'embalming / viewing / release fees post via '
      'persistMortuaryBillableEventBilling. Open billing navigates Billing. '
      'Print / export are NO_CHARGE. No module cashier.';
}

/// Documents Reports financial scope for tests and audits.
const String mortuaryReportsBillingScopeNote =
    'Mortuary Reports is the post-mortem reporting queue (exports / audit). '
    'Print and nested export are NO_CHARGE. Custody transfers are NOT_REQUIRED '
    'logistics with payer continuity. Storage, embalming, viewing, and release '
    'charges post via persistMortuaryBillableEventBilling (MORTUARY source / '
    'clinical-request-billing). Open billing navigates the Billing workspace '
    'with patient_id. Settle / adjust / refund are not mounted — Billing owns '
    'payment.';

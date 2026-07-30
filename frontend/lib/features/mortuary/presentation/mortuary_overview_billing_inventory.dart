import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum MortuaryOverviewFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Mortuary Overview (`/mortuary` /
/// `?panel=overview`).
@immutable
final class MortuaryOverviewFinancialAtom {
  const MortuaryOverviewFinancialAtom({
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
  final MortuaryOverviewFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/mortuary` / `?panel=overview`.
///
/// Overview is a summary / read surface: worklist + detail chrome. Storage,
/// embalming, viewing, and release fees must already post through
/// `persistMortuaryBillableEventBilling` (MORTUARY). Settle / adjust / refund
/// stay on the Billing workspace — this tab never mounts a parallel cashier.
/// Custody transfers are logistics-only (`NOT_REQUIRED`) and preserve payer /
/// balance continuity on the linked case.
abstract final class MortuaryOverviewBillingInventory {
  static const MortuaryOverviewFinancialAtom tab =
      MortuaryOverviewFinancialAtom(
        id: 'tab',
        label: 'Overview strip tab / count badge',
        financialClass: MortuaryOverviewFinancialClass.notRequired,
        requirement: MortuaryOverviewAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryOverviewFinancialAtom listChrome =
      MortuaryOverviewFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / columns / pagination',
        financialClass: MortuaryOverviewFinancialClass.notRequired,
        requirement: MortuaryOverviewAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryOverviewFinancialAtom emptyLoadingError =
      MortuaryOverviewFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: MortuaryOverviewFinancialClass.notRequired,
        requirement: MortuaryOverviewAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryOverviewFinancialAtom rowSelect =
      MortuaryOverviewFinancialAtom(
        id: 'row_select',
        label: 'Row select → case detail',
        financialClass: MortuaryOverviewFinancialClass.notRequired,
        requirement: MortuaryOverviewAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryOverviewFinancialAtom nextAction =
      MortuaryOverviewFinancialAtom(
        id: 'next_action',
        label: 'Next action guidance text (incl. Clear billing)',
        financialClass: MortuaryOverviewFinancialClass.notRequired,
        requirement: MortuaryOverviewAtomPermissions.nextAction,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryOverviewFinancialAtom billingStatusChip =
      MortuaryOverviewFinancialAtom(
        id: 'billing_status_chip',
        label: 'List / detail billing status badge (parity with Billing)',
        financialClass: MortuaryOverviewFinancialClass.defer,
        requirement: MortuaryOverviewAtomPermissions.detail,
        billingPath:
            'mortuary_case.billing_status ↔ invoice payment_status / billable_charge_event',
        auditCode: 'DEFERRED',
      );

  static const MortuaryOverviewFinancialAtom billingEventsPanel =
      MortuaryOverviewFinancialAtom(
        id: 'billing_events_panel',
        label: 'Detail Billing events (read ledger mirror)',
        financialClass: MortuaryOverviewFinancialClass.notRequired,
        requirement: MortuaryOverviewAtomPermissions.billingPanel,
        billingPath:
            'mortuary_billable_event.billing_reference_id → Billing invoice',
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryOverviewFinancialAtom openBilling =
      MortuaryOverviewFinancialAtom(
        id: 'open_billing',
        label:
            'Detail Open billing (settle outstanding — Billing workspace)',
        financialClass: MortuaryOverviewFinancialClass.settle,
        requirement: MortuaryOverviewAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
      );

  static const MortuaryOverviewFinancialAtom absentInlineCollect =
      MortuaryOverviewFinancialAtom(
        id: 'absent_inline_collect',
        label:
            'Inline receive-payment / issue-invoice / waive / refund (forbidden)',
        financialClass: MortuaryOverviewFinancialClass.settle,
        requirement: MortuaryOverviewAtomPermissions.openBilling,
        billingPath: 'Billing workspace only — no module cashier',
        mounted: false,
      );

  static const MortuaryOverviewFinancialAtom printDocuments =
      MortuaryOverviewFinancialAtom(
        id: 'print_documents',
        label: 'Detail Print documents',
        financialClass: MortuaryOverviewFinancialClass.noCharge,
        requirement: MortuaryOverviewAtomPermissions.printDocuments,
        auditCode: 'NO_CHARGE',
      );

  static const MortuaryOverviewFinancialAtom storageFee =
      MortuaryOverviewFinancialAtom(
        id: 'storage_fee',
        label: 'Intake / storage fee (create-charge; other tabs)',
        financialClass: MortuaryOverviewFinancialClass.createCharge,
        requirement: MortuaryOverviewAtomPermissions.billingPanel,
        billingPath:
            'applyMortuaryBillableEventBilling → persistMortuaryBillableEventBilling (MORTUARY_STORAGE)',
        mounted: false,
      );

  static const MortuaryOverviewFinancialAtom embalmingFee =
      MortuaryOverviewFinancialAtom(
        id: 'embalming_fee',
        label: 'Embalming fee (create-charge; other tabs)',
        financialClass: MortuaryOverviewFinancialClass.createCharge,
        requirement: MortuaryOverviewAtomPermissions.billingPanel,
        billingPath:
            'applyMortuaryBillableEventBilling → persistMortuaryBillableEventBilling (MORTUARY_EMBALMING)',
        mounted: false,
      );

  static const MortuaryOverviewFinancialAtom viewingFee =
      MortuaryOverviewFinancialAtom(
        id: 'viewing_fee',
        label: 'Viewing fee (create-charge; other tabs)',
        financialClass: MortuaryOverviewFinancialClass.createCharge,
        requirement: MortuaryOverviewAtomPermissions.billingPanel,
        billingPath:
            'applyMortuaryBillableEventBilling → persistMortuaryBillableEventBilling (MORTUARY_VIEWING)',
        mounted: false,
      );

  static const MortuaryOverviewFinancialAtom releaseFee =
      MortuaryOverviewFinancialAtom(
        id: 'release_fee',
        label: 'Release fee (create-charge; other tabs)',
        financialClass: MortuaryOverviewFinancialClass.createCharge,
        requirement: MortuaryOverviewAtomPermissions.billingPanel,
        billingPath:
            'applyMortuaryBillableEventBilling → persistMortuaryBillableEventBilling (MORTUARY_RELEASE)',
        mounted: false,
      );

  static const MortuaryOverviewFinancialAtom custodyTransfer =
      MortuaryOverviewFinancialAtom(
        id: 'custody_transfer',
        label: 'Custody transfer (logistics; no charge)',
        financialClass: MortuaryOverviewFinancialClass.notRequired,
        requirement: MortuaryOverviewAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryOverviewFinancialAtom receiveCase =
      MortuaryOverviewFinancialAtom(
        id: 'receive_case',
        label: 'Receive case (absent on Overview)',
        financialClass: MortuaryOverviewFinancialClass.notRequired,
        requirement: MortuaryOverviewAtomPermissions.receiveCase,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const MortuaryOverviewFinancialAtom adjustRefund =
      MortuaryOverviewFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: MortuaryOverviewFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<MortuaryOverviewFinancialAtom> atoms =
      <MortuaryOverviewFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextAction,
        billingStatusChip,
        billingEventsPanel,
        openBilling,
        absentInlineCollect,
        printDocuments,
        storageFee,
        embalmingFee,
        viewingFee,
        releaseFee,
        custodyTransfer,
        receiveCase,
        adjustRefund,
      ];

  static List<MortuaryOverviewFinancialAtom> get billableAtoms => atoms
      .where(
        (MortuaryOverviewFinancialAtom atom) =>
            atom.mounted &&
            (atom.financialClass ==
                    MortuaryOverviewFinancialClass.createCharge ||
                atom.financialClass == MortuaryOverviewFinancialClass.settle ||
                atom.financialClass == MortuaryOverviewFinancialClass.adjust ||
                atom.financialClass == MortuaryOverviewFinancialClass.reverse ||
                atom.financialClass == MortuaryOverviewFinancialClass.defer),
      )
      .toList(growable: false);

  static List<MortuaryOverviewFinancialAtom> get mountedAtoms => atoms
      .where((MortuaryOverviewFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    MortuaryOverviewFinancialClass financialClass,
  ) {
    return financialClass == MortuaryOverviewFinancialClass.settle ||
        financialClass == MortuaryOverviewFinancialClass.adjust ||
        financialClass == MortuaryOverviewFinancialClass.reverse;
  }

  /// Every mounted billable atom must navigate or post via a Billing path.
  static bool get allBillableAtomsWireThroughBilling {
    for (final MortuaryOverviewFinancialAtom atom in billableAtoms) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }
}

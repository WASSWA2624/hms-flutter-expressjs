import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum MortuaryIntakeFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Mortuary Intake (`/mortuary?panel=intake`).
@immutable
final class MortuaryIntakeFinancialAtom {
  const MortuaryIntakeFinancialAtom({
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
  final MortuaryIntakeFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/mortuary?panel=intake`.
///
/// Tab role: receive-case worklist (read-only today). Storage, embalming,
/// viewing, and release fees must post through
/// `applyMortuaryBillableEventBilling` → `persistMortuaryBillableEventBilling`
/// (MORTUARY source). Custody transfers are logistics (`NOT_REQUIRED`) and
/// preserve payer / balance continuity. Settle / adjust / refund stay on the
/// Billing workspace (Open billing / Clear billing next-action). No module
/// cashier on this tab.
abstract final class MortuaryIntakeBillingInventory {
  static const MortuaryIntakeFinancialAtom tab = MortuaryIntakeFinancialAtom(
    id: 'tab',
    label: 'Intake tab / count badge',
    financialClass: MortuaryIntakeFinancialClass.notRequired,
    requirement: MortuaryIntakeAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const MortuaryIntakeFinancialAtom listChrome =
      MortuaryIntakeFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / pagination',
        financialClass: MortuaryIntakeFinancialClass.notRequired,
        requirement: MortuaryIntakeAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryIntakeFinancialAtom emptyLoadingError =
      MortuaryIntakeFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: MortuaryIntakeFinancialClass.notRequired,
        requirement: MortuaryIntakeAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryIntakeFinancialAtom rowSelect =
      MortuaryIntakeFinancialAtom(
        id: 'row_select',
        label: 'Row select → intake case detail',
        financialClass: MortuaryIntakeFinancialClass.notRequired,
        requirement: MortuaryIntakeAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryIntakeFinancialAtom nextAction =
      MortuaryIntakeFinancialAtom(
        id: 'next_action',
        label: 'Next action (Clear billing → Open billing when allowed)',
        financialClass: MortuaryIntakeFinancialClass.defer,
        requirement: MortuaryIntakeAtomPermissions.nextAction,
        billingPath: 'AppRoutes.billing?patient_id=… when Clear billing',
        auditCode: 'DEFERRED',
      );

  static const MortuaryIntakeFinancialAtom billingStatusColumn =
      MortuaryIntakeFinancialAtom(
        id: 'billing_status_column',
        label: 'Billing status column (ledger parity)',
        financialClass: MortuaryIntakeFinancialClass.defer,
        requirement: MortuaryIntakeAtomPermissions.listChrome,
        billingPath:
            'case.billing_status ← Billing invoice / billable_charge_event',
      );

  static const MortuaryIntakeFinancialAtom detailBillingPanel =
      MortuaryIntakeFinancialAtom(
        id: 'detail_billing_panel',
        label: 'Detail Billing events (read ledger mirror)',
        financialClass: MortuaryIntakeFinancialClass.defer,
        requirement: MortuaryIntakeAtomPermissions.billingPanel,
        billingPath:
            'mortuary_billable_event.billing_reference_id → Billing invoice',
      );

  static const MortuaryIntakeFinancialAtom openBilling =
      MortuaryIntakeFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (settle outstanding — Billing workspace)',
        financialClass: MortuaryIntakeFinancialClass.settle,
        requirement: MortuaryIntakeAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline cashier)',
      );

  static const MortuaryIntakeFinancialAtom absentInlineCollect =
      MortuaryIntakeFinancialAtom(
        id: 'absent_inline_collect',
        label:
            'Inline receive-payment / issue-invoice / waive / refund (forbidden)',
        financialClass: MortuaryIntakeFinancialClass.settle,
        requirement: MortuaryIntakeAtomPermissions.openBilling,
        billingPath: 'Billing workspace only — no module cashier',
        mounted: false,
      );

  static const MortuaryIntakeFinancialAtom printDocuments =
      MortuaryIntakeFinancialAtom(
        id: 'print_documents',
        label: 'Detail Print documents',
        financialClass: MortuaryIntakeFinancialClass.noCharge,
        requirement: MortuaryIntakeAtomPermissions.printDocuments,
        auditCode: 'NO_CHARGE',
      );

  static const MortuaryIntakeFinancialAtom receiveCase =
      MortuaryIntakeFinancialAtom(
        id: 'receive_case',
        label: 'Receive case (create; not mounted)',
        financialClass: MortuaryIntakeFinancialClass.notRequired,
        requirement: MortuaryIntakeAtomPermissions.receiveCase,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const MortuaryIntakeFinancialAtom storageFee =
      MortuaryIntakeFinancialAtom(
        id: 'storage_fee',
        label: 'Intake / storage fee (create-charge)',
        financialClass: MortuaryIntakeFinancialClass.createCharge,
        requirement: MortuaryIntakeAtomPermissions.billingPanel,
        billingPath:
            'applyMortuaryBillableEventBilling → persistMortuaryBillableEventBilling (MORTUARY_STORAGE)',
        mounted: false,
      );

  static const MortuaryIntakeFinancialAtom embalmingFee =
      MortuaryIntakeFinancialAtom(
        id: 'embalming_fee',
        label: 'Embalming fee (create-charge)',
        financialClass: MortuaryIntakeFinancialClass.createCharge,
        requirement: MortuaryIntakeAtomPermissions.billingPanel,
        billingPath:
            'applyMortuaryBillableEventBilling → persistMortuaryBillableEventBilling (MORTUARY_EMBALMING)',
        mounted: false,
      );

  static const MortuaryIntakeFinancialAtom viewingFee =
      MortuaryIntakeFinancialAtom(
        id: 'viewing_fee',
        label: 'Viewing fee (create-charge)',
        financialClass: MortuaryIntakeFinancialClass.createCharge,
        requirement: MortuaryIntakeAtomPermissions.billingPanel,
        billingPath:
            'applyMortuaryBillableEventBilling → persistMortuaryBillableEventBilling (MORTUARY_VIEWING)',
        mounted: false,
      );

  static const MortuaryIntakeFinancialAtom releaseFee =
      MortuaryIntakeFinancialAtom(
        id: 'release_fee',
        label: 'Release fee (create-charge)',
        financialClass: MortuaryIntakeFinancialClass.createCharge,
        requirement: MortuaryIntakeAtomPermissions.billingPanel,
        billingPath:
            'applyMortuaryBillableEventBilling → persistMortuaryBillableEventBilling (MORTUARY_RELEASE)',
        mounted: false,
      );

  static const MortuaryIntakeFinancialAtom custodyTransfer =
      MortuaryIntakeFinancialAtom(
        id: 'custody_transfer',
        label: 'Custody transfer (logistics; continuity)',
        financialClass: MortuaryIntakeFinancialClass.notRequired,
        requirement: MortuaryIntakeAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryIntakeFinancialAtom collectPayment =
      MortuaryIntakeFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / deposit (absent — Billing owns)',
        financialClass: MortuaryIntakeFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment APIs',
        mounted: false,
      );

  static const MortuaryIntakeFinancialAtom adjustRefund =
      MortuaryIntakeFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note (absent)',
        financialClass: MortuaryIntakeFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<MortuaryIntakeFinancialAtom> all =
      <MortuaryIntakeFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextAction,
        billingStatusColumn,
        detailBillingPanel,
        openBilling,
        absentInlineCollect,
        printDocuments,
        receiveCase,
        storageFee,
        embalmingFee,
        viewingFee,
        releaseFee,
        custodyTransfer,
        collectPayment,
        adjustRefund,
      ];

  static List<MortuaryIntakeFinancialAtom> get billableMounted => all
      .where(
        (MortuaryIntakeFinancialAtom atom) =>
            atom.mounted &&
            (atom.financialClass == MortuaryIntakeFinancialClass.createCharge ||
                atom.financialClass == MortuaryIntakeFinancialClass.settle ||
                atom.financialClass == MortuaryIntakeFinancialClass.adjust ||
                atom.financialClass == MortuaryIntakeFinancialClass.reverse ||
                atom.financialClass == MortuaryIntakeFinancialClass.defer),
      )
      .toList(growable: false);

  static List<MortuaryIntakeFinancialAtom> get mountedAtoms => all
      .where((MortuaryIntakeFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool forbidsInlineCashier(MortuaryIntakeFinancialClass financialClass) {
    return financialClass == MortuaryIntakeFinancialClass.settle ||
        financialClass == MortuaryIntakeFinancialClass.adjust ||
        financialClass == MortuaryIntakeFinancialClass.reverse;
  }

  /// Every mounted billable atom must navigate or post via a Billing path.
  static bool get allBillableAtomsWireThroughBilling {
    for (final MortuaryIntakeFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }
}

/// Documents Intake financial scope for tests and audits.
const String mortuaryIntakeBillingScopeNote =
    'Mortuary Intake receives cases and surfaces billing status. Storage, '
    'embalming, viewing, and release charges post via '
    'applyMortuaryBillableEventBilling → persistMortuaryBillableEventBilling '
    '(MORTUARY source / clinical-request-billing). Open billing navigates the '
    'Billing workspace; no module cashier. Custody transfers are NOT_REQUIRED '
    'logistics and preserve payer continuity.';

import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IpdBedBoardFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on IPD Bed board (`/ipd?section=bed-board`).
@immutable
final class IpdBedBoardFinancialAtom {
  const IpdBedBoardFinancialAtom({
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
  final IpdBedBoardFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/ipd?section=bed-board`.
///
/// Tab role: ward occupancy board (`IpdBedBoardPanel`). Bed status next-actions
/// (reserve / block / maintenance / mark available / return to service) and
/// Manage beds → Rooms & beds stay `NOT_BILLED` facility ops. **Start
/// admission** mounts deposit / fee / bed-day lines via shared
/// ClinicalRequestBillingPanel → `startIpdFlow` → `buildAdmissionBilling` →
/// `persistAdmissionBilling` (no parallel cashier). Occupied-row detail may
/// open ward-round billing (wired) and discharge planning (clearance via
/// Billing ledger). Transfer rate changes, consumables, and inline
/// collect/adjust remain on Transfers / Active / Billing — never duplicated
/// as a module cash drawer on this board.
abstract final class IpdBedBoardBillingInventory {
  static const IpdBedBoardFinancialAtom tab = IpdBedBoardFinancialAtom(
    id: 'tab_navigate',
    label: 'Bed board tab (occupancy chrome)',
    financialClass: IpdBedBoardFinancialClass.notRequired,
    requirement: IpdBedBoardAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdBedBoardFinancialAtom listChrome = IpdBedBoardFinancialAtom(
    id: 'search_filters_columns',
    label: 'Search / ward+status filters / columns / table settings',
    financialClass: IpdBedBoardFinancialClass.notRequired,
    requirement: IpdBedBoardAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdBedBoardFinancialAtom emptyLoadingError =
      IpdBedBoardFinancialAtom(
        id: 'empty_loading_error_retry',
        label: 'Empty / loading / error / retry states',
        financialClass: IpdBedBoardFinancialClass.notRequired,
        requirement: IpdBedBoardAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdBedBoardFinancialAtom bedRowRead = IpdBedBoardFinancialAtom(
    id: 'bed_row_read',
    label: 'Bed row (label / ward / occupant / status)',
    financialClass: IpdBedBoardFinancialClass.notRequired,
    requirement: IpdBedBoardAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdBedBoardFinancialAtom openAdmissionDetail =
      IpdBedBoardFinancialAtom(
        id: 'open_admission_detail',
        label: 'Occupied row → admission detail dialog (no collect on board)',
        financialClass: IpdBedBoardFinancialClass.notRequired,
        requirement: IpdBedBoardAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdBedBoardFinancialAtom bedStatusUpdate =
      IpdBedBoardFinancialAtom(
        id: 'bed_status_next_action',
        label:
            'Next action bed status (Reserve / Block / Maintenance / Available)',
        financialClass: IpdBedBoardFinancialClass.notBilled,
        requirement: IpdBedBoardAtomPermissions.bedStatusUpdate,
        auditCode: 'NOT_BILLED',
      );

  static const IpdBedBoardFinancialAtom manageBeds = IpdBedBoardFinancialAtom(
    id: 'manage_beds_primary',
    label: 'Manage beds → /rooms-beds (bed-admin navigate)',
    financialClass: IpdBedBoardFinancialClass.notBilled,
    requirement: IpdBedBoardAtomPermissions.manageBeds,
    auditCode: 'NOT_BILLED',
  );

  static const IpdBedBoardFinancialAtom realtimeBoardSync =
      IpdBedBoardFinancialAtom(
        id: 'realtime_bed_board_sync',
        label: 'Post-mutation bed board / worklist refresh',
        financialClass: IpdBedBoardFinancialClass.notRequired,
        requirement: IpdBedBoardAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Primary billable mutation mounted on this tab (toolbar / secondary).
  static const IpdBedBoardFinancialAtom startAdmission =
      IpdBedBoardFinancialAtom(
        id: 'start_admission',
        label: 'Start admission (deposit / fee / bed-day → Billing)',
        financialClass: IpdBedBoardFinancialClass.createCharge,
        requirement: IpdBedBoardAtomPermissions.startAdmission,
        billingPath:
            'IpdStartAdmissionDialog ClinicalRequestBillingPanel → '
            'startIpdFlow → buildAdmissionBilling → persistAdmissionBilling '
            '(chargeKey ADMISSION_START)',
        auditCode: 'REQUIRES_BILLING',
      );

  /// Nested billing chrome inside Start admission (∩ billing:read).
  static const IpdBedBoardFinancialAtom startAdmissionBillingPanel =
      IpdBedBoardFinancialAtom(
        id: 'start_admission_billing_panel',
        label: 'Start admission ClinicalRequestBillingPanel (embedded sibling)',
        financialClass: IpdBedBoardFinancialClass.createCharge,
        requirement: IpdBedBoardAtomPermissions.billingPanel,
        billingPath:
            'ClinicalRequestBillingPanel → persistAdmissionBilling '
            '(facility billingPaymentMethods on PAID)',
        auditCode: 'REQUIRES_BILLING',
      );

  /// Reachable from occupied-row detail → Add ward round.
  static const IpdBedBoardFinancialAtom wardRoundFromDetail =
      IpdBedBoardFinancialAtom(
        id: 'detail_ward_round',
        label: 'Detail → Add ward round (clinical-request billing)',
        financialClass: IpdBedBoardFinancialClass.createCharge,
        requirement: IpdBedBoardAtomPermissions.clinicalWrite,
        billingPath:
            'addWardRound → persistWardRoundBilling (ClinicalRequestBillingPanel)',
        auditCode: 'REQUIRES_BILLING',
      );

  /// Discharge planning from detail — clearance derives from Billing ledger.
  static const IpdBedBoardFinancialAtom dischargePlanFromDetail =
      IpdBedBoardFinancialAtom(
        id: 'detail_discharge_plan',
        label: 'Detail → plan / manage discharge (financial clearance gate)',
        financialClass: IpdBedBoardFinancialClass.defer,
        requirement: IpdBedBoardAtomPermissions.clinicalWrite,
        billingPath:
            'showDischargePlanningDialog → finalizeDischarge '
            'isBillingSettledForPatient / outstanding in Billing',
        auditCode: 'REQUIRES_BILLING',
      );

  static const IpdBedBoardFinancialAtom transferRateChange =
      IpdBedBoardFinancialAtom(
        id: 'transfer_rate_change',
        label: 'Transfer that changes bed/day rate',
        financialClass: IpdBedBoardFinancialClass.createCharge,
        requirement: IpdBedBoardAtomPermissions.write,
        billingPath:
            'Transfers tab + clinical-request-billing rate delta (not board chrome)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IpdBedBoardFinancialAtom consumables = IpdBedBoardFinancialAtom(
    id: 'consumables',
    label: 'Ward consumables / supplies charge',
    financialClass: IpdBedBoardFinancialClass.createCharge,
    requirement: IpdBedBoardAtomPermissions.write,
    billingPath:
        'Active patients / nursing → persistConsumableBilling (not this board)',
    auditCode: 'REQUIRES_BILLING',
    mounted: false,
  );

  static const IpdBedBoardFinancialAtom collectPayment =
      IpdBedBoardFinancialAtom(
        id: 'collect_payment',
        label: 'Inline receive payment / cashier collect',
        financialClass: IpdBedBoardFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (facility billingPaymentMethods)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IpdBedBoardFinancialAtom issueInvoiceAdjustRefund =
      IpdBedBoardFinancialAtom(
        id: 'issue_invoice_adjust_refund',
        label: 'Issue invoice / adjust / refund / reverse / write-off',
        financialClass: IpdBedBoardFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / credit-note / refund paths',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const List<IpdBedBoardFinancialAtom> atoms =
      <IpdBedBoardFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        bedRowRead,
        openAdmissionDetail,
        bedStatusUpdate,
        manageBeds,
        realtimeBoardSync,
        startAdmission,
        startAdmissionBillingPanel,
        wardRoundFromDetail,
        dischargePlanFromDetail,
        transferRateChange,
        consumables,
        collectPayment,
        issueInvoiceAdjustRefund,
      ];

  static List<IpdBedBoardFinancialAtom> get mountedAtoms => atoms
      .where((IpdBedBoardFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// Mounted atoms that must post / gate through shared Billing paths.
  static List<IpdBedBoardFinancialAtom> get billableAtoms => mountedAtoms
      .where(
        (IpdBedBoardFinancialAtom atom) =>
            atom.financialClass == IpdBedBoardFinancialClass.createCharge ||
            atom.financialClass == IpdBedBoardFinancialClass.settle ||
            atom.financialClass == IpdBedBoardFinancialClass.adjust ||
            atom.financialClass == IpdBedBoardFinancialClass.reverse ||
            atom.financialClass == IpdBedBoardFinancialClass.defer,
      )
      .toList(growable: false);

  static bool get allBillableAtomsWireThroughBilling {
    for (final IpdBedBoardFinancialAtom atom in billableAtoms) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Occupancy / facility-ops chrome with no patient ledger post.
  static bool get allOpsAtomsExplicitlyNotBillable {
    return mountedAtoms
        .where(
          (IpdBedBoardFinancialAtom atom) =>
              atom.financialClass == IpdBedBoardFinancialClass.notRequired ||
              atom.financialClass == IpdBedBoardFinancialClass.notBilled ||
              atom.financialClass == IpdBedBoardFinancialClass.noCharge,
        )
        .every(
          (IpdBedBoardFinancialAtom atom) =>
              atom.auditCode == 'NOT_REQUIRED' ||
              atom.auditCode == 'NOT_BILLED' ||
              atom.auditCode == 'NO_CHARGE',
        );
  }

  /// Inline cashier settle/adjust/refund is forbidden — Billing owns payment.
  static bool isInlineCollectionForbidden(
    IpdBedBoardFinancialClass financialClass,
  ) {
    return financialClass == IpdBedBoardFinancialClass.settle ||
        financialClass == IpdBedBoardFinancialClass.adjust ||
        financialClass == IpdBedBoardFinancialClass.reverse;
  }

  static String summary() =>
      'IPD Bed board is an occupancy board. Bed status and Manage beds stay '
      'NOT_BILLED. Start admission posts deposit/fee/bed-day via '
      'persistAdmissionBilling. Ward-round and discharge clearance from detail '
      'reuse shared Billing helpers. Transfer rate, consumables, and cashier '
      'settle are not mounted as a parallel ledger on this tab.';
}

/// Documents Bed board financial scope for tests and audits.
const String ipdBedBoardBillingScopeNote =
    'IPD Bed board (`/ipd?section=bed-board`) is the ward occupancy view. '
    'Reserve / block / maintenance / mark available and Manage beds stay '
    'NOT_BILLED facility ops (PUT /beds/:id; Rooms & beds navigate). Start '
    'admission mounts ADMISSION_FEE / ADMISSION_DEPOSIT / BED_DAY through '
    'ClinicalRequestBillingPanel → startIpdFlow → buildAdmissionBilling → '
    'persistAdmissionBilling (idempotent ADMISSION_START). Occupied-row detail '
    'may add ward rounds via persistWardRoundBilling and plan discharge with '
    'Billing clearance. Transfer rate changes, consumables, and inline '
    'collect/adjust/refund remain on Transfers / Active / Billing — no module '
    'cashier on this board. RealtimeEventGroups.ipd includes billing for '
    'balance parity after mutations.';

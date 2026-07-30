import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum EmergencyClosedFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Emergency Closed (`/emergency?scope=closed`).
@immutable
final class EmergencyClosedFinancialAtom {
  const EmergencyClosedFinancialAtom({
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
  final EmergencyClosedFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/emergency?scope=closed`.
///
/// Closed cases are read-only for clinical mutations (no Quick arrival, no
/// next-action writes). Deferred handoff / ambulance / procedure charges must
/// already exist in Billing as outstanding/PENDING; this tab settles by
/// navigating to the Billing workspace — never a module cashier. Delete/void
/// remains unmounted and must reverse Billing lines if ever added.
abstract final class EmergencyClosedBillingInventory {
  static const EmergencyClosedFinancialAtom tab = EmergencyClosedFinancialAtom(
    id: 'tab',
    label: 'Closed tab / count badge',
    financialClass: EmergencyClosedFinancialClass.notRequired,
    requirement: EmergencyClosedAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const EmergencyClosedFinancialAtom listChrome =
      EmergencyClosedFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / columns',
        financialClass: EmergencyClosedFinancialClass.notRequired,
        requirement: EmergencyClosedAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyClosedFinancialAtom emptyLoadingError =
      EmergencyClosedFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: EmergencyClosedFinancialClass.notRequired,
        requirement: EmergencyClosedAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyClosedFinancialAtom rowSelect =
      EmergencyClosedFinancialAtom(
        id: 'row_select',
        label: 'Row select → closed case detail',
        financialClass: EmergencyClosedFinancialClass.notRequired,
        requirement: EmergencyClosedAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyClosedFinancialAtom quickArrival =
      EmergencyClosedFinancialAtom(
        id: 'quick_arrival',
        label: 'Quick arrival (absent on Closed)',
        financialClass: EmergencyClosedFinancialClass.createCharge,
        requirement: EmergencyClosedAtomPermissions.quickArrival,
        billingPath:
            'quick arrival → clinical-request-billing / OPD consultation (other tabs)',
        mounted: false,
      );

  static const EmergencyClosedFinancialAtom nextAction =
      EmergencyClosedFinancialAtom(
        id: 'next_action',
        label: 'Next action column / cells (absent on Closed)',
        financialClass: EmergencyClosedFinancialClass.notRequired,
        requirement: EmergencyClosedAtomPermissions.nextAction,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const EmergencyClosedFinancialAtom complementaryWrites =
      EmergencyClosedFinancialAtom(
        id: 'complementary_writes',
        label:
            'Detail priority / triage / response / dispatch / trip / handoff / theater',
        financialClass: EmergencyClosedFinancialClass.notBilled,
        requirement: EmergencyClosedAtomPermissions.write,
        auditCode: 'NOT_BILLED',
        mounted: false,
      );

  static const EmergencyClosedFinancialAtom printSummary =
      EmergencyClosedFinancialAtom(
        id: 'print_summary',
        label: 'Detail Print summary',
        financialClass: EmergencyClosedFinancialClass.noCharge,
        requirement: EmergencyClosedAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const EmergencyClosedFinancialAtom openInReceivingModule =
      EmergencyClosedFinancialAtom(
        id: 'open_in_receiving_module',
        label: 'Detail Open in OPD/IPD/ICU/Theater (navigate)',
        financialClass: EmergencyClosedFinancialClass.notRequired,
        requirement: EmergencyClosedAtomPermissions.openInReceivingModule,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyClosedFinancialAtom billingDeferredChip =
      EmergencyClosedFinancialAtom(
        id: 'billing_deferred_chip',
        label: 'Billing deferred status chip / message (parity with Billing)',
        financialClass: EmergencyClosedFinancialClass.defer,
        requirement: EmergencyClosedAtomPermissions.detail,
        billingPath:
            'handoff snapshot billing_deferred ↔ Billing PENDING/outstanding invoice',
        auditCode: 'DEFERRED',
      );

  static const EmergencyClosedFinancialAtom openBilling =
      EmergencyClosedFinancialAtom(
        id: 'open_billing',
        label:
            'Detail Open billing (settle deferred / outstanding — Billing workspace)',
        financialClass: EmergencyClosedFinancialClass.settle,
        requirement: EmergencyClosedAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
      );

  static const EmergencyClosedFinancialAtom absentInlineCollect =
      EmergencyClosedFinancialAtom(
        id: 'absent_inline_collect',
        label: 'Inline receive-payment / issue-invoice / waive / refund (forbidden)',
        financialClass: EmergencyClosedFinancialClass.settle,
        requirement: EmergencyClosedAtomPermissions.openBilling,
        billingPath: 'Billing workspace only — no module cashier',
        mounted: false,
      );

  static const EmergencyClosedFinancialAtom timelinePanel =
      EmergencyClosedFinancialAtom(
        id: 'timeline_panel',
        label: 'Detail Triage and response timeline (read)',
        financialClass: EmergencyClosedFinancialClass.notRequired,
        requirement: EmergencyClosedAtomPermissions.timelinePanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyClosedFinancialAtom ambulancePanel =
      EmergencyClosedFinancialAtom(
        id: 'ambulance_panel',
        label: 'Detail Ambulance panel (historical trip read)',
        financialClass: EmergencyClosedFinancialClass.notRequired,
        requirement: EmergencyClosedAtomPermissions.ambulancePanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyClosedFinancialAtom ambulanceTripCharge =
      EmergencyClosedFinancialAtom(
        id: 'ambulance_trip_charge',
        label: 'Ambulance trip complete (historical create-charge; not mounted)',
        financialClass: EmergencyClosedFinancialClass.createCharge,
        requirement: EmergencyClosedAtomPermissions.write,
        billingPath:
            'updateAmbulanceTrip ended_at → persistAmbulanceTripBilling / clinical-request-billing',
        mounted: false,
      );

  static const EmergencyClosedFinancialAtom handoffDeferredCharge =
      EmergencyClosedFinancialAtom(
        id: 'handoff_deferred_charge',
        label:
            'Handoff IPD/ICU/Theater deferred admission/theatre fee (created at handoff)',
        financialClass: EmergencyClosedFinancialClass.defer,
        requirement: EmergencyClosedAtomPermissions.handoffWrite,
        billingPath:
            'handoffEmergencyCase → buildEmergency*Billing → clinical-request-billing',
        mounted: false,
      );

  static const EmergencyClosedFinancialAtom procedureConsumable =
      EmergencyClosedFinancialAtom(
        id: 'procedure_consumable',
        label: 'Procedure / consumable order (not present on Emergency Closed)',
        financialClass: EmergencyClosedFinancialClass.createCharge,
        requirement: EmergencyClosedAtomPermissions.write,
        billingPath: 'clinical-request-billing (downstream clinical modules)',
        mounted: false,
      );

  static const EmergencyClosedFinancialAtom hardDelete =
      EmergencyClosedFinancialAtom(
        id: 'hard_delete',
        label: 'Hard delete / void (no UI; gate kept)',
        financialClass: EmergencyClosedFinancialClass.reverse,
        requirement: EmergencyClosedAtomPermissions.delete,
        billingPath:
            'DELETE emergency-cases → must void/reverse Billing lines if added',
        mounted: false,
      );

  static const List<EmergencyClosedFinancialAtom> atoms =
      <EmergencyClosedFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        quickArrival,
        nextAction,
        complementaryWrites,
        printSummary,
        openInReceivingModule,
        billingDeferredChip,
        openBilling,
        absentInlineCollect,
        timelinePanel,
        ambulancePanel,
        ambulanceTripCharge,
        handoffDeferredCharge,
        procedureConsumable,
        hardDelete,
      ];

  static List<EmergencyClosedFinancialAtom> get billableAtoms => atoms
      .where(
        (EmergencyClosedFinancialAtom atom) =>
            atom.mounted &&
            (atom.financialClass ==
                    EmergencyClosedFinancialClass.createCharge ||
                atom.financialClass == EmergencyClosedFinancialClass.settle ||
                atom.financialClass == EmergencyClosedFinancialClass.adjust ||
                atom.financialClass == EmergencyClosedFinancialClass.reverse ||
                atom.financialClass == EmergencyClosedFinancialClass.defer),
      )
      .toList(growable: false);

  static List<EmergencyClosedFinancialAtom> get mountedAtoms => atoms
      .where((EmergencyClosedFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    EmergencyClosedFinancialClass financialClass,
  ) {
    return financialClass == EmergencyClosedFinancialClass.settle ||
        financialClass == EmergencyClosedFinancialClass.adjust ||
        financialClass == EmergencyClosedFinancialClass.reverse;
  }

  /// Every mounted billable atom must navigate or post via a Billing path.
  static bool get allBillableAtomsWireThroughBilling {
    for (final EmergencyClosedFinancialAtom atom in billableAtoms) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }
}

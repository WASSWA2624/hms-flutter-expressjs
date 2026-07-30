import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum EmergencyHandoffFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Emergency Handoff ready
/// (`/emergency?scope=handoff`).
@immutable
final class EmergencyHandoffFinancialAtom {
  const EmergencyHandoffFinancialAtom({
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
  final EmergencyHandoffFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/emergency?scope=handoff`.
///
/// Cases ready for ward/OPD/IPD/ICU/Theater handoff. Urgent care may defer
/// payment when policy allows, but deferred admission, theatre, consultation,
/// ambulance, procedure, and consumable charges still post Billing records
/// (PENDING / outstanding) via emergency-billing helpers and
/// clinical-request-billing. Settlement stays on the Billing workspace — this
/// tab never mounts a parallel cashier. Record handoff is the primary
/// billable mutation (clinical:write ∪ may admit without emergency:write).
abstract final class EmergencyHandoffBillingInventory {
  static const EmergencyHandoffFinancialAtom tab =
      EmergencyHandoffFinancialAtom(
        id: 'tab',
        label: 'Handoff ready tab / count badge',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom listChrome =
      EmergencyHandoffFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / columns',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom emptyLoadingError =
      EmergencyHandoffFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom rowSelect =
      EmergencyHandoffFinancialAtom(
        id: 'row_select',
        label: 'Row select → case detail',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom quickArrival =
      EmergencyHandoffFinancialAtom(
        id: 'quick_arrival',
        label: 'Quick arrival (patient + case; no ED visit fee atom)',
        financialClass: EmergencyHandoffFinancialClass.notBilled,
        requirement: EmergencyHandoffAtomPermissions.quickArrival,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyHandoffFinancialAtom updatePriority =
      EmergencyHandoffFinancialAtom(
        id: 'update_priority',
        label: 'Update priority / severity',
        financialClass: EmergencyHandoffFinancialClass.notBilled,
        requirement: EmergencyHandoffAtomPermissions.updatePriority,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyHandoffFinancialAtom recordTriage =
      EmergencyHandoffFinancialAtom(
        id: 'record_triage',
        label: 'Record triage',
        financialClass: EmergencyHandoffFinancialClass.notBilled,
        requirement: EmergencyHandoffAtomPermissions.recordTriage,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyHandoffFinancialAtom markResponse =
      EmergencyHandoffFinancialAtom(
        id: 'mark_response',
        label: 'Mark emergency response',
        financialClass: EmergencyHandoffFinancialClass.notBilled,
        requirement: EmergencyHandoffAtomPermissions.markResponse,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyHandoffFinancialAtom dispatchAmbulance =
      EmergencyHandoffFinancialAtom(
        id: 'dispatch_ambulance',
        label: 'Dispatch ambulance (fleet status; charge on trip)',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.dispatch,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom startTrip =
      EmergencyHandoffFinancialAtom(
        id: 'start_trip',
        label: 'Start ambulance trip (ops; charge on complete)',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.startTrip,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom completeTrip =
      EmergencyHandoffFinancialAtom(
        id: 'complete_trip',
        label: 'Complete ambulance trip (create deferred transport charge)',
        financialClass: EmergencyHandoffFinancialClass.createCharge,
        requirement: EmergencyHandoffAtomPermissions.completeTrip,
        billingPath:
            'updateAmbulanceTrip ended_at → persistAmbulanceTripBilling (idempotent)',
      );

  static const EmergencyHandoffFinancialAtom handoffOpd =
      EmergencyHandoffFinancialAtom(
        id: 'handoff_opd',
        label: 'Record handoff → OPD (deferred consultation invoice)',
        financialClass: EmergencyHandoffFinancialClass.defer,
        requirement: EmergencyHandoffAtomPermissions.handoff,
        billingPath:
            'handoffEmergencyCase → startOpdFlow create_consultation_invoice + clinical-request-billing',
      );

  static const EmergencyHandoffFinancialAtom handoffIpdIcu =
      EmergencyHandoffFinancialAtom(
        id: 'handoff_ipd_icu',
        label: 'Record handoff → IPD / ICU (deferred admission billing)',
        financialClass: EmergencyHandoffFinancialClass.defer,
        requirement: EmergencyHandoffAtomPermissions.handoff,
        billingPath:
            'handoffEmergencyCase → buildEmergencyAdmissionBilling → clinical-request-billing',
      );

  static const EmergencyHandoffFinancialAtom handoffTheater =
      EmergencyHandoffFinancialAtom(
        id: 'handoff_theater',
        label: 'Record handoff → Theater (deferred theatre billing)',
        financialClass: EmergencyHandoffFinancialClass.defer,
        requirement: EmergencyHandoffAtomPermissions.handoff,
        billingPath:
            'handoffEmergencyCase → buildEmergencyTheatreBilling → clinical-request-billing',
      );

  static const EmergencyHandoffFinancialAtom handoffTerminal =
      EmergencyHandoffFinancialAtom(
        id: 'handoff_terminal',
        label: 'Record handoff → Referral / Discharge (terminal)',
        financialClass: EmergencyHandoffFinancialClass.notBilled,
        requirement: EmergencyHandoffAtomPermissions.handoff,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyHandoffFinancialAtom billingDeferredChip =
      EmergencyHandoffFinancialAtom(
        id: 'billing_deferred_chip',
        label: 'Billing deferred chip / status (parity with Billing)',
        financialClass: EmergencyHandoffFinancialClass.defer,
        requirement: EmergencyHandoffAtomPermissions.detail,
        billingPath:
            'handoff.billing_deferred + billing_payment_status ↔ Billing PENDING',
        auditCode: 'DEFERRED',
      );

  static const EmergencyHandoffFinancialAtom openBilling =
      EmergencyHandoffFinancialAtom(
        id: 'open_billing',
        label:
            'Open billing (settle deferred / outstanding — Billing workspace)',
        financialClass: EmergencyHandoffFinancialClass.settle,
        requirement: EmergencyHandoffAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const EmergencyHandoffFinancialAtom scheduleTheater =
      EmergencyHandoffFinancialAtom(
        id: 'schedule_theater',
        label: 'Schedule in Theater (navigate; charges in Theater)',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.scheduleTheater,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom printSummary =
      EmergencyHandoffFinancialAtom(
        id: 'print_summary',
        label: 'Print summary',
        financialClass: EmergencyHandoffFinancialClass.noCharge,
        requirement: EmergencyHandoffAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const EmergencyHandoffFinancialAtom openInReceivingModule =
      EmergencyHandoffFinancialAtom(
        id: 'open_in_receiving_module',
        label: 'Open in OPD/IPD/ICU/Theater (navigate)',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.openInReceivingModule,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom careBeforeBilling =
      EmergencyHandoffFinancialAtom(
        id: 'care_before_billing',
        label: 'Care before billing chip (informational)',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom timelinePanel =
      EmergencyHandoffFinancialAtom(
        id: 'timeline_panel',
        label: 'Detail Triage and response timeline (read)',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.timelinePanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom ambulancePanel =
      EmergencyHandoffFinancialAtom(
        id: 'ambulance_panel',
        label: 'Detail Ambulance panel (dispatch / trip read)',
        financialClass: EmergencyHandoffFinancialClass.notRequired,
        requirement: EmergencyHandoffAtomPermissions.ambulancePanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyHandoffFinancialAtom procedureConsumable =
      EmergencyHandoffFinancialAtom(
        id: 'procedure_consumable',
        label: 'Procedure / consumable order (not mounted on Handoff ready)',
        financialClass: EmergencyHandoffFinancialClass.createCharge,
        requirement: EmergencyHandoffAtomPermissions.write,
        billingPath: 'clinical-request-billing (downstream clinical modules)',
        mounted: false,
      );

  static const EmergencyHandoffFinancialAtom collectPayment =
      EmergencyHandoffFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: EmergencyHandoffFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Handoff ready)',
        mounted: false,
      );

  static const EmergencyHandoffFinancialAtom adjustRefund =
      EmergencyHandoffFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: EmergencyHandoffFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const EmergencyHandoffFinancialAtom hardDelete =
      EmergencyHandoffFinancialAtom(
        id: 'hard_delete',
        label: 'Hard delete / void (no UI; gate kept)',
        financialClass: EmergencyHandoffFinancialClass.reverse,
        requirement: EmergencyHandoffAtomPermissions.delete,
        billingPath:
            'DELETE emergency-cases → must void/reverse Billing lines if added',
        mounted: false,
      );

  static const List<EmergencyHandoffFinancialAtom> atoms =
      <EmergencyHandoffFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        quickArrival,
        updatePriority,
        recordTriage,
        markResponse,
        dispatchAmbulance,
        startTrip,
        completeTrip,
        handoffOpd,
        handoffIpdIcu,
        handoffTheater,
        handoffTerminal,
        billingDeferredChip,
        openBilling,
        scheduleTheater,
        printSummary,
        openInReceivingModule,
        careBeforeBilling,
        timelinePanel,
        ambulancePanel,
        procedureConsumable,
        collectPayment,
        adjustRefund,
        hardDelete,
      ];

  static List<EmergencyHandoffFinancialAtom> get mountedAtoms => atoms
      .where((EmergencyHandoffFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static List<EmergencyHandoffFinancialAtom> get billableAtoms =>
      mountedAtoms
          .where(
            (EmergencyHandoffFinancialAtom atom) =>
                atom.financialClass ==
                    EmergencyHandoffFinancialClass.createCharge ||
                atom.financialClass == EmergencyHandoffFinancialClass.settle ||
                atom.financialClass == EmergencyHandoffFinancialClass.adjust ||
                atom.financialClass == EmergencyHandoffFinancialClass.reverse ||
                atom.financialClass == EmergencyHandoffFinancialClass.defer,
          )
          .toList(growable: false);

  static bool get allBillableAtomsWireThroughBilling {
    for (final EmergencyHandoffFinancialAtom atom in billableAtoms) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden — Billing owns payment.
  static bool isInlineCollectionForbidden(
    EmergencyHandoffFinancialClass financialClass,
  ) {
    return financialClass == EmergencyHandoffFinancialClass.settle ||
        financialClass == EmergencyHandoffFinancialClass.adjust ||
        financialClass == EmergencyHandoffFinancialClass.reverse;
  }
}

const String emergencyHandoffBillingScopeNote =
    'Emergency Handoff ready is the ward/OPD admit worklist. Record handoff '
    'posts deferred consultation / admission / theatre charges through '
    'handoffEmergencyCase → emergency-billing helpers → clinical-request-billing '
    '(PENDING / outstanding, idempotent charge keys). Terminal referral / '
    'discharge is NOT_BILLED. Complete trip posts deferred transport via '
    'persistAmbulanceTripBilling. Open billing navigates the Billing workspace; '
    'settle/adjust/refund are not cashiered here. Priority, triage, response, '
    'dispatch, print, and list chrome stay NOT_REQUIRED / NOT_BILLED / NO_CHARGE.';

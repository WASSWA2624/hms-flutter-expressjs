import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum EmergencyAmbulanceFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Emergency Ambulance
/// (`/emergency?scope=ambulance`).
@immutable
final class EmergencyAmbulanceFinancialAtom {
  const EmergencyAmbulanceFinancialAtom({
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
  final EmergencyAmbulanceFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/emergency?scope=ambulance`.
///
/// Dispatch / trips board. Urgent care may defer payment, but ambulance
/// transport and deferred handoff charges still post Billing records
/// (PENDING / outstanding) via `persistAmbulanceTripBilling` /
/// emergency-billing helpers. Settlement stays on the Billing workspace —
/// this tab never mounts a parallel cashier.
abstract final class EmergencyAmbulanceBillingInventory {
  static const EmergencyAmbulanceFinancialAtom tab =
      EmergencyAmbulanceFinancialAtom(
        id: 'tab',
        label: 'Ambulance tab / count badge',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom listChrome =
      EmergencyAmbulanceFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / columns',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom emptyLoadingError =
      EmergencyAmbulanceFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom rowSelect =
      EmergencyAmbulanceFinancialAtom(
        id: 'row_select',
        label: 'Row select → case detail',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom quickArrival =
      EmergencyAmbulanceFinancialAtom(
        id: 'quick_arrival',
        label: 'Quick arrival (patient + case intake)',
        financialClass: EmergencyAmbulanceFinancialClass.notBilled,
        requirement: EmergencyAmbulanceAtomPermissions.quickArrival,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyAmbulanceFinancialAtom updatePriority =
      EmergencyAmbulanceFinancialAtom(
        id: 'update_priority',
        label: 'Update priority / severity',
        financialClass: EmergencyAmbulanceFinancialClass.notBilled,
        requirement: EmergencyAmbulanceAtomPermissions.updatePriority,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyAmbulanceFinancialAtom recordTriage =
      EmergencyAmbulanceFinancialAtom(
        id: 'record_triage',
        label: 'Record triage',
        financialClass: EmergencyAmbulanceFinancialClass.notBilled,
        requirement: EmergencyAmbulanceAtomPermissions.triage,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyAmbulanceFinancialAtom markResponse =
      EmergencyAmbulanceFinancialAtom(
        id: 'mark_response',
        label: 'Mark emergency response',
        financialClass: EmergencyAmbulanceFinancialClass.notBilled,
        requirement: EmergencyAmbulanceAtomPermissions.response,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyAmbulanceFinancialAtom dispatchAmbulance =
      EmergencyAmbulanceFinancialAtom(
        id: 'dispatch_ambulance',
        label: 'Dispatch ambulance (fleet status; charge on trip)',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.dispatch,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom updateDispatchStatus =
      EmergencyAmbulanceFinancialAtom(
        id: 'update_dispatch_status',
        label: 'Update dispatch status',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.dispatch,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom startTrip =
      EmergencyAmbulanceFinancialAtom(
        id: 'start_trip',
        label: 'Start ambulance trip (ops; charge on complete)',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.startTrip,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom completeTrip =
      EmergencyAmbulanceFinancialAtom(
        id: 'complete_trip',
        label: 'Complete ambulance trip (create deferred transport charge)',
        financialClass: EmergencyAmbulanceFinancialClass.createCharge,
        requirement: EmergencyAmbulanceAtomPermissions.completeTrip,
        billingPath:
            'updateAmbulanceTrip ended_at → persistAmbulanceTripBilling (idempotent)',
      );

  static const EmergencyAmbulanceFinancialAtom handoffDeferred =
      EmergencyAmbulanceFinancialAtom(
        id: 'handoff_deferred',
        label: 'Record handoff (deferred admission / theatre / consult)',
        financialClass: EmergencyAmbulanceFinancialClass.defer,
        requirement: EmergencyAmbulanceAtomPermissions.handoff,
        billingPath:
            'handoffEmergencyCase → buildEmergency*Billing → clinical-request-billing',
      );

  static const EmergencyAmbulanceFinancialAtom billingDeferredChip =
      EmergencyAmbulanceFinancialAtom(
        id: 'billing_deferred_chip',
        label: 'Billing deferred chip / message (parity with Billing)',
        financialClass: EmergencyAmbulanceFinancialClass.defer,
        requirement: EmergencyAmbulanceAtomPermissions.detail,
        billingPath:
            'handoff.billing_deferred + billing_payment_status ↔ Billing PENDING',
        auditCode: 'DEFERRED',
      );

  static const EmergencyAmbulanceFinancialAtom tripBillingStatus =
      EmergencyAmbulanceFinancialAtom(
        id: 'trip_billing_status',
        label: 'Ambulance trip payment status (parity with Billing)',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.ambulanceContext,
        billingPath:
            'trip.billing_payment_status from persistAmbulanceTripBilling snapshot',
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom openBilling =
      EmergencyAmbulanceFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: EmergencyAmbulanceFinancialClass.settle,
        requirement: EmergencyAmbulanceAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const EmergencyAmbulanceFinancialAtom scheduleTheater =
      EmergencyAmbulanceFinancialAtom(
        id: 'schedule_theater',
        label: 'Schedule in Theater (navigate; charges in Theater)',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.scheduleTheater,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom printSummary =
      EmergencyAmbulanceFinancialAtom(
        id: 'print_summary',
        label: 'Print summary',
        financialClass: EmergencyAmbulanceFinancialClass.noCharge,
        requirement: EmergencyAmbulanceAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const EmergencyAmbulanceFinancialAtom careBeforeBilling =
      EmergencyAmbulanceFinancialAtom(
        id: 'care_before_billing',
        label: 'Care before billing chip (informational)',
        financialClass: EmergencyAmbulanceFinancialClass.notRequired,
        requirement: EmergencyAmbulanceAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAmbulanceFinancialAtom procedureConsumable =
      EmergencyAmbulanceFinancialAtom(
        id: 'procedure_consumable',
        label: 'Procedure / consumable order (not mounted on Ambulance)',
        financialClass: EmergencyAmbulanceFinancialClass.createCharge,
        requirement: EmergencyAmbulanceAtomPermissions.write,
        billingPath: 'clinical-request-billing (downstream clinical modules)',
        mounted: false,
      );

  static const EmergencyAmbulanceFinancialAtom collectPayment =
      EmergencyAmbulanceFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: EmergencyAmbulanceFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Ambulance)',
        mounted: false,
      );

  static const EmergencyAmbulanceFinancialAtom adjustRefund =
      EmergencyAmbulanceFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: EmergencyAmbulanceFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const EmergencyAmbulanceFinancialAtom hardDelete =
      EmergencyAmbulanceFinancialAtom(
        id: 'hard_delete',
        label: 'Hard delete / void (no UI; gate kept)',
        financialClass: EmergencyAmbulanceFinancialClass.reverse,
        requirement: EmergencyAmbulanceAtomPermissions.delete,
        billingPath:
            'DELETE → must void/reverse Billing lines if added',
        mounted: false,
      );

  static const List<EmergencyAmbulanceFinancialAtom> all =
      <EmergencyAmbulanceFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        quickArrival,
        updatePriority,
        recordTriage,
        markResponse,
        dispatchAmbulance,
        updateDispatchStatus,
        startTrip,
        completeTrip,
        handoffDeferred,
        billingDeferredChip,
        tripBillingStatus,
        openBilling,
        scheduleTheater,
        printSummary,
        careBeforeBilling,
        procedureConsumable,
        collectPayment,
        adjustRefund,
        hardDelete,
      ];

  static Iterable<EmergencyAmbulanceFinancialAtom> get mountedAtoms =>
      all.where((EmergencyAmbulanceFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static Iterable<EmergencyAmbulanceFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (EmergencyAmbulanceFinancialAtom atom) =>
            atom.financialClass ==
                EmergencyAmbulanceFinancialClass.createCharge ||
            atom.financialClass == EmergencyAmbulanceFinancialClass.settle ||
            atom.financialClass == EmergencyAmbulanceFinancialClass.adjust ||
            atom.financialClass == EmergencyAmbulanceFinancialClass.reverse ||
            atom.financialClass == EmergencyAmbulanceFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final EmergencyAmbulanceFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden — Billing owns payment.
  static bool isInlineCollectionForbidden(
    EmergencyAmbulanceFinancialClass financialClass,
  ) {
    return financialClass == EmergencyAmbulanceFinancialClass.settle ||
        financialClass == EmergencyAmbulanceFinancialClass.adjust ||
        financialClass == EmergencyAmbulanceFinancialClass.reverse;
  }
}

const String emergencyAmbulanceBillingScopeNote =
    'Emergency Ambulance is the dispatch / trips worklist. Completing a trip '
    'posts a deferred transport charge via persistAmbulanceTripBilling '
    '(SERVICE source, PENDING, idempotent on trip id). Start trip is '
    'operational only unless an explicit billing payload or ended_at is '
    'supplied at create. Handoff may defer admission/theatre/consult fees '
    'through emergency-billing helpers into clinical-request-billing. Open '
    'billing navigates the Billing workspace; settle/adjust/refund are not '
    'cashiered here. Dispatch status, triage, response, priority, print, and '
    'list chrome stay NOT_REQUIRED / NOT_BILLED / NO_CHARGE.';

import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum EmergencyCriticalFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Emergency Critical
/// (`/emergency?scope=critical`).
@immutable
final class EmergencyCriticalFinancialAtom {
  const EmergencyCriticalFinancialAtom({
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
  final EmergencyCriticalFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/emergency?scope=critical`.
///
/// Critical acuity filter of open ED cases. Same mutation surface as Active
/// cases, scoped to `isCritical`. Urgent care may defer payment when policy
/// allows, but deferred handoff / ambulance / procedure / consumable charges
/// still post Billing records (PENDING / outstanding). Settle / adjust /
/// refund stay on the Billing workspace — this tab never mounts a parallel
/// cashier.
abstract final class EmergencyCriticalBillingInventory {
  static const EmergencyCriticalFinancialAtom tab =
      EmergencyCriticalFinancialAtom(
        id: 'tab',
        label: 'Critical tab / count badge',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom listChrome =
      EmergencyCriticalFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / columns',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom emptyLoadingError =
      EmergencyCriticalFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom criticalChip =
      EmergencyCriticalFinancialAtom(
        id: 'critical_chip',
        label: 'Critical row highlight / priority chip',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.criticalChip,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom rowSelect =
      EmergencyCriticalFinancialAtom(
        id: 'row_select',
        label: 'Row select → case detail',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom quickArrival =
      EmergencyCriticalFinancialAtom(
        id: 'quick_arrival',
        label: 'Quick arrival (patient + case; no ED visit fee atom)',
        financialClass: EmergencyCriticalFinancialClass.notBilled,
        requirement: EmergencyCriticalAtomPermissions.quickArrival,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyCriticalFinancialAtom updatePriority =
      EmergencyCriticalFinancialAtom(
        id: 'update_priority',
        label: 'Update priority / severity',
        financialClass: EmergencyCriticalFinancialClass.notBilled,
        requirement: EmergencyCriticalAtomPermissions.updatePriority,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyCriticalFinancialAtom recordTriage =
      EmergencyCriticalFinancialAtom(
        id: 'record_triage',
        label: 'Record triage',
        financialClass: EmergencyCriticalFinancialClass.notBilled,
        requirement: EmergencyCriticalAtomPermissions.recordTriage,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyCriticalFinancialAtom markResponse =
      EmergencyCriticalFinancialAtom(
        id: 'mark_response',
        label: 'Mark emergency response',
        financialClass: EmergencyCriticalFinancialClass.notBilled,
        requirement: EmergencyCriticalAtomPermissions.markResponse,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyCriticalFinancialAtom dispatchAmbulance =
      EmergencyCriticalFinancialAtom(
        id: 'dispatch_ambulance',
        label: 'Dispatch ambulance (fleet status; charge on trip)',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.dispatch,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom updateDispatchStatus =
      EmergencyCriticalFinancialAtom(
        id: 'update_dispatch_status',
        label: 'Update dispatch status',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.dispatch,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom startTrip =
      EmergencyCriticalFinancialAtom(
        id: 'start_trip',
        label: 'Start ambulance trip (+ deferred transport charge when billed)',
        financialClass: EmergencyCriticalFinancialClass.createCharge,
        requirement: EmergencyCriticalAtomPermissions.startTrip,
        billingPath:
            'ambulance-trip → persistAmbulanceTripBilling (SERVICE / PENDING)',
      );

  static const EmergencyCriticalFinancialAtom completeTrip =
      EmergencyCriticalFinancialAtom(
        id: 'complete_trip',
        label: 'Complete ambulance trip (idempotent Billing replay)',
        financialClass: EmergencyCriticalFinancialClass.createCharge,
        requirement: EmergencyCriticalAtomPermissions.completeTrip,
        billingPath:
            'ambulance-trip update → persistAmbulanceTripBilling (idempotent)',
      );

  static const EmergencyCriticalFinancialAtom handoffOpd =
      EmergencyCriticalFinancialAtom(
        id: 'handoff_opd',
        label: 'Handoff → OPD (deferred consultation invoice)',
        financialClass: EmergencyCriticalFinancialClass.defer,
        requirement: EmergencyCriticalAtomPermissions.handoff,
        billingPath:
            'startOpdFlow create_consultation_invoice + persistConsultationBilling',
      );

  static const EmergencyCriticalFinancialAtom handoffIpdIcu =
      EmergencyCriticalFinancialAtom(
        id: 'handoff_ipd_icu',
        label: 'Handoff → IPD / ICU (deferred admission billing)',
        financialClass: EmergencyCriticalFinancialClass.defer,
        requirement: EmergencyCriticalAtomPermissions.handoff,
        billingPath:
            'startIpdFlow persistAdmissionBilling / emergency-billing helper',
      );

  static const EmergencyCriticalFinancialAtom handoffTheater =
      EmergencyCriticalFinancialAtom(
        id: 'handoff_theater',
        label: 'Handoff → Theater (deferred theatre billing)',
        financialClass: EmergencyCriticalFinancialClass.defer,
        requirement: EmergencyCriticalAtomPermissions.handoff,
        billingPath: 'startTheatreFlow persistTheatreCaseBilling',
      );

  static const EmergencyCriticalFinancialAtom handoffTerminal =
      EmergencyCriticalFinancialAtom(
        id: 'handoff_terminal',
        label: 'Handoff → Referral / Discharge (terminal)',
        financialClass: EmergencyCriticalFinancialClass.notBilled,
        requirement: EmergencyCriticalAtomPermissions.handoff,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyCriticalFinancialAtom billingDeferredBadge =
      EmergencyCriticalFinancialAtom(
        id: 'billing_deferred_badge',
        label: 'Billing deferred badge / message (parity with Billing)',
        financialClass: EmergencyCriticalFinancialClass.defer,
        requirement: EmergencyCriticalAtomPermissions.detail,
        billingPath:
            'handoff.billing_deferred + billing_payment_status ↔ Billing PENDING',
        auditCode: 'DEFERRED',
      );

  static const EmergencyCriticalFinancialAtom tripBillingStatus =
      EmergencyCriticalFinancialAtom(
        id: 'trip_billing_status',
        label: 'Ambulance trip payment status (parity with Billing)',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.ambulanceContext,
        billingPath:
            'trip.billing_payment_status from persistAmbulanceTripBilling snapshot',
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom openBilling =
      EmergencyCriticalFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: EmergencyCriticalFinancialClass.settle,
        requirement: EmergencyCriticalAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const EmergencyCriticalFinancialAtom careBeforeBilling =
      EmergencyCriticalFinancialAtom(
        id: 'care_before_billing',
        label: 'Care before billing chip (informational)',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom scheduleTheater =
      EmergencyCriticalFinancialAtom(
        id: 'schedule_theater',
        label: 'Schedule in Theater (navigate; charges in Theater)',
        financialClass: EmergencyCriticalFinancialClass.notRequired,
        requirement: EmergencyCriticalAtomPermissions.scheduleTheater,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyCriticalFinancialAtom printSummary =
      EmergencyCriticalFinancialAtom(
        id: 'print_summary',
        label: 'Print summary',
        financialClass: EmergencyCriticalFinancialClass.noCharge,
        requirement: EmergencyCriticalAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const EmergencyCriticalFinancialAtom procedure =
      EmergencyCriticalFinancialAtom(
        id: 'procedure',
        label: 'ED procedure order (not mounted on Critical)',
        financialClass: EmergencyCriticalFinancialClass.createCharge,
        requirement: EmergencyCriticalAtomPermissions.write,
        billingPath: 'persistProcedureBilling (clinical-request-billing)',
        mounted: false,
      );

  static const EmergencyCriticalFinancialAtom consumable =
      EmergencyCriticalFinancialAtom(
        id: 'consumable',
        label: 'ED consumable charge (not mounted on Critical)',
        financialClass: EmergencyCriticalFinancialClass.createCharge,
        requirement: EmergencyCriticalAtomPermissions.write,
        billingPath: 'persistConsumableBilling (clinical-request-billing)',
        mounted: false,
      );

  static const EmergencyCriticalFinancialAtom collectPayment =
      EmergencyCriticalFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: EmergencyCriticalFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Critical)',
        mounted: false,
      );

  static const EmergencyCriticalFinancialAtom adjustRefund =
      EmergencyCriticalFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: EmergencyCriticalFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const EmergencyCriticalFinancialAtom hardDelete =
      EmergencyCriticalFinancialAtom(
        id: 'hard_delete',
        label: 'Hard delete / void (no UI; gate kept)',
        financialClass: EmergencyCriticalFinancialClass.reverse,
        requirement: EmergencyCriticalAtomPermissions.delete,
        billingPath: 'DELETE → must void/reverse Billing lines if added',
        mounted: false,
      );

  static const List<EmergencyCriticalFinancialAtom> all =
      <EmergencyCriticalFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        criticalChip,
        rowSelect,
        quickArrival,
        updatePriority,
        recordTriage,
        markResponse,
        dispatchAmbulance,
        updateDispatchStatus,
        startTrip,
        completeTrip,
        handoffOpd,
        handoffIpdIcu,
        handoffTheater,
        handoffTerminal,
        billingDeferredBadge,
        tripBillingStatus,
        openBilling,
        careBeforeBilling,
        scheduleTheater,
        printSummary,
        procedure,
        consumable,
        collectPayment,
        adjustRefund,
        hardDelete,
      ];

  static Iterable<EmergencyCriticalFinancialAtom> get mountedAtoms =>
      all.where((EmergencyCriticalFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static Iterable<EmergencyCriticalFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (EmergencyCriticalFinancialAtom atom) =>
            atom.financialClass ==
                EmergencyCriticalFinancialClass.createCharge ||
            atom.financialClass == EmergencyCriticalFinancialClass.settle ||
            atom.financialClass == EmergencyCriticalFinancialClass.adjust ||
            atom.financialClass == EmergencyCriticalFinancialClass.reverse ||
            atom.financialClass == EmergencyCriticalFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final EmergencyCriticalFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden — Billing owns payment.
  static bool isInlineCollectionForbidden(
    EmergencyCriticalFinancialClass financialClass,
  ) {
    return financialClass == EmergencyCriticalFinancialClass.settle ||
        financialClass == EmergencyCriticalFinancialClass.adjust ||
        financialClass == EmergencyCriticalFinancialClass.reverse;
  }

  static String summary() =>
      'Critical filters open high-acuity cases. Defers payment when policy '
      'allows but posts deferred handoff / ambulance charges through '
      'clinical-request-billing. Open billing navigates Billing. No module '
      'cashier.';
}

const String emergencyCriticalBillingScopeNote =
    'Emergency Critical is the acuity filter (?scope=critical). Completing or '
    'starting a billed ambulance trip posts deferred transport via '
    'persistAmbulanceTripBilling (SERVICE source, PENDING, idempotent on trip '
    'id). Handoff may defer admission/theatre/consult fees through '
    'emergency-billing helpers into clinical-request-billing. Open billing '
    'navigates the Billing workspace; settle/adjust/refund are not cashiered '
    'here. Triage, response, priority, print, critical chip, and list chrome '
    'stay NOT_REQUIRED / NOT_BILLED / NO_CHARGE.';

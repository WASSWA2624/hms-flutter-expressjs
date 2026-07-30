import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum EmergencyActiveCasesFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Emergency Active cases
/// (`/emergency?scope=active`).
@immutable
final class EmergencyActiveCasesFinancialAtom {
  const EmergencyActiveCasesFinancialAtom({
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
  final EmergencyActiveCasesFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/emergency?scope=active`.
///
/// Live ED board; Quick arrival primary. Urgent care may defer payment when
/// policy allows, but deferred handoff / ambulance / procedure / consumable
/// charges still post Billing records (PENDING / outstanding). Settle /
/// adjust / refund stay on the Billing workspace — this tab never mounts a
/// parallel cashier.
abstract final class EmergencyActiveCasesBillingInventory {
  static const EmergencyActiveCasesFinancialAtom tab =
      EmergencyActiveCasesFinancialAtom(
        id: 'tab',
        label: 'Active cases tab / count badge',
        financialClass: EmergencyActiveCasesFinancialClass.notRequired,
        requirement: EmergencyActiveCasesAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyActiveCasesFinancialAtom listChrome =
      EmergencyActiveCasesFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: EmergencyActiveCasesFinancialClass.notRequired,
        requirement: EmergencyActiveCasesAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyActiveCasesFinancialAtom emptyLoadingError =
      EmergencyActiveCasesFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: EmergencyActiveCasesFinancialClass.notRequired,
        requirement: EmergencyActiveCasesAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyActiveCasesFinancialAtom rowSelect =
      EmergencyActiveCasesFinancialAtom(
        id: 'row_select',
        label: 'Row select → case detail',
        financialClass: EmergencyActiveCasesFinancialClass.notRequired,
        requirement: EmergencyActiveCasesAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyActiveCasesFinancialAtom quickArrival =
      EmergencyActiveCasesFinancialAtom(
        id: 'quick_arrival',
        label: 'Quick arrival (patient + case; no ED visit fee atom)',
        financialClass: EmergencyActiveCasesFinancialClass.notBilled,
        requirement: EmergencyActiveCasesAtomPermissions.quickArrival,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyActiveCasesFinancialAtom updatePriority =
      EmergencyActiveCasesFinancialAtom(
        id: 'update_priority',
        label: 'Update priority / severity',
        financialClass: EmergencyActiveCasesFinancialClass.notBilled,
        requirement: EmergencyActiveCasesAtomPermissions.updatePriority,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyActiveCasesFinancialAtom recordTriage =
      EmergencyActiveCasesFinancialAtom(
        id: 'record_triage',
        label: 'Record triage',
        financialClass: EmergencyActiveCasesFinancialClass.notBilled,
        requirement: EmergencyActiveCasesAtomPermissions.recordTriage,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyActiveCasesFinancialAtom markResponse =
      EmergencyActiveCasesFinancialAtom(
        id: 'mark_response',
        label: 'Mark emergency response',
        financialClass: EmergencyActiveCasesFinancialClass.notBilled,
        requirement: EmergencyActiveCasesAtomPermissions.markResponse,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyActiveCasesFinancialAtom dispatchAmbulance =
      EmergencyActiveCasesFinancialAtom(
        id: 'dispatch_ambulance',
        label: 'Dispatch ambulance (fleet status; charge on trip)',
        financialClass: EmergencyActiveCasesFinancialClass.notRequired,
        requirement: EmergencyActiveCasesAtomPermissions.dispatch,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyActiveCasesFinancialAtom startTrip =
      EmergencyActiveCasesFinancialAtom(
        id: 'start_trip',
        label: 'Start ambulance trip (+ deferred transport charge)',
        financialClass: EmergencyActiveCasesFinancialClass.createCharge,
        requirement: EmergencyActiveCasesAtomPermissions.startTrip,
        billingPath:
            'ambulance-trip → persistAmbulanceTripBilling (SERVICE / PENDING)',
      );

  static const EmergencyActiveCasesFinancialAtom completeTrip =
      EmergencyActiveCasesFinancialAtom(
        id: 'complete_trip',
        label: 'Complete ambulance trip (idempotent Billing replay)',
        financialClass: EmergencyActiveCasesFinancialClass.createCharge,
        requirement: EmergencyActiveCasesAtomPermissions.completeTrip,
        billingPath:
            'ambulance-trip update → persistAmbulanceTripBilling (idempotent)',
      );

  static const EmergencyActiveCasesFinancialAtom handoffOpd =
      EmergencyActiveCasesFinancialAtom(
        id: 'handoff_opd',
        label: 'Handoff → OPD (deferred consultation invoice)',
        financialClass: EmergencyActiveCasesFinancialClass.defer,
        requirement: EmergencyActiveCasesAtomPermissions.handoff,
        billingPath:
            'startOpdFlow create_consultation_invoice + persistConsultationBilling',
      );

  static const EmergencyActiveCasesFinancialAtom handoffIpdIcu =
      EmergencyActiveCasesFinancialAtom(
        id: 'handoff_ipd_icu',
        label: 'Handoff → IPD / ICU (deferred admission billing)',
        financialClass: EmergencyActiveCasesFinancialClass.defer,
        requirement: EmergencyActiveCasesAtomPermissions.handoff,
        billingPath:
            'startIpdFlow persistAdmissionBilling / emergency-billing helper',
      );

  static const EmergencyActiveCasesFinancialAtom handoffTheater =
      EmergencyActiveCasesFinancialAtom(
        id: 'handoff_theater',
        label: 'Handoff → Theater (deferred theatre billing)',
        financialClass: EmergencyActiveCasesFinancialClass.defer,
        requirement: EmergencyActiveCasesAtomPermissions.handoff,
        billingPath: 'startTheatreFlow persistTheatreCaseBilling',
      );

  static const EmergencyActiveCasesFinancialAtom handoffTerminal =
      EmergencyActiveCasesFinancialAtom(
        id: 'handoff_terminal',
        label: 'Handoff → Referral / Discharge (terminal)',
        financialClass: EmergencyActiveCasesFinancialClass.notBilled,
        requirement: EmergencyActiveCasesAtomPermissions.handoff,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyActiveCasesFinancialAtom billingDeferredBadge =
      EmergencyActiveCasesFinancialAtom(
        id: 'billing_deferred_badge',
        label: 'Billing deferred badge / message (parity with Billing)',
        financialClass: EmergencyActiveCasesFinancialClass.defer,
        requirement: EmergencyActiveCasesAtomPermissions.detail,
        billingPath: 'handoff.billing_deferred + billing_payment_status',
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyActiveCasesFinancialAtom openBilling =
      EmergencyActiveCasesFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: EmergencyActiveCasesFinancialClass.defer,
        requirement: EmergencyActiveCasesAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const EmergencyActiveCasesFinancialAtom careBeforeBilling =
      EmergencyActiveCasesFinancialAtom(
        id: 'care_before_billing',
        label: 'Care before billing chip (informational)',
        financialClass: EmergencyActiveCasesFinancialClass.notRequired,
        requirement: EmergencyActiveCasesAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyActiveCasesFinancialAtom scheduleTheater =
      EmergencyActiveCasesFinancialAtom(
        id: 'schedule_theater',
        label: 'Schedule in Theater (navigate; charges in Theater)',
        financialClass: EmergencyActiveCasesFinancialClass.notRequired,
        requirement: EmergencyActiveCasesAtomPermissions.scheduleTheater,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyActiveCasesFinancialAtom printSummary =
      EmergencyActiveCasesFinancialAtom(
        id: 'print_summary',
        label: 'Print summary',
        financialClass: EmergencyActiveCasesFinancialClass.notRequired,
        requirement: EmergencyActiveCasesAtomPermissions.printSummary,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyActiveCasesFinancialAtom procedure =
      EmergencyActiveCasesFinancialAtom(
        id: 'procedure',
        label: 'ED procedure order (not mounted on Active cases)',
        financialClass: EmergencyActiveCasesFinancialClass.createCharge,
        requirement: EmergencyActiveCasesAtomPermissions.write,
        billingPath: 'persistProcedureBilling (clinical-request-billing)',
        mounted: false,
      );

  static const EmergencyActiveCasesFinancialAtom consumable =
      EmergencyActiveCasesFinancialAtom(
        id: 'consumable',
        label: 'ED consumable charge (not mounted on Active cases)',
        financialClass: EmergencyActiveCasesFinancialClass.createCharge,
        requirement: EmergencyActiveCasesAtomPermissions.write,
        billingPath: 'persistConsumableBilling (clinical-request-billing)',
        mounted: false,
      );

  static const EmergencyActiveCasesFinancialAtom collectPayment =
      EmergencyActiveCasesFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: EmergencyActiveCasesFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Active cases)',
        mounted: false,
      );

  static const EmergencyActiveCasesFinancialAtom adjustRefund =
      EmergencyActiveCasesFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: EmergencyActiveCasesFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<EmergencyActiveCasesFinancialAtom> all =
      <EmergencyActiveCasesFinancialAtom>[
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
        billingDeferredBadge,
        openBilling,
        careBeforeBilling,
        scheduleTheater,
        printSummary,
        procedure,
        consumable,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<EmergencyActiveCasesFinancialAtom> get mountedAtoms =>
      all.where((EmergencyActiveCasesFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<EmergencyActiveCasesFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (EmergencyActiveCasesFinancialAtom atom) =>
            atom.financialClass ==
                EmergencyActiveCasesFinancialClass.createCharge ||
            atom.financialClass == EmergencyActiveCasesFinancialClass.settle ||
            atom.financialClass == EmergencyActiveCasesFinancialClass.adjust ||
            atom.financialClass == EmergencyActiveCasesFinancialClass.reverse ||
            atom.financialClass == EmergencyActiveCasesFinancialClass.defer,
      );

  static bool forbidsInlineCashier(
    EmergencyActiveCasesFinancialClass actionClass,
  ) {
    return switch (actionClass) {
      EmergencyActiveCasesFinancialClass.settle ||
      EmergencyActiveCasesFinancialClass.adjust ||
      EmergencyActiveCasesFinancialClass.reverse ||
      EmergencyActiveCasesFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'Active cases defers payment when policy allows but posts deferred '
      'handoff / ambulance charges through clinical-request-billing. Open '
      'billing navigates Billing. No module cashier.';
}

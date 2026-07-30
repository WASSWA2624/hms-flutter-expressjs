import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum EmergencyAllFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Emergency All (`/emergency?scope=all`).
@immutable
final class EmergencyAllFinancialAtom {
  const EmergencyAllFinancialAtom({
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
  final EmergencyAllFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/emergency?scope=all` (unfiltered board).
///
/// Urgent care may defer payment when policy allows, but deferred handoff,
/// ambulance, procedure, and consumable charges still post Billing records
/// (PENDING / outstanding). Settle / adjust / refund stay on the Billing
/// workspace — this tab never mounts a parallel cashier.
abstract final class EmergencyAllBillingInventory {
  static const EmergencyAllFinancialAtom tab = EmergencyAllFinancialAtom(
    id: 'tab',
    label: 'All tab / count badge',
    financialClass: EmergencyAllFinancialClass.notRequired,
    requirement: EmergencyAllAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const EmergencyAllFinancialAtom listChrome = EmergencyAllFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / pagination',
    financialClass: EmergencyAllFinancialClass.notRequired,
    requirement: EmergencyAllAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const EmergencyAllFinancialAtom emptyLoadingError =
      EmergencyAllFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: EmergencyAllFinancialClass.notRequired,
        requirement: EmergencyAllAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAllFinancialAtom rowSelect = EmergencyAllFinancialAtom(
    id: 'row_select',
    label: 'Row select → case detail',
    financialClass: EmergencyAllFinancialClass.notRequired,
    requirement: EmergencyAllAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const EmergencyAllFinancialAtom quickArrival =
      EmergencyAllFinancialAtom(
        id: 'quick_arrival',
        label: 'Quick arrival (patient + case; no ED visit fee atom)',
        financialClass: EmergencyAllFinancialClass.notBilled,
        requirement: EmergencyAllAtomPermissions.quickArrival,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyAllFinancialAtom updatePriority =
      EmergencyAllFinancialAtom(
        id: 'update_priority',
        label: 'Update priority / severity',
        financialClass: EmergencyAllFinancialClass.notBilled,
        requirement: EmergencyAllAtomPermissions.updatePriority,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyAllFinancialAtom recordTriage =
      EmergencyAllFinancialAtom(
        id: 'record_triage',
        label: 'Record triage',
        financialClass: EmergencyAllFinancialClass.notBilled,
        requirement: EmergencyAllAtomPermissions.recordTriage,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyAllFinancialAtom markResponse =
      EmergencyAllFinancialAtom(
        id: 'mark_response',
        label: 'Mark emergency response',
        financialClass: EmergencyAllFinancialClass.notBilled,
        requirement: EmergencyAllAtomPermissions.markResponse,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyAllFinancialAtom dispatchAmbulance =
      EmergencyAllFinancialAtom(
        id: 'dispatch_ambulance',
        label: 'Dispatch ambulance (fleet status; charge on trip complete)',
        financialClass: EmergencyAllFinancialClass.notRequired,
        requirement: EmergencyAllAtomPermissions.dispatch,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAllFinancialAtom startTrip = EmergencyAllFinancialAtom(
    id: 'start_trip',
    label: 'Start ambulance trip (ops; charge on complete)',
    financialClass: EmergencyAllFinancialClass.notRequired,
    requirement: EmergencyAllAtomPermissions.startTrip,
    auditCode: 'NOT_REQUIRED',
  );

  static const EmergencyAllFinancialAtom completeTrip =
      EmergencyAllFinancialAtom(
        id: 'complete_trip',
        label: 'Complete ambulance trip → deferred transport charge',
        financialClass: EmergencyAllFinancialClass.createCharge,
        requirement: EmergencyAllAtomPermissions.completeTrip,
        billingPath:
            'ambulance-trip → persistAmbulanceTripBilling (SERVICE / PENDING)',
      );

  static const EmergencyAllFinancialAtom handoffOpd = EmergencyAllFinancialAtom(
    id: 'handoff_opd',
    label: 'Handoff → OPD (deferred consultation invoice)',
    financialClass: EmergencyAllFinancialClass.defer,
    requirement: EmergencyAllAtomPermissions.handoff,
    billingPath:
        'startOpdFlow create_consultation_invoice + persistConsultationBilling',
  );

  static const EmergencyAllFinancialAtom handoffIpdIcu =
      EmergencyAllFinancialAtom(
        id: 'handoff_ipd_icu',
        label: 'Handoff → IPD / ICU (deferred admission billing)',
        financialClass: EmergencyAllFinancialClass.defer,
        requirement: EmergencyAllAtomPermissions.handoff,
        billingPath:
            'startIpdFlow persistAdmissionBilling / emergency-billing helper',
      );

  static const EmergencyAllFinancialAtom handoffTheater =
      EmergencyAllFinancialAtom(
        id: 'handoff_theater',
        label: 'Handoff → Theater (deferred theatre billing)',
        financialClass: EmergencyAllFinancialClass.defer,
        requirement: EmergencyAllAtomPermissions.handoff,
        billingPath: 'startTheatreFlow persistTheatreCaseBilling',
      );

  static const EmergencyAllFinancialAtom handoffTerminal =
      EmergencyAllFinancialAtom(
        id: 'handoff_terminal',
        label: 'Handoff → Referral / Discharge (terminal)',
        financialClass: EmergencyAllFinancialClass.notBilled,
        requirement: EmergencyAllAtomPermissions.handoff,
        auditCode: 'NOT_BILLED',
      );

  static const EmergencyAllFinancialAtom billingDeferredBadge =
      EmergencyAllFinancialAtom(
        id: 'billing_deferred_badge',
        label: 'Billing deferred badge / status (parity with Billing)',
        financialClass: EmergencyAllFinancialClass.defer,
        requirement: EmergencyAllAtomPermissions.detail,
        billingPath: 'handoff.billing_deferred + billing_payment_status',
      );

  static const EmergencyAllFinancialAtom openBilling =
      EmergencyAllFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: EmergencyAllFinancialClass.settle,
        requirement: EmergencyAllAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const EmergencyAllFinancialAtom careBeforeBilling =
      EmergencyAllFinancialAtom(
        id: 'care_before_billing',
        label: 'Care before billing chip (informational)',
        financialClass: EmergencyAllFinancialClass.notRequired,
        requirement: EmergencyAllAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAllFinancialAtom scheduleTheater =
      EmergencyAllFinancialAtom(
        id: 'schedule_theater',
        label: 'Schedule in Theater (navigate; charges in Theater)',
        financialClass: EmergencyAllFinancialClass.notRequired,
        requirement: EmergencyAllAtomPermissions.scheduleTheater,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAllFinancialAtom printSummary =
      EmergencyAllFinancialAtom(
        id: 'print_summary',
        label: 'Print summary',
        financialClass: EmergencyAllFinancialClass.notRequired,
        requirement: EmergencyAllAtomPermissions.printSummary,
        auditCode: 'NOT_REQUIRED',
      );

  static const EmergencyAllFinancialAtom procedure = EmergencyAllFinancialAtom(
    id: 'procedure',
    label: 'ED procedure order (not mounted on All)',
    financialClass: EmergencyAllFinancialClass.createCharge,
    requirement: EmergencyAllAtomPermissions.write,
    billingPath: 'persistProcedureBilling (clinical-request-billing)',
    mounted: false,
  );

  static const EmergencyAllFinancialAtom consumable = EmergencyAllFinancialAtom(
    id: 'consumable',
    label: 'ED consumable charge (not mounted on All)',
    financialClass: EmergencyAllFinancialClass.createCharge,
    requirement: EmergencyAllAtomPermissions.write,
    billingPath: 'persistConsumableBilling (clinical-request-billing)',
    mounted: false,
  );

  static const EmergencyAllFinancialAtom collectPayment =
      EmergencyAllFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: EmergencyAllFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on All)',
        mounted: false,
      );

  static const EmergencyAllFinancialAtom adjustRefund =
      EmergencyAllFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: EmergencyAllFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<EmergencyAllFinancialAtom> atoms =
      <EmergencyAllFinancialAtom>[
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

  static Iterable<EmergencyAllFinancialAtom> get mountedAtoms =>
      atoms.where((EmergencyAllFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<EmergencyAllFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (EmergencyAllFinancialAtom atom) =>
            atom.financialClass == EmergencyAllFinancialClass.createCharge ||
            atom.financialClass == EmergencyAllFinancialClass.settle ||
            atom.financialClass == EmergencyAllFinancialClass.adjust ||
            atom.financialClass == EmergencyAllFinancialClass.reverse ||
            atom.financialClass == EmergencyAllFinancialClass.defer,
      );

  static bool forbidsInlineCashier(EmergencyAllFinancialClass actionClass) {
    return switch (actionClass) {
      EmergencyAllFinancialClass.settle ||
      EmergencyAllFinancialClass.adjust ||
      EmergencyAllFinancialClass.reverse => true,
      _ => false,
    };
  }

  static String summary() =>
      'All board defers payment when policy allows but posts deferred '
      'handoff / ambulance charges through clinical-request-billing. Open '
      'billing navigates Billing. No module cashier.';
}

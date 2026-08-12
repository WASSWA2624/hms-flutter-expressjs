import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum LabCriticalFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Lab Critical (`/lab?section=critical`).
@immutable
final class LabCriticalFinancialAtom {
  const LabCriticalFinancialAtom({
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
  final LabCriticalFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/lab?section=critical` (critical values;
/// notify / acknowledge).
///
/// Create / update / additional / delete orders post or reverse request-time
/// charges via `clinical-request-billing` (`persistLabOrderBilling` /
/// `reverseClinicalRequestBilling`). Collect is gated on Billing payment status
/// (PAID / NOT_REQUIRED / NO_CHARGE / NOT_BILLED). Save / enter-results is NOT
/// payment-gated. Critical notify is clinical escalation (`NOT_BILLED`); settle /
/// adjust / refund stay on the Billing workspace — this tab never mounts a
/// parallel cashier.
abstract final class LabCriticalBillingInventory {
  static const LabCriticalFinancialAtom tab = LabCriticalFinancialAtom(
    id: 'tab_navigate',
    label: 'Critical tab / count badge',
    financialClass: LabCriticalFinancialClass.notRequired,
    requirement: LabCriticalAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabCriticalFinancialAtom listChrome = LabCriticalFinancialAtom(
    id: 'search_filters_columns',
    label: 'Search / clear / filters / columns / pagination',
    financialClass: LabCriticalFinancialClass.notRequired,
    requirement: LabCriticalAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabCriticalFinancialAtom paymentFilter =
      LabCriticalFinancialAtom(
        id: 'payment_status_filter',
        label: 'Payment status filter (Billing parity)',
        financialClass: LabCriticalFinancialClass.notRequired,
        requirement: LabCriticalAtomPermissions.filters,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabCriticalFinancialAtom billingColumn =
      LabCriticalFinancialAtom(
        id: 'billing_worklist_column',
        label: 'Payment / billing worklist column',
        financialClass: LabCriticalFinancialClass.notRequired,
        requirement: LabCriticalAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabCriticalFinancialAtom emptyLoadingError =
      LabCriticalFinancialAtom(
        id: 'empty_error_retry_loading',
        label: 'Empty / loading / error / retry states',
        financialClass: LabCriticalFinancialClass.notRequired,
        requirement: LabCriticalAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabCriticalFinancialAtom viewToggle = LabCriticalFinancialAtom(
    id: 'orders_patients_view_toggle',
    label: 'Orders / Patients view toggle (removed — patients-only)',
    financialClass: LabCriticalFinancialClass.notRequired,
    requirement: LabCriticalAtomPermissions.viewToggle,
    auditCode: 'NOT_REQUIRED',
    mounted: false,
  );

  static const LabCriticalFinancialAtom rowSelect = LabCriticalFinancialAtom(
    id: 'row_select_review_critical',
    label: 'Row select / Review critical → result entry',
    financialClass: LabCriticalFinancialClass.notRequired,
    requirement: LabCriticalAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabCriticalFinancialAtom createOrder = LabCriticalFinancialAtom(
    id: 'create_lab_order',
    label: 'Create Lab Order (+ Review billing)',
    financialClass: LabCriticalFinancialClass.createCharge,
    requirement: LabCriticalAtomPermissions.create,
    billingPath:
        'ClinicalLabOrderActionDialog → persistLabOrderBilling / '
        'buildLabOrderBillingFromRequest',
  );

  static const LabCriticalFinancialAtom createAdditionalOrder =
      LabCriticalFinancialAtom(
        id: 'detail_create_additional_order',
        label: 'Detail Create additional order (+ Review billing)',
        financialClass: LabCriticalFinancialClass.createCharge,
        requirement: LabCriticalAtomPermissions.createAdditionalOrder,
        billingPath: 'ClinicalLabOrderActionDialog → persistLabOrderBilling',
        mounted: false,
      );

  static const LabCriticalFinancialAtom editOrder = LabCriticalFinancialAtom(
    id: 'detail_edit_order',
    label: 'Detail Edit order (refresh billing lines)',
    financialClass: LabCriticalFinancialClass.createCharge,
    requirement: LabCriticalAtomPermissions.editOrder,
    billingPath:
        'updateLabOrder → persistLabOrderBilling / reverse prior snapshot',
    mounted: false,
  );

  static const LabCriticalFinancialAtom deleteOrder = LabCriticalFinancialAtom(
    id: 'detail_delete_order',
    label: 'Detail Delete order (removed from lab UI)',
    financialClass: LabCriticalFinancialClass.reverse,
    requirement: LabCriticalAtomPermissions.deleteOrder,
    billingPath: 'reverseClinicalRequestBilling (lab-order)',
    mounted: false,
  );

  static const LabCriticalFinancialAtom collectSample =
      LabCriticalFinancialAtom(
        id: 'workflow_collect_sample',
        label: 'Collect sample (payment-gated clinical step)',
        financialClass: LabCriticalFinancialClass.defer,
        requirement: LabCriticalAtomPermissions.workflowMutate,
        billingPath:
            'assertLabOrderPaymentSatisfied → Billing payment_status gate',
        auditCode: 'NOT_BILLED',
      );

  static const LabCriticalFinancialAtom receiveSample =
      LabCriticalFinancialAtom(
        id: 'workflow_receive_sample',
        label: 'Receive sample',
        financialClass: LabCriticalFinancialClass.notBilled,
        requirement: LabCriticalAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabCriticalFinancialAtom enterResults =
      LabCriticalFinancialAtom(
        id: 'result_entry_save_submit',
        label: 'Save draft / submit results',
        financialClass: LabCriticalFinancialClass.notBilled,
        requirement: LabCriticalAtomPermissions.resultEntry,
        auditCode: 'NOT_BILLED',
      );

  static const LabCriticalFinancialAtom saveResults =
      LabCriticalFinancialAtom(
        id: 'workflow_save_enter_results',
        label: 'Save / enter results (clinical; not payment-gated)',
        financialClass: LabCriticalFinancialClass.notBilled,
        requirement: LabCriticalAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabCriticalFinancialAtom reverseWorkflow =
      LabCriticalFinancialAtom(
        id: 'workflow_reverse',
        label: 'Reverse workflow step (clinical reopen; not invoice reverse)',
        financialClass: LabCriticalFinancialClass.notBilled,
        requirement: LabCriticalAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabCriticalFinancialAtom rejectItem = LabCriticalFinancialAtom(
    id: 'reject_order_item',
    label: 'Reject order item / panel delete',
    financialClass: LabCriticalFinancialClass.notBilled,
    requirement: LabCriticalAtomPermissions.resultEntry,
    auditCode: 'NOT_BILLED',
  );

  static const LabCriticalFinancialAtom previewReport =
      LabCriticalFinancialAtom(
        id: 'preview_report',
        label: 'Preview report',
        financialClass: LabCriticalFinancialClass.notRequired,
        requirement: LabCriticalAtomPermissions.previewReport,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabCriticalFinancialAtom configureCatalog =
      LabCriticalFinancialAtom(
        id: 'lab_configurations',
        label: 'Lab Configurations / catalog enable (removed from Lab strip)',
        financialClass: LabCriticalFinancialClass.notRequired,
        requirement: LabCriticalAtomPermissions.configure,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const LabCriticalFinancialAtom qcLogs = LabCriticalFinancialAtom(
    id: 'qc_logs',
    label: 'QC logs (nested configurations)',
    financialClass: LabCriticalFinancialClass.notRequired,
    requirement: LabCriticalAtomPermissions.configure,
    auditCode: 'NOT_REQUIRED',
  );

  /// Backend auto-notify on critical release; dedicated strip chrome unmounted.
  static const LabCriticalFinancialAtom criticalNotify =
      LabCriticalFinancialAtom(
        id: 'critical_notify',
        label: 'Critical notify (clinical escalation)',
        financialClass: LabCriticalFinancialClass.notBilled,
        requirement: LabCriticalAtomPermissions.criticalNotify,
        auditCode: 'NOT_BILLED',
        mounted: false,
      );

  /// Acknowledge chrome unmounted on Critical today (permission atom only).
  static const LabCriticalFinancialAtom acknowledge =
      LabCriticalFinancialAtom(
        id: 'acknowledge_critical',
        label: 'Acknowledge critical value',
        financialClass: LabCriticalFinancialClass.notBilled,
        requirement: LabCriticalAtomPermissions.acknowledge,
        auditCode: 'NOT_BILLED',
        mounted: false,
      );

  static const LabCriticalFinancialAtom realtimeSync =
      LabCriticalFinancialAtom(
        id: 'realtime_list_sync',
        label: 'Post-mutation worklist / billing badge refresh',
        financialClass: LabCriticalFinancialClass.notRequired,
        requirement: LabCriticalAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Navigate-only atom reserved for unpaid gates; **UI not mounted**
  /// (Await payment text only — Billing desk owns settle).
  static const LabCriticalFinancialAtom openBilling = LabCriticalFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (settle / invoice / waive / refund)',
    financialClass: LabCriticalFinancialClass.defer,
    requirement: labOpenBillingRequirement,
    billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
    auditCode: 'REQUIRES_BILLING',
    mounted: false,
  );

  static const LabCriticalFinancialAtom collectPayment =
      LabCriticalFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: LabCriticalFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Critical)',
        mounted: false,
      );

  static const LabCriticalFinancialAtom adjustRefund = LabCriticalFinancialAtom(
    id: 'adjust_refund',
    label: 'Adjust / refund / write-off / credit note',
    financialClass: LabCriticalFinancialClass.adjust,
    requirement: billingWorkspaceWriteRequirement,
    billingPath: 'Billing adjustment / refund APIs',
    mounted: false,
  );

  static const List<LabCriticalFinancialAtom> all = <LabCriticalFinancialAtom>[
    tab,
    listChrome,
    paymentFilter,
    billingColumn,
    emptyLoadingError,
    viewToggle,
    rowSelect,
    createOrder,
    createAdditionalOrder,
    editOrder,
    deleteOrder,
    collectSample,
    receiveSample,
    enterResults,
    saveResults,
    reverseWorkflow,
    rejectItem,
    previewReport,
    configureCatalog,
    qcLogs,
    criticalNotify,
    acknowledge,
    realtimeSync,
    openBilling,
    collectPayment,
    adjustRefund,
  ];

  static Iterable<LabCriticalFinancialAtom> get mountedAtoms =>
      all.where((LabCriticalFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through or gate on shared Billing paths.
  static Iterable<LabCriticalFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (LabCriticalFinancialAtom atom) =>
            atom.financialClass == LabCriticalFinancialClass.createCharge ||
            atom.financialClass == LabCriticalFinancialClass.settle ||
            atom.financialClass == LabCriticalFinancialClass.adjust ||
            atom.financialClass == LabCriticalFinancialClass.reverse ||
            atom.financialClass == LabCriticalFinancialClass.defer,
      );

  /// True when every mounted billable atom documents a shared Billing path.
  static bool get allBillableMountedUseSharedBilling => billableMounted.every(
    (LabCriticalFinancialAtom atom) =>
        atom.billingPath != null && atom.billingPath!.trim().isNotEmpty,
  );

  static bool forbidsInlineCashier(LabCriticalFinancialClass actionClass) {
    return switch (actionClass) {
      LabCriticalFinancialClass.settle ||
      LabCriticalFinancialClass.adjust => true,
      _ => false,
    };
  }
}

const String labCriticalBillingScopeNote =
    'Lab Critical is the critical-values queue (notify / acknowledge). '
    'Create and edit orders post charges via clinical-request-billing. Collect '
    'is gated on Billing payment status. Save/enter-results is NOT payment-'
    'gated. Critical notify is NOT_BILLED clinical escalation. Settle/adjust/'
    'refund are not cashiered here. Result entry, receive, reverse, and reject '
    'stay NOT_BILLED clinical ops.';

import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum LabProcessingFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Lab Processing
/// (`/lab?section=processing`).
@immutable
final class LabProcessingFinancialAtom {
  const LabProcessingFinancialAtom({
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
  final LabProcessingFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/lab?section=processing` (in-lab processing queue;
/// `IN_PROCESS` scope).
///
/// Create / update / additional / delete orders post or reverse request-time
/// charges via `clinical-request-billing` (`persistLabOrderBilling` /
/// `reverseClinicalRequestBilling`). Collect, receive, and verify/release are
/// gated on Billing payment status (PAID / NOT_REQUIRED / NO_CHARGE /
/// NOT_BILLED). Result entry (save draft / submit) stays `NOT_BILLED` clinical
/// ops. Settle / adjust / refund stay on the Billing workspace — this tab never
/// mounts a parallel cashier. When the payment gate blocks progression,
/// [openBilling] navigates to Billing (mounted on workflow progress).
abstract final class LabProcessingBillingInventory {
  static const LabProcessingFinancialAtom tab = LabProcessingFinancialAtom(
    id: 'tab_navigate',
    label: 'Processing tab / count badge',
    financialClass: LabProcessingFinancialClass.notRequired,
    requirement: LabProcessingAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabProcessingFinancialAtom listChrome =
      LabProcessingFinancialAtom(
        id: 'search_filters_columns',
        label: 'Search / clear / filters / columns / pagination',
        financialClass: LabProcessingFinancialClass.notRequired,
        requirement: LabProcessingAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabProcessingFinancialAtom paymentFilter =
      LabProcessingFinancialAtom(
        id: 'payment_status_filter',
        label: 'Payment status filter (Billing parity)',
        financialClass: LabProcessingFinancialClass.notRequired,
        requirement: LabProcessingAtomPermissions.filters,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabProcessingFinancialAtom billingColumn =
      LabProcessingFinancialAtom(
        id: 'billing_worklist_column',
        label: 'Payment / billing worklist column',
        financialClass: LabProcessingFinancialClass.notRequired,
        requirement: LabProcessingAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabProcessingFinancialAtom emptyLoadingError =
      LabProcessingFinancialAtom(
        id: 'empty_error_retry_loading',
        label: 'Empty / loading / error / retry states',
        financialClass: LabProcessingFinancialClass.notRequired,
        requirement: LabProcessingAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabProcessingFinancialAtom viewToggle =
      LabProcessingFinancialAtom(
        id: 'orders_patients_view_toggle',
        label: 'Orders / Patients view toggle',
        financialClass: LabProcessingFinancialClass.notRequired,
        requirement: LabProcessingAtomPermissions.viewToggle,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabProcessingFinancialAtom rowSelect =
      LabProcessingFinancialAtom(
        id: 'row_select_result_entry',
        label: 'Row select / next action → result entry',
        financialClass: LabProcessingFinancialClass.notRequired,
        requirement: LabProcessingAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabProcessingFinancialAtom createOrder =
      LabProcessingFinancialAtom(
        id: 'create_lab_order',
        label: 'Create Lab Order (+ Review billing)',
        financialClass: LabProcessingFinancialClass.createCharge,
        requirement: LabProcessingAtomPermissions.create,
        billingPath:
            'ClinicalLabOrderActionDialog → persistLabOrderBilling / '
            'buildLabOrderBillingFromRequest',
      );

  static const LabProcessingFinancialAtom createAdditionalOrder =
      LabProcessingFinancialAtom(
        id: 'detail_create_additional_order',
        label: 'Detail Create additional order (+ Review billing)',
        financialClass: LabProcessingFinancialClass.createCharge,
        requirement: LabProcessingAtomPermissions.createAdditionalOrder,
        billingPath:
            'ClinicalLabOrderActionDialog → persistLabOrderBilling',
      );

  static const LabProcessingFinancialAtom editOrder =
      LabProcessingFinancialAtom(
        id: 'detail_edit_order',
        label: 'Detail Edit order (refresh billing lines)',
        financialClass: LabProcessingFinancialClass.createCharge,
        requirement: LabProcessingAtomPermissions.editOrder,
        billingPath:
            'updateLabOrder → persistLabOrderBilling / reverse prior snapshot',
      );

  static const LabProcessingFinancialAtom deleteOrder =
      LabProcessingFinancialAtom(
        id: 'detail_delete_order',
        label: 'Detail Delete order',
        financialClass: LabProcessingFinancialClass.reverse,
        requirement: LabProcessingAtomPermissions.deleteOrder,
        billingPath: 'reverseClinicalRequestBilling (lab-order)',
      );

  static const LabProcessingFinancialAtom collectSample =
      LabProcessingFinancialAtom(
        id: 'workflow_collect_sample',
        label: 'Collect sample (payment-gated clinical step)',
        financialClass: LabProcessingFinancialClass.defer,
        requirement: LabProcessingAtomPermissions.workflowMutate,
        billingPath:
            'assertLabOrderPaymentSatisfied → Billing payment_status gate',
        auditCode: 'NOT_BILLED',
      );

  /// Receive advances sample/order into `IN_PROCESS` and is payment-gated.
  static const LabProcessingFinancialAtom receiveSample =
      LabProcessingFinancialAtom(
        id: 'workflow_receive_sample',
        label: 'Receive sample (payment-gated → IN_PROCESS)',
        financialClass: LabProcessingFinancialClass.defer,
        requirement: LabProcessingAtomPermissions.workflowMutate,
        billingPath:
            'assertLabOrderPaymentSatisfied before receive (Billing gate)',
        auditCode: 'NOT_BILLED',
      );

  static const LabProcessingFinancialAtom enterResults =
      LabProcessingFinancialAtom(
        id: 'result_entry_save_submit',
        label: 'Save draft / submit results (in-lab processing)',
        financialClass: LabProcessingFinancialClass.notBilled,
        requirement: LabProcessingAtomPermissions.resultEntry,
        auditCode: 'NOT_BILLED',
      );

  static const LabProcessingFinancialAtom verifyResults =
      LabProcessingFinancialAtom(
        id: 'workflow_verify_release_results',
        label: 'Verify / release results (payment-gated)',
        financialClass: LabProcessingFinancialClass.defer,
        requirement: LabProcessingAtomPermissions.workflowMutate,
        billingPath:
            'assertLabOrderPaymentSatisfied on verify/release (Billing gate)',
        auditCode: 'NOT_BILLED',
      );

  static const LabProcessingFinancialAtom reverseWorkflow =
      LabProcessingFinancialAtom(
        id: 'workflow_reverse',
        label: 'Reverse workflow step (clinical reopen; not invoice reverse)',
        financialClass: LabProcessingFinancialClass.notBilled,
        requirement: LabProcessingAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabProcessingFinancialAtom rejectItem =
      LabProcessingFinancialAtom(
        id: 'reject_order_item',
        label: 'Reject order item / panel delete',
        financialClass: LabProcessingFinancialClass.notBilled,
        requirement: LabProcessingAtomPermissions.resultEntry,
        auditCode: 'NOT_BILLED',
      );

  static const LabProcessingFinancialAtom previewReport =
      LabProcessingFinancialAtom(
        id: 'preview_report',
        label: 'Preview report',
        financialClass: LabProcessingFinancialClass.notRequired,
        requirement: LabProcessingAtomPermissions.previewReport,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabProcessingFinancialAtom configureCatalog =
      LabProcessingFinancialAtom(
        id: 'lab_configurations',
        label: 'Lab Configurations / catalog enable',
        financialClass: LabProcessingFinancialClass.notRequired,
        requirement: LabProcessingAtomPermissions.configure,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabProcessingFinancialAtom qcLogs = LabProcessingFinancialAtom(
    id: 'qc_logs',
    label: 'QC logs (nested configurations)',
    financialClass: LabProcessingFinancialClass.notRequired,
    requirement: LabProcessingAtomPermissions.configure,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabProcessingFinancialAtom realtimeSync =
      LabProcessingFinancialAtom(
        id: 'realtime_list_sync',
        label: 'Post-mutation worklist / billing badge refresh',
        financialClass: LabProcessingFinancialClass.notRequired,
        requirement: LabProcessingAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Mounted on workflow progress when Billing gate blocks progression.
  static const LabProcessingFinancialAtom openBilling =
      LabProcessingFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (settle / invoice / waive / refund)',
        financialClass: LabProcessingFinancialClass.settle,
        requirement: labOpenBillingRequirement,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
        auditCode: 'REQUIRES_BILLING',
      );

  static const LabProcessingFinancialAtom collectPayment =
      LabProcessingFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: LabProcessingFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath:
            'Billing receive-payment (not mounted on Processing)',
        mounted: false,
      );

  static const LabProcessingFinancialAtom adjustRefund =
      LabProcessingFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: LabProcessingFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<LabProcessingFinancialAtom> all =
      <LabProcessingFinancialAtom>[
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
        verifyResults,
        reverseWorkflow,
        rejectItem,
        previewReport,
        configureCatalog,
        qcLogs,
        realtimeSync,
        openBilling,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<LabProcessingFinancialAtom> get mountedAtoms =>
      all.where((LabProcessingFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through or gate on shared Billing paths.
  static Iterable<LabProcessingFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (LabProcessingFinancialAtom atom) =>
            atom.financialClass == LabProcessingFinancialClass.createCharge ||
            atom.financialClass == LabProcessingFinancialClass.settle ||
            atom.financialClass == LabProcessingFinancialClass.adjust ||
            atom.financialClass == LabProcessingFinancialClass.reverse ||
            atom.financialClass == LabProcessingFinancialClass.defer,
      );

  /// True when every mounted billable atom documents a shared Billing path.
  static bool get allBillableMountedUseSharedBilling => billableMounted.every(
    (LabProcessingFinancialAtom atom) =>
        atom.billingPath != null && atom.billingPath!.trim().isNotEmpty,
  );

  static bool forbidsInlineCashier(LabProcessingFinancialClass actionClass) {
    return switch (actionClass) {
      LabProcessingFinancialClass.settle ||
      LabProcessingFinancialClass.adjust => true,
      _ => false,
    };
  }
}

const String labProcessingBillingScopeNote =
    'Lab Processing is the in-lab processing queue (IN_PROCESS). Create and '
    'edit orders post charges via clinical-request-billing. Collect, receive, '
    'and verify/release are gated on Billing payment status. Open billing '
    'navigates the Billing module when the gate blocks. Settle/adjust/refund '
    'are not cashiered here. Result entry, reverse, and reject stay NOT_BILLED '
    'clinical ops.';

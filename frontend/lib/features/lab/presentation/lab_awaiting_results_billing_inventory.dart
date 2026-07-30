import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum LabAwaitingResultsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Lab Awaiting results
/// (`/lab?section=awaiting-results`).
@immutable
final class LabAwaitingResultsFinancialAtom {
  const LabAwaitingResultsFinancialAtom({
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
  final LabAwaitingResultsFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/lab?section=awaiting-results` (collection queue;
/// pending sample / result entry).
///
/// Create / update / additional orders post request-time charges via
/// `clinical-request-billing` (`persistLabOrderBilling`). Collect and
/// verify/release are gated on Billing payment status (PAID / NOT_REQUIRED /
/// NO_CHARGE / NOT_BILLED). Settle / adjust / refund stay on the Billing
/// workspace — this tab never mounts a parallel cashier.
abstract final class LabAwaitingResultsBillingInventory {
  static const LabAwaitingResultsFinancialAtom tab =
      LabAwaitingResultsFinancialAtom(
        id: 'tab_navigate',
        label: 'Awaiting results tab / count badge',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom listChrome =
      LabAwaitingResultsFinancialAtom(
        id: 'search_filters_columns',
        label: 'Search / clear / filters / columns / pagination',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom paymentFilter =
      LabAwaitingResultsFinancialAtom(
        id: 'payment_status_filter',
        label: 'Payment status filter (Billing parity)',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.filters,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom billingColumn =
      LabAwaitingResultsFinancialAtom(
        id: 'billing_worklist_column',
        label: 'Payment / billing worklist column',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom emptyLoadingError =
      LabAwaitingResultsFinancialAtom(
        id: 'empty_error_retry_loading',
        label: 'Empty / loading / error / retry states',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom viewToggle =
      LabAwaitingResultsFinancialAtom(
        id: 'orders_patients_view_toggle',
        label: 'Orders / Patients view toggle',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.viewToggle,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom rowSelect =
      LabAwaitingResultsFinancialAtom(
        id: 'row_select_result_entry',
        label: 'Row select / next action → result entry',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom createOrder =
      LabAwaitingResultsFinancialAtom(
        id: 'create_lab_order',
        label: 'Create Lab Order (+ Review billing)',
        financialClass: LabAwaitingResultsFinancialClass.createCharge,
        requirement: LabAwaitingResultsAtomPermissions.create,
        billingPath:
            'ClinicalLabOrderActionDialog → persistLabOrderBilling / '
            'buildLabOrderBillingFromRequest',
      );

  static const LabAwaitingResultsFinancialAtom createAdditionalOrder =
      LabAwaitingResultsFinancialAtom(
        id: 'detail_create_additional_order',
        label: 'Detail Create additional order (+ Review billing)',
        financialClass: LabAwaitingResultsFinancialClass.createCharge,
        requirement: LabAwaitingResultsAtomPermissions.createAdditionalOrder,
        billingPath:
            'ClinicalLabOrderActionDialog → persistLabOrderBilling',
      );

  static const LabAwaitingResultsFinancialAtom editOrder =
      LabAwaitingResultsFinancialAtom(
        id: 'detail_edit_order',
        label: 'Detail Edit order (refresh billing lines)',
        financialClass: LabAwaitingResultsFinancialClass.createCharge,
        requirement: LabAwaitingResultsAtomPermissions.editOrder,
        billingPath:
            'updateLabOrder → persistLabOrderBilling / reverse prior snapshot',
      );

  static const LabAwaitingResultsFinancialAtom deleteOrder =
      LabAwaitingResultsFinancialAtom(
        id: 'detail_delete_order',
        label: 'Detail Delete order',
        financialClass: LabAwaitingResultsFinancialClass.reverse,
        requirement: LabAwaitingResultsAtomPermissions.deleteOrder,
        billingPath: 'reverseClinicalRequestBilling (lab-order)',
      );

  static const LabAwaitingResultsFinancialAtom collectSample =
      LabAwaitingResultsFinancialAtom(
        id: 'workflow_collect_sample',
        label: 'Collect sample (payment-gated clinical step)',
        financialClass: LabAwaitingResultsFinancialClass.defer,
        requirement: LabAwaitingResultsAtomPermissions.workflowMutate,
        billingPath:
            'assertLabOrderPaymentSatisfied → Billing payment_status gate',
        auditCode: 'NOT_BILLED',
      );

  static const LabAwaitingResultsFinancialAtom receiveSample =
      LabAwaitingResultsFinancialAtom(
        id: 'workflow_receive_sample',
        label: 'Receive sample',
        financialClass: LabAwaitingResultsFinancialClass.notBilled,
        requirement: LabAwaitingResultsAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabAwaitingResultsFinancialAtom enterResults =
      LabAwaitingResultsFinancialAtom(
        id: 'result_entry_save_submit',
        label: 'Save draft / submit results',
        financialClass: LabAwaitingResultsFinancialClass.notBilled,
        requirement: LabAwaitingResultsAtomPermissions.resultEntry,
        auditCode: 'NOT_BILLED',
      );

  static const LabAwaitingResultsFinancialAtom verifyResults =
      LabAwaitingResultsFinancialAtom(
        id: 'workflow_verify_release_results',
        label: 'Verify / release results (payment-gated)',
        financialClass: LabAwaitingResultsFinancialClass.defer,
        requirement: LabAwaitingResultsAtomPermissions.workflowMutate,
        billingPath:
            'assertLabOrderPaymentSatisfied on verify/release (Billing gate)',
        auditCode: 'NOT_BILLED',
      );

  static const LabAwaitingResultsFinancialAtom reverseWorkflow =
      LabAwaitingResultsFinancialAtom(
        id: 'workflow_reverse',
        label: 'Reverse workflow step',
        financialClass: LabAwaitingResultsFinancialClass.notBilled,
        requirement: LabAwaitingResultsAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabAwaitingResultsFinancialAtom rejectItem =
      LabAwaitingResultsFinancialAtom(
        id: 'reject_order_item',
        label: 'Reject order item / panel delete',
        financialClass: LabAwaitingResultsFinancialClass.notBilled,
        requirement: LabAwaitingResultsAtomPermissions.resultEntry,
        auditCode: 'NOT_BILLED',
      );

  static const LabAwaitingResultsFinancialAtom previewReport =
      LabAwaitingResultsFinancialAtom(
        id: 'preview_report',
        label: 'Preview report',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.previewReport,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom configureCatalog =
      LabAwaitingResultsFinancialAtom(
        id: 'lab_configurations',
        label: 'Lab Configurations / catalog enable',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.configure,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom qcLogs =
      LabAwaitingResultsFinancialAtom(
        id: 'qc_logs',
        label: 'QC logs (nested configurations)',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.configure,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabAwaitingResultsFinancialAtom realtimeSync =
      LabAwaitingResultsFinancialAtom(
        id: 'realtime_list_sync',
        label: 'Post-mutation worklist / billing badge refresh',
        financialClass: LabAwaitingResultsFinancialClass.notRequired,
        requirement: LabAwaitingResultsAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Navigate-only; Billing workspace remains system of record.
  static const LabAwaitingResultsFinancialAtom openBilling =
      LabAwaitingResultsFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (settle / invoice / waive / refund)',
        financialClass: LabAwaitingResultsFinancialClass.settle,
        requirement: billingWorkspaceReadRequirement,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const LabAwaitingResultsFinancialAtom collectPayment =
      LabAwaitingResultsFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: LabAwaitingResultsFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Awaiting results)',
        mounted: false,
      );

  static const LabAwaitingResultsFinancialAtom adjustRefund =
      LabAwaitingResultsFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: LabAwaitingResultsFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<LabAwaitingResultsFinancialAtom> all =
      <LabAwaitingResultsFinancialAtom>[
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

  static Iterable<LabAwaitingResultsFinancialAtom> get mountedAtoms =>
      all.where((LabAwaitingResultsFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through or gate on shared Billing paths.
  static Iterable<LabAwaitingResultsFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (LabAwaitingResultsFinancialAtom atom) =>
            atom.financialClass ==
                LabAwaitingResultsFinancialClass.createCharge ||
            atom.financialClass == LabAwaitingResultsFinancialClass.settle ||
            atom.financialClass == LabAwaitingResultsFinancialClass.adjust ||
            atom.financialClass == LabAwaitingResultsFinancialClass.reverse ||
            atom.financialClass == LabAwaitingResultsFinancialClass.defer,
      );

  /// True when every mounted billable atom documents a shared Billing path.
  static bool get allBillableMountedUseSharedBilling => billableMounted.every(
    (LabAwaitingResultsFinancialAtom atom) =>
        atom.billingPath != null && atom.billingPath!.trim().isNotEmpty,
  );

  static bool forbidsInlineCashier(LabAwaitingResultsFinancialClass actionClass) {
    return switch (actionClass) {
      LabAwaitingResultsFinancialClass.settle ||
      LabAwaitingResultsFinancialClass.adjust => true,
      _ => false,
    };
  }
}

const String labAwaitingResultsBillingScopeNote =
    'Lab Awaiting results is the collection / pending result-entry queue. '
    'Create and edit orders post charges via clinical-request-billing. Collect '
    'and verify/release are gated on Billing payment status. Settle/adjust/'
    'refund are not cashiered here. Result entry, receive, reverse, and reject '
    'stay NOT_BILLED clinical ops.';

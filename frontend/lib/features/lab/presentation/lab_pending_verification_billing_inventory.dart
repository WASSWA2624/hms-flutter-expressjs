import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum LabPendingVerificationFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Lab Pending verification
/// (`/lab?section=pending-verification`).
@immutable
final class LabPendingVerificationFinancialAtom {
  const LabPendingVerificationFinancialAtom({
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
  final LabPendingVerificationFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/lab?section=pending-verification` (results queue;
/// verify / release).
///
/// Create / update / additional / delete orders post or reverse request-time
/// charges via `clinical-request-billing` (`persistLabOrderBilling` /
/// `reverseClinicalRequestBilling`). Verify/release are gated on Billing
/// payment status (PAID / NOT_REQUIRED / NO_CHARGE / NOT_BILLED). Settle /
/// adjust / refund stay on the Billing workspace — this tab never mounts a
/// parallel cashier.
abstract final class LabPendingVerificationBillingInventory {
  static const LabPendingVerificationFinancialAtom tab =
      LabPendingVerificationFinancialAtom(
        id: 'tab_navigate',
        label: 'Pending verification tab / count badge',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom listChrome =
      LabPendingVerificationFinancialAtom(
        id: 'search_filters_columns',
        label: 'Search / clear / filters / columns / pagination',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom paymentFilter =
      LabPendingVerificationFinancialAtom(
        id: 'payment_status_filter',
        label: 'Payment status filter (Billing parity)',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.filters,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom billingColumn =
      LabPendingVerificationFinancialAtom(
        id: 'billing_worklist_column',
        label: 'Payment / billing worklist column',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom emptyLoadingError =
      LabPendingVerificationFinancialAtom(
        id: 'empty_error_retry_loading',
        label: 'Empty / loading / error / retry states',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom viewToggle =
      LabPendingVerificationFinancialAtom(
        id: 'orders_patients_view_toggle',
        label: 'Orders / Patients view toggle',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.viewToggle,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom rowSelect =
      LabPendingVerificationFinancialAtom(
        id: 'row_select_verify',
        label: 'Row select / next action → result entry (verify)',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom createOrder =
      LabPendingVerificationFinancialAtom(
        id: 'create_lab_order',
        label: 'Create Lab Order (+ Review billing)',
        financialClass: LabPendingVerificationFinancialClass.createCharge,
        requirement: LabPendingVerificationAtomPermissions.create,
        billingPath:
            'ClinicalLabOrderActionDialog → persistLabOrderBilling / '
            'buildLabOrderBillingFromRequest',
      );

  static const LabPendingVerificationFinancialAtom createAdditionalOrder =
      LabPendingVerificationFinancialAtom(
        id: 'detail_create_additional_order',
        label: 'Detail Create additional order (+ Review billing)',
        financialClass: LabPendingVerificationFinancialClass.createCharge,
        requirement: LabPendingVerificationAtomPermissions.createAdditionalOrder,
        billingPath:
            'ClinicalLabOrderActionDialog → persistLabOrderBilling',
      );

  static const LabPendingVerificationFinancialAtom editOrder =
      LabPendingVerificationFinancialAtom(
        id: 'detail_edit_order',
        label: 'Detail Edit order (refresh billing lines)',
        financialClass: LabPendingVerificationFinancialClass.createCharge,
        requirement: LabPendingVerificationAtomPermissions.editOrder,
        billingPath:
            'updateLabOrder → persistLabOrderBilling / reverse prior snapshot',
      );

  static const LabPendingVerificationFinancialAtom deleteOrder =
      LabPendingVerificationFinancialAtom(
        id: 'detail_delete_order',
        label: 'Detail Delete order',
        financialClass: LabPendingVerificationFinancialClass.reverse,
        requirement: LabPendingVerificationAtomPermissions.deleteOrder,
        billingPath: 'reverseClinicalRequestBilling (lab-order)',
      );

  static const LabPendingVerificationFinancialAtom collectSample =
      LabPendingVerificationFinancialAtom(
        id: 'workflow_collect_sample',
        label: 'Collect sample (payment-gated clinical step)',
        financialClass: LabPendingVerificationFinancialClass.defer,
        requirement: LabPendingVerificationAtomPermissions.workflowMutate,
        billingPath:
            'assertLabOrderPaymentSatisfied → Billing payment_status gate',
        auditCode: 'NOT_BILLED',
      );

  static const LabPendingVerificationFinancialAtom receiveSample =
      LabPendingVerificationFinancialAtom(
        id: 'workflow_receive_sample',
        label: 'Receive sample',
        financialClass: LabPendingVerificationFinancialClass.notBilled,
        requirement: LabPendingVerificationAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabPendingVerificationFinancialAtom enterResults =
      LabPendingVerificationFinancialAtom(
        id: 'result_entry_save_submit',
        label: 'Save draft / submit results',
        financialClass: LabPendingVerificationFinancialClass.notBilled,
        requirement: LabPendingVerificationAtomPermissions.resultEntry,
        auditCode: 'NOT_BILLED',
      );

  /// Primary tab action — fulfillment gate; charges already posted at order.
  static const LabPendingVerificationFinancialAtom verifyResults =
      LabPendingVerificationFinancialAtom(
        id: 'workflow_verify_release_results',
        label: 'Verify / release results (payment-gated)',
        financialClass: LabPendingVerificationFinancialClass.defer,
        requirement: LabPendingVerificationAtomPermissions.verify,
        billingPath:
            'assertLabOrderPaymentSatisfied on verify/release (Billing gate)',
        auditCode: 'NOT_BILLED',
      );

  static const LabPendingVerificationFinancialAtom reverseWorkflow =
      LabPendingVerificationFinancialAtom(
        id: 'workflow_reverse',
        label: 'Reverse workflow step',
        financialClass: LabPendingVerificationFinancialClass.notBilled,
        requirement: LabPendingVerificationAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabPendingVerificationFinancialAtom rejectItem =
      LabPendingVerificationFinancialAtom(
        id: 'reject_order_item',
        label: 'Reject order item / panel delete',
        financialClass: LabPendingVerificationFinancialClass.notBilled,
        requirement: LabPendingVerificationAtomPermissions.resultEntry,
        auditCode: 'NOT_BILLED',
      );

  static const LabPendingVerificationFinancialAtom previewReport =
      LabPendingVerificationFinancialAtom(
        id: 'preview_report',
        label: 'Preview report',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.previewReport,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom configureCatalog =
      LabPendingVerificationFinancialAtom(
        id: 'lab_configurations',
        label: 'Lab Configurations / catalog enable',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.configure,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom qcLogs =
      LabPendingVerificationFinancialAtom(
        id: 'qc_logs',
        label: 'QC logs (nested configurations)',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.configure,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabPendingVerificationFinancialAtom realtimeSync =
      LabPendingVerificationFinancialAtom(
        id: 'realtime_list_sync',
        label: 'Post-mutation worklist / billing badge refresh',
        financialClass: LabPendingVerificationFinancialClass.notRequired,
        requirement: LabPendingVerificationAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Navigate-only; Billing workspace remains system of record.
  static const LabPendingVerificationFinancialAtom openBilling =
      LabPendingVerificationFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (settle / invoice / waive / refund)',
        financialClass: LabPendingVerificationFinancialClass.settle,
        requirement: LabPendingVerificationAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const LabPendingVerificationFinancialAtom collectPayment =
      LabPendingVerificationFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: LabPendingVerificationFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath:
            'Billing receive-payment (not mounted on Pending verification)',
        mounted: false,
      );

  static const LabPendingVerificationFinancialAtom adjustRefund =
      LabPendingVerificationFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: LabPendingVerificationFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<LabPendingVerificationFinancialAtom> all =
      <LabPendingVerificationFinancialAtom>[
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

  static Iterable<LabPendingVerificationFinancialAtom> get mountedAtoms =>
      all.where((LabPendingVerificationFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through or gate on shared Billing paths.
  static Iterable<LabPendingVerificationFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (LabPendingVerificationFinancialAtom atom) =>
            atom.financialClass ==
                LabPendingVerificationFinancialClass.createCharge ||
            atom.financialClass ==
                LabPendingVerificationFinancialClass.settle ||
            atom.financialClass ==
                LabPendingVerificationFinancialClass.adjust ||
            atom.financialClass ==
                LabPendingVerificationFinancialClass.reverse ||
            atom.financialClass == LabPendingVerificationFinancialClass.defer,
      );

  /// True when every mounted billable atom documents a shared Billing path.
  static bool get allBillableMountedUseSharedBilling => billableMounted.every(
    (LabPendingVerificationFinancialAtom atom) =>
        atom.billingPath != null && atom.billingPath!.trim().isNotEmpty,
  );

  static bool forbidsInlineCashier(
    LabPendingVerificationFinancialClass actionClass,
  ) {
    return switch (actionClass) {
      LabPendingVerificationFinancialClass.settle ||
      LabPendingVerificationFinancialClass.adjust => true,
      _ => false,
    };
  }
}

const String labPendingVerificationBillingScopeNote =
    'Lab Pending verification is the verify/release results queue. Create and '
    'edit orders post charges via clinical-request-billing. Verify/release are '
    'gated on Billing payment status (PAID / NOT_REQUIRED / NO_CHARGE / '
    'NOT_BILLED). Settle/adjust/refund are not cashiered here. Result entry, '
    'receive, reverse, and reject stay NOT_BILLED clinical ops.';

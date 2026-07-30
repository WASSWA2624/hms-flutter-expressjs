import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum LabVerifiedFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Lab Completed (`/lab?section=completed|verified`).
@immutable
final class LabVerifiedFinancialAtom {
  const LabVerifiedFinancialAtom({
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
  final LabVerifiedFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/lab?section=completed|verified` (saved /
/// COMPLETED results; prefer read — Preview report; reopen / edit saved).
///
/// Create / update / additional / delete orders post or reverse request-time
/// charges via `clinical-request-billing` (`persistLabOrderBilling` /
/// `reverseClinicalRequestBilling`). Re-save / enter results after reopen is
/// NOT payment-gated (`NOT_BILLED` clinical). Edit / reopen saved is clinical
/// (`NOT_BILLED`) and must not reverse invoices. Settle / adjust / refund stay
/// on the Billing workspace — this tab never mounts a parallel cashier.
abstract final class LabVerifiedBillingInventory {
  static const LabVerifiedFinancialAtom tab = LabVerifiedFinancialAtom(
    id: 'tab_navigate',
    label: 'Completed tab / count badge',
    financialClass: LabVerifiedFinancialClass.notRequired,
    requirement: LabVerifiedAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabVerifiedFinancialAtom listChrome = LabVerifiedFinancialAtom(
    id: 'search_filters_columns',
    label: 'Search / clear / filters / columns / pagination',
    financialClass: LabVerifiedFinancialClass.notRequired,
    requirement: LabVerifiedAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabVerifiedFinancialAtom paymentFilter =
      LabVerifiedFinancialAtom(
        id: 'payment_status_filter',
        label: 'Payment status filter (Billing parity)',
        financialClass: LabVerifiedFinancialClass.notRequired,
        requirement: LabVerifiedAtomPermissions.filters,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabVerifiedFinancialAtom billingColumn =
      LabVerifiedFinancialAtom(
        id: 'billing_worklist_column',
        label: 'Payment / billing worklist column',
        financialClass: LabVerifiedFinancialClass.notRequired,
        requirement: LabVerifiedAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabVerifiedFinancialAtom emptyLoadingError =
      LabVerifiedFinancialAtom(
        id: 'empty_error_retry_loading',
        label: 'Empty / loading / error / retry states',
        financialClass: LabVerifiedFinancialClass.notRequired,
        requirement: LabVerifiedAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabVerifiedFinancialAtom viewToggle = LabVerifiedFinancialAtom(
    id: 'orders_patients_view_toggle',
    label: 'Orders / Patients view toggle',
    financialClass: LabVerifiedFinancialClass.notRequired,
    requirement: LabVerifiedAtomPermissions.viewToggle,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabVerifiedFinancialAtom rowSelect = LabVerifiedFinancialAtom(
    id: 'row_select_result_entry',
    label: 'Row select → result entry (terminal next-action text-only)',
    financialClass: LabVerifiedFinancialClass.notRequired,
    requirement: LabVerifiedAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabVerifiedFinancialAtom createOrder = LabVerifiedFinancialAtom(
    id: 'create_lab_order',
    label: 'Create Lab Order (+ Review billing)',
    financialClass: LabVerifiedFinancialClass.createCharge,
    requirement: LabVerifiedAtomPermissions.create,
    billingPath:
        'ClinicalLabOrderActionDialog → persistLabOrderBilling / '
        'buildLabOrderBillingFromRequest',
  );

  static const LabVerifiedFinancialAtom createAdditionalOrder =
      LabVerifiedFinancialAtom(
        id: 'detail_create_additional_order',
        label: 'Detail Create additional order (+ Review billing)',
        financialClass: LabVerifiedFinancialClass.createCharge,
        requirement: LabVerifiedAtomPermissions.createAdditionalOrder,
        billingPath: 'ClinicalLabOrderActionDialog → persistLabOrderBilling',
      );

  static const LabVerifiedFinancialAtom editOrder = LabVerifiedFinancialAtom(
    id: 'detail_edit_order',
    label: 'Detail Edit order (refresh billing lines)',
    financialClass: LabVerifiedFinancialClass.createCharge,
    requirement: LabVerifiedAtomPermissions.editOrder,
    billingPath:
        'updateLabOrder → persistLabOrderBilling / reverse prior snapshot',
  );

  static const LabVerifiedFinancialAtom deleteOrder = LabVerifiedFinancialAtom(
    id: 'detail_delete_order',
    label: 'Detail Delete order',
    financialClass: LabVerifiedFinancialClass.reverse,
    requirement: LabVerifiedAtomPermissions.deleteOrder,
    billingPath: 'reverseClinicalRequestBilling (lab-order)',
  );

  static const LabVerifiedFinancialAtom collectSample =
      LabVerifiedFinancialAtom(
        id: 'workflow_collect_sample',
        label: 'Collect sample (payment-gated clinical step)',
        financialClass: LabVerifiedFinancialClass.defer,
        requirement: LabVerifiedAtomPermissions.workflowMutate,
        billingPath:
            'assertLabOrderPaymentSatisfied → Billing payment_status gate',
        auditCode: 'NOT_BILLED',
      );

  static const LabVerifiedFinancialAtom receiveSample =
      LabVerifiedFinancialAtom(
        id: 'workflow_receive_sample',
        label: 'Receive sample',
        financialClass: LabVerifiedFinancialClass.notBilled,
        requirement: LabVerifiedAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabVerifiedFinancialAtom enterResults =
      LabVerifiedFinancialAtom(
        id: 'result_entry_save_submit',
        label: 'Save draft / submit results',
        financialClass: LabVerifiedFinancialClass.notBilled,
        requirement: LabVerifiedAtomPermissions.resultEntry,
        auditCode: 'NOT_BILLED',
      );

  static const LabVerifiedFinancialAtom saveResults =
      LabVerifiedFinancialAtom(
        id: 'workflow_save_enter_results',
        label: 'Save / enter results (clinical; not payment-gated; incl. reopen)',
        financialClass: LabVerifiedFinancialClass.notBilled,
        requirement: LabVerifiedAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  /// Clinical correction only — does not reverse or adjust Billing invoices.
  static const LabVerifiedFinancialAtom editReopenVerified =
      LabVerifiedFinancialAtom(
        id: 'edit_reopen_verified_result',
        label: 'Edit / reopen saved result (clinical; not invoice reverse)',
        financialClass: LabVerifiedFinancialClass.notBilled,
        requirement: LabVerifiedAtomPermissions.reopenVerifiedResult,
        auditCode: 'NOT_BILLED',
      );

  static const LabVerifiedFinancialAtom reverseWorkflow =
      LabVerifiedFinancialAtom(
        id: 'workflow_reverse',
        label: 'Reverse workflow step (clinical reopen; not invoice reverse)',
        financialClass: LabVerifiedFinancialClass.notBilled,
        requirement: LabVerifiedAtomPermissions.workflowMutate,
        auditCode: 'NOT_BILLED',
      );

  static const LabVerifiedFinancialAtom rejectItem = LabVerifiedFinancialAtom(
    id: 'reject_order_item',
    label: 'Reject order item / panel delete',
    financialClass: LabVerifiedFinancialClass.notBilled,
    requirement: LabVerifiedAtomPermissions.resultEntry,
    auditCode: 'NOT_BILLED',
  );

  static const LabVerifiedFinancialAtom previewReport =
      LabVerifiedFinancialAtom(
        id: 'preview_report',
        label: 'Preview report',
        financialClass: LabVerifiedFinancialClass.notRequired,
        requirement: LabVerifiedAtomPermissions.previewReport,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabVerifiedFinancialAtom configureCatalog =
      LabVerifiedFinancialAtom(
        id: 'lab_configurations',
        label: 'Lab Configurations / catalog enable',
        financialClass: LabVerifiedFinancialClass.notRequired,
        requirement: LabVerifiedAtomPermissions.configure,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabVerifiedFinancialAtom qcLogs = LabVerifiedFinancialAtom(
    id: 'qc_logs',
    label: 'QC logs (nested configurations)',
    financialClass: LabVerifiedFinancialClass.notRequired,
    requirement: LabVerifiedAtomPermissions.configure,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabVerifiedFinancialAtom realtimeSync =
      LabVerifiedFinancialAtom(
        id: 'realtime_list_sync',
        label: 'Post-mutation worklist / billing badge refresh',
        financialClass: LabVerifiedFinancialClass.notRequired,
        requirement: LabVerifiedAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Navigate-only; Billing workspace remains system of record.
  /// Mounted from workflow when `billingGateBlocked` (Open billing CTA).
  static const LabVerifiedFinancialAtom openBilling = LabVerifiedFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (settle / invoice / waive / refund)',
    financialClass: LabVerifiedFinancialClass.defer,
    requirement: LabVerifiedAtomPermissions.openBilling,
    billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
    auditCode: 'REQUIRES_BILLING',
  );

  static const LabVerifiedFinancialAtom collectPayment =
      LabVerifiedFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: LabVerifiedFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Completed)',
        mounted: false,
      );

  static const LabVerifiedFinancialAtom adjustRefund = LabVerifiedFinancialAtom(
    id: 'adjust_refund',
    label: 'Adjust / refund / write-off / credit note',
    financialClass: LabVerifiedFinancialClass.adjust,
    requirement: billingWorkspaceWriteRequirement,
    billingPath: 'Billing adjustment / refund APIs',
    mounted: false,
  );

  static const List<LabVerifiedFinancialAtom> all = <LabVerifiedFinancialAtom>[
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
    editReopenVerified,
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

  static Iterable<LabVerifiedFinancialAtom> get mountedAtoms =>
      all.where((LabVerifiedFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through or gate on shared Billing paths.
  static Iterable<LabVerifiedFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (LabVerifiedFinancialAtom atom) =>
            atom.financialClass == LabVerifiedFinancialClass.createCharge ||
            atom.financialClass == LabVerifiedFinancialClass.settle ||
            atom.financialClass == LabVerifiedFinancialClass.adjust ||
            atom.financialClass == LabVerifiedFinancialClass.reverse ||
            atom.financialClass == LabVerifiedFinancialClass.defer,
      );

  /// True when every mounted billable atom documents a shared Billing path.
  static bool get allBillableMountedUseSharedBilling => billableMounted.every(
    (LabVerifiedFinancialAtom atom) =>
        atom.billingPath != null && atom.billingPath!.trim().isNotEmpty,
  );

  static bool forbidsInlineCashier(LabVerifiedFinancialClass actionClass) {
    return switch (actionClass) {
      LabVerifiedFinancialClass.settle ||
      LabVerifiedFinancialClass.adjust => true,
      _ => false,
    };
  }
}

const String labVerifiedBillingScopeNote =
    'Lab Completed is the saved / COMPLETED results queue (prefer read). '
    'Create and edit orders post charges via clinical-request-billing. '
    'Save/enter-results (including after reopen) is NOT payment-gated. '
    'Edit/reopen saved results and reverse workflow are NOT_BILLED clinical '
    'ops and must not reverse invoices. Settle/adjust/refund are not cashiered '
    'here. Result entry, receive, and reject stay NOT_BILLED clinical ops.';

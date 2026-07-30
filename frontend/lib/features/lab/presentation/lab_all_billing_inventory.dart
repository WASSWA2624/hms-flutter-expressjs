import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum LabAllFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Lab All (`/lab?section=all|worklist`).
@immutable
final class LabAllFinancialAtom {
  const LabAllFinancialAtom({
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
  final LabAllFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for Lab workspace **All** tab.
///
/// Create / update lab orders post request-time charges via
/// `clinical-request-billing` (persistLabOrderBilling). Collect / receive /
/// verify / release are gated on Billing payment satisfaction. Settle and
/// adjust stay on the Billing workspace (Open billing navigation)—no lab
/// cashier.
abstract final class LabAllBillingInventory {
  static const LabAllFinancialAtom tab = LabAllFinancialAtom(
    id: 'tab',
    label: 'All tab / count badge',
    financialClass: LabAllFinancialClass.notRequired,
    requirement: LabAllAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabAllFinancialAtom listChrome = LabAllFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters (incl. payment) / columns / pagination',
    financialClass: LabAllFinancialClass.notRequired,
    requirement: LabAllAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabAllFinancialAtom emptyLoadingError = LabAllFinancialAtom(
    id: 'empty_loading_error',
    label: 'Empty / loading / error / retry',
    financialClass: LabAllFinancialClass.notRequired,
    requirement: LabAllAtomPermissions.empty,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabAllFinancialAtom viewToggle = LabAllFinancialAtom(
    id: 'view_toggle',
    label: 'Orders ↔ Patients view toggle',
    financialClass: LabAllFinancialClass.notRequired,
    requirement: LabAllAtomPermissions.viewToggle,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabAllFinancialAtom createOrder = LabAllFinancialAtom(
    id: 'create_lab_order',
    label: 'Create Lab Order (+ Review billing / bill-later)',
    financialClass: LabAllFinancialClass.createCharge,
    requirement: LabAllAtomPermissions.create,
    billingPath:
        'mergeClinicalRequestBilling → lab-order + persistLabOrderBilling',
  );

  static const LabAllFinancialAtom configure = LabAllFinancialAtom(
    id: 'configure',
    label: 'Lab Configurations / catalog unit prices',
    financialClass: LabAllFinancialClass.notBilled,
    requirement: LabAllAtomPermissions.configure,
    auditCode: 'NOT_BILLED',
  );

  static const LabAllFinancialAtom rowSelect = LabAllFinancialAtom(
    id: 'row_select',
    label: 'Row select / Next action → result entry',
    financialClass: LabAllFinancialClass.notRequired,
    requirement: LabAllAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabAllFinancialAtom createAdditional = LabAllFinancialAtom(
    id: 'create_additional_order',
    label: 'Detail Create additional order',
    financialClass: LabAllFinancialClass.createCharge,
    requirement: LabAllAtomPermissions.createAdditionalOrder,
    billingPath:
        'mergeClinicalRequestBilling → lab-order + persistLabOrderBilling',
  );

  static const LabAllFinancialAtom editOrder = LabAllFinancialAtom(
    id: 'edit_order',
    label: 'Detail Edit order (refresh Billing lines)',
    financialClass: LabAllFinancialClass.createCharge,
    requirement: LabAllAtomPermissions.editOrder,
    billingPath: 'updateOrder → resolveLabOrderBillingPayload / persist',
  );

  static const LabAllFinancialAtom deleteOrder = LabAllFinancialAtom(
    id: 'delete_order',
    label: 'Detail Delete order',
    financialClass: LabAllFinancialClass.reverse,
    requirement: LabAllAtomPermissions.deleteOrder,
    billingPath: 'reverseClinicalRequestBilling (lab-order)',
  );

  static const LabAllFinancialAtom reviewBilling = LabAllFinancialAtom(
    id: 'review_billing',
    label: 'Review billing in create/edit order dialog',
    financialClass: LabAllFinancialClass.createCharge,
    requirement: LabAllAtomPermissions.create,
    billingPath:
        'showResolvedClinicalRequestBillingDialog → ClinicalRequestBillingSubmit',
  );

  static const LabAllFinancialAtom billLater = LabAllFinancialAtom(
    id: 'bill_later_pending',
    label: 'Bill-later pending charge on create (no Review billing)',
    financialClass: LabAllFinancialClass.defer,
    requirement: LabAllAtomPermissions.create,
    billingPath: 'PENDING payment_status via clinical-request-billing',
  );

  static const LabAllFinancialAtom collectSample = LabAllFinancialAtom(
    id: 'collect_sample',
    label: 'Workflow Collect sample (payment-gated)',
    financialClass: LabAllFinancialClass.notRequired,
    requirement: LabAllAtomPermissions.workflowMutate,
    billingPath: 'assertLabOrderPaymentSatisfied before collect',
    auditCode: 'NOT_REQUIRED',
  );

  static const LabAllFinancialAtom receiveSample = LabAllFinancialAtom(
    id: 'receive_sample',
    label: 'Workflow Receive sample (payment-gated)',
    financialClass: LabAllFinancialClass.notRequired,
    requirement: LabAllAtomPermissions.workflowMutate,
    billingPath: 'assertLabOrderPaymentSatisfied before receive',
    auditCode: 'NOT_REQUIRED',
  );

  static const LabAllFinancialAtom verifyRelease = LabAllFinancialAtom(
    id: 'verify_release',
    label: 'Verify / release results (payment-gated)',
    financialClass: LabAllFinancialClass.notRequired,
    requirement: LabAllAtomPermissions.resultEntry,
    billingPath: 'assertLabOrderPaymentSatisfied before verify/release',
    auditCode: 'NOT_REQUIRED',
  );

  static const LabAllFinancialAtom resultEntryClinical = LabAllFinancialAtom(
    id: 'result_entry_clinical',
    label: 'Save draft / submit result (clinical only)',
    financialClass: LabAllFinancialClass.notBilled,
    requirement: LabAllAtomPermissions.resultEntry,
    auditCode: 'NOT_BILLED',
  );

  static const LabAllFinancialAtom openBilling = LabAllFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (navigate Billing when gate blocked)',
    financialClass: LabAllFinancialClass.defer,
    requirement: LabAllAtomPermissions.openBilling,
    billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
  );

  static const LabAllFinancialAtom previewReport = LabAllFinancialAtom(
    id: 'preview_report',
    label: 'Preview / print released report',
    financialClass: LabAllFinancialClass.notRequired,
    requirement: LabAllAtomPermissions.previewReport,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabAllFinancialAtom collectPayment = LabAllFinancialAtom(
    id: 'collect_payment',
    label: 'Receive payment / cashier collect',
    financialClass: LabAllFinancialClass.settle,
    requirement: LabAllAtomPermissions.openBilling,
    billingPath: 'Billing receive-payment (not mounted as cashier on All)',
    mounted: false,
  );

  static const LabAllFinancialAtom adjustRefund = LabAllFinancialAtom(
    id: 'adjust_refund',
    label: 'Adjust / refund / write-off / credit note',
    financialClass: LabAllFinancialClass.adjust,
    requirement: LabAllAtomPermissions.openBilling,
    billingPath: 'Billing adjustment / refund APIs',
    mounted: false,
  );

  static const List<LabAllFinancialAtom> all = <LabAllFinancialAtom>[
    tab,
    listChrome,
    emptyLoadingError,
    viewToggle,
    createOrder,
    configure,
    rowSelect,
    createAdditional,
    editOrder,
    deleteOrder,
    reviewBilling,
    billLater,
    collectSample,
    receiveSample,
    verifyRelease,
    resultEntryClinical,
    openBilling,
    previewReport,
    collectPayment,
    adjustRefund,
  ];

  static Iterable<LabAllFinancialAtom> get mountedAtoms =>
      all.where((LabAllFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<LabAllFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (LabAllFinancialAtom atom) =>
            atom.financialClass == LabAllFinancialClass.createCharge ||
            atom.financialClass == LabAllFinancialClass.settle ||
            atom.financialClass == LabAllFinancialClass.adjust ||
            atom.financialClass == LabAllFinancialClass.reverse ||
            atom.financialClass == LabAllFinancialClass.defer,
      );

  static bool get allBillableMountedUseSharedBilling {
    return billableMounted.every(
      (LabAllFinancialAtom atom) =>
          atom.billingPath != null && atom.billingPath!.trim().isNotEmpty,
    );
  }

  static bool forbidsInlineCollection(LabAllFinancialClass actionClass) {
    return switch (actionClass) {
      LabAllFinancialClass.settle ||
      LabAllFinancialClass.adjust ||
      LabAllFinancialClass.reverse ||
      LabAllFinancialClass.createCharge ||
      LabAllFinancialClass.defer => true,
      _ => false,
    };
  }
}

const String labAllBillingScopeNote =
    'Lab All is the full lab worklist. Create / edit orders post charges via '
    'clinical-request-billing (pending bill-later when Review billing is '
    'skipped). Delete reverses Billing snapshots. Collect, receive, verify, '
    'and release are blocked when Billing shows unpaid required charges unless '
    'PAID / NOT_REQUIRED / NO_CHARGE / NOT_BILLED. Open billing navigates the '
    'Billing module; settle/adjust/refund are not cashiered here. Catalog '
    'configuration and clinical result entry stay NOT_BILLED.';

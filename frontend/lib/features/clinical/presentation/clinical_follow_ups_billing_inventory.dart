import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum ClinicalFollowUpsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Clinical Follow-ups
/// (`/clinical?section=follow-ups`).
@immutable
final class ClinicalFollowUpsFinancialAtom {
  const ClinicalFollowUpsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final ClinicalFollowUpsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/clinical?section=follow-ups`.
///
/// Scope: tab chrome, hospital-wide [FollowUpWorklistPanel], row → detail
/// ([ReceptionFollowUpDetailDialog]), Mark completed, Reschedule / nested
/// [ClinicalFollowUpActionDialog], search/columns/empty/loading/retry, and
/// post-mutation list refresh. Callback complete and reschedule stay
/// NOT_BILLED ops. Patient visit/consult charges, receive-payment, and invoice
/// adjustments are not mounted here; if introduced they must post via Billing
/// (`clinical-request-billing` / receive-payment / adjustment)—never a
/// parallel cash ledger. Nested encounter / lab / radiology / pharmacy /
/// admission / discharge UI is not reachable from this tab.
abstract final class ClinicalFollowUpsBillingInventory {
  static const List<ClinicalFollowUpsFinancialAtom> atoms =
      <ClinicalFollowUpsFinancialAtom>[
        ClinicalFollowUpsFinancialAtom(
          id: 'tab_navigate',
          label:
              'Follow-ups tab (clinical:read ∩ encounters-vitals)',
          financialClass: ClinicalFollowUpsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'search_columns',
          label: 'Search / clear / columns / table settings',
          financialClass: ClinicalFollowUpsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: ClinicalFollowUpsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → Follow-up detail dialog',
          financialClass: ClinicalFollowUpsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'detail_close_readonly',
          label: 'Detail Close (read-only footer)',
          financialClass: ClinicalFollowUpsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'detail_mark_completed',
          label: 'Mark completed (callback worklist complete)',
          financialClass: ClinicalFollowUpsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'detail_reschedule',
          label: 'Reschedule follow-up',
          financialClass: ClinicalFollowUpsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'nested_save_follow_up',
          label: 'Save follow-up (nested reschedule dialog)',
          financialClass: ClinicalFollowUpsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'realtime_list_sync',
          label: 'Post-mutation Follow-ups list refresh',
          financialClass: ClinicalFollowUpsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'follow_up_visit_charge',
          label: 'Follow-up visit / consult charge on complete',
          financialClass: ClinicalFollowUpsFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: ClinicalFollowUpsFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        ClinicalFollowUpsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: ClinicalFollowUpsFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<ClinicalFollowUpsFinancialAtom> get billableClasses =>
      atoms.where(
        (ClinicalFollowUpsFinancialAtom atom) =>
            atom.financialClass ==
                ClinicalFollowUpsFinancialClass.createCharge ||
            atom.financialClass == ClinicalFollowUpsFinancialClass.settle ||
            atom.financialClass == ClinicalFollowUpsFinancialClass.adjust ||
            atom.financialClass == ClinicalFollowUpsFinancialClass.reverse ||
            atom.financialClass == ClinicalFollowUpsFinancialClass.defer,
      );

  static Iterable<ClinicalFollowUpsFinancialAtom> get mountedAtoms =>
      atoms.where((ClinicalFollowUpsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (ClinicalFollowUpsFinancialAtom atom) =>
        atom.financialClass == ClinicalFollowUpsFinancialClass.notRequired ||
        atom.financialClass == ClinicalFollowUpsFinancialClass.notBilled ||
        atom.financialClass == ClinicalFollowUpsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get followUpsTabHasNoBillableActions => billableClasses.every(
    (ClinicalFollowUpsFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Follow-ups financial scope for tests and audits.
const String clinicalFollowUpsBillingScopeNote =
    'Clinical Follow-ups is a hospital-wide scheduled callback worklist '
    '(FollowUpWorklistPanel). Mark completed and reschedule stay NOT_BILLED '
    'ops that update follow-up status/schedule only. Visit/consult charges, '
    'payment collection, and invoice adjustments are not mounted on this tab; '
    'they remain on the Billing module of record and must use '
    'clinical-request-billing when introduced.';

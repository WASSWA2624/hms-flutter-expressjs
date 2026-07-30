import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';

/// Financial action classification for the Claims **Authorizations** tab scan.
enum ClaimsAuthorizationsActionClass {
  /// Request / update pre-auth — limits constrain Billing coverage splits.
  defer,

  /// Read chrome, navigation, print, filters (balance unchanged).
  notBillable,
}

/// One financially relevant atom on the Authorizations tab (`?section=authorizations`).
final class ClaimsAuthorizationsFinancialAtom {
  const ClaimsAuthorizationsFinancialAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requirement,
    this.repositoryMethod,
    this.auditNote,
  });

  final String id;
  final String label;
  final ClaimsAuthorizationsActionClass actionClass;
  final AccessRequirement requirement;

  /// Shared claims / pre-auth API method — null when read-only.
  final String? repositoryMethod;
  final String? auditNote;
}

/// Canonical inventory of Authorizations tab financially relevant atoms (AC1).
///
/// Primary focus: pre-auth limits and covered amounts must constrain Billing
/// coverage splits. This tab does not collect cashier payments — request/update
/// are classified as [ClaimsAuthorizationsActionClass.defer].
abstract final class ClaimsAuthorizationsFinancialInventory {
  static const ClaimsAuthorizationsFinancialAtom tab =
      ClaimsAuthorizationsFinancialAtom(
    id: 'tab',
    label: 'Authorizations tab',
    actionClass: ClaimsAuthorizationsActionClass.notBillable,
    requirement: ClaimsAuthorizationsAtomPermissions.tab,
  );

  static const ClaimsAuthorizationsFinancialAtom listChrome =
      ClaimsAuthorizationsFinancialAtom(
    id: 'list_chrome',
    label: 'Search / columns / summary chips',
    actionClass: ClaimsAuthorizationsActionClass.notBillable,
    requirement: ClaimsAuthorizationsAtomPermissions.listChrome,
  );

  static const ClaimsAuthorizationsFinancialAtom detail =
      ClaimsAuthorizationsFinancialAtom(
    id: 'detail',
    label: 'Row select → detail',
    actionClass: ClaimsAuthorizationsActionClass.notBillable,
    requirement: ClaimsAuthorizationsAtomPermissions.detail,
  );

  static const ClaimsAuthorizationsFinancialAtom requestAuthorization =
      ClaimsAuthorizationsFinancialAtom(
    id: 'request_authorization',
    label: 'Request authorization',
    actionClass: ClaimsAuthorizationsActionClass.defer,
    requirement: ClaimsAuthorizationsAtomPermissions.requestAuthorization,
    repositoryMethod: 'requestPreAuthorization',
    auditNote:
        'Creates pre_authorization; approved limits constrain Billing coverage splits',
  );

  static const ClaimsAuthorizationsFinancialAtom updateStatus =
      ClaimsAuthorizationsFinancialAtom(
    id: 'update_status',
    label: 'Update authorization status',
    actionClass: ClaimsAuthorizationsActionClass.defer,
    requirement: ClaimsAuthorizationsAtomPermissions.update,
    repositoryMethod: 'updatePreAuthorization',
    auditNote:
        'APPROVED/PARTIAL approved_amount caps insurer share via coverage-split',
  );

  static const ClaimsAuthorizationsFinancialAtom nextAction =
      ClaimsAuthorizationsFinancialAtom(
    id: 'next_action',
    label: 'Next action: Update status',
    actionClass: ClaimsAuthorizationsActionClass.defer,
    requirement: ClaimsAuthorizationsAtomPermissions.nextAction,
    repositoryMethod: 'updatePreAuthorization',
  );

  static const ClaimsAuthorizationsFinancialAtom deepLinkPreauth =
      ClaimsAuthorizationsFinancialAtom(
    id: 'deep_link_preauth',
    label: 'Deep link action=preauth',
    actionClass: ClaimsAuthorizationsActionClass.defer,
    requirement: ClaimsAuthorizationsAtomPermissions.requestAuthorization,
    repositoryMethod: 'requestPreAuthorization',
  );

  static const ClaimsAuthorizationsFinancialAtom printStatement =
      ClaimsAuthorizationsFinancialAtom(
    id: 'print_statement',
    label: 'Print authorization statement',
    actionClass: ClaimsAuthorizationsActionClass.notBillable,
    requirement: ClaimsAuthorizationsAtomPermissions.document,
  );

  static const ClaimsAuthorizationsFinancialAtom billingImpact =
      ClaimsAuthorizationsFinancialAtom(
    id: 'billing_impact',
    label: 'Billing impact panel (read)',
    actionClass: ClaimsAuthorizationsActionClass.notBillable,
    requirement: ClaimsAuthorizationsAtomPermissions.detail,
    auditNote:
        'Shows approved/consumed/remaining from Billing-linked pre-auth — no local % math',
  );

  static const ClaimsAuthorizationsFinancialAtom emptyState =
      ClaimsAuthorizationsFinancialAtom(
    id: 'empty_state',
    label: 'Empty queue state',
    actionClass: ClaimsAuthorizationsActionClass.notBillable,
    requirement: ClaimsAuthorizationsAtomPermissions.listChrome,
  );

  static const ClaimsAuthorizationsFinancialAtom errorRetry =
      ClaimsAuthorizationsFinancialAtom(
    id: 'error_retry',
    label: 'Error / retry surface',
    actionClass: ClaimsAuthorizationsActionClass.notBillable,
    requirement: ClaimsAuthorizationsAtomPermissions.listChrome,
  );

  /// Every atom inventoried for the Authorizations tab scan.
  static const List<ClaimsAuthorizationsFinancialAtom> all =
      <ClaimsAuthorizationsFinancialAtom>[
    tab,
    listChrome,
    detail,
    requestAuthorization,
    updateStatus,
    nextAction,
    deepLinkPreauth,
    printStatement,
    billingImpact,
    emptyState,
    errorRetry,
  ];

  /// Defer mutations that must post through shared pre-auth → Billing handoff.
  static Iterable<ClaimsAuthorizationsFinancialAtom> get billableMutations =>
      all.where(
        (ClaimsAuthorizationsFinancialAtom atom) =>
            atom.repositoryMethod != null &&
            atom.actionClass != ClaimsAuthorizationsActionClass.notBillable,
      );

  /// True when the atom must never mutate balances outside Billing APIs.
  static bool forbidsInlineCollection(ClaimsAuthorizationsActionClass actionClass) {
    return switch (actionClass) {
      ClaimsAuthorizationsActionClass.defer => true,
      _ => false,
    };
  }
}

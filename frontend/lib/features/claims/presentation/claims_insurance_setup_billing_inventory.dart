import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum ClaimsInsuranceSetupFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Claims Insurance Setup
/// (`/claims?section=insurance-setup`).
@immutable
final class ClaimsInsuranceSetupFinancialAtom {
  const ClaimsInsuranceSetupFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final ClaimsInsuranceSetupFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/claims?section=insurance-setup`.
///
/// Tab role: payers / plans / scheme offers / enrollments / price book /
/// insurer API config. Creates persist catalog rows only — they must **not**
/// post patient invoices, payments, or adjustments. Pricing and coverage
/// enter Billing later via `price-resolver` + `coverage-split` at charge /
/// clinical-request resolve time. Enrollment stays PENDING until an explicit
/// verify path activates payer context.
abstract final class ClaimsInsuranceSetupBillingInventory {
  static const List<ClaimsInsuranceSetupFinancialAtom> atoms =
      <ClaimsInsuranceSetupFinancialAtom>[
        ClaimsInsuranceSetupFinancialAtom(
          id: 'tab_navigate',
          label: 'Insurance Setup tab (read ∪ + insurance-claims)',
          financialClass: ClaimsInsuranceSetupFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'setup_description',
          label: 'Setup description copy',
          financialClass: ClaimsInsuranceSetupFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'quick_actions_chrome',
          label: 'Quick actions titled panel (AppCollapsibleSection)',
          financialClass: ClaimsInsuranceSetupFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'add_company',
          label: 'Add company → POST /insurance-companies',
          financialClass: ClaimsInsuranceSetupFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'add_scheme',
          label: 'Add scheme → POST /coverage-plans',
          financialClass: ClaimsInsuranceSetupFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'add_offer',
          label: 'Add offer → POST /scheme-offers (price-resolver tier 1)',
          financialClass: ClaimsInsuranceSetupFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'enroll_patient',
          label:
              'Enroll patient → POST /patient-insurance-enrollments (PENDING)',
          financialClass: ClaimsInsuranceSetupFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'add_price_book',
          label: 'Add price book → POST /price-book-entries (resolver tiers 2–4)',
          financialClass: ClaimsInsuranceSetupFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'insurer_api',
          label: 'Insurer API → POST /insurer-integrations',
          financialClass: ClaimsInsuranceSetupFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'nested_catalog_dialogs',
          label: 'Nested catalog create dialogs (forms + validation + snackbar)',
          financialClass: ClaimsInsuranceSetupFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'post_mutation_refresh',
          label: 'Post-mutation claims workspace refresh / realtime',
          financialClass: ClaimsInsuranceSetupFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'catalog_update_delete',
          label: 'Catalog update / delete (permission atoms; UI unmounted)',
          financialClass: ClaimsInsuranceSetupFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          mounted: false,
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'silent_enrollment_auto_verify',
          label: 'Silent enrollment auto-verify to ACTIVE (removed leakage)',
          financialClass: ClaimsInsuranceSetupFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          mounted: false,
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'collect_payment',
          label: 'Collect / receive payment',
          financialClass: ClaimsInsuranceSetupFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'issue_invoice',
          label: 'Issue invoice / generate charge',
          financialClass: ClaimsInsuranceSetupFinancialClass.createCharge,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'adjust_refund_write_off',
          label: 'Adjust / refund / reverse / write-off / credit note',
          financialClass: ClaimsInsuranceSetupFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        ClaimsInsuranceSetupFinancialAtom(
          id: 'claim_settlement_remittance',
          label: 'Claim settlement / remittance → patient responsibility',
          financialClass: ClaimsInsuranceSetupFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<ClaimsInsuranceSetupFinancialAtom> get billableClasses =>
      atoms.where(
        (ClaimsInsuranceSetupFinancialAtom atom) =>
            atom.financialClass ==
                ClaimsInsuranceSetupFinancialClass.createCharge ||
            atom.financialClass == ClaimsInsuranceSetupFinancialClass.settle ||
            atom.financialClass == ClaimsInsuranceSetupFinancialClass.adjust ||
            atom.financialClass == ClaimsInsuranceSetupFinancialClass.reverse ||
            atom.financialClass == ClaimsInsuranceSetupFinancialClass.defer,
      );

  static Iterable<ClaimsInsuranceSetupFinancialAtom> get mountedAtoms =>
      atoms.where((ClaimsInsuranceSetupFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (ClaimsInsuranceSetupFinancialAtom atom) =>
        atom.financialClass ==
            ClaimsInsuranceSetupFinancialClass.notRequired ||
        atom.financialClass == ClaimsInsuranceSetupFinancialClass.notBilled ||
        atom.financialClass == ClaimsInsuranceSetupFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get insuranceSetupTabHasNoBillableActions =>
      billableClasses.every(
        (ClaimsInsuranceSetupFinancialAtom atom) => !atom.mounted,
      );
}

/// Documents Insurance Setup financial scope for tests and audits.
const String claimsInsuranceSetupBillingScopeNote =
    'Claims Insurance Setup maintains payers, plans, scheme offers, '
    'enrollments, price-book tariffs, and insurer integrations. Catalog '
    'creates stay NOT_BILLED — they do not post invoices or payments. '
    'Tariffs and coverage percentages feed Billing only through '
    'price-resolver and coverage-split at charge time. Enrollment remains '
    'PENDING until explicit verify activates payer context. Collect, issue, '
    'settle, and adjust remain on the Billing module / Active Claims paths.';

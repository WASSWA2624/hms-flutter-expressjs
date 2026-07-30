import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum MortuaryCustodyFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Mortuary Custody (`/mortuary?panel=custody`).
@immutable
final class MortuaryCustodyFinancialAtom {
  const MortuaryCustodyFinancialAtom({
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
  final MortuaryCustodyFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/mortuary?panel=custody`.
///
/// Tab role: custody chain worklist (read-only). Custody transfers / record
/// custody / post-mortem gates are logistics (`NOT_REQUIRED`) — they must not
/// invent a cash ledger and must preserve payer + balance continuity on the
/// linked case. Intake storage, embalming, viewing, and release fees post via
/// `persistMortuaryBillableEventBilling` (MORTUARY source) when fulfilled
/// elsewhere. Settle / adjust / refund stay on the Billing workspace (Open
/// billing). No module cashier on this tab.
abstract final class MortuaryCustodyBillingInventory {
  static const MortuaryCustodyFinancialAtom tab = MortuaryCustodyFinancialAtom(
    id: 'tab',
    label: 'Custody tab / count badge',
    financialClass: MortuaryCustodyFinancialClass.notRequired,
    requirement: MortuaryCustodyAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const MortuaryCustodyFinancialAtom listChrome =
      MortuaryCustodyFinancialAtom(
        id: 'list_chrome',
        label: 'Search / Clear / Filters / Settings / pagination',
        financialClass: MortuaryCustodyFinancialClass.notRequired,
        requirement: MortuaryCustodyAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryCustodyFinancialAtom emptyLoadingError =
      MortuaryCustodyFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: MortuaryCustodyFinancialClass.notRequired,
        requirement: MortuaryCustodyAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryCustodyFinancialAtom rowSelect =
      MortuaryCustodyFinancialAtom(
        id: 'row_select',
        label: 'Row select → custody detail',
        financialClass: MortuaryCustodyFinancialClass.notRequired,
        requirement: MortuaryCustodyAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryCustodyFinancialAtom nextAction =
      MortuaryCustodyFinancialAtom(
        id: 'next_action',
        label: 'Next action (guidance text only)',
        financialClass: MortuaryCustodyFinancialClass.notRequired,
        requirement: MortuaryCustodyAtomPermissions.nextAction,
        auditCode: 'NOT_REQUIRED',
      );

  static const MortuaryCustodyFinancialAtom billingStatusColumn =
      MortuaryCustodyFinancialAtom(
        id: 'billing_status_column',
        label: 'Billing status column (case ledger parity)',
        financialClass: MortuaryCustodyFinancialClass.defer,
        requirement: MortuaryCustodyAtomPermissions.listChrome,
        billingPath:
            'case.billing_status ← Billing invoice / mortuary_billable_event',
      );

  static const MortuaryCustodyFinancialAtom detailBillingPanel =
      MortuaryCustodyFinancialAtom(
        id: 'detail_billing_panel',
        label: 'Detail Billing events (read)',
        financialClass: MortuaryCustodyFinancialClass.defer,
        requirement: MortuaryCustodyAtomPermissions.billingPanel,
        billingPath:
            'billable_events.billing_reference_id → Billing invoice rows',
      );

  static const MortuaryCustodyFinancialAtom openBilling =
      MortuaryCustodyFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (settle / refund / adjust — Billing workspace)',
        financialClass: MortuaryCustodyFinancialClass.settle,
        requirement: MortuaryCustodyAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline cashier)',
      );

  static const MortuaryCustodyFinancialAtom printDocuments =
      MortuaryCustodyFinancialAtom(
        id: 'print_documents',
        label: 'Detail Print documents',
        financialClass: MortuaryCustodyFinancialClass.noCharge,
        requirement: MortuaryCustodyAtomPermissions.printDocuments,
        auditCode: 'NO_CHARGE',
      );

  static const MortuaryCustodyFinancialAtom recordCustody =
      MortuaryCustodyFinancialAtom(
        id: 'record_custody',
        label: 'Record custody / custody transfer (logistics; continuity)',
        financialClass: MortuaryCustodyFinancialClass.notRequired,
        requirement: MortuaryCustodyAtomPermissions.nestedWrite,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const MortuaryCustodyFinancialAtom postMortemRequest =
      MortuaryCustodyFinancialAtom(
        id: 'post_mortem_request',
        label: 'Post-mortem request / approve gate',
        financialClass: MortuaryCustodyFinancialClass.notRequired,
        requirement: MortuaryCustodyAtomPermissions.nestedWrite,
        auditCode: 'NOT_REQUIRED',
        mounted: false,
      );

  static const MortuaryCustodyFinancialAtom storageFee =
      MortuaryCustodyFinancialAtom(
        id: 'storage_fee',
        label: 'Intake / storage fee (fulfilled elsewhere)',
        financialClass: MortuaryCustodyFinancialClass.createCharge,
        requirement: MortuaryCustodyAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_STORAGE)',
        mounted: false,
      );

  static const MortuaryCustodyFinancialAtom embalmingFee =
      MortuaryCustodyFinancialAtom(
        id: 'embalming_fee',
        label: 'Embalming charge (fulfilled elsewhere)',
        financialClass: MortuaryCustodyFinancialClass.createCharge,
        requirement: MortuaryCustodyAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_EMBALMING)',
        mounted: false,
      );

  static const MortuaryCustodyFinancialAtom viewingFee =
      MortuaryCustodyFinancialAtom(
        id: 'viewing_fee',
        label: 'Viewing charge (fulfilled elsewhere)',
        financialClass: MortuaryCustodyFinancialClass.createCharge,
        requirement: MortuaryCustodyAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_VIEWING)',
        mounted: false,
      );

  static const MortuaryCustodyFinancialAtom releaseFee =
      MortuaryCustodyFinancialAtom(
        id: 'release_fee',
        label: 'Release charge (fulfilled elsewhere)',
        financialClass: MortuaryCustodyFinancialClass.createCharge,
        requirement: MortuaryCustodyAtomPermissions.billingPanel,
        billingPath:
            'persistMortuaryBillableEventBilling (MORTUARY / MORTUARY_RELEASE)',
        mounted: false,
      );

  static const MortuaryCustodyFinancialAtom collectPayment =
      MortuaryCustodyFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / deposit (absent — Billing owns)',
        financialClass: MortuaryCustodyFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment APIs',
        mounted: false,
      );

  static const MortuaryCustodyFinancialAtom adjustRefund =
      MortuaryCustodyFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note (absent)',
        financialClass: MortuaryCustodyFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<MortuaryCustodyFinancialAtom> all =
      <MortuaryCustodyFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextAction,
        billingStatusColumn,
        detailBillingPanel,
        openBilling,
        printDocuments,
        recordCustody,
        postMortemRequest,
        storageFee,
        embalmingFee,
        viewingFee,
        releaseFee,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<MortuaryCustodyFinancialAtom> get mountedAtoms =>
      all.where((MortuaryCustodyFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static Iterable<MortuaryCustodyFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (MortuaryCustodyFinancialAtom atom) =>
            atom.financialClass == MortuaryCustodyFinancialClass.createCharge ||
            atom.financialClass == MortuaryCustodyFinancialClass.settle ||
            atom.financialClass == MortuaryCustodyFinancialClass.adjust ||
            atom.financialClass == MortuaryCustodyFinancialClass.reverse ||
            atom.financialClass == MortuaryCustodyFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final MortuaryCustodyFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden — Billing owns payment.
  static bool forbidsInlineCashier(MortuaryCustodyFinancialClass actionClass) {
    return switch (actionClass) {
      MortuaryCustodyFinancialClass.settle ||
      MortuaryCustodyFinancialClass.adjust ||
      MortuaryCustodyFinancialClass.reverse ||
      MortuaryCustodyFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'Mortuary Custody is the custody-chain worklist. Transfers / record '
      'custody / post-mortem gates stay NOT_REQUIRED logistics with payer '
      'continuity. Storage / embalming / viewing / release fees post via '
      'persistMortuaryBillableEventBilling. Open billing navigates Billing. '
      'No module cashier.';
}

/// Documents Custody financial scope for tests and audits.
const String mortuaryCustodyBillingScopeNote =
    'Mortuary Custody is the custody chain queue. Record custody / transfer '
    'and post-mortem gates are NOT_REQUIRED logistics (no patient ledger; '
    'payer and balance continuity on the linked case). Storage, embalming, '
    'viewing, and release charges post via persistMortuaryBillableEventBilling '
    '(MORTUARY source / clinical-request-billing). Open billing navigates the '
    'Billing workspace with patient_id. Settle / adjust / refund are not '
    'mounted — Billing owns payment.';

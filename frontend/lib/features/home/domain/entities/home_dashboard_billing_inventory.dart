import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';

/// Financial action classification for the home dashboard scan.
enum HomeBillingActionClass {
  /// Creates invoice lines via Billing / clinical-request billing downstream.
  createCharge,

  /// Collects payment, applies deposit, or clears outstanding balance.
  settle,

  /// Discount, waive, write-off, credit note, or price correction.
  adjust,

  /// Refund, payment reversal, or void linked to Billing.
  reverse,

  /// Pay-later / outstanding status still recorded in Billing.
  defer,

  /// Read-only navigation, SaaS subscription, or audited no-charge protocol.
  notBillable,
}

/// One financially relevant atom reachable from the home dashboard.
final class HomeDashboardBillingAtom {
  const HomeDashboardBillingAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requiredPermissions,
    this.billingRoute = AppRoutes.billing,
    this.routeQuery = const <String, String>{},
    this.auditNote,
    this.auditCode,
    this.delegatesToModule,
  });

  final String id;
  final String label;
  final HomeBillingActionClass actionClass;
  final List<AppPermission> requiredPermissions;
  final AppRouteData billingRoute;
  final Map<String, String> routeQuery;
  final String? auditNote;

  /// Explicit not-billable protocol when [actionClass] is [HomeBillingActionClass.notBillable].
  final String? auditCode;
  final String? delegatesToModule;
}

/// Canonical inventory of financially relevant home dashboard atoms (AC1).
///
/// Home coordinates navigation and read-only KPIs; collection and ledger
/// mutations happen in Billing (or owning clinical modules via shared billing).
abstract final class HomeDashboardBillingInventory {
  static const List<AppPermission> billingRead = <AppPermission>[
    AppPermissions.billingRead,
  ];
  static const List<AppPermission> billingWrite = <AppPermission>[
    AppPermissions.billingWrite,
  ];
  static const List<AppPermission> financialApprove = <AppPermission>[
    AppPermissions.financialApprove,
  ];

  /// Quick actions / next steps that touch revenue or balances.
  static const Map<String, HomeDashboardBillingAtom> quickActions =
      <String, HomeDashboardBillingAtom>{
        'create_invoice': HomeDashboardBillingAtom(
          id: 'create_invoice',
          label: 'Create invoice',
          actionClass: HomeBillingActionClass.createCharge,
          requiredPermissions: billingWrite,
          routeQuery: <String, String>{},
        ),
        'receive_payment': HomeDashboardBillingAtom(
          id: 'receive_payment',
          label: 'Receive payment',
          actionClass: HomeBillingActionClass.settle,
          requiredPermissions: billingWrite,
        ),
        'process_refund': HomeDashboardBillingAtom(
          id: 'process_refund',
          label: 'Process refund',
          actionClass: HomeBillingActionClass.reverse,
          requiredPermissions: billingWrite,
        ),
        'close_shift': HomeDashboardBillingAtom(
          id: 'close_shift',
          label: 'Close shift',
          actionClass: HomeBillingActionClass.settle,
          requiredPermissions: billingWrite,
          auditNote: 'Shift close reconciles Billing payments',
        ),
        'review_overdue_invoices': HomeDashboardBillingAtom(
          id: 'review_overdue_invoices',
          label: 'Overdue invoices',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'overdue'},
          auditCode: 'NOT_REQUIRED',
          auditNote: 'Read-only Billing worklist navigation',
        ),
        'review_pending_payments': HomeDashboardBillingAtom(
          id: 'review_pending_payments',
          label: 'Pending payments',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'pendingPayment'},
          auditCode: 'NOT_REQUIRED',
        ),
        'review_claims_pending': HomeDashboardBillingAtom(
          id: 'review_claims_pending',
          label: 'Claims pending',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          billingRoute: AppRoutes.claims,
        ),
        'review_open_patient_balances': HomeDashboardBillingAtom(
          id: 'review_open_patient_balances',
          label: 'Open patient balances',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: <AppPermission>[AppPermissions.patientRead],
          billingRoute: AppRoutes.patients,
          routeQuery: <String, String>{'has_outstanding_balance': 'true'},
          auditCode: 'NOT_REQUIRED',
          auditNote: 'Patient list filtered by live Billing balance',
        ),
        'add_mortuary_billable_event': HomeDashboardBillingAtom(
          id: 'add_mortuary_billable_event',
          label: 'Add billable event',
          actionClass: HomeBillingActionClass.createCharge,
          requiredPermissions: <AppPermission>[
            AppPermissions.mortuaryBillingEvent,
          ],
          billingRoute: AppRoutes.mortuary,
          delegatesToModule: 'mortuary',
        ),
        'record_pharmacy_sale': HomeDashboardBillingAtom(
          id: 'record_pharmacy_sale',
          label: 'Create order',
          actionClass: HomeBillingActionClass.createCharge,
          requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
          billingRoute: AppRoutes.pharmacy,
          routeQuery: <String, String>{'section': 'sales'},
          delegatesToModule: 'pharmacy',
        ),
        'dispense_medication': HomeDashboardBillingAtom(
          id: 'dispense_medication',
          label: 'New orders',
          actionClass: HomeBillingActionClass.createCharge,
          requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
          billingRoute: AppRoutes.pharmacy,
          routeQuery: <String, String>{'section': 'orders'},
          delegatesToModule: 'pharmacy',
        ),
        'order_lab': HomeDashboardBillingAtom(
          id: 'order_lab',
          label: 'Order lab test',
          actionClass: HomeBillingActionClass.createCharge,
          requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
          billingRoute: AppRoutes.clinical,
          routeQuery: <String, String>{'section': 'assigned-to-me'},
          delegatesToModule: 'lab',
          auditNote: 'Ordered from Clinical; lab billing at request time',
        ),
        'order_radiology': HomeDashboardBillingAtom(
          id: 'order_radiology',
          label: 'Order imaging',
          actionClass: HomeBillingActionClass.createCharge,
          requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
          billingRoute: AppRoutes.clinical,
          routeQuery: <String, String>{'section': 'assigned-to-me'},
          delegatesToModule: 'radiology',
          auditNote: 'Ordered from Clinical; radiology billing at request time',
        ),
        'manage_subscription': HomeDashboardBillingAtom(
          id: 'manage_subscription',
          label: 'Manage subscription',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: <AppPermission>[AppPermissions.platformAdmin],
          billingRoute: AppRoutes.subscriptions,
          auditCode: 'NOT_BILLED',
          auditNote: 'SaaS subscription path — not patient ledger',
        ),
      };

  /// KPI cards that surface balances or collections (read-only on home).
  static const Map<String, HomeDashboardBillingAtom> statusCards =
      <String, HomeDashboardBillingAtom>{
        'collections_today': HomeDashboardBillingAtom(
          id: 'collections_today',
          label: 'Collections today',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: billingRead,
          auditCode: 'NOT_REQUIRED',
          auditNote: 'Live Billing payment aggregate — navigate only',
        ),
        'billing_exceptions': HomeDashboardBillingAtom(
          id: 'billing_exceptions',
          label: 'Billing exceptions',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'overdue'},
          auditCode: 'NOT_REQUIRED',
        ),
        'billing_pending': HomeDashboardBillingAtom(
          id: 'billing_pending',
          label: 'Billing pending',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'pendingPayment'},
        ),
        'pending_balance_amount': HomeDashboardBillingAtom(
          id: 'pending_balance_amount',
          label: 'Pending balances',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'pendingPayment'},
          auditNote: 'Value = Billing balance_due aggregate',
        ),
        'pending_payments': HomeDashboardBillingAtom(
          id: 'pending_payments',
          label: 'Pending payments',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'pendingPayment'},
        ),
        'overdue_balance_amount': HomeDashboardBillingAtom(
          id: 'overdue_balance_amount',
          label: 'Overdue amount',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'overdue'},
          auditNote: 'Value = Billing balance_due for OVERDUE invoices',
        ),
        'overdue_invoices': HomeDashboardBillingAtom(
          id: 'overdue_invoices',
          label: 'Overdue invoices',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'overdue'},
        ),
        'open_balances': HomeDashboardBillingAtom(
          id: 'open_balances',
          label: 'Open balances',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'pendingPayment'},
        ),
        'invoices_today': HomeDashboardBillingAtom(
          id: 'invoices_today',
          label: 'Invoices today',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'needsIssue'},
          auditCode: 'NOT_REQUIRED',
        ),
        'refunds_today': HomeDashboardBillingAtom(
          id: 'refunds_today',
          label: 'Refunds today',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: billingWrite,
          auditCode: 'NOT_REQUIRED',
        ),
        'pending_approvals': HomeDashboardBillingAtom(
          id: 'pending_approvals',
          label: 'Pending approvals',
          actionClass: HomeBillingActionClass.adjust,
          requiredPermissions: financialApprove,
          routeQuery: <String, String>{'queue': 'approvalRequired'},
        ),
        'pending_insurance_claims': HomeDashboardBillingAtom(
          id: 'pending_insurance_claims',
          label: 'Claims pending',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'claimsPending'},
        ),
        'my_open_bills': HomeDashboardBillingAtom(
          id: 'my_open_bills',
          label: 'My open bills',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'pendingPayment'},
        ),
        'open_invoices': HomeDashboardBillingAtom(
          id: 'open_invoices',
          label: 'Open invoices',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'pendingPayment'},
        ),
        'payments_today': HomeDashboardBillingAtom(
          id: 'payments_today',
          label: 'Payments today',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: billingRead,
          auditCode: 'NOT_REQUIRED',
        ),
        'billable_events_to_capture': HomeDashboardBillingAtom(
          id: 'billable_events_to_capture',
          label: 'Billable events to capture',
          actionClass: HomeBillingActionClass.createCharge,
          requiredPermissions: <AppPermission>[
            AppPermissions.mortuaryBillingEvent,
          ],
          billingRoute: AppRoutes.mortuary,
          delegatesToModule: 'mortuary',
        ),
      };

  /// Navigation shortcuts with billing impact.
  static const Map<String, HomeDashboardBillingAtom> shortcuts =
      <String, HomeDashboardBillingAtom>{
        'billing': HomeDashboardBillingAtom(
          id: 'billing',
          label: 'Billing',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: billingRead,
          auditCode: 'NOT_REQUIRED',
        ),
        'claims': HomeDashboardBillingAtom(
          id: 'claims',
          label: 'Claims',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: billingRead,
          billingRoute: AppRoutes.claims,
          auditCode: 'NOT_REQUIRED',
        ),
        'discharge': HomeDashboardBillingAtom(
          id: 'discharge',
          label: 'Discharge',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
          billingRoute: AppRoutes.discharge,
          auditNote: 'Financial clearance enforced in discharge workspace',
        ),
        'subscriptions': HomeDashboardBillingAtom(
          id: 'subscriptions',
          label: 'Subscriptions',
          actionClass: HomeBillingActionClass.notBillable,
          requiredPermissions: <AppPermission>[AppPermissions.subscriptionsRead],
          billingRoute: AppRoutes.subscriptions,
          auditCode: 'NOT_BILLED',
          auditNote: 'Commercial SaaS billing — not patient ledger',
        ),
      };

  /// Guided alerts / queue rows that surface billing worklists (read-only).
  static const Map<String, HomeDashboardBillingAtom> worklistItems =
      <String, HomeDashboardBillingAtom>{
        'guided_billing_follow_up': HomeDashboardBillingAtom(
          id: 'guided_billing_follow_up',
          label: 'Billing follow-up queue',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'pendingPayment'},
        ),
        'guided_billing_exceptions': HomeDashboardBillingAtom(
          id: 'guided_billing_exceptions',
          label: 'Billing follow-up',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'overdue'},
        ),
        'guided_overdue_invoices': HomeDashboardBillingAtom(
          id: 'guided_overdue_invoices',
          label: 'Overdue invoices',
          actionClass: HomeBillingActionClass.defer,
          requiredPermissions: billingRead,
          routeQuery: <String, String>{'queue': 'overdue'},
        ),
      };

  /// Every catalogued quick action id declared in [homeActionLibrary].
  static Iterable<String> get cataloguedFinancialQuickActionIds =>
      quickActions.keys;

  /// Returns true when a home quick action routes through Billing (not shadow ledger).
  static bool quickActionUsesBillingModule(String actionId) {
    final String canonical = homeCanonicalActionId(actionId);
    final HomeDashboardBillingAtom? atom = quickActions[canonical];
    if (atom == null) {
      return false;
    }
    if (atom.delegatesToModule != null) {
      return true;
    }
    return atom.billingRoute.path == AppRoutes.billing.path ||
        atom.billingRoute.path == AppRoutes.claims.path;
  }

  /// Billable classes that must never mutate balances on the home tab itself.
  static bool isInlineCollectionForbidden(HomeBillingActionClass actionClass) {
    return switch (actionClass) {
      HomeBillingActionClass.settle ||
      HomeBillingActionClass.adjust ||
      HomeBillingActionClass.reverse => true,
      _ => false,
    };
  }

  /// Every inventoried atom across quick actions, KPIs, shortcuts, and worklists.
  static Iterable<HomeDashboardBillingAtom> get allAtoms sync* {
    yield* quickActions.values;
    yield* statusCards.values;
    yield* shortcuts.values;
    yield* worklistItems.values;
  }

  /// Not-billable atoms must declare an explicit audit protocol code.
  static bool hasExplicitNotBillableAudit(HomeDashboardBillingAtom atom) {
    if (atom.actionClass != HomeBillingActionClass.notBillable) {
      return true;
    }
    final String? code = atom.auditCode?.trim().toUpperCase();
    return code == 'NOT_BILLED' ||
        code == 'NOT_REQUIRED' ||
        code == 'NO_CHARGE';
  }
}

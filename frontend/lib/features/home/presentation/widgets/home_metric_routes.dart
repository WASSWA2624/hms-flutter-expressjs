import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_billing_inventory.dart';
import 'package:hosspi_hms/features/home/presentation/home_access.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_workspace_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Whether the user may open HR workforce modals from the home dashboard.
bool homeHrMetricAccessAllowed(AppAccessPolicy policy) {
  if (!policy.hasAllActiveModules(<String>['hr'])) {
    return false;
  }
  return policy.grantsAny(<AppPermission>[
    AppPermissions.hrRead,
    AppPermissions.rosterRead,
  ]);
}

/// Default Billing workspace deep links for financial KPI cards.
Map<String, String> homeDefaultBillingMetricQuery(String cardId) {
  return switch (cardId.trim().toLowerCase()) {
    'overdue_balance_amount' ||
    'overdue_invoices' ||
    'billing_exceptions' => <String, String>{'queue': 'overdue'},
    'pending_balance_amount' ||
    'open_balances' ||
    'billing_pending' ||
    'pending_payments' ||
    'my_open_bills' ||
    'open_invoices' => <String, String>{'queue': 'pendingPayment'},
    'invoices_today' => <String, String>{'queue': 'needsIssue'},
    'pending_approvals' => <String, String>{'queue': 'needsApproval'},
    'pending_insurance_claims' => <String, String>{'queue': 'claimsPending'},
    _ => const <String, String>{},
  };
}

/// Inclusive local-day start / exclusive next-day end for pharmacy date filters.
({DateTime from, DateTime to}) homePharmacyMostSoldPeriodBounds(
  HomeMostSoldPeriod period, {
  DateTime? now,
}) {
  final DateTime clock = now ?? DateTime.now();
  final DateTime startOfToday = DateTime(clock.year, clock.month, clock.day);
  final DateTime endExclusive = startOfToday.add(const Duration(days: 1));
  // Keep aligned with backend `resolveMostSoldWindow`.
  final DateTime from = switch (period) {
    HomeMostSoldPeriod.today => startOfToday,
    HomeMostSoldPeriod.lastWeek =>
      startOfToday.subtract(const Duration(days: 6)),
    HomeMostSoldPeriod.lastMonth =>
      startOfToday.subtract(const Duration(days: 30)),
    HomeMostSoldPeriod.lastThreeMonths =>
      startOfToday.subtract(const Duration(days: 90)),
    HomeMostSoldPeriod.lastSixMonths =>
      startOfToday.subtract(const Duration(days: 180)),
    HomeMostSoldPeriod.lastYear =>
      startOfToday.subtract(const Duration(days: 365)),
    HomeMostSoldPeriod.lastFiveYears =>
      startOfToday.subtract(const Duration(days: 365 * 5)),
    HomeMostSoldPeriod.custom => startOfToday,
  };
  return (from: from, to: endExclusive);
}

/// `from` / `to` query params for a most-sold / status-mix period preset.
Map<String, String> homePharmacyMostSoldPeriodQuery(
  HomeMostSoldPeriod period, {
  DateTime? now,
}) {
  final ({DateTime from, DateTime to}) bounds =
      homePharmacyMostSoldPeriodBounds(period, now: now);
  String iso(DateTime value) => value.toUtc().toIso8601String();
  return <String, String>{
    'from': iso(bounds.from),
    'to': iso(bounds.to),
  };
}

/// Order-status mix legend → `/pharmacy` section + matching period window.
Map<String, String> homePharmacyStatusMixQuery({
  required String section,
  required HomeMostSoldPeriod period,
  DateTime? now,
}) {
  return <String, String>{
    'section': section,
    ...homePharmacyMostSoldPeriodQuery(period, now: now),
  };
}

/// Pharmacist home KPI → `/pharmacy` section + facility-local date range.
///
/// Sales week = trailing 7 calendar days including today.
Map<String, String> homePharmacyMetricQuery(String cardId) {
  final DateTime now = DateTime.now();
  final DateTime startOfToday = DateTime(now.year, now.month, now.day);
  final DateTime endExclusive = startOfToday.add(const Duration(days: 1));
  final DateTime weekStart = startOfToday.subtract(const Duration(days: 6));
  String iso(DateTime value) => value.toUtc().toIso8601String();

  return switch (cardId.trim().toLowerCase()) {
    'orders_today' => <String, String>{
      'section': 'all',
      'from': iso(startOfToday),
      'to': iso(endExclusive),
    },
    'pending_dispense' => <String, String>{'section': 'queue'},
    'dispensed_today' || 'sales_today' => <String, String>{
      'section': 'completed',
      'from': iso(startOfToday),
      'to': iso(endExclusive),
    },
    'sales_this_week' => <String, String>{
      'section': 'completed',
      'from': iso(weekStart),
      'to': iso(endExclusive),
    },
    'low_stock' || 'critical_stock' => <String, String>{
      'section': 'low-stock',
    },
    'near_expiry' || 'near-expiry' || 'expiring' => <String, String>{
      'section': 'near-expiry',
    },
    'expired' || 'expired_stock' => <String, String>{
      'section': 'expired',
    },
    _ => const <String, String>{},
  };
}

/// Canonical Billing / Claims routes for balance and collection KPIs (any persona).
HomeMetricNavigation? homeBillingMetricNavigation({
  required String cardId,
  required HomeDashboardProfile profile,
  required AppAccessPolicy policy,
}) {
  final String normalized = cardId.trim().toLowerCase();
  if (!HomeDashboardBillingInventory.statusCards.containsKey(normalized)) {
    return null;
  }
  final HomeDashboardBillingAtom atom =
      HomeDashboardBillingInventory.statusCards[normalized]!;
  if (!homeAllows(policy, homeAtomRequirement(atom.requiredPermissions))) {
    return null;
  }

  final AppRouteData route = atom.billingRoute;
  if (!canAccessShellRoute(route, policy)) {
    return null;
  }

  final HomeMetricRouteTarget? target = profile.metricRouteTargets[normalized];
  final Map<String, String> queryParameters = target?.queryParameters.isNotEmpty == true
      ? target!.queryParameters
      : atom.routeQuery.isNotEmpty
      ? atom.routeQuery
      : homeDefaultBillingMetricQuery(normalized);

  return HomeMetricNavigation(route: route, queryParameters: queryParameters);
}

/// Resolves a tappable destination for a home KPI card when the profile defines one.
HomeMetricNavigation? homeMetricNavigation({
  required HomeDashboardProfile profile,
  required HomeStatusCard card,
  required AppAccessPolicy policy,
}) {
  if (!homeAllows(
        policy,
        homeStatusCardRequirement(
          id: card.id,
          declared: card.requiredPermissions,
        ),
      ) ||
      card.effectiveRequiredPermissions.isEmpty) {
    return null;
  }
  if (profile.metricActionTargets.containsKey(card.id)) {
    return null;
  }
  final HomeMetricNavigation? billingNavigation = homeBillingMetricNavigation(
    cardId: card.id,
    profile: profile,
    policy: policy,
  );
  if (billingNavigation != null) {
    return billingNavigation;
  }
  if (profile.metricRouteTargets.containsKey(card.id)) {
    final AppRouteData? route = _clinicalMetricRoute(
      cardId: card.id,
      profile: profile,
      policy: policy,
    );
    if (route != null && canAccessShellRoute(route, policy)) {
      final Map<String, String> profileQuery =
          profile.metricRouteTargets[card.id]?.queryParameters ??
          const <String, String>{};
      final Map<String, String> pharmacyQuery = profile.id == 'pharmacist'
          ? homePharmacyMetricQuery(card.id)
          : const <String, String>{};
      return HomeMetricNavigation(
        route: route,
        queryParameters: pharmacyQuery.isNotEmpty ? pharmacyQuery : profileQuery,
      );
    }
    // Department / clinical packs declare routes explicitly — do not fall
    // through to the HR workspace when the mapped shell route is denied.
    if (profile.id != 'hr') {
      return null;
    }
  }
  final HomeMetricRouteTarget? target = profile.metricRouteTargets[card.id];
  if (target == null) {
    return null;
  }
  if (!homeHrMetricAccessAllowed(policy)) {
    return null;
  }

  return HomeMetricNavigation(
    route: AppRoutes.hr,
    queryParameters: target.queryParameters,
  );
}

/// Resolves an in-place modal action for a home KPI card.
HomeMetricAction? homeMetricAction({
  required HomeDashboardProfile profile,
  required HomeStatusCard card,
  required AppAccessPolicy policy,
}) {
  if (!homeAllows(
        policy,
        homeStatusCardRequirement(
          id: card.id,
          declared: card.requiredPermissions,
        ),
      ) ||
      card.effectiveRequiredPermissions.isEmpty) {
    return null;
  }
  final HomeMetricActionTarget? target = profile.metricActionTargets[card.id];
  if (target == null) {
    return null;
  }
  if (!homeHrMetricAccessAllowed(policy)) {
    return null;
  }
  return HomeMetricAction(target: target);
}

AppRouteData? _clinicalMetricRoute({
  required String cardId,
  required HomeDashboardProfile profile,
  required AppAccessPolicy policy,
}) {
  if (profile.id == 'doctor') {
    return switch (cardId) {
      'assigned' || 'in_progress' || 'follow_ups_due'
          when policy.grants(AppPermissions.clinicalRead) =>
        AppRoutes.clinical,
      'results_pending_review' when policy.grants(AppPermissions.labRead) =>
        AppRoutes.lab,
      'radiology_pending' when policy.grants(AppPermissions.radiologyRead) =>
        AppRoutes.radiology,
      'prescriptions_pending' when policy.grants(AppPermissions.pharmacyRead) =>
        AppRoutes.pharmacy,
      'emergency_cases_today'
          when policy.grants(AppPermissions.emergencyRead) =>
        AppRoutes.emergency,
      'shifts_today' when policy.grants(AppPermissions.rosterRead) =>
        AppRoutes.hr,
      _ => null,
    };
  }

  if (profile.id == 'nurse') {
    return switch (cardId) {
      'inpatient_flow' || 'transfer_queue' || 'discharge_pressure'
          when policy.grants(AppPermissions.clinicalRead) =>
        AppRoutes.ipd,
      'med_admin_today' when policy.grants(AppPermissions.clinicalWrite) =>
        AppRoutes.nursing,
      'critical_labs' when policy.grants(AppPermissions.labRead) =>
        AppRoutes.lab,
      'opd_notifications_attention' || 'appointments_today'
          when policy.grants(AppPermissions.patientRead) =>
        AppRoutes.opd,
      'emergency_cases_today'
          when policy.grants(AppPermissions.emergencyRead) =>
        AppRoutes.emergency,
      'theatre_cases_today' when policy.grants(AppPermissions.clinicalRead) =>
        AppRoutes.theater,
      'radiology_pending' when policy.grants(AppPermissions.radiologyRead) =>
        AppRoutes.radiology,
      _ => null,
    };
  }

  if (profile.id == 'lab_tech' && policy.grants(AppPermissions.labRead)) {
    return AppRoutes.lab;
  }

  if (profile.id == 'pharmacist') {
    return switch (cardId) {
      'billing_pending' when policy.grants(AppPermissions.billingRead) =>
        AppRoutes.billing,
      _
          when policy.grantsAny(const <AppPermission>[
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
          ]) =>
        AppRoutes.pharmacy,
      _ => null,
    };
  }

  if (profile.id == 'receptionist') {
    return switch (cardId) {
      'registrations_today' when policy.grants(AppPermissions.patientRead) =>
        AppRoutes.patients,
      'appointments_today' ||
      'desk_queue' ||
      'turnaround_pressure' ||
      'no_show_pressure' ||
      'opd_notifications_attention' ||
      'emergency_cases_today'
          when policy.grants(AppPermissions.patientRead) =>
        AppRoutes.reception,
      'pending_balance_amount' when policy.grants(AppPermissions.billingRead) =>
        AppRoutes.billing,
      _ => null,
    };
  }

  if (profile.id == 'super_admin') {
    return switch (cardId) {
      'pending_registration_approvals' ||
      'tenants_active' ||
      'facilities_active'
          when policy.grants(AppPermissions.systemAdmin) =>
        AppRoutes.tenantFacilitySetup,
      'subscriptions_health'
          when policy.grants(AppPermissions.subscriptionsRead) =>
        AppRoutes.subscriptions,
      'module_entitlement_issues'
          when policy.grants(AppPermissions.systemAdmin) =>
        AppRoutes.subscriptions,
      _ => null,
    };
  }

  return null;
}

/// Opens the HR modal mapped to a workforce dashboard metric card.
Future<void> resolveHrMetricModal(
  BuildContext context,
  WidgetRef ref, {
  required HomeMetricActionTarget target,
}) async {
  switch (target.kind) {
    case HomeMetricActionKind.hrStaffDirectory:
      await showHrStaffDirectoryDialog(
        context,
        ref,
        statusFilter: target.staffStatusFilter,
        maximize: true,
      );
    case HomeMetricActionKind.hrWorkQueue:
      final HrQueue? queue = HrQueue.fromValue(target.hrQueue);
      if (queue == null) {
        return;
      }
      await applyHrQueueAndShow(
        context,
        ref,
        queue,
        maximize: true,
        status: target.workItemStatus,
      );
    case HomeMetricActionKind.hrTodayShifts:
      await showHrTodayShiftsDialog(context, ref);
    case HomeMetricActionKind.hrOnLeaveToday:
      await showHrOnLeaveTodayDialog(context, ref);
    case HomeMetricActionKind.hrAttendedToday:
      await showHrAttendedTodayDialog(context, ref);
  }
}

final class HomeMetricNavigation {
  const HomeMetricNavigation({
    required this.route,
    this.queryParameters = const <String, String>{},
  });

  final AppRouteData route;
  final Map<String, String> queryParameters;
}

final class HomeMetricAction {
  const HomeMetricAction({required this.target});

  final HomeMetricActionTarget target;

  Future<void> invoke(BuildContext context, WidgetRef ref) {
    return resolveHrMetricModal(context, ref, target: target);
  }
}

/// Maps home queue / alert route targets to module deep-link query parameters.
Map<String, String> homeRouteQueryForTarget(HomeRouteTarget? target) {
  if (target == null) {
    return const <String, String>{};
  }

  final Map<String, String> hr = homeHrQueryForTarget(target);
  if (hr.isNotEmpty) {
    return hr;
  }
  return homeLabQueryForTarget(target);
}

/// Maps HR workspace queue row targets to `/hr` deep-link query parameters.
Map<String, String> homeHrQueryForTarget(HomeRouteTarget? target) {
  if (target == null) {
    return const <String, String>{};
  }
  if (target.moduleSlug.toLowerCase() != 'hr') {
    return const <String, String>{};
  }

  final String? queue = switch ((target.resource ?? '').toLowerCase()) {
    'staff-leaves' => 'LEAVE_REQUESTS',
    'shift-swap-requests' => 'SWAP_REQUESTS',
    'nurse-rosters' => 'ROSTER_DRAFTS',
    'shifts' => 'UNASSIGNED_SHIFTS',
    'payroll-runs' => 'PAYROLL_DRAFTS',
    _ => null,
  };
  if (queue == null) {
    return const <String, String>{};
  }
  return <String, String>{'queue': queue};
}

/// Maps lab queue row targets to `/lab` deep-link query parameters.
Map<String, String> homeLabQueryForTarget(HomeRouteTarget? target) {
  if (target == null) {
    return const <String, String>{};
  }
  final String slug = target.moduleSlug.toLowerCase();
  if (slug != 'lab' && slug != 'laboratory') {
    return const <String, String>{};
  }

  final Map<String, String> query = <String, String>{'section': 'worklist'};
  final String? orderId = target.publicId?.trim();
  if (orderId != null && orderId.isNotEmpty) {
    query['order'] = orderId;
  }
  return query;
}

/// Compact workforce metric labels for narrow dashboard layouts.
String homeMetricCardLabel(
  AppLocalizations l10n,
  HomeStatusCard card, {
  bool compact = false,
}) {
  if (!compact) {
    return card.label;
  }
  return switch (card.id) {
    'active_staff' => l10n.homeMetricActiveStaffCompact,
    'shifts_today' => l10n.homeMetricShiftsTodayCompact,
    'pending_leaves' => l10n.homeMetricPendingLeavesCompact,
    'on_leave_today' => l10n.homeMetricOnLeaveTodayCompact,
    'unassigned_shifts' => l10n.homeMetricUnassignedShiftsCompact,
    'attended_today' => l10n.homeMetricAttendedTodayCompact,
    'missed_shifts_today' => l10n.homeMetricMissedShiftsTodayCompact,
    'payroll_pending' => l10n.homeMetricPayrollPendingCompact,
    _ => card.label,
  };
}

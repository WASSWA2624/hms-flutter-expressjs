import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
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

/// Resolves a tappable destination for a home KPI card when the profile defines one.
HomeMetricNavigation? homeMetricNavigation({
  required HomeDashboardProfile profile,
  required HomeStatusCard card,
  required AppAccessPolicy policy,
}) {
  if (profile.metricActionTargets.containsKey(card.id)) {
    return null;
  }
  if (profile.metricRouteTargets.containsKey(card.id)) {
    final AppRouteData? route = _clinicalMetricRoute(
      cardId: card.id,
      profile: profile,
      policy: policy,
    );
    if (route != null) {
      return HomeMetricNavigation(
        route: route,
        queryParameters:
            profile.metricRouteTargets[card.id]?.queryParameters ??
            const <String, String>{},
      );
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
      'assigned' ||
      'in_progress' ||
      'follow_ups_due' when policy.grants(AppPermissions.clinicalRead) =>
        AppRoutes.clinical,
      'results_pending_review' when policy.grants(AppPermissions.labRead) =>
        AppRoutes.lab,
      _ => null,
    };
  }

  if (profile.id == 'nurse') {
    return switch (cardId) {
      'inpatient_flow' ||
      'transfer_queue' ||
      'discharge_pressure' when policy.grants(AppPermissions.clinicalRead) =>
        AppRoutes.ipd,
      'med_admin_today' when policy.grants(AppPermissions.clinicalWrite) =>
        AppRoutes.nursing,
      'critical_labs' when policy.grants(AppPermissions.labRead) =>
        AppRoutes.lab,
      'opd_notifications_attention' ||
      'appointments_today' when policy.grants(AppPermissions.patientRead) =>
        AppRoutes.opd,
      'emergency_cases_today' when policy.grants(AppPermissions.emergencyRead) =>
        AppRoutes.emergency,
      'theatre_cases_today' when policy.grants(AppPermissions.clinicalRead) =>
        AppRoutes.theater,
      'radiology_pending' when policy.grants(AppPermissions.radiologyRead) =>
        AppRoutes.radiology,
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

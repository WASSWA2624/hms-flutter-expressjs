import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_access.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_scope.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_sync.dart';
import 'package:hosspi_hms/features/home/presentation/home_access.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_context_panel.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_mapper.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/pharmacy_most_sold_charts.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/reception_desk_charts.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({this.request = HomeDashboardRequest.empty, super.key});

  final HomeDashboardRequest request;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _boundSessionScope;
  /// True after an account/auth-scope change until a fresh load cycle finishes.
  bool _awaitingFreshDashboard = false;
  bool _sawLoadingAfterScopeChange = false;

  @override
  Widget build(BuildContext context) {
    final HomeDashboardRequest request = widget.request;
    final String sessionScope = ref.watch(
      sessionStateProvider.select(dashboardSessionScope),
    );
    if (_boundSessionScope != sessionScope) {
      if (_boundSessionScope != null) {
        _awaitingFreshDashboard = true;
        _sawLoadingAfterScopeChange = false;
        Future<void>.microtask(() {
          if (!mounted) {
            return;
          }
          homeClearDashboardOptimisticPatch(ref, request);
          ref.invalidate(homeCoreControllerProvider(request));
          ref.invalidate(homeControllerProvider(request));
          ref.invalidate(homeLookupsControllerProvider(request));
        });
      }
      _boundSessionScope = sessionScope;
    }

    final dashboard = watchHomeDashboardForWidget(ref, request);
    final AsyncValue<Result<HomeDashboard>> fullDashboard = ref.watch(
      homeControllerProvider(request),
    );
    if (_awaitingFreshDashboard && dashboard.isLoading) {
      _sawLoadingAfterScopeChange = true;
    }
    // Same-role account switches (e.g. platform admin A → B) keep prior AsyncData
    // until reload finishes. Never clear on role match alone — that re-exposes
    // the previous user's metrics. Require a real load cycle after the scope
    // change (local sync dashboards still briefly enter loading).
    if (_awaitingFreshDashboard &&
        _sawLoadingAfterScopeChange &&
        !dashboard.isLoading &&
        (dashboard.hasValue || dashboard.hasError)) {
      _awaitingFreshDashboard = false;
      _sawLoadingAfterScopeChange = false;
    }

    final HomeDashboardOptimisticPatchState? optimisticState = ref.watch(
      homeDashboardOptimisticPatchProvider(request),
    );
    final l10n = context.l10n;

    ref.listen(appAccessPolicyProvider, (
      AppAccessPolicy? previous,
      AppAccessPolicy next,
    ) {
      final HomeDashboard? loaded = readSuccessfulHomeDashboard(ref, request);
      if (loaded == null || _awaitingFreshDashboard) {
        return;
      }
      final HomeDashboardProfile expected = homeProfileForAccessPolicy(next);
      if (loaded.profile.role == expected.role) {
        return;
      }
      setState(() {
        _awaitingFreshDashboard = true;
        _sawLoadingAfterScopeChange = false;
      });
      homeClearDashboardOptimisticPatch(ref, request);
      ref.invalidate(homeCoreControllerProvider(request));
      ref.invalidate(homeControllerProvider(request));
      ref.invalidate(homeLookupsControllerProvider(request));
    });

    ref.listen(homeControllerProvider(request), (
      AsyncValue<Result<HomeDashboard>>? previous,
      AsyncValue<Result<HomeDashboard>> next,
    ) {
      next.whenOrNull(
        data: (Result<HomeDashboard> result) {
          result.when(
            success: (HomeDashboard dashboard) =>
                homeClearDashboardOptimisticPatchIfSatisfied(
                  ref,
                  request,
                  dashboard,
                ),
            failure: (_) {},
          );
        },
      );
    });

    // While the session/account scope is changing, never paint the previous
    // keep-alive payload — including same-role switches where metrics differ.
    final AsyncValue<Result<HomeDashboard>> displayValue =
        _awaitingFreshDashboard
        ? const AsyncLoading<Result<HomeDashboard>>()
        : dashboard;

    // Tab read = profile:read (matrix). Per-atom Dashboard.md gates apply inside
    // [_HomeDashboardContent] via [filterHomeDashboardForAccess].
    return AppAccessGate(
      requirement: homeTabReadRequirement,
      child: AsyncStateScaffold<HomeDashboard>(
        key: ValueKey<String>('home-dashboard-$sessionScope'),
        value: displayValue,
        keepPreviousDataDuringRefresh: !_awaitingFreshDashboard,
        loadingTitle: l10n.homeLoadingTitle,
        loadingBody: l10n.homeLoadingBody,
        maxWidth: PageMaxWidth.dataHeavy,
        centerVertically: false,
        onRetry: () {
          homeClearDashboardOptimisticPatch(ref, request);
          ref.invalidate(homeCoreControllerProvider(request));
          ref.invalidate(homeControllerProvider(request));
        },
        dataBuilder: (BuildContext context, HomeDashboard snapshot) {
          final HomeDashboard display = homeDashboardWithOptimisticPatch(
            snapshot,
            optimisticState,
          );
          final bool isUpdating =
              display.isEnriching ||
              (!_awaitingFreshDashboard &&
                  (fullDashboard.isLoading || fullDashboard.isReloading) &&
                  dashboard.hasValue);
          return _HomeDashboardContent(
            dashboard: display,
            request: request,
            isUpdating: isUpdating,
          );
        },
      ),
    );
  }
}

class _HomeDashboardContent extends ConsumerWidget {
  const _HomeDashboardContent({
    required this.dashboard,
    required this.request,
    this.isUpdating = false,
  });

  final HomeDashboard dashboard;
  final HomeDashboardRequest request;
  final bool isUpdating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    final policy = ref.watch(appAccessPolicyProvider);
    final HomeDashboardProfile expectedProfile = homeProfileForAccessPolicy(
      policy,
    );
    // Keep-alive loads can briefly retain another role's dashboard while the
    // shell already reflects the current grants. Align chrome to the live
    // policy immediately; HomePage invalidates on session-scope changes for
    // fresh metrics.
    final HomeDashboard roleAligned =
        dashboard.profile.role == expectedProfile.role
        ? dashboard
        : mergeHomeDashboardForProfile(
            profile: expectedProfile,
            dashboard: dashboard,
            policy: policy,
          );
    final HomeDashboard authorized = filterHomeDashboardForAccess(
      roleAligned,
      policy,
    );
    final profile = authorized.profile;
    final actions = homeDeduplicateQuickActionsAgainstManage(
      homeVisibleActions(
        authorized.quickActionIds,
        policy,
        maxCount: profile.maxQuickActions,
      ),
      profile.emptyActionIds,
      policy,
    );
    final l10n = context.l10n;
    final DashboardPriorityPanelData priorityData = homeDashboardPriorityData(
      context: context,
      ref: ref,
      dashboard: authorized,
      actions: actions,
      policy: policy,
      l10n: l10n,
      request: request,
    );
    final bool hasPrioritySurface =
        priorityData.showQueue ||
        priorityData.showAlerts ||
        priorityData.showResults ||
        priorityData.showFollowUps ||
        priorityData.emptyMessage.isNotEmpty ||
        priorityData.emptyActions.isNotEmpty;
    final bool chartsAllowed = homeAllows(policy, homeChartsRequirement);
    final RoleDashboardLayout layout = homeRoleDashboardLayoutAfterFilter(
      profile: profile,
      dashboard: authorized,
      hasQuickActions: actions.isNotEmpty,
      hasPrioritySurface: hasPrioritySurface,
      chartsAllowed: chartsAllowed,
    );

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (isUpdating) ...<Widget>[
              LinearProgressIndicator(
                minHeight: 2,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                l10n.homeUpdatingBanner,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
              SizedBox(height: spacing.sm),
            ],
            if (authorized.isTenantContextRequired)
              HomeTenantContextPanel(
                tenantOptions: authorized.tenantOptions,
                request: request,
              )
            else
              RoleDashboardScaffold(
                layout: layout,
                spacing: spacing,
                leadingPanel: profile.alertsBeforeMetrics
                    ? DashboardAlertsPanel(
                        data: homeDashboardAlertsPanelData(
                          context: context,
                          ref: ref,
                          dashboard: authorized,
                          policy: policy,
                        ),
                      )
                    : null,
                summaryBadges: DashboardMetricStrip(
                  cards: homeDashboardMetrics(
                    context: context,
                    ref: ref,
                    dashboard: authorized,
                    policy: policy,
                    compact: profile.compactMetrics,
                  ),
                  maxCards: profile.effectiveMaxStatusCards,
                  compact: profile.compactMetrics,
                ),
                quickActions: AppQuickActions(
                  title: l10n.homeDashboardNextStepsTitle,
                  leadingIcon: Icons.bolt_rounded,
                  actions: <AppActionItem>[
                    for (final DashboardQuickActionData action
                        in homeDashboardQuickActions(
                          context: context,
                          ref: ref,
                          actions: actions,
                          request: request,
                        ))
                      AppActionItem(
                        label: action.label,
                        leadingIcon: action.icon,
                        semanticLabel: action.semanticsLabel,
                        onPressed: action.onPressed,
                      ),
                  ],
                ),
                priorityPanel: DashboardPriorityPanel(data: priorityData),
                // Mount charts only when layout allows — avoids empty chrome
                // if AppAccessGate would shrink while showCharts stayed true.
                charts: layout.showCharts
                    ? AppAccessGate(
                        requirement: homeChartsRequirement,
                        child: LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                if (authorized.profile.isPharmacistDepartmentDashboard) {
                                  return PharmacyMostSoldCharts(
                                    dashboard: authorized,
                                    l10n: l10n,
                                    request: request,
                                    twoColumns: constraints.maxWidth >= 980,
                                  );
                                }
                                if (authorized.profile.isReceptionistFrontDeskDashboard) {
                                  return ReceptionDeskCharts(
                                    dashboard: authorized,
                                    l10n: l10n,
                                    request: request,
                                    twoColumns: constraints.maxWidth >= 980,
                                  );
                                }
                                return DashboardChartsRow(
                                  data: homeDashboardChartsData(
                                    dashboard: authorized,
                                    l10n: l10n,
                                  ),
                                  twoColumns: constraints.maxWidth >= 980,
                                );
                              },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

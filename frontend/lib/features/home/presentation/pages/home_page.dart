import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_access.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_sync.dart';
import 'package:hosspi_hms/features/home/presentation/home_access.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_context_panel.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_mapper.dart';
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
  /// When set, hide prior-account metrics until the dashboard finishes loading.
  String? _pendingFreshSessionScope;

  @override
  Widget build(BuildContext context) {
    final HomeDashboardRequest request = widget.request;
    final String sessionScope = ref.watch(
      sessionStateProvider.select(_homeSessionScope),
    );
    if (_boundSessionScope != sessionScope) {
      if (_boundSessionScope != null) {
        _pendingFreshSessionScope = sessionScope;
        _scheduleClearOptimisticPatch(request);
      }
      _boundSessionScope = sessionScope;
    }

    final AsyncValue<Result<HomeDashboard>> dashboard = ref.watch(
      homeControllerProvider(request),
    );
    if (_pendingFreshSessionScope == null) {
      final HomeDashboard? loaded = switch (dashboard) {
        AsyncData<Result<HomeDashboard>>(:final value) => value.when(
          success: (HomeDashboard data) => data,
          failure: (_) => null,
        ),
        _ => null,
      };
      if (loaded != null &&
          !_dashboardMatchesSession(
            loaded,
            ref.read(sessionStateProvider),
          )) {
        _pendingFreshSessionScope = sessionScope;
        _scheduleClearOptimisticPatch(request);
        Future<void>.microtask(() {
          if (!mounted) {
            return;
          }
          ref.invalidate(homeControllerProvider(request));
        });
      }
    }
    final HomeDashboardOptimisticPatchState? optimisticState = ref.watch(
      homeDashboardOptimisticPatchProvider(request),
    );
    final l10n = context.l10n;

    ref.listen(homeControllerProvider(request), (
      AsyncValue<Result<HomeDashboard>>? previous,
      AsyncValue<Result<HomeDashboard>> next,
    ) {
      if (_pendingFreshSessionScope != null &&
          !next.isLoading &&
          (next.hasValue || next.hasError)) {
        setState(() {
          _pendingFreshSessionScope = null;
        });
      }
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

    // While switching accounts, ignore keep-alive AsyncData from the previous
    // user so the loading chrome shows until the new dashboard resolves.
    final AsyncValue<Result<HomeDashboard>> displayValue =
        _pendingFreshSessionScope == null
        ? dashboard
        : const AsyncLoading<Result<HomeDashboard>>();

    // Tab read = profile:read (matrix). Per-atom Dashboard.md gates apply inside
    // [_HomeDashboardContent] via [filterHomeDashboardForAccess].
    return AppAccessGate(
      requirement: homeTabReadRequirement,
      child: AsyncStateScaffold<HomeDashboard>(
        key: ValueKey<String>('home-dashboard-$sessionScope'),
        value: displayValue,
        keepPreviousDataDuringRefresh: _pendingFreshSessionScope == null,
        loadingTitle: l10n.homeLoadingTitle,
        loadingBody: l10n.homeLoadingBody,
        maxWidth: PageMaxWidth.dataHeavy,
        centerVertically: false,
        onRetry: () {
          homeClearDashboardOptimisticPatch(ref, request);
          ref.invalidate(homeControllerProvider(request));
        },
        dataBuilder: (BuildContext context, HomeDashboard snapshot) {
          final HomeDashboard display = homeDashboardWithOptimisticPatch(
            snapshot,
            optimisticState,
          );
          return _HomeDashboardContent(dashboard: display, request: request);
        },
      ),
    );
  }

  void _scheduleClearOptimisticPatch(HomeDashboardRequest request) {
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      homeClearDashboardOptimisticPatch(ref, request);
    });
  }
}

String _homeSessionScope(SessionState state) {
  final AuthUserProfile? user = state.session?.user;
  return '${user?.id ?? ''}|${user?.tenantId ?? ''}|${user?.facilityId ?? ''}';
}

bool _dashboardMatchesSession(HomeDashboard dashboard, SessionState state) {
  final AuthSession? session = state.session;
  final AuthUserProfile? user = session?.user;
  if (user == null) {
    return false;
  }

  final HomeDashboardProfile expectedProfile = homeProfileForAccessPolicy(
    AppAccessPolicy.fromSession(session),
  );
  if (dashboard.profile.role != expectedProfile.role) {
    return false;
  }

  final HomeDashboardContext context = dashboard.context;
  final String? sessionTenantId = _normalizedId(user.tenantId);
  final String? sessionFacilityId = _normalizedId(user.facilityId);
  final String? dashboardTenantId = _normalizedId(context.tenantId);
  final String? dashboardFacilityId = _normalizedId(context.facilityId);

  if (sessionTenantId != null &&
      dashboardTenantId != null &&
      sessionTenantId != dashboardTenantId) {
    return false;
  }
  if (sessionFacilityId != null &&
      dashboardFacilityId != null &&
      sessionFacilityId != dashboardFacilityId) {
    return false;
  }
  return true;
}

String? _normalizedId(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

class _HomeDashboardContent extends ConsumerWidget {
  const _HomeDashboardContent({required this.dashboard, required this.request});

  final HomeDashboard dashboard;
  final HomeDashboardRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    final policy = ref.watch(appAccessPolicyProvider);
    final HomeDashboard authorized = filterHomeDashboardForAccess(
      dashboard,
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
    final shortcuts = homeShortcutsExcludingQuickActions(
      homeVisibleShortcuts(authorized.shortcutIds, policy),
      actions,
      profile,
    );
    final l10n = context.l10n;
    final DashboardPriorityPanelData priorityData = homeDashboardPriorityData(
      context: context,
      ref: ref,
      dashboard: authorized,
      actions: actions,
      shortcuts: shortcuts,
      policy: policy,
      l10n: l10n,
      request: request,
    );
    final bool hasPrioritySurface =
        priorityData.showQueue ||
        priorityData.showAlerts ||
        priorityData.showResults ||
        priorityData.showFollowUps ||
        priorityData.showShortcuts ||
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

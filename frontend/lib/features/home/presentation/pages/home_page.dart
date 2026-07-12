import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_sync.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_context_panel.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_mapper.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class HomePage extends ConsumerWidget {
  const HomePage({this.request = HomeDashboardRequest.empty, super.key});

  final HomeDashboardRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeControllerProvider(request));
    final HomeDashboardOptimisticPatchState? optimisticState = ref.watch(
      homeDashboardOptimisticPatchProvider(request),
    );
    final l10n = context.l10n;

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

    return AsyncStateScaffold<HomeDashboard>(
      value: dashboard,
      keepPreviousDataDuringRefresh: true,
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
    );
  }
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
    final profile = dashboard.profile;
    final actions = homeVisibleActions(
      dashboard.quickActionIds,
      policy,
      maxCount: profile.maxQuickActions,
    );
    final shortcuts = homeShortcutsExcludingQuickActions(
      homeVisibleShortcuts(dashboard.shortcutIds, policy),
      actions,
      profile,
    );
    final l10n = context.l10n;
    final DashboardPriorityPanelData priorityData = homeDashboardPriorityData(
      context: context,
      ref: ref,
      dashboard: dashboard,
      actions: actions,
      shortcuts: shortcuts,
      policy: policy,
      l10n: l10n,
      request: request,
    );

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (dashboard.isTenantContextRequired)
              HomeTenantContextPanel(
                tenantOptions: dashboard.tenantOptions,
                request: request,
              )
            else
              RoleDashboardScaffold(
                layout: homeRoleDashboardLayout(
                  profile,
                  trend: dashboard.trend,
                  distribution: dashboard.distribution,
                ),
                spacing: spacing,
                leadingPanel: profile.alertsBeforeMetrics
                    ? DashboardAlertsPanel(
                        data: homeDashboardAlertsPanelData(
                          context: context,
                          ref: ref,
                          dashboard: dashboard,
                          policy: policy,
                        ),
                      )
                    : null,
                summaryBadges: DashboardMetricStrip(
                  cards: homeDashboardMetrics(
                    context: context,
                    ref: ref,
                    dashboard: dashboard,
                    policy: policy,
                    compact: profile.compactMetrics,
                  ),
                  maxCards: profile.effectiveMaxStatusCards,
                  compact: profile.compactMetrics,
                ),
                quickActions: DashboardQuickActions(
                  title: l10n.homeDashboardNextStepsTitle,
                  actions: homeDashboardQuickActions(
                    context: context,
                    ref: ref,
                    actions: actions,
                    request: request,
                  ),
                ),
                priorityPanel: DashboardPriorityPanel(data: priorityData),
                charts: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return DashboardChartsRow(
                      data: homeDashboardChartsData(
                        dashboard: dashboard,
                        l10n: l10n,
                      ),
                      twoColumns: constraints.maxWidth >= 980,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

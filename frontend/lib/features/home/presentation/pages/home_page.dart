import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_context_panel.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_scaffold.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_workspace_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:intl/intl.dart' hide TextDirection;

class HomePage extends ConsumerWidget {
  const HomePage({this.request = HomeDashboardRequest.empty, super.key});

  final HomeDashboardRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeControllerProvider(request));
    final l10n = context.l10n;

    return AsyncStateScaffold<HomeDashboard>(
      value: dashboard,
      loadingTitle: l10n.homeLoadingTitle,
      loadingBody: l10n.homeLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.invalidate(homeControllerProvider(request));
      },
      dataBuilder: (context, snapshot) {
        return _HomeDashboardContent(dashboard: snapshot, request: request);
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
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final HomeDashboardProfile profile = dashboard.profile;
    final List<_HomeActionDefinition> actions = _visibleActions(
      dashboard.quickActionIds,
      policy,
      maxCount: profile.maxQuickActions,
    );
    final List<_HomeShortcutDefinition> shortcuts =
        _shortcutsExcludingQuickActions(
          _visibleShortcuts(dashboard.shortcutIds, policy),
          actions,
          profile,
        );

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (dashboard.isTenantContextRequired) ...<Widget>[
              HomeTenantContextPanel(
                tenantOptions: dashboard.tenantOptions,
                request: request,
              ),
            ] else ...<Widget>[
              HomeDashboardScaffold(
                profile: profile,
                spacing: spacing,
                summaryBadges: _HomeStatusStrip(
                  cards: dashboard.statusCards,
                  profile: profile,
                  policy: policy,
                ),
                quickActions:
                    profile.suppressHomeQuickActions || actions.isEmpty
                    ? const SizedBox.shrink()
                    : _HomeQuickActions(actions: actions),
                criticalShortcuts: _HomeCriticalShortcuts(
                  dashboard: dashboard,
                  actions: actions,
                  shortcuts: shortcuts,
                ),
                charts: _HomeChartsSection(dashboard: dashboard),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeChartsSection extends StatelessWidget {
  const _HomeChartsSection({required this.dashboard});

  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final HomeDashboardProfile profile = dashboard.profile;
    final bool showCharts = profile.showChartsWhenData(
      trend: dashboard.trend,
      distribution: dashboard.distribution,
    );

    if (!showCharts) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return _HomeChartsRow(
          role: profile.role,
          trend: dashboard.trend,
          distribution: dashboard.distribution,
          twoColumns: constraints.maxWidth >= 980,
          gap: theme.spacing.md,
        );
      },
    );
  }
}

class _HomeCriticalShortcuts extends StatelessWidget {
  const _HomeCriticalShortcuts({
    required this.dashboard,
    required this.actions,
    required this.shortcuts,
  });

  final HomeDashboard dashboard;
  final List<_HomeActionDefinition> actions;
  final List<_HomeShortcutDefinition> shortcuts;

  @override
  Widget build(BuildContext context) {
    return _HomeMainGrid(
      dashboard: dashboard,
      actions: actions,
      shortcuts: shortcuts,
    );
  }
}

class _HomeStatusStrip extends StatelessWidget {
  const _HomeStatusStrip({
    required this.cards,
    required this.profile,
    required this.policy,
  });

  final List<HomeStatusCard> cards;
  final HomeDashboardProfile profile;
  final AppAccessPolicy policy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<HomeStatusCard> visibleCards = cards
        .where((HomeStatusCard card) => card.value != 0)
        .take(profile.effectiveMaxStatusCards)
        .toList(growable: false);

    if (visibleCards.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = theme.spacing.sm;
        final int columns = constraints.maxWidth >= 1180
            ? math.min(visibleCards.length, profile.effectiveMaxStatusCards)
            : constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 340
            ? 2
            : 1;
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final HomeStatusCard card in visibleCards)
              SizedBox(
                width: math.max(0, width),
                child: _HomeMetricCard(
                  card: card,
                  profile: profile,
                  policy: policy,
                  compact:
                      profile.compactMetrics ||
                      constraints.maxWidth < AppBreakpoints.md,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeMetricCard extends ConsumerWidget {
  const _HomeMetricCard({
    required this.card,
    required this.profile,
    required this.policy,
    this.compact = false,
  });

  final HomeStatusCard card;
  final HomeDashboardProfile profile;
  final AppAccessPolicy policy;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final AppWorkspaceStatusTone tone = _metricTone(card);
    final Color accent = _toneColor(theme, tone);
    final String value = _formatMetricValue(card);
    final HomeMetricNavigation? navigation = homeMetricNavigation(
      profile: profile,
      card: card,
      policy: policy,
    );
    final HomeMetricAction? action = homeMetricAction(
      profile: profile,
      card: card,
      policy: policy,
    );
    final bool isActionable = navigation != null || action != null;
    final String label = homeMetricCardLabel(l10n, card, compact: compact);
    final String semanticsLabel = isActionable
        ? l10n.homeMetricCardSemantics(label, value)
        : '$label: $value';

    final Widget cardBody = Padding(
      padding: EdgeInsets.all(compact ? theme.spacing.sm : theme.spacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 32 : 38,
            height: compact ? 32 : 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(theme.radius.md),
            ),
            child: Icon(_metricIcon(card.id), color: accent, size: 20),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.headlineSmall)
                          ?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                ),
              ],
            ),
          ),
          if (isActionable) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: isActionable,
      label: semanticsLabel,
      child: isActionable
          ? Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(theme.radius.lg),
              child: InkWell(
                onTap: () {
                  if (action != null) {
                    unawaited(action.invoke(context, ref));
                    return;
                  }
                  if (navigation != null) {
                    _goToRoute(
                      context,
                      navigation.route,
                      queryParameters: navigation.queryParameters,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(theme.radius.lg),
                child: DecoratedBox(
                  decoration: _metricCardDecoration(theme, colorScheme),
                  child: cardBody,
                ),
              ),
            )
          : DecoratedBox(
              decoration: _metricCardDecoration(theme, colorScheme),
              child: cardBody,
            ),
    );
  }
}

BoxDecoration _metricCardDecoration(ThemeData theme, ColorScheme colorScheme) {
  return BoxDecoration(
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(theme.radius.lg),
    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: 0.8),
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class _HomeQuickActions extends ConsumerWidget {
  const _HomeQuickActions({required this.actions});

  final List<_HomeActionDefinition> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      children: <Widget>[
        for (final _HomeActionDefinition action in actions)
          Semantics(
            button: true,
            label: action.label,
            child: AppButton.secondary(
              label: action.label,
              leadingIcon: action.icon,
              onPressed: () => _invokeHomeAction(context, ref, action),
            ),
          ),
      ],
    );
  }
}

class _HomeMainGrid extends StatelessWidget {
  const _HomeMainGrid({
    required this.dashboard,
    required this.actions,
    required this.shortcuts,
  });

  final HomeDashboard dashboard;
  final List<_HomeActionDefinition> actions;
  final List<_HomeShortcutDefinition> shortcuts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final HomeDashboardProfile profile = dashboard.profile;
    final double gap = theme.spacing.md;
    final bool showQueue = profile.showQueuePanelFor(dashboard.queuePreview);
    final bool showAlerts = profile.showAlertsPanel(dashboard.alerts);
    final bool showShortcuts = profile.showShortcutsSection(
      quickActionCount: actions.length,
    );
    final int queueLimit = profile.maxQueueItems;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 980;
        final Widget primary = showQueue
            ? _PrimaryQueuePanel(
                title: profile.showQueuePanelTitle
                    ? _queueTitle(profile.role)
                    : null,
                items: dashboard.queuePreview,
                emptyMessage: profile.emptyMessage,
                emptyActions: _visibleEmptyActions(
                  profile.emptyActionIds,
                  actions,
                ),
                maxItems: queueLimit,
              )
            : const SizedBox.shrink();
        final Widget alerts = showAlerts
            ? _AlertsPanel(role: profile.role, alerts: dashboard.alerts)
            : const SizedBox.shrink();
        final bool hasQueueContent =
            showQueue && dashboard.queuePreview.isNotEmpty;
        final bool hasWorkContent = hasQueueContent || showAlerts;

        if (!hasWorkContent && !showShortcuts) {
          return const SizedBox.shrink();
        }

        final Widget work = hasWorkContent
            ? (wide && hasQueueContent && showAlerts
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: primary),
                        SizedBox(width: gap),
                        Expanded(flex: 2, child: alerts),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (showQueue) primary,
                        if (showQueue && showAlerts) SizedBox(height: gap),
                        if (showAlerts) alerts,
                      ],
                    ))
            : const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (hasWorkContent) work,
            if (showShortcuts) ...<Widget>[
              if (hasWorkContent) SizedBox(height: gap),
              _ShortcutsSection(
                shortcuts: shortcuts,
                maxTiles: profile.maxShortcutTiles,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HomeChartsRow extends StatelessWidget {
  const _HomeChartsRow({
    required this.role,
    required this.trend,
    required this.distribution,
    required this.twoColumns,
    required this.gap,
  });

  final AppRole role;
  final HomeDashboardTrend trend;
  final HomeDashboardDistribution distribution;
  final bool twoColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final Widget trendPanel = _HomeTrendPanel(role: role, trend: trend);
    final Widget distributionPanel = _HomeDistributionPanel(
      role: role,
      distribution: distribution,
    );

    if (twoColumns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 3, child: trendPanel),
          SizedBox(width: gap),
          Expanded(flex: 2, child: distributionPanel),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        trendPanel,
        SizedBox(height: gap),
        distributionPanel,
      ],
    );
  }
}

class _PrimaryQueuePanel extends StatelessWidget {
  const _PrimaryQueuePanel({
    this.title,
    required this.items,
    required this.emptyMessage,
    required this.emptyActions,
    this.maxItems = 3,
  });

  final String? title;
  final List<HomeQueueItem> items;
  final String emptyMessage;
  final List<_HomeActionDefinition> emptyActions;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: title,
      leadingIcon: Icons.format_list_bulleted,
      trailing: items.isEmpty
          ? null
          : _ViewAllButton(target: _firstQueueTarget(items)),
      children: <Widget>[
        if (items.isEmpty)
          _EmptyStateInline(message: emptyMessage, actions: emptyActions)
        else
          for (final HomeQueueItem item in items.take(maxItems))
            _QueueRow(item: item),
      ],
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.role, required this.alerts});

  final AppRole role;
  final List<HomeAlertItem> alerts;

  @override
  Widget build(BuildContext context) {
    final List<HomeAlertItem> visibleAlerts = alerts
        .where((HomeAlertItem alert) => alert.count > 0)
        .take(3)
        .toList(growable: false);
    if (visibleAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppSectionPanel(
      title: _alertsTitle(role),
      leadingIcon: Icons.warning_amber_outlined,
      children: <Widget>[
        for (final HomeAlertItem alert in visibleAlerts)
          _AlertRow(alert: alert),
      ],
    );
  }
}

class _ShortcutsSection extends StatelessWidget {
  const _ShortcutsSection({required this.shortcuts, required this.maxTiles});

  final List<_HomeShortcutDefinition> shortcuts;
  final int maxTiles;

  @override
  Widget build(BuildContext context) {
    if (shortcuts.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppResponsiveWrap(
      children: <Widget>[
        for (final _HomeShortcutDefinition shortcut in shortcuts.take(maxTiles))
          _ShortcutTile(shortcut: shortcut),
      ],
    );
  }
}

class _HomeTrendPanel extends StatelessWidget {
  const _HomeTrendPanel({required this.role, required this.trend});

  final AppRole role;
  final HomeDashboardTrend trend;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      title: _trendTitle(role, trend.title),
      leadingIcon: Icons.show_chart_outlined,
      children: <Widget>[
        if (trend.points.isEmpty)
          _QuietState(message: l10n.homeTrendEmptyMessage)
        else
          _HomeTrendChart(points: trend.points),
      ],
    );
  }
}

class _HomeTrendChart extends StatelessWidget {
  const _HomeTrendChart({required this.points});

  final List<HomeTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<HomeTrendPoint> visiblePoints = points.take(14).toList();

    return Semantics(
      label: 'Trend chart with ${visiblePoints.length} points',
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendChartPainter(
                points: visiblePoints,
                barColor: colorScheme.primary.withValues(alpha: 0.18),
                lineColor: colorScheme.primary,
                gridColor: colorScheme.outlineVariant,
                labelColor: colorScheme.onSurfaceVariant,
                textStyle: theme.textTheme.labelSmall,
              ),
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Row(
            children: <Widget>[
              if (visiblePoints.isNotEmpty)
                Text(
                  _trendPointLabel(visiblePoints.first),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              if (visiblePoints.length > 1)
                Text(
                  _trendPointLabel(visiblePoints.last),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeDistributionPanel extends StatelessWidget {
  const _HomeDistributionPanel({
    required this.role,
    required this.distribution,
  });

  final AppRole role;
  final HomeDashboardDistribution distribution;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      title: _distributionTitle(role, distribution.title),
      leadingIcon: Icons.donut_large_outlined,
      children: <Widget>[
        if (!distribution.hasData)
          _QuietState(message: l10n.homeDistributionEmptyMessage)
        else
          _HomeDistributionChart(distribution: distribution),
      ],
    );
  }
}

class _HomeDistributionChart extends StatelessWidget {
  const _HomeDistributionChart({required this.distribution});

  final HomeDashboardDistribution distribution;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<HomeDistributionSegment> segments = distribution.segments
        .where((HomeDistributionSegment segment) => segment.value > 0)
        .toList(growable: false);
    final num total = distribution.total > 0
        ? distribution.total
        : segments.fold<num>(0, (num sum, HomeDistributionSegment segment) {
            return sum + segment.value;
          });

    return Semantics(
      label:
          'Distribution chart with total ${NumberFormat.compact().format(total)}',
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 170,
            width: double.infinity,
            child: Center(
              child: SizedBox(
                width: 154,
                height: 154,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CustomPaint(
                      size: const Size.square(154),
                      painter: _DonutChartPainter(
                        segments: segments,
                        total: total,
                        fallbackColor: colorScheme.primary,
                        trackColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          NumberFormat.compact().format(total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'total',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (int index = 0; index < segments.length; index += 1)
                _DistributionLegendItem(
                  segment: segments[index],
                  total: total,
                  color: _segmentColor(theme, segments[index], index),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistributionLegendItem extends StatelessWidget {
  const _DistributionLegendItem({
    required this.segment,
    required this.total,
    required this.color,
  });

  final HomeDistributionSegment segment;
  final num total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double percent = total <= 0 ? 0 : (segment.value / total) * 100;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: theme.spacing.xs),
          Text(
            '${_formatToken(segment.label)} ${percent.round()}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({
    required this.points,
    required this.barColor,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.textStyle,
  });

  final List<HomeTrendPoint> points;
  final Color barColor;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final TextStyle? textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final double chartHeight = math.max(0, size.height - 26);
    final double maxValue = math.max(
      1,
      points
          .map((HomeTrendPoint point) => point.value.toDouble())
          .reduce(math.max),
    );
    final Paint gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final Paint barPaint = Paint()..color = barColor;
    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint dotPaint = Paint()..color = lineColor;
    final double slotWidth = size.width / points.length;
    final double barWidth = math.max(6, math.min(22, slotWidth * 0.42));
    final Path path = Path();

    for (int i = 0; i <= 3; i += 1) {
      final double y = chartHeight * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int index = 0; index < points.length; index += 1) {
      final HomeTrendPoint point = points[index];
      final double centerX = slotWidth * index + (slotWidth / 2);
      final double normalized = point.value.toDouble() / maxValue;
      final double y = chartHeight - (chartHeight * normalized);
      final Rect barRect = Rect.fromLTWH(
        centerX - (barWidth / 2),
        y,
        barWidth,
        chartHeight - y,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(8)),
        barPaint,
      );

      if (index == 0) {
        path.moveTo(centerX, y);
      } else {
        path.lineTo(centerX, y);
      }
      canvas.drawCircle(Offset(centerX, y), 3.5, dotPaint);

      if (points.length <= 7) {
        final TextPainter painter = TextPainter(
          text: TextSpan(
            text: _trendPointLabel(point, compact: true),
            style:
                textStyle?.copyWith(color: labelColor) ??
                TextStyle(color: labelColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: slotWidth);
        painter.paint(
          canvas,
          Offset(centerX - (painter.width / 2), chartHeight + 8),
        );
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.barColor != barColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({
    required this.segments,
    required this.total,
    required this.fallbackColor,
    required this.trackColor,
  });

  final List<HomeDistributionSegment> segments;
  final num total;
  final Color fallbackColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius - 10);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    paint.color = trackColor;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, paint);

    if (total <= 0 || segments.isEmpty) {
      return;
    }

    double start = -math.pi / 2;
    for (int index = 0; index < segments.length; index += 1) {
      final HomeDistributionSegment segment = segments[index];
      final double sweep = (segment.value / total) * math.pi * 2;
      paint.color =
          _segmentColorFromHex(segment.color) ??
          _fallbackSegmentColor(fallbackColor, index);
      canvas.drawArc(rect, start, math.max(0.02, sweep), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.total != total ||
        oldDelegate.fallbackColor != fallbackColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item});

  final HomeQueueItem item;

  @override
  Widget build(BuildContext context) {
    final AppWorkspaceStatus status = AppWorkspaceStatus(
      label: _statusLabel(item.status),
      tone: _severityTone(item.severity ?? item.status),
    );

    return _LinkedDashboardRow(
      icon: _moduleIcon(item.moduleSlug),
      title: item.label,
      subtitle: _timeLabel(item.occurredAt),
      status: status,
      target: item.target,
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});

  final HomeAlertItem alert;

  @override
  Widget build(BuildContext context) {
    return _LinkedDashboardRow(
      icon: Icons.warning_amber_outlined,
      title: alert.label,
      subtitle: alert.count > 0 ? '${alert.count}' : '',
      status: AppWorkspaceStatus(
        label: _statusLabel(alert.severity),
        tone: _severityTone(alert.severity),
      ),
      target: alert.target,
    );
  }
}

class _LinkedDashboardRow extends StatelessWidget {
  const _LinkedDashboardRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.target,
    this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppWorkspaceStatus? status;
  final HomeRouteTarget? target;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppRouteData? route = _routeForTarget(target);
    final Widget row = Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: theme.appTokens.listIconSize,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                if (subtitle.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (status != null) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            AppWorkspaceStatusBadge(status: status!),
          ],
        ],
      ),
    );

    if (route == null) {
      return row;
    }

    final Map<String, String> queryParameters = homeHrQueryForTarget(target);
    return InkWell(
      onTap: () => _goToRoute(context, route, queryParameters: queryParameters),
      child: row,
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.shortcut});

  final _HomeShortcutDefinition shortcut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => _goToRoute(context, shortcut.route),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          color: colorScheme.surfaceContainerLowest,
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Row(
            children: <Widget>[
              Icon(
                shortcut.icon,
                size: theme.appTokens.listIconSize,
                color: colorScheme.primary,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  shortcut.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              Icon(
                Icons.chevron_right,
                size: theme.appTokens.listIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.target});

  final HomeRouteTarget? target;

  @override
  Widget build(BuildContext context) {
    final AppRouteData? route = _routeForTarget(target);
    if (route == null) {
      return const SizedBox.shrink();
    }

    return AppButton.tertiary(
      label: context.l10n.homeViewAllAction,
      leadingIcon: Icons.open_in_new,
      onPressed: () => _goToRoute(
        context,
        route,
        queryParameters: homeHrQueryForTarget(target),
      ),
    );
  }
}

class _EmptyStateInline extends ConsumerWidget {
  const _EmptyStateInline({required this.message, required this.actions});

  final String message;
  final List<_HomeActionDefinition> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      label: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.inbox_outlined,
            size: 28,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          if (actions.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                for (final _HomeActionDefinition action in actions.take(3))
                  AppButton.secondary(
                    label: action.label,
                    leadingIcon: action.icon,
                    onPressed: () => _invokeHomeAction(context, ref, action),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuietState extends StatelessWidget {
  const _QuietState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      label: message,
      child: Icon(
        Icons.check_circle_outline,
        size: 24,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

final class _HomeActionDefinition {
  const _HomeActionDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    this.routeQuery = const <String, String>{},
    this.allowedRoles = const <AppRole>[],
    this.requiredPermissions = const <AppPermission>[],
    this.requiredAnyPermissions = const <AppPermission>[],
    this.requiredModules = const <String>[],
  });

  final String id;
  final String label;
  final IconData icon;
  final AppRouteData route;
  final Map<String, String> routeQuery;
  final List<AppRole> allowedRoles;
  final List<AppPermission> requiredPermissions;
  final List<AppPermission> requiredAnyPermissions;
  final List<String> requiredModules;

  bool isAllowed(AppAccessPolicy policy) {
    return route.accessRequirement.isAllowed(policy) &&
        _hasAllowedActionRole(policy) &&
        policy.grantsAll(requiredPermissions) &&
        (requiredAnyPermissions.isEmpty ||
            policy.grantsAny(requiredAnyPermissions)) &&
        policy.hasAllActiveModules(requiredModules);
  }

  bool _hasAllowedActionRole(AppAccessPolicy policy) {
    if (allowedRoles.isEmpty) {
      return true;
    }
    return allowedRoles.any(policy.hasRole);
  }
}

final class _HomeShortcutDefinition {
  const _HomeShortcutDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });

  final String id;
  final String label;
  final IconData icon;
  final AppRouteData route;

  bool isAllowed(AppAccessPolicy policy) {
    return route.accessRequirement.isAllowed(policy);
  }
}

const Map<String, _HomeActionDefinition>
_actionLibrary = <String, _HomeActionDefinition>{
  'register_patient': _HomeActionDefinition(
    id: 'register_patient',
    label: 'Register patient',
    icon: Icons.person_add_alt_1_outlined,
    route: AppRoutes.patients,
    allowedRoles: <AppRole>[AppRole.facilityAdmin, AppRole.receptionist],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['patients'],
  ),
  'book_appointment': _HomeActionDefinition(
    id: 'book_appointment',
    label: 'Book appointment',
    icon: Icons.event_available_outlined,
    route: AppRoutes.opd,
    allowedRoles: <AppRole>[AppRole.facilityAdmin, AppRole.receptionist],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['scheduling'],
  ),
  'check_in_patient': _HomeActionDefinition(
    id: 'check_in_patient',
    label: 'Check in patient',
    icon: Icons.fact_check_outlined,
    route: AppRoutes.opd,
    allowedRoles: <AppRole>[AppRole.facilityAdmin, AppRole.receptionist],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['scheduling'],
  ),
  'route_patient': _HomeActionDefinition(
    id: 'route_patient',
    label: 'Route patient',
    icon: Icons.alt_route_outlined,
    route: AppRoutes.opd,
    allowedRoles: <AppRole>[AppRole.receptionist, AppRole.nurse],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['scheduling'],
  ),
  'start_consultation': _HomeActionDefinition(
    id: 'start_consultation',
    label: 'Start consultation',
    icon: Icons.medical_services_outlined,
    route: AppRoutes.clinical,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['clinical'],
  ),
  'continue_consultation': _HomeActionDefinition(
    id: 'continue_consultation',
    label: 'Continue consultation',
    icon: Icons.medical_information_outlined,
    route: AppRoutes.clinical,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['clinical'],
  ),
  'write_clinical_note': _HomeActionDefinition(
    id: 'write_clinical_note',
    label: 'Write clinical note',
    icon: Icons.note_add_outlined,
    route: AppRoutes.clinical,
    allowedRoles: <AppRole>[
      AppRole.doctor,
      AppRole.nurse,
      AppRole.icuManager,
      AppRole.theatreManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['clinical'],
  ),
  'record_vitals': _HomeActionDefinition(
    id: 'record_vitals',
    label: 'Record vitals',
    icon: Icons.monitor_heart_outlined,
    route: AppRoutes.nursing,
    allowedRoles: <AppRole>[AppRole.nurse, AppRole.doctor, AppRole.icuManager],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['nursing'],
  ),
  'mark_med_administered': _HomeActionDefinition(
    id: 'mark_med_administered',
    label: 'Mark medication administered',
    icon: Icons.medication_outlined,
    route: AppRoutes.nursing,
    allowedRoles: <AppRole>[AppRole.nurse],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['nursing'],
  ),
  'create_handover': _HomeActionDefinition(
    id: 'create_handover',
    label: 'Create handover',
    icon: Icons.swap_horiz_outlined,
    route: AppRoutes.nursing,
    allowedRoles: <AppRole>[
      AppRole.nurse,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.unitManage,
    ],
    requiredModules: <String>['nursing'],
  ),
  'order_lab': _HomeActionDefinition(
    id: 'order_lab',
    label: 'Order lab test',
    icon: Icons.biotech_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['lab'],
  ),
  'order_radiology': _HomeActionDefinition(
    id: 'order_radiology',
    label: 'Order imaging',
    icon: Icons.camera_outdoor_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['radiology'],
  ),
  'receive_sample': _HomeActionDefinition(
    id: 'receive_sample',
    label: 'Receive sample',
    icon: Icons.science_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.labTech],
    requiredPermissions: <AppPermission>[AppPermissions.labWrite],
    requiredModules: <String>['lab'],
  ),
  'enter_lab_result': _HomeActionDefinition(
    id: 'enter_lab_result',
    label: 'Enter lab result',
    icon: Icons.edit_note_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.labTech],
    requiredPermissions: <AppPermission>[AppPermissions.labWrite],
    requiredModules: <String>['lab'],
  ),
  'flag_critical_lab': _HomeActionDefinition(
    id: 'flag_critical_lab',
    label: 'Flag critical result',
    icon: Icons.priority_high_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.labTech],
    requiredPermissions: <AppPermission>[AppPermissions.labWrite],
    requiredModules: <String>['lab'],
  ),
  'start_imaging_study': _HomeActionDefinition(
    id: 'start_imaging_study',
    label: 'Start imaging study',
    icon: Icons.camera_outdoor_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.radiologyTech],
    requiredPermissions: <AppPermission>[AppPermissions.radiologyWrite],
    requiredModules: <String>['radiology'],
  ),
  'update_imaging_status': _HomeActionDefinition(
    id: 'update_imaging_status',
    label: 'Update imaging status',
    icon: Icons.update_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.radiologyTech],
    requiredPermissions: <AppPermission>[AppPermissions.radiologyWrite],
    requiredModules: <String>['radiology'],
  ),
  'add_radiology_report': _HomeActionDefinition(
    id: 'add_radiology_report',
    label: 'Add imaging report',
    icon: Icons.post_add_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.radiologyTech],
    requiredPermissions: <AppPermission>[AppPermissions.radiologyWrite],
    requiredModules: <String>['radiology'],
  ),
  'create_invoice': _HomeActionDefinition(
    id: 'create_invoice',
    label: 'Create invoice',
    icon: Icons.receipt_long_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'receive_payment': _HomeActionDefinition(
    id: 'receive_payment',
    label: 'Receive payment',
    icon: Icons.payments_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'process_refund': _HomeActionDefinition(
    id: 'process_refund',
    label: 'Process refund',
    icon: Icons.undo_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'close_shift': _HomeActionDefinition(
    id: 'close_shift',
    label: 'Close shift',
    icon: Icons.lock_clock_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'dispense_medication': _HomeActionDefinition(
    id: 'dispense_medication',
    label: 'Dispense medication',
    icon: Icons.medication_liquid_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'record_pharmacy_sale': _HomeActionDefinition(
    id: 'record_pharmacy_sale',
    label: 'Record pharmacy sale',
    icon: Icons.point_of_sale_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'receive_pharmacy_stock': _HomeActionDefinition(
    id: 'receive_pharmacy_stock',
    label: 'Receive pharmacy stock',
    icon: Icons.inventory_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'adjust_pharmacy_stock': _HomeActionDefinition(
    id: 'adjust_pharmacy_stock',
    label: 'Adjust pharmacy stock',
    icon: Icons.tune_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'add_staff_profile': _HomeActionDefinition(
    id: 'add_staff_profile',
    label: 'Add staff profile',
    icon: Icons.badge_outlined,
    route: AppRoutes.hr,
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.hrWrite,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
    ],
    requiredModules: <String>['hr'],
  ),
  'review_leave': _HomeActionDefinition(
    id: 'review_leave',
    label: 'Review leave',
    icon: Icons.approval_outlined,
    route: AppRoutes.hr,
    routeQuery: <String, String>{'queue': 'LEAVE_REQUESTS'},
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.biomedManager,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.hrWrite,
      AppPermissions.rosterApprove,
    ],
    requiredModules: <String>['hr'],
  ),
  'create_shift': _HomeActionDefinition(
    id: 'create_shift',
    label: 'Create shift',
    icon: Icons.add_alarm_outlined,
    route: AppRoutes.hr,
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.biomedManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.rosterWrite],
    requiredModules: <String>['hr'],
  ),
  'publish_roster': _HomeActionDefinition(
    id: 'publish_roster',
    label: 'Publish roster',
    icon: Icons.calendar_month_outlined,
    route: AppRoutes.hr,
    routeQuery: <String, String>{'queue': 'ROSTER_DRAFTS'},
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.rosterPublish],
    requiredModules: <String>['hr'],
  ),
  'approve_roster': _HomeActionDefinition(
    id: 'approve_roster',
    label: 'Approve roster',
    icon: Icons.verified_outlined,
    route: AppRoutes.hr,
    routeQuery: <String, String>{'queue': 'ROSTER_DRAFTS'},
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.rosterApprove],
    requiredModules: <String>['hr'],
  ),
  'create_maintenance_request': _HomeActionDefinition(
    id: 'create_maintenance_request',
    label: 'Create maintenance request',
    icon: Icons.handyman_outlined,
    route: AppRoutes.operations,
    allowedRoles: <AppRole>[AppRole.operations, AppRole.facilityAdmin],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['operations'],
  ),
  'assign_maintenance': _HomeActionDefinition(
    id: 'assign_maintenance',
    label: 'Assign maintenance',
    icon: Icons.assignment_ind_outlined,
    route: AppRoutes.operations,
    allowedRoles: <AppRole>[AppRole.operations],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['operations'],
  ),
  'update_bed_readiness': _HomeActionDefinition(
    id: 'update_bed_readiness',
    label: 'Update bed readiness',
    icon: Icons.bed_outlined,
    route: AppRoutes.roomsBeds,
    allowedRoles: <AppRole>[AppRole.operations, AppRole.housekeepingManager],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['rooms_beds'],
  ),
  'report_equipment_issue': _HomeActionDefinition(
    id: 'report_equipment_issue',
    label: 'Report equipment issue',
    icon: Icons.precision_manufacturing_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[
      AppRole.biomed,
      AppRole.biomedManager,
      AppRole.facilityAdmin,
      AppRole.operations,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.biomedWrite,
      AppPermissions.facilityAdmin,
      AppPermissions.operationsWrite,
    ],
    requiredModules: <String>['biomedical'],
  ),
  'acknowledge_work_order': _HomeActionDefinition(
    id: 'acknowledge_work_order',
    label: 'Acknowledge work order',
    icon: Icons.task_alt_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomed],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'update_work_order': _HomeActionDefinition(
    id: 'update_work_order',
    label: 'Update work order',
    icon: Icons.build_circle_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomed, AppRole.biomedManager],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'log_calibration': _HomeActionDefinition(
    id: 'log_calibration',
    label: 'Log calibration',
    icon: Icons.fact_check_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomed, AppRole.biomedManager],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'schedule_maintenance': _HomeActionDefinition(
    id: 'schedule_maintenance',
    label: 'Schedule maintenance',
    icon: Icons.event_repeat_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomed, AppRole.biomedManager],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'assign_technician': _HomeActionDefinition(
    id: 'assign_technician',
    label: 'Assign technician',
    icon: Icons.engineering_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomedManager],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'create_cleaning_task': _HomeActionDefinition(
    id: 'create_cleaning_task',
    label: 'Create cleaning task',
    icon: Icons.cleaning_services_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.housekeepingManager, AppRole.operations],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['housekeeping'],
  ),
  'assign_cleaning_task': _HomeActionDefinition(
    id: 'assign_cleaning_task',
    label: 'Assign cleaning task',
    icon: Icons.assignment_turned_in_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.housekeepingManager],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['housekeeping'],
  ),
  'start_cleaning_task': _HomeActionDefinition(
    id: 'start_cleaning_task',
    label: 'Start cleaning task',
    icon: Icons.play_arrow_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.houseKeeper],
    requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
    requiredModules: <String>['housekeeping'],
  ),
  'complete_cleaning_task': _HomeActionDefinition(
    id: 'complete_cleaning_task',
    label: 'Complete cleaning task',
    icon: Icons.check_circle_outline,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.houseKeeper],
    requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
    requiredModules: <String>['housekeeping'],
  ),
  'mark_cleaning_blocked': _HomeActionDefinition(
    id: 'mark_cleaning_blocked',
    label: 'Mark cleaning blocked',
    icon: Icons.block_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.houseKeeper, AppRole.housekeepingManager],
    requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
    requiredModules: <String>['housekeeping'],
  ),
  'dispatch_ambulance': _HomeActionDefinition(
    id: 'dispatch_ambulance',
    label: 'Dispatch ambulance',
    icon: Icons.emergency_share_outlined,
    route: AppRoutes.emergency,
    allowedRoles: <AppRole>[AppRole.ambulanceOperator],
    requiredPermissions: <AppPermission>[AppPermissions.emergencyWrite],
    requiredModules: <String>['emergency'],
  ),
  'update_trip_status': _HomeActionDefinition(
    id: 'update_trip_status',
    label: 'Update trip status',
    icon: Icons.route_outlined,
    route: AppRoutes.emergency,
    allowedRoles: <AppRole>[AppRole.ambulanceOperator],
    requiredPermissions: <AppPermission>[AppPermissions.emergencyWrite],
    requiredModules: <String>['emergency'],
  ),
  'record_emergency_handover': _HomeActionDefinition(
    id: 'record_emergency_handover',
    label: 'Record handover',
    icon: Icons.swap_calls_outlined,
    route: AppRoutes.emergency,
    allowedRoles: <AppRole>[AppRole.ambulanceOperator],
    requiredPermissions: <AppPermission>[AppPermissions.emergencyWrite],
    requiredModules: <String>['emergency'],
  ),
  'open_mortuary_case': _HomeActionDefinition(
    id: 'open_mortuary_case',
    label: 'Open mortuary case',
    icon: Icons.inventory_2_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
    requiredModules: <String>['mortuary'],
  ),
  'assign_storage_slot': _HomeActionDefinition(
    id: 'assign_storage_slot',
    label: 'Assign storage slot',
    icon: Icons.grid_view_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryManageStorage],
    requiredModules: <String>['mortuary'],
  ),
  'record_custody_event': _HomeActionDefinition(
    id: 'record_custody_event',
    label: 'Record custody event',
    icon: Icons.history_edu_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
    requiredModules: <String>['mortuary'],
  ),
  'schedule_viewing': _HomeActionDefinition(
    id: 'schedule_viewing',
    label: 'Schedule viewing',
    icon: Icons.event_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
    requiredModules: <String>['mortuary'],
  ),
  'add_mortuary_billable_event': _HomeActionDefinition(
    id: 'add_mortuary_billable_event',
    label: 'Add billable event',
    icon: Icons.add_card_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryBillingEvent],
    requiredModules: <String>['mortuary'],
  ),
  'review_release_authorization': _HomeActionDefinition(
    id: 'review_release_authorization',
    label: 'Review release authorization',
    icon: Icons.verified_user_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryManager],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.mortuaryRelease,
      AppPermissions.mortuaryApprove,
    ],
    requiredModules: <String>['mortuary'],
  ),
  'approve_release': _HomeActionDefinition(
    id: 'approve_release',
    label: 'Approve release',
    icon: Icons.verified_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryApprove],
    requiredModules: <String>['mortuary'],
  ),
  'export_mortuary_evidence': _HomeActionDefinition(
    id: 'export_mortuary_evidence',
    label: 'Export evidence',
    icon: Icons.file_download_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryManager],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.mortuaryExport,
      AppPermissions.evidenceExport,
    ],
    requiredModules: <String>['mortuary'],
  ),
  'run_report': _HomeActionDefinition(
    id: 'run_report',
    label: 'Run report',
    icon: Icons.analytics_outlined,
    route: AppRoutes.reports,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.billing,
      AppRole.operations,
      AppRole.hr,
      AppRole.labTech,
      AppRole.radiologyTech,
      AppRole.pharmacist,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.biomedManager,
      AppRole.mortuaryManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.reportsRead],
    requiredModules: <String>['reports'],
  ),
  'manage_subscription': _HomeActionDefinition(
    id: 'manage_subscription',
    label: 'Manage subscription',
    icon: Icons.workspace_premium_outlined,
    route: AppRoutes.subscriptions,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.subscriptionsWrite,
      AppPermissions.subscriptionsRead,
    ],
    requiredModules: <String>['subscriptions'],
  ),
  'select_context': _HomeActionDefinition(
    id: 'select_context',
    label: 'Select tenant/facility',
    icon: Icons.account_tree_outlined,
    route: AppRoutes.tenantFacilitySetup,
    allowedRoles: <AppRole>[AppRole.superAdmin, AppRole.tenantAdmin],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
    ],
  ),
  'create_tenant': _HomeActionDefinition(
    id: 'create_tenant',
    label: 'Create tenant',
    icon: Icons.add_business_outlined,
    route: AppRoutes.tenantFacilitySetup,
    allowedRoles: <AppRole>[AppRole.superAdmin],
    requiredPermissions: <AppPermission>[AppPermissions.systemAdmin],
  ),
  'create_facility': _HomeActionDefinition(
    id: 'create_facility',
    label: 'Create facility',
    icon: Icons.apartment_outlined,
    route: AppRoutes.tenantFacilitySetup,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
    ],
  ),
  'manage_users_roles': _HomeActionDefinition(
    id: 'manage_users_roles',
    label: 'Manage users and roles',
    icon: Icons.manage_accounts_outlined,
    route: AppRoutes.accessAdmin,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.operations,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.systemAdmin,
    ],
  ),
  'manage_staff_access': _HomeActionDefinition(
    id: 'manage_staff_access',
    label: 'Manage users and roles',
    icon: Icons.manage_accounts_outlined,
    route: AppRoutes.hr,
    allowedRoles: <AppRole>[AppRole.hr],
    requiredAnyPermissions: <AppPermission>[AppPermissions.hrWrite],
    requiredModules: <String>['hr-rosters'],
  ),
  'review_audit': _HomeActionDefinition(
    id: 'review_audit',
    label: 'Review audit',
    icon: Icons.policy_outlined,
    route: AppRoutes.reports,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.operations,
      AppRole.mortuaryManager,
      AppRole.biomedManager,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.complianceReview,
      AppPermissions.evidenceExport,
    ],
  ),
  'update_own_profile': _HomeActionDefinition(
    id: 'update_own_profile',
    label: 'Update my profile',
    icon: Icons.account_circle_outlined,
    route: AppRoutes.profile,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.profileUpdate,
      AppPermissions.profileRead,
    ],
  ),
  'view_my_care': _HomeActionDefinition(
    id: 'view_my_care',
    label: 'View my care',
    icon: Icons.favorite_border_outlined,
    route: AppRoutes.profile,
    allowedRoles: <AppRole>[AppRole.patient],
    requiredPermissions: <AppPermission>[AppPermissions.profileRead],
  ),
  'contact_facility': _HomeActionDefinition(
    id: 'contact_facility',
    label: 'Contact facility',
    icon: Icons.forum_outlined,
    route: AppRoutes.communications,
    allowedRoles: <AppRole>[AppRole.patient, AppRole.other],
    requiredPermissions: <AppPermission>[AppPermissions.profileRead],
  ),
  'open_profile': _HomeActionDefinition(
    id: 'open_profile',
    label: 'Open profile',
    icon: Icons.account_circle_outlined,
    route: AppRoutes.profile,
    requiredPermissions: <AppPermission>[AppPermissions.profileRead],
  ),
  'new_patient': _HomeActionDefinition(
    id: 'new_patient',
    label: 'Register patient',
    icon: Icons.person_add_alt_1_outlined,
    route: AppRoutes.patients,
    allowedRoles: <AppRole>[AppRole.facilityAdmin, AppRole.receptionist],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['patients'],
  ),
  'appointment': _HomeActionDefinition(
    id: 'appointment',
    label: 'Book appointment',
    icon: Icons.event_available_outlined,
    route: AppRoutes.opd,
    allowedRoles: <AppRole>[AppRole.facilityAdmin, AppRole.receptionist],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['scheduling'],
  ),
  'lab_order': _HomeActionDefinition(
    id: 'lab_order',
    label: 'Order lab test',
    icon: Icons.biotech_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['lab'],
  ),
  'radiology_order': _HomeActionDefinition(
    id: 'radiology_order',
    label: 'Order imaging',
    icon: Icons.camera_outdoor_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['radiology'],
  ),
  'invoice': _HomeActionDefinition(
    id: 'invoice',
    label: 'Create invoice',
    icon: Icons.receipt_long_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'sale': _HomeActionDefinition(
    id: 'sale',
    label: 'Pharmacy sale',
    icon: Icons.medication_liquid_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'staff_profile': _HomeActionDefinition(
    id: 'staff_profile',
    label: 'Add staff profile',
    icon: Icons.badge_outlined,
    route: AppRoutes.hr,
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.hrWrite,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
    ],
    requiredModules: <String>['hr'],
  ),
  'report_maintenance_issue': _HomeActionDefinition(
    id: 'report_maintenance_issue',
    label: 'Create maintenance request',
    icon: Icons.handyman_outlined,
    route: AppRoutes.operations,
    allowedRoles: <AppRole>[AppRole.operations, AppRole.facilityAdmin],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['operations'],
  ),
  'cleaning_task': _HomeActionDefinition(
    id: 'cleaning_task',
    label: 'Create cleaning task',
    icon: Icons.cleaning_services_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.housekeepingManager, AppRole.operations],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['housekeeping'],
  ),
  'mortuary_case': _HomeActionDefinition(
    id: 'mortuary_case',
    label: 'Open mortuary case',
    icon: Icons.inventory_2_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
    requiredModules: <String>['mortuary'],
  ),
  'release_authorisation': _HomeActionDefinition(
    id: 'release_authorisation',
    label: 'Review release authorization',
    icon: Icons.verified_user_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryManager],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.mortuaryRelease,
      AppPermissions.mortuaryApprove,
    ],
    requiredModules: <String>['mortuary'],
  ),
};

const Map<String, _HomeShortcutDefinition> _shortcutLibrary =
    <String, _HomeShortcutDefinition>{
      'patients': _HomeShortcutDefinition(
        id: 'patients',
        label: 'Patients',
        icon: Icons.people_alt_outlined,
        route: AppRoutes.patients,
      ),
      'opd': _HomeShortcutDefinition(
        id: 'opd',
        label: 'OPD',
        icon: Icons.event_note_outlined,
        route: AppRoutes.opd,
      ),
      'emergency': _HomeShortcutDefinition(
        id: 'emergency',
        label: 'Emergency',
        icon: Icons.emergency_outlined,
        route: AppRoutes.emergency,
      ),
      'ipd': _HomeShortcutDefinition(
        id: 'ipd',
        label: 'IPD',
        icon: Icons.local_hospital_outlined,
        route: AppRoutes.ipd,
      ),
      'rooms_beds': _HomeShortcutDefinition(
        id: 'rooms_beds',
        label: 'Rooms and beds',
        icon: Icons.bed_outlined,
        route: AppRoutes.roomsBeds,
      ),
      'icu': _HomeShortcutDefinition(
        id: 'icu',
        label: 'ICU',
        icon: Icons.monitor_heart_outlined,
        route: AppRoutes.icu,
      ),
      'nursing': _HomeShortcutDefinition(
        id: 'nursing',
        label: 'Nursing',
        icon: Icons.health_and_safety_outlined,
        route: AppRoutes.nursing,
      ),
      'clinical': _HomeShortcutDefinition(
        id: 'clinical',
        label: 'Clinical',
        icon: Icons.medical_services_outlined,
        route: AppRoutes.clinical,
      ),
      'lab': _HomeShortcutDefinition(
        id: 'lab',
        label: 'Laboratory',
        icon: Icons.biotech_outlined,
        route: AppRoutes.lab,
      ),
      'radiology': _HomeShortcutDefinition(
        id: 'radiology',
        label: 'Radiology',
        icon: Icons.camera_outdoor_outlined,
        route: AppRoutes.radiology,
      ),
      'pharmacy': _HomeShortcutDefinition(
        id: 'pharmacy',
        label: 'Pharmacy',
        icon: Icons.local_pharmacy_outlined,
        route: AppRoutes.pharmacy,
      ),
      'billing': _HomeShortcutDefinition(
        id: 'billing',
        label: 'Billing',
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.billing,
      ),
      'claims': _HomeShortcutDefinition(
        id: 'claims',
        label: 'Claims',
        icon: Icons.assignment_turned_in_outlined,
        route: AppRoutes.claims,
      ),
      'hr': _HomeShortcutDefinition(
        id: 'hr',
        label: 'HR',
        icon: Icons.badge_outlined,
        route: AppRoutes.hr,
      ),
      'operations': _HomeShortcutDefinition(
        id: 'operations',
        label: 'Operations',
        icon: Icons.handyman_outlined,
        route: AppRoutes.operations,
      ),
      'housekeeping': _HomeShortcutDefinition(
        id: 'housekeeping',
        label: 'Housekeeping',
        icon: Icons.cleaning_services_outlined,
        route: AppRoutes.housekeeping,
      ),
      'biomedical': _HomeShortcutDefinition(
        id: 'biomedical',
        label: 'Biomedical',
        icon: Icons.precision_manufacturing_outlined,
        route: AppRoutes.biomedical,
      ),
      'communications': _HomeShortcutDefinition(
        id: 'communications',
        label: 'Communications',
        icon: Icons.forum_outlined,
        route: AppRoutes.communications,
      ),
      'integrations': _HomeShortcutDefinition(
        id: 'integrations',
        label: 'Integrations',
        icon: Icons.hub_outlined,
        route: AppRoutes.integrations,
      ),
      'discharge': _HomeShortcutDefinition(
        id: 'discharge',
        label: 'Discharge',
        icon: Icons.output_outlined,
        route: AppRoutes.discharge,
      ),
      'mortuary': _HomeShortcutDefinition(
        id: 'mortuary',
        label: 'Mortuary',
        icon: Icons.inventory_2_outlined,
        route: AppRoutes.mortuary,
      ),
      'theater': _HomeShortcutDefinition(
        id: 'theater',
        label: 'Theatre',
        icon: Icons.fact_check_outlined,
        route: AppRoutes.theater,
      ),
      'reports': _HomeShortcutDefinition(
        id: 'reports',
        label: 'Reports',
        icon: Icons.analytics_outlined,
        route: AppRoutes.reports,
      ),
      'subscriptions': _HomeShortcutDefinition(
        id: 'subscriptions',
        label: 'Subscriptions',
        icon: Icons.workspace_premium_outlined,
        route: AppRoutes.subscriptions,
      ),
      'tenant_facility_setup': _HomeShortcutDefinition(
        id: 'tenant_facility_setup',
        label: 'Tenant and facility setup',
        icon: Icons.account_tree_outlined,
        route: AppRoutes.tenantFacilitySetup,
      ),
      'settings': _HomeShortcutDefinition(
        id: 'settings',
        label: 'Settings',
        icon: Icons.settings_outlined,
        route: AppRoutes.settings,
      ),
      'profile': _HomeShortcutDefinition(
        id: 'profile',
        label: 'Profile',
        icon: Icons.account_circle_outlined,
        route: AppRoutes.profile,
      ),
    };

List<_HomeActionDefinition> _visibleActions(
  List<String> ids,
  AppAccessPolicy policy, {
  int? maxCount,
}) {
  final List<_HomeActionDefinition> actions = ids
      .map((String id) => _actionLibrary[id])
      .whereType<_HomeActionDefinition>()
      .where((_HomeActionDefinition action) => action.isAllowed(policy))
      .toList(growable: false);
  if (maxCount == null || maxCount <= 0) {
    return actions;
  }
  return actions.take(maxCount).toList(growable: false);
}

List<_HomeShortcutDefinition> _shortcutsExcludingQuickActions(
  List<_HomeShortcutDefinition> shortcuts,
  List<_HomeActionDefinition> actions,
  HomeDashboardProfile profile,
) {
  if (!profile.showShortcutsSection(quickActionCount: actions.length)) {
    return const <_HomeShortcutDefinition>[];
  }
  final Set<String> actionRoutes = actions
      .map((_HomeActionDefinition action) => action.route.path)
      .toSet();
  return shortcuts
      .where(
        (_HomeShortcutDefinition shortcut) =>
            !actionRoutes.contains(shortcut.route.path),
      )
      .toList(growable: false);
}

List<_HomeShortcutDefinition> _visibleShortcuts(
  List<String> ids,
  AppAccessPolicy policy,
) {
  return ids
      .map((String id) => _shortcutLibrary[id])
      .whereType<_HomeShortcutDefinition>()
      .where((_HomeShortcutDefinition shortcut) => shortcut.isAllowed(policy))
      .toList(growable: false);
}

List<_HomeActionDefinition> _visibleEmptyActions(
  List<String> ids,
  List<_HomeActionDefinition> visibleActions,
) {
  final Set<String> allowedIds = visibleActions
      .map((_HomeActionDefinition action) => action.id)
      .toSet();
  return ids
      .where(allowedIds.contains)
      .map((String id) => _actionLibrary[id])
      .whereType<_HomeActionDefinition>()
      .toList(growable: false);
}

HomeRouteTarget? _firstQueueTarget(List<HomeQueueItem> items) {
  for (final HomeQueueItem item in items) {
    if (item.target != null) {
      return item.target;
    }
  }
  return null;
}

AppRouteData? _routeForTarget(HomeRouteTarget? target) {
  final String moduleSlug = (target?.moduleSlug ?? '').trim().toLowerCase();
  if (moduleSlug.isEmpty) {
    return null;
  }

  return switch (moduleSlug) {
    'patients' || 'patient' => AppRoutes.patients,
    'scheduling' || 'opd' || 'appointments' => AppRoutes.opd,
    'emergency' => AppRoutes.emergency,
    'clinical' => AppRoutes.clinical,
    'nursing' => AppRoutes.nursing,
    'ipd' => AppRoutes.ipd,
    'icu' => AppRoutes.icu,
    'theatre' || 'theater' => AppRoutes.theater,
    'lab' || 'laboratory' => AppRoutes.lab,
    'radiology' || 'imaging' => AppRoutes.radiology,
    'pharmacy' => AppRoutes.pharmacy,
    'billing' => AppRoutes.billing,
    'claims' => AppRoutes.claims,
    'hr' || 'roster' => AppRoutes.hr,
    'operations' => AppRoutes.operations,
    'rooms_beds' || 'rooms-beds' => AppRoutes.roomsBeds,
    'housekeeping' => AppRoutes.housekeeping,
    'biomedical' || 'biomed' => AppRoutes.biomedical,
    'mortuary' => AppRoutes.mortuary,
    'communications' => AppRoutes.communications,
    'reports' || 'audit' || 'dashboard' => AppRoutes.reports,
    'subscriptions' => AppRoutes.subscriptions,
    'settings' => AppRoutes.settings,
    'profile' => AppRoutes.profile,
    _ => null,
  };
}

void _goToRoute(
  BuildContext context,
  AppRouteData route, {
  Map<String, String> queryParameters = const <String, String>{},
}) {
  context.go(route.location(queryParameters: queryParameters));
}

void _invokeHomeAction(
  BuildContext context,
  WidgetRef ref,
  _HomeActionDefinition action,
) {
  if (action.id == 'add_staff_profile' || action.id == 'staff_profile') {
    unawaited(showHrStaffOnboardingDialog(context, ref));
    return;
  }
  _goToRoute(context, action.route, queryParameters: action.routeQuery);
}

String _trendTitle(AppRole role, String fallback) {
  final String title = switch (role) {
    AppRole.superAdmin => 'Platform signal trend',
    AppRole.tenantAdmin => 'Facilities performance trend',
    AppRole.facilityAdmin => 'OPD flow by hour',
    AppRole.doctor => 'Consultation trend',
    AppRole.nurse => 'Medication rounds trend',
    AppRole.labTech => 'Sample throughput trend',
    AppRole.radiologyTech => 'Imaging throughput trend',
    AppRole.pharmacist => 'Dispensing throughput trend',
    AppRole.receptionist => 'Front desk arrivals trend',
    AppRole.billing => 'Collections trend',
    AppRole.operations => 'Facility readiness trend',
    AppRole.hr => 'Staffing coverage trend',
    AppRole.biomed || AppRole.biomedManager => 'Equipment service trend',
    AppRole.houseKeeper ||
    AppRole.housekeepingManager => 'Cleaning throughput trend',
    AppRole.ambulanceOperator => 'Dispatch response trend',
    AppRole.patient => 'Care activity trend',
    AppRole.mortuaryStaff ||
    AppRole.mortuaryManager => 'Mortuary activity trend',
    _ => fallback,
  };
  return title.trim().isEmpty ? 'Dashboard trend' : title;
}

String _distributionTitle(AppRole role, String fallback) {
  final String title = switch (role) {
    AppRole.superAdmin => 'Tenant mix donut',
    AppRole.tenantAdmin => 'Module adoption donut',
    AppRole.facilityAdmin => 'Bed readiness donut',
    AppRole.doctor => 'Patient acuity mix',
    AppRole.nurse => 'Ward distribution',
    AppRole.labTech => 'Test mix donut',
    AppRole.radiologyTech => 'Study mix donut',
    AppRole.pharmacist => 'Stock pressure donut',
    AppRole.receptionist => 'Queue mix donut',
    AppRole.billing => 'Revenue mix donut',
    AppRole.operations => 'Bed readiness mix donut',
    AppRole.hr => 'Workforce mix donut',
    AppRole.biomed || AppRole.biomedManager => 'Asset service status donut',
    AppRole.houseKeeper || AppRole.housekeepingManager => 'Task mix donut',
    AppRole.ambulanceOperator => 'Fleet readiness donut',
    AppRole.patient => 'Care summary donut',
    AppRole.mortuaryStaff || AppRole.mortuaryManager => 'Case status donut',
    _ => fallback,
  };
  return title.trim().isEmpty ? 'Status distribution' : title;
}

String _queueTitle(AppRole role) {
  return switch (role) {
    AppRole.superAdmin => 'Review',
    AppRole.tenantAdmin => 'Actions',
    AppRole.facilityAdmin => 'Operations',
    AppRole.doctor => 'Worklist',
    AppRole.nurse => 'Tasks',
    AppRole.labTech => 'Lab queue',
    AppRole.radiologyTech => 'Imaging',
    AppRole.pharmacist => 'Orders',
    AppRole.receptionist => 'Desk',
    AppRole.billing => 'Billing',
    AppRole.operations => 'Ops queue',
    AppRole.hr => 'Workforce',
    AppRole.biomed || AppRole.biomedManager => 'Service',
    AppRole.houseKeeper || AppRole.housekeepingManager => 'Cleaning',
    AppRole.ambulanceOperator => 'Dispatch',
    AppRole.patient => 'Updates',
    _ => 'Queue',
  };
}

String _alertsTitle(AppRole role) {
  return switch (role) {
    AppRole.doctor => 'Critical alerts',
    _ => 'Alerts',
  };
}

String _trendPointLabel(HomeTrendPoint point, {bool compact = false}) {
  if (_hasText(point.label)) {
    return point.label!;
  }
  if (point.date == null) {
    return point.id;
  }
  return DateFormat(compact ? 'E' : 'MMM d').format(point.date!.toLocal());
}

Color _toneColor(ThemeData theme, AppWorkspaceStatusTone tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  return switch (tone) {
    AppWorkspaceStatusTone.success => colorScheme.tertiary,
    AppWorkspaceStatusTone.warning => colorScheme.secondary,
    AppWorkspaceStatusTone.error => colorScheme.error,
    AppWorkspaceStatusTone.info => colorScheme.primary,
    AppWorkspaceStatusTone.neutral => colorScheme.onSurfaceVariant,
  };
}

Color _segmentColor(
  ThemeData theme,
  HomeDistributionSegment segment,
  int index,
) {
  return _segmentColorFromHex(segment.color) ??
      _fallbackSegmentColor(theme.colorScheme.primary, index);
}

Color? _segmentColorFromHex(String? value) {
  final String normalized = (value ?? '').trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) {
    return null;
  }
  final int? parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
}

Color _fallbackSegmentColor(Color seed, int index) {
  final HSLColor hsl = HSLColor.fromColor(seed);
  final double hue = (hsl.hue + (index * 42)) % 360;
  return hsl
      .withHue(hue)
      .withSaturation(math.min(0.86, hsl.saturation + 0.18))
      .toColor();
}

String _formatMetricValue(HomeStatusCard card) {
  if (card.format == 'currency') {
    return NumberFormat.compactCurrency(symbol: 'UGX ').format(card.value);
  }
  if (card.format == 'percent') {
    final num value = card.value <= 1 && card.value >= 0
        ? card.value * 100
        : card.value;
    return '${NumberFormat.compact().format(value)}%';
  }
  return NumberFormat.compact().format(card.value);
}

String _statusLabel(String? value) {
  if (!_hasText(value)) {
    return 'Open';
  }
  return _formatToken(value!);
}

String _timeLabel(DateTime? value) {
  if (value == null) {
    return '';
  }
  return DateFormat('MMM d, HH:mm').format(value.toLocal());
}

String _formatToken(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) {
        final String lower = word.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

AppWorkspaceStatusTone _metricTone(HomeStatusCard card) {
  final String id = card.id.toLowerCase();
  if (id.contains('critical') ||
      id.contains('overdue') ||
      id.contains('warning') ||
      id.contains('risk')) {
    return card.numericValue > 0
        ? AppWorkspaceStatusTone.error
        : AppWorkspaceStatusTone.success;
  }
  if (id.contains('pending') ||
      id.contains('queue') ||
      id.contains('open') ||
      id.contains('pressure')) {
    return card.numericValue > 0
        ? AppWorkspaceStatusTone.warning
        : AppWorkspaceStatusTone.neutral;
  }
  if (id.contains('completed') ||
      id.contains('available') ||
      id.contains('ready') ||
      id.contains('active')) {
    return AppWorkspaceStatusTone.success;
  }
  return AppWorkspaceStatusTone.info;
}

AppWorkspaceStatusTone _severityTone(String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  return switch (normalized) {
    'CRITICAL' ||
    'ERROR' ||
    'HIGH' ||
    'OVERDUE' ||
    'CANCELLED' => AppWorkspaceStatusTone.error,
    'MEDIUM' ||
    'WARNING' ||
    'PENDING' ||
    'OPEN' ||
    'IN_PROGRESS' => AppWorkspaceStatusTone.warning,
    'LOW' ||
    'INFO' ||
    'SCHEDULED' ||
    'CONFIRMED' => AppWorkspaceStatusTone.info,
    'SUCCESS' ||
    'COMPLETED' ||
    'FINAL' ||
    'PAID' => AppWorkspaceStatusTone.success,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData _metricIcon(String id) {
  final String normalized = id.toLowerCase();
  if (normalized.contains('patient')) return Icons.people_alt_outlined;
  if (normalized.contains('appointment')) return Icons.event_available_outlined;
  if (normalized.contains('admission') || normalized.contains('bed')) {
    return Icons.local_hospital_outlined;
  }
  if (normalized.contains('invoice') ||
      normalized.contains('payment') ||
      normalized.contains('revenue') ||
      normalized.contains('collection')) {
    return Icons.receipt_long_outlined;
  }
  if (normalized.contains('lab')) return Icons.biotech_outlined;
  if (normalized.contains('radiology')) return Icons.camera_outdoor_outlined;
  if (normalized.contains('stock') || normalized.contains('medication')) {
    return Icons.local_pharmacy_outlined;
  }
  if (normalized.contains('staff') ||
      normalized.contains('shift') ||
      normalized.contains('roster')) {
    return Icons.badge_outlined;
  }
  if (normalized.contains('maintenance') || normalized.contains('work_order')) {
    return Icons.handyman_outlined;
  }
  if (normalized.contains('clean') || normalized.contains('housekeeping')) {
    return Icons.cleaning_services_outlined;
  }
  if (normalized.contains('alert') ||
      normalized.contains('critical') ||
      normalized.contains('risk')) {
    return Icons.warning_amber_outlined;
  }
  return Icons.insights_outlined;
}

IconData _moduleIcon(String moduleSlug) {
  return switch (moduleSlug.toLowerCase()) {
    'patients' || 'patient' => Icons.people_alt_outlined,
    'scheduling' || 'opd' => Icons.event_note_outlined,
    'clinical' => Icons.medical_services_outlined,
    'nursing' => Icons.health_and_safety_outlined,
    'ipd' => Icons.local_hospital_outlined,
    'rooms_beds' || 'rooms-beds' => Icons.bed_outlined,
    'icu' => Icons.monitor_heart_outlined,
    'lab' => Icons.biotech_outlined,
    'radiology' => Icons.camera_outdoor_outlined,
    'pharmacy' => Icons.local_pharmacy_outlined,
    'billing' => Icons.receipt_long_outlined,
    'housekeeping' => Icons.cleaning_services_outlined,
    'biomedical' => Icons.precision_manufacturing_outlined,
    'hr' => Icons.badge_outlined,
    'emergency' => Icons.emergency_outlined,
    'mortuary' => Icons.inventory_2_outlined,
    'communications' => Icons.forum_outlined,
    'profile' => Icons.account_circle_outlined,
    _ => Icons.insights_outlined,
  };
}

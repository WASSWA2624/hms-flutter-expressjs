import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_mapper.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_charts_row.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Pharmacy home charts: most-sold series with period / top-N / chart controls.
class PharmacyMostSoldCharts extends ConsumerStatefulWidget {
  const PharmacyMostSoldCharts({
    required this.dashboard,
    required this.l10n,
    this.request = HomeDashboardRequest.empty,
    this.twoColumns = false,
    super.key,
  });

  final HomeDashboard dashboard;
  final AppLocalizations l10n;
  final HomeDashboardRequest request;
  final bool twoColumns;

  @override
  ConsumerState<PharmacyMostSoldCharts> createState() =>
      _PharmacyMostSoldChartsState();
}

class _PharmacyMostSoldChartsState extends ConsumerState<PharmacyMostSoldCharts> {
  static const List<int> _topNOptions = <int>[5, 10, 20, 100];

  static const List<HomeMostSoldPeriod> _periodOptions = <HomeMostSoldPeriod>[
    HomeMostSoldPeriod.today,
    HomeMostSoldPeriod.lastWeek,
    HomeMostSoldPeriod.lastMonth,
    HomeMostSoldPeriod.lastThreeMonths,
    HomeMostSoldPeriod.lastSixMonths,
    HomeMostSoldPeriod.lastYear,
    HomeMostSoldPeriod.lastFiveYears,
  ];

  HomeMostSoldMetric _metric = HomeMostSoldMetric.qty;
  HomeMostSoldPeriod _period = HomeMostSoldPeriod.today;
  int _topN = 5;
  DashboardTrendChartStyle _chartStyle = DashboardTrendChartStyle.bar;
  HomeMostSoldSeries? _mostSoldOverride;
  bool _loadingMostSold = false;
  String? _mostSoldError;

  @override
  void initState() {
    super.initState();
    final HomeMostSoldPeriod requested =
        widget.request.mostSoldPeriod ?? HomeMostSoldPeriod.today;
    _period = _periodOptions.contains(requested)
        ? requested
        : HomeMostSoldPeriod.today;
    _topN = _normalizeTopN(widget.request.mostSoldLimit ?? 5);
  }

  @override
  void didUpdateWidget(covariant PharmacyMostSoldCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dashboard.mostSold != widget.dashboard.mostSold &&
        _mostSoldOverride == null) {
      // Parent refresh replaced baseline series.
    }
  }

  HomeMostSoldSeries get _series =>
      _mostSoldOverride ?? widget.dashboard.mostSold;

  int _normalizeTopN(int value) {
    if (_topNOptions.contains(value)) {
      return value;
    }
    return _topNOptions.reduce(
      (int a, int b) => (value - a).abs() <= (value - b).abs() ? a : b,
    );
  }

  Future<void> _reloadMostSold({
    HomeMostSoldPeriod? period,
    int? topN,
  }) async {
    final HomeMostSoldPeriod nextPeriod = period ?? _period;
    final int nextTopN = topN ?? _topN;

    setState(() {
      _period = nextPeriod;
      _topN = nextTopN;
      _loadingMostSold = true;
      _mostSoldError = null;
    });

    final HomeRepository repository = ref.read(homeRepositoryProvider);
    final Result<HomeDashboard> result = await repository.loadDashboard(
      widget.request.copyWith(
        mostSoldPeriod: nextPeriod,
        mostSoldLimit: nextTopN,
        clearMostSoldFrom: true,
        clearMostSoldTo: true,
      ),
    );

    if (!mounted) {
      return;
    }

    result.when(
      success: (HomeDashboard dashboard) {
        setState(() {
          _mostSoldOverride = dashboard.mostSold;
          _loadingMostSold = false;
          _mostSoldError = null;
        });
      },
      failure: (failure) {
        setState(() {
          _loadingMostSold = false;
          _mostSoldError =
              failure.detailMessage ?? 'Could not refresh most-sold drugs.';
        });
      },
    );
  }

  void _openStatusSection(DashboardDistributionSegmentData segment) {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (!policy.grantsAny(const <AppPermission>[
      AppPermissions.pharmacyRead,
      AppPermissions.pharmacyWrite,
    ])) {
      return;
    }
    final String? section = pharmacyOrderStatusSection(
      segmentId: segment.id,
      label: segment.label,
    );
    if (section == null) {
      return;
    }
    homeGoToRoute(
      context,
      AppRoutes.pharmacy,
      queryParameters: <String, String>{'section': section},
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canSeeMoney =
        policy.grants(AppPermissions.pricingPharmacyRead) ||
        policy.grants(AppPermissions.billingRead) ||
        policy.grants(AppPermissions.reportsRead);
    final bool hasProfit = _series.profit.any(
      (HomeTrendPoint point) => point.value > 0,
    );

    final List<HomeMostSoldMetric> allowed = <HomeMostSoldMetric>[
      HomeMostSoldMetric.qty,
      if (canSeeMoney) HomeMostSoldMetric.amount,
      if (canSeeMoney && hasProfit) HomeMostSoldMetric.profit,
    ];
    final HomeMostSoldMetric active = allowed.contains(_metric)
        ? _metric
        : HomeMostSoldMetric.qty;

    final List<HomeTrendPoint> ranked = _series.hasData
        ? _series.forMetric(active).take(_topN).toList(growable: false)
        : const <HomeTrendPoint>[];
    final List<DashboardTrendPointData> chartPoints = ranked.isEmpty
        ? List<DashboardTrendPointData>.generate(
            _topN,
            (int index) => DashboardTrendPointData(
              value: 0,
              label: '#${index + 1}',
            ),
            growable: false,
          )
        : ranked
            .map(
              (HomeTrendPoint point) => DashboardTrendPointData(
                value: point.value,
                label: point.label,
                date: point.date,
              ),
            )
            .toList(growable: false);

    final DashboardChartsData charts = homeDashboardChartsData(
      dashboard: widget.dashboard.copyWith(
        mostSold: _series,
        trend: HomeDashboardTrend(
          title: 'Most sold drugs',
          subtitle: _subtitle(active),
          points: ranked,
          requiredPermissions: widget.dashboard.trend.requiredPermissions,
        ),
      ),
      l10n: widget.l10n,
    );

    final List<Widget> filterActions = <Widget>[
      _MostSoldToolbar(
        period: _period,
        topN: _topN,
        chartStyle: _chartStyle,
        metric: active,
        allowedMetrics: allowed,
        loading: _loadingMostSold,
        periodOptions: _periodOptions,
        topNOptions: _topNOptions,
        onPeriodChanged: (HomeMostSoldPeriod value) =>
            _reloadMostSold(period: value),
        onTopNChanged: (int value) => _reloadMostSold(topN: value),
        onChartStyleChanged: (DashboardTrendChartStyle value) {
          setState(() => _chartStyle = value);
        },
        onMetricChanged: (HomeMostSoldMetric value) {
          setState(() => _metric = value);
        },
      ),
    ];

    final DashboardChartsData decorated = DashboardChartsData(
      trend: DashboardTrendChartData(
        title: charts.trend.title,
        subtitle: charts.trend.subtitle,
        points: chartPoints,
        emptyMessage: '',
        chartStyle: _chartStyle,
        sectionActions: filterActions,
        footer: ranked.isEmpty
            ? null
            : _SoldDrugsList(
                points: ranked,
                metric: active,
              ),
      ),
      distribution: DashboardDistributionChartData(
        title: charts.distribution.title,
        total: charts.distribution.total,
        segments: charts.distribution.segments,
        emptyMessage: charts.distribution.emptyMessage,
        totalLabel: charts.distribution.totalLabel,
        onSegmentSelected: _openStatusSection,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_mostSoldError != null && !_loadingMostSold)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: Text(
              _mostSoldError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        DashboardChartsRow(data: decorated, twoColumns: widget.twoColumns),
      ],
    );
  }

  String _subtitle(HomeMostSoldMetric metric) {
    final String metricLabel = switch (metric) {
      HomeMostSoldMetric.qty => 'quantity dispensed',
      HomeMostSoldMetric.amount => 'sales amount',
      HomeMostSoldMetric.profit => 'profit proxy',
    };
    return 'Top $_topN by $metricLabel · ${_period.label}';
  }
}

/// Maps order-status mix segment id/label → `/pharmacy?section=` value.
String? pharmacyOrderStatusSection({String? segmentId, String? label}) {
  final String raw = (segmentId ?? label ?? '').trim().toLowerCase();
  final String normalized = raw.replaceAll(RegExp(r'[\s-]+'), '_');
  return switch (normalized) {
    'ordered' || 'order' || 'ready' || 'queue' || 'new' => 'queue',
    'partially_dispensed' ||
    'partially dispensed' ||
    'partial' ||
    'in_progress' ||
    'in-progress' =>
      'in-progress',
    'dispensed' || 'completed' => 'completed',
    'cancelled' || 'canceled' => 'cancelled',
    _ => null,
  };
}

/// Compact unlabeled dashboard controls in one horizontal strip.
class _MostSoldToolbar extends StatelessWidget {
  const _MostSoldToolbar({
    required this.period,
    required this.topN,
    required this.chartStyle,
    required this.metric,
    required this.allowedMetrics,
    required this.loading,
    required this.periodOptions,
    required this.topNOptions,
    required this.onPeriodChanged,
    required this.onTopNChanged,
    required this.onChartStyleChanged,
    required this.onMetricChanged,
  });

  final HomeMostSoldPeriod period;
  final int topN;
  final DashboardTrendChartStyle chartStyle;
  final HomeMostSoldMetric metric;
  final List<HomeMostSoldMetric> allowedMetrics;
  final bool loading;
  final List<HomeMostSoldPeriod> periodOptions;
  final List<int> topNOptions;
  final ValueChanged<HomeMostSoldPeriod> onPeriodChanged;
  final ValueChanged<int> onTopNChanged;
  final ValueChanged<DashboardTrendChartStyle> onChartStyleChanged;
  final ValueChanged<HomeMostSoldMetric> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.spacing.sm,
        runSpacing: theme.spacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _CompactDropdown<HomeMostSoldPeriod>(
            tooltip: 'Period',
            value: period,
            items: periodOptions,
            labelOf: (HomeMostSoldPeriod value) => value.label,
            onChanged: loading ? null : onPeriodChanged,
          ),
          _CompactDropdown<int>(
            tooltip: 'Top drugs',
            value: topN,
            items: topNOptions,
            labelOf: (int value) => 'Top $value',
            onChanged: loading ? null : onTopNChanged,
          ),
          _CompactDropdown<DashboardTrendChartStyle>(
            tooltip: 'Chart type',
            value: chartStyle,
            items: const <DashboardTrendChartStyle>[
              DashboardTrendChartStyle.bar,
              DashboardTrendChartStyle.line,
              DashboardTrendChartStyle.pie,
            ],
            labelOf: _chartStyleLabel,
            onChanged: loading ? null : onChartStyleChanged,
          ),
          if (allowedMetrics.length > 1)
            _MetricRadioToggle(
              metric: metric,
              allowed: allowedMetrics,
              onChanged: loading ? null : onMetricChanged,
            ),
          if (loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

String _chartStyleLabel(DashboardTrendChartStyle style) {
  return switch (style) {
    DashboardTrendChartStyle.line => 'Line',
    DashboardTrendChartStyle.bar => 'Bar',
    DashboardTrendChartStyle.pie => 'Pie',
    DashboardTrendChartStyle.combined => 'Combined',
  };
}

class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({
    required this.tooltip,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String tooltip;
  final T value;
  final List<T> items;
  final String Function(T value) labelOf;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radius.md),
          border: theme.borders.all(color: theme.borders.faint),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              borderRadius: BorderRadius.circular(theme.radius.md),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              items: <DropdownMenuItem<T>>[
                for (final T item in items)
                  DropdownMenuItem<T>(
                    value: item,
                    child: Text(labelOf(item)),
                  ),
              ],
              onChanged: onChanged == null
                  ? null
                  : (T? next) {
                      if (next == null) {
                        return;
                      }
                      onChanged!(next);
                    },
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact radio-style metric picker for qty / amount / profit.
class _MetricRadioToggle extends StatelessWidget {
  const _MetricRadioToggle({
    required this.metric,
    required this.allowed,
    required this.onChanged,
  });

  final HomeMostSoldMetric metric;
  final List<HomeMostSoldMetric> allowed;
  final ValueChanged<HomeMostSoldMetric>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: theme.borders.all(color: theme.borders.faint),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < allowed.length; index += 1) ...<Widget>[
            if (index > 0)
              Container(
                width: 1,
                height: 28,
                color: theme.borders.faint,
              ),
            InkWell(
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(allowed[index]),
              borderRadius: BorderRadius.circular(theme.radius.sm),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      allowed[index] == metric
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 16,
                      color: allowed[index] == metric
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: theme.spacing.xs),
                    Text(
                      _metricLabel(allowed[index]),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: allowed[index] == metric
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: allowed[index] == metric
                            ? AppFontWeight.emphasis
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _metricLabel(HomeMostSoldMetric metric) {
    return switch (metric) {
      HomeMostSoldMetric.qty => 'Qty',
      HomeMostSoldMetric.amount => 'Amount',
      HomeMostSoldMetric.profit => 'Profit',
    };
  }
}

class _SoldDrugsList extends StatelessWidget {
  const _SoldDrugsList({required this.points, required this.metric});

  final List<HomeTrendPoint> points;
  final HomeMostSoldMetric metric;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NumberFormat compact = NumberFormat.compact();
    final String unit = switch (metric) {
      HomeMostSoldMetric.qty => 'qty',
      HomeMostSoldMetric.amount => 'amount',
      HomeMostSoldMetric.profit => 'profit',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Sold drugs',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        for (int index = 0; index < points.length; index += 1) ...<Widget>[
          if (index > 0) SizedBox(height: theme.spacing.xs),
          Row(
            children: <Widget>[
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}.',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  points[index].label?.trim().isNotEmpty == true
                      ? points[index].label!.trim()
                      : points[index].id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${compact.format(points[index].value)} $unit',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

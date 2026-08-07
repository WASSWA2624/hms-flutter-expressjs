import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_mapper.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_charts_row.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

/// Reception home charts: registrations trend + tappable appointment status mix.
class ReceptionDeskCharts extends ConsumerStatefulWidget {
  const ReceptionDeskCharts({
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
  ConsumerState<ReceptionDeskCharts> createState() =>
      _ReceptionDeskChartsState();
}

class _ReceptionDeskChartsState extends ConsumerState<ReceptionDeskCharts> {
  static const List<HomeMostSoldPeriod> _periodOptions = <HomeMostSoldPeriod>[
    HomeMostSoldPeriod.today,
    HomeMostSoldPeriod.lastWeek,
    HomeMostSoldPeriod.lastMonth,
    HomeMostSoldPeriod.lastThreeMonths,
    HomeMostSoldPeriod.lastSixMonths,
    HomeMostSoldPeriod.lastYear,
  ];

  static const List<({String id, String label})> _statusCatalog =
      <({String id, String label})>[
        (id: 'scheduled', label: 'Scheduled'),
        (id: 'confirmed', label: 'Confirmed'),
        (id: 'in_progress', label: 'In progress'),
        (id: 'completed', label: 'Completed'),
        (id: 'no_show', label: 'No-show'),
        (id: 'cancelled', label: 'Cancelled'),
      ];

  HomeMostSoldPeriod _trendPeriod = HomeMostSoldPeriod.lastWeek;
  HomeMostSoldPeriod _statusPeriod = HomeMostSoldPeriod.today;
  DashboardTrendChartStyle _trendStyle = DashboardTrendChartStyle.combined;
  DashboardTrendChartStyle _statusStyle = DashboardTrendChartStyle.pie;
  HomeDashboardTrend? _trendOverride;
  HomeDashboardDistribution? _distributionOverride;
  bool _loadingTrend = false;
  bool _loadingStatus = false;
  String? _trendError;
  String? _statusError;

  HomeMostSoldPeriod get _parentPackPeriod =>
      widget.request.mostSoldPeriod ?? HomeMostSoldPeriod.today;

  @override
  void initState() {
    super.initState();
    final HomeMostSoldPeriod requested =
        widget.request.mostSoldPeriod ?? HomeMostSoldPeriod.today;
    final HomeMostSoldPeriod initial = _periodOptions.contains(requested)
        ? requested
        : HomeMostSoldPeriod.today;
    _statusPeriod = initial;
    if (_periodOptions.contains(HomeMostSoldPeriod.lastWeek)) {
      _trendPeriod = HomeMostSoldPeriod.lastWeek;
    }
  }

  @override
  void didUpdateWidget(covariant ReceptionDeskCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_parentDashboardPackChanged(oldWidget.dashboard, widget.dashboard)) {
      return;
    }
    final bool viewingPackStatus = _statusPeriod == _parentPackPeriod;
    if (viewingPackStatus && _distributionOverride != null) {
      setState(() => _distributionOverride = null);
    } else if (!viewingPackStatus && _distributionOverride != null) {
      unawaited(_reloadStatusMix());
    }
    if (_trendOverride != null && _trendPeriod == HomeMostSoldPeriod.lastWeek) {
      setState(() => _trendOverride = null);
    } else if (_trendOverride != null) {
      unawaited(_reloadTrend());
    }
  }

  bool _parentDashboardPackChanged(HomeDashboard previous, HomeDashboard next) {
    if (previous.generatedAt != null || next.generatedAt != null) {
      return previous.generatedAt != next.generatedAt;
    }
    return previous.trend.points.length != next.trend.points.length ||
        previous.distribution.total != next.distribution.total;
  }

  HomeDashboardTrend get _trend => _trendOverride ?? widget.dashboard.trend;

  HomeDashboardDistribution get _distribution =>
      _distributionOverride ?? widget.dashboard.distribution;

  Future<void> _reloadTrend({HomeMostSoldPeriod? period}) async {
    final HomeMostSoldPeriod nextPeriod = period ?? _trendPeriod;
    setState(() {
      _trendPeriod = nextPeriod;
      _loadingTrend = true;
      _trendError = null;
    });
    final HomeRepository repository = ref.read(homeRepositoryProvider);
    final Result<HomeDashboard> result = await repository.loadDashboard(
      widget.request.copyWith(mostSoldPeriod: nextPeriod),
    );
    if (!mounted) {
      return;
    }
    result.when(
      success: (HomeDashboard dashboard) {
        setState(() {
          _trendOverride = dashboard.trend;
          _loadingTrend = false;
          _trendError = null;
        });
      },
      failure: (failure) {
        setState(() {
          _loadingTrend = false;
          _trendError =
              failure.detailMessage ?? 'Could not refresh registrations trend.';
        });
      },
    );
  }

  Future<void> _reloadStatusMix({HomeMostSoldPeriod? period}) async {
    final HomeMostSoldPeriod nextPeriod = period ?? _statusPeriod;
    setState(() {
      _statusPeriod = nextPeriod;
      _loadingStatus = true;
      _statusError = null;
    });
    final HomeRepository repository = ref.read(homeRepositoryProvider);
    final Result<HomeDashboard> result = await repository.loadDashboard(
      widget.request.copyWith(mostSoldPeriod: nextPeriod),
    );
    if (!mounted) {
      return;
    }
    result.when(
      success: (HomeDashboard dashboard) {
        setState(() {
          _distributionOverride = dashboard.distribution;
          _loadingStatus = false;
          _statusError = null;
        });
      },
      failure: (failure) {
        setState(() {
          _loadingStatus = false;
          _statusError =
              failure.detailMessage ??
              'Could not refresh appointment status mix.';
        });
      },
    );
  }

  void _openStatusSection(DashboardDistributionSegmentData segment) {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (!policy.grants(AppPermissions.patientRead)) {
      return;
    }
    final String? section = receptionAppointmentStatusSection(
      segmentId: segment.id,
      label: segment.label,
    );
    if (section == null) {
      return;
    }
    homeGoToRoute(
      context,
      AppRoutes.reception,
      queryParameters: homeReceptionStatusMixQuery(
        section: section,
        period: _statusPeriod,
      ),
    );
  }

  List<HomeDistributionSegment> _statusSegments() {
    final Map<String, HomeDistributionSegment> byId =
        <String, HomeDistributionSegment>{
          for (final HomeDistributionSegment segment in _distribution.segments)
            segment.id.trim().toLowerCase(): segment,
        };
    return <HomeDistributionSegment>[
      for (final ({String id, String label}) entry in _statusCatalog)
        HomeDistributionSegment(
          id: entry.id,
          label: byId[entry.id]?.label ?? entry.label,
          value: byId[entry.id]?.value ?? 0,
          color: byId[entry.id]?.color,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<HomeDistributionSegment> statusSegments = _statusSegments();
    final num statusTotal = statusSegments.fold<num>(
      0,
      (num sum, HomeDistributionSegment segment) => sum + segment.value,
    );

    final DashboardChartsData charts = homeDashboardChartsData(
      dashboard: widget.dashboard.copyWith(
        trend: _trend,
        distribution: HomeDashboardDistribution(
          title: _distribution.title,
          subtitle: _distribution.subtitle,
          total: statusTotal,
          segments: statusSegments,
          requiredPermissions: _distribution.requiredPermissions,
        ),
      ),
      l10n: widget.l10n,
    );

    final List<Widget> trendActions = <Widget>[
      _ReceptionChartToolbar(
        period: _trendPeriod,
        chartStyle: _trendStyle,
        loading: _loadingTrend,
        periodOptions: _periodOptions,
        chartStyles: const <DashboardTrendChartStyle>[
          DashboardTrendChartStyle.combined,
          DashboardTrendChartStyle.bar,
          DashboardTrendChartStyle.line,
          DashboardTrendChartStyle.area,
        ],
        onPeriodChanged: (HomeMostSoldPeriod value) =>
            _reloadTrend(period: value),
        onChartStyleChanged: (DashboardTrendChartStyle value) {
          setState(() => _trendStyle = value);
        },
      ),
    ];
    final List<Widget> statusActions = <Widget>[
      _ReceptionChartToolbar(
        period: _statusPeriod,
        chartStyle: _statusStyle,
        loading: _loadingStatus,
        periodOptions: _periodOptions,
        chartStyles: const <DashboardTrendChartStyle>[
          DashboardTrendChartStyle.pie,
          DashboardTrendChartStyle.bar,
        ],
        onPeriodChanged: (HomeMostSoldPeriod value) =>
            _reloadStatusMix(period: value),
        onChartStyleChanged: (DashboardTrendChartStyle value) {
          setState(() => _statusStyle = value);
        },
      ),
    ];

    final DashboardChartsData decorated = DashboardChartsData(
      trend: DashboardTrendChartData(
        title: charts.trend.title,
        subtitle: charts.trend.subtitle,
        points: charts.trend.points,
        emptyMessage: charts.trend.emptyMessage,
        chartStyle: _trendStyle,
        sectionActions: trendActions,
      ),
      distribution: DashboardDistributionChartData(
        title: charts.distribution.title,
        total: statusTotal,
        segments: charts.distribution.segments,
        emptyMessage: charts.distribution.emptyMessage,
        totalLabel: 'appointments',
        onSegmentSelected: _openStatusSection,
        chartStyle: _statusStyle,
        sectionActions: statusActions,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_trendError != null && !_loadingTrend)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: Text(
              _trendError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (_statusError != null && !_loadingStatus)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: Text(
              _statusError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        DashboardChartsRow(data: decorated, twoColumns: widget.twoColumns),
      ],
    );
  }
}

class _ReceptionChartToolbar extends StatelessWidget {
  const _ReceptionChartToolbar({
    required this.period,
    required this.chartStyle,
    required this.loading,
    required this.periodOptions,
    required this.chartStyles,
    required this.onPeriodChanged,
    required this.onChartStyleChanged,
  });

  final HomeMostSoldPeriod period;
  final DashboardTrendChartStyle chartStyle;
  final bool loading;
  final List<HomeMostSoldPeriod> periodOptions;
  final List<DashboardTrendChartStyle> chartStyles;
  final ValueChanged<HomeMostSoldPeriod> onPeriodChanged;
  final ValueChanged<DashboardTrendChartStyle> onChartStyleChanged;

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
          Tooltip(
            message: 'Period',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<HomeMostSoldPeriod>(
                value: periodOptions.contains(period)
                    ? period
                    : periodOptions.first,
                isDense: true,
                items: <DropdownMenuItem<HomeMostSoldPeriod>>[
                  for (final HomeMostSoldPeriod option in periodOptions)
                    DropdownMenuItem<HomeMostSoldPeriod>(
                      value: option,
                      child: Text(option.label),
                    ),
                ],
                onChanged: loading
                    ? null
                    : (HomeMostSoldPeriod? value) {
                        if (value != null) {
                          onPeriodChanged(value);
                        }
                      },
              ),
            ),
          ),
          Tooltip(
            message: 'Chart type',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DashboardTrendChartStyle>(
                value: chartStyles.contains(chartStyle)
                    ? chartStyle
                    : chartStyles.first,
                isDense: true,
                items: <DropdownMenuItem<DashboardTrendChartStyle>>[
                  for (final DashboardTrendChartStyle style in chartStyles)
                    DropdownMenuItem<DashboardTrendChartStyle>(
                      value: style,
                      child: Text(_chartStyleLabel(style)),
                    ),
                ],
                onChanged: loading
                    ? null
                    : (DashboardTrendChartStyle? value) {
                        if (value != null) {
                          onChartStyleChanged(value);
                        }
                      },
              ),
            ),
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
    DashboardTrendChartStyle.area => 'Area',
    DashboardTrendChartStyle.pie => 'Pie',
    DashboardTrendChartStyle.combined => 'Combined',
  };
}

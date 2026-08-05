import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_mapper.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_charts_row.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

/// Pharmacy home charts: most-sold bar series with qty / amount / profit toggle.
class PharmacyMostSoldCharts extends ConsumerStatefulWidget {
  const PharmacyMostSoldCharts({
    required this.dashboard,
    required this.l10n,
    this.twoColumns = false,
    super.key,
  });

  final HomeDashboard dashboard;
  final AppLocalizations l10n;
  final bool twoColumns;

  @override
  ConsumerState<PharmacyMostSoldCharts> createState() =>
      _PharmacyMostSoldChartsState();
}

class _PharmacyMostSoldChartsState extends ConsumerState<PharmacyMostSoldCharts> {
  HomeMostSoldMetric _metric = HomeMostSoldMetric.qty;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canSeeMoney =
        policy.grants(AppPermissions.pricingPharmacyRead) ||
        policy.grants(AppPermissions.billingRead) ||
        policy.grants(AppPermissions.reportsRead);
    final bool hasProfit = widget.dashboard.mostSold.profit.any(
      (HomeTrendPoint point) => point.value > 0,
    );

    final List<HomeMostSoldMetric> allowed = <HomeMostSoldMetric>[
      HomeMostSoldMetric.qty,
      if (canSeeMoney) HomeMostSoldMetric.amount,
      // Profit only when backend has cost-based margin (not invented COGS).
      if (canSeeMoney && hasProfit) HomeMostSoldMetric.profit,
    ];
    final HomeMostSoldMetric active = allowed.contains(_metric)
        ? _metric
        : HomeMostSoldMetric.qty;

    final List<HomeTrendPoint> points = widget.dashboard.mostSold.hasData
        ? widget.dashboard.mostSold.forMetric(active)
        : widget.dashboard.trend.points;

    final DashboardChartsData charts = homeDashboardChartsData(
      dashboard: widget.dashboard.copyWith(
        trend: HomeDashboardTrend(
          title: widget.dashboard.trend.title.isEmpty
              ? 'Most sold drugs (last month)'
              : widget.dashboard.trend.title,
          subtitle: _subtitle(active),
          points: points,
          requiredPermissions: widget.dashboard.trend.requiredPermissions,
        ),
      ),
      l10n: widget.l10n,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (allowed.length > 1) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<HomeMostSoldMetric>(
              segments: <ButtonSegment<HomeMostSoldMetric>>[
                for (final HomeMostSoldMetric metric in allowed)
                  ButtonSegment<HomeMostSoldMetric>(
                    value: metric,
                    label: Text(_metricLabel(metric)),
                    icon: Icon(_metricIcon(metric), size: 16),
                  ),
              ],
              selected: <HomeMostSoldMetric>{active},
              onSelectionChanged: (Set<HomeMostSoldMetric> next) {
                if (next.isEmpty) {
                  return;
                }
                setState(() => _metric = next.first);
              },
            ),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        DashboardChartsRow(data: charts, twoColumns: widget.twoColumns),
      ],
    );
  }

  String _metricLabel(HomeMostSoldMetric metric) {
    return switch (metric) {
      HomeMostSoldMetric.qty => 'Qty',
      HomeMostSoldMetric.amount => 'Amount',
      HomeMostSoldMetric.profit => 'Profit',
    };
  }

  IconData _metricIcon(HomeMostSoldMetric metric) {
    return switch (metric) {
      HomeMostSoldMetric.qty => Icons.inventory_2_outlined,
      HomeMostSoldMetric.amount => Icons.payments_outlined,
      HomeMostSoldMetric.profit => Icons.trending_up_outlined,
    };
  }

  String _subtitle(HomeMostSoldMetric metric) {
    return switch (metric) {
      HomeMostSoldMetric.qty => 'Top drugs by quantity dispensed',
      HomeMostSoldMetric.amount => 'Top drugs by sales amount',
      HomeMostSoldMetric.profit => 'Top drugs by profit proxy',
    };
  }
}

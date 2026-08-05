import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_financial_analytics_controller.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_charts_row.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

/// Period-based collections / expenditures / profit analytics for Billing.
class BillingFinancialAnalyticsPanel extends ConsumerWidget {
  const BillingFinancialAnalyticsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!canReadBillingAnalytics(policy)) {
      return const SizedBox.shrink();
    }

    final AsyncValue<Result<BillingFinancialAnalytics>> asyncValue = ref.watch(
      billingFinancialAnalyticsControllerProvider,
    );
    final BillingFinancialAnalyticsController controller = ref.read(
      billingFinancialAnalyticsControllerProvider.notifier,
    );
    final bool showCharts = canViewBillingAnalyticsCharts(policy);
    final bool canOpenReports = canOpenBillingReportsAnalytics(policy);
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      title: l10n.billingAnalyticsTitle,
      leadingIcon: Icons.insights_outlined,
      density: AppContentPanelDensity.compact,
      trailing: canOpenReports
          ? AppButton.tertiary(
              label: l10n.billingAnalyticsOpenReportsAction,
              onPressed: () {
                context.go(
                  '${AppRoutes.reports.path}?dataset=billing_collections_open_balances',
                );
              },
              dense: true,
            )
          : null,
      children: <Widget>[
        Text(
          l10n.billingAnalyticsSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        _PeriodSelector(
          selected: controller.query.period,
          onSelected: (BillingAnalyticsPeriod period) async {
            if (period == BillingAnalyticsPeriod.custom) {
              await _pickCustomRange(context, ref);
              return;
            }
            await controller.applyPeriod(period);
          },
        ),
        SizedBox(height: theme.spacing.md),
        asyncValue.when(
          loading: () => AppLoadingIndicator(
            title: l10n.billingAnalyticsLoadingTitle,
            body: l10n.billingAnalyticsLoadingBody,
          ),
          error: (Object error, StackTrace stackTrace) => AppFailureStateView(
            failure: error is AppFailure ? error : const AppFailure.unexpected(),
            onRetry: controller.refresh,
          ),
          data: (Result<BillingFinancialAnalytics> result) {
            return result.when(
              success: (BillingFinancialAnalytics analytics) {
                return _AnalyticsBody(
                  analytics: analytics,
                  showCharts: showCharts,
                );
              },
              failure: (AppFailure failure) => AppFailureStateView(
                failure: failure,
                onRetry: controller.refresh,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final BillingAnalyticsPeriod selected;
  final ValueChanged<BillingAnalyticsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<(BillingAnalyticsPeriod, String)> options =
        <(BillingAnalyticsPeriod, String)>[
          (BillingAnalyticsPeriod.day, l10n.billingAnalyticsPeriodDay),
          (BillingAnalyticsPeriod.month, l10n.billingAnalyticsPeriodMonth),
          (BillingAnalyticsPeriod.year, l10n.billingAnalyticsPeriodYear),
          (BillingAnalyticsPeriod.custom, l10n.billingAnalyticsPeriodCustom),
        ];

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final (BillingAnalyticsPeriod period, String label) in options)
          FilterChip(
            label: Text(label),
            selected: selected == period,
            onSelected: (_) => onSelected(period),
          ),
      ],
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.analytics, required this.showCharts});

  final BillingFinancialAnalytics analytics;
  final bool showCharts;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (analytics.isEmpty) {
      return AppStateView(
        title: l10n.billingAnalyticsEmptyTitle,
        body: l10n.billingAnalyticsEmptyBody,
        icon: Icons.analytics_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (analytics.subtitle.trim().isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: Text(
              analytics.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        AppReportSummaryGrid(
          records: <AppReportSummaryItem>[
            AppReportSummaryItem(
              label: l10n.billingAnalyticsCollectionsLabel,
              value: billingMoney(context, analytics.collections, null),
              icon: Icons.payments_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.billingAnalyticsExpendituresLabel,
              value: billingMoney(context, analytics.expenditures, null),
              icon: Icons.money_off_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.billingAnalyticsProfitProxyLabel,
              value: billingMoney(context, analytics.profitProxy, null),
              icon: Icons.trending_up_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        if (showCharts) ...<Widget>[
          DashboardChartsRow(
            data: _chartsData(context, analytics),
            twoColumns: MediaQuery.sizeOf(context).width >= 900,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        ExpansionTile(
          title: Text(l10n.billingAnalyticsBreakdownTitle),
          children: <Widget>[
            AppReportSummaryGrid(
              records: <AppReportSummaryItem>[
                AppReportSummaryItem(
                  label: l10n.billingAnalyticsRefundsLabel,
                  value: billingMoney(context, analytics.refunds, null),
                  icon: Icons.undo_outlined,
                ),
                AppReportSummaryItem(
                  label: l10n.billingAnalyticsWriteOffsLabel,
                  value: billingMoney(context, analytics.writeOffs, null),
                  icon: Icons.remove_circle_outline,
                ),
                AppReportSummaryItem(
                  label: l10n.billingAnalyticsNetCollectionsLabel,
                  value: billingMoney(context, analytics.netCollections, null),
                  icon: Icons.account_balance_wallet_outlined,
                ),
                AppReportSummaryItem(
                  label: l10n.billingAnalyticsIssuedInvoicesLabel,
                  value: '${analytics.issuedInvoices}',
                  icon: Icons.receipt_long_outlined,
                ),
                AppReportSummaryItem(
                  label: l10n.billingAnalyticsOpenInvoicesLabel,
                  value: '${analytics.openInvoices}',
                  icon: Icons.pending_actions_outlined,
                ),
              ],
            ),
            if (analytics.collectionsByMethod.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.billingAnalyticsByMethodTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              for (final BillingAnalyticsMethodBreakdown entry
                  in analytics.collectionsByMethod)
                ListTile(
                  dense: true,
                  title: Text(billingApiLabel(context, entry.method)),
                  trailing: Text(billingMoney(context, entry.amount, null)),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

DashboardChartsData _chartsData(
  BuildContext context,
  BillingFinancialAnalytics analytics,
) {
  final AppLocalizations l10n = context.l10n;
  final List<DashboardTrendPointData> points = analytics.series
      .map(
        (BillingAnalyticsPoint point) => DashboardTrendPointData(
          value: point.collections,
          label: point.date,
        ),
      )
      .toList(growable: false);

  final List<DashboardDistributionSegmentData> segments =
      <DashboardDistributionSegmentData>[
        DashboardDistributionSegmentData(
          label: l10n.billingAnalyticsCollectionsLabel,
          value: analytics.collections,
        ),
        DashboardDistributionSegmentData(
          label: l10n.billingAnalyticsExpendituresLabel,
          value: analytics.expenditures,
        ),
        DashboardDistributionSegmentData(
          label: l10n.billingAnalyticsProfitProxyLabel,
          value: analytics.profitProxy < 0 ? 0 : analytics.profitProxy,
        ),
      ].where((DashboardDistributionSegmentData s) => s.value > 0).toList();

  final num distributionTotal = segments.fold<num>(
    0,
    (num sum, DashboardDistributionSegmentData s) => sum + s.value,
  );

  return DashboardChartsData(
    trend: DashboardTrendChartData(
      title: l10n.billingAnalyticsTrendTitle,
      subtitle: analytics.subtitle,
      points: points,
      emptyMessage: l10n.billingAnalyticsEmptyBody,
    ),
    distribution: DashboardDistributionChartData(
      title: l10n.billingAnalyticsMixTitle,
      total: distributionTotal,
      segments: segments,
      emptyMessage: l10n.billingAnalyticsEmptyBody,
      totalLabel: l10n.billingAnalyticsMixTotalLabel,
    ),
  );
}

Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
  final DateTimeRange? range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 1)),
    initialDateRange: DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 29)),
      end: DateTime.now(),
    ),
  );
  if (range == null) {
    return;
  }
  await ref
      .read(billingFinancialAnalyticsControllerProvider.notifier)
      .applyCustomRange(from: range.start, to: range.end);
}

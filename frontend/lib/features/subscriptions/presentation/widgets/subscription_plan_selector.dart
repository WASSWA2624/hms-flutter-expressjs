import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/subscriptions/subscription_plan_theme.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class SubscriptionPlanSelector extends StatelessWidget {
  const SubscriptionPlanSelector({
    required this.plans,
    required this.selectedPlanId,
    required this.currentPlanId,
    required this.billingCycle,
    required this.monthlyLabel,
    required this.annualLabel,
    required this.currentPlanLabel,
    required this.planLabelBuilder,
    required this.onBillingCycleChanged,
    required this.onSelected,
    this.billingCycleHint,
    this.emptyTitle,
    this.emptyMessage,
    super.key,
  });

  final List<SubscriptionUpgradePlanOption> plans;
  final String? selectedPlanId;
  final String? currentPlanId;
  final SubscriptionUpgradeBillingCycle billingCycle;
  final String monthlyLabel;
  final String annualLabel;
  final String currentPlanLabel;
  final String Function(SubscriptionUpgradePlanOption plan) planLabelBuilder;
  final ValueChanged<SubscriptionUpgradeBillingCycle> onBillingCycleChanged;
  final ValueChanged<String> onSelected;
  final String? billingCycleHint;
  final String? emptyTitle;
  final String? emptyMessage;

  static const double _minCardWidth = 168;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (plans.isEmpty) {
      return AppMessagePanel(
        title: emptyTitle ?? 'No plans available',
        message:
            emptyMessage ??
            'Commercial plans could not be loaded. Refresh and try again.',
        icon: Icons.inbox_outlined,
        tone: AppWorkspaceStatusTone.warning,
      );
    }

    final List<SubscriptionUpgradePlanOption> ordered = _sortedPlans();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSectionPanel(
          title: billingCycleHint,
          leadingIcon: Icons.payments_outlined,
          tone: AppWorkspaceStatusTone.info,
          density: AppContentPanelDensity.compact,
          children: <Widget>[
            _BillingCycleToggle(
              value: billingCycle,
              monthlyLabel: monthlyLabel,
              annualLabel: annualLabel,
              onChanged: onBillingCycleChanged,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final int columns = _columnCount(maxWidth, ordered.length);
            final double gap = theme.spacing.sm;
            final List<Widget> rows = <Widget>[];

            for (int start = 0; start < ordered.length; start += columns) {
              final List<SubscriptionUpgradePlanOption> rowPlans = ordered
                  .skip(start)
                  .take(columns)
                  .toList(growable: false);
              if (rows.isNotEmpty) {
                rows.add(SizedBox(height: gap));
              }
              rows.add(
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < columns;
                        index += 1
                      ) ...<Widget>[
                        if (index > 0) SizedBox(width: gap),
                        Expanded(
                          child: index < rowPlans.length
                              ? _PlanColumnTile(
                                  label: planLabelBuilder(rowPlans[index]),
                                  tierCode: rowPlans[index].tierCode,
                                  priceLabel: _priceLabel(
                                    context,
                                    rowPlans[index],
                                  ),
                                  cycleLabel:
                                      billingCycle ==
                                          SubscriptionUpgradeBillingCycle
                                              .monthly
                                      ? monthlyLabel
                                      : annualLabel,
                                  selected:
                                      selectedPlanId == rowPlans[index].id,
                                  isCurrentPlan:
                                      rowPlans[index].id == currentPlanId,
                                  currentPlanLabel: currentPlanLabel,
                                  onTap: () => onSelected(rowPlans[index].id),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            );
          },
        ),
      ],
    );
  }

  List<SubscriptionUpgradePlanOption> _sortedPlans() {
    final List<SubscriptionUpgradePlanOption> ordered =
        List<SubscriptionUpgradePlanOption>.of(plans);
    ordered.sort((
      SubscriptionUpgradePlanOption a,
      SubscriptionUpgradePlanOption b,
    ) {
      final double? left = a.priceFor(billingCycle);
      final double? right = b.priceFor(billingCycle);
      if (left == null && right == null) {
        return a.label.compareTo(b.label);
      }
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      final int byPrice = left.compareTo(right);
      if (byPrice != 0) {
        return byPrice;
      }
      return a.label.compareTo(b.label);
    });
    return ordered;
  }

  int _columnCount(double width, int planCount) {
    if (width <= 0 || planCount <= 0) {
      return 1;
    }
    final int byMinWidth = math.max(1, (width / _minCardWidth).floor());
    final int preferred = width >= AppBreakpoints.xl
        ? 4
        : width >= AppBreakpoints.lg
        ? 3
        : width >= AppBreakpoints.md
        ? 2
        : 1;
    return math.min(planCount, math.min(byMinWidth, preferred));
  }

  String _priceLabel(BuildContext context, SubscriptionUpgradePlanOption plan) {
    final double? amount = plan.priceFor(billingCycle);
    if (amount == null) {
      return '—';
    }
    return AppFormatters.currency(
      amount,
      Localizations.localeOf(context),
      currencyCode: subscriptionPlanBaseCurrencyCode,
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
  }
}

class _BillingCycleToggle extends StatelessWidget {
  const _BillingCycleToggle({
    required this.value,
    required this.monthlyLabel,
    required this.annualLabel,
    required this.onChanged,
  });

  final SubscriptionUpgradeBillingCycle value;
  final String monthlyLabel;
  final String annualLabel;
  final ValueChanged<SubscriptionUpgradeBillingCycle> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final BorderRadius radius = BorderRadius.circular(theme.radius.md);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: radius,
        border: theme.borders.all(),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _BillingCycleOption(
                label: monthlyLabel,
                icon: Icons.calendar_view_month_outlined,
                selected: value == SubscriptionUpgradeBillingCycle.monthly,
                onTap: () => onChanged(SubscriptionUpgradeBillingCycle.monthly),
              ),
            ),
            SizedBox(width: theme.spacing.xs),
            Expanded(
              child: _BillingCycleOption(
                label: annualLabel,
                icon: Icons.calendar_today_outlined,
                selected: value == SubscriptionUpgradeBillingCycle.annual,
                onTap: () => onChanged(SubscriptionUpgradeBillingCycle.annual),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingCycleOption extends StatelessWidget {
  const _BillingCycleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final BorderRadius radius = BorderRadius.circular(theme.radius.sm);
    final Color foreground = selected
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Material(
      color: selected ? colorScheme.primary : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm + 2,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: foreground),
              SizedBox(width: theme.spacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanColumnTile extends StatelessWidget {
  const _PlanColumnTile({
    required this.label,
    required this.tierCode,
    required this.priceLabel,
    required this.cycleLabel,
    required this.selected,
    required this.isCurrentPlan,
    required this.currentPlanLabel,
    required this.onTap,
  });

  final String label;
  final String? tierCode;
  final String priceLabel;
  final String cycleLabel;
  final bool selected;
  final bool isCurrentPlan;
  final String currentPlanLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.resolve(
      theme,
      tierCode ?? label,
    );
    final BorderRadius radius = BorderRadius.circular(theme.radius.lg);
    final Color fill = selected
        ? Color.alphaBlend(
            planTheme.foreground.withValues(alpha: 0.16),
            planTheme.background,
          )
        : planTheme.background;
    final Color borderColor = selected
        ? planTheme.foreground
        : planTheme.border;

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: theme.borders.side(color: borderColor, width: selected ? 2 : 1.25),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(height: 5, color: planTheme.foreground),
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.md,
                theme.spacing.sm + 2,
                theme.spacing.md,
                theme.spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: AppFontWeight.emphasis,
                            color: planTheme.foreground,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: theme.spacing.xs),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: selected
                            ? planTheme.foreground
                            : planTheme.foreground.withValues(alpha: 0),
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Text(
                    priceLabel,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                      color: planTheme.foreground,
                      height: 1.1,
                      fontSize: 22,
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    cycleLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: AppFontWeight.medium,
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  // Reserved so every card in a row shares one height.
                  SizedBox(
                    height: 24,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Visibility(
                        visible: isCurrentPlan,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: theme.spacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: planTheme.foreground.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(
                              theme.radius.full,
                            ),
                            border: theme.borders.all(color: planTheme.foreground.withValues(
                                alpha: 0.35,
                              )),
                          ),
                          child: Text(
                            currentPlanLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: planTheme.foreground,
                              fontWeight: AppFontWeight.emphasis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

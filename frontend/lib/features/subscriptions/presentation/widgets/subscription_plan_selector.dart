import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/permissions/commercial_module_tiers.dart';
import 'package:hosspi_hms/core/subscriptions/subscription_plan_theme.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_plan_comparison.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_radio_group.dart';
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
  final String? emptyTitle;
  final String? emptyMessage;

  static const double _compactColumnWidth = 148;
  static const double _wideColumnWidth = 168;

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
        AppRadioGroup<SubscriptionUpgradeBillingCycle>(
          value: billingCycle,
          dense: true,
          layout: AppRadioGroupLayout.horizontal,
          presentation: AppRadioGroupPresentation.borderless,
          options: <AppRadioOption<SubscriptionUpgradeBillingCycle>>[
            AppRadioOption<SubscriptionUpgradeBillingCycle>(
              value: SubscriptionUpgradeBillingCycle.monthly,
              label: monthlyLabel,
            ),
            AppRadioOption<SubscriptionUpgradeBillingCycle>(
              value: SubscriptionUpgradeBillingCycle.annual,
              label: annualLabel,
            ),
          ],
          onChanged: (SubscriptionUpgradeBillingCycle? value) {
            if (value != null) {
              onBillingCycleChanged(value);
            }
          },
        ),
        SizedBox(height: theme.spacing.sm),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final bool compact = maxWidth < AppBreakpoints.md;
            final double columnWidth = compact
                ? _compactColumnWidth
                : _wideColumnWidth;
            final double gap = theme.spacing.xs;
            final double minRowWidth =
                ordered.length * columnWidth +
                math.max(0, ordered.length - 1) * gap;
            final bool fillWidth = maxWidth >= minRowWidth;
            final double resolvedWidth = fillWidth
                ? (maxWidth - math.max(0, ordered.length - 1) * gap) /
                      ordered.length
                : columnWidth;

            final Widget row = IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int index = 0; index < ordered.length; index += 1) ...<
                    Widget
                  >[
                    if (index > 0) SizedBox(width: gap),
                    SizedBox(
                      width: resolvedWidth,
                      child: _PlanComparisonColumn(
                        plan: ordered[index],
                        label: planLabelBuilder(ordered[index]),
                        priceLabel: _priceLabel(context, ordered[index]),
                        cycleLabel:
                            billingCycle ==
                                SubscriptionUpgradeBillingCycle.monthly
                            ? monthlyLabel
                            : annualLabel,
                        selected: selectedPlanId == ordered[index].id,
                        isCurrentPlan: ordered[index].id == currentPlanId,
                        currentPlanLabel: currentPlanLabel,
                        onTap: () => onSelected(ordered[index].id),
                      ),
                    ),
                  ],
                ],
              ),
            );

            if (fillWidth) {
              return row;
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
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
      final int leftRank = CommercialModuleTiers.rankOf(a.tierCode);
      final int rightRank = CommercialModuleTiers.rankOf(b.tierCode);
      final int byTier =
          (leftRank < 0 ? 99 : leftRank) - (rightRank < 0 ? 99 : rightRank);
      if (byTier != 0) {
        return byTier;
      }
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

class _PlanComparisonColumn extends StatelessWidget {
  const _PlanComparisonColumn({
    required this.plan,
    required this.label,
    required this.priceLabel,
    required this.cycleLabel,
    required this.selected,
    required this.isCurrentPlan,
    required this.currentPlanLabel,
    required this.onTap,
  });

  final SubscriptionUpgradePlanOption plan;
  final String label;
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
      plan.tierCode ?? label,
    );
    final BorderRadius radius = BorderRadius.circular(theme.radius.md);
    final Color fill = selected
        ? Color.alphaBlend(
            planTheme.foreground.withValues(alpha: 0.12),
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
        side: theme.borders.side(
          color: borderColor,
          weight: selected ? AppBorderWeight.thick : AppBorderWeight.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(height: 3, color: planTheme.foreground),
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.sm,
                theme.spacing.xs + 2,
                theme.spacing.sm,
                theme.spacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: AppFontWeight.emphasis,
                            color: planTheme.foreground,
                            height: 1.15,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: selected
                            ? planTheme.foreground
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                      color: planTheme.foreground,
                      height: 1.05,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    cycleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                  if (isCurrentPlan) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: planTheme.foreground.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(theme.radius.sm),
                      ),
                      child: Text(
                        currentPlanLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: planTheme.foreground,
                          fontWeight: AppFontWeight.emphasis,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: theme.spacing.xs),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: planTheme.border.withValues(alpha: 0.55),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  for (final SubscriptionPlanComparisonFeature feature
                      in SubscriptionPlanComparisonCatalog
                          .features) ...<Widget>[
                    _FeatureRow(
                      feature: feature,
                      plan: plan,
                      accent: planTheme.foreground,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.feature,
    required this.plan,
    required this.accent,
  });

  final SubscriptionPlanComparisonFeature feature;
  final SubscriptionUpgradePlanOption plan;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? limitKey = feature.limitKey;
    final String? moduleSlug = feature.moduleSlug;

    final bool included;
    final String trailing;
    if (limitKey != null) {
      included = true;
      trailing = SubscriptionPlanComparisonCatalog.limitValue(plan, limitKey);
    } else if (moduleSlug != null) {
      included = SubscriptionPlanComparisonCatalog.includesModule(
        plan,
        moduleSlug,
      );
      trailing = included ? 'Yes' : '—';
    } else {
      included = false;
      trailing = '—';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            included ? Icons.check_rounded : Icons.remove,
            size: 14,
            color: included
                ? accent
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
          SizedBox(width: theme.spacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: feature.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: ' · $trailing',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: included
                          ? accent
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: included
                          ? AppFontWeight.emphasis
                          : FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

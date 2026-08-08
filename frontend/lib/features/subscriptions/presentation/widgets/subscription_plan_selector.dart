import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/permissions/commercial_module_tiers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/subscriptions/subscription_plan_theme.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_plan_comparison.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
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
    this.featuresColumnLabel = 'Features',
    this.priceRowLabel = 'Price',
    this.contactUsLabel = 'Contact us',
    this.displayCurrency = subscriptionPlanBaseCurrencyCode,
    this.usdToDisplayRate,
    this.onContactCustomPlan,
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
  final String featuresColumnLabel;
  final String priceRowLabel;
  final String contactUsLabel;

  /// Currency used for the price row (tenant/facility default).
  /// Plan catalog amounts are stored in [subscriptionPlanBaseCurrencyCode].
  final String displayCurrency;

  /// USD → [displayCurrency] rate. Null while loading or when FX fails.
  final double? usdToDisplayRate;
  final VoidCallback? onContactCustomPlan;
  final String Function(SubscriptionUpgradePlanOption plan) planLabelBuilder;
  final ValueChanged<SubscriptionUpgradeBillingCycle> onBillingCycleChanged;
  final ValueChanged<String> onSelected;
  final String? emptyTitle;
  final String? emptyMessage;

  static const double _featureColumnWidth = 132;
  static const double _compactFeatureColumnWidth = 108;
  static const double _planColumnWidth = 112;
  static const double _compactPlanColumnWidth = 96;
  static const double _cardsBreakpointWidth = 640;

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
    if (ordered.isEmpty) {
      return AppMessagePanel(
        title: emptyTitle ?? 'No plans available',
        message:
            emptyMessage ??
            'Commercial plans could not be loaded. Refresh and try again.',
        icon: Icons.inbox_outlined,
        tone: AppWorkspaceStatusTone.warning,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final AppBreakpoint breakpoint = AppBreakpoints.fromWidth(maxWidth);
        final bool useCards =
            breakpoint.isMobile || maxWidth < _cardsBreakpointWidth;
        final bool compactTable = !useCards && maxWidth < AppBreakpoints.lg;
        final double featureWidth = compactTable
            ? _compactFeatureColumnWidth
            : _featureColumnWidth;
        final double basePlanWidth = compactTable
            ? _compactPlanColumnWidth
            : _planColumnWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppRadioGroup<SubscriptionUpgradeBillingCycle>(
              value: billingCycle,
              dense: true,
              layout: maxWidth < 360
                  ? AppRadioGroupLayout.wrap
                  : AppRadioGroupLayout.horizontal,
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
            if (useCards)
              _PlanCardsList(
                plans: ordered,
                selectedPlanId: selectedPlanId,
                currentPlanId: currentPlanId,
                priceRowLabel: priceRowLabel,
                currentPlanLabel: currentPlanLabel,
                contactUsLabel: contactUsLabel,
                planLabelBuilder: planLabelBuilder,
                priceLabelBuilder: (SubscriptionUpgradePlanOption plan) =>
                    _priceLabel(context, plan),
                onSelected: onSelected,
                onContactCustomPlan: onContactCustomPlan,
              )
            else
              Builder(
                builder: (BuildContext context) {
                  final double minTableWidth =
                      featureWidth + ordered.length * basePlanWidth;
                  final bool fillWidth = maxWidth >= minTableWidth;
                  final double planWidth = fillWidth
                      ? math.max(
                          basePlanWidth,
                          (maxWidth - featureWidth) / ordered.length,
                        )
                      : basePlanWidth;

                  final Widget table = _PlanComparisonTable(
                    plans: ordered,
                    selectedPlanId: selectedPlanId,
                    currentPlanId: currentPlanId,
                    featuresColumnLabel: featuresColumnLabel,
                    priceRowLabel: priceRowLabel,
                    currentPlanLabel: currentPlanLabel,
                    contactUsLabel: contactUsLabel,
                    featureColumnWidth: featureWidth,
                    planColumnWidth: planWidth,
                    compact: compactTable,
                    planLabelBuilder: planLabelBuilder,
                    priceLabelBuilder: (SubscriptionUpgradePlanOption plan) =>
                        _priceLabel(context, plan),
                    onSelected: onSelected,
                    onContactCustomPlan: onContactCustomPlan,
                  );

                  if (fillWidth) {
                    return table;
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: minTableWidth, child: table),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  List<SubscriptionUpgradePlanOption> _sortedPlans() {
    final List<SubscriptionUpgradePlanOption> ordered = plans
        .where(
          (SubscriptionUpgradePlanOption plan) => !plan.isDeveloperPlan,
        )
        .toList(growable: true);
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
    final double? usdAmount = plan.priceFor(billingCycle);
    if (usdAmount == null) {
      return '—';
    }

    final String currency = displayCurrency.trim().toUpperCase();
    final double? rate = usdToDisplayRate;
    final bool useDisplayCurrency =
        currency.isNotEmpty &&
        currency != subscriptionPlanBaseCurrencyCode &&
        rate != null;

    if (!useDisplayCurrency) {
      return AppFormatters.currency(
        usdAmount,
        Localizations.localeOf(context),
        currencyCode: subscriptionPlanBaseCurrencyCode,
        decimalDigits: decimalDigitsForCurrency(
          subscriptionPlanBaseCurrencyCode,
        ),
      );
    }

    final double converted = roundConvertedAmount(usdAmount * rate, currency);
    return AppFormatters.currency(
      converted,
      Localizations.localeOf(context),
      currencyCode: currency,
      decimalDigits: decimalDigitsForCurrency(currency),
    );
  }
}

class _PlanCardsList extends StatelessWidget {
  const _PlanCardsList({
    required this.plans,
    required this.selectedPlanId,
    required this.currentPlanId,
    required this.priceRowLabel,
    required this.currentPlanLabel,
    required this.contactUsLabel,
    required this.planLabelBuilder,
    required this.priceLabelBuilder,
    required this.onSelected,
    this.onContactCustomPlan,
  });

  final List<SubscriptionUpgradePlanOption> plans;
  final String? selectedPlanId;
  final String? currentPlanId;
  final String priceRowLabel;
  final String currentPlanLabel;
  final String contactUsLabel;
  final String Function(SubscriptionUpgradePlanOption plan) planLabelBuilder;
  final String Function(SubscriptionUpgradePlanOption plan) priceLabelBuilder;
  final ValueChanged<String> onSelected;
  final VoidCallback? onContactCustomPlan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < plans.length; index += 1) ...<Widget>[
          if (index > 0) SizedBox(height: theme.spacing.sm),
          _PlanCard(
            plan: plans[index],
            label: planLabelBuilder(plans[index]),
            priceLabel: priceLabelBuilder(plans[index]),
            priceRowLabel: priceRowLabel,
            selected: selectedPlanId == plans[index].id,
            isCurrentPlan: plans[index].id == currentPlanId,
            currentPlanLabel: currentPlanLabel,
            contactUsLabel: contactUsLabel,
            onTap: () => onSelected(plans[index].id),
            onContactUs: plans[index].isCustomPlan ? onContactCustomPlan : null,
          ),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.label,
    required this.priceLabel,
    required this.priceRowLabel,
    required this.selected,
    required this.isCurrentPlan,
    required this.currentPlanLabel,
    required this.contactUsLabel,
    required this.onTap,
    this.onContactUs,
  });

  final SubscriptionUpgradePlanOption plan;
  final String label;
  final String priceLabel;
  final String priceRowLabel;
  final bool selected;
  final bool isCurrentPlan;
  final String currentPlanLabel;
  final String contactUsLabel;
  final VoidCallback onTap;
  final VoidCallback? onContactUs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.resolve(
      theme,
      plan.tierCode ?? label,
    );
    final Color fill = isCurrentPlan
        ? Color.alphaBlend(
            planTheme.foreground.withValues(alpha: 0.22),
            planTheme.background,
          )
        : selected
        ? Color.alphaBlend(
            planTheme.foreground.withValues(alpha: 0.12),
            planTheme.background,
          )
        : theme.colorScheme.surface;

    final List<SubscriptionPlanComparisonFeature> limitFeatures =
        SubscriptionPlanComparisonCatalog.features
            .where(
              (SubscriptionPlanComparisonFeature feature) =>
                  feature.limitKey != null,
            )
            .toList(growable: false);
    final List<SubscriptionPlanComparisonFeature> moduleFeatures =
        SubscriptionPlanComparisonCatalog.features
            .where(
              (SubscriptionPlanComparisonFeature feature) =>
                  feature.moduleSlug != null,
            )
            .toList(growable: false);

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radius.md),
        side: BorderSide(
          color: selected || isCurrentPlan
              ? planTheme.foreground
              : theme.colorScheme.outlineVariant,
          width: selected || isCurrentPlan ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected
                        ? planTheme.foreground
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: AppFontWeight.emphasis,
                            color: planTheme.foreground,
                          ),
                        ),
                        if (isCurrentPlan) ...<Widget>[
                          SizedBox(height: theme.spacing.xs / 2),
                          Text(
                            currentPlanLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: planTheme.foreground,
                              fontWeight: AppFontWeight.emphasis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          priceRowLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          priceLabel,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: AppFontWeight.emphasis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (plan.isCustomPlan && onContactUs != null) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: contactUsLabel,
                    dense: true,
                    variant: AppButtonVariant.secondary,
                    leadingIcon: Icons.support_agent_outlined,
                    onPressed: onContactUs,
                  ),
                ),
              ],
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  for (final SubscriptionPlanComparisonFeature feature
                      in limitFeatures)
                    _LimitChip(
                      label: feature.label,
                      value: SubscriptionPlanComparisonCatalog.limitValue(
                        plan,
                        feature.limitKey!,
                      ),
                      accent: planTheme.foreground,
                    ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final int columns = constraints.maxWidth >= 420
                      ? 2
                      : 1;
                  if (columns == 1) {
                    return Column(
                      children: <Widget>[
                        for (
                          int i = 0;
                          i < moduleFeatures.length;
                          i += 1
                        ) ...<Widget>[
                          if (i > 0) SizedBox(height: theme.spacing.xs),
                          _ModuleFeatureRow(
                            feature: moduleFeatures[i],
                            plan: plan,
                          ),
                        ],
                      ],
                    );
                  }

                  final List<Widget> left = <Widget>[];
                  final List<Widget> right = <Widget>[];
                  for (int i = 0; i < moduleFeatures.length; i += 1) {
                    final Widget row = _ModuleFeatureRow(
                      feature: moduleFeatures[i],
                      plan: plan,
                    );
                    if (i.isEven) {
                      left.add(row);
                    } else {
                      right.add(row);
                    }
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < left.length; i += 1) ...<Widget>[
                              if (i > 0) SizedBox(height: theme.spacing.xs),
                              left[i],
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: theme.spacing.sm),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < right.length; i += 1) ...<
                              Widget
                            >[
                              if (i > 0) SizedBox(height: theme.spacing.xs),
                              right[i],
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label · ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: AppFontWeight.emphasis,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleFeatureRow extends StatelessWidget {
  const _ModuleFeatureRow({required this.feature, required this.plan});

  final SubscriptionPlanComparisonFeature feature;
  final SubscriptionUpgradePlanOption plan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.resolve(
      theme,
      plan.tierCode ?? plan.label,
    );
    final String? moduleSlug = feature.moduleSlug;
    final bool included =
        moduleSlug != null &&
        SubscriptionPlanComparisonCatalog.includesModule(plan, moduleSlug);

    return Row(
      children: <Widget>[
        Icon(
          included ? Icons.check_rounded : Icons.close_rounded,
          size: 18,
          color: included
              ? planTheme.foreground
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        SizedBox(width: theme.spacing.xs),
        Expanded(
          child: Text(
            feature.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: included
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanComparisonTable extends StatelessWidget {
  const _PlanComparisonTable({
    required this.plans,
    required this.selectedPlanId,
    required this.currentPlanId,
    required this.featuresColumnLabel,
    required this.priceRowLabel,
    required this.currentPlanLabel,
    required this.contactUsLabel,
    required this.featureColumnWidth,
    required this.planColumnWidth,
    required this.planLabelBuilder,
    required this.priceLabelBuilder,
    required this.onSelected,
    this.compact = false,
    this.onContactCustomPlan,
  });

  final List<SubscriptionUpgradePlanOption> plans;
  final String? selectedPlanId;
  final String? currentPlanId;
  final String featuresColumnLabel;
  final String priceRowLabel;
  final String currentPlanLabel;
  final String contactUsLabel;
  final double featureColumnWidth;
  final double planColumnWidth;
  final bool compact;
  final String Function(SubscriptionUpgradePlanOption plan) planLabelBuilder;
  final String Function(SubscriptionUpgradePlanOption plan) priceLabelBuilder;
  final ValueChanged<String> onSelected;
  final VoidCallback? onContactCustomPlan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius radius = BorderRadius.circular(theme.radius.md);

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: theme.borders.side(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeaderRow(
            plans: plans,
            selectedPlanId: selectedPlanId,
            currentPlanId: currentPlanId,
            featuresColumnLabel: featuresColumnLabel,
            currentPlanLabel: currentPlanLabel,
            featureColumnWidth: featureColumnWidth,
            planColumnWidth: planColumnWidth,
            compact: compact,
            planLabelBuilder: planLabelBuilder,
            onSelected: onSelected,
          ),
          _DataRow(
            label: priceRowLabel,
            featureColumnWidth: featureColumnWidth,
            planColumnWidth: planColumnWidth,
            plans: plans,
            selectedPlanId: selectedPlanId,
            currentPlanId: currentPlanId,
            emphasize: true,
            compact: compact,
            cellBuilder: (SubscriptionUpgradePlanOption plan) => _PriceCell(
              priceLabel: priceLabelBuilder(plan),
              isCustomPlan: plan.isCustomPlan,
              contactUsLabel: contactUsLabel,
              compact: compact,
              onContactUs: plan.isCustomPlan ? onContactCustomPlan : null,
            ),
            onSelected: onSelected,
          ),
          for (
            int index = 0;
            index < SubscriptionPlanComparisonCatalog.features.length;
            index += 1
          )
            _DataRow(
              label: SubscriptionPlanComparisonCatalog.features[index].label,
              featureColumnWidth: featureColumnWidth,
              planColumnWidth: planColumnWidth,
              plans: plans,
              selectedPlanId: selectedPlanId,
              currentPlanId: currentPlanId,
              showTopBorder: true,
              compact: compact,
              cellBuilder: (SubscriptionUpgradePlanOption plan) => _FeatureCell(
                feature: SubscriptionPlanComparisonCatalog.features[index],
                plan: plan,
              ),
              onSelected: onSelected,
            ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.plans,
    required this.selectedPlanId,
    required this.currentPlanId,
    required this.featuresColumnLabel,
    required this.currentPlanLabel,
    required this.featureColumnWidth,
    required this.planColumnWidth,
    required this.planLabelBuilder,
    required this.onSelected,
    this.compact = false,
  });

  final List<SubscriptionUpgradePlanOption> plans;
  final String? selectedPlanId;
  final String? currentPlanId;
  final String featuresColumnLabel;
  final String currentPlanLabel;
  final double featureColumnWidth;
  final double planColumnWidth;
  final bool compact;
  final String Function(SubscriptionUpgradePlanOption plan) planLabelBuilder;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: featureColumnWidth,
            child: Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? theme.spacing.xs : theme.spacing.sm,
                vertical: theme.spacing.sm,
              ),
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              child: Text(
                featuresColumnLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            ),
          ),
          for (final SubscriptionUpgradePlanOption plan in plans)
            SizedBox(
              width: planColumnWidth,
              child: _PlanHeaderCell(
                plan: plan,
                label: planLabelBuilder(plan),
                selected: selectedPlanId == plan.id,
                isCurrentPlan: plan.id == currentPlanId,
                currentPlanLabel: currentPlanLabel,
                compact: compact,
                onTap: () => onSelected(plan.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanHeaderCell extends StatelessWidget {
  const _PlanHeaderCell({
    required this.plan,
    required this.label,
    required this.selected,
    required this.isCurrentPlan,
    required this.currentPlanLabel,
    required this.onTap,
    this.compact = false,
  });

  final SubscriptionUpgradePlanOption plan;
  final String label;
  final bool selected;
  final bool isCurrentPlan;
  final String currentPlanLabel;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.resolve(
      theme,
      plan.tierCode ?? label,
    );
    final Color fill = isCurrentPlan
        ? Color.alphaBlend(
            planTheme.foreground.withValues(alpha: 0.28),
            planTheme.background,
          )
        : selected
        ? Color.alphaBlend(
            planTheme.foreground.withValues(alpha: 0.16),
            planTheme.background,
          )
        : planTheme.background;

    return Material(
      color: fill,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? theme.spacing.xs / 2 : theme.spacing.xs,
            theme.spacing.sm,
            compact ? theme.spacing.xs / 2 : theme.spacing.xs,
            theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
              bottom: BorderSide(
                color: planTheme.foreground,
                width: isCurrentPlan ? 3 : 2,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: compact ? 16 : 18,
                color: selected
                    ? planTheme.foreground
                    : theme.colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                  color: planTheme.foreground,
                  height: 1.15,
                  fontSize: compact ? 12 : null,
                ),
              ),
              if (isCurrentPlan) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                Text(
                  currentPlanLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: planTheme.foreground,
                    fontWeight: AppFontWeight.emphasis,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.featureColumnWidth,
    required this.planColumnWidth,
    required this.plans,
    required this.selectedPlanId,
    required this.currentPlanId,
    required this.cellBuilder,
    required this.onSelected,
    this.emphasize = false,
    this.showTopBorder = false,
    this.compact = false,
  });

  final String label;
  final double featureColumnWidth;
  final double planColumnWidth;
  final List<SubscriptionUpgradePlanOption> plans;
  final String? selectedPlanId;
  final String? currentPlanId;
  final Widget Function(SubscriptionUpgradePlanOption plan) cellBuilder;
  final ValueChanged<String> onSelected;
  final bool emphasize;
  final bool showTopBorder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color divider = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.7,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: featureColumnWidth,
            child: Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? theme.spacing.xs : theme.spacing.sm,
                vertical: theme.spacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: emphasize
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      )
                    : null,
                border: showTopBorder
                    ? Border(top: BorderSide(color: divider))
                    : null,
              ),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: emphasize
                      ? AppFontWeight.emphasis
                      : FontWeight.w500,
                  fontSize: compact ? 12 : null,
                ),
              ),
            ),
          ),
          for (final SubscriptionUpgradePlanOption plan in plans)
            SizedBox(
              width: planColumnWidth,
              child: Material(
                color: _cellBackground(theme, plan),
                child: InkWell(
                  onTap: () => onSelected(plan.id),
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact
                          ? theme.spacing.xs / 2
                          : theme.spacing.xs,
                      vertical: theme.spacing.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: divider),
                        top: showTopBorder
                            ? BorderSide(color: divider)
                            : BorderSide.none,
                      ),
                    ),
                    child: cellBuilder(plan),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color? _cellBackground(ThemeData theme, SubscriptionUpgradePlanOption plan) {
    final bool selected = selectedPlanId == plan.id;
    final bool isCurrent = plan.id == currentPlanId;
    if (!selected && !isCurrent) {
      return null;
    }
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.resolve(
      theme,
      plan.tierCode ?? plan.label,
    );
    if (isCurrent) {
      return planTheme.rowTint;
    }
    return Color.alphaBlend(
      planTheme.foreground.withValues(alpha: 0.06),
      theme.colorScheme.surface,
    );
  }
}

class _PriceCell extends StatelessWidget {
  const _PriceCell({
    required this.priceLabel,
    required this.isCustomPlan,
    required this.contactUsLabel,
    this.compact = false,
    this.onContactUs,
  });

  final String priceLabel;
  final bool isCustomPlan;
  final String contactUsLabel;
  final bool compact;
  final VoidCallback? onContactUs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          priceLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: AppFontWeight.emphasis,
            fontSize: compact ? 11 : null,
            height: 1.15,
          ),
        ),
        if (isCustomPlan && onContactUs != null) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          AppButton(
            label: contactUsLabel,
            dense: true,
            variant: AppButtonVariant.secondary,
            leadingIcon: compact ? null : Icons.support_agent_outlined,
            onPressed: onContactUs,
          ),
        ],
      ],
    );
  }
}

class _FeatureCell extends StatelessWidget {
  const _FeatureCell({required this.feature, required this.plan});

  final SubscriptionPlanComparisonFeature feature;
  final SubscriptionUpgradePlanOption plan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.resolve(
      theme,
      plan.tierCode ?? plan.label,
    );
    final String? limitKey = feature.limitKey;
    final String? moduleSlug = feature.moduleSlug;

    if (limitKey != null) {
      return Text(
        SubscriptionPlanComparisonCatalog.limitValue(plan, limitKey),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: AppFontWeight.emphasis,
        ),
      );
    }

    final bool included =
        moduleSlug != null &&
        SubscriptionPlanComparisonCatalog.includesModule(plan, moduleSlug);

    return Icon(
      included ? Icons.check_rounded : Icons.close_rounded,
      size: 18,
      color: included
          ? planTheme.foreground
          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
    );
  }
}

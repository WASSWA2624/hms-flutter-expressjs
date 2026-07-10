import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_board_toggle.dart';

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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (plans.isEmpty) {
      return const SizedBox.shrink();
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
            Align(
              alignment: Alignment.centerLeft,
              child: AppWorkspaceBoardToggle<SubscriptionUpgradeBillingCycle>(
                value: billingCycle,
                segments: <ButtonSegment<SubscriptionUpgradeBillingCycle>>[
                  ButtonSegment<SubscriptionUpgradeBillingCycle>(
                    value: SubscriptionUpgradeBillingCycle.monthly,
                    label: Text(monthlyLabel),
                    icon: const Icon(
                      Icons.calendar_view_month_outlined,
                      size: 18,
                    ),
                  ),
                  ButtonSegment<SubscriptionUpgradeBillingCycle>(
                    value: SubscriptionUpgradeBillingCycle.annual,
                    label: Text(annualLabel),
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                ],
                onChanged: onBillingCycleChanged,
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = _columnCount(constraints.maxWidth, ordered.length);
            final double gap = theme.spacing.sm;
            final double tileWidth =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final SubscriptionUpgradePlanOption plan in ordered)
                  SizedBox(
                    width: tileWidth,
                    child: _PlanColumnTile(
                      label: planLabelBuilder(plan),
                      priceLabel: _priceLabel(context, plan),
                      cycleLabel: billingCycle ==
                              SubscriptionUpgradeBillingCycle.monthly
                          ? monthlyLabel
                          : annualLabel,
                      selected: selectedPlanId == plan.id,
                      isCurrentPlan: plan.id == currentPlanId,
                      currentPlanLabel: currentPlanLabel,
                      onTap: () => onSelected(plan.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<SubscriptionUpgradePlanOption> _sortedPlans() {
    final List<SubscriptionUpgradePlanOption> ordered =
        List<SubscriptionUpgradePlanOption>.of(plans);
    ordered.sort((SubscriptionUpgradePlanOption a, SubscriptionUpgradePlanOption b) {
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
    if (width >= 720) {
      return planCount.clamp(1, 4);
    }
    if (width >= 520) {
      return 2;
    }
    return 1;
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

class _PlanColumnTile extends StatelessWidget {
  const _PlanColumnTile({
    required this.label,
    required this.priceLabel,
    required this.cycleLabel,
    required this.selected,
    required this.isCurrentPlan,
    required this.currentPlanLabel,
    required this.onTap,
  });

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
    final ColorScheme colorScheme = theme.colorScheme;
    final BorderRadius radius = BorderRadius.circular(theme.radius.lg);

    return Material(
      elevation: selected ? 1.5 : 0,
      shadowColor: colorScheme.primary.withValues(alpha: 0.18),
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.42)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 1.75 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
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
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.md),
              Text(
                priceLabel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  height: 1.1,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                cycleLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCurrentPlan) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.sm,
                    vertical: theme.spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(theme.radius.full),
                  ),
                  child: Text(
                    currentPlanLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
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

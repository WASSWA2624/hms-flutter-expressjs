import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
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
    this.labelText,
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
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (plans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (labelText != null && labelText!.trim().isNotEmpty) ...<Widget>[
          Text(
            labelText!,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: AppWorkspaceBoardToggle<SubscriptionUpgradeBillingCycle>(
            value: billingCycle,
            segments: <ButtonSegment<SubscriptionUpgradeBillingCycle>>[
              ButtonSegment<SubscriptionUpgradeBillingCycle>(
                value: SubscriptionUpgradeBillingCycle.monthly,
                label: Text(monthlyLabel),
                icon: const Icon(Icons.calendar_view_month_outlined, size: 18),
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
        SizedBox(height: theme.spacing.md),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = _columnCount(constraints.maxWidth);
            final double gap = theme.spacing.sm;
            final double tileWidth =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final SubscriptionUpgradePlanOption plan in plans)
                  SizedBox(
                    width: tileWidth,
                    child: _PlanColumnTile(
                      label: planLabelBuilder(plan),
                      priceLabel: _priceLabel(context, plan),
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

  int _columnCount(double width) {
    if (width >= 720) {
      return plans.length.clamp(1, 4);
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
    required this.selected,
    required this.isCurrentPlan,
    required this.currentPlanLabel,
    required this.onTap,
  });

  final String label;
  final String priceLabel;
  final bool selected;
  final bool isCurrentPlan;
  final String currentPlanLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final BorderRadius radius = BorderRadius.circular(theme.radius.md);

    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                priceLabel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              if (isCurrentPlan) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                Text(
                  currentPlanLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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

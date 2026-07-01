import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';

class SubscriptionPlanSelector extends StatelessWidget {
  const SubscriptionPlanSelector({
    required this.plans,
    required this.selectedPlanId,
    required this.currentPlanId,
    required this.labelText,
    required this.planLabelBuilder,
    required this.onSelected,
    super.key,
  });

  final List<SubscriptionUpgradePlanOption> plans;
  final String? selectedPlanId;
  final String? currentPlanId;
  final String labelText;
  final String Function(SubscriptionUpgradePlanOption plan) planLabelBuilder;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    if (plans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          labelText,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final SubscriptionUpgradePlanOption plan in plans)
                Padding(
                  padding: EdgeInsets.only(right: theme.spacing.xs),
                  child: _PlanToggleChip(
                    label: planLabelBuilder(plan),
                    selected: selectedPlanId == plan.id,
                    isCurrentPlan: plan.id == currentPlanId,
                    colorScheme: colorScheme,
                    theme: theme,
                    onTap: () => onSelected(plan.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanToggleChip extends StatelessWidget {
  const _PlanToggleChip({
    required this.label,
    required this.selected,
    required this.isCurrentPlan,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isCurrentPlan;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = colorScheme.primary;
    final Color labelColor = selected ? accent : colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
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
                isCurrentPlan ? Icons.autorenew : Icons.trending_up,
                size: 18,
                color: selected ? accent : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: theme.spacing.xs),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: labelColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  decoration: selected ? TextDecoration.underline : null,
                  decorationColor: accent,
                  decorationThickness: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_methods.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

class SubscriptionPaymentMethodSelector extends StatelessWidget {
  const SubscriptionPaymentMethodSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final SubscriptionPaymentMethodId selected;
  final ValueChanged<SubscriptionPaymentMethodId> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final SubscriptionPaymentMethodDefinition definition
              in subscriptionPaymentMethods)
            Padding(
              padding: EdgeInsets.only(right: theme.spacing.md),
              child: _PaymentMethodChip(
                definition: definition,
                label: subscriptionPaymentMethodLabel(l10n, definition.id),
                selected: selected == definition.id,
                colorScheme: colorScheme,
                theme: theme,
                onTap: () => onSelected(definition.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({
    required this.definition,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
    required this.theme,
  });

  final SubscriptionPaymentMethodDefinition definition;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color accent = definition.color;
    final Color iconColor = selected ? accent : colorScheme.onSurfaceVariant;
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
            horizontal: theme.spacing.xs,
            vertical: theme.spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(definition.icon, color: iconColor, size: 20),
              SizedBox(width: theme.spacing.xs),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
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

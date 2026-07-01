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
    final AppLocalizations l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 520 ? 3 : 2;
        final double itemWidth = (width - theme.spacing.sm * (columns - 1)) / columns;

        return Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            for (final SubscriptionPaymentMethodDefinition definition
                in subscriptionPaymentMethods)
              SizedBox(
                width: itemWidth,
                child: _PaymentMethodCard(
                  definition: definition,
                  label: subscriptionPaymentMethodLabel(l10n, definition.id),
                  selected: selected == definition.id,
                  onTap: () => onSelected(definition.id),
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
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
    final Color background = selected
        ? accent.withValues(alpha: 0.12)
        : colorScheme.surfaceContainerHighest;
    final Color border = selected ? accent : colorScheme.outlineVariant;
    final Color iconColor = selected ? accent : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radius.md),
          side: BorderSide(color: border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(theme.radius.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(definition.icon, color: iconColor, size: 28),
                SizedBox(height: theme.spacing.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? accent : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

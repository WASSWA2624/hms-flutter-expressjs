import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_methods.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_choice_tile.dart';

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
    final AppLocalizations l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 640
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final double gap = theme.spacing.sm;
        final double tileWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final SubscriptionPaymentMethodDefinition definition
                in subscriptionPaymentMethods)
              SizedBox(
                width: tileWidth,
                child: AppChoiceTile(
                  label: subscriptionPaymentMethodLabel(l10n, definition.id),
                  icon: definition.icon,
                  accentColor: definition.color,
                  selected: selected == definition.id,
                  onTap: () => onSelected(definition.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

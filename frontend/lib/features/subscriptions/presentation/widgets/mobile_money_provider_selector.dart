import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_methods.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

class MobileMoneyProviderSelector extends StatelessWidget {
  const MobileMoneyProviderSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final MobileMoneyProviderId selected;
  final ValueChanged<MobileMoneyProviderId> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final MobileMoneyProviderId provider in MobileMoneyProviderId.values)
            Padding(
              padding: EdgeInsets.only(right: theme.spacing.sm),
              child: _MobileMoneyProviderChip(
                provider: provider,
                label: mobileMoneyProviderLabel(l10n, provider),
                selected: selected == provider,
                colorScheme: colorScheme,
                theme: theme,
                onTap: () => onSelected(provider),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileMoneyProviderChip extends StatelessWidget {
  const _MobileMoneyProviderChip({
    required this.provider,
    required this.label,
    required this.selected,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  final MobileMoneyProviderId provider;
  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _MobileMoneyBrand brand = _mobileMoneyBrand(provider);
    final Color border = selected ? brand.accent : colorScheme.outlineVariant;
    final Color background = selected
        ? brand.accent.withValues(alpha: 0.12)
        : colorScheme.surfaceContainerHighest;

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
              vertical: theme.spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _MobileMoneyProviderLogo(provider: provider, size: 28),
                SizedBox(width: theme.spacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? brand.accent : colorScheme.onSurface,
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

class _MobileMoneyProviderLogo extends StatelessWidget {
  const _MobileMoneyProviderLogo({required this.provider, required this.size});

  final MobileMoneyProviderId provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final _MobileMoneyBrand brand = _mobileMoneyBrand(provider);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brand.accent,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Text(
        brand.initials,
        style: TextStyle(
          color: brand.onAccent,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _MobileMoneyBrand {
  const _MobileMoneyBrand({
    required this.initials,
    required this.accent,
    required this.onAccent,
  });

  final String initials;
  final Color accent;
  final Color onAccent;
}

_MobileMoneyBrand _mobileMoneyBrand(MobileMoneyProviderId provider) {
  return switch (provider) {
    MobileMoneyProviderId.mtn => const _MobileMoneyBrand(
      initials: 'MTN',
      accent: Color(0xFFFFCC00),
      onAccent: Color(0xFF1A1A1A),
    ),
    MobileMoneyProviderId.airtel => const _MobileMoneyBrand(
      initials: 'AT',
      accent: Color(0xFFE40000),
      onAccent: Colors.white,
    ),
    MobileMoneyProviderId.mpesa => const _MobileMoneyBrand(
      initials: 'M',
      accent: Color(0xFF43B02A),
      onAccent: Colors.white,
    ),
    MobileMoneyProviderId.vodacom => const _MobileMoneyBrand(
      initials: 'V',
      accent: Color(0xFFE60000),
      onAccent: Colors.white,
    ),
    MobileMoneyProviderId.tigo => const _MobileMoneyBrand(
      initials: 'TG',
      accent: Color(0xFF00377B),
      onAccent: Colors.white,
    ),
    MobileMoneyProviderId.orange => const _MobileMoneyBrand(
      initials: 'OR',
      accent: Color(0xFFFF7900),
      onAccent: Colors.white,
    ),
    MobileMoneyProviderId.zamtel => const _MobileMoneyBrand(
      initials: 'ZT',
      accent: Color(0xFF00A651),
      onAccent: Colors.white,
    ),
    MobileMoneyProviderId.government => const _MobileMoneyBrand(
      initials: 'GOV',
      accent: Color(0xFF334155),
      onAccent: Colors.white,
    ),
  };
}

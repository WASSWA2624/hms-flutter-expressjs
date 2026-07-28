import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_layout.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

class DashboardMetricStrip extends StatelessWidget {
  const DashboardMetricStrip({
    required this.cards,
    this.maxCards = 4,
    this.compact = false,
    super.key,
  });

  final List<DashboardMetricCardData> cards;
  final int maxCards;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<DashboardMetricCardData> visibleCards = cards
        .take(maxCards)
        .toList(growable: false);

    if (visibleCards.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ThemeData theme = Theme.of(context);
        final double gap = theme.spacing.sm;
        final bool wide = constraints.maxWidth >= AppBreakpoints.md;
        final List<Widget> cardWidgets = <Widget>[
          for (final DashboardMetricCardData card in visibleCards)
            _DashboardMetricCard(card: card, compact: compact || !wide),
        ];

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (
                int index = 0;
                index < cardWidgets.length;
                index += 1
              ) ...<Widget>[
                if (index > 0) SizedBox(width: gap),
                Expanded(child: cardWidgets[index]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (
              int index = 0;
              index < cardWidgets.length;
              index += 1
            ) ...<Widget>[
              if (index > 0) SizedBox(height: gap),
              cardWidgets[index],
            ],
          ],
        );
      },
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({required this.card, this.compact = false});

  final DashboardMetricCardData card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isActionable = card.onTap != null;
    final double iconBox = compact ? 28 : 32;
    final double iconGlyph = compact ? 16 : 18;

    final Widget cardBody = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? theme.spacing.sm : theme.spacing.md,
        vertical: compact ? theme.spacing.sm : theme.spacing.sm + 2,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: iconBox,
            height: iconBox,
            alignment: Alignment.center,
            decoration: dashboardMetricIconDecoration(theme, card.accent),
            child: Icon(card.icon, color: card.accent, size: iconGlyph),
          ),
          SizedBox(width: theme.spacing.sm),
          Text(
            card.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(
                      color: card.accent,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      letterSpacing: -0.3,
                    ),
          ),
          SizedBox(width: theme.spacing.xs),
          Expanded(
            child: Text(
              card.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ),
          if (isActionable) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ],
        ],
      ),
    );

    final BoxDecoration decoration = dashboardMetricCardDecoration(
      theme,
      colorScheme,
      card.accent,
    );

    return Semantics(
      button: isActionable,
      label: card.semanticsLabel,
      child: isActionable
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: card.onTap,
                borderRadius: BorderRadius.circular(theme.radius.lg),
                child: Ink(decoration: decoration, child: cardBody),
              ),
            )
          : DecoratedBox(decoration: decoration, child: cardBody),
    );
  }
}

import 'dart:math' as math;

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
        final int columns = dashboardMetricColumnCount(
          constraints.maxWidth,
          visibleCards.length,
        );
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        final bool singleRow = columns == visibleCards.length;
        final List<Widget> cardWidgets = <Widget>[
          for (final DashboardMetricCardData card in visibleCards)
            SizedBox(
              width: singleRow ? null : math.max(0, width),
              child: _DashboardMetricCard(
                card: card,
                compact:
                    compact || constraints.maxWidth < AppBreakpoints.md,
              ),
            ),
        ];

        if (singleRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int index = 0; index < cardWidgets.length; index += 1) ...<Widget>[
                if (index > 0) SizedBox(width: gap),
                Expanded(child: cardWidgets[index]),
              ],
            ],
          );
        }

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cardWidgets,
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
    final double iconSize = compact ? 28 : 32;

    final Widget cardBody = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? theme.spacing.sm : theme.spacing.md,
        vertical: compact ? theme.spacing.sm : theme.spacing.sm + 2,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: card.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(theme.radius.md),
            ),
            child: Icon(card.icon, color: card.accent, size: 18),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  card.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                    color: card.accent,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  card.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isActionable) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: isActionable,
      label: card.semanticsLabel,
      child: isActionable
          ? Material(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(theme.radius.lg),
              child: InkWell(
                onTap: card.onTap,
                borderRadius: BorderRadius.circular(theme.radius.lg),
                child: DecoratedBox(
                  decoration: _metricCardDecoration(theme, colorScheme),
                  child: cardBody,
                ),
              ),
            )
          : DecoratedBox(
              decoration: _metricCardDecoration(theme, colorScheme),
              child: cardBody,
            ),
    );
  }
}

BoxDecoration _metricCardDecoration(ThemeData theme, ColorScheme colorScheme) {
  return BoxDecoration(
    color: colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(theme.radius.lg),
    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
    ),
  );
}

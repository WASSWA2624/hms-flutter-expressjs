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
    final ThemeData theme = Theme.of(context);
    final List<DashboardMetricCardData> visibleCards = cards
        .take(maxCards)
        .toList(growable: false);

    if (visibleCards.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = theme.spacing.sm;
        final int columns = dashboardMetricColumnCount(
          constraints.maxWidth,
          visibleCards.length,
        );
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final DashboardMetricCardData card in visibleCards)
              SizedBox(
                width: math.max(0, width),
                child: _DashboardMetricCard(
                  card: card,
                  compact:
                      compact || constraints.maxWidth < AppBreakpoints.md,
                ),
              ),
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
    final double iconSize = compact ? 32 : 38;

    final Widget cardBody = Padding(
      padding: EdgeInsets.all(compact ? theme.spacing.sm : theme.spacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: card.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(theme.radius.md),
            ),
            child: Icon(card.icon, color: card.accent, size: 20),
          ),
          SizedBox(width: theme.spacing.sm),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isActionable) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            Icon(
              Icons.chevron_right,
              size: 18,
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
              color: colorScheme.surface,
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
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(theme.radius.lg),
    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: 0.8),
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

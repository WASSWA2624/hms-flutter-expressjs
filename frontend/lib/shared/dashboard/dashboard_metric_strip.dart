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
            crossAxisAlignment: CrossAxisAlignment.start,
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

  /// Fixed height so the value region can expand and auto-fit type.
  static const double _compactHeight = 96;
  static const double _regularHeight = 112;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isActionable = card.onTap != null;
    final double iconBox = compact ? 28 : 32;
    final double iconGlyph = compact ? 16 : 18;
    final double cardHeight = compact ? _compactHeight : _regularHeight;
    const TextHeightBehavior tightTextHeight = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    );

    // Cap at title size; FittedBox only scales down for long values.
    final TextStyle valueStyle =
        (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)!
            .copyWith(
              color: card.accent,
              fontWeight: AppFontWeight.emphasis,
              height: 1.1,
              letterSpacing: -0.2,
              leadingDistribution: TextLeadingDistribution.even,
            );
    final TextStyle? labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: AppFontWeight.emphasis,
      height: 1.2,
      leadingDistribution: TextLeadingDistribution.even,
    );

    final Widget cardBody = SizedBox(
      height: cardHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? theme.spacing.sm : theme.spacing.md,
          vertical: compact ? theme.spacing.sm : theme.spacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: iconBox,
                  height: iconBox,
                  alignment: Alignment.center,
                  decoration: dashboardMetricIconDecoration(theme, card.accent),
                  child: Icon(card.icon, color: card.accent, size: iconGlyph),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(
                    card.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textHeightBehavior: tightTextHeight,
                    style: labelStyle,
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
            SizedBox(height: theme.spacing.xs),
            // Value keeps remaining width; shrinks only when text overflows.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    card.value,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    textHeightBehavior: tightTextHeight,
                    style: valueStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final BoxDecoration decoration = dashboardMetricCardDecoration(
      theme,
      colorScheme,
      card.accent,
    );
    final BorderRadius borderRadius = BorderRadius.circular(theme.radius.lg);

    return Semantics(
      button: isActionable,
      label: card.semanticsLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: card.onTap,
          borderRadius: borderRadius,
          child: Ink(decoration: decoration, child: cardBody),
        ),
      ),
    );
  }
}

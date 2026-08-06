import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
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

  /// Columns per row: 1 on mobile, 3 on tablet, 5 on desktop.
  static int columnsForWidth(double width) =>
      dashboardMetricColumnsForWidth(width);

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
        // Prefer the wider of content vs viewport so a desktop shell with a
        // nav rail still gets 5 columns (content alone often sits under xl).
        final double constraintWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0;
        final double layoutWidth = math.max(
          constraintWidth,
          MediaQuery.sizeOf(context).width,
        );
        final int columns = columnsForWidth(layoutWidth);
        final double rowWidth = constraintWidth > 0
            ? constraintWidth
            : layoutWidth;
        final bool useCompact = compact || columns == 1;
        final double cardWidth = columns <= 1
            ? rowWidth
            : (rowWidth - gap * (columns - 1)) / columns;
        final double uniformHeight = visibleCards
            .map(
              (DashboardMetricCardData card) =>
                  _DashboardMetricCard.measureHeight(
                    context: context,
                    card: card,
                    maxWidth: cardWidth,
                    compact: useCompact,
                  ),
            )
            .fold<double>(0, math.max);

        final List<Widget> rows = <Widget>[];
        for (
          int start = 0;
          start < visibleCards.length;
          start += columns
        ) {
          final int end = math.min(start + columns, visibleCards.length);
          final List<DashboardMetricCardData> rowCards = visibleCards.sublist(
            start,
            end,
          );
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: gap));
          }
          rows.add(
            _MetricStripRow(
              cards: rowCards,
              cardWidth: cardWidth,
              cardHeight: uniformHeight,
              gap: gap,
              compact: useCompact,
              stretchSingleColumn: columns == 1,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }
}

class _MetricStripRow extends StatelessWidget {
  const _MetricStripRow({
    required this.cards,
    required this.cardWidth,
    required this.cardHeight,
    required this.gap,
    required this.compact,
    required this.stretchSingleColumn,
  });

  final List<DashboardMetricCardData> cards;
  final double cardWidth;
  final double cardHeight;
  final double gap;
  final bool compact;
  final bool stretchSingleColumn;

  @override
  Widget build(BuildContext context) {
    if (stretchSingleColumn) {
      return _DashboardMetricCard(
        card: cards.first,
        compact: compact,
        height: cardHeight,
      );
    }

    return SizedBox(
      height: cardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int index = 0; index < cards.length; index += 1) ...<Widget>[
            if (index > 0) SizedBox(width: gap),
            SizedBox(
              width: cardWidth,
              child: _DashboardMetricCard(
                card: cards[index],
                compact: compact,
                height: cardHeight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.card,
    this.compact = false,
    this.height,
  });

  final DashboardMetricCardData card;
  final bool compact;
  final double? height;

  /// Enough lines for typical KPI titles (e.g. "Total sales (last 7 days)").
  static const int _labelMaxLines = 2;

  static TextStyle _valueStyle(ThemeData theme, Color accent, bool compact) {
    return (compact ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall)!
        .copyWith(
          color: accent,
          fontWeight: AppFontWeight.strong,
          height: 1.05,
          letterSpacing: -0.2,
          leadingDistribution: TextLeadingDistribution.even,
        );
  }

  static TextStyle? _labelStyle(ThemeData theme, ColorScheme colorScheme) {
    return theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: AppFontWeight.emphasis,
      height: 1.15,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static double _horizontalPad(ThemeData theme, bool compact) =>
      compact ? theme.spacing.sm : theme.spacing.md;

  static double _verticalPad(ThemeData theme) => theme.spacing.sm;

  static double _iconBox(bool compact) => compact ? 28 : 32;

  /// Minimum height that fits [card] at [maxWidth] (icon + wrapped label + value).
  static double measureHeight({
    required BuildContext context,
    required DashboardMetricCardData card,
    required double maxWidth,
    required bool compact,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accent = dashboardResolveMetricAccent(
      theme,
      accent: card.accent,
      tone: card.tone,
      colorCode: card.colorCode,
    );
    final double hPad = _horizontalPad(theme, compact);
    final double vPad = _verticalPad(theme);
    final double iconBox = _iconBox(compact);
    final double gap = theme.spacing.xs;
    final bool isActionable = card.onTap != null;
    final double trailing = isActionable ? theme.spacing.xs + 18 : 0;
    final double labelMaxWidth = math.max(
      0,
      maxWidth - hPad * 2 - iconBox - theme.spacing.sm - trailing,
    );
    final double valueMaxWidth = math.max(0, maxWidth - hPad * 2);

    final TextPainter labelPainter = TextPainter(
      text: TextSpan(text: card.label, style: _labelStyle(theme, colorScheme)),
      maxLines: _labelMaxLines,
      textDirection: Directionality.of(context),
      ellipsis: null,
    )..layout(maxWidth: labelMaxWidth);

    final TextPainter valuePainter = TextPainter(
      text: TextSpan(text: card.value, style: _valueStyle(theme, accent, compact)),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: valueMaxWidth);

    final double headerHeight = math.max(iconBox, labelPainter.height);
    return vPad * 2 + headerHeight + gap + valuePainter.height;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accent = dashboardResolveMetricAccent(
      theme,
      accent: card.accent,
      tone: card.tone,
      colorCode: card.colorCode,
    );
    final bool isActionable = card.onTap != null;
    final double iconBox = _iconBox(compact);
    final double iconGlyph = compact ? 16 : 18;
    final bool pinValueToBottom = height != null;
    const TextHeightBehavior tightTextHeight = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    );

    final TextStyle valueStyle = _valueStyle(theme, accent, compact);
    final TextStyle? labelStyle = _labelStyle(theme, colorScheme);

    final Widget valueText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomCenter,
      child: Text(
        card.value,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
        textHeightBehavior: tightTextHeight,
        style: valueStyle,
      ),
    );

    final Widget cardBody = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPad(theme, compact),
        vertical: _verticalPad(theme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: pinValueToBottom ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: iconBox,
                height: iconBox,
                alignment: Alignment.center,
                decoration: dashboardMetricIconDecoration(theme, accent),
                child: Icon(card.icon, color: accent, size: iconGlyph),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  card.label,
                  maxLines: _labelMaxLines,
                  softWrap: true,
                  overflow: TextOverflow.fade,
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
          if (pinValueToBottom)
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: valueText,
              ),
            )
          else
            Align(
              alignment: Alignment.center,
              child: valueText,
            ),
        ],
      ),
    );

    final BoxDecoration decoration = dashboardMetricCardDecoration(
      theme,
      colorScheme,
      accent,
    );
    final BorderRadius borderRadius = BorderRadius.circular(theme.radius.lg);
    final Widget sizedBody = height == null
        ? cardBody
        : SizedBox(height: height, child: cardBody);

    return Semantics(
      button: isActionable,
      label: card.semanticsLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: card.onTap,
          borderRadius: borderRadius,
          child: Ink(decoration: decoration, child: sizedBody),
        ),
      ),
    );
  }
}

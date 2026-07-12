import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';

/// Faint elevated surface used by dashboard section panels.
Color dashboardSectionBackgroundColor(ColorScheme colorScheme) {
  return colorScheme.surface;
}

/// Subtle border matching metric cards and shortcut tiles.
Color dashboardSectionBorderColor(ColorScheme colorScheme) {
  return colorScheme.outlineVariant.withValues(alpha: 0.35);
}

List<BoxShadow> dashboardSoftShadow(ColorScheme colorScheme) {
  return <BoxShadow>[
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
}

BoxDecoration dashboardSurfaceCardDecoration(
  ThemeData theme,
  ColorScheme colorScheme, {
  Color? backgroundColor,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: backgroundColor ?? dashboardSectionBackgroundColor(colorScheme),
    borderRadius: BorderRadius.circular(theme.radius.xl),
    border: Border.all(
      color: borderColor ?? dashboardSectionBorderColor(colorScheme),
    ),
    boxShadow: dashboardSoftShadow(colorScheme),
  );
}

BoxDecoration dashboardMetricCardDecoration(
  ThemeData theme,
  ColorScheme colorScheme,
  Color accent,
) {
  final Color blend = Color.lerp(accent, colorScheme.primary, 0.35) ?? accent;
  final Color wash = Color.lerp(colorScheme.surface, accent, 0.05) ?? colorScheme.surface;

  return BoxDecoration(
    color: wash,
    borderRadius: BorderRadius.circular(theme.radius.lg),
    border: Border.all(color: accent.withValues(alpha: 0.18)),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: accent.withValues(alpha: 0.08),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
    gradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[
        accent.withValues(alpha: 0.16),
        blend.withValues(alpha: 0.08),
        colorScheme.surface,
      ],
      stops: const <double>[0, 0.42, 1],
    ),
  );
}

BoxDecoration dashboardMetricIconDecoration(ThemeData theme, Color accent) {
  final Color highlight = Color.lerp(accent, Colors.white, 0.25) ?? accent;

  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        highlight.withValues(alpha: 0.28),
        accent.withValues(alpha: 0.14),
      ],
    ),
    borderRadius: BorderRadius.circular(theme.radius.md),
    border: Border.all(color: accent.withValues(alpha: 0.22)),
  );
}

BoxDecoration dashboardAccentIconDecoration(ThemeData theme, Color accent) {
  return dashboardMetricIconDecoration(theme, accent);
}

BoxDecoration dashboardWorklistGroupDecoration(
  ThemeData theme,
  ColorScheme colorScheme,
) {
  return BoxDecoration(
    color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.65),
    borderRadius: BorderRadius.circular(theme.radius.lg),
    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
    ),
  );
}

BoxDecoration dashboardAlertsPanelDecoration(
  ThemeData theme,
  ColorScheme colorScheme,
) {
  final Color accent = theme.statusColors.warning;
  return BoxDecoration(
    color: Color.lerp(colorScheme.surface, accent, 0.06),
    borderRadius: BorderRadius.circular(theme.radius.xl),
    border: Border.all(color: accent.withValues(alpha: 0.22)),
    boxShadow: dashboardSoftShadow(colorScheme),
  );
}

/// Desktop & tablet (≥ md): one column per visible card on a single row.
/// Mobile (< md): one card per row.
int dashboardMetricColumnCount(double maxWidth, int cardCount) {
  final int count = math.max(1, cardCount);
  if (maxWidth >= AppBreakpoints.md) {
    return count;
  }
  return 1;
}

/// Desktop & tablet (≥ md): all actions on one row (max 5).
/// Mobile (< md): one action per row.
int dashboardQuickActionColumnCount(double maxWidth, int actionCount) {
  final int count = math.max(1, math.min(actionCount, 5));
  if (maxWidth >= AppBreakpoints.md) {
    return count;
  }
  return 1;
}

double dashboardQuickActionMinTileWidth(double maxWidth) {
  if (maxWidth >= AppBreakpoints.lg) {
    return 148;
  }
  if (maxWidth >= AppBreakpoints.md) {
    return 136;
  }
  return maxWidth;
}

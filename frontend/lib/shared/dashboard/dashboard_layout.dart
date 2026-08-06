import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Faint elevated surface used by dashboard section panels.
Color dashboardSectionBackgroundColor(ColorScheme colorScheme) {
  return colorScheme.surface;
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
    border: theme.borders.all(
      color: borderColor ?? theme.borders.faint,
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
  final Color wash =
      Color.lerp(colorScheme.surface, accent, 0.05) ?? colorScheme.surface;

  return BoxDecoration(
    color: wash,
    borderRadius: BorderRadius.circular(theme.radius.lg),
    border: theme.borders.all(color: accent.withValues(alpha: 0.18)),
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

/// Resolves metric accent from [colorCode], then [tone], then [accent].
Color dashboardResolveMetricAccent(
  ThemeData theme, {
  Color? accent,
  AppWorkspaceStatusTone? tone,
  String? colorCode,
}) {
  final Color? fromCode = dashboardColorFromCode(theme, colorCode);
  if (fromCode != null) {
    return fromCode;
  }
  if (tone != null) {
    return dashboardToneAccent(theme, tone);
  }
  return accent ?? theme.colorScheme.primary;
}

/// Maps a semantic workspace tone to theme status / surface colors.
Color dashboardToneAccent(ThemeData theme, AppWorkspaceStatusTone tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  final AppStatusColors statusColors = theme.statusColors;
  return switch (tone) {
    AppWorkspaceStatusTone.neutral => colorScheme.onSurfaceVariant,
    AppWorkspaceStatusTone.success => statusColors.success,
    AppWorkspaceStatusTone.warning => statusColors.warning,
    AppWorkspaceStatusTone.error => statusColors.error,
    AppWorkspaceStatusTone.info => statusColors.info,
  };
}

/// Parses a hex (`#RRGGBB` / `RRGGBBAA`) or named color code for metric cards.
Color? dashboardColorFromCode(ThemeData theme, String? value) {
  final String raw = (value ?? '').trim();
  if (raw.isEmpty) {
    return null;
  }

  final Color? hex = dashboardColorFromHex(raw);
  if (hex != null) {
    return hex;
  }

  final ColorScheme colorScheme = theme.colorScheme;
  final AppStatusColors statusColors = theme.statusColors;
  return switch (raw.toLowerCase()) {
    'success' => statusColors.success,
    'warning' => statusColors.warning,
    'error' => statusColors.error,
    'danger' => statusColors.danger,
    'info' => statusColors.info,
    'neutral' => colorScheme.onSurfaceVariant,
    'primary' => colorScheme.primary,
    'secondary' => colorScheme.secondary,
    'tertiary' => colorScheme.tertiary,
    _ => null,
  };
}

Color? dashboardColorFromHex(String? value) {
  final String normalized = (value ?? '').trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) {
    return null;
  }
  final int? parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
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
    border: theme.borders.all(color: accent.withValues(alpha: 0.22)),
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
    border: theme.borders.all(),
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
    border: theme.borders.all(color: accent.withValues(alpha: 0.22)),
    boxShadow: dashboardSoftShadow(colorScheme),
  );
}

/// Summary KPI columns: 1 on mobile, 3 on tablet, 5 on desktop.
int dashboardMetricColumnsForWidth(double width) {
  if (width < AppBreakpoints.md) {
    return 1;
  }
  if (width < AppBreakpoints.xl) {
    return 3;
  }
  return 5;
}

/// Columns for [cardCount] cards, capped by the responsive column budget.
int dashboardMetricColumnCount(double maxWidth, int cardCount) {
  final int count = math.max(1, cardCount);
  return math.min(count, dashboardMetricColumnsForWidth(maxWidth));
}

/// Desktop & tablet (≥ md): all actions on one row (max 8).
/// Mobile (< md): one action per row.
int dashboardQuickActionColumnCount(double maxWidth, int actionCount) {
  final int count = math.max(1, math.min(actionCount, 8));
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

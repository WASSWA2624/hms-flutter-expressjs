import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';

/// Faint elevated surface used by dashboard section panels.
Color dashboardSectionBackgroundColor(ColorScheme colorScheme) {
  return colorScheme.surfaceContainerLowest;
}

/// Subtle border matching metric cards and shortcut tiles.
Color dashboardSectionBorderColor(ColorScheme colorScheme) {
  return colorScheme.outlineVariant.withValues(alpha: 0.7);
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

/// Desktop & tablet (≥ md): all actions on one row (max 4).
/// Mobile (< md): one action per row.
int dashboardQuickActionColumnCount(double maxWidth, int actionCount) {
  final int count = math.max(1, math.min(actionCount, 4));
  if (maxWidth >= AppBreakpoints.md) {
    return count;
  }
  return 1;
}

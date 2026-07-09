import 'dart:math' as math;

/// Desktop: one column per visible card (even widths for 2–4 cards).
/// Tablet: up to two per row; mobile: one or two per row.
int dashboardMetricColumnCount(double maxWidth, int cardCount) {
  final int count = math.max(1, cardCount);
  if (maxWidth >= 1180) {
    return count;
  }
  if (maxWidth >= 760) {
    return math.min(count, 2);
  }
  if (maxWidth >= 340) {
    return math.min(count, 2);
  }
  return 1;
}

int dashboardQuickActionColumnCount(double maxWidth, int actionCount) {
  final int count = math.max(1, actionCount);
  if (maxWidth >= 1180) {
    return count;
  }
  if (maxWidth >= 760) {
    return math.min(count, 2);
  }
  if (maxWidth >= 340) {
    return math.min(count, 2);
  }
  return 1;
}

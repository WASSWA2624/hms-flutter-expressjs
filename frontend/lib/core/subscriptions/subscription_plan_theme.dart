import 'package:flutter/material.dart';

enum SubscriptionPlanTier { free, basic, pro, advanced, custom }

/// Shared subscription plan-tier colors used across the app
/// (plans table rows, header badge, status chips, etc.).
///
/// Always resolve through [of] / [resolve] with the active [ThemeData] so
/// light and dark surfaces stay readable.
@immutable
final class SubscriptionPlanTheme {
  const SubscriptionPlanTheme({
    required this.tier,
    required this.foreground,
    required this.background,
    required this.border,
    required this.rowTint,
  });

  final SubscriptionPlanTier tier;
  final Color foreground;
  final Color background;
  final Color border;
  final Color rowTint;

  static SubscriptionPlanTheme of(BuildContext context, String? tierOrLabel) {
    return resolve(Theme.of(context), tierOrLabel);
  }

  static SubscriptionPlanTheme resolve(ThemeData theme, String? tierOrLabel) {
    final SubscriptionPlanTier tier = parseTier(tierOrLabel);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = _accent(tier, isDark);
    final Color surface = theme.colorScheme.surface;

    return SubscriptionPlanTheme(
      tier: tier,
      foreground: accent,
      background: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.22 : 0.14),
        surface,
      ),
      border: accent.withValues(alpha: isDark ? 0.45 : 0.32),
      rowTint: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.16 : 0.08),
        surface,
      ),
    );
  }

  static SubscriptionPlanTier parseTier(String? tierOrLabel) {
    final String normalized = (tierOrLabel ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');

    if (normalized.isEmpty ||
        normalized == 'NOT_SUBSCRIBED' ||
        normalized == 'NOT_RECORDED' ||
        normalized == 'NONE' ||
        normalized == 'UNKNOWN') {
      return SubscriptionPlanTier.free;
    }
    if (normalized == 'FREE' || normalized.contains('FREE')) {
      return SubscriptionPlanTier.free;
    }
    if (normalized == 'BASIC' || normalized.contains('BASIC')) {
      return SubscriptionPlanTier.basic;
    }
    if (normalized == 'PRO' ||
        normalized == 'STANDARD' ||
        normalized == 'PREMIUM' ||
        normalized.contains('PRO')) {
      return SubscriptionPlanTier.pro;
    }
    if (normalized == 'ADVANCED' ||
        normalized == 'ENTERPRISE' ||
        normalized.contains('ADVANCED') ||
        normalized.contains('ENTERPRISE')) {
      return SubscriptionPlanTier.advanced;
    }
    if (normalized == 'CUSTOM' || normalized.contains('CUSTOM')) {
      return SubscriptionPlanTier.custom;
    }
    return SubscriptionPlanTier.free;
  }

  static bool isFreeTier(String? tierOrLabel) {
    return parseTier(tierOrLabel) == SubscriptionPlanTier.free;
  }

  /// Light accents stay saturated; dark accents stay luminous on navy surfaces.
  static Color _accent(SubscriptionPlanTier tier, bool isDark) {
    return switch (tier) {
      SubscriptionPlanTier.free =>
        isDark ? const Color(0xFFA6B4CB) : const Color(0xFF566579),
      SubscriptionPlanTier.basic =>
        isDark ? const Color(0xFF83B0FF) : const Color(0xFF1D4ED8),
      SubscriptionPlanTier.pro =>
        isDark ? const Color(0xFF7ED89B) : const Color(0xFF15803D),
      SubscriptionPlanTier.advanced =>
        isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
      SubscriptionPlanTier.custom =>
        isDark ? const Color(0xFFF2B366) : const Color(0xFFC2410C),
    };
  }
}

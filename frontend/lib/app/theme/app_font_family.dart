import 'package:flutter/material.dart';

/// Application font family configuration.
///
/// Bundled Roboto files are registered under [primary] instead of `Roboto`
/// because reusing the Material default family name on Flutter web overrides
/// the engine's font resolution and can prevent all text from rendering.
///
/// Weights are declared in [AppFontWeight] and applied through [AppTheme]
/// so every platform (mobile, tablet, desktop, web) shares one light-first
/// typography system.
abstract final class AppFontFamily {
  static const String primary = 'HosspiSans';

  /// Platform monospace stack for code / identifiers.
  static const String monospace = 'monospace';

  static const List<String> fallback = <String>[
    'Segoe UI',
    'Arial',
    'Helvetica Neue',
    'sans-serif',
  ];

  static const List<String> monospaceFallback = <String>[
    'Consolas',
    'Courier New',
    'monospace',
  ];

  /// Base [TextStyle] that always applies the app family + fallbacks.
  static TextStyle style({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    TextDecoration? decoration,
    List<FontFeature>? fontFeatures,
    String? fontFamily,
    List<String>? fontFamilyFallback,
  }) {
    return TextStyle(
      fontFamily: fontFamily ?? primary,
      fontFamilyFallback: fontFamilyFallback ?? fallback,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight ?? AppFontWeight.body,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      decoration: decoration,
      fontFeatures: fontFeatures,
    );
  }

  /// Monospace variant for codes, hashes, and technical identifiers.
  static TextStyle mono({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return style(
      fontFamily: monospace,
      fontFamilyFallback: monospaceFallback,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight ?? AppFontWeight.regular,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

/// Light-first weight scale for [AppFontFamily.primary] across all screens.
///
/// Prefer semantic roles ([body], [title], [emphasis], [strong], [display])
/// over raw Material [FontWeight] values so hierarchy stays consistent.
abstract final class AppFontWeight {
  // --- Physical scale (matches bundled HosspiSans / Roboto files) ---
  static const FontWeight thin = FontWeight.w100;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // --- Semantic roles (defaults lean thin / light) ---

  /// Large display / hero type.
  static const FontWeight display = thin;

  /// Default paragraph and workspace body copy.
  static const FontWeight body = light;

  /// Form labels, hints, and captions.
  static const FontWeight label = light;

  /// Section and card titles.
  static const FontWeight title = regular;

  /// Selected tabs, highlighted meta, soft emphasis.
  static const FontWeight emphasis = medium;

  /// Strongest UI emphasis (headers, primary labels). Caps below heavy bold.
  static const FontWeight strong = semiBold;

  /// Maps an arbitrary [FontWeight] onto the app scale (one step lighter).
  static FontWeight resolve(FontWeight? weight) {
    if (weight == null) {
      return body;
    }
    final int value = weight.value;
    if (value <= 100) {
      return thin;
    }
    if (value <= 300) {
      return light;
    }
    if (value <= 400) {
      return regular;
    }
    if (value <= 500) {
      return medium;
    }
    if (value <= 600) {
      return semiBold;
    }
    return bold;
  }

  /// Softens Material defaults toward the light-first scale.
  static FontWeight lighten(FontWeight? weight) {
    if (weight == null) {
      return body;
    }
    final int value = weight.value;
    if (value >= 800) {
      return strong;
    }
    if (value >= 700) {
      return strong;
    }
    if (value >= 600) {
      return emphasis;
    }
    if (value >= 500) {
      return regular;
    }
    if (value >= 400) {
      return light;
    }
    return thin;
  }
}

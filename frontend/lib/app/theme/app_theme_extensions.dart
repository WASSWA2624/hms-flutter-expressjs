import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
final class AppSpacingTokens extends ThemeExtension<AppSpacingTokens> {
  const AppSpacingTokens({
    required this.none,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  static const AppSpacingTokens standard = AppSpacingTokens(
    none: 0,
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    xxl: 32,
  );

  final double none;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  @override
  AppSpacingTokens copyWith({
    double? none,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) {
    return AppSpacingTokens(
      none: none ?? this.none,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  AppSpacingTokens lerp(AppSpacingTokens? other, double t) {
    if (other == null) {
      return this;
    }

    return AppSpacingTokens(
      none: _lerpDouble(none, other.none, t),
      xs: _lerpDouble(xs, other.xs, t),
      sm: _lerpDouble(sm, other.sm, t),
      md: _lerpDouble(md, other.md, t),
      lg: _lerpDouble(lg, other.lg, t),
      xl: _lerpDouble(xl, other.xl, t),
      xxl: _lerpDouble(xxl, other.xxl, t),
    );
  }
}

@immutable
final class AppRadiusTokens extends ThemeExtension<AppRadiusTokens> {
  const AppRadiusTokens({
    required this.none,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  static const AppRadiusTokens standard = AppRadiusTokens(
    none: 0,
    xs: 4,
    sm: 8,
    md: 10,
    lg: 12,
    xl: 16,
  );

  final double none;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  @override
  AppRadiusTokens copyWith({
    double? none,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
  }) {
    return AppRadiusTokens(
      none: none ?? this.none,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }

  @override
  AppRadiusTokens lerp(AppRadiusTokens? other, double t) {
    if (other == null) {
      return this;
    }

    return AppRadiusTokens(
      none: _lerpDouble(none, other.none, t),
      xs: _lerpDouble(xs, other.xs, t),
      sm: _lerpDouble(sm, other.sm, t),
      md: _lerpDouble(md, other.md, t),
      lg: _lerpDouble(lg, other.lg, t),
      xl: _lerpDouble(xl, other.xl, t),
    );
  }
}

@immutable
final class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  AppStatusColors lerp(AppStatusColors? other, double t) {
    if (other == null) {
      return this;
    }

    return AppStatusColors(
      success: _lerpColor(success, other.success, t),
      onSuccess: _lerpColor(onSuccess, other.onSuccess, t),
      successContainer: _lerpColor(successContainer, other.successContainer, t),
      onSuccessContainer: _lerpColor(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      ),
      warning: _lerpColor(warning, other.warning, t),
      onWarning: _lerpColor(onWarning, other.onWarning, t),
      warningContainer: _lerpColor(warningContainer, other.warningContainer, t),
      onWarningContainer: _lerpColor(
        onWarningContainer,
        other.onWarningContainer,
        t,
      ),
      error: _lerpColor(error, other.error, t),
      onError: _lerpColor(onError, other.onError, t),
      errorContainer: _lerpColor(errorContainer, other.errorContainer, t),
      onErrorContainer: _lerpColor(onErrorContainer, other.onErrorContainer, t),
      danger: _lerpColor(danger, other.danger, t),
      onDanger: _lerpColor(onDanger, other.onDanger, t),
      dangerContainer: _lerpColor(dangerContainer, other.dangerContainer, t),
      onDangerContainer: _lerpColor(
        onDangerContainer,
        other.onDangerContainer,
        t,
      ),
      info: _lerpColor(info, other.info, t),
      onInfo: _lerpColor(onInfo, other.onInfo, t),
      infoContainer: _lerpColor(infoContainer, other.infoContainer, t),
      onInfoContainer: _lerpColor(onInfoContainer, other.onInfoContainer, t),
    );
  }
}

@immutable
final class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  const AppDesignTokens({
    required this.pagePaddingMobile,
    required this.pagePaddingTablet,
    required this.pagePaddingDesktop,
    required this.formGapCompact,
    required this.formGapRegular,
    required this.formGapSpacious,
    required this.minInteractiveDimension,
    required this.listIconSize,
    required this.statusIconSize,
    required this.dividerThickness,
  });

  static const AppDesignTokens standard = AppDesignTokens(
    pagePaddingMobile: 12,
    pagePaddingTablet: 16,
    pagePaddingDesktop: 24,
    formGapCompact: 8,
    formGapRegular: 12,
    formGapSpacious: 16,
    minInteractiveDimension: 40,
    listIconSize: 20,
    statusIconSize: 32,
    dividerThickness: 1,
  );

  final double pagePaddingMobile;
  final double pagePaddingTablet;
  final double pagePaddingDesktop;
  final double formGapCompact;
  final double formGapRegular;
  final double formGapSpacious;
  final double minInteractiveDimension;
  final double listIconSize;
  final double statusIconSize;
  final double dividerThickness;

  @override
  AppDesignTokens copyWith({
    double? pagePaddingMobile,
    double? pagePaddingTablet,
    double? pagePaddingDesktop,
    double? formGapCompact,
    double? formGapRegular,
    double? formGapSpacious,
    double? minInteractiveDimension,
    double? listIconSize,
    double? statusIconSize,
    double? dividerThickness,
  }) {
    return AppDesignTokens(
      pagePaddingMobile: pagePaddingMobile ?? this.pagePaddingMobile,
      pagePaddingTablet: pagePaddingTablet ?? this.pagePaddingTablet,
      pagePaddingDesktop: pagePaddingDesktop ?? this.pagePaddingDesktop,
      formGapCompact: formGapCompact ?? this.formGapCompact,
      formGapRegular: formGapRegular ?? this.formGapRegular,
      formGapSpacious: formGapSpacious ?? this.formGapSpacious,
      minInteractiveDimension:
          minInteractiveDimension ?? this.minInteractiveDimension,
      listIconSize: listIconSize ?? this.listIconSize,
      statusIconSize: statusIconSize ?? this.statusIconSize,
      dividerThickness: dividerThickness ?? this.dividerThickness,
    );
  }

  @override
  AppDesignTokens lerp(AppDesignTokens? other, double t) {
    if (other == null) {
      return this;
    }

    return AppDesignTokens(
      pagePaddingMobile: _lerpDouble(
        pagePaddingMobile,
        other.pagePaddingMobile,
        t,
      ),
      pagePaddingTablet: _lerpDouble(
        pagePaddingTablet,
        other.pagePaddingTablet,
        t,
      ),
      pagePaddingDesktop: _lerpDouble(
        pagePaddingDesktop,
        other.pagePaddingDesktop,
        t,
      ),
      formGapCompact: _lerpDouble(formGapCompact, other.formGapCompact, t),
      formGapRegular: _lerpDouble(formGapRegular, other.formGapRegular, t),
      formGapSpacious: _lerpDouble(formGapSpacious, other.formGapSpacious, t),
      minInteractiveDimension: _lerpDouble(
        minInteractiveDimension,
        other.minInteractiveDimension,
        t,
      ),
      listIconSize: _lerpDouble(listIconSize, other.listIconSize, t),
      statusIconSize: _lerpDouble(statusIconSize, other.statusIconSize, t),
      dividerThickness: _lerpDouble(
        dividerThickness,
        other.dividerThickness,
        t,
      ),
    );
  }
}

extension AppThemeDataTokens on ThemeData {
  AppSpacingTokens get spacing {
    return extension<AppSpacingTokens>() ?? AppSpacingTokens.standard;
  }

  AppRadiusTokens get radius {
    return extension<AppRadiusTokens>() ?? AppRadiusTokens.standard;
  }

  AppStatusColors get statusColors {
    final AppStatusColors? tokens = extension<AppStatusColors>();
    if (tokens != null) {
      return tokens;
    }

    throw StateError('AppStatusColors is not configured for this ThemeData.');
  }

  AppDesignTokens get appTokens {
    return extension<AppDesignTokens>() ?? AppDesignTokens.standard;
  }
}

double _lerpDouble(double begin, double end, double t) {
  return lerpDouble(begin, end, t)!;
}

Color _lerpColor(Color begin, Color end, double t) {
  return Color.lerp(begin, end, t)!;
}

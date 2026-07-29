import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';

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
    required this.xxl,
    required this.full,
  });

  static const AppRadiusTokens standard = AppRadiusTokens(
    none: 0,
    xs: 4,
    sm: 8,
    md: 10,
    lg: 12,
    xl: 16,
    xxl: 24,
    // Sentinel for fully rounded (pill/circular) surfaces. Widgets clamp this
    // to half of the shortest side so it renders as a true pill/circle.
    full: 9999,
  );

  final double none;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double full;

  @override
  AppRadiusTokens copyWith({
    double? none,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? full,
  }) {
    return AppRadiusTokens(
      none: none ?? this.none,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      full: full ?? this.full,
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
      xxl: _lerpDouble(xxl, other.xxl, t),
      full: _lerpDouble(full, other.full, t),
    );
  }

  /// Scales a base radius so surfaces feel proportionate across breakpoints:
  /// tighter on compact phones, more generous on large desktops. There is no
  /// fixed ceiling — any token (including [full]) may be passed.
  double responsive(AppBreakpoint breakpoint, double base) {
    final double factor = switch (breakpoint) {
      AppBreakpoint.xs => 0.75,
      AppBreakpoint.sm => 0.85,
      AppBreakpoint.md => 1,
      AppBreakpoint.lg => 1,
      AppBreakpoint.xl => 1.15,
      AppBreakpoint.xxl => 1.25,
    };
    return base * factor;
  }
}

extension AppResponsiveRadiusContext on BuildContext {
  /// Breakpoint-aware radius for the current viewport. Pass any radius token
  /// value (e.g. `theme.radius.lg`); it is scaled for responsiveness.
  double responsiveRadius(double base) {
    return AppRadiusTokens.standard.responsive(AppBreakpoints.of(this), base);
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
    required this.dialogInsetMobile,
    required this.dialogInsetTablet,
    required this.dialogInsetDesktop,
    required this.dialogSnackBarClearance,
    required this.dialogMinWidth,
    required this.dialogMinHeight,
    required this.dialogResizeHandleThickness,
    required this.formGapCompact,
    required this.formGapRegular,
    required this.formGapSpacious,
    required this.minInteractiveDimension,
    required this.listIconSize,
    required this.statusIconSize,
    required this.dividerThickness,
  });

  static const AppDesignTokens standard = AppDesignTokens(
    pagePaddingMobile: 16,
    pagePaddingTablet: 24,
    pagePaddingDesktop: 32,
    dialogInsetMobile: 12,
    dialogInsetTablet: 24,
    dialogInsetDesktop: 24,
    dialogSnackBarClearance: 88,
    dialogMinWidth: 360,
    dialogMinHeight: 280,
    dialogResizeHandleThickness: 6,
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
  final double dialogInsetMobile;
  final double dialogInsetTablet;
  final double dialogInsetDesktop;
  final double dialogSnackBarClearance;
  final double dialogMinWidth;
  final double dialogMinHeight;
  final double dialogResizeHandleThickness;
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
    double? dialogInsetMobile,
    double? dialogInsetTablet,
    double? dialogInsetDesktop,
    double? dialogSnackBarClearance,
    double? dialogMinWidth,
    double? dialogMinHeight,
    double? dialogResizeHandleThickness,
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
      dialogInsetMobile: dialogInsetMobile ?? this.dialogInsetMobile,
      dialogInsetTablet: dialogInsetTablet ?? this.dialogInsetTablet,
      dialogInsetDesktop: dialogInsetDesktop ?? this.dialogInsetDesktop,
      dialogSnackBarClearance:
          dialogSnackBarClearance ?? this.dialogSnackBarClearance,
      dialogMinWidth: dialogMinWidth ?? this.dialogMinWidth,
      dialogMinHeight: dialogMinHeight ?? this.dialogMinHeight,
      dialogResizeHandleThickness:
          dialogResizeHandleThickness ?? this.dialogResizeHandleThickness,
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
      dialogInsetMobile: _lerpDouble(
        dialogInsetMobile,
        other.dialogInsetMobile,
        t,
      ),
      dialogInsetTablet: _lerpDouble(
        dialogInsetTablet,
        other.dialogInsetTablet,
        t,
      ),
      dialogInsetDesktop: _lerpDouble(
        dialogInsetDesktop,
        other.dialogInsetDesktop,
        t,
      ),
      dialogSnackBarClearance: _lerpDouble(
        dialogSnackBarClearance,
        other.dialogSnackBarClearance,
        t,
      ),
      dialogMinWidth: _lerpDouble(dialogMinWidth, other.dialogMinWidth, t),
      dialogMinHeight: _lerpDouble(dialogMinHeight, other.dialogMinHeight, t),
      dialogResizeHandleThickness: _lerpDouble(
        dialogResizeHandleThickness,
        other.dialogResizeHandleThickness,
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

/// List typography and metrics for [AppListTable] mobile rows.
@immutable
final class AppListTokens extends ThemeExtension<AppListTokens> {
  const AppListTokens({
    required this.mobileTitle,
    required this.mobileCaption,
    required this.mobileMeta,
    required this.mobileAvatarInitials,
    required this.mobileRowNumber,
    required this.mobileAvatarSize,
    required this.mobileMetaIconSize,
    required this.mobileChevronSize,
    required this.mobileMetaLineGap,
  });

  /// Weights for mobile list hierarchy (title stands out from muted meta).
  static const FontWeight mobileTitleWeight = FontWeight.w600;
  static const FontWeight mobileSecondaryWeight = FontWeight.w400;
  static const FontWeight mobileAvatarInitialsWeight = FontWeight.w600;

  /// Metrics for mobile list chrome — sized for thumb-friendly readability.
  static const double mobileAvatarExtent = 40;
  static const double mobileMetaIconExtent = 14;
  static const double mobileChevronExtent = 18;
  static const double mobileMetaGap = 6;

  /// Mobile list styles derived from the active [TextTheme]/[ColorScheme].
  ///
  /// Titles use ~15sp body; captions/meta use ~12sp so hierarchy is clear
  /// without looking dense or washed-out on phones.
  factory AppListTokens.compact({
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    final TextStyle titleBase =
        textTheme.bodyLarge ??
        textTheme.titleSmall ??
        const TextStyle(fontSize: 15, height: 1.3);
    final TextStyle secondaryBase =
        textTheme.bodySmall ??
        textTheme.labelMedium ??
        const TextStyle(fontSize: 12, height: 1.3);
    final double titleSize = titleBase.fontSize ?? 15;
    final double secondarySize = secondaryBase.fontSize ?? 12;
    final Color muted = colorScheme.onSurfaceVariant.withValues(alpha: 0.78);

    return AppListTokens(
      mobileTitle: titleBase.copyWith(
        color: colorScheme.onSurface,
        fontSize: titleSize.clamp(14, 16).toDouble(),
        fontWeight: mobileTitleWeight,
        height: 1.3,
        letterSpacing: -0.1,
      ),
      mobileCaption: secondaryBase.copyWith(
        color: muted,
        fontSize: secondarySize,
        fontWeight: mobileSecondaryWeight,
        height: 1.3,
      ),
      mobileMeta: secondaryBase.copyWith(
        color: muted,
        fontSize: secondarySize,
        fontWeight: mobileSecondaryWeight,
        height: 1.3,
      ),
      mobileAvatarInitials: secondaryBase.copyWith(
        fontSize: 13,
        fontWeight: mobileAvatarInitialsWeight,
        height: 1,
        letterSpacing: 0.2,
      ),
      mobileRowNumber: secondaryBase.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.2,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      mobileAvatarSize: mobileAvatarExtent,
      mobileMetaIconSize: mobileMetaIconExtent,
      mobileChevronSize: mobileChevronExtent,
      mobileMetaLineGap: mobileMetaGap,
    );
  }

  final TextStyle mobileTitle;
  final TextStyle mobileCaption;
  final TextStyle mobileMeta;
  final TextStyle mobileAvatarInitials;
  final TextStyle mobileRowNumber;
  final double mobileAvatarSize;
  final double mobileMetaIconSize;
  final double mobileChevronSize;
  final double mobileMetaLineGap;

  @override
  AppListTokens copyWith({
    TextStyle? mobileTitle,
    TextStyle? mobileCaption,
    TextStyle? mobileMeta,
    TextStyle? mobileAvatarInitials,
    TextStyle? mobileRowNumber,
    double? mobileAvatarSize,
    double? mobileMetaIconSize,
    double? mobileChevronSize,
    double? mobileMetaLineGap,
  }) {
    return AppListTokens(
      mobileTitle: mobileTitle ?? this.mobileTitle,
      mobileCaption: mobileCaption ?? this.mobileCaption,
      mobileMeta: mobileMeta ?? this.mobileMeta,
      mobileAvatarInitials: mobileAvatarInitials ?? this.mobileAvatarInitials,
      mobileRowNumber: mobileRowNumber ?? this.mobileRowNumber,
      mobileAvatarSize: mobileAvatarSize ?? this.mobileAvatarSize,
      mobileMetaIconSize: mobileMetaIconSize ?? this.mobileMetaIconSize,
      mobileChevronSize: mobileChevronSize ?? this.mobileChevronSize,
      mobileMetaLineGap: mobileMetaLineGap ?? this.mobileMetaLineGap,
    );
  }

  @override
  AppListTokens lerp(AppListTokens? other, double t) {
    if (other == null) {
      return this;
    }

    return AppListTokens(
      mobileTitle: TextStyle.lerp(mobileTitle, other.mobileTitle, t)!,
      mobileCaption: TextStyle.lerp(mobileCaption, other.mobileCaption, t)!,
      mobileMeta: TextStyle.lerp(mobileMeta, other.mobileMeta, t)!,
      mobileAvatarInitials: TextStyle.lerp(
        mobileAvatarInitials,
        other.mobileAvatarInitials,
        t,
      )!,
      mobileRowNumber: TextStyle.lerp(
        mobileRowNumber,
        other.mobileRowNumber,
        t,
      )!,
      mobileAvatarSize: _lerpDouble(
        mobileAvatarSize,
        other.mobileAvatarSize,
        t,
      ),
      mobileMetaIconSize: _lerpDouble(
        mobileMetaIconSize,
        other.mobileMetaIconSize,
        t,
      ),
      mobileChevronSize: _lerpDouble(
        mobileChevronSize,
        other.mobileChevronSize,
        t,
      ),
      mobileMetaLineGap: _lerpDouble(
        mobileMetaLineGap,
        other.mobileMetaLineGap,
        t,
      ),
    );
  }
}

@immutable
final class AppSidebarTokens extends ThemeExtension<AppSidebarTokens> {
  const AppSidebarTokens({
    required this.backgroundColor,
    required this.shadowColor,
    required this.elevation,
    required this.itemHeight,
    required this.itemBorderRadius,
    required this.selectedBackgroundColor,
    required this.selectedForegroundColor,
    required this.hoverBackgroundColor,
    required this.hoverForegroundColor,
    required this.defaultForegroundColor,
    required this.focusBorderColor,
    required this.badgeAccentBackgroundColor,
    required this.badgeAccentForegroundColor,
  });

  final Color backgroundColor;
  final Color shadowColor;
  final double elevation;
  final double itemHeight;
  final double itemBorderRadius;
  final Color selectedBackgroundColor;
  final Color selectedForegroundColor;
  final Color hoverBackgroundColor;
  final Color hoverForegroundColor;
  final Color defaultForegroundColor;
  final Color focusBorderColor;
  final Color badgeAccentBackgroundColor;
  final Color badgeAccentForegroundColor;

  @override
  AppSidebarTokens copyWith({
    Color? backgroundColor,
    Color? shadowColor,
    double? elevation,
    double? itemHeight,
    double? itemBorderRadius,
    Color? selectedBackgroundColor,
    Color? selectedForegroundColor,
    Color? hoverBackgroundColor,
    Color? hoverForegroundColor,
    Color? defaultForegroundColor,
    Color? focusBorderColor,
    Color? badgeAccentBackgroundColor,
    Color? badgeAccentForegroundColor,
  }) {
    return AppSidebarTokens(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      shadowColor: shadowColor ?? this.shadowColor,
      elevation: elevation ?? this.elevation,
      itemHeight: itemHeight ?? this.itemHeight,
      itemBorderRadius: itemBorderRadius ?? this.itemBorderRadius,
      selectedBackgroundColor:
          selectedBackgroundColor ?? this.selectedBackgroundColor,
      selectedForegroundColor:
          selectedForegroundColor ?? this.selectedForegroundColor,
      hoverBackgroundColor: hoverBackgroundColor ?? this.hoverBackgroundColor,
      hoverForegroundColor: hoverForegroundColor ?? this.hoverForegroundColor,
      defaultForegroundColor:
          defaultForegroundColor ?? this.defaultForegroundColor,
      focusBorderColor: focusBorderColor ?? this.focusBorderColor,
      badgeAccentBackgroundColor:
          badgeAccentBackgroundColor ?? this.badgeAccentBackgroundColor,
      badgeAccentForegroundColor:
          badgeAccentForegroundColor ?? this.badgeAccentForegroundColor,
    );
  }

  @override
  AppSidebarTokens lerp(AppSidebarTokens? other, double t) {
    if (other == null) {
      return this;
    }

    return AppSidebarTokens(
      backgroundColor: _lerpColor(backgroundColor, other.backgroundColor, t),
      shadowColor: _lerpColor(shadowColor, other.shadowColor, t),
      elevation: _lerpDouble(elevation, other.elevation, t),
      itemHeight: _lerpDouble(itemHeight, other.itemHeight, t),
      itemBorderRadius: _lerpDouble(
        itemBorderRadius,
        other.itemBorderRadius,
        t,
      ),
      selectedBackgroundColor: _lerpColor(
        selectedBackgroundColor,
        other.selectedBackgroundColor,
        t,
      ),
      selectedForegroundColor: _lerpColor(
        selectedForegroundColor,
        other.selectedForegroundColor,
        t,
      ),
      hoverBackgroundColor: _lerpColor(
        hoverBackgroundColor,
        other.hoverBackgroundColor,
        t,
      ),
      hoverForegroundColor: _lerpColor(
        hoverForegroundColor,
        other.hoverForegroundColor,
        t,
      ),
      defaultForegroundColor: _lerpColor(
        defaultForegroundColor,
        other.defaultForegroundColor,
        t,
      ),
      focusBorderColor: _lerpColor(focusBorderColor, other.focusBorderColor, t),
      badgeAccentBackgroundColor: _lerpColor(
        badgeAccentBackgroundColor,
        other.badgeAccentBackgroundColor,
        t,
      ),
      badgeAccentForegroundColor: _lerpColor(
        badgeAccentForegroundColor,
        other.badgeAccentForegroundColor,
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

    final ColorScheme colors = colorScheme;
    return AppStatusColors(
      success: colors.tertiary,
      onSuccess: colors.onTertiary,
      successContainer: colors.tertiaryContainer,
      onSuccessContainer: colors.onTertiaryContainer,
      warning: colors.secondary,
      onWarning: colors.onSecondary,
      warningContainer: colors.secondaryContainer,
      onWarningContainer: colors.onSecondaryContainer,
      error: colors.error,
      onError: colors.onError,
      errorContainer: colors.errorContainer,
      onErrorContainer: colors.onErrorContainer,
      danger: colors.error,
      onDanger: colors.onError,
      dangerContainer: colors.errorContainer,
      onDangerContainer: colors.onErrorContainer,
      info: colors.primary,
      onInfo: colors.onPrimary,
      infoContainer: colors.primaryContainer,
      onInfoContainer: colors.onPrimaryContainer,
    );
  }

  AppDesignTokens get appTokens {
    return extension<AppDesignTokens>() ?? AppDesignTokens.standard;
  }

  AppListTokens get listTokens {
    return extension<AppListTokens>() ??
        AppListTokens.compact(
          textTheme: textTheme,
          colorScheme: colorScheme,
        );
  }

  AppSidebarTokens get sidebarTokens {
    final AppSidebarTokens? tokens = extension<AppSidebarTokens>();
    if (tokens != null) {
      return tokens;
    }

    final ColorScheme colors = colorScheme;
    return AppSidebarTokens(
      backgroundColor: colors.surface,
      shadowColor: colors.shadow.withValues(alpha: 0.08),
      elevation: 1,
      itemHeight: 40,
      itemBorderRadius: AppRadiusTokens.standard.md,
      selectedBackgroundColor: colors.primaryContainer,
      selectedForegroundColor: colors.primary,
      hoverBackgroundColor: colors.primary.withValues(alpha: 0.07),
      hoverForegroundColor: colors.primary,
      defaultForegroundColor: colors.onSurfaceVariant,
      focusBorderColor: colors.primary.withValues(alpha: 0.56),
      badgeAccentBackgroundColor: colors.tertiaryContainer,
      badgeAccentForegroundColor: colors.onTertiaryContainer,
    );
  }
}

double _lerpDouble(double begin, double end, double t) {
  return lerpDouble(begin, end, t)!;
}

Color _lerpColor(Color begin, Color end, double t) {
  return Color.lerp(begin, end, t)!;
}

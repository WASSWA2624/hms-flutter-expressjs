import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_logo.dart';

/// Visual density for [AppLoadingIndicator].
enum AppLoadingIndicatorSize {
  /// Inline / table / compact panel (small logo).
  compact,

  /// Default component / workspace panel.
  regular,

  /// Full-page async scaffolds.
  large,

  /// App bootstrap / branded splash.
  hero,
}

/// Elegant logo-based loading indicator.
///
/// Prefer this over [CircularProgressIndicator] for page and component loads.
/// By default, [expand] centers the mark within the loading parent’s available
/// bounds and scales the logo down when that region is tight. Pass
/// `expand: false` only for intrinsic inline slots (e.g. field trailing icons).
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({
    this.size = AppLoadingIndicatorSize.regular,
    this.title,
    this.body,
    this.expand = true,
    this.semanticLabel,
    this.showBrandName = false,
    super.key,
  });

  /// Compact centered mark for tables and tight panels.
  const AppLoadingIndicator.compact({
    this.title,
    this.body,
    this.expand = true,
    this.semanticLabel,
    this.showBrandName = false,
    super.key,
  }) : size = AppLoadingIndicatorSize.compact;

  /// Full-viewport branded loader (startup / auth-adjacent).
  const AppLoadingIndicator.page({
    this.title,
    this.body,
    this.semanticLabel,
    this.showBrandName = true,
    super.key,
  }) : size = AppLoadingIndicatorSize.large,
       expand = true;

  /// Bootstrap splash with the largest logo treatment.
  const AppLoadingIndicator.startup({
    this.title,
    this.body,
    this.semanticLabel,
    this.showBrandName = true,
    super.key,
  }) : size = AppLoadingIndicatorSize.hero,
       expand = true;

  final AppLoadingIndicatorSize size;
  final String? title;
  final String? body;
  final bool expand;
  final String? semanticLabel;
  final bool showBrandName;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.expand) {
      return _buildContent(context, scale: 1);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool hasBoundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final bool hasBoundedWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
        final double scale = _fitScale(constraints);

        Widget centered = Center(
          child: _buildContent(context, scale: scale),
        );
        if (hasBoundedHeight || hasBoundedWidth) {
          centered = SizedBox(
            width: hasBoundedWidth ? constraints.maxWidth : null,
            height: hasBoundedHeight ? constraints.maxHeight : null,
            child: centered,
          );
        }
        return KeyedSubtree(
          key: const ValueKey<String>('appLoadingIndicatorExpanded'),
          child: centered,
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, {required double scale}) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final _LoadingMetrics metrics = _LoadingMetrics.resolve(
      size: widget.size,
      breakpoint: breakpoint,
      spacing: theme.spacing,
      scale: scale,
    );

    return Semantics(
      label: widget.semanticLabel ?? widget.title ?? 'Loading',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _AnimatedLogoMark(
                progress: _controller.value,
                logoSize: metrics.logoSize,
                ringPadding: metrics.ringPadding,
                colorScheme: theme.colorScheme,
              ),
              if (widget.showBrandName) ...<Widget>[
                SizedBox(height: metrics.gapAfterLogo),
                Text(
                  _brandName(context, breakpoint),
                  textAlign: TextAlign.center,
                  style: metrics.brandStyle(theme),
                ),
              ],
              if (widget.title != null &&
                  widget.title!.trim().isNotEmpty) ...<Widget>[
                SizedBox(
                  height: widget.showBrandName
                      ? theme.spacing.sm
                      : metrics.gapAfterLogo,
                ),
                Text(
                  widget.title!,
                  textAlign: TextAlign.center,
                  style: metrics.titleStyle(theme),
                ),
              ],
              if (widget.body != null &&
                  widget.body!.trim().isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: metrics.copyMaxWidth),
                  child: Text(
                    widget.body!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              SizedBox(height: theme.spacing.md),
              _SoftProgressDots(
                progress: _controller.value,
                color: theme.colorScheme.primary,
              ),
            ],
          );
        },
      ),
    );
  }

  double _fitScale(BoxConstraints constraints) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final _LoadingMetrics preferred = _LoadingMetrics.resolve(
      size: widget.size,
      breakpoint: breakpoint,
      spacing: theme.spacing,
    );
    final double preferredMark =
        preferred.logoSize + (preferred.ringPadding * 2) + 16;
    double scale = 1;
    if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
      // Leave room for title/body copy; mark should stay within the parent.
      scale = math.min(scale, (constraints.maxWidth * 0.55) / preferredMark);
    }
    if (constraints.hasBoundedHeight && constraints.maxHeight.isFinite) {
      // Reserve space for copy + dots beneath the mark.
      final double usableHeight = math.max(constraints.maxHeight * 0.55, 28);
      scale = math.min(scale, usableHeight / preferredMark);
    }
    return scale.clamp(0.45, 1.0);
  }

  String _brandName(BuildContext context, AppBreakpoint breakpoint) {
    final l10n = context.l10n;
    return switch (breakpoint) {
      AppBreakpoint.xs ||
      AppBreakpoint.sm ||
      AppBreakpoint.md => l10n.appShortTitle,
      _ => l10n.appTitle,
    };
  }
}

class _LoadingMetrics {
  const _LoadingMetrics({
    required this.logoSize,
    required this.ringPadding,
    required this.gapAfterLogo,
    required this.copyMaxWidth,
    required this.brandStyle,
    required this.titleStyle,
  });

  final double logoSize;
  final double ringPadding;
  final double gapAfterLogo;
  final double copyMaxWidth;
  final TextStyle? Function(ThemeData theme) brandStyle;
  final TextStyle? Function(ThemeData theme) titleStyle;

  factory _LoadingMetrics.resolve({
    required AppLoadingIndicatorSize size,
    required AppBreakpoint breakpoint,
    required AppSpacingTokens spacing,
    double scale = 1,
  }) {
    final bool compactViewport =
        breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;
    final double clampedScale = scale.clamp(0.45, 1.0);

    final _LoadingMetrics base = switch (size) {
      AppLoadingIndicatorSize.compact => _LoadingMetrics(
        logoSize: 36,
        ringPadding: 10,
        gapAfterLogo: spacing.sm,
        copyMaxWidth: 240,
        brandStyle: (ThemeData theme) => theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleStyle: (ThemeData theme) =>
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      AppLoadingIndicatorSize.regular => _LoadingMetrics(
        logoSize: compactViewport ? 48 : 56,
        ringPadding: 14,
        gapAfterLogo: spacing.md,
        copyMaxWidth: 320,
        brandStyle: (ThemeData theme) => theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleStyle: (ThemeData theme) =>
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      AppLoadingIndicatorSize.large => _LoadingMetrics(
        logoSize: switch (breakpoint) {
          AppBreakpoint.xs || AppBreakpoint.sm => 64,
          AppBreakpoint.md => 72,
          _ => 84,
        },
        ringPadding: 18,
        gapAfterLogo: spacing.lg,
        copyMaxWidth: switch (breakpoint) {
          AppBreakpoint.xs || AppBreakpoint.sm => 280,
          AppBreakpoint.md => 360,
          _ => 420,
        },
        brandStyle: (ThemeData theme) => theme.textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.15),
        titleStyle: (ThemeData theme) =>
            theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      AppLoadingIndicatorSize.hero => _LoadingMetrics(
        logoSize: switch (breakpoint) {
          AppBreakpoint.xs || AppBreakpoint.sm => 72,
          AppBreakpoint.md => 88,
          _ => 104,
        },
        ringPadding: 22,
        gapAfterLogo: spacing.lg,
        copyMaxWidth: switch (breakpoint) {
          AppBreakpoint.xs || AppBreakpoint.sm => 300,
          AppBreakpoint.md => 400,
          _ => 480,
        },
        brandStyle: (ThemeData theme) {
          final TextStyle? brandBase = compactViewport
              ? theme.textTheme.headlineSmall
              : theme.textTheme.headlineMedium;
          return brandBase?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.15,
          );
        },
        titleStyle: (ThemeData theme) => theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    };

    if (clampedScale >= 0.999) {
      return base;
    }

    return _LoadingMetrics(
      logoSize: base.logoSize * clampedScale,
      ringPadding: base.ringPadding * clampedScale,
      gapAfterLogo: base.gapAfterLogo * clampedScale,
      copyMaxWidth: base.copyMaxWidth * clampedScale,
      brandStyle: base.brandStyle,
      titleStyle: base.titleStyle,
    );
  }
}

class _AnimatedLogoMark extends StatelessWidget {
  const _AnimatedLogoMark({
    required this.progress,
    required this.logoSize,
    required this.ringPadding,
    required this.colorScheme,
  });

  final double progress;
  final double logoSize;
  final double ringPadding;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final double breath = 0.5 + 0.5 * math.sin(progress * math.pi * 2);
    final double scale = 0.96 + (0.04 * breath);
    final double outerOpacity = 0.18 + (0.22 * breath);
    final double midOpacity = 0.28 + (0.24 * (1 - breath));
    final double markSize = logoSize + (ringPadding * 2);

    return SizedBox.square(
      dimension: markSize + 16,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.scale(
            scale: 0.92 + (0.18 * breath),
            child: Container(
              width: markSize + 12,
              height: markSize + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(
                  alpha: outerOpacity * 0.35,
                ),
              ),
            ),
          ),
          CustomPaint(
            size: Size.square(markSize + 8),
            painter: _SoftRingPainter(
              progress: progress,
              color: colorScheme.primary.withValues(alpha: midOpacity),
              trackColor: colorScheme.primary.withValues(alpha: 0.12),
              strokeWidth: 2.5,
            ),
          ),
          Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface.withValues(alpha: 0.92),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colorScheme.primary.withValues(
                      alpha: 0.12 + 0.1 * breath,
                    ),
                    blurRadius: 18 + (8 * breath),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(ringPadding * 0.55),
                child: AppLogo(
                  size: logoSize,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftRingPainter extends CustomPainter {
  const _SoftRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final Paint arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Soft sweeping arc — elegant motion without a harsh spinner.
    final double start = progress * math.pi * 2;
    canvas.drawArc(rect, start, math.pi * 1.15, false, arc);
  }

  @override
  bool shouldRepaint(covariant _SoftRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _SoftProgressDots extends StatelessWidget {
  const _SoftProgressDots({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (int index) {
        final double wave = (progress + (index * 0.18)) % 1.0;
        final double intensity =
            0.35 + (0.65 * (0.5 + 0.5 * math.sin(wave * math.pi * 2)));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Opacity(
            opacity: intensity.clamp(0.25, 1),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.55 + (0.45 * intensity)),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Full-bleed branded loading surface used for app startup and full-page loads.
class AppLoadingSurface extends StatelessWidget {
  const AppLoadingSurface({
    required this.child,
    this.safeArea = true,
    super.key,
  });

  final Widget child;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);

    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: switch (breakpoint) {
          AppBreakpoint.xs || AppBreakpoint.sm => theme.spacing.lg,
          AppBreakpoint.md => theme.spacing.xl,
          _ => theme.spacing.xxl,
        },
        vertical: switch (breakpoint) {
          AppBreakpoint.xs || AppBreakpoint.sm => theme.spacing.lg,
          _ => theme.spacing.xl,
        },
      ),
      child: child,
    );

    if (safeArea) {
      content = SafeArea(child: content);
    }

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colorScheme.primaryContainer.withValues(alpha: 0.55),
              colorScheme.surface,
              theme.scaffoldBackgroundColor,
            ],
            stops: const <double>[0, 0.42, 1],
          ),
        ),
        child: content,
      ),
    );
  }
}

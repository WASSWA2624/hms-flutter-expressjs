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
/// bounds and scales the logo + message down when that region is tight. Pass
/// `expand: false` only for intrinsic inline slots (e.g. field trailing icons).
///
/// A context-appropriate message is always shown below the logo unless this is
/// an intrinsic inline mark (`expand: false` with no [title]/[body]). Prefer
/// passing feature-specific [title]/[body]; otherwise size-based defaults are used.
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

  /// Feature-specific loading title. When null/blank, a size-based default is used.
  final String? title;

  /// Optional supporting copy under [title].
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
      return _buildContent(context);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool hasBoundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final bool hasBoundedWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite;

        // Scale the full mark + message together so tight parents never clip
        // the context copy under the logo.
        Widget centered = Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _buildContent(context),
          ),
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

  Widget _buildContent(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final _LoadingMetrics metrics = _LoadingMetrics.resolve(
      size: widget.size,
      breakpoint: breakpoint,
      spacing: theme.spacing,
    );
    final _LoadingCopy copy = _resolveCopy(context);
    // Intrinsic inline marks stay logo-only (no title/body/dots).
    final bool markOnly = !widget.expand &&
        copy.title == null &&
        copy.body == null &&
        !widget.showBrandName;

    return Semantics(
      label: widget.semanticLabel ?? copy.title ?? 'Loading',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
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
              if (copy.title != null) ...<Widget>[
                SizedBox(
                  height: widget.showBrandName
                      ? theme.spacing.sm
                      : metrics.gapAfterLogo,
                ),
                Text(
                  copy.title!,
                  textAlign: TextAlign.center,
                  style: metrics.titleStyle(theme),
                ),
              ],
              if (copy.body != null) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: metrics.copyMaxWidth),
                  child: Text(
                    copy.body!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              if (!markOnly) ...<Widget>[
                SizedBox(height: theme.spacing.md),
                _SoftProgressDots(
                  progress: _controller.value,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Resolves the message shown under the logo for the current loading context.
  ///
  /// Explicit [AppLoadingIndicator.title]/[AppLoadingIndicator.body] win.
  /// Otherwise size-based localized defaults are used. Intrinsic inline marks
  /// (`expand: false` with no copy) stay mark-only.
  _LoadingCopy _resolveCopy(BuildContext context) {
    final String? explicitTitle = _trimmedOrNull(widget.title);
    final String? explicitBody = _trimmedOrNull(widget.body);
    final bool hasExplicitTitle = explicitTitle != null;
    final bool hasExplicitBody = explicitBody != null;

    if (!widget.expand && !hasExplicitTitle && !hasExplicitBody) {
      return const _LoadingCopy();
    }

    final l10n = context.l10n;
    final String title =
        explicitTitle ??
        switch (widget.size) {
          AppLoadingIndicatorSize.compact => l10n.commonLoadingCompactTitle,
          AppLoadingIndicatorSize.regular => l10n.commonLoadingTitle,
          AppLoadingIndicatorSize.large => l10n.commonLoadingTitle,
          AppLoadingIndicatorSize.hero => l10n.startupLoadingTitle,
        };

    final String? body =
        explicitBody ??
        (hasExplicitTitle
            ? null
            : switch (widget.size) {
                AppLoadingIndicatorSize.compact => null,
                AppLoadingIndicatorSize.regular => l10n.commonLoadingBody,
                AppLoadingIndicatorSize.large => l10n.commonLoadingBody,
                AppLoadingIndicatorSize.hero => l10n.startupLoadingBody,
              });

    return _LoadingCopy(title: title, body: body);
  }

  static String? _trimmedOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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

class _LoadingCopy {
  const _LoadingCopy({this.title, this.body});

  final String? title;
  final String? body;
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
  }) {
    final bool compactViewport =
        breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;

    return switch (size) {
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

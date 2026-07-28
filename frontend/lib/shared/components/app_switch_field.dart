import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_field_error_text.dart';

/// Themed glassmorphism on/off field with optional title, subtitle, and leading
/// icon. Scales padding, radius, and switch size across breakpoints.
class AppSwitchField extends StatelessWidget {
  const AppSwitchField({
    required this.title,
    required this.value,
    this.onChanged,
    this.subtitle,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.secondary,
    this.contentPadding,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<bool>? validator;
  final FormFieldSetter<bool>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canChange = enabled;

    return FormField<bool>(
      key: ValueKey<bool>(value),
      initialValue: value,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      forceErrorText: errorText,
      builder: (FormFieldState<bool> field) {
        final bool fieldValue = field.value ?? false;

        void toggle(bool next) {
          if (!canChange) {
            return;
          }
          field.didChange(next);
          onChanged?.call(next);
        }

        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _GlassSwitchTile(
              title: title,
              subtitle: subtitle,
              value: fieldValue,
              enabled: canChange,
              secondary: secondary,
              contentPadding: contentPadding,
              onChanged: canChange ? toggle : null,
            ),
            if (field.errorText != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              AppFieldErrorText(errorText: field.errorText),
            ],
          ],
        );

        if (semanticLabel != null) {
          content = Semantics(
            toggled: fieldValue,
            enabled: canChange,
            label: semanticLabel,
            child: content,
          );
        }

        return content;
      },
    );
  }
}

@immutable
final class _GlassSwitchMetrics {
  const _GlassSwitchMetrics({
    required this.padding,
    required this.gap,
    required this.radius,
    required this.iconSize,
    required this.iconWellSize,
    required this.trackWidth,
    required this.trackHeight,
    required this.thumbSize,
    required this.blurSigma,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  factory _GlassSwitchMetrics.of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final TextTheme textTheme = theme.textTheme;

    final double pad = switch (breakpoint) {
      AppBreakpoint.xs => theme.spacing.sm,
      AppBreakpoint.sm => theme.spacing.md,
      AppBreakpoint.md => theme.spacing.lg,
      AppBreakpoint.lg || AppBreakpoint.xl || AppBreakpoint.xxl =>
        theme.spacing.xl,
    };
    final double gap = switch (breakpoint) {
      AppBreakpoint.xs || AppBreakpoint.sm => theme.spacing.sm,
      _ => theme.spacing.md,
    };
    final double trackWidth = switch (breakpoint) {
      AppBreakpoint.xs => 46,
      AppBreakpoint.sm => 50,
      AppBreakpoint.md => 52,
      _ => 56,
    };
    final double trackHeight = switch (breakpoint) {
      AppBreakpoint.xs => 28,
      AppBreakpoint.sm => 30,
      _ => 32,
    };
    final double thumbSize = trackHeight - 6;
    final double iconWellSize = switch (breakpoint) {
      AppBreakpoint.xs => 36,
      AppBreakpoint.sm => 40,
      _ => 44,
    };
    final double iconSize = switch (breakpoint) {
      AppBreakpoint.xs => 18,
      AppBreakpoint.sm => 20,
      _ => 22,
    };
    final double blurSigma = switch (breakpoint) {
      AppBreakpoint.xs || AppBreakpoint.sm => 12,
      _ => 18,
    };

    return _GlassSwitchMetrics(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.85),
      gap: gap,
      radius: context.responsiveRadius(theme.radius.xxl),
      iconSize: iconSize,
      iconWellSize: iconWellSize,
      trackWidth: trackWidth,
      trackHeight: trackHeight,
      thumbSize: thumbSize,
      blurSigma: blurSigma,
      titleStyle: (textTheme.titleSmall ?? textTheme.bodyLarge)!.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      subtitleStyle: (textTheme.bodySmall ?? textTheme.labelMedium)!.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w400,
        height: 1.3,
      ),
    );
  }

  final EdgeInsets padding;
  final double gap;
  final double radius;
  final double iconSize;
  final double iconWellSize;
  final double trackWidth;
  final double trackHeight;
  final double thumbSize;
  final double blurSigma;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
}

class _GlassSwitchTile extends StatelessWidget {
  const _GlassSwitchTile({
    required this.title,
    required this.value,
    required this.enabled,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final _GlassSwitchMetrics metrics = _GlassSwitchMetrics.of(context);

    final Color glassFill = isDark
        ? colors.surface.withValues(alpha: 0.42)
        : colors.surface.withValues(alpha: 0.62);
    final Color glassBorder = isDark
        ? colors.onSurface.withValues(alpha: 0.14)
        : colors.onSurface.withValues(alpha: 0.10);
    final Color glassHighlight = isDark
        ? colors.onSurface.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.55);
    final List<BoxShadow> glassShadow = <BoxShadow>[
      BoxShadow(
        color: colors.shadow.withValues(alpha: isDark ? 0.35 : 0.10),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];

    final BorderRadius radius = BorderRadius.circular(metrics.radius);

    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (secondary != null) ...<Widget>[
          _GlassWell(
            size: metrics.iconWellSize,
            child: IconTheme(
              data: IconThemeData(
                color: colors.onSurface.withValues(alpha: enabled ? 0.88 : 0.45),
                size: metrics.iconSize,
              ),
              child: secondary!,
            ),
          ),
          SizedBox(width: metrics.gap),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: metrics.titleStyle.copyWith(
                  color: metrics.titleStyle.color?.withValues(
                    alpha: enabled ? 1 : 0.55,
                  ),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                Text(
                  subtitle!,
                  style: metrics.subtitleStyle.copyWith(
                    color: metrics.subtitleStyle.color?.withValues(
                      alpha: enabled ? 1 : 0.5,
                    ),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: metrics.gap),
        // Visual-only: the parent InkWell owns the tap to avoid double toggles.
        IgnorePointer(
          child: _GlassToggle(
            value: value,
            enabled: enabled,
            metrics: metrics,
          ),
        ),
      ],
    );

    row = Padding(
      padding: contentPadding ?? metrics.padding,
      child: row,
    );

    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: glassShadow,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: metrics.blurSigma,
                sigmaY: metrics.blurSigma,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      glassHighlight,
                      glassFill,
                    ],
                  ),
                  border: Border.all(color: glassBorder, width: 1),
                ),
                child: InkWell(
                  onTap: onChanged == null ? null : () => onChanged!(!value),
                  borderRadius: radius,
                  child: row,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassWell extends StatelessWidget {
  const _GlassWell({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.onSurface.withValues(alpha: isDark ? 0.08 : 0.04),
          border: Border.all(
            color: colors.onSurface.withValues(alpha: isDark ? 0.12 : 0.08),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
              spreadRadius: -1,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _GlassToggle extends StatelessWidget {
  const _GlassToggle({
    required this.value,
    required this.enabled,
    required this.metrics,
  });

  final bool value;
  final bool enabled;
  final _GlassSwitchMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Brand teal accent for the active track (matches the glass sample).
    final Color activeTrack = colors.tertiary;
    final Color inactiveTrack = isDark
        ? colors.surfaceContainerHighest.withValues(alpha: 0.72)
        : colors.surfaceContainerHighest.withValues(alpha: 0.95);
    final Color activeThumb = colors.onTertiary;
    final Color inactiveThumb = isDark ? colors.onSurface : Colors.white;

    return SizedBox(
      width: metrics.trackWidth + 8,
      height: metrics.trackHeight + 8,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.55,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: metrics.trackWidth,
            height: metrics.trackHeight,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? activeTrack : inactiveTrack,
              borderRadius: BorderRadius.circular(metrics.trackHeight),
              boxShadow: <BoxShadow>[
                if (value)
                  BoxShadow(
                    color: activeTrack.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: metrics.thumbSize,
                height: metrics.thumbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? activeThumb : inactiveThumb,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

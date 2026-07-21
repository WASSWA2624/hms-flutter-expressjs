import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';

enum AppButtonVariant { primary, secondary, tertiary }

const Duration _buttonAnimationDuration = Duration(milliseconds: 140);

/// Borderless action button: icon + label (or icon-only in compact toolbars).
class AppButton extends StatelessWidget {
  AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    this.iconOnly = false,
    this.color,
    this.iconWidget,
    this.labelWidget,
    super.key,
  }) : assert(
         iconOnly || label.isNotEmpty,
         'Labeled buttons require a non-empty label.',
       );

  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    this.iconOnly = false,
    this.color,
    this.iconWidget,
    this.labelWidget,
    super.key,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    this.iconOnly = false,
    this.color,
    this.iconWidget,
    this.labelWidget,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.tertiary({
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    this.iconOnly = false,
    this.color,
    this.iconWidget,
    this.labelWidget,
    super.key,
  }) : variant = AppButtonVariant.tertiary;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;
  final bool fullWidth;
  final String? semanticLabel;
  final String? tooltip;
  final bool autofocus;
  final bool iconOnly;
  final Color? color;
  final Widget? iconWidget;

  /// Optional rich label. When set, replaces the default [Text] while [label]
  /// remains the semantic/findable string.
  final Widget? labelWidget;

  IconData? get _resolvedIcon => leadingIcon ?? icon;

  /// Icon-only trigger for [PopupMenuButton] and [MenuAnchor] overflow menus.
  static Widget popupMenuTrigger({
    required BuildContext context,
    required IconData icon,
    required String semanticLabel,
    Color? color,
    VoidCallback? onPressed,
    int attentionCount = 0,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double iconSize = theme.appTokens.listIconSize;
    final Widget? iconWidget = attentionCount > 0
        ? Badge(
            isLabelVisible: false,
            backgroundColor: colorScheme.error,
            smallSize: 8,
            child: Icon(icon, size: iconSize),
          )
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AppButton(
        iconOnly: true,
        icon: icon,
        label: semanticLabel,
        semanticLabel: semanticLabel,
        tooltip: semanticLabel,
        color: color,
        iconWidget: iconWidget,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppActionLabelScope? labelScope = AppActionLabelScope.maybeOf(
      context,
    );
    final bool compactIconOnly =
        iconOnly ||
        (labelScope?.forceIconOnly == true && _resolvedIcon != null);
    final bool showLabel = !compactIconOnly;

    final bool canPress = enabled && !isLoading && onPressed != null;
    final Widget button = showLabel
        ? _buildLabeledButton(context, canPress)
        : _buildIconOnlyButton(context, canPress);
    final Widget sizedButton = fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
    final String resolvedLabel = semanticLabel ?? label;

    final Widget semanticButton = Semantics(
      button: true,
      enabled: canPress,
      label: resolvedLabel,
      liveRegion: isLoading,
      child: sizedButton,
    );

    final String? resolvedTooltip = tooltip;
    if (resolvedTooltip == null) {
      return semanticButton;
    }

    return Tooltip(message: resolvedTooltip, child: semanticButton);
  }

  Widget _buildIconOnlyButton(BuildContext context, bool canPress) {
    final ThemeData theme = Theme.of(context);
    final double iconSize = theme.appTokens.listIconSize;
    final Color foregroundColor = _foregroundColor(theme, variant);

    return TextButton(
      onPressed: canPress ? onPressed : null,
      autofocus: autofocus,
      style: _buttonStyle(context, variant, iconOnly: true),
      child: _ButtonGlyph(
        icon: _resolvedIcon,
        iconSize: iconSize,
        isLoading: isLoading,
        loadingColor: foregroundColor,
        iconWidget: iconWidget,
      ),
    );
  }

  Widget _buildLabeledButton(BuildContext context, bool canPress) {
    final ThemeData theme = Theme.of(context);
    final Color foregroundColor = _foregroundColor(theme, variant);

    return TextButton(
      onPressed: canPress ? onPressed : null,
      autofocus: autofocus,
      style: _buttonStyle(context, variant, iconOnly: false),
      child: _ButtonContent(
        label: label,
        labelWidget: labelWidget,
        leadingIcon: _resolvedIcon,
        isLoading: isLoading,
        loadingColor: foregroundColor,
        iconWidget: iconWidget,
      ),
    );
  }

  ButtonStyle _buttonStyle(
    BuildContext context,
    AppButtonVariant variant, {
    required bool iconOnly,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacingTokens spacing = theme.spacing;
    final double viewportWidth = MediaQuery.sizeOf(context).width;
    final bool compact = viewportWidth < 360;
    final EdgeInsetsGeometry padding = iconOnly
        ? EdgeInsets.all(spacing.xs)
        : EdgeInsets.symmetric(
            horizontal: compact ? spacing.md : spacing.lg,
            vertical: spacing.sm,
          );
    final double minimumDimension = math.max(
      theme.appTokens.minInteractiveDimension,
      theme.appTokens.listIconSize + spacing.lg,
    );

    return ButtonStyle(
      animationDuration: _buttonAnimationDuration,
      enableFeedback: true,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.center,
      minimumSize: WidgetStatePropertyAll<Size>(
        iconOnly
            ? Size.square(minimumDimension)
            : Size(spacing.none, theme.appTokens.minInteractiveDimension),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            context.responsiveRadius(theme.radius.sm),
          ),
        ),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle?>(
        theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        final Color base = _foregroundColor(theme, variant);
        if (states.contains(WidgetState.pressed)) {
          return _emphasizedForeground(base, colorScheme, strong: true);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _emphasizedForeground(base, colorScheme, strong: false);
        }
        return base;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        if (variant == AppButtonVariant.primary) {
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.primary.withValues(alpha: 0.22);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colorScheme.primary.withValues(alpha: 0.16);
          }
          return colorScheme.primary.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.pressed)) {
          return colorScheme.surfaceContainerHigh.withValues(alpha: 0.72);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return colorScheme.surfaceContainerHighest.withValues(alpha: 0.56);
        }
        return Colors.transparent;
      }),
      overlayColor: const WidgetStatePropertyAll<Color?>(null),
      side: WidgetStateProperty.resolveWith<BorderSide?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.focused) &&
            variant != AppButtonVariant.primary) {
          return BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.72),
            width: 1.25,
          );
        }
        if (variant == AppButtonVariant.primary) {
          final double alpha = states.contains(WidgetState.disabled)
              ? 0.24
              : 0.72;
          return BorderSide(
            color: colorScheme.primary.withValues(alpha: alpha),
            width: 1.75,
          );
        }
        if (variant == AppButtonVariant.secondary) {
          final double alpha = states.contains(WidgetState.disabled)
              ? 0.2
              : 0.42;
          return BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: alpha),
            width: 1.5,
          );
        }
        return BorderSide.none;
      }),
    );
  }

  Color _foregroundColor(ThemeData theme, AppButtonVariant variant) {
    if (color != null) {
      return color!;
    }

    final ColorScheme colorScheme = theme.colorScheme;
    return switch (variant) {
      AppButtonVariant.primary => colorScheme.primary,
      AppButtonVariant.secondary => colorScheme.onSurfaceVariant,
      AppButtonVariant.tertiary => colorScheme.primary,
    };
  }

  Color _emphasizedForeground(
    Color base,
    ColorScheme colorScheme, {
    required bool strong,
  }) {
    if (base == colorScheme.onSurfaceVariant) {
      return strong
          ? colorScheme.primary
          : colorScheme.primary.withValues(alpha: 0.88);
    }
    if (base == colorScheme.primary) {
      return strong
          ? colorScheme.primary
          : colorScheme.primary.withValues(alpha: 0.88);
    }
    return strong ? base : base.withValues(alpha: 0.88);
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.leadingIcon,
    required this.isLoading,
    required this.loadingColor,
    this.iconWidget,
    this.labelWidget,
  });

  final String label;
  final Widget? labelWidget;
  final IconData? leadingIcon;
  final bool isLoading;
  final Color loadingColor;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    final double iconSize = theme.appTokens.listIconSize;
    final TextStyle? labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 14,
    );
    final Widget labelText = labelWidget ??
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: labelStyle,
        );

    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox.square(
            dimension: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
            ),
          ),
          SizedBox(width: spacing.sm),
          Flexible(child: labelText),
        ],
      );
    }

    if (leadingIcon == null && iconWidget == null) {
      return labelText;
    }

    // `Flexible` lets the label ellipsize when the button is width-constrained
    // while staying intrinsic-safe. A `LayoutBuilder` here would throw
    // "LayoutBuilder does not support returning intrinsic dimensions" whenever
    // the button is measured for intrinsics (e.g. inside a DataTable cell,
    // which sizes columns with IntrinsicColumnWidth).
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _ButtonGlyph(
          icon: leadingIcon,
          iconSize: iconSize,
          isLoading: isLoading,
          loadingColor: loadingColor,
          iconWidget: iconWidget,
        ),
        SizedBox(width: spacing.sm),
        Flexible(child: labelText),
      ],
    );
  }
}

class _ButtonGlyph extends StatelessWidget {
  const _ButtonGlyph({
    required this.icon,
    required this.iconSize,
    required this.isLoading,
    required this.loadingColor,
    this.iconWidget,
  });

  final IconData? icon;
  final double iconSize;
  final bool isLoading;
  final Color loadingColor;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    if (iconWidget != null && !isLoading) {
      return iconWidget!;
    }

    return AnimatedSwitcher(
      duration: _buttonAnimationDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: isLoading
          ? SizedBox.square(
              key: const ValueKey<String>('loading'),
              dimension: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
              ),
            )
          : Icon(icon, key: const ValueKey<String>('icon'), size: iconSize),
    );
  }
}

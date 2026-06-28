import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

const Duration _ghostActionAnimationDuration = Duration(milliseconds: 140);
const OutlinedBorder _ghostActionShape = RoundedRectangleBorder();

/// Borderless toolbar/header action: leading icon + label, transparent background.
class AppGhostActionButton extends StatelessWidget {
  const AppGhostActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    this.color,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final String? semanticLabel;
  final String? tooltip;
  final bool autofocus;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canPress = enabled && !isLoading && onPressed != null;
    final double iconSize = theme.appTokens.listIconSize;
    final Color foregroundColor = color ?? theme.colorScheme.onSurfaceVariant;
    final AppSpacingTokens spacing = theme.spacing;

    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox.square(
          dimension: iconSize,
          child: isLoading
              ? CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                )
              : Icon(icon, size: iconSize),
        ),
        SizedBox(width: spacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );

    final Widget button = TextButton(
      onPressed: canPress ? onPressed : null,
      autofocus: autofocus,
      style: _ghostActionButtonStyle(
        theme: theme,
        foregroundColor: foregroundColor,
      ),
      child: child,
    );

    final Widget semanticButton = Semantics(
      button: true,
      enabled: canPress,
      label: semanticLabel ?? label,
      liveRegion: isLoading,
      child: button,
    );

    final String resolvedTooltip = tooltip ?? semanticLabel ?? label;

    return Tooltip(message: resolvedTooltip, child: semanticButton);
  }

  static ButtonStyle _ghostActionButtonStyle({
    required ThemeData theme,
    required Color foregroundColor,
  }) {
    final ColorScheme colorScheme = theme.colorScheme;
    final double minimumHeight = theme.appTokens.minInteractiveDimension;

    return ButtonStyle(
      animationDuration: _ghostActionAnimationDuration,
      enableFeedback: true,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.center,
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(0, minimumHeight),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(_ghostActionShape),
      textStyle: WidgetStatePropertyAll<TextStyle?>(
        theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        return foregroundColor;
      }),
      backgroundColor: const WidgetStatePropertyAll<Color?>(Colors.transparent),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.pressed)) {
          return foregroundColor.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.focused)) {
          return foregroundColor.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return foregroundColor.withValues(alpha: 0.08);
        }
        return null;
      }),
      side: const WidgetStatePropertyAll<BorderSide?>(BorderSide.none),
    );
  }

  /// Icon-only trigger styled like [AppIconButton] for [PopupMenuButton] children.
  static Widget popupMenuTrigger({
    required BuildContext context,
    required IconData icon,
    required String semanticLabel,
    Color? color,
  }) {
    final ThemeData theme = Theme.of(context);
    final double iconSize = theme.appTokens.listIconSize;
    final Color foregroundColor = color ?? theme.colorScheme.onSurfaceVariant;
    final double minimumDimension = math.max(
      theme.appTokens.minInteractiveDimension,
      iconSize + theme.spacing.lg,
    );

    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton(
        tooltip: semanticLabel,
        onPressed: null,
        style: ButtonStyle(
          animationDuration: _ghostActionAnimationDuration,
          enableFeedback: true,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: WidgetStatePropertyAll<Size>(
            Size.square(minimumDimension),
          ),
          padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.all(theme.spacing.xs),
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(_ghostActionShape),
          foregroundColor: WidgetStatePropertyAll<Color?>(foregroundColor),
          backgroundColor:
              const WidgetStatePropertyAll<Color?>(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.pressed)) {
              return foregroundColor.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.focused)) {
              return foregroundColor.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return foregroundColor.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
        iconSize: iconSize,
        icon: Icon(icon),
      ),
    );
  }
}

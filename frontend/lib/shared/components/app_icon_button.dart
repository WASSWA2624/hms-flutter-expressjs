import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';
import 'package:hosspi_hms/shared/components/app_ghost_action_button.dart';

const Duration _iconButtonAnimationDuration = Duration(milliseconds: 140);
const OutlinedBorder _iconButtonShape = RoundedRectangleBorder();

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.tooltip,
    this.enabled = true,
    this.isLoading = false,
    this.autofocus = false,
    this.color,
    this.size,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool enabled;
  final bool isLoading;
  final bool autofocus;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canPress = enabled && !isLoading && onPressed != null;
    final double iconSize = size ?? theme.appTokens.listIconSize;
    final Color foregroundColor = color ?? theme.colorScheme.onSurfaceVariant;
    final AppActionLabelScope? labelScope = AppActionLabelScope.maybeOf(
      context,
    );

    if (labelScope?.showLabels == true) {
      return AppGhostActionButton(
        label: semanticLabel,
        icon: icon,
        enabled: enabled,
        isLoading: isLoading,
        semanticLabel: semanticLabel,
        tooltip: tooltip,
        autofocus: autofocus,
        onPressed: onPressed,
        color: color,
      );
    }

    return Semantics(
      button: true,
      enabled: canPress,
      label: semanticLabel,
      liveRegion: isLoading,
      child: IconButton(
        tooltip: tooltip ?? semanticLabel,
        onPressed: canPress ? onPressed : null,
        autofocus: autofocus,
        style: _iconButtonStyle(
          theme: theme,
          foregroundColor: foregroundColor,
          iconSize: iconSize,
        ),
        iconSize: iconSize,
        icon: AnimatedSwitcher(
          duration: _iconButtonAnimationDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: isLoading
              ? SizedBox.square(
                  key: const ValueKey<String>('loading'),
                  dimension: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              : Icon(icon, key: const ValueKey<String>('icon')),
        ),
      ),
    );
  }

  ButtonStyle _iconButtonStyle({
    required ThemeData theme,
    required Color foregroundColor,
    required double iconSize,
  }) {
    final ColorScheme colorScheme = theme.colorScheme;
    final double minimumDimension = math.max(
      theme.appTokens.minInteractiveDimension,
      iconSize + theme.spacing.lg,
    );

    return ButtonStyle(
      animationDuration: _iconButtonAnimationDuration,
      enableFeedback: true,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: WidgetStatePropertyAll<Size>(Size.square(minimumDimension)),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.all(theme.spacing.xs),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(_iconButtonShape),
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
    );
  }
}

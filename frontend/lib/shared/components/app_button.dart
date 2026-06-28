import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';
import 'package:hosspi_hms/shared/components/app_ghost_action_button.dart';

enum AppButtonVariant { primary, secondary, tertiary }

const Duration _buttonAnimationDuration = Duration(milliseconds: 140);
const OutlinedBorder _buttonShape = RoundedRectangleBorder();

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    super.key,
  });

  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    super.key,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.tertiary({
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    super.key,
  }) : variant = AppButtonVariant.tertiary;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final bool isLoading;
  final bool enabled;
  final bool fullWidth;
  final String? semanticLabel;
  final String? tooltip;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final AppActionLabelScope? labelScope = AppActionLabelScope.maybeOf(
      context,
    );
    if (labelScope?.forceIconOnly == true && leadingIcon != null) {
      return _buildIconOnlyButton(context);
    }

    if (labelScope?.showLabels == true &&
        variant == AppButtonVariant.secondary) {
      return AppGhostActionButton(
        label: label,
        icon: leadingIcon ?? Icons.touch_app_outlined,
        enabled: enabled,
        isLoading: isLoading,
        semanticLabel: semanticLabel,
        tooltip: tooltip,
        autofocus: autofocus,
        onPressed: onPressed,
      );
    }

    final bool canPress = enabled && !isLoading && onPressed != null;
    final Widget button = _buildButton(context, canPress);
    final Widget sizedButton = fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
    final Widget semanticButton = Semantics(
      button: true,
      enabled: canPress,
      label: semanticLabel ?? label,
      liveRegion: isLoading,
      child: sizedButton,
    );

    if (tooltip == null) {
      return semanticButton;
    }

    return Tooltip(message: tooltip!, child: semanticButton);
  }

  Widget _buildIconOnlyButton(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canPress = enabled && !isLoading && onPressed != null;
    final String label = semanticLabel ?? this.label;
    final double iconSize = theme.appTokens.listIconSize;
    final Color foregroundColor = _buttonForegroundColor(theme, variant);

    return Semantics(
      button: true,
      enabled: canPress,
      label: label,
      liveRegion: isLoading,
      child: IconButton(
        tooltip: tooltip ?? label,
        onPressed: canPress ? onPressed : null,
        autofocus: autofocus,
        style: _iconOnlyButtonStyle(context),
        iconSize: iconSize,
        icon: _ButtonGlyph(
          icon: leadingIcon,
          iconSize: iconSize,
          isLoading: isLoading,
          loadingColor: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, bool canPress) {
    final ThemeData theme = Theme.of(context);
    final Widget child = _ButtonContent(
      label: label,
      leadingIcon: leadingIcon,
      isLoading: isLoading,
      loadingColor: _buttonForegroundColor(theme, variant),
    );
    final ButtonStyle style = _buttonStyle(context, variant);

    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: canPress ? onPressed : null,
        autofocus: autofocus,
        style: style,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: canPress ? onPressed : null,
        autofocus: autofocus,
        style: style,
        child: child,
      ),
      AppButtonVariant.tertiary => TextButton(
        onPressed: canPress ? onPressed : null,
        autofocus: autofocus,
        style: style,
        child: child,
      ),
    };
  }

  ButtonStyle _buttonStyle(BuildContext context, AppButtonVariant variant) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacingTokens spacing = theme.spacing;
    final double viewportWidth = MediaQuery.sizeOf(context).width;
    final bool compact = viewportWidth < 360;
    final EdgeInsetsGeometry padding = EdgeInsets.symmetric(
      horizontal: compact ? spacing.md : spacing.lg,
      vertical: spacing.sm,
    );
    final Color foregroundColor = _buttonForegroundColor(theme, variant);
    final Color overlayBaseColor = switch (variant) {
      AppButtonVariant.primary => colorScheme.onPrimary,
      AppButtonVariant.secondary ||
      AppButtonVariant.tertiary => foregroundColor,
    };

    return ButtonStyle(
      animationDuration: _buttonAnimationDuration,
      enableFeedback: true,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.center,
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(spacing.none, theme.appTokens.minInteractiveDimension),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(_buttonShape),
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
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return switch (variant) {
            AppButtonVariant.primary => colorScheme.onSurface.withValues(
              alpha: 0.08,
            ),
            AppButtonVariant.secondary ||
            AppButtonVariant.tertiary => Colors.transparent,
          };
        }
        if (variant == AppButtonVariant.secondary &&
            states.contains(WidgetState.hovered)) {
          return colorScheme.primary.withValues(alpha: 0.05);
        }
        if (variant == AppButtonVariant.secondary &&
            states.contains(WidgetState.pressed)) {
          return colorScheme.primary.withValues(alpha: 0.08);
        }
        return switch (variant) {
          AppButtonVariant.primary => colorScheme.primary,
          AppButtonVariant.secondary ||
          AppButtonVariant.tertiary => Colors.transparent,
        };
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.pressed)) {
          return overlayBaseColor.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.focused)) {
          return overlayBaseColor.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return overlayBaseColor.withValues(alpha: 0.08);
        }
        return null;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide?>((
        Set<WidgetState> states,
      ) {
        if (variant != AppButtonVariant.secondary) {
          return BorderSide.none;
        }
        final bool disabled = states.contains(WidgetState.disabled);
        final bool focused = states.contains(WidgetState.focused);
        final bool hovered = states.contains(WidgetState.hovered);
        final Color borderColor = disabled
            ? colorScheme.onSurface.withValues(alpha: 0.12)
            : focused
            ? colorScheme.primary.withValues(alpha: 0.72)
            : hovered
            ? colorScheme.primary.withValues(alpha: 0.56)
            : colorScheme.outline.withValues(alpha: 0.44);
        return BorderSide(color: borderColor, width: focused ? 1.25 : 1);
      }),
    );
  }

  ButtonStyle _iconOnlyButtonStyle(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color foregroundColor = _buttonForegroundColor(theme, variant);
    // The primary variant is a high-emphasis CTA (for example "Add staff").
    // When collapsed to icon-only inside compact action bars it must stay a
    // clearly visible, filled control in both light and dark themes rather
    // than fading into a low-contrast plain glyph.
    final bool filled = variant == AppButtonVariant.primary;
    final Color overlayBaseColor = filled
        ? colorScheme.onPrimary
        : foregroundColor;

    return ButtonStyle(
      animationDuration: _buttonAnimationDuration,
      enableFeedback: true,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: WidgetStatePropertyAll<Size>(
        Size.square(theme.appTokens.minInteractiveDimension),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.all(theme.spacing.xs),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(_buttonShape),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        return foregroundColor;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (!filled) {
          return Colors.transparent;
        }
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.08);
        }
        return colorScheme.primary;
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.pressed)) {
          return overlayBaseColor.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.focused)) {
          return overlayBaseColor.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return overlayBaseColor.withValues(alpha: 0.08);
        }
        return null;
      }),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.leadingIcon,
    required this.isLoading,
    required this.loadingColor,
  });

  final String label;
  final IconData? leadingIcon;
  final bool isLoading;
  final Color loadingColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    final double iconSize = theme.appTokens.listIconSize;
    final Widget labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );

    if (!isLoading && leadingIcon == null) {
      return labelText;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Only flex the label when the button has a bounded width so it can
        // ellipsize instead of overflowing. Under unbounded constraints the
        // label keeps its intrinsic size to avoid RenderFlex flex errors.
        final Widget label = constraints.maxWidth.isFinite
            ? Flexible(child: labelText)
            : labelText;
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _ButtonGlyph(
              icon: leadingIcon,
              iconSize: iconSize,
              isLoading: isLoading,
              loadingColor: loadingColor,
            ),
            SizedBox(width: spacing.sm),
            label,
          ],
        );
      },
    );
  }
}

class _ButtonGlyph extends StatelessWidget {
  const _ButtonGlyph({
    required this.icon,
    required this.iconSize,
    required this.isLoading,
    required this.loadingColor,
  });

  final IconData? icon;
  final double iconSize;
  final bool isLoading;
  final Color loadingColor;

  @override
  Widget build(BuildContext context) {
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

Color _buttonForegroundColor(ThemeData theme, AppButtonVariant variant) {
  return switch (variant) {
    AppButtonVariant.primary => theme.colorScheme.onPrimary,
    AppButtonVariant.secondary ||
    AppButtonVariant.tertiary => theme.colorScheme.primary,
  };
}

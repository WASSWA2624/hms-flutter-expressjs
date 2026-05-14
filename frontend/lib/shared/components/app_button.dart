import 'package:flutter/material.dart';
import 'package:flutter_template/app/theme/app_theme_extensions.dart';

enum AppButtonVariant { primary, secondary, tertiary }

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

  Widget _buildButton(BuildContext context, bool canPress) {
    final Widget child = _ButtonContent(
      label: label,
      leadingIcon: leadingIcon,
      isLoading: isLoading,
    );

    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: canPress ? onPressed : null,
        autofocus: autofocus,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: canPress ? onPressed : null,
        autofocus: autofocus,
        child: child,
      ),
      AppButtonVariant.tertiary => TextButton(
        onPressed: canPress ? onPressed : null,
        autofocus: autofocus,
        child: child,
      ),
    };
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.leadingIcon,
    required this.isLoading,
  });

  final String label;
  final IconData? leadingIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;

    if (!isLoading && leadingIcon == null) {
      return Text(label, overflow: TextOverflow.ellipsis);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (isLoading)
          SizedBox.square(
            dimension: theme.appTokens.listIconSize,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(leadingIcon, size: theme.appTokens.listIconSize),
        SizedBox(width: spacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

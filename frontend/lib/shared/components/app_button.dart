import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';

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
    final AppActionLabelScope? labelScope = AppActionLabelScope.maybeOf(
      context,
    );
    if (labelScope?.forceIconOnly == true && leadingIcon != null) {
      return _buildIconOnlyButton(context);
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

    return Semantics(
      button: true,
      enabled: canPress,
      label: label,
      liveRegion: isLoading,
      child: IconButton(
        tooltip: tooltip ?? label,
        onPressed: canPress ? onPressed : null,
        autofocus: autofocus,
        iconSize: theme.appTokens.listIconSize,
        icon: isLoading
            ? SizedBox.square(
                dimension: theme.appTokens.listIconSize,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(leadingIcon),
      ),
    );
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

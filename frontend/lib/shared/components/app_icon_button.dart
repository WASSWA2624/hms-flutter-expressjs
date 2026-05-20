import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

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
    final AppActionLabelScope? labelScope = AppActionLabelScope.maybeOf(
      context,
    );

    if (labelScope?.showLabels == true) {
      return AppButton.secondary(
        label: semanticLabel,
        leadingIcon: icon,
        enabled: enabled,
        isLoading: isLoading,
        semanticLabel: semanticLabel,
        tooltip: tooltip,
        autofocus: autofocus,
        onPressed: onPressed,
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
        color: color,
        iconSize: size ?? theme.appTokens.listIconSize,
        icon: isLoading
            ? SizedBox.square(
                dimension: theme.appTokens.listIconSize,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
      ),
    );
  }
}

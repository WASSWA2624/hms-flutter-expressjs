import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

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

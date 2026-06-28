import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

class AuthTextLink extends StatefulWidget {
  const AuthTextLink({
    required this.label,
    required this.onPressed,
    this.alignment = Alignment.center,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Alignment alignment;

  @override
  State<AuthTextLink> createState() => _AuthTextLinkState();
}

class _AuthTextLinkState extends State<AuthTextLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool enabled = widget.onPressed != null;
    final Color color = enabled
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return Align(
      alignment: widget.alignment,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: TextButton(
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.xs,
            ),
            foregroundColor: color,
            textStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              decoration: _isHovered && enabled
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationColor: color,
            ),
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

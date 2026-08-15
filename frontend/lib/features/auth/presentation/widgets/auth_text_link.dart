import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

class AuthTextLink extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Align(
      alignment: alignment,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: AppFontWeight.emphasis,
            fontSize: 14,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Footer links for auth pages, kept on one horizontal row at every width.
///
/// Labels shrink together rather than stacking so the links read as a single
/// group under the primary action on phones and desktop alike.
class AuthSecondaryLinkRow extends StatelessWidget {
  const AuthSecondaryLinkRow({required this.links, super.key});

  final List<AuthTextLink> links;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Scale the group as one unit instead of letting Flex wrap or stack: the
    // links must stay on a single centered row down to the narrowest phone.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < links.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: theme.spacing.xs),
            links[i],
          ],
        ],
      ),
    );
  }
}

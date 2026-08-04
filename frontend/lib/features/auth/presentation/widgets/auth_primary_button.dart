import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Prominent filled call-to-action for auth flows.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.isLoading = false,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    final bool canPress = !isLoading && onPressed != null;

    final Widget button = FilledButton(
      onPressed: canPress ? onPressed : null,
      style: FilledButton.styleFrom(
        minimumSize: Size(fullWidth ? double.infinity : 0, 48),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.xl,
          vertical: spacing.md,
        ),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: AppFontWeight.emphasis,
          fontSize: 15,
          letterSpacing: 0.1,
        ),
        elevation: 0,
      ),
      child: _AuthPrimaryButtonContent(
        label: label,
        leadingIcon: leadingIcon,
        isLoading: isLoading,
      ),
    );

    if (!fullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

class _AuthPrimaryButtonContent extends StatelessWidget {
  const _AuthPrimaryButtonContent({
    required this.label,
    required this.isLoading,
    this.leadingIcon,
  });

  final String label;
  final IconData? leadingIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    final Color onPrimary = theme.colorScheme.onPrimary;

    final TextStyle labelStyle = theme.textTheme.labelLarge!.copyWith(
      fontWeight: AppFontWeight.emphasis,
      fontSize: 15,
      color: onPrimary,
    );

    if (isLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(onPrimary),
            ),
          ),
          SizedBox(width: spacing.sm),
          Flexible(
            child: Text(
              label,
              style: labelStyle,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (leadingIcon == null) {
      return Text(
        label,
        style: labelStyle,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(leadingIcon, size: 18, color: onPrimary),
        SizedBox(width: spacing.sm),
        Flexible(
          child: Text(
            label,
            style: labelStyle,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

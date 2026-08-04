import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    required this.title,
    required this.child,
    this.subtitle,
    this.maxWidth = 420,
    this.useCard = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final double maxWidth;
  final bool useCard;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);

    final EdgeInsets panelPadding = EdgeInsets.all(switch (breakpoint) {
      AppBreakpoint.xs || AppBreakpoint.sm => theme.spacing.lg,
      _ => theme.spacing.xl,
    });

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: switch (breakpoint) {
              AppBreakpoint.xs || AppBreakpoint.sm => 22,
              _ => 24,
            },
            height: 1.2,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
        SizedBox(height: theme.spacing.xl),
        child,
      ],
    );

    if (useCard) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(
            context.responsiveRadius(theme.radius.lg),
          ),
          border: theme.borders.all(color: colorScheme.outlineVariant.withValues(alpha: 0.55)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.07),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(padding: panelPadding, child: content),
      );
    }

    return AppFieldRequirementScope(
      showOptionalIndicators: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}

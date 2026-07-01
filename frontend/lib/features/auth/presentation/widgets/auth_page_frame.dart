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
    this.useCard = false,
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
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool showCard = useCard && breakpoint.index >= AppBreakpoint.lg.index;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
        SizedBox(height: theme.spacing.lg),
        child,
      ],
    );

    if (showCard) {
      content = Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.xl),
          child: content,
        ),
      );
    }

    return AppFieldRequirementScope(
      showOptionalIndicators: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget frame = content;
            if (constraints.hasBoundedHeight &&
                constraints.maxHeight.isFinite) {
              return SingleChildScrollView(child: frame);
            }
            return frame;
          },
        ),
      ),
    );
  }
}

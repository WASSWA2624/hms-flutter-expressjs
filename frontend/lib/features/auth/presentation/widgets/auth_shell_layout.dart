import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_logo.dart';

class AuthShellLayout extends StatelessWidget {
  const AuthShellLayout({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool isLarge = breakpoint.index >= AppBreakpoint.lg.index;
    final l10n = context.l10n;
    final String displayName = isLarge ? l10n.appTitle : l10n.appShortTitle;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double maxFormWidth = switch (breakpoint) {
              AppBreakpoint.xs || AppBreakpoint.sm => constraints.maxWidth,
              AppBreakpoint.md => constraints.maxWidth.clamp(0, 520),
              _ => constraints.maxWidth.clamp(0, 560),
            };

            return SingleChildScrollView(
              padding: EdgeInsets.all(theme.spacing.lg),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxFormWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _AuthBrandHeader(
                        isLarge: isLarge,
                        displayName: displayName,
                      ),
                      SizedBox(height: theme.spacing.xl),
                      child,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader({
    required this.isLarge,
    required this.displayName,
  });

  final bool isLarge;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (isLarge) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const AppLogo(size: 48),
          SizedBox(width: theme.spacing.md),
          Flexible(
            child: Text(
              displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                height: 1.2,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        const AppLogo(size: 48),
        SizedBox(height: theme.spacing.sm),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

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
    final ColorScheme colorScheme = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool isLarge = breakpoint.index >= AppBreakpoint.lg.index;
    final l10n = context.l10n;
    final String displayName = isLarge ? l10n.appTitle : l10n.appShortTitle;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colorScheme.primaryContainer.withValues(alpha: 0.45),
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor,
            ],
            stops: const <double>[0, 0.32, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxFormWidth = switch (breakpoint) {
                AppBreakpoint.xs || AppBreakpoint.sm => constraints.maxWidth,
                AppBreakpoint.md => constraints.maxWidth.clamp(0, 480),
                _ => constraints.maxWidth.clamp(0, 520),
              };

              final EdgeInsets pagePadding = EdgeInsets.symmetric(
                horizontal: theme.spacing.lg,
                vertical: switch (breakpoint) {
                  AppBreakpoint.xs || AppBreakpoint.sm => theme.spacing.md,
                  _ => theme.spacing.xl,
                },
              );

              return CustomScrollView(
                slivers: <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxFormWidth),
                        child: Padding(
                          padding: pagePadding,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _AuthBrandHeader(
                                isLarge: isLarge,
                                displayName: displayName,
                              ),
                              SizedBox(
                                height: switch (breakpoint) {
                                  AppBreakpoint.xs ||
                                  AppBreakpoint.sm => theme.spacing.lg,
                                  _ => theme.spacing.xl,
                                },
                              ),
                              child,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader({required this.isLarge, required this.displayName});

  final bool isLarge;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double logoSize = isLarge ? 56 : 48;

    final Widget logo = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(
          context.responsiveRadius(theme.radius.md),
        ),
        border: theme.borders.all(),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: AppLogo(size: logoSize - theme.spacing.sm * 2),
      ),
    );

    if (isLarge) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          logo,
          SizedBox(width: theme.spacing.md),
          Flexible(
            child: Text(
              displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: AppFontWeight.emphasis,
                fontSize: 22,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        logo,
        SizedBox(height: theme.spacing.md),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: AppFontWeight.emphasis,
            fontSize: 16,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

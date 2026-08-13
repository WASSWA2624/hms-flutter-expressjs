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
    final bool isCompact =
        breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;
    final String displayName = context.l10n.appTitle;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colorScheme.primaryContainer.withValues(alpha: 0.35),
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor,
            ],
            stops: const <double>[0, 0.28, 1],
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

              final EdgeInsets pagePadding = EdgeInsets.fromLTRB(
                theme.spacing.lg,
                isCompact ? theme.spacing.lg : theme.spacing.xl,
                theme.spacing.lg,
                theme.spacing.lg,
              );

              // Prefer a slight upper bias over dead-vertical centering so the
              // brand and form read as one composed block.
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: pagePadding,
                    child: Align(
                      alignment: const Alignment(0, -0.35),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxFormWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _AuthBrandHeader(
                              displayName: displayName,
                              isCompact: isCompact,
                            ),
                            SizedBox(
                              height: isCompact
                                  ? theme.spacing.md
                                  : theme.spacing.md,
                            ),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader({
    required this.displayName,
    required this.isCompact,
  });

  final String displayName;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final double logoHeight = isCompact ? 56.0 : 72.0;
    // App name is 3/4 of the logo height.
    final double titleSize = logoHeight * 0.75;

    return Semantics(
      header: true,
      label: displayName,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            AppLogo(size: logoHeight),
            SizedBox(width: theme.spacing.md),
            Text(
              displayName,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppLogo.brandBlue,
                fontWeight: AppFontWeight.strong,
                fontSize: titleSize,
                height: 1.0,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_logo.dart';

/// Persistent chrome for auth routes (logo, brand, page backdrop).
///
/// Only [child] swaps when navigating between login / register / etc.
class AuthShellLayout extends StatefulWidget {
  const AuthShellLayout({required this.child, super.key});

  final Widget child;

  @override
  State<AuthShellLayout> createState() => _AuthShellLayoutState();
}

class _AuthShellLayoutState extends State<AuthShellLayout> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool isCompact =
        breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;

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

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: pagePadding,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxFormWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const _AuthBrandHeader(),
                            SizedBox(height: theme.spacing.md),
                            widget.child,
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
  const _AuthBrandHeader();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool isCompact =
        breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;
    final String displayName = context.l10n.appTitle;

    final double logoHeight = isCompact ? 56.0 : 72.0;
    // App name is half the logo height, bottom-aligned with the mark.
    final double titleSize = logoHeight * 0.5;

    return Semantics(
      header: true,
      label: displayName,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppLogo.brandBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(
              context.responsiveRadius(theme.radius.lg),
            ),
            border: Border.all(
              color: AppLogo.brandBlue.withValues(alpha: 0.10),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.lg,
              vertical: theme.spacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
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
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

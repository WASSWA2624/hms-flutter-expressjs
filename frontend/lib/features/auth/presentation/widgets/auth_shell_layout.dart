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

  /// The surface holding branding and form. Exposed so layout tests can assert
  /// the panel measure without depending on the widget tree's shape.
  static const Key panelKey = Key('auth-shell-panel');

  /// The scrollable region below the branding band.
  static const Key formRegionKey = Key('auth-shell-form-region');

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
              // Branding and form share one measure so they read as a single
              // panel. On phones that measure is the viewport; from tablet up it
              // is only as wide as the form needs, centred over the backdrop.
              final double panelWidth = switch (breakpoint) {
                AppBreakpoint.xs || AppBreakpoint.sm => constraints.maxWidth,
                AppBreakpoint.md => constraints.maxWidth.clamp(0, 480),
                _ => constraints.maxWidth.clamp(0, 520),
              };
              final bool isCompact = panelWidth >= constraints.maxWidth;

              // The panel always runs the full height of the safe area, so the
              // surface reaches both edges of the viewport at every width.
              final Widget panel = SizedBox(
                key: AuthShellLayout.panelKey,
                width: panelWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: isCompact
                        ? theme.borders.only(top: true)
                        : theme.borders.all(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _AuthBrandHeader(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (
                            BuildContext context,
                            BoxConstraints formConstraints,
                          ) {
                            // `minHeight` + `Center`: short forms sit in the
                            // middle of the remaining space, while a form taller
                            // than the viewport grows the box instead, so it
                            // anchors to the top and scrolls with nothing
                            // clipped and the submit action reachable.
                            return SingleChildScrollView(
                              key: AuthShellLayout.formRegionKey,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: formConstraints.maxHeight,
                                ),
                                // `Center` loosens the width constraint, so the
                                // form is stretched back to the panel measure.
                                child: Center(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: widget.child,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return Align(alignment: Alignment.topCenter, child: panel);
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

    // One height for both halves of the lockup. The title sets `height: 1.0`,
    // so its line box equals its font size; the mark is sized to the cap height
    // of that font size so it matches the letters rather than the em box.
    final double brandHeight = isCompact ? 28.0 : 36.0;
    final double markHeight = AppLogo.markHeightForFontSize(brandHeight);

    return Semantics(
      header: true,
      label: displayName,
      child: ColoredBox(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.lg,
            vertical: theme.spacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            // Both halves start at the top of the title's line box, and the
            // mark is then inset down onto the baseline. Centring instead would
            // leave it sitting low, because a line box is not centred on its
            // capitals; row baseline alignment cannot help, because an image
            // reports no real baseline for `RenderFlex` to align to.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(
                  top: AppLogo.markBaselineInsetForFontSize(brandHeight),
                ),
                child: AppLogo(size: markHeight),
              ),
              SizedBox(width: theme.spacing.md),
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: AppFontWeight.strong,
                    fontSize: brandHeight,
                    height: 1.0,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

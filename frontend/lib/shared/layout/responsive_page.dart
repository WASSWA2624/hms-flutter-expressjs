import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/layout/responsive_spacing.dart';

enum PageMaxWidth {
  authForm(520),
  form(720),
  reading(1040),
  dashboard(1440),
  dataHeavy(1440);

  const PageMaxWidth(this.value);

  final double value;
}

class PageMaxWidthBox extends StatelessWidget {
  const PageMaxWidthBox({
    required this.child,
    this.maxWidth = PageMaxWidth.reading,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final PageMaxWidth maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth.value),
        child: child,
      ),
    );
  }
}

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    required this.child,
    this.maxWidth = PageMaxWidth.reading,
    this.scrollable = true,
    this.safeArea = true,
    this.avoidKeyboardInsets = true,
    this.centerVertically = false,
    this.padding,
    super.key,
  });

  final Widget child;
  final PageMaxWidth maxWidth;
  final bool scrollable;
  final bool safeArea;
  final bool avoidKeyboardInsets;
  final bool centerVertically;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ThemeData theme = Theme.of(context);
        final AppBreakpoint breakpoint = AppBreakpoints.fromConstraints(
          constraints,
        );
        final double keyboardBottomInset = avoidKeyboardInsets
            ? MediaQuery.viewInsetsOf(context).bottom
            : theme.spacing.none;
        final EdgeInsets basePadding =
            padding ??
            ResponsiveSpacing.pagePaddingFor(
              breakpoint,
              designTokens: theme.appTokens,
            );
        final EdgeInsets resolvedPadding = basePadding.copyWith(
          bottom: basePadding.bottom + keyboardBottomInset,
        );
        final AlignmentGeometry alignment = centerVertically
            ? Alignment.center
            : Alignment.topCenter;

        Widget content = PageMaxWidthBox(
          maxWidth: maxWidth,
          alignment: alignment,
          child: child,
        );

        if (centerVertically && constraints.hasBoundedHeight) {
          content = ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(
                theme.spacing.none,
                constraints.maxHeight - resolvedPadding.vertical,
              ),
            ),
            child: content,
          );
        }

        Widget page = Padding(padding: resolvedPadding, child: content);

        if (scrollable) {
          page = SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: page,
          );
        }

        if (safeArea) {
          page = SafeArea(child: page);
        }

        return page;
      },
    );
  }
}

class AppScreen extends StatelessWidget {
  const AppScreen({
    required this.title,
    required this.children,
    this.subtitle,
    this.body,
    this.leadingIcon,
    this.headerActions,
    this.maxWidth = PageMaxWidth.reading,
    this.padding,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? body;
  final IconData? leadingIcon;
  final List<Widget> children;
  final List<Widget>? headerActions;
  final PageMaxWidth maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final double contentGap = ResponsiveSpacing.contentGapFor(
      breakpoint,
      spacing: theme.spacing,
    );

    return ResponsivePage(
      maxWidth: maxWidth,
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppScreenHeader(
              title: title,
              subtitle: subtitle,
              body: body,
              leadingIcon: leadingIcon,
              actions: headerActions,
            ),
            if (children.isNotEmpty) ...<Widget>[
              SizedBox(height: contentGap),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    required this.title,
    this.subtitle,
    this.body,
    this.leadingIcon,
    this.actions,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? body;
  final IconData? leadingIcon;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final List<Widget> effectiveActions = actions ?? const <Widget>[];
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool stackActions = breakpoint.isMobile;
    final TextStyle? titleStyle = switch (breakpoint) {
      AppBreakpoint.xs => textTheme.headlineSmall,
      AppBreakpoint.sm => textTheme.headlineSmall,
      AppBreakpoint.md => textTheme.headlineSmall,
      _ => textTheme.headlineMedium,
    };
    final TextStyle? subtitleStyle = switch (breakpoint) {
      AppBreakpoint.xs => textTheme.titleMedium,
      AppBreakpoint.sm => textTheme.titleMedium,
      AppBreakpoint.md => textTheme.titleMedium,
      _ => textTheme.titleLarge,
    };
    final TextStyle? bodyStyle = switch (breakpoint) {
      AppBreakpoint.xs => textTheme.bodyMedium,
      AppBreakpoint.sm => textTheme.bodyMedium,
      _ => textTheme.bodyLarge,
    }?.copyWith(color: colorScheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (stackActions)
          _HeaderText(
            title: title,
            subtitle: subtitle,
            body: body,
            leadingIcon: leadingIcon,
            titleStyle: titleStyle,
            subtitleStyle: subtitleStyle,
            bodyStyle: bodyStyle,
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _HeaderText(
                  title: title,
                  subtitle: subtitle,
                  body: body,
                  leadingIcon: leadingIcon,
                  titleStyle: titleStyle,
                  subtitleStyle: subtitleStyle,
                  bodyStyle: bodyStyle,
                ),
              ),
              if (effectiveActions.isNotEmpty) ...<Widget>[
                SizedBox(width: theme.spacing.lg),
                Wrap(spacing: theme.spacing.sm, children: effectiveActions),
              ],
            ],
          ),
        if (stackActions && effectiveActions.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: effectiveActions,
          ),
        ],
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText({
    required this.title,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.bodyStyle,
    this.subtitle,
    this.body,
    this.leadingIcon,
  });

  final String title;
  final String? subtitle;
  final String? body;
  final IconData? leadingIcon;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (leadingIcon != null) ...<Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.62,
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                  ),
                ),
                child: SizedBox.square(
                  dimension: 36,
                  child: Icon(
                    leadingIcon,
                    color: theme.colorScheme.primary,
                    size: theme.appTokens.listIconSize,
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
            ],
            Expanded(child: Text(title, style: titleStyle)),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Text(subtitle!, style: subtitleStyle),
        ],
        if (body != null && body!.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Text(body!, style: bodyStyle),
        ],
      ],
    );
  }
}

class AppScreenSection extends StatelessWidget {
  const AppScreenSection({
    required this.title,
    required this.body,
    required this.child,
    super.key,
  });

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool compact = breakpoint.isMobile;
    final double padding = theme.spacing.md;
    final double headingGap = compact ? theme.spacing.sm : theme.spacing.md;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium),
            SizedBox(height: theme.spacing.xs),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: headingGap),
            child,
          ],
        ),
      ),
    );
  }
}

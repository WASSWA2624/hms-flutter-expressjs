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

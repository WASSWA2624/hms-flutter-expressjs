import 'package:flutter/widgets.dart';

enum AppBreakpoint { xs, sm, md, lg, xl, xxl }

extension AppBreakpointProperties on AppBreakpoint {
  String get token => name;

  bool get isMobile => switch (this) {
    AppBreakpoint.xs || AppBreakpoint.sm => true,
    _ => false,
  };

  bool get supportsNavigationRail => !isMobile;

  bool get supportsExtendedNavigationRail => switch (this) {
    AppBreakpoint.lg || AppBreakpoint.xl || AppBreakpoint.xxl => true,
    _ => false,
  };
}

abstract final class AppBreakpoints {
  static const double sm = 360;
  static const double md = 600;
  static const double lg = 840;
  static const double xl = 1200;
  static const double xxl = 1600;

  static AppBreakpoint of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static AppBreakpoint fromConstraints(BoxConstraints constraints) {
    return fromWidth(constraints.maxWidth);
  }

  static AppBreakpoint fromWidth(double width) {
    if (width < sm) {
      return AppBreakpoint.xs;
    }
    if (width < md) {
      return AppBreakpoint.sm;
    }
    if (width < lg) {
      return AppBreakpoint.md;
    }
    if (width < xl) {
      return AppBreakpoint.lg;
    }
    if (width < xxl) {
      return AppBreakpoint.xl;
    }

    return AppBreakpoint.xxl;
  }
}

typedef ResponsiveWidgetBuilder =
    Widget Function(BuildContext context, AppBreakpoint breakpoint);

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({required this.builder, super.key});

  final ResponsiveWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return builder(context, AppBreakpoints.fromConstraints(constraints));
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

enum AppResponsiveFieldRowGap { standard, form }

class AppResponsiveFieldRow extends StatelessWidget {
  const AppResponsiveFieldRow({
    required this.children,
    this.breakpoint = 560,
    this.gap = AppResponsiveFieldRowGap.standard,
    super.key,
  });

  AppResponsiveFieldRow.two({
    required Widget left,
    required Widget right,
    double breakpoint = 560,
    AppResponsiveFieldRowGap gap = AppResponsiveFieldRowGap.standard,
    Key? key,
  }) : this(
         children: <Widget>[left, right],
         breakpoint: breakpoint,
         gap: gap,
         key: key,
       );

  final List<Widget> children;
  final double breakpoint;
  final AppResponsiveFieldRowGap gap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked =
            !constraints.hasBoundedWidth || constraints.maxWidth < breakpoint;

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var index = 0; index < children.length; index += 1) ...[
                children[index],
                if (index < children.length - 1)
                  SizedBox(height: _verticalGap(theme)),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < children.length; index += 1) ...[
              Expanded(child: children[index]),
              if (index < children.length - 1)
                SizedBox(width: _horizontalGap(theme)),
            ],
          ],
        );
      },
    );
  }

  double _horizontalGap(ThemeData theme) {
    return switch (gap) {
      AppResponsiveFieldRowGap.standard => theme.spacing.sm,
      AppResponsiveFieldRowGap.form => theme.spacing.md,
    };
  }

  double _verticalGap(ThemeData theme) {
    return switch (gap) {
      AppResponsiveFieldRowGap.standard => theme.spacing.sm,
      AppResponsiveFieldRowGap.form => theme.appTokens.formGapCompact,
    };
  }
}

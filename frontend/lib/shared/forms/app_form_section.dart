import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

enum AppFormSectionDensity { compact, regular, spacious }

class AppFormSection extends StatelessWidget {
  const AppFormSection({
    required this.children,
    this.title,
    this.description,
    this.density = AppFormSectionDensity.regular,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    super.key,
  });

  final String? title;
  final String? description;
  final List<Widget> children;
  final AppFormSectionDensity density;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final double gap = _gap(theme);

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Text(title!, style: textTheme.titleMedium),
          if (description != null) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            Text(description!, style: textTheme.bodyMedium),
          ],
          SizedBox(height: gap),
        ],
        for (var index = 0; index < children.length; index++) ...<Widget>[
          children[index],
          if (index < children.length - 1) SizedBox(height: gap),
        ],
      ],
    );
  }

  double _gap(ThemeData theme) {
    return switch (density) {
      AppFormSectionDensity.compact => theme.appTokens.formGapCompact,
      AppFormSectionDensity.regular => theme.appTokens.formGapRegular,
      AppFormSectionDensity.spacious => theme.appTokens.formGapSpacious,
    };
  }
}

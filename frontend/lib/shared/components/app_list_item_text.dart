import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

class AppListItemText extends StatelessWidget {
  const AppListItemText({
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
    this.softWrap = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? resolvedSubtitle = subtitle?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: titleMaxLines,
          softWrap: softWrap,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (resolvedSubtitle != null && resolvedSubtitle.isNotEmpty)
          Text(
            resolvedSubtitle,
            maxLines: subtitleMaxLines,
            softWrap: softWrap,
            overflow: TextOverflow.ellipsis,
            style:
                subtitleStyle ??
                theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

class AppInlineMetaText extends StatelessWidget {
  const AppInlineMetaText({
    required this.icon,
    required this.label,
    this.maxWidth = 220,
    super.key,
  });

  final IconData icon;
  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: theme.appTokens.listIconSize * 0.78,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: theme.spacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

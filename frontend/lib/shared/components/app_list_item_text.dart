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

class AppListItemRow extends StatelessWidget {
  const AppListItemRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.trailing,
    this.details = const <Widget>[],
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 2,
    this.softWrap = false,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? leadingIcon;
  final Widget? trailing;
  final List<Widget> details;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final bool softWrap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget? leadingWidget = leading ?? _leadingIcon(theme);
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppListItemText(
          title: title,
          subtitle: subtitle,
          titleStyle: titleStyle ?? theme.textTheme.titleSmall,
          subtitleStyle: subtitleStyle,
          titleMaxLines: titleMaxLines,
          subtitleMaxLines: subtitleMaxLines,
          softWrap: softWrap,
        ),
        for (final Widget detail in details) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          detail,
        ],
      ],
    );

    return Padding(
      padding: padding ?? EdgeInsets.all(theme.spacing.md),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: <Widget>[
          if (leadingWidget != null) ...<Widget>[
            leadingWidget,
            SizedBox(width: theme.spacing.sm),
          ],
          Expanded(child: content),
          if (trailing != null) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }

  Widget? _leadingIcon(ThemeData theme) {
    final IconData? icon = leadingIcon;
    if (icon == null) {
      return null;
    }

    return Icon(
      icon,
      color: theme.colorScheme.primary,
      size: theme.appTokens.listIconSize,
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

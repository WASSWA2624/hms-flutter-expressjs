import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';

/// How an [AppPropertyValueList] stacks its pairs.
enum AppPropertyValueListDirection {
  /// Pairs flow left-to-right and wrap onto new runs.
  horizontal,

  /// One pair per line.
  vertical,
}

/// Data for one `[icon] Property name: Property value` pair.
///
/// Use with [AppPropertyValueList] to render a group of pairs.
@immutable
final class AppPropertyValueData {
  const AppPropertyValueData({
    required this.label,
    this.value,
    this.icon,
    this.iconColor,
    this.valueColor,
    this.copyable = false,
    this.copyTooltip,
    this.copiedMessage,
    this.copySemanticLabel,
    this.showCopyIcon = true,
    this.copyPlaceholderValues = const <String>{},
    this.onTap,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final Color? iconColor;
  final Color? valueColor;
  final bool copyable;
  final String? copyTooltip;
  final String? copiedMessage;
  final String? copySemanticLabel;
  final bool showCopyIcon;
  final Set<String> copyPlaceholderValues;
  final VoidCallback? onTap;

  bool get hasValue => (value ?? '').trim().isNotEmpty;
}

/// The app's single inline property/value pair.
///
/// Lays out as `[icon] Property name: Property value` on one line — the label
/// in regular weight, the value in bold. Borderless by default; pass
/// [bordered] to frame it as a chip.
///
/// ```dart
/// AppPropertyValue(
///   icon: Icons.person_outline,
///   label: l10n.commonNameLabel,
///   value: 'Wasswa Wilson',
/// )
/// ```
///
/// Prefer this over hand-rolled `Row(Icon, Text('$label: '), Text(value))`
/// blocks. For stacked label-above-value tiles use `AppInfoTile`, and for
/// grouped detail panels use `AppInfoSheetGrid`.
class AppPropertyValue extends StatelessWidget {
  const AppPropertyValue({
    required this.label,
    this.value,
    this.icon,
    this.iconColor,
    this.emptyValue = '',
    this.bordered = false,
    this.labelStyle,
    this.valueStyle,
    this.valueColor,
    this.maxLines = 1,
    this.expand = false,
    this.copyable = false,
    this.copyTooltip,
    this.copiedMessage,
    this.copySemanticLabel,
    this.showCopyIcon = true,
    this.copyPlaceholderValues = const <String>{},
    this.onTap,
    this.semanticsLabel,
    this.padding,
    this.valueWidget,
    this.onCopied,
    super.key,
  });

  /// Property name, rendered in regular weight and followed by `: `.
  final String label;

  /// Property value, rendered in bold. Falls back to [emptyValue] when blank.
  final String? value;

  /// Optional leading icon.
  final IconData? icon;

  /// Leading icon colour. Defaults to the primary colour.
  final Color? iconColor;

  /// Shown when [value] is null or blank.
  final String emptyValue;

  /// Frames the pair with the standard faint border. Off by default.
  final bool bordered;

  /// Overrides the default label style (regular weight, muted).
  final TextStyle? labelStyle;

  /// Overrides the default value style (bold, on-surface).
  final TextStyle? valueStyle;

  /// Value colour applied on top of the resolved value style.
  final Color? valueColor;

  /// Lines the value may occupy before it ellipsizes.
  final int maxLines;

  /// Fills the available width and lets the pair wrap onto multiple lines
  /// instead of sizing to its content on a single line.
  final bool expand;

  final bool copyable;
  final String? copyTooltip;
  final String? copiedMessage;
  final String? copySemanticLabel;
  final bool showCopyIcon;
  final Set<String> copyPlaceholderValues;

  /// Makes the whole pair tappable.
  final VoidCallback? onTap;

  /// Overrides the default `Property name: value` semantics label.
  final String? semanticsLabel;

  /// Outer padding — mainly for the gap between pairs in a detail stack.
  final EdgeInsetsGeometry? padding;

  /// Fires after a [copyable] value is copied to the clipboard.
  final VoidCallback? onCopied;

  /// Renders in place of [value] when the value is not plain text — a status
  /// badge, a chip, a link. [value] is still used for the semantics label.
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String displayValue = _resolvedValue(value, emptyValue);

    final TextStyle? resolvedLabelStyle =
        labelStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: AppFontWeight.regular,
        );
    final TextStyle? baseValueStyle =
        valueStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: AppFontWeight.strong,
        );
    final TextStyle? resolvedValueStyle = valueColor == null
        ? baseValueStyle
        : baseValueStyle?.copyWith(color: valueColor);

    final Widget pair = expand
        ? _wrappingPair(
            label: label,
            value: displayValue,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
          )
        : _inlinePair(
            label: label,
            value: displayValue,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
          );

    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: expand
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(
            icon,
            size: theme.appTokens.listIconSize,
            color: iconColor ?? colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.xs),
        ],
        if (expand) Expanded(child: pair) else Flexible(child: pair),
      ],
    );

    if (bordered) {
      content = Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(theme.radius.sm),
          border: theme.borders.all(),
        ),
        child: content,
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(theme.radius.sm),
          child: content,
        ),
      );
    }

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Semantics(
      label: semanticsLabel ?? '$label: $displayValue',
      child: content,
    );
  }

  /// Single line: label and value sized to content, value ellipsizing last.
  Widget _inlinePair({
    required String label,
    required String value,
    required TextStyle? labelStyle,
    required TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Label and separator stay one Text node: callers (and tests) match on
        // the rendered `Label: ` string.
        Text('$label$_separator', style: labelStyle, maxLines: 1),
        Flexible(child: _valueWidget(value, valueStyle, softWrap: false)),
      ],
    );
  }

  /// Full width: label and value share one paragraph so they wrap together.
  Widget _wrappingPair({
    required String label,
    required String value,
    required TextStyle? labelStyle,
    required TextStyle? valueStyle,
  }) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: '$label$_separator', style: labelStyle),
          if (copyable || valueWidget != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _valueWidget(value, valueStyle, softWrap: true),
            )
          else
            TextSpan(text: value, style: valueStyle),
        ],
      ),
      softWrap: true,
    );
  }

  Widget _valueWidget(
    String value,
    TextStyle? style, {
    required bool softWrap,
  }) {
    if (valueWidget != null) {
      return DefaultTextStyle.merge(style: style, child: valueWidget!);
    }
    if (copyable) {
      return AppCopyableIdentifier(
        value: value,
        tooltip: copyTooltip,
        copiedMessage: copiedMessage,
        semanticLabel: copySemanticLabel,
        showCopyIcon: showCopyIcon,
        maxLines: maxLines,
        placeholderValues: copyPlaceholderValues,
        textStyle: style,
        onCopied: onCopied,
      );
    }

    return Text(
      value,
      style: style,
      maxLines: softWrap ? null : maxLines,
      softWrap: softWrap,
      overflow: softWrap ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }

  static const String _separator = ': ';
}

/// A group of [AppPropertyValue] pairs sharing one layout.
///
/// Horizontal is the default — pairs flow left-to-right and wrap when the row
/// runs out of space. Pass [AppPropertyValueListDirection.vertical] for
/// one-per-line detail stacks.
class AppPropertyValueList extends StatelessWidget {
  const AppPropertyValueList({
    required this.items,
    this.direction = AppPropertyValueListDirection.horizontal,
    this.emptyValue = '',
    this.bordered = false,
    this.hideEmptyValues = false,
    this.maxLines = 1,
    this.spacing,
    this.runSpacing,
    super.key,
  });

  final List<AppPropertyValueData> items;
  final AppPropertyValueListDirection direction;
  final String emptyValue;
  final bool bordered;

  /// Drops pairs whose value is null or blank instead of showing [emptyValue].
  final bool hideEmptyValues;
  final int maxLines;
  final double? spacing;
  final double? runSpacing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AppPropertyValueData> visible = hideEmptyValues
        ? items
              .where((AppPropertyValueData item) => item.hasValue)
              .toList(growable: false)
        : items;
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool vertical = direction == AppPropertyValueListDirection.vertical;
    final double gap =
        spacing ?? (vertical ? theme.spacing.sm : theme.spacing.lg);
    final double rowGap = runSpacing ?? theme.spacing.sm;

    final List<Widget> pairs = <Widget>[
      for (final AppPropertyValueData item in visible)
        AppPropertyValue(
          label: item.label,
          value: item.value,
          icon: item.icon,
          iconColor: item.iconColor,
          valueColor: item.valueColor,
          emptyValue: emptyValue,
          bordered: bordered,
          maxLines: maxLines,
          expand: vertical,
          copyable: item.copyable,
          copyTooltip: item.copyTooltip,
          copiedMessage: item.copiedMessage,
          copySemanticLabel: item.copySemanticLabel,
          showCopyIcon: item.showCopyIcon,
          copyPlaceholderValues: item.copyPlaceholderValues,
          onTap: item.onTap,
        ),
    ];

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < pairs.length; index += 1) ...<Widget>[
            if (index > 0) SizedBox(height: gap),
            pairs[index],
          ],
        ],
      );
    }

    return Wrap(
      spacing: gap,
      runSpacing: rowGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: pairs,
    );
  }
}

String _resolvedValue(String? value, String emptyValue) {
  final String? normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return emptyValue;
  }

  return normalized;
}

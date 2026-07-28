import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_field_error_text.dart';

/// How [AppRadioGroup] arranges its options.
enum AppRadioGroupLayout {
  /// Single column stack (default; Settings and compact forms).
  vertical,

  /// Options share one row; each expands equally.
  horizontal,

  /// Wrapping grid. Column count follows available width unless [wrapColumns]
  /// is set.
  wrap,
}

/// Visual treatment for each radio option.
enum AppRadioGroupPresentation {
  /// Bordered, filled option cards (default).
  card,

  /// Control + label only; no per-option border or fill.
  borderless,
}

class AppRadioOption<T> {
  const AppRadioOption({
    required this.value,
    required this.label,
    this.description,
    this.secondary,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// Optional supporting copy; omitted when null or blank.
  final String? description;
  final Widget? secondary;
  final bool enabled;
}

class AppRadioGroup<T> extends StatelessWidget {
  const AppRadioGroup({
    required this.options,
    this.value,
    this.onChanged,
    this.labelText,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.contentPadding,
    this.layout = AppRadioGroupLayout.vertical,
    this.presentation = AppRadioGroupPresentation.card,
    this.dense = false,
    this.wrapColumns,
    this.itemMinWidth = 240,
    super.key,
  });

  final List<AppRadioOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<T>? validator;
  final FormFieldSetter<T>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;
  final AppRadioGroupLayout layout;
  final AppRadioGroupPresentation presentation;

  /// Reduces label/option spacing for tight inline toolbars.
  final bool dense;

  /// Fixed wrap column count when set; otherwise width-driven (1 on narrow,
  /// up to 2 when space allows for [itemMinWidth]).
  final int? wrapColumns;
  final double itemMinWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canChange = enabled;

    return FormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      forceErrorText: errorText,
      builder: (FormFieldState<T> field) {
        final bool hasError = field.errorText != null;
        final Widget optionsBody = _buildOptions(
          context: context,
          theme: theme,
          field: field,
          canChange: canChange,
          hasError: hasError,
        );

        final Widget group = RadioGroup<T>(
          groupValue: field.value,
          onChanged: canChange
              ? (T? newValue) {
                  field.didChange(newValue);
                  onChanged?.call(newValue);
                }
              : (_) {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (labelText != null) ...<Widget>[
                Text(
                  labelText!,
                  style: (dense
                          ? theme.textTheme.labelLarge
                          : theme.textTheme.titleSmall)
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SizedBox(height: dense ? theme.spacing.xs : theme.spacing.sm),
              ],
              optionsBody,
              if (field.errorText != null) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                AppFieldErrorText(errorText: field.errorText),
              ],
            ],
          ),
        );

        if (semanticLabel == null && labelText == null) {
          return group;
        }

        return Semantics(
          container: true,
          enabled: canChange,
          label: semanticLabel ?? labelText,
          child: group,
        );
      },
    );
  }

  Widget _buildOptions({
    required BuildContext context,
    required ThemeData theme,
    required FormFieldState<T> field,
    required bool canChange,
    required bool hasError,
  }) {
    final double gap = dense ? theme.spacing.xs : theme.spacing.sm;
    final List<Widget> tiles = <Widget>[
      for (final AppRadioOption<T> option in options)
        _AppRadioOptionTile<T>(
          option: option,
          selected: field.value == option.value,
          enabled: canChange && option.enabled,
          hasError: hasError,
          presentation: presentation,
          dense: dense,
          contentPadding: contentPadding,
          onSelected: canChange && option.enabled
              ? () {
                  field.didChange(option.value);
                  onChanged?.call(option.value);
                }
              : null,
        ),
    ];

    return switch (layout) {
      AppRadioGroupLayout.vertical => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: gap),
            tiles[i],
          ],
        ],
      ),
      AppRadioGroupLayout.horizontal => Row(
        crossAxisAlignment: presentation == AppRadioGroupPresentation.borderless
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
      AppRadioGroupLayout.wrap => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = _resolveWrapColumns(
            context: context,
            maxWidth: constraints.maxWidth,
            gap: gap,
          );
          final double itemWidth = columns <= 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final Widget tile in tiles)
                SizedBox(width: itemWidth, child: tile),
            ],
          );
        },
      ),
    };
  }

  int _resolveWrapColumns({
    required BuildContext context,
    required double maxWidth,
    required double gap,
  }) {
    final int requested = (wrapColumns ?? 2).clamp(1, 4);
    if (requested == 1) {
      return 1;
    }

    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    if (breakpoint.isMobile || maxWidth < itemMinWidth * 2 + gap) {
      return 1;
    }
    if (requested >= 3 && maxWidth >= itemMinWidth * 3 + gap * 2) {
      return 3.clamp(1, requested);
    }
    return 2.clamp(1, requested);
  }
}

class _AppRadioOptionTile<T> extends StatelessWidget {
  const _AppRadioOptionTile({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.hasError,
    required this.presentation,
    required this.dense,
    required this.onSelected,
    this.contentPadding,
  });

  final AppRadioOption<T> option;
  final bool selected;
  final bool enabled;
  final bool hasError;
  final AppRadioGroupPresentation presentation;
  final bool dense;
  final VoidCallback? onSelected;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? description = option.description?.trim();
    final bool showDescription =
        description != null && description.isNotEmpty;
    final bool borderless =
        presentation == AppRadioGroupPresentation.borderless;

    final EdgeInsetsGeometry padding =
        contentPadding ??
        (borderless
            ? EdgeInsets.symmetric(
                vertical: dense ? 0 : theme.spacing.xs / 2,
              )
            : EdgeInsets.symmetric(
                horizontal: theme.spacing.sm,
                vertical: dense ? theme.spacing.xs : theme.spacing.sm,
              ));

    final Widget labelBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          option.label,
          style: (borderless
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.titleSmall)
              ?.copyWith(
                fontWeight: FontWeight.w700,
                height: borderless ? 1.2 : null,
                color: enabled
                    ? colors.onSurface
                    : colors.onSurface.withValues(alpha: 0.6),
              ),
        ),
        if (showDescription) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );

    final Widget content = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: borderless && !showDescription
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          if (!borderless)
            Padding(
              padding: EdgeInsets.only(top: theme.spacing.xs / 2),
              child: Radio<T>(
                value: option.value,
                enabled: enabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            )
          else
            Radio<T>(
              value: option.value,
              enabled: enabled,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          SizedBox(width: theme.spacing.sm),
          Expanded(child: labelBlock),
          if (option.secondary != null) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            IconTheme.merge(
              data: IconThemeData(
                color: selected ? colors.primary : colors.onSurfaceVariant,
                size: 22,
              ),
              child: option.secondary!,
            ),
          ],
        ],
      ),
    );

    if (borderless) {
      return Opacity(
        opacity: enabled ? 1 : 0.55,
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(theme.radius.sm),
          child: content,
        ),
      );
    }

    final Color borderColor;
    if (!enabled) {
      borderColor = colors.outlineVariant.withValues(alpha: 0.5);
    } else if (hasError && !selected) {
      borderColor = colors.error.withValues(alpha: 0.7);
    } else if (selected) {
      borderColor = colors.primary;
    } else {
      borderColor = colors.outlineVariant;
    }

    final Color fillColor;
    if (!enabled) {
      fillColor = colors.surfaceContainerHighest.withValues(alpha: 0.28);
    } else if (selected) {
      fillColor = colors.primaryContainer.withValues(alpha: 0.42);
    } else {
      fillColor = colors.surfaceContainerHighest.withValues(alpha: 0.28);
    }

    final BorderRadius radius = BorderRadius.circular(theme.radius.md);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: fillColor,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected,
          borderRadius: radius,
          child: content,
        ),
      ),
    );
  }
}

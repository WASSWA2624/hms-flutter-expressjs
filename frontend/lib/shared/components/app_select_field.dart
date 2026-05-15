import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/src/app_field_label.dart';

class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.labelWidget,
    this.leadingIcon,
    this.trailingIcon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final Widget? labelWidget;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool enabled;
}

class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    required this.options,
    this.value,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.isRequired = false,
    this.isLoading = false,
    this.searchable = false,
    this.filterCallback,
    this.searchCallback,
    this.focusNode,
    this.restorationId,
    this.menuHeight,
    super.key,
  });

  const AppSelectField.searchable({
    required this.options,
    this.value,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.isRequired = false,
    this.isLoading = false,
    this.filterCallback,
    this.searchCallback,
    this.focusNode,
    this.restorationId,
    this.menuHeight,
    super.key,
  }) : searchable = true;

  final List<AppSelectOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<T>? validator;
  final FormFieldSetter<T>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final bool isRequired;
  final bool isLoading;
  final bool searchable;
  final FilterCallback<T>? filterCallback;
  final SearchCallback<T>? searchCallback;
  final FocusNode? focusNode;
  final String? restorationId;
  final double? menuHeight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canSelect = enabled && !isLoading;
    Widget field = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double? width =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final double effectiveMenuHeight =
            menuHeight ??
            (MediaQuery.sizeOf(context).height * 0.42).clamp(220.0, 360.0);
        final bool canClear = canSelect && value != null && onChanged != null;
        final Widget trailingIcon = isLoading
            ? const _SelectLoadingIcon()
            : _SelectTrailingIcon(
                showClear: canClear,
                isExpanded: false,
                onClear: () => onChanged?.call(null),
              );
        final Widget selectedTrailingIcon = isLoading
            ? const _SelectLoadingIcon()
            : _SelectTrailingIcon(
                showClear: canClear,
                isExpanded: true,
                onClear: () => onChanged?.call(null),
              );

        return DropdownMenuFormField<T>(
          key: ValueKey<T?>(value),
          restorationId: restorationId,
          initialSelection: value,
          enabled: canSelect,
          width: width,
          menuHeight: effectiveMenuHeight,
          label: labelText == null
              ? null
              : Text(appFieldLabel(labelText, isRequired: isRequired)!),
          hintText: hintText,
          helperText: helperText,
          trailingIcon: trailingIcon,
          selectedTrailingIcon: selectedTrailingIcon,
          textStyle: theme.textTheme.bodyLarge?.copyWith(
            color: canSelect
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.62),
            fontWeight: FontWeight.w500,
          ),
          enableFilter: searchable,
          enableSearch: searchable,
          expandedInsets: EdgeInsets.zero,
          filterCallback: filterCallback ?? _defaultFilter,
          searchCallback: searchCallback ?? _defaultSearch,
          requestFocusOnTap: true,
          focusNode: focusNode,
          autovalidateMode: autovalidateMode,
          validator: validator,
          onSaved: onSaved,
          forceErrorText: errorText,
          onSelected: onChanged,
          dropdownMenuEntries: <DropdownMenuEntry<T>>[
            for (final AppSelectOption<T> option in options)
              DropdownMenuEntry<T>(
                value: option.value,
                label: option.label,
                labelWidget: option.labelWidget,
                leadingIcon: option.leadingIcon,
                trailingIcon: option.trailingIcon,
                enabled: option.enabled,
              ),
          ],
        );
      },
    );

    if (semanticLabel != null) {
      field = Semantics(
        textField: true,
        enabled: canSelect,
        label: semanticLabel,
        child: field,
      );
    }

    return field;
  }
}

List<DropdownMenuEntry<T>> _defaultFilter<T>(
  List<DropdownMenuEntry<T>> entries,
  String filter,
) {
  final String query = filter.trim().toLowerCase();
  if (query.isEmpty) {
    return entries;
  }

  return entries
      .where(
        (DropdownMenuEntry<T> entry) =>
            entry.label.toLowerCase().contains(query) ||
            entry.value.toString().toLowerCase().contains(query),
      )
      .toList(growable: false);
}

int? _defaultSearch<T>(List<DropdownMenuEntry<T>> entries, String query) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  final int startsWithIndex = entries.indexWhere(
    (DropdownMenuEntry<T> entry) =>
        entry.label.toLowerCase().startsWith(normalized) ||
        entry.value.toString().toLowerCase().startsWith(normalized),
  );
  if (startsWithIndex >= 0) {
    return startsWithIndex;
  }

  final int containsIndex = entries.indexWhere(
    (DropdownMenuEntry<T> entry) =>
        entry.label.toLowerCase().contains(normalized) ||
        entry.value.toString().toLowerCase().contains(normalized),
  );

  return containsIndex >= 0 ? containsIndex : null;
}

class _SelectTrailingIcon extends StatelessWidget {
  const _SelectTrailingIcon({
    required this.showClear,
    required this.isExpanded,
    required this.onClear,
  });

  final bool showClear;
  final bool isExpanded;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SizedBox(
      width: showClear ? 76 : 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showClear)
            IconButton(
              tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: Icon(
                Icons.close,
                size: theme.appTokens.listIconSize * 0.82,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: onClear,
            ),
          Padding(
            padding: EdgeInsetsDirectional.only(end: theme.spacing.sm),
            child: Icon(
              isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectLoadingIcon extends StatelessWidget {
  const _SelectLoadingIcon();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.sm),
      child: SizedBox.square(
        dimension: theme.appTokens.listIconSize,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

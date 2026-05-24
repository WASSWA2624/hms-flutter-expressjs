import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';

class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.labelWidget,
    this.leadingIcon,
    this.trailingIcon,
    this.searchText,
    this.enabled = true,
  });

  final T value;
  final String label;
  final Widget? labelWidget;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final String? searchText;
  final bool enabled;
}

class AppSelectField<T> extends StatefulWidget {
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
    this.allowClear = true,
    this.searchable = false,
    this.filterCallback,
    this.searchCallback,
    this.onSearchTextChanged,
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
    this.allowClear = true,
    this.filterCallback,
    this.searchCallback,
    this.onSearchTextChanged,
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
  final bool allowClear;
  final bool searchable;
  final FilterCallback<T>? filterCallback;
  final SearchCallback<T>? searchCallback;
  final ValueChanged<String>? onSearchTextChanged;
  final FocusNode? focusNode;
  final String? restorationId;
  final double? menuHeight;

  @override
  State<AppSelectField<T>> createState() => _AppSelectFieldState<T>();
}

class _AppSelectFieldState<T> extends State<AppSelectField<T>> {
  static const int _maxFilteredOptions = 80;

  late final TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _hasControllerText = false;
  bool _isSyncingControllerText = false;

  @override
  void initState() {
    super.initState();
    _attachFocusNode();
    _controller = TextEditingController(text: _labelForValue(widget.value));
    _hasControllerText = _controller.text.isNotEmpty;
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }

    final bool selectionChanged = oldWidget.value != widget.value;
    final bool selectedOptionMayHaveChanged =
        widget.value != null &&
        oldWidget.options != widget.options &&
        (!_focusNode.hasFocus ||
            _controller.text.isEmpty ||
            _controller.text ==
                _labelForValueInOptions(widget.value, oldWidget.options));
    if (selectionChanged || selectedOptionMayHaveChanged) {
      final String label = _labelForValue(widget.value);
      if (_controller.text != label) {
        _isSyncingControllerText = true;
        try {
          _controller.value = TextEditingValue(text: label);
        } finally {
          _isSyncingControllerText = false;
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _detachFocusNode();
    super.dispose();
  }

  void _attachFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
  }

  void _detachFocusNode() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canSelect = widget.enabled;
    Widget field = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double? width =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final double effectiveMenuHeight =
            widget.menuHeight ??
            (MediaQuery.sizeOf(context).height * 0.42).clamp(220.0, 360.0);
        final bool canClear =
            canSelect &&
            widget.allowClear &&
            widget.onChanged != null &&
            (widget.value != null || _hasControllerText);
        final Widget trailingIcon = _SelectTrailingIcon(
          showClear: canClear,
          isExpanded: false,
          isLoading: widget.isLoading,
          onClear: _clearSelection,
        );
        final Widget selectedTrailingIcon = _SelectTrailingIcon(
          showClear: canClear,
          isExpanded: true,
          isLoading: widget.isLoading,
          onClear: _clearSelection,
        );
        final bool enableFilter =
            widget.searchable || widget.filterCallback != null;
        final bool enableSearch =
            widget.searchable || widget.searchCallback != null;

        return DropdownMenuFormField<T>(
          key: ValueKey<T?>(widget.value),
          restorationId: widget.restorationId,
          controller: _controller,
          initialSelection: widget.value,
          enabled: canSelect,
          width: width,
          menuHeight: effectiveMenuHeight,
          label: appFieldLabelWidget(
            context,
            widget.labelText,
            isRequired: widget.isRequired,
          ),
          hintText: widget.hintText,
          helperText: widget.helperText,
          trailingIcon: trailingIcon,
          selectedTrailingIcon: selectedTrailingIcon,
          textStyle: theme.textTheme.bodyLarge?.copyWith(
            color: canSelect
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.62),
            fontWeight: FontWeight.w500,
          ),
          enableFilter: enableFilter,
          enableSearch: enableSearch,
          expandedInsets: EdgeInsets.zero,
          filterCallback: enableFilter
              ? widget.filterCallback ?? _filterEntries
              : null,
          searchCallback: enableSearch
              ? widget.searchCallback ?? _searchEntries
              : null,
          requestFocusOnTap: true,
          focusNode: _focusNode,
          autovalidateMode: widget.autovalidateMode,
          validator: widget.validator,
          onSaved: widget.onSaved,
          forceErrorText: widget.errorText,
          onSelected: (T? value) {
            if (value == null) {
              _controller.clear();
            }
            widget.onChanged?.call(value);
          },
          dropdownMenuEntries: <DropdownMenuEntry<T>>[
            for (final AppSelectOption<T> option in widget.options)
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

    if (widget.semanticLabel != null) {
      field = Semantics(
        textField: true,
        enabled: canSelect,
        label: widget.semanticLabel,
        child: field,
      );
    }

    return field;
  }

  void _clearSelection() {
    _controller.clear();
    widget.onChanged?.call(null);
  }

  void _handleControllerChanged() {
    final bool hasText = _controller.text.isNotEmpty;
    if (hasText != _hasControllerText) {
      setState(() {
        _hasControllerText = hasText;
      });
    }

    if (!_isSyncingControllerText) {
      widget.onSearchTextChanged?.call(_controller.text);
    }
  }

  String _labelForValue(T? value) {
    return _labelForValueInOptions(value, widget.options);
  }

  String _labelForValueInOptions(
    T? value,
    List<AppSelectOption<T>> options,
  ) {
    if (value == null) {
      return '';
    }
    for (final AppSelectOption<T> option in options) {
      if (option.value == value) {
        return option.label;
      }
    }
    return '';
  }

  List<DropdownMenuEntry<T>> _filterEntries(
    List<DropdownMenuEntry<T>> entries,
    String filter,
  ) {
    final List<String> tokens = _queryTokens(filter);
    if (tokens.isEmpty) {
      return entries;
    }

    return entries
        .where((DropdownMenuEntry<T> entry) {
          final String searchable = _searchTextForEntry(entry);
          return tokens.every(searchable.contains);
        })
        .take(_maxFilteredOptions)
        .toList(growable: false);
  }

  int? _searchEntries(List<DropdownMenuEntry<T>> entries, String query) {
    final List<String> tokens = _queryTokens(query);
    if (tokens.isEmpty) {
      return null;
    }

    final String firstToken = tokens.first;
    final int startsWithIndex = entries.indexWhere(
      (DropdownMenuEntry<T> entry) =>
          _searchTextForEntry(entry).startsWith(firstToken),
    );
    if (startsWithIndex >= 0) {
      return startsWithIndex;
    }

    final int containsIndex = entries.indexWhere((DropdownMenuEntry<T> entry) {
      final String searchable = _searchTextForEntry(entry);
      return tokens.every(searchable.contains);
    });

    return containsIndex >= 0 ? containsIndex : null;
  }

  String _searchTextForEntry(DropdownMenuEntry<T> entry) {
    final AppSelectOption<T>? option = _optionForValue(entry.value);
    final String raw = <String>[
      entry.label,
      option?.label ?? '',
      option?.searchText ?? '',
      entry.value.toString(),
    ].where((String value) => value.trim().isNotEmpty).join(' ');
    return _normalizeSearchText(raw);
  }

  AppSelectOption<T>? _optionForValue(T value) {
    for (final AppSelectOption<T> option in widget.options) {
      if (option.value == value) {
        return option;
      }
    }
    return null;
  }
}

List<String> _queryTokens(String query) {
  final String normalized = _normalizeSearchText(query);
  if (normalized.isEmpty) {
    return const <String>[];
  }
  return normalized
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

String _normalizeSearchText(String value) {
  return value.trim().toLowerCase();
}

class _SelectTrailingIcon extends StatelessWidget {
  const _SelectTrailingIcon({
    required this.showClear,
    required this.isExpanded,
    required this.isLoading,
    required this.onClear,
  });

  final bool showClear;
  final bool isExpanded;
  final bool isLoading;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SizedBox(
      width: (showClear ? 76.0 : 44.0) + (isLoading ? 28.0 : 0.0),
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
          if (isLoading)
            Padding(
              padding: EdgeInsetsDirectional.only(end: theme.spacing.xs),
              child: SizedBox.square(
                dimension: theme.appTokens.listIconSize * 0.78,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
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


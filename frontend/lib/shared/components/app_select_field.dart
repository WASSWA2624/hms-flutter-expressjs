import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';
import 'package:hosspi_hms/shared/components/app_loading_indicator.dart';

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
    this.emptyResultsText,
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
    this.emptyResultsText,
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
  /// Disabled menu row when a searchable filter matches no options.
  final String? emptyResultsText;
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
  static const double _defaultMenuMinHeight = 220.0;
  static const double _defaultMenuMaxHeight = 360.0;
  static const double _emptyResultsMenuHeight = 56.0;
  static const double _menuViewportPadding = 8.0;
  static const double _menuFieldGap = 4.0;
  static const double _menuItemDividerThickness = 0.5;
  static const double _menuItemDividerEndInsetFactor = 1;

  final GlobalKey<FormFieldState<T>> _formFieldKey =
      GlobalKey<FormFieldState<T>>();

  late final TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _hasControllerText = false;
  bool _isSyncingControllerText = false;
  bool _hadFocus = false;
  bool _browseAllOptions = false;
  Object? _dropdownEntriesCacheToken;
  List<DropdownMenuEntry<T>>? _cachedDropdownEntries;

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

    if (oldWidget.options != widget.options) {
      _invalidateDropdownEntriesCache();
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
    // Searchable selects must remain focusable so the inner TextField accepts
    // typing. DropdownMenu ignores [requestFocusOnTap] when a focusNode is set.
    if (widget.searchable) {
      _focusNode.canRequestFocus = true;
    }
    _focusNode.addListener(_handleFocusChanged);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool canSelect = widget.enabled;
    Widget field = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double? width =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final double effectiveMenuHeight = _effectiveMenuHeight(context);
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
        // Searchable fields must use DropdownMenu's native filter path so
        // typing updates the open overlay immediately (not only after a
        // parent rebuild of dropdownMenuEntries).
        final bool useNativeFilter =
            widget.searchable || widget.filterCallback != null;
        final bool useNativeSearch = widget.searchCallback != null;
        final bool menuIsOpen = _focusNode.hasFocus;
        final _SelectMenuChrome menuChrome = _selectMenuChrome(
          theme,
          colorScheme,
          menuIsOpen: menuIsOpen,
        );
        final _SelectMenuChrome entryChrome = _selectMenuChrome(
          theme,
          colorScheme,
          menuIsOpen: false,
        );
        final MenuStyle menuStyle = _selectMenuStyle(theme, menuChrome);
        final List<DropdownMenuEntry<T>> dropdownMenuEntries =
            _cachedDropdownMenuEntries(theme, colorScheme, entryChrome);

        return DropdownMenuFormField<T>(
          key: _formFieldKey,
          restorationId: widget.restorationId,
          controller: _controller,
          initialSelection: widget.value,
          enabled: canSelect,
          width: width,
          menuHeight: effectiveMenuHeight,
          menuStyle: menuStyle,
          alignmentOffset: Offset(0, -menuChrome.borderWidth),
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
            fontWeight: FontWeight.w400,
          ),
          enableFilter: useNativeFilter,
          enableSearch: useNativeSearch,
          keyboardType: widget.searchable ? TextInputType.text : null,
          expandedInsets: EdgeInsets.zero,
          filterCallback: useNativeFilter
              ? (List<DropdownMenuEntry<T>> entries, String filter) =>
                    _filterCurrentEntries(dropdownMenuEntries, filter)
              : null,
          searchCallback: useNativeSearch
              ? widget.searchCallback ?? _searchEntries
              : null,
          requestFocusOnTap: widget.searchable,
          selectOnly: !widget.searchable,
          closeBehavior: DropdownMenuCloseBehavior.self,
          focusNode: _focusNode,
          autovalidateMode: widget.autovalidateMode,
          validator: widget.validator,
          onSaved: widget.onSaved,
          forceErrorText: widget.errorText,
          onSelected: _commitSelection,
          dropdownMenuEntries: dropdownMenuEntries,
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

  void _commitSelection(T? value) {
    _browseAllOptions = false;
    _invalidateDropdownEntriesCache();
    _syncControllerForSelection(value);
    widget.onChanged?.call(value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    });
  }

  void _invalidateDropdownEntriesCache() {
    _dropdownEntriesCacheToken = null;
    _cachedDropdownEntries = null;
  }

  void _clearSelection() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    _browseAllOptions = false;
    _syncControllerForSelection(null);
    _formFieldKey.currentState?.didChange(null);
  }

  void _syncControllerForSelection(T? value) {
    final String label = _labelForValue(value);
    if (_controller.text == label) {
      return;
    }
    _isSyncingControllerText = true;
    try {
      if (label.isEmpty) {
        _controller.clear();
      } else {
        _controller.value = TextEditingValue(text: label);
      }
    } finally {
      _isSyncingControllerText = false;
    }
  }

  void _handleFocusChanged() {
    final bool hasFocus = _focusNode.hasFocus;
    if (widget.searchable) {
      if (hasFocus && !_hadFocus) {
        _browseAllOptions = true;
        // Select-all so the next keystroke replaces the current label and
        // filters the menu, instead of appending onto the selected option.
        final String text = _controller.text;
        if (text.isNotEmpty) {
          _isSyncingControllerText = true;
          try {
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: text.length,
            );
          } finally {
            _isSyncingControllerText = false;
          }
        }
      } else if (!hasFocus && _hadFocus) {
        _browseAllOptions = false;
        _syncControllerForSelection(widget.value);
      }
    }
    final bool shouldRebuild = _hadFocus != hasFocus;
    _hadFocus = hasFocus;
    if (shouldRebuild && mounted) {
      setState(() {});
    }
  }

  void _handleControllerChanged() {
    final bool hasText = _controller.text.isNotEmpty;
    final bool shouldRefreshSearchEntries =
        !_isSyncingControllerText && widget.searchable;
    if (!_isSyncingControllerText &&
        widget.searchable &&
        _focusNode.hasFocus &&
        _browseAllOptions) {
      _browseAllOptions = false;
      _invalidateDropdownEntriesCache();
    }
    if (hasText != _hasControllerText || shouldRefreshSearchEntries) {
      void updateControllerState() {
        if (!mounted) {
          return;
        }
        setState(() {
          _hasControllerText = hasText;
        });
      }

      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        updateControllerState();
      } else {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => updateControllerState(),
        );
      }
    }

    if (!_isSyncingControllerText) {
      widget.onSearchTextChanged?.call(_controller.text);
    }
  }

  double _effectiveMenuHeight(BuildContext context) {
    if (_showingEmptyResults) {
      return _emptyResultsMenuHeight;
    }
    final Size screenSize = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final double preferredHeight =
        widget.menuHeight ??
        (screenSize.height * 0.42)
            .clamp(_defaultMenuMinHeight, _defaultMenuMaxHeight)
            .toDouble();
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return preferredHeight;
    }

    final Offset fieldOffset = renderObject.localToGlobal(Offset.zero);
    final double fieldTop = fieldOffset.dy;
    final double fieldBottom = fieldTop + renderObject.size.height;
    final double viewportTop = padding.top + _menuViewportPadding;
    final double viewportBottom =
        screenSize.height -
        padding.bottom -
        viewInsets.bottom -
        _menuViewportPadding;
    final double spaceBelow = viewportBottom - fieldBottom - _menuFieldGap;
    final double spaceAbove = fieldTop - viewportTop - _menuFieldGap;
    final double availableHeight = <double>[
      spaceBelow,
      spaceAbove,
    ].reduce((double left, double right) => left > right ? left : right);

    if (availableHeight <= 0) {
      return preferredHeight;
    }
    return preferredHeight.clamp(0.0, availableHeight).toDouble();
  }

  bool get _showingEmptyResults {
    if (!widget.searchable ||
        widget.emptyResultsText == null ||
        !_focusNode.hasFocus ||
        _browseAllOptions) {
      return false;
    }
    final List<String> tokens = _queryTokens(_controller.text);
    if (tokens.isEmpty) {
      return false;
    }
    return _menuOptions().isEmpty;
  }

  Color _fieldFillColor(ThemeData theme) {
    return theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surface;
  }

  _SelectMenuChrome _selectMenuChrome(
    ThemeData theme,
    ColorScheme colorScheme, {
    required bool menuIsOpen,
  }) {
    final InputBorder? focusedBorder = theme.inputDecorationTheme.focusedBorder;
    final InputBorder? enabledBorder = theme.inputDecorationTheme.enabledBorder;
    final Color focusedBorderColor =
        focusedBorder?.borderSide.color ?? colorScheme.primary;
    final double focusedBorderWidth = focusedBorder?.borderSide.width ?? 1.4;
    final Color enabledBorderColor =
        enabledBorder?.borderSide.color ?? colorScheme.outlineVariant;
    final double enabledBorderWidth =
        enabledBorder?.borderSide.width ?? theme.appTokens.dividerThickness;

    return _SelectMenuChrome(
      fillColor: _fieldFillColor(theme),
      borderColor: menuIsOpen ? focusedBorderColor : enabledBorderColor,
      borderWidth: menuIsOpen ? focusedBorderWidth : enabledBorderWidth,
      dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.72),
      hoverColor: colorScheme.onSurface.withValues(alpha: 0.06),
      shadowColor: colorScheme.shadow.withValues(alpha: 0.14),
    );
  }

  MenuStyle _selectMenuStyle(ThemeData theme, _SelectMenuChrome chrome) {
    return MenuStyle(
      elevation: const WidgetStatePropertyAll<double?>(3),
      shadowColor: WidgetStatePropertyAll<Color?>(chrome.shadowColor),
      surfaceTintColor: const WidgetStatePropertyAll<Color?>(
        Colors.transparent,
      ),
      backgroundColor: WidgetStatePropertyAll<Color?>(chrome.fillColor),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.zero,
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          side: BorderSide(
            color: chrome.borderColor,
            width: chrome.borderWidth,
          ),
        ),
      ),
      visualDensity: theme.visualDensity,
    );
  }

  ButtonStyle _menuItemStyle(ThemeData theme, _SelectMenuChrome chrome) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          return chrome.hoverColor;
        }
        return Colors.transparent;
      }),
      surfaceTintColor: const WidgetStatePropertyAll<Color?>(
        Colors.transparent,
      ),
      elevation: const WidgetStatePropertyAll<double?>(0),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.zero,
      ),
      minimumSize: const WidgetStatePropertyAll<Size>(Size.fromHeight(48)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: theme.visualDensity,
    );
  }

  Widget _menuEntryLabel(
    ThemeData theme,
    ColorScheme colorScheme,
    _SelectMenuChrome chrome,
    AppSelectOption<T> option, {
    required bool showDivider,
  }) {
    final TextStyle? labelStyle = theme.textTheme.bodyLarge?.copyWith(
      color: option.enabled
          ? colorScheme.onSurface
          : colorScheme.onSurface.withValues(alpha: 0.38),
      fontWeight: FontWeight.w400,
    );
    final Widget label =
        option.labelWidget ?? Text(option.label, style: labelStyle);
    final double dividerEndInset =
        theme.spacing.lg * _menuItemDividerEndInsetFactor;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.lg,
        vertical: theme.spacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (option.leadingIcon != null) ...<Widget>[
                option.leadingIcon!,
                SizedBox(width: theme.spacing.sm),
              ],
              Expanded(child: label),
              if (option.trailingIcon != null) option.trailingIcon!,
            ],
          ),
          if (showDivider)
            Padding(
              padding: EdgeInsets.only(top: theme.spacing.sm),
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: dividerEndInset),
                child: Container(
                  height: _menuItemDividerThickness,
                  color: chrome.dividerColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Object _computeDropdownEntriesCacheKey() {
    final bool filterByQuery =
        widget.searchable &&
        _focusNode.hasFocus &&
        !_browseAllOptions &&
        _queryTokens(_controller.text).isNotEmpty;
    return Object.hash(
      widget.options,
      filterByQuery ? _controller.text : null,
      widget.emptyResultsText,
    );
  }

  List<DropdownMenuEntry<T>> _cachedDropdownMenuEntries(
    ThemeData theme,
    ColorScheme colorScheme,
    _SelectMenuChrome entryChrome,
  ) {
    final Object cacheKey = _computeDropdownEntriesCacheKey();
    if (_cachedDropdownEntries != null &&
        _dropdownEntriesCacheToken == cacheKey) {
      return _cachedDropdownEntries!;
    }

    _dropdownEntriesCacheToken = cacheKey;
    _cachedDropdownEntries = _dropdownMenuEntries(
      theme,
      colorScheme,
      entryChrome,
    );
    return _cachedDropdownEntries!;
  }

  List<DropdownMenuEntry<T>> _dropdownMenuEntries(
    ThemeData theme,
    ColorScheme colorScheme,
    _SelectMenuChrome entryChrome,
  ) {
    final Iterable<AppSelectOption<T>> options = _menuOptions();
    final List<AppSelectOption<T>> optionList = options.toList(growable: false);
    if (optionList.isEmpty) {
      return _emptyResultsEntries(theme, colorScheme);
    }
    return <DropdownMenuEntry<T>>[
      for (int index = 0; index < optionList.length; index++)
        DropdownMenuEntry<T>(
          value: optionList[index].value,
          label: optionList[index].label,
          labelWidget: _menuEntryLabel(
            theme,
            colorScheme,
            entryChrome,
            optionList[index],
            showDivider: index < optionList.length - 1,
          ),
          enabled: optionList[index].enabled,
          style: _menuItemStyle(theme, entryChrome),
        ),
    ];
  }

  List<DropdownMenuEntry<T>> _emptyResultsEntries(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final String? message = widget.emptyResultsText?.trim();
    final T? sentinel = _emptyResultsSentinelValue();
    if (message == null || message.isEmpty || sentinel == null) {
      return <DropdownMenuEntry<T>>[];
    }
    final TextStyle? labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );
    return <DropdownMenuEntry<T>>[
      DropdownMenuEntry<T>(
        value: sentinel,
        label: message,
        enabled: false,
        labelWidget: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.lg,
            vertical: theme.spacing.sm,
          ),
          child: Text(message, style: labelStyle),
        ),
        style: _menuItemStyle(
          theme,
          _selectMenuChrome(theme, colorScheme, menuIsOpen: false),
        ),
      ),
    ];
  }

  T? _emptyResultsSentinelValue() {
    if (widget.value != null) {
      return widget.value;
    }
    if (widget.options.isNotEmpty) {
      return widget.options.first.value;
    }
    return null;
  }

  List<DropdownMenuEntry<T>> _filterCurrentEntries(
    List<DropdownMenuEntry<T>> entries,
    String filter,
  ) {
    final FilterCallback<T>? filterCallback = widget.filterCallback;
    final List<DropdownMenuEntry<T>> filtered = filterCallback != null
        ? filterCallback(entries, filter)
        : _filterEntries(entries, filter);
    if (filtered.isNotEmpty) {
      return filtered;
    }
    final ThemeData theme = Theme.of(context);
    return _emptyResultsEntries(theme, theme.colorScheme);
  }

  Iterable<AppSelectOption<T>> _menuOptions() {
    if (!widget.searchable || widget.filterCallback != null) {
      return widget.options;
    }

    if (!_focusNode.hasFocus || _browseAllOptions) {
      return widget.options.take(_maxFilteredOptions);
    }

    final List<String> tokens = _queryTokens(_controller.text);
    if (tokens.isEmpty) {
      return widget.options.take(_maxFilteredOptions);
    }

    return widget.options
        .where((AppSelectOption<T> option) {
          final String searchable = _searchTextForOption(option);
          return tokens.every(searchable.contains);
        })
        .take(_maxFilteredOptions);
  }

  String _labelForValue(T? value) {
    return _labelForValueInOptions(value, widget.options);
  }

  String _labelForValueInOptions(T? value, List<AppSelectOption<T>> options) {
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

  String _searchTextForOption(AppSelectOption<T> option) {
    final String raw = <String>[
      option.label,
      option.searchText ?? '',
      option.value.toString(),
    ].where((String value) => value.trim().isNotEmpty).join(' ');
    return _normalizeSearchText(raw);
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

class _SelectMenuChrome {
  const _SelectMenuChrome({
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.dividerColor,
    required this.hoverColor,
    required this.shadowColor,
  });

  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final Color dividerColor;
  final Color hoverColor;
  final Color shadowColor;
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
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.close,
              label: MaterialLocalizations.of(context).clearButtonTooltip,
              semanticLabel: MaterialLocalizations.of(
                context,
              ).clearButtonTooltip,
              tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
              onPressed: onClear,
            ),
          if (isLoading)
            Padding(
              padding: EdgeInsetsDirectional.only(end: theme.spacing.xs),
              child: SizedBox.square(
                dimension: theme.appTokens.listIconSize * 0.78,
                child: const FittedBox(
                  child: AppLoadingIndicator(
                    size: AppLoadingIndicatorSize.compact,
                    expand: false,
                  ),
                ),
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

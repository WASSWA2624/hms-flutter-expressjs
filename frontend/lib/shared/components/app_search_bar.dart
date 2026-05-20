import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_date_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';

@immutable
final class AppSearchBarFieldChoice {
  const AppSearchBarFieldChoice({
    required this.field,
    required this.label,
    this.icon,
  });

  final String field;
  final String label;
  final IconData? icon;
}

@immutable
final class AppSearchBarTextFilter {
  const AppSearchBarTextFilter({
    required this.key,
    required this.label,
    this.hintText,
    this.icon,
    this.keyboardType,
    this.textInputAction,
  });

  final String key;
  final String label;
  final String? hintText;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
}

@immutable
final class AppSearchBarFilterChoice {
  const AppSearchBarFilterChoice({
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;
}

@immutable
final class AppSearchBarFilterGroup {
  const AppSearchBarFilterGroup({
    required this.key,
    required this.label,
    required this.choices,
    this.allLabel,
  });

  final String key;
  final String label;
  final List<AppSearchBarFilterChoice> choices;
  final String? allLabel;
}

@immutable
final class AppSearchBarFilterValue {
  const AppSearchBarFilterValue({
    this.field,
    this.dateFrom,
    this.dateTo,
    this.texts = const <String, String>{},
    this.options = const <String, String>{},
  });

  static const AppSearchBarFilterValue empty = AppSearchBarFilterValue();

  final String? field;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Map<String, String> texts;
  final Map<String, String> options;

  bool get isActive {
    return _hasText(field) ||
        dateFrom != null ||
        dateTo != null ||
        texts.values.any(_hasText) ||
        options.values.any(_hasText);
  }

  String? text(String key) {
    final String? value = texts[key];
    return _hasText(value) ? value : null;
  }

  String? option(String key) {
    final String? value = options[key];
    return _hasText(value) ? value : null;
  }

  AppSearchBarFilterValue copyWith({
    String? field,
    DateTime? dateFrom,
    DateTime? dateTo,
    Map<String, String>? texts,
    Map<String, String>? options,
    bool clearField = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearTexts = false,
    bool clearOptions = false,
  }) {
    return AppSearchBarFilterValue(
      field: clearField ? null : field ?? this.field,
      dateFrom: clearDateFrom ? null : dateFrom ?? this.dateFrom,
      dateTo: clearDateTo ? null : dateTo ?? this.dateTo,
      texts: clearTexts ? const <String, String>{} : texts ?? this.texts,
      options: clearOptions
          ? const <String, String>{}
          : options ?? this.options,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSearchBarFilterValue &&
        other.field == field &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo &&
        mapEquals(other.texts, texts) &&
        mapEquals(other.options, options);
  }

  @override
  int get hashCode {
    final List<String> textKeys = texts.keys.toList(growable: false)..sort();
    final List<String> optionKeys = options.keys.toList(growable: false)
      ..sort();
    return Object.hash(
      field,
      dateFrom,
      dateTo,
      Object.hashAll(
        textKeys.map((String key) => Object.hash(key, texts[key])),
      ),
      Object.hashAll(
        optionKeys.map((String key) => Object.hash(key, options[key])),
      ),
    );
  }
}

class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    required this.controller,
    required this.semanticLabel,
    this.hintText,
    this.clearLabel,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.enabled = true,
    this.isLoading = false,
    this.autofocus = false,
    this.showClearButton = true,
    this.focusNode,
    this.showAdvancedFilterButton = false,
    this.onAdvancedFilterPressed,
    this.advancedFilterButtonLabel,
    this.advancedFilterTitle,
    this.advancedFilterApplyLabel,
    this.advancedFilterResetLabel,
    this.advancedFilterCancelLabel,
    this.searchFields = const <AppSearchBarFieldChoice>[],
    this.textFilters = const <AppSearchBarTextFilter>[],
    this.searchFieldLabel,
    this.allFieldsLabel,
    this.enableDateFilter = true,
    this.dateFilterLabel,
    this.dateFromLabel,
    this.dateToLabel,
    this.datePickerButtonLabel,
    this.invalidDateMessage,
    this.firstDate,
    this.lastDate,
    this.currentDate,
    this.filterGroups = const <AppSearchBarFilterGroup>[],
    this.filterValue = AppSearchBarFilterValue.empty,
    this.onFilterChanged,
    this.hasActiveFilters = false,
    super.key,
  });

  final TextEditingController controller;
  final String semanticLabel;
  final String? hintText;
  final String? clearLabel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool enabled;
  final bool isLoading;
  final bool autofocus;
  final bool showClearButton;
  final FocusNode? focusNode;
  final bool showAdvancedFilterButton;
  final VoidCallback? onAdvancedFilterPressed;
  final String? advancedFilterButtonLabel;
  final String? advancedFilterTitle;
  final String? advancedFilterApplyLabel;
  final String? advancedFilterResetLabel;
  final String? advancedFilterCancelLabel;
  final List<AppSearchBarFieldChoice> searchFields;
  final List<AppSearchBarTextFilter> textFilters;
  final String? searchFieldLabel;
  final String? allFieldsLabel;
  final bool enableDateFilter;
  final String? dateFilterLabel;
  final String? dateFromLabel;
  final String? dateToLabel;
  final String? datePickerButtonLabel;
  final String? invalidDateMessage;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? currentDate;
  final List<AppSearchBarFilterGroup> filterGroups;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue>? onFilterChanged;
  final bool hasActiveFilters;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _attachFocusNode();
  }

  @override
  void didUpdateWidget(covariant AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }
  }

  @override
  void dispose() {
    _detachFocusNode();
    super.dispose();
  }

  void _attachFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (BuildContext context, TextEditingValue value, _) {
        final ThemeData theme = Theme.of(context);
        final bool canEdit = widget.enabled && !widget.isLoading;
        final String clearLabel =
            widget.clearLabel ??
            MaterialLocalizations.of(context).clearButtonTooltip;
        final bool canClear =
            widget.showClearButton &&
            value.text.isNotEmpty &&
            widget.enabled &&
            !widget.isLoading;
        final bool showFilters = _shouldShowFilterButton;
        final BorderSide borderSide = _borderSide(theme);
        final double minHeight =
            theme.inputDecorationTheme.constraints?.minHeight ?? 48;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: _fillColor(theme, canEdit),
            border: Border.all(
              color: borderSide.color,
              width: borderSide.width,
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    textField: true,
                    enabled: canEdit,
                    label: widget.semanticLabel,
                    child: TextFormField(
                      controller: widget.controller,
                      enabled: canEdit,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      textInputAction: TextInputAction.search,
                      onChanged: widget.onChanged,
                      onFieldSubmitted: widget.onSubmitted,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: canEdit
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.62,
                              ),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _suffixIcon(clearLabel, canClear),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                if (showFilters)
                  _AttachedFilterButton(
                    borderColor: borderSide.color,
                    enabled: widget.enabled && !widget.isLoading,
                    active:
                        widget.hasActiveFilters || widget.filterValue.isActive,
                    label:
                        widget.advancedFilterButtonLabel ?? 'Advanced filters',
                    onPressed: _openAdvancedFilters,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _suffixIcon(String clearLabel, bool canClear) {
    if (widget.isLoading) {
      final ThemeData theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: SizedBox.square(
          dimension: theme.appTokens.listIconSize,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!canClear) {
      return null;
    }

    return AppIconButton(
      icon: Icons.close,
      semanticLabel: clearLabel,
      tooltip: clearLabel,
      onPressed: _clear,
    );
  }

  BorderSide _borderSide(ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    if (!widget.enabled) {
      return _sideFromBorder(theme.inputDecorationTheme.disabledBorder) ??
          BorderSide(color: colorScheme.outlineVariant);
    }

    if (_focusNode.hasFocus) {
      return _sideFromBorder(theme.inputDecorationTheme.focusedBorder) ??
          BorderSide(color: colorScheme.primary, width: 1.4);
    }

    return _sideFromBorder(theme.inputDecorationTheme.enabledBorder) ??
        BorderSide(color: colorScheme.outlineVariant);
  }

  BorderSide? _sideFromBorder(InputBorder? border) {
    if (border is OutlineInputBorder) {
      return border.borderSide;
    }
    if (border is UnderlineInputBorder) {
      return border.borderSide;
    }
    return null;
  }

  Color _fillColor(ThemeData theme, bool canEdit) {
    final Color fallback = canEdit
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38);
    return theme.inputDecorationTheme.fillColor ?? fallback;
  }

  bool get _shouldShowFilterButton {
    return widget.showAdvancedFilterButton ||
        widget.onAdvancedFilterPressed != null ||
        widget.onFilterChanged != null ||
        widget.searchFields.isNotEmpty ||
        widget.textFilters.isNotEmpty ||
        widget.filterGroups.isNotEmpty;
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  Future<void> _openAdvancedFilters() async {
    if (!widget.enabled || widget.isLoading) {
      return;
    }

    final VoidCallback? customHandler = widget.onAdvancedFilterPressed;
    if (customHandler != null) {
      customHandler();
      return;
    }

    final AppSearchBarFilterValue?
    value = await showAppDialog<AppSearchBarFilterValue>(
      context: context,
      builder: (_) => _AppSearchBarFiltersDialog(
        title: widget.advancedFilterTitle ?? 'Advanced filters',
        applyLabel: widget.advancedFilterApplyLabel ?? 'Apply filters',
        resetLabel: widget.advancedFilterResetLabel ?? 'Reset filters',
        cancelLabel:
            widget.advancedFilterCancelLabel ??
            MaterialLocalizations.of(context).cancelButtonLabel,
        searchFields: widget.searchFields,
        textFilters: widget.textFilters,
        searchFieldLabel: widget.searchFieldLabel ?? 'Search in',
        allFieldsLabel: widget.allFieldsLabel ?? 'All fields',
        enableDateFilter: widget.enableDateFilter,
        dateFilterLabel: widget.dateFilterLabel ?? 'Date',
        dateFromLabel: widget.dateFromLabel ?? 'From',
        dateToLabel: widget.dateToLabel ?? 'To',
        datePickerButtonLabel: widget.datePickerButtonLabel ?? 'Choose date',
        invalidDateMessage: widget.invalidDateMessage ?? 'Enter a valid date.',
        firstDate: widget.firstDate ?? DateTime(1900),
        lastDate: widget.lastDate ?? _defaultLastDate(),
        currentDate: widget.currentDate,
        filterGroups: widget.filterGroups,
        initialValue: widget.filterValue,
      ),
    );
    if (!mounted || value == null) {
      return;
    }

    widget.onFilterChanged?.call(value);
  }

  DateTime _defaultLastDate() {
    final DateTime now = DateTime.now();
    return DateTime(now.year + 20, 12, 31);
  }
}

class _AttachedFilterButton extends StatelessWidget {
  const _AttachedFilterButton({
    required this.borderColor,
    required this.enabled,
    required this.active,
    required this.label,
    required this.onPressed,
  });

  final Color borderColor;
  final bool enabled;
  final bool active;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color foreground = active
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final Color background = active
        ? colorScheme.primaryContainer.withValues(alpha: 0.54)
        : Colors.transparent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: BorderDirectional(start: BorderSide(color: borderColor)),
      ),
      child: SizedBox(
        width: theme.appTokens.minInteractiveDimension + theme.spacing.sm,
        child: Center(
          child: Semantics(
            button: true,
            enabled: enabled,
            label: label,
            selected: active,
            child: IconButton(
              tooltip: label,
              onPressed: enabled ? onPressed : null,
              color: foreground,
              icon: Icon(
                active ? Icons.filter_alt : Icons.tune,
                size: theme.appTokens.listIconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppSearchBarFiltersDialog extends StatefulWidget {
  const _AppSearchBarFiltersDialog({
    required this.title,
    required this.applyLabel,
    required this.resetLabel,
    required this.cancelLabel,
    required this.searchFields,
    required this.textFilters,
    required this.searchFieldLabel,
    required this.allFieldsLabel,
    required this.enableDateFilter,
    required this.dateFilterLabel,
    required this.dateFromLabel,
    required this.dateToLabel,
    required this.datePickerButtonLabel,
    required this.invalidDateMessage,
    required this.firstDate,
    required this.lastDate,
    required this.currentDate,
    required this.filterGroups,
    required this.initialValue,
  });

  final String title;
  final String applyLabel;
  final String resetLabel;
  final String cancelLabel;
  final List<AppSearchBarFieldChoice> searchFields;
  final List<AppSearchBarTextFilter> textFilters;
  final String searchFieldLabel;
  final String allFieldsLabel;
  final bool enableDateFilter;
  final String dateFilterLabel;
  final String dateFromLabel;
  final String dateToLabel;
  final String datePickerButtonLabel;
  final String invalidDateMessage;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? currentDate;
  final List<AppSearchBarFilterGroup> filterGroups;
  final AppSearchBarFilterValue initialValue;

  @override
  State<_AppSearchBarFiltersDialog> createState() =>
      _AppSearchBarFiltersDialogState();
}

class _AppSearchBarFiltersDialogState
    extends State<_AppSearchBarFiltersDialog> {
  static const String _allValue = '__all__';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String? _field;
  late DateTime? _dateFrom;
  late DateTime? _dateTo;
  late Map<String, TextEditingController> _textControllers;
  late Map<String, String> _options;

  @override
  void initState() {
    super.initState();
    _textControllers = <String, TextEditingController>{
      for (final AppSearchBarTextFilter filter in widget.textFilters)
        filter.key: TextEditingController(),
    };
    _hydrate(widget.initialValue);
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.tune),
      scrollable: true,
      maxWidth: 760,
      content: AppFieldRequirementScope(
        showOptionalIndicators: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.searchFields.isNotEmpty) ...<Widget>[
                _FilterControlShell(
                  child: AppSelectField<String>.searchable(
                    value: _field ?? _allValue,
                    labelText: widget.searchFieldLabel,
                    options: <AppSelectOption<String>>[
                      AppSelectOption<String>(
                        value: _allValue,
                        label: widget.allFieldsLabel,
                        leadingIcon: const Icon(Icons.manage_search_outlined),
                      ),
                      for (final AppSearchBarFieldChoice field
                          in widget.searchFields)
                        AppSelectOption<String>(
                          value: field.field,
                          label: field.label,
                          leadingIcon: field.icon == null
                              ? null
                              : Icon(field.icon),
                        ),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _field = value == null || value == _allValue
                            ? null
                            : value;
                      });
                    },
                  ),
                ),
                SizedBox(height: theme.spacing.md),
              ],
              if (widget.textFilters.isNotEmpty) ...<Widget>[
                _DialogSectionTitle(label: widget.searchFieldLabel),
                SizedBox(height: theme.spacing.sm),
                _ResponsiveFilterGrid(
                  children: <Widget>[
                    for (final AppSearchBarTextFilter filter
                        in widget.textFilters)
                      TextFormField(
                        controller: _textControllers[filter.key],
                        keyboardType: filter.keyboardType,
                        textInputAction:
                            filter.textInputAction ?? TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: filter.label,
                          hintText: filter.hintText,
                          prefixIcon: filter.icon == null
                              ? null
                              : Icon(filter.icon),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: theme.spacing.md),
              ],
              if (widget.enableDateFilter) ...<Widget>[
                _DialogSectionTitle(label: widget.dateFilterLabel),
                SizedBox(height: theme.spacing.sm),
                _ResponsiveFilterRow(
                  left: _FilterControlShell(
                    child: AppDateField(
                      value: _dateFrom,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      currentDate: widget.currentDate,
                      pickerButtonLabel: widget.datePickerButtonLabel,
                      invalidDateMessage: widget.invalidDateMessage,
                      labelText: widget.dateFromLabel,
                      onChanged: (DateTime? value) {
                        _dateFrom = value;
                      },
                    ),
                  ),
                  right: _FilterControlShell(
                    child: AppDateField(
                      value: _dateTo,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      currentDate: widget.currentDate,
                      pickerButtonLabel: widget.datePickerButtonLabel,
                      invalidDateMessage: widget.invalidDateMessage,
                      labelText: widget.dateToLabel,
                      onChanged: (DateTime? value) {
                        _dateTo = value;
                      },
                    ),
                  ),
                ),
              ],
              if (widget.filterGroups.any(_hasFilterChoices)) ...<Widget>[
                SizedBox(height: theme.spacing.md),
                _ResponsiveFilterGrid(
                  children: <Widget>[
                    for (final AppSearchBarFilterGroup group
                        in widget.filterGroups)
                      if (group.choices.isNotEmpty)
                        AppSelectField<String>.searchable(
                          value: _options[group.key] ?? _allValue,
                          labelText: group.label,
                          options: <AppSelectOption<String>>[
                            AppSelectOption<String>(
                              value: _allValue,
                              label: group.allLabel ?? widget.allFieldsLabel,
                              leadingIcon: const Icon(Icons.filter_list_off),
                            ),
                            for (final AppSearchBarFilterChoice choice
                                in group.choices)
                              AppSelectOption<String>(
                                value: choice.value,
                                label: choice.label,
                                leadingIcon: choice.icon == null
                                    ? null
                                    : Icon(choice.icon),
                              ),
                          ],
                          onChanged: (String? value) {
                            setState(() {
                              final Map<String, String> next =
                                  Map<String, String>.of(_options);
                              if (value == null || value == _allValue) {
                                next.remove(group.key);
                              } else {
                                next[group.key] = value;
                              }
                              _options = next;
                            });
                          },
                        ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: widget.resetLabel,
          leadingIcon: Icons.filter_alt_off_outlined,
          onPressed: _reset,
        ),
        AppButton.secondary(
          label: widget.cancelLabel,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        AppButton.primary(
          label: widget.applyLabel,
          leadingIcon: Icons.check,
          onPressed: _apply,
        ),
      ],
    );
  }

  void _hydrate(AppSearchBarFilterValue value) {
    _field = _knownField(value.field);
    _dateFrom = value.dateFrom;
    _dateTo = value.dateTo;
    final Map<String, String> texts = _knownTexts(value.texts);
    for (final AppSearchBarTextFilter filter in widget.textFilters) {
      _textControllers[filter.key]?.text = texts[filter.key] ?? '';
    }
    _options = _knownOptions(value.options);
  }

  void _reset() {
    setState(() {
      _hydrate(AppSearchBarFilterValue.empty);
    });
  }

  void _apply() {
    final bool isValid = _formKey.currentState?.validate() ?? true;
    if (!isValid) {
      return;
    }
    Navigator.of(context).pop(_value);
  }

  AppSearchBarFilterValue get _value {
    return AppSearchBarFilterValue(
      field: _field,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      texts: Map<String, String>.unmodifiable(<String, String>{
        for (final MapEntry<String, TextEditingController> entry
            in _textControllers.entries)
          if (_hasText(entry.value.text)) entry.key: entry.value.text.trim(),
      }),
      options: Map<String, String>.unmodifiable(_options),
    );
  }

  String? _knownField(String? field) {
    if (!_hasText(field)) {
      return null;
    }
    final bool exists = widget.searchFields.any(
      (AppSearchBarFieldChoice choice) => choice.field == field,
    );
    return exists ? field : null;
  }

  Map<String, String> _knownTexts(Map<String, String> texts) {
    final Set<String> knownKeys = widget.textFilters
        .map((AppSearchBarTextFilter filter) => filter.key)
        .toSet();
    return <String, String>{
      for (final MapEntry<String, String> entry in texts.entries)
        if (knownKeys.contains(entry.key) && _hasText(entry.value))
          entry.key: entry.value.trim(),
    };
  }

  Map<String, String> _knownOptions(Map<String, String> options) {
    final Map<String, String> known = <String, String>{};
    for (final AppSearchBarFilterGroup group in widget.filterGroups) {
      final String? value = options[group.key];
      if (!_hasText(value)) {
        continue;
      }
      final bool exists = group.choices.any(
        (AppSearchBarFilterChoice choice) => choice.value == value,
      );
      if (exists) {
        known[group.key] = value!;
      }
    }
    return known;
  }
}

bool _hasFilterChoices(AppSearchBarFilterGroup group) {
  return group.choices.isNotEmpty;
}

class _DialogSectionTitle extends StatelessWidget {
  const _DialogSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FilterControlShell extends StatelessWidget {
  const _FilterControlShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: Theme.of(context).spacing.xs),
      child: child,
    );
  }
}

class _ResponsiveFilterGrid extends StatelessWidget {
  const _ResponsiveFilterGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double spacing = theme.spacing.md;
        final bool twoColumns = constraints.maxWidth >= 620;
        final double itemWidth = twoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: theme.spacing.md,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(
                width: itemWidth,
                child: _FilterControlShell(child: child),
              ),
          ],
        );
      },
    );
  }
}

class _ResponsiveFilterRow extends StatelessWidget {
  const _ResponsiveFilterRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              left,
              SizedBox(height: theme.spacing.sm),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            SizedBox(width: theme.spacing.sm),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

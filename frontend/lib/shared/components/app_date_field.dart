import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/src/app_field_label.dart';

class AppDateField extends StatefulWidget {
  const AppDateField({
    required this.firstDate,
    required this.lastDate,
    required this.pickerButtonLabel,
    required this.invalidDateMessage,
    this.value,
    this.onChanged,
    this.initialPickerDate,
    this.currentDate,
    this.labelText,
    this.yearLabelText = 'YYYY',
    this.monthLabelText = 'MM',
    this.dayLabelText = 'DD',
    this.hintText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.isRequired = false,
    this.focusNode,
    this.restorationId,
    this.initialEntryMode = DatePickerEntryMode.calendar,
    this.selectableDayPredicate,
    super.key,
  });

  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialPickerDate;
  final DateTime? currentDate;
  final String pickerButtonLabel;
  final String invalidDateMessage;
  final String? labelText;
  final String yearLabelText;
  final String monthLabelText;
  final String dayLabelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<DateTime>? validator;
  final FormFieldSetter<DateTime>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final bool isRequired;
  final FocusNode? focusNode;
  final String? restorationId;
  final DatePickerEntryMode initialEntryMode;
  final SelectableDayPredicate? selectableDayPredicate;

  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState extends State<AppDateField> {
  late final TextEditingController _yearController;
  late final TextEditingController _monthController;
  late final TextEditingController _dayController;
  late FocusNode _yearFocusNode;
  late FocusNode _monthFocusNode;
  late FocusNode _dayFocusNode;
  late bool _ownsYearFocusNode;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _yearController = TextEditingController();
    _monthController = TextEditingController();
    _dayController = TextEditingController();
    _syncControllersFromDate(widget.value);
    _attachFocusNode();
  }

  @override
  void didUpdateWidget(AppDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }
    if (oldWidget.value != widget.value && !_hasFocus) {
      _syncControllersFromDate(widget.value);
    }
  }

  @override
  void dispose() {
    _detachFocusNode();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _attachFocusNode() {
    _ownsYearFocusNode = widget.focusNode == null;
    _yearFocusNode = widget.focusNode ?? FocusNode();
    _monthFocusNode = FocusNode();
    _dayFocusNode = FocusNode();
    _yearFocusNode.addListener(_handleFocusChanged);
    _monthFocusNode.addListener(_handleFocusChanged);
    _dayFocusNode.addListener(_handleFocusChanged);
  }

  void _detachFocusNode() {
    _yearFocusNode.removeListener(_handleFocusChanged);
    _monthFocusNode.removeListener(_handleFocusChanged);
    _dayFocusNode.removeListener(_handleFocusChanged);
    if (_ownsYearFocusNode) {
      _yearFocusNode.dispose();
    }
    _monthFocusNode.dispose();
    _dayFocusNode.dispose();
  }

  void _handleFocusChanged() {
    if (!_hasFocus) {
      final _DatePartsValidationResult result = _validateParts();
      if (result.isValid) {
        _syncControllersFromDate(result.date);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canChange = widget.enabled;

    return FormField<DateTime>(
      initialValue: widget.value,
      enabled: canChange,
      validator: (_) => _validate(),
      onSaved: (_) => widget.onSaved?.call(_parseParts()),
      autovalidateMode: widget.autovalidateMode,
      forceErrorText: widget.errorText,
      onReset: () => _syncControllersFromDate(widget.value),
      builder: (FormFieldState<DateTime> field) {
        Widget dateField = InputDecorator(
          isFocused: _hasFocus,
          isEmpty: _allPartsEmpty,
          decoration: InputDecoration(
            enabled: canChange,
            label: appFieldLabelWidget(
              context,
              widget.labelText,
              isRequired: widget.isRequired,
            ),
            helperText: widget.helperText,
            errorText: field.errorText,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding: EdgeInsetsDirectional.fromSTEB(
              theme.spacing.md,
              theme.spacing.md,
              theme.spacing.xs,
              theme.spacing.sm,
            ),
            suffixIcon: _DatePickerButton(
              label: widget.pickerButtonLabel,
              onPressed: canChange ? () => _selectDate(context, field) : null,
            ),
            suffixIconConstraints: BoxConstraints(
              minWidth:
                  theme.appTokens.minInteractiveDimension + theme.spacing.md,
              minHeight:
                  theme.inputDecorationTheme.constraints?.minHeight ?? 48,
            ),
          ).applyDefaults(theme.inputDecorationTheme),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: <Widget>[
                Flexible(
                  flex: 2,
                  child: SizedBox(
                    width: 30,
                    child: _DatePartTextField(
                      controller: _dayController,
                      focusNode: _dayFocusNode,
                      nextFocusNode: _monthFocusNode,
                      labelText: widget.dayLabelText,
                      hintText: _partHint(0, widget.dayLabelText),
                      maxLength: 2,
                      enabled: canChange,
                      restorationId: _partRestorationId('day'),
                      textInputAction: TextInputAction.next,
                      onChanged: () => _handlePartsChanged(field),
                    ),
                  ),
                ),
                _DatePartSeparator(enabled: canChange),
                Flexible(
                  flex: 2,
                  child: SizedBox(
                    width: 30,
                    child: _DatePartTextField(
                      controller: _monthController,
                      focusNode: _monthFocusNode,
                      nextFocusNode: _yearFocusNode,
                      labelText: widget.monthLabelText,
                      hintText: _partHint(1, widget.monthLabelText),
                      maxLength: 2,
                      enabled: canChange,
                      restorationId: _partRestorationId('month'),
                      textInputAction: TextInputAction.next,
                      onChanged: () => _handlePartsChanged(field),
                    ),
                  ),
                ),
                _DatePartSeparator(enabled: canChange),
                Flexible(
                  flex: 3,
                  child: SizedBox(
                    width: 54,
                    child: _DatePartTextField(
                      controller: _yearController,
                      focusNode: _yearFocusNode,
                      labelText: widget.yearLabelText,
                      hintText: _partHint(2, widget.yearLabelText),
                      maxLength: 4,
                      enabled: canChange,
                      restorationId: _partRestorationId('year'),
                      textInputAction: TextInputAction.done,
                      onChanged: () => _handlePartsChanged(field),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (widget.semanticLabel != null) {
          dateField = Semantics(
            textField: true,
            enabled: canChange,
            label: widget.semanticLabel,
            child: dateField,
          );
        }

        return dateField;
      },
    );
  }

  bool get _hasFocus =>
      _yearFocusNode.hasFocus ||
      _monthFocusNode.hasFocus ||
      _dayFocusNode.hasFocus;

  void _handlePartsChanged(FormFieldState<DateTime> field) {
    if (_isSyncing) {
      return;
    }
    final _DatePartsValidationResult result = _validateParts();
    final DateTime? validDate = result.isValid ? result.date : null;
    field.didChange(validDate);
    widget.onChanged?.call(result.isEmpty ? null : validDate);
  }

  Future<void> _selectDate(
    BuildContext context,
    FormFieldState<DateTime> field,
  ) async {
    final _DatePartsValidationResult partsResult = _validateParts();
    final DateTime? initialDate = _resolveInitialDate(
      partsResult.date ?? field.value,
    );
    if (initialDate == null) {
      field.validate();
      return;
    }

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _dateOnly(widget.firstDate),
      lastDate: _dateOnly(widget.lastDate),
      currentDate: widget.currentDate == null
          ? null
          : _dateOnly(widget.currentDate!),
      initialEntryMode: widget.initialEntryMode,
      selectableDayPredicate: widget.selectableDayPredicate,
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    field.didChange(selectedDate);
    _syncControllersFromDate(selectedDate);
    widget.onChanged?.call(selectedDate);
  }

  DateTime? _resolveInitialDate(DateTime? fieldValue) {
    final DateTime firstDate = _dateOnly(widget.firstDate);
    final DateTime lastDate = _dateOnly(widget.lastDate);
    if (lastDate.isBefore(firstDate)) {
      return null;
    }

    final DateTime fallback = _dateOnly(
      fieldValue ?? widget.value ?? widget.initialPickerDate ?? DateTime.now(),
    );
    final DateTime clampedDate = _clampDate(fallback, firstDate, lastDate);

    if (_isSelectableDate(clampedDate)) {
      return clampedDate;
    }

    return _nearestSelectableDate(clampedDate, firstDate, lastDate);
  }

  String? _validate() {
    final _DatePartsValidationResult result = _validateParts();
    return switch (result.status) {
      _DatePartsValidationStatus.empty => widget.validator?.call(null),
      _DatePartsValidationStatus.valid => widget.validator?.call(result.date),
      _ => widget.invalidDateMessage,
    };
  }

  DateTime? _parseParts() {
    final _DatePartsValidationResult result = _validateParts();
    return result.isValid ? result.date : null;
  }

  _DatePartsValidationResult _validateParts() {
    final String year = _yearController.text.trim();
    final String month = _monthController.text.trim();
    final String day = _dayController.text.trim();
    if (year.isEmpty && month.isEmpty && day.isEmpty) {
      return const _DatePartsValidationResult.empty();
    }
    if (year.length != 4 || month.isEmpty || day.isEmpty) {
      return const _DatePartsValidationResult.incomplete();
    }

    final DateTime? date = _safeDate(
      int.tryParse(year),
      int.tryParse(month),
      int.tryParse(day),
    );
    if (date == null) {
      return const _DatePartsValidationResult.invalid();
    }

    final DateTime firstDate = _dateOnly(widget.firstDate);
    final DateTime lastDate = _dateOnly(widget.lastDate);
    if (lastDate.isBefore(firstDate)) {
      return _DatePartsValidationResult.invalidRange(date);
    }

    if (date.isBefore(firstDate) || date.isAfter(lastDate)) {
      return _DatePartsValidationResult.outOfRange(date);
    }

    if (!_isSelectableDate(date)) {
      return _DatePartsValidationResult.unselectable(date);
    }

    return _DatePartsValidationResult.valid(date);
  }

  DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final DateTime date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return _dateOnly(date);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _clampDate(DateTime value, DateTime firstDate, DateTime lastDate) {
    if (value.isBefore(firstDate)) {
      return firstDate;
    }

    if (value.isAfter(lastDate)) {
      return lastDate;
    }

    return value;
  }

  DateTime? _nearestSelectableDate(
    DateTime value,
    DateTime firstDate,
    DateTime lastDate,
  ) {
    for (int offset = 1; ; offset += 1) {
      final DateTime previousDate = value.subtract(Duration(days: offset));
      final DateTime nextDate = value.add(Duration(days: offset));
      final bool canUsePrevious = !previousDate.isBefore(firstDate);
      final bool canUseNext = !nextDate.isAfter(lastDate);

      if (!canUsePrevious && !canUseNext) {
        return null;
      }

      if (canUseNext && _isSelectableDate(nextDate)) {
        return nextDate;
      }

      if (canUsePrevious && _isSelectableDate(previousDate)) {
        return previousDate;
      }
    }
  }

  bool _isSelectableDate(DateTime date) {
    return widget.selectableDayPredicate?.call(date) ?? true;
  }

  void _syncControllersFromDate(DateTime? value) {
    final String year = value == null ? '' : value.year.toString();
    final String month = value == null
        ? ''
        : value.month.toString().padLeft(2, '0');
    final String day = value == null
        ? ''
        : value.day.toString().padLeft(2, '0');
    _isSyncing = true;
    _yearController.text = year;
    _monthController.text = month;
    _dayController.text = day;
    _isSyncing = false;
  }

  bool get _allPartsEmpty =>
      _yearController.text.trim().isEmpty &&
      _monthController.text.trim().isEmpty &&
      _dayController.text.trim().isEmpty;

  String? _partRestorationId(String part) {
    final String? restorationId = widget.restorationId;
    return restorationId == null ? null : '${restorationId}_$part';
  }

  String _partHint(int index, String fallback) {
    final String? hintText = widget.hintText;
    if (hintText == null || hintText.trim().isEmpty) {
      return fallback;
    }

    final List<String> parts = hintText
        .split(RegExp(r'[/\-\.\s]+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.length != 3) {
      return fallback;
    }

    return parts[index];
  }
}

enum _DatePartsValidationStatus {
  empty,
  incomplete,
  invalid,
  invalidRange,
  outOfRange,
  unselectable,
  valid,
}

class _DatePartsValidationResult {
  const _DatePartsValidationResult._(this.status, this.date);

  const _DatePartsValidationResult.empty()
    : this._(_DatePartsValidationStatus.empty, null);

  const _DatePartsValidationResult.incomplete()
    : this._(_DatePartsValidationStatus.incomplete, null);

  const _DatePartsValidationResult.invalid()
    : this._(_DatePartsValidationStatus.invalid, null);

  const _DatePartsValidationResult.invalidRange(DateTime date)
    : this._(_DatePartsValidationStatus.invalidRange, date);

  const _DatePartsValidationResult.outOfRange(DateTime date)
    : this._(_DatePartsValidationStatus.outOfRange, date);

  const _DatePartsValidationResult.unselectable(DateTime date)
    : this._(_DatePartsValidationStatus.unselectable, date);

  const _DatePartsValidationResult.valid(DateTime date)
    : this._(_DatePartsValidationStatus.valid, date);

  final _DatePartsValidationStatus status;
  final DateTime? date;

  bool get isEmpty => status == _DatePartsValidationStatus.empty;

  bool get isValid => status == _DatePartsValidationStatus.valid;
}

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onPressed != null;
    final double buttonSize = theme.appTokens.minInteractiveDimension;
    final Color disabledColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.38,
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(end: theme.spacing.xs),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(
            Icons.calendar_today_outlined,
            size: theme.appTokens.listIconSize,
          ),
          color: enabled ? theme.colorScheme.onSurfaceVariant : disabledColor,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: enabled ? 0.72 : 0.32),
            disabledBackgroundColor: theme.colorScheme.onSurface.withValues(
              alpha: 0.08,
            ),
            fixedSize: Size.square(buttonSize),
            minimumSize: Size.square(buttonSize),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _DatePartTextField extends StatelessWidget {
  const _DatePartTextField({
    required this.controller,
    required this.focusNode,
    required this.labelText,
    required this.maxLength,
    required this.enabled,
    required this.textInputAction,
    required this.onChanged,
    this.hintText,
    this.nextFocusNode,
    this.restorationId,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final String? hintText;
  final int maxLength;
  final bool enabled;
  final TextInputAction textInputAction;
  final VoidCallback onChanged;
  final String? restorationId;
  final FocusNode? nextFocusNode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color textColor = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.62);

    return TextField(
      controller: controller,
      enabled: enabled,
      focusNode: focusNode,
      restorationId: restorationId,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      maxLength: maxLength,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: (String value) {
        onChanged();
        if (value.length == maxLength) {
          nextFocusNode?.requestFocus();
        }
      },
      onSubmitted: (_) {
        final FocusNode? nextNode = nextFocusNode;
        if (nextNode == null) {
          focusNode.unfocus();
          return;
        }

        nextNode.requestFocus();
      },
      style: theme.textTheme.bodyLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText ?? labelText,
        hintStyle: theme.inputDecorationTheme.hintStyle,
        counterText: '',
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}

class _DatePartSeparator extends StatelessWidget {
  const _DatePartSeparator({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = enabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
      child: Text(
        '/',
        style: theme.textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

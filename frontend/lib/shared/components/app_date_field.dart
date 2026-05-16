import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';
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
      final DateTime? parsed = _parseParts();
      if (parsed != null) {
        _syncControllersFromDate(parsed);
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
      validator: (_) => _validate(),
      onSaved: (_) => widget.onSaved?.call(_parseParts()),
      autovalidateMode: widget.autovalidateMode,
      forceErrorText: widget.errorText,
      builder: (FormFieldState<DateTime> field) {
        Widget dateField = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.labelText != null) ...<Widget>[
              appFieldLabelWidget(
                context,
                widget.labelText,
                isRequired: widget.isRequired,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              )!,
              const SizedBox(height: 8),
            ],
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool hasError = field.errorText != null;
                final bool isFocused = _hasFocus;
                final Color borderColor = !canChange
                    ? theme.disabledColor
                    : hasError
                    ? theme.colorScheme.error
                    : isFocused
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline;
                final Widget dayField = _DatePartTextField(
                  controller: _dayController,
                  focusNode: _dayFocusNode,
                  labelText: widget.dayLabelText,
                  hintText: widget.hintText,
                  maxLength: 2,
                  enabled: canChange,
                  restorationId: _partRestorationId('day'),
                  textInputAction: TextInputAction.next,
                  onChanged: () => _handlePartsChanged(field),
                );
                final Widget monthField = _DatePartTextField(
                  controller: _monthController,
                  focusNode: _monthFocusNode,
                  labelText: widget.monthLabelText,
                  maxLength: 2,
                  enabled: canChange,
                  restorationId: _partRestorationId('month'),
                  textInputAction: TextInputAction.next,
                  onChanged: () => _handlePartsChanged(field),
                );
                final Widget yearField = _DatePartTextField(
                  controller: _yearController,
                  focusNode: _yearFocusNode,
                  labelText: widget.yearLabelText,
                  maxLength: 4,
                  enabled: canChange,
                  restorationId: _partRestorationId('year'),
                  textInputAction: TextInputAction.done,
                  onChanged: () => _handlePartsChanged(field),
                );
                final Widget pickerButton = AppIconButton(
                  semanticLabel: widget.pickerButtonLabel,
                  tooltip: widget.pickerButtonLabel,
                  onPressed: canChange
                      ? () => _selectDate(context, field)
                      : null,
                  icon: Icons.calendar_today_outlined,
                );

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsetsDirectional.only(
                    start: 12,
                    end: 6,
                    top: 6,
                    bottom: 6,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(flex: 9, child: dayField),
                      _DatePartSeparator(enabled: canChange),
                      Expanded(flex: 9, child: monthField),
                      _DatePartSeparator(enabled: canChange),
                      Expanded(flex: 12, child: yearField),
                      const SizedBox(width: 4),
                      pickerButton,
                    ],
                  ),
                );
              },
            ),
            if (widget.helperText != null || field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  field.errorText ?? widget.helperText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: field.errorText == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
              ),
          ],
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
    final DateTime? parsed = _parseParts();
    field.didChange(parsed);
    widget.onChanged?.call(_allPartsEmpty ? null : parsed);
  }

  Future<void> _selectDate(
    BuildContext context,
    FormFieldState<DateTime> field,
  ) async {
    final DateTime initialDate = _resolveInitialDate(field.value);
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      currentDate: widget.currentDate,
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

  DateTime _resolveInitialDate(DateTime? fieldValue) {
    final DateTime fallback =
        fieldValue ??
        widget.value ??
        widget.initialPickerDate ??
        DateTime.now();

    if (fallback.isBefore(widget.firstDate)) {
      return widget.firstDate;
    }

    if (fallback.isAfter(widget.lastDate)) {
      return widget.lastDate;
    }

    return fallback;
  }

  String? _validate() {
    if (_allPartsEmpty) {
      return widget.validator?.call(null);
    }

    final DateTime? parsed = _parseParts();
    if (parsed == null ||
        parsed.isBefore(_dateOnly(widget.firstDate)) ||
        parsed.isAfter(_dateOnly(widget.lastDate)) ||
        widget.selectableDayPredicate?.call(parsed) == false) {
      return widget.invalidDateMessage;
    }

    return widget.validator?.call(parsed);
  }

  DateTime? _parseParts() {
    final String year = _yearController.text.trim();
    final String month = _monthController.text.trim();
    final String day = _dayController.text.trim();
    if (year.isEmpty && month.isEmpty && day.isEmpty) {
      return null;
    }
    if (year.length != 4 || month.isEmpty || day.isEmpty) {
      return null;
    }
    return _safeDate(
      int.tryParse(year),
      int.tryParse(month),
      int.tryParse(day),
    );
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
      onChanged: (_) => onChanged(),
      style: theme.textTheme.bodyLarge?.copyWith(
        color: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withValues(alpha: 0.62),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText ?? labelText,
        counterText: '',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '/',
        style: theme.textTheme.titleMedium?.copyWith(
          color: enabled
              ? theme.colorScheme.onSurfaceVariant
              : theme.disabledColor,
        ),
      ),
    );
  }
}

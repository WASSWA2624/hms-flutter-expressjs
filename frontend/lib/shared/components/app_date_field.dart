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
  late final TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatDate(widget.value));
    _attachFocusNode();
  }

  @override
  void didUpdateWidget(AppDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = _formatDate(widget.value);
    }
  }

  @override
  void dispose() {
    _detachFocusNode();
    _controller.dispose();
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
    if (!_focusNode.hasFocus) {
      final DateTime? parsed = _parseDate(_controller.text);
      if (parsed != null) {
        _controller.text = _formatDate(parsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canChange = widget.enabled;

    return FormField<DateTime>(
      initialValue: widget.value,
      validator: (_) => _validate(),
      onSaved: (_) => widget.onSaved?.call(_parseDate(_controller.text)),
      autovalidateMode: widget.autovalidateMode,
      forceErrorText: widget.errorText,
      builder: (FormFieldState<DateTime> field) {
        Widget textField = TextField(
          controller: _controller,
          enabled: canChange,
          focusNode: _focusNode,
          restorationId: widget.restorationId,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.next,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9/\-.]')),
          ],
          onChanged: (String value) => _handleTextChanged(field, value),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: canChange
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.62),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            label: appFieldLabelWidget(
              context,
              widget.labelText,
              isRequired: widget.isRequired,
            ),
            hintText: widget.hintText,
            helperText: widget.helperText,
            errorText: field.errorText,
            suffixIcon: AppIconButton(
              semanticLabel: widget.pickerButtonLabel,
              tooltip: widget.pickerButtonLabel,
              onPressed: canChange ? () => _selectDate(context, field) : null,
              icon: Icons.calendar_today_outlined,
            ),
          ),
        );

        if (widget.semanticLabel != null) {
          textField = Semantics(
            textField: true,
            enabled: canChange,
            label: widget.semanticLabel,
            child: textField,
          );
        }

        return textField;
      },
    );
  }

  void _handleTextChanged(FormFieldState<DateTime> field, String value) {
    final DateTime? parsed = _parseDate(value);
    field.didChange(parsed);
    widget.onChanged?.call(value.trim().isEmpty ? null : parsed);
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
    _controller.text = _formatDate(selectedDate);
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
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      return widget.validator?.call(null);
    }

    final DateTime? parsed = _parseDate(value);
    if (parsed == null ||
        parsed.isBefore(_dateOnly(widget.firstDate)) ||
        parsed.isAfter(_dateOnly(widget.lastDate)) ||
        widget.selectableDayPredicate?.call(parsed) == false) {
      return widget.invalidDateMessage;
    }

    return widget.validator?.call(parsed);
  }

  DateTime? _parseDate(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final RegExpMatch? iso = RegExp(
      r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$',
    ).firstMatch(normalized);
    if (iso != null) {
      return _safeDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final RegExpMatch? slash = RegExp(
      r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$',
    ).firstMatch(normalized);
    if (slash != null) {
      final int first = int.parse(slash.group(1)!);
      final int second = int.parse(slash.group(2)!);
      final int year = int.parse(slash.group(3)!);
      if (first > 12) {
        return _safeDate(year, second, first);
      }
      return _safeDate(year, first, second);
    }

    return null;
  }

  DateTime? _safeDate(int year, int month, int day) {
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

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }

    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

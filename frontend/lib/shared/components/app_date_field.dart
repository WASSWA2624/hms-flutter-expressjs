import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';

class AppDateField extends StatefulWidget {
  const AppDateField({
    required this.firstDate,
    required this.lastDate,
    required this.pickerButtonLabel,
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
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<DateTime>? validator;
  final FormFieldSetter<DateTime>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final FocusNode? focusNode;
  final String? restorationId;
  final DatePickerEntryMode initialEntryMode;
  final SelectableDayPredicate? selectableDayPredicate;

  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState extends State<AppDateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canChange = widget.enabled;

    return FormField<DateTime>(
      key: ValueKey<DateTime?>(widget.value),
      initialValue: widget.value,
      validator: widget.validator,
      onSaved: widget.onSaved,
      autovalidateMode: widget.autovalidateMode,
      forceErrorText: widget.errorText,
      builder: (FormFieldState<DateTime> field) {
        _controller.text = _formatDate(context, field.value);

        Widget textField = TextField(
          controller: _controller,
          enabled: canChange,
          readOnly: true,
          focusNode: widget.focusNode,
          restorationId: widget.restorationId,
          onTap: canChange ? () => _selectDate(context, field) : null,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: canChange
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.62),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: widget.labelText,
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

  String _formatDate(BuildContext context, DateTime? value) {
    if (value == null) {
      return '';
    }

    return MaterialLocalizations.of(context).formatMediumDate(value);
  }
}

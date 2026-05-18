import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';

class AppTimeField extends StatefulWidget {
  const AppTimeField({
    required this.pickerButtonLabel,
    required this.invalidTimeMessage,
    this.value,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.semanticLabel,
    this.validator,
    this.enabled = true,
    this.isRequired = false,
    super.key,
  });

  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?>? onChanged;
  final String pickerButtonLabel;
  final String invalidTimeMessage;
  final String? labelText;
  final String? hintText;
  final String? semanticLabel;
  final FormFieldValidator<TimeOfDay>? validator;
  final bool enabled;
  final bool isRequired;

  @override
  State<AppTimeField> createState() => _AppTimeFieldState();
}

class _AppTimeFieldState extends State<AppTimeField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatTime(widget.value));
  }

  @override
  void didUpdateWidget(covariant AppTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = _formatTime(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<TimeOfDay>(
      initialValue: widget.value,
      enabled: widget.enabled,
      validator: (_) {
        final TimeOfDay? parsed = _parseTime(_controller.text);
        if (_controller.text.trim().isNotEmpty && parsed == null) {
          return widget.invalidTimeMessage;
        }
        return widget.validator?.call(parsed);
      },
      builder: (FormFieldState<TimeOfDay> field) {
        return AppTextField(
          controller: _controller,
          labelText: widget.labelText,
          hintText: widget.hintText,
          semanticLabel: widget.semanticLabel,
          enabled: widget.enabled,
          isRequired: widget.isRequired,
          keyboardType: TextInputType.datetime,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            LengthLimitingTextInputFormatter(5),
          ],
          errorText: field.errorText,
          suffixIcon: _TimePickerButton(
            label: widget.pickerButtonLabel,
            onPressed: widget.enabled
                ? () async {
                    final TimeOfDay? selected = await showTimePicker(
                      context: context,
                      initialTime:
                          _parseTime(_controller.text) ??
                          widget.value ??
                          TimeOfDay.now(),
                    );
                    if (selected == null) {
                      return;
                    }
                    _controller.text = _formatTime(selected);
                    field.didChange(selected);
                    widget.onChanged?.call(selected);
                  }
                : null,
          ),
          onChanged: (String value) {
            final TimeOfDay? parsed = _parseTime(value);
            field.didChange(parsed);
            if (parsed != null || value.trim().isEmpty) {
              widget.onChanged?.call(parsed);
            }
          },
        );
      },
    );
  }

  String _formatTime(TimeOfDay? value) {
    if (value == null) {
      return '';
    }
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay? _parseTime(String value) {
    final List<String> parts = value.trim().split(':');
    if (parts.length != 2) {
      return null;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onPressed != null;
    final Color disabledColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.38,
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(end: theme.spacing.xs),
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(Icons.schedule_outlined, size: theme.appTokens.listIconSize),
        color: enabled ? theme.colorScheme.onSurfaceVariant : disabledColor,
      ),
    );
  }
}

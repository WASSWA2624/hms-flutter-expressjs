import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';
import 'package:hosspi_hms/shared/components/app_time_value.dart';

enum _AppTimePeriod { am, pm }

class AppTimeField extends StatefulWidget {
  const AppTimeField({
    required this.pickerButtonLabel,
    required this.invalidTimeMessage,
    this.value,
    this.onChanged,
    this.labelText,
    this.hourLabelText = 'HH',
    this.minuteLabelText = 'MM',
    this.secondLabelText = 'SS',
    this.amLabelText = 'AM',
    this.pmLabelText = 'PM',
    this.hour12LabelText = '12H',
    this.hour24LabelText = '24H',
    this.hintText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.isRequired = false,
    this.showSeconds = false,
    this.use24HourFormat,
    this.allowFormatToggle = true,
    this.focusNode,
    this.restorationId,
    super.key,
  });

  final AppTimeValue? value;
  final ValueChanged<AppTimeValue?>? onChanged;
  final String pickerButtonLabel;
  final String invalidTimeMessage;
  final String? labelText;
  final String hourLabelText;
  final String minuteLabelText;
  final String secondLabelText;
  final String amLabelText;
  final String pmLabelText;
  final String hour12LabelText;
  final String hour24LabelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<AppTimeValue>? validator;
  final FormFieldSetter<AppTimeValue>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final bool isRequired;
  final bool showSeconds;
  final bool? use24HourFormat;
  final bool allowFormatToggle;
  final FocusNode? focusNode;
  final String? restorationId;

  @override
  State<AppTimeField> createState() => _AppTimeFieldState();
}

class _AppTimeFieldState extends State<AppTimeField> {
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  late final TextEditingController _secondController;
  late FocusNode _hourFocusNode;
  late FocusNode _minuteFocusNode;
  late FocusNode _secondFocusNode;
  late bool _ownsHourFocusNode;
  late _AppTimePeriod _period;
  bool? _userFormat24Hour;
  bool _isSyncing = false;
  bool _didSyncInitialValue = false;

  @override
  void initState() {
    super.initState();
    _hourController = TextEditingController();
    _minuteController = TextEditingController();
    _secondController = TextEditingController();
    _period = _AppTimePeriod.am;
    _attachFocusNodes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSyncInitialValue) {
      _didSyncInitialValue = true;
      _period = _periodForValue(widget.value);
      _syncControllersFromValue(widget.value);
    }
  }

  @override
  void didUpdateWidget(covariant AppTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNodes();
      _attachFocusNodes();
    }
    if (oldWidget.value != widget.value && !_hasFocus) {
      _period = _periodForValue(widget.value);
      _syncControllersFromValue(widget.value);
    }
    if (oldWidget.use24HourFormat != widget.use24HourFormat && mounted) {
      _userFormat24Hour = null;
      _syncControllersFromValue(_parseParts() ?? widget.value);
    }
  }

  @override
  void dispose() {
    _detachFocusNodes();
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _attachFocusNodes() {
    _ownsHourFocusNode = widget.focusNode == null;
    _hourFocusNode = widget.focusNode ?? FocusNode();
    _minuteFocusNode = FocusNode();
    _secondFocusNode = FocusNode();
    _hourFocusNode.addListener(_handleFocusChanged);
    _minuteFocusNode.addListener(_handleFocusChanged);
    _secondFocusNode.addListener(_handleFocusChanged);
  }

  void _detachFocusNodes() {
    _hourFocusNode.removeListener(_handleFocusChanged);
    _minuteFocusNode.removeListener(_handleFocusChanged);
    _secondFocusNode.removeListener(_handleFocusChanged);
    if (_ownsHourFocusNode) {
      _hourFocusNode.dispose();
    }
    _minuteFocusNode.dispose();
    _secondFocusNode.dispose();
  }

  void _handleFocusChanged() {
    if (!_hasFocus) {
      final AppTimeValue? parsed = _parseParts();
      if (parsed != null) {
        _syncControllersFromValue(parsed);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  bool get _uses24Hour =>
      _userFormat24Hour ??
      widget.use24HourFormat ??
      MediaQuery.alwaysUse24HourFormatOf(context);

  int get _hourMaxLength => _uses24Hour ? 2 : 2;

  int get _hourMaxValue => _uses24Hour ? 23 : 12;

  int get _hourMinValue => _uses24Hour ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canChange = widget.enabled;

    return FormField<AppTimeValue>(
      initialValue: widget.value,
      enabled: canChange,
      validator: (_) => _validate(),
      onSaved: (_) => widget.onSaved?.call(_parseParts()),
      autovalidateMode: widget.autovalidateMode,
      forceErrorText: widget.errorText,
      onReset: () => _syncControllersFromValue(widget.value),
      builder: (FormFieldState<AppTimeValue> field) {
        final Widget? fieldLabel = appFieldLabelWidget(
          context,
          widget.labelText,
          isRequired: widget.isRequired,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        );

        Widget timeField = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (fieldLabel != null)
              Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.xs),
                child: fieldLabel,
              ),
            InputDecorator(
              isFocused: _hasFocus,
              isEmpty: _allPartsEmpty,
              decoration: InputDecoration(
                enabled: canChange,
                helperText: widget.helperText,
                errorText: field.errorText,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                contentPadding: EdgeInsetsDirectional.fromSTEB(
                  theme.spacing.md,
                  theme.spacing.sm,
                  theme.spacing.xs,
                  theme.spacing.sm,
                ),
                suffixIcon: _TimeFieldSuffix(
                  allowFormatToggle: widget.allowFormatToggle,
                  uses24Hour: _uses24Hour,
                  label12: widget.hour12LabelText,
                  label24: widget.hour24LabelText,
                  pickerLabel: widget.pickerButtonLabel,
                  enabled: canChange,
                  onFormatChanged: (bool use24Hour) {
                    final AppTimeValue? current = _parseParts() ?? widget.value;
                    setState(() => _userFormat24Hour = use24Hour);
                    if (current != null) {
                      _syncControllersFromValue(current);
                      field.didChange(current);
                      widget.onChanged?.call(current);
                    }
                  },
                  onPickTime: canChange
                      ? () => _selectTime(context, field)
                      : null,
                ),
                suffixIconConstraints: BoxConstraints(
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
                        child: _TimePartTextField(
                          controller: _hourController,
                          focusNode: _hourFocusNode,
                          nextFocusNode: _minuteFocusNode,
                          labelText: widget.hourLabelText,
                          hintText: _partHint(0, widget.hourLabelText),
                          maxLength: _hourMaxLength,
                          minValue: _hourMinValue,
                          maxValue: _hourMaxValue,
                          enabled: canChange,
                          restorationId: _partRestorationId('hour'),
                          textInputAction: TextInputAction.next,
                          onChanged: () => _handlePartsChanged(field),
                        ),
                      ),
                    ),
                    _TimePartSeparator(enabled: canChange),
                    Flexible(
                      flex: 2,
                      child: SizedBox(
                        width: 30,
                        child: _TimePartTextField(
                          controller: _minuteController,
                          focusNode: _minuteFocusNode,
                          nextFocusNode: widget.showSeconds
                              ? _secondFocusNode
                              : (_uses24Hour ? null : _hourFocusNode),
                          labelText: widget.minuteLabelText,
                          hintText: _partHint(1, widget.minuteLabelText),
                          maxLength: 2,
                          minValue: 0,
                          maxValue: 59,
                          enabled: canChange,
                          restorationId: _partRestorationId('minute'),
                          textInputAction: widget.showSeconds
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onChanged: () => _handlePartsChanged(field),
                        ),
                      ),
                    ),
                    if (widget.showSeconds) ...<Widget>[
                      _TimePartSeparator(enabled: canChange),
                      Flexible(
                        flex: 2,
                        child: SizedBox(
                          width: 30,
                          child: _TimePartTextField(
                            controller: _secondController,
                            focusNode: _secondFocusNode,
                            labelText: widget.secondLabelText,
                            hintText: _partHint(2, widget.secondLabelText),
                            maxLength: 2,
                            minValue: 0,
                            maxValue: 59,
                            enabled: canChange,
                            restorationId: _partRestorationId('second'),
                            textInputAction: TextInputAction.done,
                            onChanged: () => _handlePartsChanged(field),
                          ),
                        ),
                      ),
                    ],
                    if (!_uses24Hour) ...<Widget>[
                      SizedBox(width: theme.spacing.xs),
                      Flexible(
                        flex: 3,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _TimePeriodToggle(
                              amLabel: widget.amLabelText,
                              pmLabel: widget.pmLabelText,
                              period: _period,
                              enabled: canChange,
                              onChanged: (_AppTimePeriod value) {
                                setState(() => _period = value);
                                _handlePartsChanged(field);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );

        if (widget.semanticLabel != null) {
          timeField = Semantics(
            textField: true,
            enabled: canChange,
            label: widget.semanticLabel,
            child: timeField,
          );
        }

        return timeField;
      },
    );
  }

  bool get _hasFocus =>
      _hourFocusNode.hasFocus ||
      _minuteFocusNode.hasFocus ||
      _secondFocusNode.hasFocus;

  void _handlePartsChanged(FormFieldState<AppTimeValue> field) {
    if (_isSyncing) {
      return;
    }
    final _TimePartsValidationResult result = _validateParts();
    final AppTimeValue? validTime = result.isValid ? result.time : null;
    field.didChange(validTime);
    widget.onChanged?.call(result.isEmpty ? null : validTime);
  }

  Future<void> _selectTime(
    BuildContext context,
    FormFieldState<AppTimeValue> field,
  ) async {
    final AppTimeValue initialTime =
        _parseParts() ?? field.value ?? widget.value ?? AppTimeValue.now();

    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: initialTime.toTimeOfDay(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: _uses24Hour),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    final AppTimeValue next = AppTimeValue(
      hour: selected.hour,
      minute: selected.minute,
      second: widget.showSeconds ? initialTime.second : 0,
    );
    field.didChange(next);
    _period = _periodForValue(next);
    _syncControllersFromValue(next);
    widget.onChanged?.call(next);
  }

  String? _validate() {
    final _TimePartsValidationResult result = _validateParts();
    return switch (result.status) {
      _TimePartsValidationStatus.empty => widget.validator?.call(null),
      _TimePartsValidationStatus.valid => widget.validator?.call(result.time),
      _ => widget.invalidTimeMessage,
    };
  }

  AppTimeValue? _parseParts() {
    final _TimePartsValidationResult result = _validateParts();
    return result.isValid ? result.time : null;
  }

  _TimePartsValidationResult _validateParts() {
    final String hourText = _hourController.text.trim();
    final String minuteText = _minuteController.text.trim();
    final String secondText = _secondController.text.trim();

    final bool hourEmpty = hourText.isEmpty;
    final bool minuteEmpty = minuteText.isEmpty;
    final bool secondEmpty = secondText.isEmpty;

    if (hourEmpty && minuteEmpty && (!widget.showSeconds || secondEmpty)) {
      return const _TimePartsValidationResult.empty();
    }

    if (hourEmpty || minuteEmpty || (widget.showSeconds && secondEmpty)) {
      return const _TimePartsValidationResult.incomplete();
    }

    final int? hourPart = int.tryParse(hourText);
    final int? minutePart = int.tryParse(minuteText);
    final int? secondPart = widget.showSeconds ? int.tryParse(secondText) : 0;
    if (hourPart == null || minutePart == null || secondPart == null) {
      return const _TimePartsValidationResult.invalid();
    }

    if (minutePart > 59 || secondPart > 59) {
      return const _TimePartsValidationResult.invalid();
    }

    final int hour24 = _uses24Hour ? hourPart : _to24Hour(hourPart, _period);
    if (_uses24Hour) {
      if (hourPart < _hourMinValue || hourPart > _hourMaxValue) {
        return const _TimePartsValidationResult.invalid();
      }
    } else if (hourPart < 1 || hourPart > 12) {
      return const _TimePartsValidationResult.invalid();
    }

    if (hour24 < 0 || hour24 > 23) {
      return const _TimePartsValidationResult.invalid();
    }

    return _TimePartsValidationResult.valid(
      AppTimeValue(hour: hour24, minute: minutePart, second: secondPart),
    );
  }

  int _to24Hour(int hour12, _AppTimePeriod period) {
    if (period == _AppTimePeriod.am) {
      return hour12 == 12 ? 0 : hour12;
    }
    return hour12 == 12 ? 12 : hour12 + 12;
  }

  int _to12HourDisplay(int hour24) {
    final int remainder = hour24 % 12;
    return remainder == 0 ? 12 : remainder;
  }

  _AppTimePeriod _periodForValue(AppTimeValue? value) {
    if (value == null) {
      return _AppTimePeriod.am;
    }
    return value.hour >= 12 ? _AppTimePeriod.pm : _AppTimePeriod.am;
  }

  void _syncControllersFromValue(AppTimeValue? value) {
    final String hour = value == null
        ? ''
        : _uses24Hour
        ? value.hour.toString().padLeft(2, '0')
        : _to12HourDisplay(value.hour).toString().padLeft(2, '0');
    final String minute = value == null
        ? ''
        : value.minute.toString().padLeft(2, '0');
    final String second = value == null
        ? ''
        : value.second.toString().padLeft(2, '0');

    _isSyncing = true;
    _hourController.text = hour;
    _minuteController.text = minute;
    _secondController.text = second;
    if (value != null) {
      _period = _periodForValue(value);
    }
    _isSyncing = false;
  }

  bool get _allPartsEmpty =>
      _hourController.text.trim().isEmpty &&
      _minuteController.text.trim().isEmpty &&
      _secondController.text.trim().isEmpty;

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
        .split(RegExp(r'[:.\s]+'))
        .where((String part) => part.isNotEmpty)
        .map((String part) => part.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return fallback;
    }

    if (index < parts.length) {
      return parts[index];
    }

    return fallback;
  }
}

enum _TimePartsValidationStatus { empty, incomplete, invalid, valid }

class _TimePartsValidationResult {
  const _TimePartsValidationResult._(this.status, this.time);

  const _TimePartsValidationResult.empty()
    : this._(_TimePartsValidationStatus.empty, null);

  const _TimePartsValidationResult.incomplete()
    : this._(_TimePartsValidationStatus.incomplete, null);

  const _TimePartsValidationResult.invalid()
    : this._(_TimePartsValidationStatus.invalid, null);

  const _TimePartsValidationResult.valid(AppTimeValue time)
    : this._(_TimePartsValidationStatus.valid, time);

  final _TimePartsValidationStatus status;
  final AppTimeValue? time;

  bool get isEmpty => status == _TimePartsValidationStatus.empty;

  bool get isValid => status == _TimePartsValidationStatus.valid;
}

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onPressed != null;

    return Padding(
      padding: EdgeInsetsDirectional.only(end: theme.spacing.xs),
      child: AppButton(
        iconOnly: true,
        leadingIcon: Icons.schedule_outlined,
        label: label,
        semanticLabel: label,
        tooltip: label,
        enabled: enabled,
        onPressed: onPressed,
      ),
    );
  }
}

class _TimeFieldSuffix extends StatelessWidget {
  const _TimeFieldSuffix({
    required this.allowFormatToggle,
    required this.uses24Hour,
    required this.label12,
    required this.label24,
    required this.pickerLabel,
    required this.enabled,
    required this.onFormatChanged,
    required this.onPickTime,
  });

  final bool allowFormatToggle;
  final bool uses24Hour;
  final String label12;
  final String label24;
  final String pickerLabel;
  final bool enabled;
  final ValueChanged<bool> onFormatChanged;
  final VoidCallback? onPickTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (allowFormatToggle)
          _TimeFormatToggle(
            uses24Hour: uses24Hour,
            label12: label12,
            label24: label24,
            enabled: enabled,
            onChanged: onFormatChanged,
          ),
        _TimePickerButton(label: pickerLabel, onPressed: onPickTime),
      ],
    );
  }
}

class _TimePartTextField extends StatelessWidget {
  const _TimePartTextField({
    required this.controller,
    required this.focusNode,
    required this.labelText,
    required this.maxLength,
    required this.minValue,
    required this.maxValue,
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
  final int minValue;
  final int maxValue;
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
        _TimePartRangeFormatter(
          minValue: minValue,
          maxValue: maxValue,
          maxLength: maxLength,
        ),
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

class _TimePartRangeFormatter extends TextInputFormatter {
  const _TimePartRangeFormatter({
    required this.minValue,
    required this.maxValue,
    required this.maxLength,
  });

  final int minValue;
  final int maxValue;
  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }
    final int? value = int.tryParse(text);
    if (value == null || value > maxValue) {
      return oldValue;
    }
    if (text.length >= maxLength && value < minValue) {
      return oldValue;
    }
    return newValue;
  }
}

class _TimePartSeparator extends StatelessWidget {
  const _TimePartSeparator({required this.enabled});

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
        ':',
        style: theme.textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

class _TimeFormatToggle extends StatelessWidget {
  const _TimeFormatToggle({
    required this.uses24Hour,
    required this.label12,
    required this.label24,
    required this.enabled,
    required this.onChanged,
  });

  final bool uses24Hour;
  final String label12;
  final String label24;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String activeLabel = uses24Hour ? label24 : label12;
    final String nextLabel = uses24Hour ? label12 : label24;
    final Color foreground = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);

    return Tooltip(
      message: nextLabel,
      child: Material(
        color: enabled
            ? colors.surfaceContainerHighest
            : colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(theme.radius.sm),
        child: InkWell(
          onTap: enabled ? () => onChanged(!uses24Hour) : null,
          borderRadius: BorderRadius.circular(theme.radius.sm),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.xs,
            ),
            child: Text(
              activeLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePeriodToggle extends StatelessWidget {
  const _TimePeriodToggle({
    required this.amLabel,
    required this.pmLabel,
    required this.period,
    required this.enabled,
    required this.onChanged,
  });

  final String amLabel;
  final String pmLabel;
  final _AppTimePeriod period;
  final bool enabled;
  final ValueChanged<_AppTimePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled
            ? colors.surfaceContainerHighest
            : colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _TimePeriodChip(
            label: amLabel,
            selected: period == _AppTimePeriod.am,
            enabled: enabled,
            onTap: () => onChanged(_AppTimePeriod.am),
          ),
          _TimePeriodChip(
            label: pmLabel,
            selected: period == _AppTimePeriod.pm,
            enabled: enabled,
            onTap: () => onChanged(_AppTimePeriod.pm),
          ),
        ],
      ),
    );
  }
}

class _TimePeriodChip extends StatelessWidget {
  const _TimePeriodChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color foreground = !enabled
        ? colors.onSurface.withValues(alpha: 0.38)
        : selected
        ? colors.onPrimary
        : colors.onSurfaceVariant;

    return Material(
      color: selected && enabled ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(theme.radius.sm),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.xs,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

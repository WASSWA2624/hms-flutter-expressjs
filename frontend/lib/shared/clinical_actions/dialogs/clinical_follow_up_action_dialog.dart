import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalFollowUpActionDialog extends StatefulWidget {
  const ClinicalFollowUpActionDialog({
    required this.onSubmit,
    this.title,
    this.submitLabel,
    this.icon = const Icon(Icons.event_repeat_outlined),
    this.initialScheduledAt,
    this.dateLabel,
    this.timeLabel,
    this.notesLabel,
    this.datePickerButtonLabel,
    this.lastDate,
    this.leadingContent = const <Widget>[],
    super.key,
  });

  final Future<AppFailure?> Function({
    required DateTime scheduledAt,
    required String notes,
  })
  onSubmit;
  final String? title;
  final String? submitLabel;
  final Widget icon;
  final DateTime? initialScheduledAt;
  final String? dateLabel;
  final String? timeLabel;
  final String? notesLabel;
  final String? datePickerButtonLabel;
  final DateTime? lastDate;
  final List<Widget> leadingContent;

  @override
  State<ClinicalFollowUpActionDialog> createState() =>
      _ClinicalFollowUpActionDialogState();
}

class _ClinicalFollowUpActionDialogState
    extends State<ClinicalFollowUpActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late DateTime _followUpDate;
  late TimeOfDay _followUpTime;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final DateTime defaultAt =
        widget.initialScheduledAt ??
        DateTime.now().add(const Duration(days: 7));
    _followUpDate = _dateOnly(defaultAt);
    _followUpTime = TimeOfDay.fromDateTime(defaultAt);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DateTime today = _dateOnly(DateTime.now());
    return AppDialog(
      title: Text(widget.title ?? l10n.opdFollowUpAction),
      icon: widget.icon,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            ...widget.leadingContent,
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppDateField(
                value: _followUpDate,
                labelText: widget.dateLabel ?? l10n.opdFollowUpDateLabel,
                hintText: l10n.appDateFormatHint,
                firstDate: today,
                lastDate:
                    widget.lastDate ??
                    _dateOnly(today.add(const Duration(days: 365))),
                currentDate: today,
                pickerButtonLabel:
                    widget.datePickerButtonLabel ??
                    l10n.opdDatePickerButtonLabel,
                invalidDateMessage: l10n.appDateInvalidMessage,
                enabled: !_isSaving,
                isRequired: true,
                validator: AppValidators.requiredValue<DateTime>(
                  l10n.validationRequired,
                ),
                onChanged: (DateTime? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _followUpDate = _dateOnly(value));
                },
              ),
              right: AppTimeField(
                value: _followUpTime,
                labelText: widget.timeLabel ?? l10n.opdFollowUpTimeLabel,
                hintText: l10n.appTimeFormatHint,
                pickerButtonLabel: l10n.appTimePickerAction,
                invalidTimeMessage: l10n.appTimeInvalidMessage,
                enabled: !_isSaving,
                isRequired: true,
                validator: AppValidators.requiredValue<TimeOfDay>(
                  l10n.validationRequired,
                ),
                onChanged: (TimeOfDay? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _followUpTime = value);
                },
              ),
            ),
            AppTextField(
              controller: _notesController,
              labelText: widget.notesLabel ?? l10n.opdNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        widget.submitLabel ?? l10n.opdFollowUpAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final DateTime scheduledAt = _combineDateAndTime(
      _followUpDate,
      _followUpTime,
    );
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      scheduledAt: scheduledAt,
      notes: _notesController.text.trim(),
    );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

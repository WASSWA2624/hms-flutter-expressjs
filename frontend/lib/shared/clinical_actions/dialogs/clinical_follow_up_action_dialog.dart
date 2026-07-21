import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Shared follow-up scheduling dialog used by clinical, OPD, and physiotherapy.
class ClinicalFollowUpActionDialog extends StatefulWidget {
  const ClinicalFollowUpActionDialog({
    required this.onSubmit,
    this.title,
    this.submitLabel,
    this.icon = const Icon(AppActionIcons.followUp),
    this.submitLeadingIcon = AppActionIcons.save,
    this.initialScheduledAt,
    this.dateLabel,
    this.timeLabel,
    this.notesLabel,
    this.datePickerButtonLabel,
    this.lastDate,
    this.leadingContent = const <Widget>[],
    this.scrollable = true,
    this.pinActionsToBottom = true,
    this.density = AppFormSectionDensity.compact,
    this.maxWidth = 720,
    this.cancelLabel,
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
  final IconData submitLeadingIcon;
  final DateTime? initialScheduledAt;
  final String? dateLabel;
  final String? timeLabel;
  final String? notesLabel;
  final String? datePickerButtonLabel;
  final DateTime? lastDate;
  final List<Widget> leadingContent;
  final bool scrollable;
  final bool pinActionsToBottom;
  final AppFormSectionDensity density;
  final double maxWidth;
  final String? cancelLabel;

  @override
  State<ClinicalFollowUpActionDialog> createState() =>
      _ClinicalFollowUpActionDialogState();
}

class _ClinicalFollowUpActionDialogState
    extends State<ClinicalFollowUpActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late DateTime _followUpDate;
  late AppTimeValue _followUpTime;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final DateTime defaultAt =
        widget.initialScheduledAt ??
        DateTime.now().add(const Duration(days: 7));
    _followUpDate = _dateOnly(defaultAt);
    _followUpTime = AppTimeValue.fromTimeOfDay(
      TimeOfDay.fromDateTime(defaultAt),
    );
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
    final ThemeData theme = Theme.of(context);
    final DateTime today = _dateOnly(DateTime.now());
    final String title = widget.title ?? l10n.opdFollowUpAction;
    final String submitLabel =
        widget.submitLabel ?? l10n.opdSaveFollowUpAction;
    return AppDialog(
      title: Text(title),
      icon: widget.icon,
      maxWidth: widget.maxWidth,
      scrollable: widget.scrollable,
      pinActionsToBottom: widget.pinActionsToBottom,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: widget.density,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            ...widget.leadingContent,
            AppFormSection(
              title: l10n.clinicalFollowUpDetailsTitle,
              density: widget.density,
              children: <Widget>[
                AppResponsiveFieldRow.two(
                  gap: AppResponsiveFieldRowGap.form,
                  left: AppDateField(
                    value: _followUpDate,
                    labelText: l10n.opdFieldRequiredLabel(
                      widget.dateLabel ?? l10n.opdFollowUpDateLabel,
                    ),
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
                    labelText: l10n.opdFieldRequiredLabel(
                      widget.timeLabel ?? l10n.opdFollowUpTimeLabel,
                    ),
                    hintText: l10n.appTimeFormatHint,
                    hourLabelText: l10n.appTimeHourLabel,
                    minuteLabelText: l10n.appTimeMinuteLabel,
                    pickerButtonLabel: l10n.appTimePickerAction,
                    invalidTimeMessage: l10n.appTimeInvalidMessage,
                    enabled: !_isSaving,
                    isRequired: true,
                    validator: AppValidators.requiredValue<AppTimeValue>(
                      l10n.validationRequired,
                    ),
                    onChanged: (AppTimeValue? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _followUpTime = value);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            AppFormSection(
              title: l10n.clinicalFollowUpNotesTitle,
              density: widget.density,
              children: <Widget>[
                AppTextField(
                  controller: _notesController,
                  labelText: l10n.opdFieldOptionalLabel(
                    widget.notesLabel ?? l10n.opdNotesLabel,
                  ),
                  enabled: !_isSaving,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  prefixIcon: const Icon(AppActionIcons.edit),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        submitLabel,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: widget.submitLeadingIcon,
        cancelLabel: widget.cancelLabel,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
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

DateTime _combineDateAndTime(DateTime date, AppTimeValue time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

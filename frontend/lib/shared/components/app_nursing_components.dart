import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_checkbox_field.dart';
import 'package:hosspi_hms/shared/components/app_date_field.dart';
import 'package:hosspi_hms/shared/components/app_file_upload_panel.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/components/app_time_field.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class AppMedicationAdministrationForm extends StatelessWidget {
  const AppMedicationAdministrationForm({
    required this.medicationLabel,
    required this.doseLabel,
    required this.unitLabel,
    required this.routeLabel,
    required this.administeredDateLabel,
    required this.administeredTimeLabel,
    required this.datePickerLabel,
    required this.invalidDateMessage,
    required this.timePickerLabel,
    required this.invalidTimeMessage,
    required this.confirmLabel,
    required this.confirmSubtitle,
    required this.requiredMessage,
    required this.doseController,
    required this.unitController,
    required this.administeredDate,
    required this.administeredTime,
    required this.routeValue,
    required this.routeOptions,
    required this.confirmed,
    required this.onAdministeredDateChanged,
    required this.onAdministeredTimeChanged,
    required this.onRouteChanged,
    required this.onConfirmedChanged,
    this.medicationValue,
    this.medicationOptions = const <AppSelectOption<String>>[],
    this.onMedicationChanged,
    this.selectedMedicationDescription,
    this.noMedicationMessage,
    this.enabled = true,
    super.key,
  });

  final String medicationLabel;
  final String doseLabel;
  final String unitLabel;
  final String routeLabel;
  final String administeredDateLabel;
  final String administeredTimeLabel;
  final String datePickerLabel;
  final String invalidDateMessage;
  final String timePickerLabel;
  final String invalidTimeMessage;
  final String confirmLabel;
  final String confirmSubtitle;
  final String requiredMessage;
  final TextEditingController doseController;
  final TextEditingController unitController;
  final DateTime administeredDate;
  final TimeOfDay administeredTime;
  final String routeValue;
  final List<AppSelectOption<String>> routeOptions;
  final bool confirmed;
  final ValueChanged<DateTime?> onAdministeredDateChanged;
  final ValueChanged<TimeOfDay?> onAdministeredTimeChanged;
  final ValueChanged<String?> onRouteChanged;
  final ValueChanged<bool> onConfirmedChanged;
  final String? medicationValue;
  final List<AppSelectOption<String>> medicationOptions;
  final ValueChanged<String?>? onMedicationChanged;
  final String? selectedMedicationDescription;
  final String? noMedicationMessage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasMedicationOptions = medicationOptions.isNotEmpty;
    return AppFormSection(
      children: <Widget>[
        if (hasMedicationOptions)
          AppSelectField<String>.searchable(
            value: medicationValue,
            labelText: medicationLabel,
            enabled: enabled,
            isRequired: true,
            options: medicationOptions,
            validator: (String? value) =>
                value == null || value.trim().isEmpty ? requiredMessage : null,
            onChanged: onMedicationChanged,
          )
        else if (noMedicationMessage != null)
          Text(
            noMedicationMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (hasMedicationOptions &&
            (selectedMedicationDescription ?? '').trim().isNotEmpty)
          Text(
            selectedMedicationDescription!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (hasMedicationOptions) ...<Widget>[
          AppTextField(
            controller: doseController,
            labelText: doseLabel,
            enabled: enabled,
            validator: (String? value) => _requiredText(value, requiredMessage),
          ),
          AppTextField(
            controller: unitController,
            labelText: unitLabel,
            enabled: enabled,
          ),
          AppSelectField<String>(
            value: routeValue,
            labelText: routeLabel,
            enabled: enabled,
            options: routeOptions,
            onChanged: onRouteChanged,
          ),
          _DateTimeFields(
            date: administeredDate,
            time: administeredTime,
            dateLabel: administeredDateLabel,
            timeLabel: administeredTimeLabel,
            datePickerLabel: datePickerLabel,
            invalidDateMessage: invalidDateMessage,
            timePickerLabel: timePickerLabel,
            invalidTimeMessage: invalidTimeMessage,
            requiredMessage: requiredMessage,
            enabled: enabled,
            onDateChanged: onAdministeredDateChanged,
            onTimeChanged: onAdministeredTimeChanged,
          ),
          AppCheckboxField(
            title: confirmLabel,
            subtitle: confirmSubtitle,
            value: confirmed,
            enabled: enabled,
            validator: (bool? value) => value == true ? null : requiredMessage,
            onChanged: onConfirmedChanged,
          ),
        ],
      ],
    );
  }
}

class AppHandoverActionForm extends StatelessWidget {
  const AppHandoverActionForm({
    required this.toUserLabel,
    required this.notesLabel,
    required this.requiredMessage,
    required this.toUserValue,
    required this.userOptions,
    required this.notesController,
    required this.onToUserChanged,
    this.onUserSearchTextChanged,
    this.confirmLabel,
    this.confirmed = false,
    this.onConfirmedChanged,
    this.attachmentTitle,
    this.attachmentEmptyDescription,
    this.attachmentChooseLabel,
    this.attachmentClearLabel,
    this.attachmentFileNames = const <String>[],
    this.onChooseAttachments,
    this.onClearAttachments,
    this.enabled = true,
    super.key,
  });

  final String toUserLabel;
  final String notesLabel;
  final String requiredMessage;
  final String? toUserValue;
  final List<AppSelectOption<String>> userOptions;
  final TextEditingController notesController;
  final ValueChanged<String?> onToUserChanged;
  final ValueChanged<String>? onUserSearchTextChanged;
  final String? confirmLabel;
  final bool confirmed;
  final ValueChanged<bool>? onConfirmedChanged;
  final String? attachmentTitle;
  final String? attachmentEmptyDescription;
  final String? attachmentChooseLabel;
  final String? attachmentClearLabel;
  final List<String> attachmentFileNames;
  final VoidCallback? onChooseAttachments;
  final VoidCallback? onClearAttachments;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: toUserValue,
          labelText: toUserLabel,
          enabled: enabled,
          isRequired: true,
          options: userOptions,
          validator: (String? value) =>
              value == null || value.trim().isEmpty ? requiredMessage : null,
          onChanged: onToUserChanged,
          onSearchTextChanged: onUserSearchTextChanged,
        ),
        AppTextField(
          controller: notesController,
          labelText: notesLabel,
          enabled: enabled,
          maxLines: 5,
          validator: (String? value) => _requiredText(value, requiredMessage),
        ),
        if (_hasAttachmentPanel)
          AppFileUploadPanel(
            title: attachmentTitle!,
            emptyDescription: attachmentEmptyDescription!,
            chooseLabel: attachmentChooseLabel!,
            clearLabel: attachmentClearLabel!,
            fileNames: attachmentFileNames,
            enabled: enabled,
            onChoose: onChooseAttachments!,
            onClear: onClearAttachments!,
          ),
        if (confirmLabel != null && onConfirmedChanged != null)
          AppCheckboxField(
            title: confirmLabel!,
            value: confirmed,
            enabled: enabled,
            validator: (bool? value) => value == true ? null : requiredMessage,
            onChanged: onConfirmedChanged,
          ),
      ],
    );
  }

  bool get _hasAttachmentPanel {
    return attachmentTitle != null &&
        attachmentEmptyDescription != null &&
        attachmentChooseLabel != null &&
        attachmentClearLabel != null &&
        onChooseAttachments != null &&
        onClearAttachments != null;
  }
}

class _DateTimeFields extends StatelessWidget {
  const _DateTimeFields({
    required this.date,
    required this.time,
    required this.dateLabel,
    required this.timeLabel,
    required this.datePickerLabel,
    required this.invalidDateMessage,
    required this.timePickerLabel,
    required this.invalidTimeMessage,
    required this.requiredMessage,
    required this.enabled,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  final DateTime date;
  final TimeOfDay time;
  final String dateLabel;
  final String timeLabel;
  final String datePickerLabel;
  final String invalidDateMessage;
  final String timePickerLabel;
  final String invalidTimeMessage;
  final String requiredMessage;
  final bool enabled;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<TimeOfDay?> onTimeChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 560;
        final List<Widget> fields = <Widget>[
          AppDateField(
            value: date,
            labelText: dateLabel,
            pickerButtonLabel: datePickerLabel,
            invalidDateMessage: invalidDateMessage,
            firstDate: DateTime(1900),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            currentDate: DateTime.now(),
            enabled: enabled,
            isRequired: true,
            validator: (DateTime? value) =>
                value == null ? requiredMessage : null,
            onChanged: onDateChanged,
          ),
          AppTimeField(
            value: time,
            labelText: timeLabel,
            hintText: 'HH:MM',
            pickerButtonLabel: timePickerLabel,
            invalidTimeMessage: invalidTimeMessage,
            enabled: enabled,
            isRequired: true,
            validator: (TimeOfDay? value) =>
                value == null ? requiredMessage : null,
            onChanged: onTimeChanged,
          ),
        ];
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              fields[0],
              SizedBox(height: theme.spacing.md),
              fields[1],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: fields[0]),
            SizedBox(width: theme.spacing.md),
            Expanded(child: fields[1]),
          ],
        );
      },
    );
  }
}

@immutable
final class AppCareTaskChecklistItem {
  const AppCareTaskChecklistItem({
    required this.title,
    required this.isComplete,
    this.subtitle,
    this.status,
  });

  final String title;
  final bool isComplete;
  final String? subtitle;
  final AppWorkspaceStatus? status;
}

class AppCareTaskChecklist extends StatelessWidget {
  const AppCareTaskChecklist({
    required this.items,
    required this.emptyLabel,
    super.key,
  });

  final List<AppCareTaskChecklistItem> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < items.length; index += 1) ...<Widget>[
          if (index > 0) const Divider(height: 1),
          _ChecklistRow(item: items[index]),
        ],
      ],
    );
  }
}

@immutable
final class AppRosterAssignmentView {
  const AppRosterAssignmentView({
    required this.title,
    this.subtitle,
    this.status,
  });

  final String title;
  final String? subtitle;
  final AppWorkspaceStatus? status;
}

class AppRosterAssignmentList extends StatelessWidget {
  const AppRosterAssignmentList({
    required this.items,
    required this.emptyLabel,
    super.key,
  });

  final List<AppRosterAssignmentView> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return _StatusRecordList(
      records: <_StatusRecordView>[
        for (final AppRosterAssignmentView item in items)
          _StatusRecordView(
            title: item.title,
            subtitle: item.subtitle,
            icon: Icons.badge_outlined,
            status: item.status,
          ),
      ],
      emptyLabel: emptyLabel,
    );
  }
}

@immutable
final class AppWardActivityEntry {
  const AppWardActivityEntry({
    required this.title,
    required this.icon,
    this.subtitle,
    this.body,
    this.status,
    this.trailingLabel,
    this.trailingIcon,
    this.onTrailingPressed,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final String? body;
  final AppWorkspaceStatus? status;
  final String? trailingLabel;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingPressed;
}

class AppWardActivityList extends StatelessWidget {
  const AppWardActivityList({
    required this.items,
    required this.emptyLabel,
    super.key,
  });

  final List<AppWardActivityEntry> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return _StatusRecordList(
      records: <_StatusRecordView>[
        for (final AppWardActivityEntry item in items)
          _StatusRecordView(
            title: item.title,
            subtitle: item.subtitle,
            body: item.body,
            icon: item.icon,
            status: item.status,
            trailingLabel: item.trailingLabel,
            trailingIcon: item.trailingIcon,
            onTrailingPressed: item.onTrailingPressed,
          ),
      ],
      emptyLabel: emptyLabel,
    );
  }
}

@immutable
final class AppNursingRecordEntry {
  const AppNursingRecordEntry({
    required this.title,
    required this.icon,
    this.subtitle,
    this.body,
    this.status,
    this.trailingLabel,
    this.trailingIcon,
    this.onTrailingPressed,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final String? body;
  final AppWorkspaceStatus? status;
  final String? trailingLabel;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingPressed;
}

class AppNursingRecordList extends StatelessWidget {
  const AppNursingRecordList({
    required this.items,
    required this.emptyLabel,
    super.key,
  });

  final List<AppNursingRecordEntry> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return _StatusRecordList(
      records: <_StatusRecordView>[
        for (final AppNursingRecordEntry item in items)
          _StatusRecordView(
            title: item.title,
            subtitle: item.subtitle,
            body: item.body,
            icon: item.icon,
            status: item.status,
            trailingLabel: item.trailingLabel,
            trailingIcon: item.trailingIcon,
            onTrailingPressed: item.onTrailingPressed,
          ),
      ],
      emptyLabel: emptyLabel,
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});

  final AppCareTaskChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            item.isComplete
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: theme.appTokens.listIconSize,
            color: item.isComplete ? colorScheme.primary : colorScheme.outline,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title, style: theme.textTheme.titleSmall),
                if (item.subtitle != null) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    item.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.status != null) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            AppWorkspaceStatusBadge(status: item.status!),
          ],
        ],
      ),
    );
  }
}

class _StatusRecordList extends StatelessWidget {
  const _StatusRecordList({required this.records, required this.emptyLabel});

  final List<_StatusRecordView> records;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (records.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < records.length; index += 1) ...<Widget>[
          if (index > 0) const Divider(height: 1),
          _StatusRecordRow(record: records[index]),
        ],
      ],
    );
  }
}

class _StatusRecordRow extends StatelessWidget {
  const _StatusRecordRow({required this.record});

  final _StatusRecordView record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            record.icon,
            size: theme.appTokens.listIconSize,
            color: colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(record.title, style: theme.textTheme.titleSmall),
                if (record.subtitle != null) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    record.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (record.body != null) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(record.body!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (record.status != null) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            AppWorkspaceStatusBadge(status: record.status!),
          ],
          if (record.trailingLabel != null &&
              record.onTrailingPressed != null) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            AppButton.tertiary(
              label: record.trailingLabel!,
              leadingIcon: record.trailingIcon,
              onPressed: record.onTrailingPressed,
            ),
          ],
        ],
      ),
    );
  }
}

final class _StatusRecordView {
  const _StatusRecordView({
    required this.title,
    required this.icon,
    this.subtitle,
    this.body,
    this.status,
    this.trailingLabel,
    this.trailingIcon,
    this.onTrailingPressed,
  });

  final String title;
  final String? subtitle;
  final String? body;
  final IconData icon;
  final AppWorkspaceStatus? status;
  final String? trailingLabel;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingPressed;
}

String? _requiredText(String? value, String requiredMessage) {
  if (value == null || value.trim().isEmpty) {
    return requiredMessage;
  }
  return null;
}

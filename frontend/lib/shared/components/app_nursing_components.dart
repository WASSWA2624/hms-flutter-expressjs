import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_checkbox_field.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class AppMedicationAdministrationForm extends StatelessWidget {
  const AppMedicationAdministrationForm({
    required this.medicationLabel,
    required this.doseLabel,
    required this.unitLabel,
    required this.routeLabel,
    required this.administeredAtLabel,
    required this.confirmLabel,
    required this.confirmSubtitle,
    required this.requiredMessage,
    required this.doseController,
    required this.unitController,
    required this.administeredAtController,
    required this.routeValue,
    required this.routeOptions,
    required this.confirmed,
    required this.onRouteChanged,
    required this.onConfirmedChanged,
    this.medicationValue,
    this.medicationOptions = const <AppSelectOption<String>>[],
    this.onMedicationChanged,
    this.enabled = true,
    this.dateTimeHint,
    super.key,
  });

  final String medicationLabel;
  final String doseLabel;
  final String unitLabel;
  final String routeLabel;
  final String administeredAtLabel;
  final String confirmLabel;
  final String confirmSubtitle;
  final String requiredMessage;
  final TextEditingController doseController;
  final TextEditingController unitController;
  final TextEditingController administeredAtController;
  final String routeValue;
  final List<AppSelectOption<String>> routeOptions;
  final bool confirmed;
  final ValueChanged<String?> onRouteChanged;
  final ValueChanged<bool> onConfirmedChanged;
  final String? medicationValue;
  final List<AppSelectOption<String>> medicationOptions;
  final ValueChanged<String?>? onMedicationChanged;
  final bool enabled;
  final String? dateTimeHint;

  @override
  Widget build(BuildContext context) {
    return AppFormSection(
      children: <Widget>[
        if (medicationOptions.isNotEmpty)
          AppSelectField<String>.searchable(
            value: medicationValue,
            labelText: medicationLabel,
            enabled: enabled,
            options: medicationOptions,
            onChanged: onMedicationChanged,
          ),
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
        AppTextField(
          controller: administeredAtController,
          labelText: administeredAtLabel,
          hintText: dateTimeHint,
          enabled: enabled,
          validator: (String? value) => _requiredText(value, requiredMessage),
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
    );
  }
}

class AppHandoverActionForm extends StatelessWidget {
  const AppHandoverActionForm({
    required this.toUserLabel,
    required this.notesLabel,
    required this.requiredMessage,
    required this.toUserController,
    required this.notesController,
    this.confirmLabel,
    this.confirmed = false,
    this.onConfirmedChanged,
    this.enabled = true,
    super.key,
  });

  final String toUserLabel;
  final String notesLabel;
  final String requiredMessage;
  final TextEditingController toUserController;
  final TextEditingController notesController;
  final String? confirmLabel;
  final bool confirmed;
  final ValueChanged<bool>? onConfirmedChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppFormSection(
      children: <Widget>[
        AppTextField(
          controller: toUserController,
          labelText: toUserLabel,
          enabled: enabled,
          validator: (String? value) => _requiredText(value, requiredMessage),
        ),
        AppTextField(
          controller: notesController,
          labelText: notesLabel,
          enabled: enabled,
          maxLines: 5,
          validator: (String? value) => _requiredText(value, requiredMessage),
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
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final String? body;
  final AppWorkspaceStatus? status;
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
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final String? body;
  final AppWorkspaceStatus? status;
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
  });

  final String title;
  final String? subtitle;
  final String? body;
  final IconData icon;
  final AppWorkspaceStatus? status;
}

String? _requiredText(String? value, String requiredMessage) {
  if (value == null || value.trim().isEmpty) {
    return requiredMessage;
  }
  return null;
}

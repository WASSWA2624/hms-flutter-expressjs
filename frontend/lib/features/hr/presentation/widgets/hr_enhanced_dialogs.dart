import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

const AccessRequirement hrAdminWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.hrWrite],
  activeModules: <String>['hr-rosters'],
);

Future<void> showHrAssignRoleDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffDetail detail,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  String? roleId;
  String? facilityId;

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAssignRoleDialogTitle),
    icon: const Icon(Icons.admin_panel_settings_outlined),
    submitLabel: l10n.hrAssignRoleAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _, [
      AppFailure? failure,
    ]) {
      return AppFormSection(
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: roleId,
            labelText: l10n.hrRolePositionColumnLabel,
            isRequired: true,
            options: _localizedSelectOptions(
              l10n,
              state?.referenceData.roles ?? const [],
            ),
            validator: AppValidators.requiredValue(
              l10n.hrFieldRequiredLabel(l10n.hrRolePositionColumnLabel),
            ),
            onChanged: (String? value) => roleId = value,
          ),
          AppSelectField<String>.searchable(
            value: facilityId,
            labelText: l10n.hrDepartmentLabel,
            options: _selectOptions(
              state?.referenceData.facilities ?? const [],
            ),
            onChanged: (String? value) => facilityId = value,
          ),
        ],
      );
    },
    onSubmit: () =>
        controller.assignUserRole(roleId: roleId ?? '', facilityId: facilityId),
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> showHrModuleAccessDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffAccessSummary? access,
) async {
  final AppLocalizations l10n = context.l10n;
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.hrModuleAccessDialogTitle),
      icon: const Icon(Icons.apps_outlined),
      scrollable: true,
      maxWidth: 640,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.hrModuleAccessSectionTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (access == null || access.moduleAccess.isEmpty)
            Text(l10n.hrNoModuleAccessLabel)
          else
            for (final HrModuleAccess module in access.moduleAccess)
              ListTile(
                dense: true,
                leading: Icon(
                  module.granted ? Icons.check_circle_outline : Icons.block,
                  color: module.granted
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(module.label ?? module.slug),
                subtitle: module.moduleGroup == null
                    ? null
                    : Text(module.moduleGroup!),
              ),
          const SizedBox(height: 16),
          Text(
            l10n.hrEffectivePermissionsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (access == null || access.effectivePermissions.isEmpty)
            Text(l10n.profileUnknownValue)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: access.effectivePermissions
                  .take(24)
                  .map((String permission) => Chip(label: Text(permission)))
                  .toList(growable: false),
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.hrManageAccessAction,
          onPressed: () {
            Navigator.of(context).maybePop();
            unawaited(showHrAccessWorkspaceDialog(context));
          },
        ),
      ],
    ),
  );
}

Future<void> showHrManageScheduleTemplatesDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => Consumer(
      builder: (BuildContext context, WidgetRef dialogRef, _) {
        final HrWorkspaceState? state = _readHrState(dialogRef);
        final List<HrOption> templates =
            state?.referenceData.shiftTemplates ?? const <HrOption>[];
        final HrWorkspaceController controller = dialogRef.read(
          hrWorkspaceControllerProvider.notifier,
        );

        return AppDialog(
          title: Text(l10n.hrManageScheduleTemplatesTitle),
          icon: const Icon(Icons.view_week_outlined),
          scrollable: true,
          maxWidth: 720,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.hrManageScheduleTemplatesDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (templates.isEmpty)
                Text(l10n.hrNoShiftTemplatesLabel)
              else
                for (final HrOption template in templates)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.view_week_outlined),
                    title: Text(template.label),
                    trailing: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        AppButton.secondary(
                          label: l10n.hrEditShiftTemplateAction,
                          onPressed: () async {
                            await showHrShiftTemplateDialog(
                              context,
                              dialogRef,
                              template,
                            );
                          },
                        ),
                        AppButton.secondary(
                          label: l10n.hrDeleteShiftTemplateAction,
                          onPressed: () async {
                            final AppFailure? failure = await controller
                                .deleteShiftTemplate(template.value);
                            if (context.mounted) {
                              showHrMutationSnackBar(context, failure);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
            ],
          ),
          actions: <Widget>[
            AppButton.primary(
              label: l10n.hrCreateShiftTemplateAction,
              leadingIcon: Icons.add,
              onPressed: () async {
                await showHrShiftTemplateDialog(context, dialogRef);
              },
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showHrShiftTemplateDialog(
  BuildContext context,
  WidgetRef ref, [
  HrOption? template,
]) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final TextEditingController nameController = TextEditingController(
    text: template?.label.split(' | ').first,
  );
  String? shiftType = template?.extra['shift_type']?.toString();
  String? facilityId;
  AppTimeValue? startTime = AppTimeValue.parse('08:00');
  AppTimeValue? endTime = AppTimeValue.parse('16:00');

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrShiftTemplateDialogTitle),
    icon: const Icon(Icons.view_week_outlined),
    submitLabel: template == null
        ? l10n.hrCreateShiftTemplateAction
        : l10n.hrEditShiftTemplateAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    showCancelButton: false,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _, [
      AppFailure? failure,
    ]) {
      return AppFormSection(
        children: <Widget>[
          AppTextField(
            controller: nameController,
            labelText: l10n.hrShiftTemplateNameLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrShiftTemplateNameLabel),
            ),
          ),
          AppSelectField<String>.searchable(
            value: shiftType,
            labelText: l10n.hrShiftTypeLabel,
            isRequired: true,
            options: _selectOptions(
              state?.referenceData.shiftTypes ?? const [],
            ),
            validator: AppValidators.requiredValue(
              l10n.hrFieldRequiredLabel(l10n.hrShiftTypeLabel),
            ),
            onChanged: (String? value) => shiftType = value,
          ),
          AppSelectField<String>.searchable(
            value: facilityId,
            labelText: l10n.hrDepartmentLabel,
            options: _selectOptions(
              state?.referenceData.facilities ?? const [],
            ),
            onChanged: (String? value) => facilityId = value,
          ),
          AppTimeField(
            value: startTime,
            labelText: l10n.hrStartTimeLabel,
            hintText: l10n.hrTimeHint,
            hourLabelText: l10n.appTimeHourLabel,
            minuteLabelText: l10n.appTimeMinuteLabel,
            pickerButtonLabel: l10n.appTimePickerAction,
            invalidTimeMessage: l10n.appTimeInvalidMessage,
            isRequired: true,
            use24HourFormat: true,
            validator: AppValidators.requiredValue<AppTimeValue>(
              l10n.hrFieldRequiredLabel(l10n.hrStartTimeLabel),
            ),
            onChanged: (AppTimeValue? value) => startTime = value,
          ),
          AppTimeField(
            value: endTime,
            labelText: l10n.hrEndTimeLabel,
            hintText: l10n.hrTimeHint,
            hourLabelText: l10n.appTimeHourLabel,
            minuteLabelText: l10n.appTimeMinuteLabel,
            pickerButtonLabel: l10n.appTimePickerAction,
            invalidTimeMessage: l10n.appTimeInvalidMessage,
            isRequired: true,
            use24HourFormat: true,
            validator: AppValidators.requiredValue<AppTimeValue>(
              l10n.hrFieldRequiredLabel(l10n.hrEndTimeLabel),
            ),
            onChanged: (AppTimeValue? value) => endTime = value,
          ),
        ],
      );
    },
    onSubmit: () {
      final Map<String, Object?> payload = <String, Object?>{
        'name': nameController.text.trim(),
        'shift_type': shiftType,
        'facility_id': facilityId,
        'default_start_time': startTime?.format24(),
        'default_end_time': endTime?.format24(),
        'is_active': true,
        if (template == null && state?.selectedStaff?.profile.tenantId != null)
          'tenant_id': state!.selectedStaff!.profile.tenantId,
      };
      if (template == null) {
        return controller.createShiftTemplate(payload);
      }
      return controller.updateShiftTemplate(template.value, payload);
    },
  );
  nameController.dispose();
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> showHrPreviewPayrollDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final Result<HrPayrollPreview> result = await controller.previewPayrollRun(
    item,
  );
  if (!context.mounted) {
    return;
  }
  await result.when(
    success: (HrPayrollPreview preview) async {
      await showAppDialog<void>(
        context: context,
        builder: (_) => AppDialog(
          title: Text(l10n.hrPreviewPayrollDialogTitle),
          icon: const Icon(Icons.receipt_long_outlined),
          scrollable: true,
          maxWidth: 720,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppInfoTileGrid(
                emptyValue: l10n.profileUnknownValue,
                items: <AppInfoTileData>[
                  AppInfoTileData(
                    label: l10n.hrPeriodColumnLabel,
                    value: _dateRange(
                      context,
                      preview.periodStart,
                      preview.periodEnd,
                    ),
                    icon: Icons.date_range_outlined,
                  ),
                  AppInfoTileData(
                    label: l10n.hrStatusColumnLabel,
                    value: preview.status,
                    icon: Icons.radio_button_checked,
                  ),
                  AppInfoTileData(
                    label: l10n.hrPayrollReportLabel,
                    value:
                        '${preview.totalAmount} ${preview.currency ?? ''} (${preview.staffCount} staff)',
                    icon: Icons.payments_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final HrPayrollPreviewItem line in preview.items.take(12))
                ListTile(
                  dense: true,
                  title: Text(line.staffName ?? line.staffNumber ?? ''),
                  subtitle: Text(
                    '${line.totalHours}h | ${line.amount} ${line.currency ?? ''}',
                  ),
                ),
            ],
          ),
        ),
      );
    },
    failure: (AppFailure failure) {
      showHrMutationSnackBar(context, failure);
    },
  );
}

Future<void> showHrPreviewRosterDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final Result<HrRosterGenerateResult> result = await controller
      .previewRosterGenerate(item);
  if (!context.mounted) {
    return;
  }
  await result.when(
    success: (HrRosterGenerateResult preview) async {
      await showAppDialog<void>(
        context: context,
        builder: (_) => AppDialog(
          title: Text(l10n.hrPreviewRosterDialogTitle),
          icon: const Icon(Icons.auto_awesome_outlined),
          scrollable: true,
          maxWidth: 560,
          content: AppInfoTileGrid(
            emptyValue: l10n.profileUnknownValue,
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.hrRosterCoverageLabel,
                value: preview.coveragePercent?.toString(),
                icon: Icons.check_circle_outline,
              ),
              AppInfoTileData(
                label: l10n.hrRosterGapsLabel,
                value: preview.gapCount.toString(),
                icon: Icons.warning_amber_outlined,
              ),
              AppInfoTileData(
                label: l10n.hrAssignShiftAction,
                value: preview.assignmentCount.toString(),
                icon: Icons.calendar_view_week_outlined,
              ),
            ],
          ),
        ),
      );
    },
    failure: (AppFailure failure) {
      showHrMutationSnackBar(context, failure);
    },
  );
}

Future<void> showHrEndAssignmentDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffAssignment assignment,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  DateTime endDate = DateTime.now();
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialog(
      title: Text(l10n.hrEndAssignmentDialogTitle),
      icon: const Icon(Icons.event_busy_outlined),
      content: AppDateField(
        value: endDate,
        labelText: l10n.hrEndAssignmentDateLabel,
        isRequired: true,
        firstDate: assignment.startDate ?? DateTime(2020),
        lastDate: DateTime(2100),
        currentDate: DateTime.now(),
        pickerButtonLabel: l10n.hrPickDateAction,
        invalidDateMessage: l10n.appDateInvalidMessage,
        onChanged: (DateTime? value) {
          if (value != null) {
            endDate = value;
          }
        },
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AppButton(
          label: l10n.hrEndAssignmentAction,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  if (saved == true && context.mounted) {
    final AppFailure? failure = await controller.endAssignment(
      assignment,
      endDate: endDate,
    );
    if (context.mounted) {
      showHrMutationSnackBar(context, failure);
    }
  }
}

void showHrMutationSnackBar(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.hrSavedMessage : l10n.failureMessage(failure),
      ),
    ),
  );
}

HrWorkspaceState? _readHrState(WidgetRef ref) {
  return ref
      .read(hrWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (HrWorkspaceState state) => state, failure: (_) => null);
}

List<AppSelectOption<String>> _localizedSelectOptions(
  AppLocalizations l10n,
  List<HrOption> options,
) {
  return <AppSelectOption<String>>[
    for (final HrOption option in options)
      AppSelectOption<String>(
        value: option.value,
        label: l10n.hrLocalizedOptionLabel(option),
      ),
  ];
}

List<AppSelectOption<String>> _selectOptions(List<HrOption> options) {
  return <AppSelectOption<String>>[
    for (final HrOption option in options)
      AppSelectOption<String>(value: option.value, label: option.label),
  ];
}

String _dateRange(BuildContext context, DateTime? from, DateTime? to) {
  final AppLocalizations l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  final String? start = from == null
      ? null
      : AppFormatters.shortDate(from, locale);
  final String? end = to == null ? null : AppFormatters.shortDate(to, locale);
  if (start != null && end != null) {
    return '$start - $end';
  }
  return start ?? end ?? l10n.profileUnknownValue;
}

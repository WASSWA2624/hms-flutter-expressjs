import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_preview_breakdown.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

export '../hr_presentation_helpers.dart';

Future<void> showHrAssignRoleDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffDetail detail,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
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
            options: hrLocalizedSelectOptions(
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
            options: hrSelectOptions(
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
        final HrWorkspaceState? state = readHrWorkspaceState(dialogRef);
        final List<HrOption> templates =
            state?.referenceData.shiftTemplates ?? const <HrOption>[];
        final HrWorkspaceController controller = dialogRef.read(
          hrWorkspaceControllerProvider.notifier,
        );

        return AppDialog(
          title: Text(l10n.hrManageScheduleTemplatesTitle),
          icon: const Icon(Icons.view_week_outlined),
          scrollable: true,
          initialMaximized: true,
          maxWidth: 980,
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
                  _HrScheduleTemplateListTile(
                    template: template,
                    referenceData: state?.referenceData ?? const HrReferenceData(),
                    onOpenDetail: () => showHrScheduleTemplateDetailDialog(
                      context,
                      dialogRef,
                      template,
                    ),
                    onEdit: () => showHrShiftTemplateDialog(
                      context,
                      dialogRef,
                      template,
                    ),
                    onDelete: () async {
                      final AppFailure? failure = await controller
                          .deleteShiftTemplate(template.value);
                      if (context.mounted) {
                        showHrMutationSnackBar(context, failure);
                      }
                    },
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
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final TextEditingController nameController = TextEditingController(
    text: template?.label,
  );
  String? shiftType = template?.extra['shift_type']?.toString();
  String? facilityId = template?.extra['facility_id']?.toString();
  final HrWeeklyScheduleDraft schedule = template == null
      ? HrWeeklyScheduleDraft(weekdayDefaults: true)
      : HrWeeklyScheduleDraft.fromTemplateExtra(template.extra);

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(
      template == null
          ? l10n.hrSchedulePatternCreateTitle
          : l10n.hrSchedulePatternEditTitle,
    ),
    icon: const Icon(Icons.view_week_outlined),
    submitLabel: template == null
        ? l10n.hrCreateShiftTemplateAction
        : l10n.hrSchedulePatternEditAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    showCancelButton: false,
    initialMaximized: true,
    maxWidth: 980,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _, [
      AppFailure? failure,
    ]) {
      return _HrShiftTemplateFields(
        nameController: nameController,
        referenceData: state?.referenceData ?? const HrReferenceData(),
        schedule: schedule,
        shiftType: shiftType,
        facilityId: facilityId,
        onShiftTypeChanged: (String? value) => shiftType = value,
        onFacilityChanged: (String? value) => facilityId = value,
      );
    },
    onSubmit: () {
      final String? validationError = schedule.validate(l10n);
      if (validationError != null) {
        return Future<AppFailure?>.value(
          AppFailure.validation(detailMessage: validationError),
        );
      }

      final List<Map<String, Object?>> weeklySchedule =
          schedule.toTemplateWeeklySchedulePayload();
      final Map<String, Object?> payload = <String, Object?>{
        'name': nameController.text.trim(),
        'shift_type': shiftType,
        'facility_id': facilityId,
        'weekly_schedule_json': weeklySchedule,
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
  schedule.dispose();
  nameController.dispose();
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

class _HrShiftTemplateFields extends StatefulWidget {
  const _HrShiftTemplateFields({
    required this.nameController,
    required this.referenceData,
    required this.schedule,
    required this.shiftType,
    required this.facilityId,
    required this.onShiftTypeChanged,
    required this.onFacilityChanged,
  });

  final TextEditingController nameController;
  final HrReferenceData referenceData;
  final HrWeeklyScheduleDraft schedule;
  final String? shiftType;
  final String? facilityId;
  final ValueChanged<String?> onShiftTypeChanged;
  final ValueChanged<String?> onFacilityChanged;

  @override
  State<_HrShiftTemplateFields> createState() => _HrShiftTemplateFieldsState();
}

class _HrShiftTemplateFieldsState extends State<_HrShiftTemplateFields> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormSection(
      children: <Widget>[
        AppTextField(
          controller: widget.nameController,
          labelText: l10n.hrShiftTemplateNameLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrShiftTemplateNameLabel),
          ),
        ),
        AppSelectField<String>.searchable(
          value: widget.shiftType,
          labelText: l10n.hrShiftTypeLabel,
          isRequired: true,
          options: hrSelectOptions(widget.referenceData.shiftTypes),
          validator: AppValidators.requiredValue(
            l10n.hrFieldRequiredLabel(l10n.hrShiftTypeLabel),
          ),
          onChanged: widget.onShiftTypeChanged,
        ),
        AppSelectField<String>.searchable(
          value: widget.facilityId,
          labelText: l10n.hrDepartmentLabel,
          options: hrSelectOptions(widget.referenceData.facilities),
          onChanged: widget.onFacilityChanged,
        ),
        HrWeeklyScheduleEditor(
          schedule: widget.schedule,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }
}

class _HrScheduleTemplateListTile extends StatelessWidget {
  const _HrScheduleTemplateListTile({
    required this.template,
    required this.referenceData,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final HrOption template;
  final HrReferenceData referenceData;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? shiftType = template.extra['shift_type']?.toString();
    final String? facilityId = template.extra['facility_id']?.toString();
    final String? departmentLabel = referenceData.facilities
        .where((HrOption option) => option.value == facilityId)
        .map((HrOption option) => option.label)
        .firstOrNull;
    final List<String> subtitleParts = <String>[
      if (shiftType != null && shiftType.isNotEmpty)
        hrShiftTypeLabel(l10n, shiftType),
      if (departmentLabel != null && departmentLabel.trim().isNotEmpty)
        departmentLabel,
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.view_week_outlined),
      title: Text(template.label),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' · ')),
      onTap: onOpenDetail,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isCopyableIdentifierValue(template.displayId ?? template.value))
            Padding(
              padding: EdgeInsetsDirectional.only(end: theme.spacing.sm),
              child: AppCopyableIdentifier(
                value: template.displayId ?? template.value,
              ),
            ),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.edit_outlined,
            label: l10n.hrSchedulePatternEditAction,
            semanticLabel: l10n.hrSchedulePatternEditAction,
            tooltip: l10n.hrSchedulePatternEditAction,
            onPressed: onEdit,
          ),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.delete_outline,
            label: l10n.hrSchedulePatternDeleteAction,
            semanticLabel: l10n.hrSchedulePatternDeleteAction,
            tooltip: l10n.hrSchedulePatternDeleteAction,
            color: theme.colorScheme.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
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
                    value: hrDateRange(
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
                HrPayrollPreviewBreakdown(item: line),
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

Future<void> showHrScheduleTemplateDetailDialog(
  BuildContext context,
  WidgetRef ref,
  HrOption template,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => Consumer(
      builder: (BuildContext context, WidgetRef dialogRef, _) {
        final AppLocalizations l10n = context.l10n;
        final ThemeData theme = Theme.of(context);
        final HrWorkspaceState? state = dialogRef
            .watch(hrWorkspaceControllerProvider)
            .asData
            ?.value
            .when(
              success: (HrWorkspaceState value) => value,
              failure: (_) => null,
            );
        final HrReferenceData referenceData =
            state?.referenceData ?? const HrReferenceData();
        final HrWorkspaceController controller = dialogRef.read(
          hrWorkspaceControllerProvider.notifier,
        );
        final HrWeeklyScheduleDraft schedule =
            HrWeeklyScheduleDraft.fromTemplateExtra(template.extra);
        final String? facilityId = template.extra['facility_id']?.toString();
        final String? departmentLabel = referenceData.facilities
            .where((HrOption option) => option.value == facilityId)
            .map((HrOption option) => option.label)
            .firstOrNull;
        final String? shiftType = template.extra['shift_type']?.toString();
        final bool isActive = template.extra['is_active'] != false;
        final DateTime? createdAt =
            _parseTemplateDateTime(template.extra['created_at']);
        final DateTime? updatedAt =
            _parseTemplateDateTime(template.extra['updated_at']);

        return AppDialog(
          title: Text(template.label),
          icon: const Icon(Icons.view_week_outlined),
          scrollable: true,
          initialMaximized: true,
          maxWidth: 980,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppInfoTileGrid(
                emptyValue: l10n.profileUnknownValue,
                items: <AppInfoTileData>[
                  AppInfoTileData(
                    label: l10n.hrScheduleTemplateIdLabel,
                    value: template.displayId ?? template.value,
                    icon: Icons.confirmation_number_outlined,
                    copyable: true,
                  ),
                  AppInfoTileData(
                    label: l10n.hrShiftTypeLabel,
                    value: hrShiftTypeLabel(l10n, shiftType),
                    icon: Icons.schedule_outlined,
                  ),
                  if ((departmentLabel ?? '').trim().isNotEmpty)
                    AppInfoTileData(
                      label: l10n.hrDepartmentLabel,
                      value: departmentLabel,
                      icon: Icons.account_tree_outlined,
                    ),
                  AppInfoTileData(
                    label: l10n.hrStatusLabel,
                    value: isActive
                        ? l10n.hrScheduleTemplateActiveLabel
                        : l10n.hrScheduleTemplateInactiveLabel,
                    icon: Icons.flag_outlined,
                  ),
                  if (createdAt != null)
                    AppInfoTileData(
                      label: l10n.hrCreatedAtLabel,
                      value: AppFormatters.dateTime(
                        createdAt,
                        Localizations.localeOf(context),
                      ),
                      icon: Icons.event_outlined,
                    ),
                  if (updatedAt != null)
                    AppInfoTileData(
                      label: l10n.hrUpdatedAtLabel,
                      value: AppFormatters.dateTime(
                        updatedAt,
                        Localizations.localeOf(context),
                      ),
                      icon: Icons.update_outlined,
                    ),
                ],
              ),
              SizedBox(height: theme.spacing.md),
              HrWeeklyScheduleEditor(
                schedule: schedule,
                onChanged: () {},
                readOnly: true,
              ),
            ],
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: l10n.hrSchedulePatternEditAction,
              leadingIcon: Icons.edit_outlined,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await showHrShiftTemplateDialog(context, dialogRef, template);
              },
            ),
            AppButton(
              label: l10n.hrSchedulePatternDeleteAction,
              leadingIcon: Icons.delete_outline,
              semanticLabel: l10n.hrSchedulePatternDeleteAction,
              tooltip: l10n.hrSchedulePatternDeleteAction,
              onPressed: () async {
                final AppFailure? failure = await controller.deleteShiftTemplate(
                  template.value,
                );
                if (context.mounted) {
                  Navigator.of(dialogContext).pop();
                  showHrMutationSnackBar(context, failure);
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

DateTime? _parseTemplateDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  final String raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

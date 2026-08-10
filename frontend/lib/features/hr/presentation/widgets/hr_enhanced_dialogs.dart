import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_preview_breakdown.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

export 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_role_dialog.dart'
    show showHrAssignRoleDialog;
export '../hr_presentation_helpers.dart';

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
      maxWidth: 980,
      content: _HrModuleAccessDialogBody(access: access),
    ),
  );
}

class _HrModuleAccessDialogBody extends StatelessWidget {
  const _HrModuleAccessDialogBody({required this.access});

  final HrStaffAccessSummary? access;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<HrModuleAccess> modules =
        access?.moduleAccess ?? const <HrModuleAccess>[];
    final List<String> permissions =
        access?.effectivePermissions ?? const <String>[];
    final int grantedCount = modules
        .where((HrModuleAccess module) => module.granted)
        .length;
    final List<AppPermissionAssignmentOption> permissionOptions = permissions
        .map(
          (String code) => AppPermissionAssignmentOption(
            id: code,
            code: code,
            label: l10n.permissionCatalogLabelForCode(code),
            description: code,
          ),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (access != null && access!.hasLinkedUser) ...<Widget>[
          AppInfoTileGrid(
            emptyValue: l10n.profileUnknownValue,
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.hrLinkedUserLabel,
                value:
                    access!.linkedUserFullName ??
                    access!.linkedUserEmail ??
                    access!.linkedUserDisplayId,
                icon: Icons.person_outline,
              ),
              AppInfoTileData(
                label: l10n.hrModuleAccessSectionTitle,
                value: l10n.hrModuleAccessGrantedSummaryLabel(grantedCount),
                icon: Icons.extension_outlined,
              ),
              AppInfoTileData(
                label: l10n.hrEffectivePermissionsTitle,
                value: l10n.hrAccessPermissionCountLabel(permissions.length),
                icon: Icons.verified_user_outlined,
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
        ],
        AppCollapsibleSection(
          title: l10n.hrModuleAccessSectionTitle,
          subtitle: l10n.hrModuleAccessSectionSubtitle,
          titleIcon: Icons.extension_outlined,
          headerActions: <Widget>[
            _HrModuleAccessCountChip(
              count: modules.length,
              labeledCount: l10n.hrModuleAccessModulesCountChip(modules.length),
            ),
          ],
          child: modules.isEmpty
              ? AppStateView(
                  title: l10n.hrNoModuleAccessLabel,
                  body: l10n.hrModuleAccessSectionSubtitle,
                  variant: AppStateViewVariant.empty,
                )
              : _HrModuleAccessGrid(modules: modules),
        ),
        SizedBox(height: theme.spacing.md),
        AppCollapsibleSection(
          title: l10n.hrEffectivePermissionsTitle,
          subtitle: l10n.hrEffectivePermissionsSubtitle,
          titleIcon: Icons.verified_user_outlined,
          headerActions: <Widget>[
            _HrModuleAccessCountChip(
              count: permissions.length,
              labeledCount: l10n.hrModuleAccessPermissionsCountChip(
                permissions.length,
              ),
            ),
          ],
          child: AppPermissionGroupedView(
            permissions: permissionOptions,
            emptyMessage: l10n.profileUnknownValue,
          ),
        ),
      ],
    );
  }
}

class _HrModuleAccessGrid extends StatelessWidget {
  const _HrModuleAccessGrid({required this.modules});

  final List<HrModuleAccess> modules;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveWrap(
      maxColumns: 2,
      minItemWidth: 280,
      children: <Widget>[
        for (final HrModuleAccess module in modules)
          _HrModuleAccessCard(module: module),
      ],
    );
  }
}

class _HrModuleAccessCard extends StatelessWidget {
  const _HrModuleAccessCard({required this.module});

  final HrModuleAccess module;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool granted = module.granted;
    final String title = (module.label ?? module.slug).trim().isEmpty
        ? module.slug
        : (module.label ?? module.slug);
    final AppWorkspaceStatusTone tone = granted
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral;
    final Color iconBackground = granted
        ? theme.statusColors.successContainer
        : colors.surfaceContainerHighest;
    final Color iconColor = granted
        ? theme.statusColors.onSuccessContainer
        : colors.onSurfaceVariant;

    return AppContentPanel(
      tone: tone,
      density: AppContentPanelDensity.compact,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(
                context.responsiveRadius(theme.radius.md),
              ),
            ),
            child: Icon(
              granted ? Icons.check_circle_outline : Icons.lock_outline,
              color: iconColor,
              size: 22,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
                if (module.slug.trim().isNotEmpty &&
                    module.slug.trim().toLowerCase() !=
                        title.trim().toLowerCase()) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    module.slug,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                SizedBox(height: theme.spacing.sm),
                AppStatusBadge(
                  label: granted
                      ? l10n.hrModuleAccessGrantedLabel
                      : l10n.hrModuleAccessNotGrantedLabel,
                  tone: granted
                      ? AppWorkspaceStatusTone.success
                      : AppWorkspaceStatusTone.warning,
                  icon: granted
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HrModuleAccessCountChip extends StatelessWidget {
  const _HrModuleAccessCountChip({
    required this.count,
    required this.labeledCount,
  });

  final int count;
  final String labeledCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppActionLabelScope? labelScope = AppActionLabelScope.maybeOf(
      context,
    );
    final bool showLabel =
        labelScope?.forceIconOnly != true && (labelScope?.showLabels ?? true);

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Chip(
        avatar: Icon(
          Icons.format_list_numbered_outlined,
          size: 16,
          color: colorScheme.primary,
        ),
        label: Text(showLabel ? labeledCount : '$count'),
        backgroundColor: colorScheme.primaryContainer,
        visualDensity: VisualDensity.compact,
        labelStyle: theme.textTheme.labelSmall,
      ),
    );
  }
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
                    referenceData:
                        state?.referenceData ?? const HrReferenceData(),
                    onOpenDetail: () => showHrScheduleTemplateDetailDialog(
                      context,
                      dialogRef,
                      template,
                    ),
                    onEdit: () =>
                        showHrShiftTemplateDialog(context, dialogRef, template),
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
            AppAccessActionGate(
              requirement: HrShiftsAtomPermissions.create,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.primary(
                  label: l10n.hrCreateShiftTemplateAction,
                  leadingIcon: Icons.add,
                  enabled: isAllowed,
                  onPressed: !isAllowed
                      ? null
                      : () async {
                          await showHrShiftTemplateDialog(context, dialogRef);
                        },
                );
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
    maxWidth: 980,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
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

      final List<Map<String, Object?>> weeklySchedule = schedule
          .toTemplateWeeklySchedulePayload();
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
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
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
          AppAccessActionGate(
            requirement: HrShiftsAtomPermissions.update,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton(
                iconOnly: true,
                leadingIcon: Icons.edit_outlined,
                label: l10n.hrSchedulePatternEditAction,
                semanticLabel: l10n.hrSchedulePatternEditAction,
                tooltip: l10n.hrSchedulePatternEditAction,
                enabled: isAllowed,
                onPressed: isAllowed ? onEdit : null,
              );
            },
          ),
          AppAccessActionGate(
            requirement: HrShiftsAtomPermissions.delete,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton(
                iconOnly: true,
                leadingIcon: Icons.delete_outline,
                label: l10n.hrSchedulePatternDeleteAction,
                semanticLabel: l10n.hrSchedulePatternDeleteAction,
                tooltip: l10n.hrSchedulePatternDeleteAction,
                color: theme.colorScheme.error,
                enabled: isAllowed,
                onPressed: isAllowed ? onDelete : null,
              );
            },
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
  if (!HrHumanResourcesAtomPermissions.endAssignment.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }

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
        AppButton.close(
          leadingIcon: AppActionIcons.cancel,
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
  final HrWorkspaceState? workspaceState = readHrWorkspaceState(ref);
  final HrReferenceData referenceData =
      workspaceState?.referenceData ?? const HrReferenceData();
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AppLocalizations l10n = dialogContext.l10n;
      final ThemeData theme = Theme.of(dialogContext);
      final HrWeeklyScheduleDraft schedule =
          HrWeeklyScheduleDraft.fromTemplateExtra(template.extra);
      final String? facilityId = template.extra['facility_id']?.toString();
      final String? departmentLabel = referenceData.facilities
          .where((HrOption option) => option.value == facilityId)
          .map((HrOption option) => option.label)
          .firstOrNull;
      final String? shiftType = template.extra['shift_type']?.toString();
      final bool isActive = template.extra['is_active'] != false;
      final DateTime? createdAt = _parseTemplateDateTime(
        template.extra['created_at'],
      );
      final DateTime? updatedAt = _parseTemplateDateTime(
        template.extra['updated_at'],
      );

      return AppDialog(
        title: Text(template.label),
        icon: const Icon(Icons.view_week_outlined),
        scrollable: true,
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
                      Localizations.localeOf(dialogContext),
                    ),
                    icon: Icons.event_outlined,
                  ),
                if (updatedAt != null)
                  AppInfoTileData(
                    label: l10n.hrUpdatedAtLabel,
                    value: AppFormatters.dateTime(
                      updatedAt,
                      Localizations.localeOf(dialogContext),
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
          AppAccessActionGate(
            requirement: HrShiftsAtomPermissions.update,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                label: l10n.hrSchedulePatternEditAction,
                leadingIcon: Icons.edit_outlined,
                enabled: isAllowed,
                onPressed: !isAllowed
                    ? null
                    : () async {
                        Navigator.of(dialogContext).pop();
                        await showHrShiftTemplateDialog(
                          context,
                          ref,
                          template,
                        );
                      },
              );
            },
          ),
          AppAccessActionGate(
            requirement: HrShiftsAtomPermissions.delete,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton(
                label: l10n.hrSchedulePatternDeleteAction,
                leadingIcon: Icons.delete_outline,
                semanticLabel: l10n.hrSchedulePatternDeleteAction,
                tooltip: l10n.hrSchedulePatternDeleteAction,
                enabled: isAllowed,
                onPressed: !isAllowed
                    ? null
                    : () async {
                        final AppFailure? failure = await controller
                            .deleteShiftTemplate(template.value);
                        if (context.mounted) {
                          Navigator.of(dialogContext).pop();
                          showHrMutationSnackBar(context, failure);
                        }
                      },
              );
            },
          ),
        ],
      );
    },
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

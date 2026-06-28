import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
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
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return AppFormSection(
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: roleId,
            labelText: l10n.hrRolePositionColumnLabel,
            isRequired: true,
            options: _selectOptions(state?.referenceData.roles ?? const []),
            validator: AppValidators.requiredValue(
              l10n.hrFieldRequiredLabel(l10n.hrRolePositionColumnLabel),
            ),
            onChanged: (String? value) => roleId = value,
          ),
          AppSelectField<String>.searchable(
            value: facilityId,
            labelText: l10n.hrDepartmentLabel,
            options: _selectOptions(state?.referenceData.facilities ?? const []),
            onChanged: (String? value) => facilityId = value,
          ),
        ],
      );
    },
    onSubmit: () => controller.assignUserRole(
      roleId: roleId ?? '',
      facilityId: facilityId,
    ),
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> showHrModuleAccessDialog(
  BuildContext context,
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
          label: l10n.hrOpenAccessAdminAction,
          onPressed: () {
            Navigator.of(context).maybePop();
            context.go(
              AppRoutes.accessAdmin.location(
                queryParameters: <String, String>{
                  if ((access?.linkedUserDisplayId ?? '').isNotEmpty)
                    'userId': access!.linkedUserDisplayId!,
                },
              ),
            );
          },
        ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    ),
  );
}

Future<void> showHrCreateUserDialog(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, Object?> staffPayload,
}) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrCreateUserDialogTitle),
    icon: const Icon(Icons.person_add_outlined),
    submitLabel: l10n.hrCreateUserAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
      return AppFormSection(
        children: <Widget>[
          AppTextField(
            controller: emailController,
            labelText: l10n.hrEmailLabel,
            isRequired: true,
            keyboardType: TextInputType.emailAddress,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrEmailLabel),
            ),
          ),
          AppTextField(
            controller: passwordController,
            labelText: l10n.hrPasswordLabel,
            isRequired: true,
            obscureText: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrPasswordLabel),
            ),
          ),
          AppTextField(
            controller: phoneController,
            labelText: l10n.profilePhoneLabel,
            keyboardType: TextInputType.phone,
          ),
        ],
      );
    },
    onSubmit: () => controller.createUserAndLinkStaff(<String, Object?>{
      ...staffPayload,
      'email': emailController.text.trim(),
      'password': passwordController.text.trim(),
      'phone': phoneController.text.trim(),
      'status': 'ACTIVE',
    }),
  );
  emailController.dispose();
  passwordController.dispose();
  phoneController.dispose();
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
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
  final TextEditingController startController = TextEditingController(
    text: '08:00',
  );
  final TextEditingController endController = TextEditingController(
    text: '16:00',
  );

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrShiftTemplateDialogTitle),
    icon: const Icon(Icons.view_week_outlined),
    submitLabel: template == null
        ? l10n.hrCreateShiftTemplateAction
        : l10n.hrEditShiftTemplateAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _) {
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
            options: _selectOptions(state?.referenceData.shiftTypes ?? const []),
            validator: AppValidators.requiredValue(
              l10n.hrFieldRequiredLabel(l10n.hrShiftTypeLabel),
            ),
            onChanged: (String? value) => shiftType = value,
          ),
          AppSelectField<String>.searchable(
            value: facilityId,
            labelText: l10n.hrDepartmentLabel,
            options: _selectOptions(state?.referenceData.facilities ?? const []),
            onChanged: (String? value) => facilityId = value,
          ),
          AppTextField(
            controller: startController,
            labelText: l10n.hrStartTimeLabel,
            isRequired: true,
          ),
          AppTextField(
            controller: endController,
            labelText: l10n.hrEndTimeLabel,
            isRequired: true,
          ),
        ],
      );
    },
    onSubmit: () {
      final Map<String, Object?> payload = <String, Object?>{
        'name': nameController.text.trim(),
        'shift_type': shiftType,
        'facility_id': facilityId,
        'default_start_time': startController.text.trim(),
        'default_end_time': endController.text.trim(),
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
  startController.dispose();
  endController.dispose();
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
          actions: <Widget>[
            AppButton.secondary(
              label: l10n.commonCloseActionLabel,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
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
          actions: <Widget>[
            AppButton.secondary(
              label: l10n.commonCloseActionLabel,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
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
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.hrEndAssignmentDialogTitle),
      icon: const Icon(Icons.event_busy_outlined),
      content: Text(l10n.hrEndAssignmentAction),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: l10n.hrEndAssignmentAction,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (saved == true && context.mounted) {
    final AppFailure? failure = await controller.endAssignment(assignment);
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

List<AppSelectOption<String>> _selectOptions(List<HrOption> options) {
  return <AppSelectOption<String>>[
    for (final HrOption option in options)
      AppSelectOption<String>(value: option.value, label: option.label),
  ];
}

String _dateRange(BuildContext context, DateTime? from, DateTime? to) {
  final AppLocalizations l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  final String? start =
      from == null ? null : AppFormatters.shortDate(from, locale);
  final String? end = to == null ? null : AppFormatters.shortDate(to, locale);
  if (start != null && end != null) {
    return '$start - $end';
  }
  return start ?? end ?? l10n.profileUnknownValue;
}

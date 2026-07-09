import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_mutation_dialog.dart';

enum RoleMutationMode { create, edit }

typedef RoleMutationSubmitHandler =
    Future<AppFailure?> Function(AccessAdminRoleDraft draft);

typedef RolePermissionLookupsLoader =
    Future<List<AccessAdminLookupOption>> Function(String tenantId);

Future<bool?> showRoleMutationDialog({
  required BuildContext context,
  required RoleMutationMode mode,
  List<AccessAdminLookupOption> permissionLookups =
      const <AccessAdminLookupOption>[],
  RolePermissionLookupsLoader? loadPermissionsForTenant,
  String? tenantId,
  String? facilityId,
  List<AccessAdminLookupOption> tenantOptions = const <AccessAdminLookupOption>[],
  bool requireTenantPicker = false,
  String? initialName,
  String? initialDescription,
  Set<String> initialPermissionIds = const <String>{},
  required RoleMutationSubmitHandler onSubmit,
}) async {
  final AppLocalizations l10n = context.l10n;
  final TextEditingController nameController = TextEditingController(
    text: initialName,
  );
  final TextEditingController descriptionController = TextEditingController(
    text: initialDescription,
  );
  final Set<String> selectedPermissionIds = Set<String>.from(
    initialPermissionIds,
  );
  String? selectedTenantId = tenantId;
  final bool showTenantPicker =
      requireTenantPicker || (mode == RoleMutationMode.create && tenantId == null);
  List<AccessAdminLookupOption> currentPermissionLookups =
      List<AccessAdminLookupOption>.from(permissionLookups);
  bool isLoadingPermissions = false;
  bool permissionLoadAttempted = permissionLookups.isNotEmpty;
  bool scheduledInitialPermissionLoad = false;

  List<AppPermissionAssignmentOption> buildPermissionOptions() {
    return currentPermissionLookups
        .map(
          (AccessAdminLookupOption option) => AppPermissionAssignmentOption(
            id: option.id,
            code: option.label,
            label: l10n.permissionCatalogLabelForCode(option.label),
            description: option.label,
          ),
        )
        .toList(growable: false);
  }

  Future<void> loadPermissionsForSelectedTenant(StateSetter setState) async {
    final String? resolvedTenantId = selectedTenantId;
    final RolePermissionLookupsLoader? loader = loadPermissionsForTenant;
    if (loader == null || (resolvedTenantId ?? '').isEmpty) {
      return;
    }

    setState(() {
      isLoadingPermissions = true;
      currentPermissionLookups = <AccessAdminLookupOption>[];
      selectedPermissionIds.clear();
    });

    final List<AccessAdminLookupOption> loaded =
        await loader(resolvedTenantId!);

    setState(() {
      isLoadingPermissions = false;
      permissionLoadAttempted = true;
      currentPermissionLookups = loaded;
    });
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(
      mode == RoleMutationMode.create
          ? l10n.accessAdminCreateRoleAction
          : l10n.accessAdminEditRoleAction,
    ),
    icon: Icon(
      mode == RoleMutationMode.create
          ? Icons.add_moderator_outlined
          : Icons.edit_outlined,
    ),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    cancelIcon: Icons.close_outlined,
    maxWidth: 840,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool isSubmitting, [
          AppFailure? failure,
        ]) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              final bool tenantSelected = (selectedTenantId ?? '').isNotEmpty;
              final bool fieldsEnabled =
                  !isSubmitting && (!showTenantPicker || tenantSelected);
              final List<AppPermissionAssignmentOption> permissionOptions =
                  buildPermissionOptions();

              if (loadPermissionsForTenant != null &&
                  tenantSelected &&
                  !permissionLoadAttempted &&
                  !isLoadingPermissions &&
                  !scheduledInitialPermissionLoad) {
                scheduledInitialPermissionLoad = true;
                unawaited(
                  loadPermissionsForSelectedTenant(setState),
                );
              }

              return AppFormSection(
                children: <Widget>[
                  if (showTenantPicker) ...<Widget>[
                    if (tenantOptions.isEmpty)
                      AppFormInformationBanner(
                        title: l10n.accessAdminTenantContextRequiredTitle,
                        message: l10n.tenantFacilitySelectTenantLoadError,
                        variant: AppFormInformationVariant.warning,
                        icon: Icons.apartment_outlined,
                      )
                    else
                      AppSelectField<String>.searchable(
                        value: selectedTenantId,
                        enabled: !isSubmitting,
                        labelText: l10n.tenantFacilitySelectTenantLabel,
                        isRequired: true,
                        menuHeight: 320,
                        options: tenantOptions
                            .map(
                              (AccessAdminLookupOption tenant) =>
                                  AppSelectOption<String>(
                                    value: tenant.id,
                                    label: tenant.label,
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (String? value) {
                          setState(() {
                            selectedTenantId = value;
                            permissionLoadAttempted = false;
                            scheduledInitialPermissionLoad = false;
                          });
                          if ((value ?? '').isEmpty) {
                            setState(() {
                              currentPermissionLookups =
                                  <AccessAdminLookupOption>[];
                            });
                            return;
                          }
                          unawaited(
                            loadPermissionsForSelectedTenant(setState),
                          );
                        },
                        validator: (String? value) =>
                            (value ?? '').trim().isEmpty
                            ? l10n.validationRequired
                            : null,
                      ),
                    SizedBox(height: Theme.of(context).spacing.md),
                  ],
                  AppTextField(
                    controller: nameController,
                    enabled: fieldsEnabled,
                    labelText: l10n.accessAdminRoleNameLabel,
                    isRequired: true,
                    validator: AppValidators.requiredText(
                      l10n.validationRequired,
                    ),
                  ),
                  AppTextField(
                    controller: descriptionController,
                    enabled: fieldsEnabled,
                    labelText: l10n.accessAdminRoleDescriptionLabel,
                    maxLines: 2,
                  ),
                  Text(
                    l10n.accessAdminRolePermissionsLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SizedBox(height: Theme.of(context).spacing.xs),
                  if (showTenantPicker && !tenantSelected)
                    AppFormInformationBanner(
                      title: l10n.accessAdminPermissionCatalogSelectTenantTitle,
                      message: l10n.accessAdminPermissionCatalogSelectTenantMessage,
                      icon: Icons.apartment_outlined,
                    )
                  else if (isLoadingPermissions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (permissionOptions.isEmpty)
                    AppFormInformationBanner(
                      title: l10n.accessAdminPermissionCatalogUnavailableTitle,
                      message: l10n.accessAdminPermissionCatalogUnavailableMessage,
                      variant: AppFormInformationVariant.warning,
                      icon: Icons.security_outlined,
                      children: loadPermissionsForTenant != null && tenantSelected
                          ? <Widget>[
                              AppButton.secondary(
                                label: l10n.commonRetryActionLabel,
                                enabled: !isSubmitting,
                                onPressed: () => unawaited(
                                  loadPermissionsForSelectedTenant(setState),
                                ),
                              ),
                            ]
                          : const <Widget>[],
                    )
                  else ...<Widget>[
                    AppPermissionAssignmentPicker(
                      permissions: permissionOptions,
                      selectedPermissionIds: selectedPermissionIds,
                      enabled: fieldsEnabled,
                      onSelectionChanged: fieldsEnabled
                          ? (Set<String> next) {
                              setState(() {
                                selectedPermissionIds
                                  ..clear()
                                  ..addAll(next);
                              });
                            }
                          : (_) {},
                    ),
                    if (selectedPermissionIds.isEmpty)
                      Text(
                        l10n.accessAdminRolePermissionsRequired,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ],
              );
            },
          );
        },
    onSubmit: () {
      final String? resolvedTenantId = selectedTenantId ?? tenantId;
      if (resolvedTenantId == null || resolvedTenantId.trim().isEmpty) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      if (currentPermissionLookups.isEmpty || selectedPermissionIds.isEmpty) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      return onSubmit(
        AccessAdminRoleDraft(
          tenantId: resolvedTenantId,
          facilityId: facilityId,
          name: nameController.text.trim().toUpperCase(),
          description: descriptionController.text.trim(),
          permissionIds: selectedPermissionIds.toList(growable: false),
        ),
      );
    },
  );

  nameController.dispose();
  descriptionController.dispose();
  return saved;
}

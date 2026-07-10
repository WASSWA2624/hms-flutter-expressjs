import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_mutation_dialog.dart';

enum RoleMutationMode { create, edit }

typedef RoleMutationSubmitHandler =
    Future<AppFailure?> Function(AccessAdminRoleDraft draft);

typedef RolePermissionLookupsLoader =
    Future<Result<List<AccessAdminLookupOption>>> Function(String tenantId);

typedef RoleTenantOptionsLoader =
    Future<List<AccessAdminLookupOption>> Function();

Future<bool?> showRoleMutationDialog({
  required BuildContext context,
  required RoleMutationMode mode,
  List<AccessAdminLookupOption> permissionLookups =
      const <AccessAdminLookupOption>[],
  RolePermissionLookupsLoader? loadPermissionsForTenant,
  RoleTenantOptionsLoader? loadTenantOptions,
  String? tenantId,
  String? facilityId,
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
      requireTenantPicker ||
      (mode == RoleMutationMode.create && tenantId == null);
  List<AccessAdminLookupOption> tenantOptions =
      const <AccessAdminLookupOption>[];
  bool isLoadingTenants = false;
  bool tenantLoadAttempted = false;
  bool scheduledInitialTenantLoad = false;
  List<AccessAdminLookupOption> currentPermissionLookups =
      List<AccessAdminLookupOption>.from(permissionLookups);
  bool isLoadingPermissions = false;
  bool permissionLoadAttempted = permissionLookups.isNotEmpty;
  bool scheduledInitialPermissionLoad = false;
  AppFailure? permissionLoadFailure;

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

  Future<void> reloadTenantOptions(StateSetter setState) async {
    final RoleTenantOptionsLoader? loader = loadTenantOptions;
    if (loader == null) {
      return;
    }

    setState(() {
      isLoadingTenants = true;
      tenantOptions = const <AccessAdminLookupOption>[];
    });

    final List<AccessAdminLookupOption> loaded = await loader();

    setState(() {
      isLoadingTenants = false;
      tenantLoadAttempted = true;
      tenantOptions = loaded;
    });
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
      permissionLoadFailure = null;
    });

    final Result<List<AccessAdminLookupOption>> loaded = await loader(
      resolvedTenantId!,
    );

    setState(() {
      isLoadingPermissions = false;
      permissionLoadAttempted = true;
      loaded.when(
        success: (List<AccessAdminLookupOption> permissions) {
          currentPermissionLookups = permissions;
          permissionLoadFailure = null;
        },
        failure: (AppFailure failure) {
          currentPermissionLookups = <AccessAdminLookupOption>[];
          permissionLoadFailure = failure;
        },
      );
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
    maxWidth: 920,
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

              if (loadTenantOptions != null &&
                  showTenantPicker &&
                  !tenantLoadAttempted &&
                  !isLoadingTenants &&
                  !scheduledInitialTenantLoad) {
                scheduledInitialTenantLoad = true;
                unawaited(reloadTenantOptions(setState));
              }

              if (loadPermissionsForTenant != null &&
                  tenantSelected &&
                  !permissionLoadAttempted &&
                  !isLoadingPermissions &&
                  !scheduledInitialPermissionLoad) {
                scheduledInitialPermissionLoad = true;
                unawaited(loadPermissionsForSelectedTenant(setState));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (mode == RoleMutationMode.create) ...<Widget>[
                    AppMessagePanel(
                      icon: Icons.lightbulb_outline,
                      message: l10n.accessAdminCreateRoleIntro,
                      density: AppContentPanelDensity.compact,
                    ),
                    SizedBox(height: Theme.of(context).spacing.md),
                  ],
                  if (showTenantPicker)
                    AppSectionPanel(
                      title: l10n.accessAdminCreateRoleScopeSectionTitle,
                      description:
                          l10n.accessAdminCreateRoleScopeSectionDescription,
                      leadingIcon: Icons.apartment_outlined,
                      tone: AppWorkspaceStatusTone.info,
                      children: <Widget>[
                        if (isLoadingTenants)
                          _RoleMutationLoadingIndicator(
                            label: l10n.accessAdminCreateRoleLoadingTenants,
                          )
                        else if (tenantOptions.isEmpty)
                          AppFormInformationBanner(
                            title: l10n.accessAdminTenantContextRequiredTitle,
                            message: l10n.tenantFacilitySelectTenantLoadError,
                            variant: AppFormInformationVariant.warning,
                            icon: Icons.apartment_outlined,
                            children: loadTenantOptions != null
                                ? <Widget>[
                                    AppButton.secondary(
                                      label: l10n.commonRetryActionLabel,
                                      enabled: !isSubmitting,
                                      onPressed: () {
                                        setState(() {
                                          tenantLoadAttempted = false;
                                          scheduledInitialTenantLoad = false;
                                        });
                                        unawaited(
                                          reloadTenantOptions(setState),
                                        );
                                      },
                                    ),
                                  ]
                                : const <Widget>[],
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
                      ],
                    ),
                  if (showTenantPicker)
                    SizedBox(height: Theme.of(context).spacing.md),
                  AppSectionPanel(
                    title: l10n.accessAdminCreateRoleDetailsSectionTitle,
                    description:
                        l10n.accessAdminCreateRoleDetailsSectionDescription,
                    leadingIcon: Icons.badge_outlined,
                    children: <Widget>[
                      AppResponsiveFieldRow.two(
                        gap: AppResponsiveFieldRowGap.form,
                        breakpoint: 720,
                        left: AppTextField(
                          controller: nameController,
                          enabled: fieldsEnabled,
                          labelText: l10n.accessAdminRoleNameLabel,
                          isRequired: true,
                          textCapitalization: TextCapitalization.characters,
                          validator: AppValidators.requiredText(
                            l10n.validationRequired,
                          ),
                        ),
                        right: AppTextField(
                          controller: descriptionController,
                          enabled: fieldsEnabled,
                          labelText: l10n.accessAdminRoleDescriptionLabel,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Theme.of(context).spacing.md),
                  AppSectionPanel(
                    title: l10n.accessAdminRolePermissionsLabel,
                    description:
                        l10n.accessAdminCreateRolePermissionsSectionDescription,
                    leadingIcon: Icons.security_outlined,
                    trailing: permissionOptions.isNotEmpty
                        ? _RoleMutationSelectionChip(
                            selectedCount: selectedPermissionIds.length,
                            totalCount: permissionOptions.length,
                          )
                        : null,
                    children: <Widget>[
                      if (showTenantPicker &&
                          !tenantSelected &&
                          !isLoadingTenants)
                        AppMessagePanel(
                          icon: Icons.touch_app_outlined,
                          title: l10n
                              .accessAdminPermissionCatalogSelectTenantTitle,
                          message: l10n
                              .accessAdminPermissionCatalogSelectTenantMessage,
                          density: AppContentPanelDensity.compact,
                        )
                      else if (isLoadingPermissions)
                        _RoleMutationLoadingIndicator(
                          label: l10n.accessAdminCreateRoleLoadingPermissions,
                        )
                      else if (permissionOptions.isEmpty &&
                          permissionLoadFailure != null)
                        AppFormInformationBanner.failure(
                          context: context,
                          failure: permissionLoadFailure!,
                          children:
                              loadPermissionsForTenant != null && tenantSelected
                              ? <Widget>[
                                  AppButton.secondary(
                                    label: l10n.commonRetryActionLabel,
                                    enabled: !isSubmitting,
                                    onPressed: () {
                                      setState(() {
                                        permissionLoadAttempted = false;
                                        scheduledInitialPermissionLoad = false;
                                        permissionLoadFailure = null;
                                      });
                                      unawaited(
                                        loadPermissionsForSelectedTenant(
                                          setState,
                                        ),
                                      );
                                    },
                                  ),
                                ]
                              : const <Widget>[],
                        )
                      else if (permissionOptions.isEmpty)
                        AppFormInformationBanner(
                          title:
                              l10n.accessAdminPermissionCatalogUnavailableTitle,
                          message: l10n
                              .accessAdminPermissionCatalogUnavailableMessage,
                          variant: AppFormInformationVariant.warning,
                          icon: Icons.security_outlined,
                          children:
                              loadPermissionsForTenant != null && tenantSelected
                              ? <Widget>[
                                  AppButton.secondary(
                                    label: l10n.commonRetryActionLabel,
                                    enabled: !isSubmitting,
                                    onPressed: () {
                                      setState(() {
                                        permissionLoadAttempted = false;
                                        scheduledInitialPermissionLoad = false;
                                      });
                                      unawaited(
                                        loadPermissionsForSelectedTenant(
                                          setState,
                                        ),
                                      );
                                    },
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                      ],
                    ],
                  ),
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

class _RoleMutationLoadingIndicator extends StatelessWidget {
  const _RoleMutationLoadingIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleMutationSelectionChip extends StatelessWidget {
  const _RoleMutationSelectionChip({
    required this.selectedCount,
    required this.totalCount,
  });

  final int selectedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool hasSelection = selectedCount > 0;

    return Chip(
      avatar: Icon(
        hasSelection
            ? Icons.check_circle_outline
            : Icons.radio_button_unchecked,
        size: 16,
        color: hasSelection ? colors.primary : colors.onSurfaceVariant,
      ),
      label: Text(
        context.l10n.hrPermissionAssignmentSelectedCount(
          selectedCount,
          totalCount,
        ),
        style: theme.textTheme.labelSmall,
      ),
      backgroundColor: hasSelection
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      side: BorderSide(
        color: hasSelection
            ? colors.primary.withValues(alpha: 0.24)
            : colors.outlineVariant,
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
    );
  }
}

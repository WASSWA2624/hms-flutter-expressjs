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
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_mutation_dialog.dart';

enum RoleMutationMode { create, edit }

enum RoleScopeKind { tenant, facility }

typedef RoleMutationSubmitHandler =
    Future<AppFailure?> Function(AccessAdminRoleDraft draft);

typedef RolePermissionLookupsLoader =
    Future<Result<List<AccessAdminLookupOption>>> Function({
      required String tenantId,
      String? facilityId,
    });

typedef RoleTenantOptionsLoader =
    Future<List<AccessAdminLookupOption>> Function();

typedef RoleFacilityOptionsLoader =
    Future<List<AccessAdminLookupOption>> Function(String tenantId);

Future<bool?> showRoleMutationDialog({
  required BuildContext context,
  required RoleMutationMode mode,
  List<AccessAdminLookupOption> permissionLookups =
      const <AccessAdminLookupOption>[],
  List<AccessAdminLookupOption> initialFacilityOptions =
      const <AccessAdminLookupOption>[],
  RolePermissionLookupsLoader? loadPermissionsForTenant,
  RoleTenantOptionsLoader? loadTenantOptions,
  RoleFacilityOptionsLoader? loadFacilityOptions,
  String? tenantId,
  String? facilityId,
  bool requireTenantPicker = false,
  bool allowTenantWideScope = true,
  bool forceFacilityScope = false,
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
  String? selectedFacilityId = facilityId;
  final bool showTenantPicker =
      requireTenantPicker ||
      (mode == RoleMutationMode.create && tenantId == null);
  final bool lockedFacilityScope = forceFacilityScope || !allowTenantWideScope;
  RoleScopeKind scopeKind = lockedFacilityScope || (facilityId ?? '').isNotEmpty
      ? RoleScopeKind.facility
      : RoleScopeKind.tenant;

  List<AccessAdminLookupOption> tenantOptions =
      const <AccessAdminLookupOption>[];
  bool isLoadingTenants = false;
  bool tenantLoadAttempted = false;
  bool scheduledInitialTenantLoad = false;

  List<AccessAdminLookupOption> facilityOptions =
      List<AccessAdminLookupOption>.from(initialFacilityOptions);
  bool isLoadingFacilities = false;
  bool facilityLoadAttempted = initialFacilityOptions.isNotEmpty;
  bool scheduledInitialFacilityLoad = false;

  if ((selectedFacilityId ?? '').isEmpty && facilityOptions.length == 1) {
    selectedFacilityId = facilityOptions.first.id;
  }

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

  Future<void> reloadFacilityOptions(StateSetter setState) async {
    final RoleFacilityOptionsLoader? loader = loadFacilityOptions;
    final String? resolvedTenantId = selectedTenantId;
    if (loader == null || (resolvedTenantId ?? '').isEmpty) {
      setState(() {
        facilityOptions = const <AccessAdminLookupOption>[];
        facilityLoadAttempted = true;
        isLoadingFacilities = false;
      });
      return;
    }

    setState(() {
      isLoadingFacilities = true;
      facilityOptions = const <AccessAdminLookupOption>[];
    });

    final List<AccessAdminLookupOption> loaded = await loader(resolvedTenantId!);

    setState(() {
      isLoadingFacilities = false;
      facilityLoadAttempted = true;
      facilityOptions = loaded;
      if ((selectedFacilityId ?? '').isNotEmpty &&
          loaded.every(
            (AccessAdminLookupOption option) => option.id != selectedFacilityId,
          )) {
        selectedFacilityId = null;
      }
      if ((selectedFacilityId ?? '').isEmpty && loaded.length == 1) {
        selectedFacilityId = loaded.first.id;
      }
    });
  }

  Future<void> loadPermissionsForScope(StateSetter setState) async {
    final String? resolvedTenantId = selectedTenantId;
    final RolePermissionLookupsLoader? loader = loadPermissionsForTenant;
    if (loader == null || (resolvedTenantId ?? '').isEmpty) {
      return;
    }

    final String? scopeFacilityId = scopeKind == RoleScopeKind.facility
        ? selectedFacilityId
        : null;
    final bool preserveSelection =
        mode == RoleMutationMode.edit && !permissionLoadAttempted;

    setState(() {
      isLoadingPermissions = true;
      currentPermissionLookups = <AccessAdminLookupOption>[];
      if (!preserveSelection) {
        selectedPermissionIds.clear();
      }
      permissionLoadFailure = null;
    });

    final Result<List<AccessAdminLookupOption>> loaded = await loader(
      tenantId: resolvedTenantId!,
      facilityId: scopeFacilityId,
    );

    setState(() {
      isLoadingPermissions = false;
      permissionLoadAttempted = true;
      loaded.when(
        success: (List<AccessAdminLookupOption> permissions) {
          currentPermissionLookups = permissions;
          permissionLoadFailure = null;
          if (preserveSelection) {
            final Set<String> lookupIds = permissions
                .map((AccessAdminLookupOption option) => option.id)
                .toSet();
            final Map<String, String> idByLabel = <String, String>{
              for (final AccessAdminLookupOption option in permissions)
                option.label: option.id,
            };
            final Set<String> remapped = <String>{};
            for (final String selected in selectedPermissionIds) {
              if (lookupIds.contains(selected)) {
                remapped.add(selected);
                continue;
              }
              final String? byLabel = idByLabel[selected];
              if (byLabel != null) {
                remapped.add(byLabel);
              }
            }
            selectedPermissionIds
              ..clear()
              ..addAll(remapped);
          }
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
    maxWidth: 760,
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
              final bool facilitySelected =
                  (selectedFacilityId ?? '').isNotEmpty;
              final bool scopeReady =
                  tenantSelected &&
                  (scopeKind == RoleScopeKind.tenant || facilitySelected);
              final bool fieldsEnabled = !isSubmitting && scopeReady;
              final List<AppPermissionAssignmentOption> permissionOptions =
                  buildPermissionOptions();
              final ThemeData theme = Theme.of(context);

              if (loadTenantOptions != null &&
                  showTenantPicker &&
                  !tenantLoadAttempted &&
                  !isLoadingTenants &&
                  !scheduledInitialTenantLoad) {
                scheduledInitialTenantLoad = true;
                unawaited(reloadTenantOptions(setState));
              }

              final bool shouldLoadFacilities =
                  scopeKind == RoleScopeKind.facility &&
                  loadFacilityOptions != null &&
                  tenantSelected &&
                  !facilityLoadAttempted &&
                  !isLoadingFacilities &&
                  !scheduledInitialFacilityLoad;
              final bool shouldLoadPermissions =
                  loadPermissionsForTenant != null &&
                  scopeReady &&
                  !permissionLoadAttempted &&
                  !isLoadingPermissions &&
                  !scheduledInitialPermissionLoad;

              if (shouldLoadFacilities && shouldLoadPermissions) {
                scheduledInitialFacilityLoad = true;
                scheduledInitialPermissionLoad = true;
                unawaited(() async {
                  await Future.wait(<Future<void>>[
                    reloadFacilityOptions(setState),
                    loadPermissionsForScope(setState),
                  ]);
                }());
              } else {
                if (shouldLoadFacilities) {
                  scheduledInitialFacilityLoad = true;
                  unawaited(reloadFacilityOptions(setState));
                }
                if (shouldLoadPermissions) {
                  scheduledInitialPermissionLoad = true;
                  unawaited(loadPermissionsForScope(setState));
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppFormSection(
                    density: AppFormSectionDensity.compact,
                    title: l10n.accessAdminRoleScopeLabel,
                    children: <Widget>[
                      if (showTenantPicker) ...<Widget>[
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
                            menuHeight: 280,
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
                                selectedFacilityId = null;
                                facilityLoadAttempted = false;
                                scheduledInitialFacilityLoad = false;
                                permissionLoadAttempted = false;
                                scheduledInitialPermissionLoad = false;
                                currentPermissionLookups =
                                    <AccessAdminLookupOption>[];
                                selectedPermissionIds.clear();
                              });
                            },
                            validator: (String? value) =>
                                (value ?? '').trim().isEmpty
                                ? l10n.validationRequired
                                : null,
                          ),
                        SizedBox(height: theme.spacing.sm),
                      ],
                      SegmentedButton<RoleScopeKind>(
                        segments: <ButtonSegment<RoleScopeKind>>[
                          ButtonSegment<RoleScopeKind>(
                            value: RoleScopeKind.tenant,
                            enabled: !lockedFacilityScope && !isSubmitting,
                            label: Text(l10n.accessAdminRoleScopeTenantLabel),
                            icon: const Icon(Icons.domain_outlined, size: 18),
                          ),
                          ButtonSegment<RoleScopeKind>(
                            value: RoleScopeKind.facility,
                            enabled: !isSubmitting,
                            label: Text(l10n.accessAdminRoleScopeFacilityLabel),
                            icon: const Icon(
                              Icons.local_hospital_outlined,
                              size: 18,
                            ),
                          ),
                        ],
                        selected: <RoleScopeKind>{scopeKind},
                        onSelectionChanged: lockedFacilityScope || isSubmitting
                            ? null
                            : (Set<RoleScopeKind> next) {
                                if (next.isEmpty) {
                                  return;
                                }
                                setState(() {
                                  scopeKind = next.first;
                                  if (scopeKind == RoleScopeKind.tenant) {
                                    selectedFacilityId = null;
                                  }
                                  facilityLoadAttempted = false;
                                  scheduledInitialFacilityLoad = false;
                                  permissionLoadAttempted = false;
                                  scheduledInitialPermissionLoad = false;
                                  currentPermissionLookups =
                                      <AccessAdminLookupOption>[];
                                  selectedPermissionIds.clear();
                                });
                              },
                      ),
                      if (scopeKind == RoleScopeKind.facility) ...<Widget>[
                        SizedBox(height: theme.spacing.sm),
                        if (!tenantSelected)
                          AppMessagePanel(
                            icon: Icons.touch_app_outlined,
                            message: l10n
                                .accessAdminPermissionCatalogSelectTenantMessage,
                            density: AppContentPanelDensity.compact,
                          )
                        else if (isLoadingFacilities)
                          _RoleMutationLoadingIndicator(
                            label: l10n.accessAdminCreateRoleLoadingFacilities,
                          )
                        else if (facilityOptions.isEmpty)
                          AppFormInformationBanner(
                            title: l10n.accessAdminRoleFacilityRequiredTitle,
                            message:
                                l10n.accessAdminRoleFacilityRequiredMessage,
                            variant: AppFormInformationVariant.warning,
                            icon: Icons.local_hospital_outlined,
                            children: loadFacilityOptions != null
                                ? <Widget>[
                                    AppButton.secondary(
                                      label: l10n.commonRetryActionLabel,
                                      enabled: !isSubmitting,
                                      onPressed: () {
                                        setState(() {
                                          facilityLoadAttempted = false;
                                          scheduledInitialFacilityLoad = false;
                                        });
                                        unawaited(
                                          reloadFacilityOptions(setState),
                                        );
                                      },
                                    ),
                                  ]
                                : const <Widget>[],
                          )
                        else
                          AppSelectField<String>.searchable(
                            value: selectedFacilityId,
                            enabled: !isSubmitting,
                            labelText: l10n.tenantFacilityFacilitySelectLabel,
                            isRequired: true,
                            menuHeight: 280,
                            options: facilityOptions
                                .map(
                                  (AccessAdminLookupOption facility) =>
                                      AppSelectOption<String>(
                                        value: facility.id,
                                        label: facility.label,
                                      ),
                                )
                                .toList(growable: false),
                            onChanged: (String? value) {
                              setState(() {
                                selectedFacilityId = value;
                                permissionLoadAttempted = false;
                                scheduledInitialPermissionLoad = false;
                                currentPermissionLookups =
                                    <AccessAdminLookupOption>[];
                                selectedPermissionIds.clear();
                              });
                            },
                            validator: (String? value) =>
                                (value ?? '').trim().isEmpty
                                ? l10n.validationRequired
                                : null,
                          ),
                      ],
                    ],
                  ),
                  SizedBox(height: theme.spacing.md),
                  AppFormSection(
                    density: AppFormSectionDensity.compact,
                    title: l10n.accessAdminCreateRoleDetailsSectionTitle,
                    children: <Widget>[
                      AppResponsiveFieldRow.two(
                        gap: AppResponsiveFieldRowGap.form,
                        breakpoint: 640,
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
                  SizedBox(height: theme.spacing.md),
                  AppFormSection(
                    density: AppFormSectionDensity.compact,
                    title: l10n.accessAdminRolePermissionsLabel,
                    children: <Widget>[
                      if (!scopeReady && !isLoadingPermissions)
                        AppMessagePanel(
                          icon: Icons.touch_app_outlined,
                          message: scopeKind == RoleScopeKind.facility
                              ? l10n.accessAdminRoleSelectFacilityMessage
                              : l10n
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
                              loadPermissionsForTenant != null && scopeReady
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
                                        loadPermissionsForScope(setState),
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
                              loadPermissionsForTenant != null && scopeReady
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
                                        loadPermissionsForScope(setState),
                                      );
                                    },
                                  ),
                                ]
                              : const <Widget>[],
                        )
                      else ...<Widget>[
                        Align(
                          alignment: Alignment.centerRight,
                          child: _RoleMutationSelectionChip(
                            selectedCount: selectedPermissionIds.length,
                            totalCount: permissionOptions.length,
                          ),
                        ),
                        SizedBox(height: theme.spacing.xs),
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
                          Padding(
                            padding: EdgeInsets.only(top: theme.spacing.xs),
                            child: Text(
                              l10n.accessAdminRolePermissionsRequired,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
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
      if (scopeKind == RoleScopeKind.facility &&
          (selectedFacilityId == null || selectedFacilityId!.trim().isEmpty)) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      if (currentPermissionLookups.isEmpty || selectedPermissionIds.isEmpty) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      return onSubmit(
        AccessAdminRoleDraft(
          tenantId: resolvedTenantId,
          facilityId: scopeKind == RoleScopeKind.facility
              ? selectedFacilityId
              : null,
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
      padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
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

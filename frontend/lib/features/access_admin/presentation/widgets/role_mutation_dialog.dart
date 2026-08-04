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
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_mutation_dialog.dart';

enum RoleMutationMode { create, edit }

/// Shared create/edit scope radios (RBAC/ABAC: platform | tenant | facility).
enum RoleCreateScopeKind { platform, tenants, facilities }

typedef RoleMutationSubmitHandler =
    Future<AppFailure?> Function(List<AccessAdminRoleDraft> drafts);

typedef RolePermissionLookupsLoader =
    Future<Result<List<AccessAdminLookupOption>>> Function({
      required String tenantId,
      String? facilityId,
    });

typedef RoleTenantOptionsLoader =
    Future<List<AccessAdminLookupOption>> Function();

typedef RoleFacilityOptionsLoader =
    Future<List<AccessAdminLookupOption>> Function(String tenantId);

typedef RoleAllFacilityOptionsLoader =
    Future<List<AccessAdminLookupOption>> Function();

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
  RoleAllFacilityOptionsLoader? loadAllFacilityOptions,
  String? tenantId,
  String? facilityId,
  bool allowTenantWideScope = true,
  bool forceFacilityScope = false,
  bool allowPlatformScope = false,
  bool allowTenantScope = true,
  bool allowFacilityScope = true,
  bool? includePermissions,
  String? initialName,
  String? initialDisplayName,
  String? initialDescription,
  Set<String> initialPermissionIds = const <String>{},
  required RoleMutationSubmitHandler onSubmit,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool showPermissions = includePermissions ?? false;
  final TextEditingController nameController = TextEditingController(
    text: initialName,
  );
  final TextEditingController displayNameController = TextEditingController(
    text: initialDisplayName,
  );
  final TextEditingController descriptionController = TextEditingController(
    text: initialDescription,
  );
  final Set<String> selectedPermissionIds = Set<String>.from(
    initialPermissionIds,
  );
  String? selectedTenantId = tenantId;
  String? selectedFacilityId = facilityId;
  final bool lockedFacilityScope = forceFacilityScope || !allowTenantWideScope;

  final bool canPlatform = allowPlatformScope && !lockedFacilityScope;
  final bool canTenants = allowTenantScope && !lockedFacilityScope;
  final bool canFacilities = allowFacilityScope;

  // Edit prefills from the role's actual ABAC scope; create defaults to the
  // broadest allowed option (platform → tenants → facilities).
  final RoleCreateScopeKind createScopeKindInitial;
  if (mode == RoleMutationMode.edit) {
    if ((facilityId ?? '').trim().isNotEmpty) {
      createScopeKindInitial = RoleCreateScopeKind.facilities;
    } else if ((tenantId ?? '').trim().isNotEmpty) {
      createScopeKindInitial = RoleCreateScopeKind.tenants;
    } else if (canPlatform) {
      createScopeKindInitial = RoleCreateScopeKind.platform;
    } else if (canTenants) {
      createScopeKindInitial = RoleCreateScopeKind.tenants;
    } else {
      createScopeKindInitial = RoleCreateScopeKind.facilities;
    }
  } else {
    createScopeKindInitial = canPlatform
        ? RoleCreateScopeKind.platform
        : (canTenants
              ? RoleCreateScopeKind.tenants
              : RoleCreateScopeKind.facilities);
  }
  RoleCreateScopeKind createScopeKind = createScopeKindInitial;

  final Set<String> selectedTenantIds = <String>{
    if ((tenantId ?? '').isNotEmpty &&
        createScopeKind == RoleCreateScopeKind.tenants)
      tenantId!,
  };
  final Set<String> selectedFacilityIds = <String>{
    if ((facilityId ?? '').isNotEmpty &&
        createScopeKind == RoleCreateScopeKind.facilities)
      facilityId!,
  };
  bool reinforceIdentityGuidance = false;

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
  if (selectedFacilityIds.isEmpty &&
      facilityOptions.length == 1 &&
      createScopeKind == RoleCreateScopeKind.facilities) {
    selectedFacilityIds.add(facilityOptions.first.id);
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
            label: l10n.permissionAssignmentLabelForCode(
              option.label,
              displayName: option.displayName,
            ),
            description:
                (option.meta ?? '').trim().isNotEmpty
                    ? option.meta
                    : l10n.permissionCatalogDescriptionForCode(option.label),
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
      if (selectedTenantIds.isNotEmpty) {
        selectedTenantIds.removeWhere(
          (String id) =>
              loaded.every((AccessAdminLookupOption o) => o.id != id),
        );
      }
      if (mode == RoleMutationMode.create &&
          createScopeKind == RoleCreateScopeKind.tenants &&
          selectedTenantIds.isEmpty &&
          loaded.length == 1) {
        selectedTenantIds.add(loaded.first.id);
      }
      if (mode == RoleMutationMode.edit &&
          createScopeKind == RoleCreateScopeKind.tenants &&
          selectedTenantIds.isEmpty &&
          loaded.length == 1) {
        selectedTenantIds.add(loaded.first.id);
      }
    });
  }

  Future<void> reloadFacilityOptions(StateSetter setState) async {
    final RoleAllFacilityOptionsLoader? allLoader = loadAllFacilityOptions;
    final RoleFacilityOptionsLoader? loader = loadFacilityOptions;

    if (createScopeKind == RoleCreateScopeKind.facilities &&
        allLoader != null) {
      setState(() {
        isLoadingFacilities = true;
        facilityOptions = const <AccessAdminLookupOption>[];
      });
      final List<AccessAdminLookupOption> loaded = await allLoader();
      setState(() {
        isLoadingFacilities = false;
        facilityLoadAttempted = true;
        facilityOptions = loaded;
        selectedFacilityIds.removeWhere(
          (String id) =>
              loaded.every((AccessAdminLookupOption o) => o.id != id),
        );
        if (selectedFacilityIds.isEmpty && loaded.length == 1) {
          selectedFacilityIds.add(loaded.first.id);
        }
      });
      return;
    }

    final String? resolvedTenantId = selectedTenantIds.length == 1
        ? selectedTenantIds.first
        : selectedTenantId ?? tenantId;
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

    final List<AccessAdminLookupOption> loaded = await loader(
      resolvedTenantId!,
    );

    setState(() {
      isLoadingFacilities = false;
      facilityLoadAttempted = true;
      facilityOptions = loaded;
      selectedFacilityIds.removeWhere(
        (String id) =>
            loaded.every((AccessAdminLookupOption o) => o.id != id),
      );
      if (selectedFacilityIds.isEmpty && loaded.length == 1) {
        selectedFacilityIds.add(loaded.first.id);
      }
      if ((selectedFacilityId ?? '').isNotEmpty &&
          loaded.every(
            (AccessAdminLookupOption option) =>
                option.id != selectedFacilityId,
          )) {
        selectedFacilityId = null;
      }
      if ((selectedFacilityId ?? '').isEmpty &&
          selectedFacilityIds.length == 1) {
        selectedFacilityId = selectedFacilityIds.first;
      } else if ((selectedFacilityId ?? '').isEmpty && loaded.length == 1) {
        selectedFacilityId = loaded.first.id;
      }
    });
  }

  Future<void> loadPermissionsForScope(StateSetter setState) async {
    final String? resolvedTenantId =
        selectedTenantIds.length == 1
        ? selectedTenantIds.first
        : selectedTenantId ?? tenantId;
    final RolePermissionLookupsLoader? loader = loadPermissionsForTenant;
    if (loader == null || (resolvedTenantId ?? '').isEmpty) {
      return;
    }

    final String? scopeFacilityId =
        createScopeKind == RoleCreateScopeKind.facilities
        ? (selectedFacilityIds.length == 1
              ? selectedFacilityIds.first
              : selectedFacilityId)
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
                continue;
              }
              // Keep unresolved ids so a later catalog refresh can still match.
              remapped.add(selected);
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
              final bool isCreate = mode == RoleMutationMode.create;
              final bool scopeReady = switch (createScopeKind) {
                RoleCreateScopeKind.platform => true,
                RoleCreateScopeKind.tenants => selectedTenantIds.isNotEmpty,
                RoleCreateScopeKind.facilities =>
                  selectedFacilityIds.isNotEmpty,
              };
              final bool fieldsEnabled = !isSubmitting && scopeReady;
              final List<AppPermissionAssignmentOption> permissionOptions =
                  buildPermissionOptions();
              final ThemeData theme = Theme.of(context);

              final bool shouldLoadTenants =
                  loadTenantOptions != null &&
                  !tenantLoadAttempted &&
                  !isLoadingTenants &&
                  !scheduledInitialTenantLoad &&
                  (createScopeKind == RoleCreateScopeKind.tenants ||
                      (createScopeKind == RoleCreateScopeKind.facilities &&
                          loadAllFacilityOptions == null));
              if (shouldLoadTenants) {
                scheduledInitialTenantLoad = true;
                unawaited(reloadTenantOptions(setState));
              }

              final String? createFacilityTenantId =
                  selectedTenantIds.length == 1
                  ? selectedTenantIds.first
                  : (selectedTenantId ?? tenantId);
              final bool shouldLoadFacilities =
                  createScopeKind == RoleCreateScopeKind.facilities &&
                  !facilityLoadAttempted &&
                  !isLoadingFacilities &&
                  !scheduledInitialFacilityLoad &&
                  (loadAllFacilityOptions != null ||
                      (loadFacilityOptions != null &&
                          (createFacilityTenantId ?? '').isNotEmpty));
              final bool shouldLoadPermissions =
                  showPermissions &&
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

              final List<AppRadioOption<RoleCreateScopeKind>> createScopeOptions =
                  <AppRadioOption<RoleCreateScopeKind>>[
                    if (canPlatform)
                      AppRadioOption<RoleCreateScopeKind>(
                        value: RoleCreateScopeKind.platform,
                        label: l10n.accessAdminRoleScopePlatformLabel,
                      ),
                    if (canTenants)
                      AppRadioOption<RoleCreateScopeKind>(
                        value: RoleCreateScopeKind.tenants,
                        label: l10n.accessAdminRoleScopeTenantsLabel,
                      ),
                    if (canFacilities)
                      AppRadioOption<RoleCreateScopeKind>(
                        value: RoleCreateScopeKind.facilities,
                        label: l10n.accessAdminRoleScopeFacilitiesLabel,
                      ),
                  ];

              final String identityGuidanceMessage = switch (createScopeKind) {
                RoleCreateScopeKind.tenants =>
                  l10n.accessAdminRoleIdentityBlockedSelectTenants,
                RoleCreateScopeKind.facilities =>
                  l10n.accessAdminRoleIdentityBlockedSelectFacilities,
                RoleCreateScopeKind.platform =>
                  l10n.accessAdminRoleIdentityBlockedSelectScope,
              };

              void onCreateScopeChanged(RoleCreateScopeKind next) {
                setState(() {
                  createScopeKind = next;
                  reinforceIdentityGuidance = false;
                  tenantLoadAttempted = false;
                  scheduledInitialTenantLoad = false;
                  facilityLoadAttempted = false;
                  scheduledInitialFacilityLoad = false;
                  if (next != RoleCreateScopeKind.tenants) {
                    selectedTenantIds.clear();
                  }
                  if (next != RoleCreateScopeKind.facilities) {
                    selectedFacilityIds.clear();
                    facilityOptions = List<AccessAdminLookupOption>.from(
                      initialFacilityOptions,
                    );
                  }
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppFormSection(
                    density: AppFormSectionDensity.compact,
                    title: l10n.accessAdminRoleScopeLabel,
                    children: <Widget>[
                      if (createScopeOptions.length <= 1)
                        Text(
                          createScopeOptions.isEmpty
                              ? l10n.accessAdminRoleScopeLabel
                              : createScopeOptions.first.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: AppFontWeight.emphasis,
                          ),
                        )
                      else
                        AppRadioGroup<RoleCreateScopeKind>(
                          value: createScopeKind,
                          enabled: !isSubmitting,
                          layout: AppRadioGroupLayout.wrap,
                          wrapColumns: 3,
                          itemMinWidth: 160,
                          options: createScopeOptions,
                          onChanged: isSubmitting
                              ? null
                              : (RoleCreateScopeKind? value) {
                                  if (value == null) {
                                    return;
                                  }
                                  onCreateScopeChanged(value);
                                },
                        ),
                      if (createScopeKind ==
                          RoleCreateScopeKind.tenants) ...<Widget>[
                        SizedBox(height: theme.spacing.sm),
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
                          _RoleTargetMultiSelect(
                            label: l10n.accessAdminRoleSelectTenantsLabel,
                            options: tenantOptions,
                            selectedIds: selectedTenantIds,
                            enabled: !isSubmitting,
                            emptySelectionError: selectedTenantIds.isEmpty
                                ? l10n.accessAdminRoleTargetsRequired
                                : null,
                            onChanged: (Set<String> next) {
                              setState(() {
                                final Set<String> resolved =
                                    !isCreate && next.length > 1
                                    ? <String>{next.last}
                                    : next;
                                selectedTenantIds
                                  ..clear()
                                  ..addAll(resolved);
                                selectedTenantId =
                                    selectedTenantIds.length == 1
                                    ? selectedTenantIds.first
                                    : null;
                                reinforceIdentityGuidance = false;
                              });
                            },
                          ),
                      ],
                      if (createScopeKind ==
                          RoleCreateScopeKind.facilities) ...<Widget>[
                        SizedBox(height: theme.spacing.sm),
                        if (isLoadingFacilities)
                          _RoleMutationLoadingIndicator(
                            label:
                                l10n.accessAdminCreateRoleLoadingFacilities,
                          )
                        else if (facilityOptions.isEmpty)
                          AppFormInformationBanner(
                            title: l10n.accessAdminRoleFacilityRequiredTitle,
                            message:
                                l10n.accessAdminRoleFacilityRequiredMessage,
                            variant: AppFormInformationVariant.warning,
                            icon: Icons.local_hospital_outlined,
                            children:
                                loadAllFacilityOptions != null ||
                                    loadFacilityOptions != null
                                ? <Widget>[
                                    AppButton.secondary(
                                      label: l10n.commonRetryActionLabel,
                                      enabled: !isSubmitting,
                                      onPressed: () {
                                        setState(() {
                                          facilityLoadAttempted = false;
                                          scheduledInitialFacilityLoad =
                                              false;
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
                          _RoleTargetMultiSelect(
                            label: l10n.accessAdminRoleSelectFacilitiesLabel,
                            options: facilityOptions,
                            selectedIds: selectedFacilityIds,
                            enabled: !isSubmitting,
                            emptySelectionError: selectedFacilityIds.isEmpty
                                ? l10n.accessAdminRoleTargetsRequired
                                : null,
                            onChanged: (Set<String> next) {
                              setState(() {
                                final Set<String> resolved =
                                    !isCreate && next.length > 1
                                    ? <String>{next.last}
                                    : next;
                                selectedFacilityIds
                                  ..clear()
                                  ..addAll(resolved);
                                selectedFacilityId =
                                    selectedFacilityIds.length == 1
                                    ? selectedFacilityIds.first
                                    : null;
                                reinforceIdentityGuidance = false;
                              });
                            },
                          ),
                      ],
                    ],
                  ),
                  SizedBox(height: theme.spacing.md),
                  AppFormSection(
                    density: AppFormSectionDensity.compact,
                    title: l10n.accessAdminCreateRoleDetailsSectionTitle,
                    children: <Widget>[
                      if (!scopeReady || reinforceIdentityGuidance) ...<Widget>[
                        AppMessagePanel(
                          icon: reinforceIdentityGuidance && !scopeReady
                              ? Icons.warning_amber_outlined
                              : Icons.touch_app_outlined,
                          message: identityGuidanceMessage,
                          tone: reinforceIdentityGuidance && !scopeReady
                              ? AppWorkspaceStatusTone.warning
                              : AppWorkspaceStatusTone.info,
                          density: AppContentPanelDensity.compact,
                        ),
                        SizedBox(height: theme.spacing.sm),
                      ],
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: fieldsEnabled
                            ? null
                            : () {
                                setState(() {
                                  reinforceIdentityGuidance = true;
                                });
                              },
                        child: IgnorePointer(
                          ignoring: !fieldsEnabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              AppResponsiveFieldRow.two(
                                gap: AppResponsiveFieldRowGap.form,
                                breakpoint: 640,
                                left: AppTextField(
                                  controller: nameController,
                                  enabled: fieldsEnabled,
                                  labelText: l10n.accessAdminRoleNameLabel,
                                  isRequired: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  validator: AppValidators.requiredText(
                                    l10n.validationRequired,
                                  ),
                                ),
                                right: AppTextField(
                                  controller: displayNameController,
                                  enabled: fieldsEnabled,
                                  labelText:
                                      l10n.accessAdminRoleDisplayNameLabel,
                                  isRequired: true,
                                  textCapitalization: TextCapitalization.words,
                                  validator: AppValidators.requiredText(
                                    l10n.validationRequired,
                                  ),
                                ),
                              ),
                              SizedBox(height: theme.spacing.sm),
                              AppTextField(
                                controller: descriptionController,
                                enabled: fieldsEnabled,
                                labelText: l10n.accessAdminRoleDescriptionLabel,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showPermissions) ...<Widget>[
                    SizedBox(height: theme.spacing.md),
                    AppFormSection(
                      density: AppFormSectionDensity.compact,
                      title: l10n.accessAdminRolePermissionsLabel,
                      children: <Widget>[
                        if (!scopeReady && !isLoadingPermissions)
                          AppMessagePanel(
                            icon: Icons.touch_app_outlined,
                            message: createScopeKind == RoleCreateScopeKind.facilities
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
                                          scheduledInitialPermissionLoad =
                                              false;
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
                            title: l10n
                                .accessAdminPermissionCatalogUnavailableTitle,
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
                                          scheduledInitialPermissionLoad =
                                              false;
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
                ],
              );
            },
          );
        },
    onSubmit: () {
      final String displayName = displayNameController.text.trim();
      if (displayName.isEmpty) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      if (showPermissions &&
          (currentPermissionLookups.isEmpty ||
              selectedPermissionIds.isEmpty)) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }

      final String name = nameController.text.trim().toUpperCase();
      final String? description = descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim();
      final List<String> permissionIds = showPermissions
          ? selectedPermissionIds.toList(growable: false)
          : const <String>[];
      // Create may send an empty permission set; edit without the permissions
      // UI must not sync (would wipe existing grants).
      final bool syncPermissions =
          showPermissions || mode == RoleMutationMode.create;

      List<AccessAdminRoleDraft> draftsForScope() {
        switch (createScopeKind) {
          case RoleCreateScopeKind.platform:
            return <AccessAdminRoleDraft>[
              AccessAdminRoleDraft(
                name: name,
                displayName: displayName,
                description: description,
                permissionIds: permissionIds,
                syncPermissions: syncPermissions,
                scope: 'platform',
              ),
            ];
          case RoleCreateScopeKind.tenants:
            if (selectedTenantIds.isEmpty) {
              return const <AccessAdminRoleDraft>[];
            }
            final Iterable<String> targets = mode == RoleMutationMode.edit
                ? <String>[selectedTenantIds.first]
                : selectedTenantIds;
            return <AccessAdminRoleDraft>[
              for (final String id in targets)
                AccessAdminRoleDraft(
                  tenantId: id,
                  name: name,
                  displayName: displayName,
                  description: description,
                  permissionIds: permissionIds,
                  syncPermissions: syncPermissions,
                  scope: 'tenant',
                ),
            ];
          case RoleCreateScopeKind.facilities:
            if (selectedFacilityIds.isEmpty) {
              return const <AccessAdminRoleDraft>[];
            }
            final Iterable<String> targets = mode == RoleMutationMode.edit
                ? <String>[selectedFacilityIds.first]
                : selectedFacilityIds;
            return <AccessAdminRoleDraft>[
              for (final String id in targets)
                AccessAdminRoleDraft(
                  tenantId:
                      facilityOptions
                          .where(
                            (AccessAdminLookupOption option) => option.id == id,
                          )
                          .map(
                            (AccessAdminLookupOption option) => option.meta,
                          )
                          .firstOrNull ??
                      tenantId ??
                      selectedTenantId,
                  facilityId: id,
                  name: name,
                  displayName: displayName,
                  description: description,
                  permissionIds: permissionIds,
                  syncPermissions: syncPermissions,
                  scope: 'facility',
                ),
            ];
        }
      }

      final List<AccessAdminRoleDraft> drafts = draftsForScope();
      if (drafts.isEmpty) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      return onSubmit(drafts);
    },
  );

  nameController.dispose();
  displayNameController.dispose();
  descriptionController.dispose();
  return saved;
}

class _RoleTargetMultiSelect extends StatelessWidget {
  const _RoleTargetMultiSelect({
    required this.label,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    required this.enabled,
    this.emptySelectionError,
  });

  final String label;
  final List<AccessAdminLookupOption> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;
  final String? emptySelectionError;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Plain label + list — must not wrap in [AppFormSection] (nested section
    // inside the scope [AppFormSection] on the Roles create/edit dialog).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: Material(
            color: theme.colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.radius.md),
              side: theme.borders.side(),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (BuildContext context, int index) {
                final AccessAdminLookupOption option = options[index];
                final bool selected = selectedIds.contains(option.id);
                return CheckboxListTile(
                  value: selected,
                  enabled: enabled,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(option.label),
                  onChanged: enabled
                      ? (bool? checked) {
                          final Set<String> next = Set<String>.from(
                            selectedIds,
                          );
                          if (checked ?? false) {
                            next.add(option.id);
                          } else {
                            next.remove(option.id);
                          }
                          onChanged(next);
                        }
                      : null,
                );
              },
            ),
          ),
        ),
        if (emptySelectionError != null)
          AppFieldErrorText(errorText: emptySelectionError),
      ],
    );
  }
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
      side: theme.borders.side(
        color: hasSelection
            ? colors.primary.withValues(alpha: 0.24)
            : theme.borders.subtle,
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
    );
  }
}

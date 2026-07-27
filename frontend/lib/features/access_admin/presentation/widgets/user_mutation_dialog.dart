import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_mutation_dialog.dart';

enum UserMutationMode { create, edit }

typedef UserMutationSubmitHandler =
    Future<AppFailure?> Function(
      AccessAdminUserDraft draft,
      List<String> roleIds,
    );

Future<bool?> showUserMutationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required UserMutationMode mode,
  required AccessAdminWorkspaceState state,
  AccessAdminItem? initialUser,
  AccessAdminUserDetail? initialDetail,
  required UserMutationSubmitHandler onSubmit,
}) async {
  final AppLocalizations l10n = context.l10n;
  final AccessAdminRepository repository = ref.read(
    accessAdminRepositoryProvider,
  );
  final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
  final bool isCrossTenantAdmin = accessPolicy.canCreateTenant();
  final String? sessionTenantId = ref
      .read(sessionStateProvider)
      .session
      ?.user
      ?.tenantId;
  final String? sessionFacilityId = ref
      .read(sessionStateProvider)
      .session
      ?.user
      ?.facilityId;

  final TextEditingController emailController = TextEditingController(
    text: initialUser?.email,
  );
  final TextEditingController phoneController = TextEditingController(
    text: initialUser?.phone,
  );
  final TextEditingController titleController = TextEditingController(
    text: initialUser?.positionTitle,
  );
  final TextEditingController passwordController = TextEditingController();
  String status = initialUser?.status ?? 'ACTIVE';

  String? selectedTenantId =
      initialUser?.tenantId ??
      state.query.tenantId ??
      (isCrossTenantAdmin ? null : sessionTenantId);
  String? selectedFacilityId =
      initialUser?.facilityId ??
      state.query.facilityId ??
      (isCrossTenantAdmin ? null : sessionFacilityId);

  final Set<String> selectedRoleIds =
      initialUser?.roles.map((AccessAdminRoleRef role) => role.id).toSet() ??
      <String>{};
  final Set<String> selectedPermissionIds =
      initialDetail?.directPermissions
          .map((AccessAdminPermissionRef permission) => permission.id)
          .toSet() ??
      initialUser?.permissions
          .map((AccessAdminPermissionRef permission) => permission.id)
          .toSet() ??
      <String>{};

  final bool showTenantPicker =
      isCrossTenantAdmin || (selectedTenantId ?? '').isEmpty;

  List<AccessAdminLookupOption> tenantOptions =
      const <AccessAdminLookupOption>[];
  List<AccessAdminLookupOption> facilityOptions =
      const <AccessAdminLookupOption>[];
  List<AccessAdminLookupOption> roleLookups = const <AccessAdminLookupOption>[];
  List<AccessAdminLookupOption> permissionLookups =
      const <AccessAdminLookupOption>[];

  bool isLoadingTenants = false;
  bool tenantLoadAttempted = !showTenantPicker;
  bool scheduledInitialTenantLoad = false;

  bool isLoadingFacilities = false;
  bool facilityLoadAttempted = (selectedTenantId ?? '').isEmpty;
  bool scheduledInitialFacilityLoad = false;

  bool isLoadingReferenceData = false;
  bool referenceLoadAttempted = (selectedTenantId ?? '').isEmpty;
  bool scheduledInitialReferenceLoad = false;
  AppFailure? referenceLoadFailure;

  Future<void> reloadTenantOptions(StateSetter setState) async {
    setState(() {
      isLoadingTenants = true;
      tenantOptions = const <AccessAdminLookupOption>[];
    });

    final List<AccessAdminLookupOption> loaded = await _loadTenantOptions(
      ref,
      state,
      isCrossTenantAdmin,
    );

    setState(() {
      isLoadingTenants = false;
      tenantLoadAttempted = true;
      tenantOptions = loaded;
    });
  }

  Future<void> reloadFacilityOptions(StateSetter setState) async {
    final String? tenantId = selectedTenantId;
    if ((tenantId ?? '').isEmpty) {
      setState(() {
        facilityOptions = const <AccessAdminLookupOption>[];
        facilityLoadAttempted = true;
      });
      return;
    }

    setState(() {
      isLoadingFacilities = true;
      facilityOptions = const <AccessAdminLookupOption>[];
    });

    final Result<AppPage<FacilityProfile>> result = await ref
        .read(tenantFacilityRepositoryProvider)
        .listFacilities(
          tenantId: tenantId,
          request: const AppPageRequest(pageSize: 100),
        );

    setState(() {
      isLoadingFacilities = false;
      facilityLoadAttempted = true;
      facilityOptions = result.when(
        success: (AppPage<FacilityProfile> page) => page.items
            .map(
              (FacilityProfile facility) => AccessAdminLookupOption(
                id: facility.mutationId,
                label: facility.name,
              ),
            )
            .toList(growable: false),
        failure: (_) => const <AccessAdminLookupOption>[],
      );
    });
  }

  Future<void> reloadReferenceData(StateSetter setState) async {
    final String? tenantId = selectedTenantId;
    if ((tenantId ?? '').isEmpty) {
      return;
    }

    setState(() {
      isLoadingReferenceData = true;
      roleLookups = const <AccessAdminLookupOption>[];
      permissionLookups = const <AccessAdminLookupOption>[];
      referenceLoadFailure = null;
    });

    final Result<AccessAdminLookups> result = await repository.getReferenceData(
      tenantId: tenantId,
      facilityId: selectedFacilityId,
      include: const <String>['roles', 'permissions', 'facilities'],
    );

    setState(() {
      isLoadingReferenceData = false;
      referenceLoadAttempted = true;
      result.when(
        success: (AccessAdminLookups lookups) {
          roleLookups = lookups.roles;
          permissionLookups = lookups.permissions;
          referenceLoadFailure = null;
        },
        failure: (AppFailure failure) {
          roleLookups = const <AccessAdminLookupOption>[];
          permissionLookups = const <AccessAdminLookupOption>[];
          referenceLoadFailure = failure;
        },
      );
    });
  }

  List<AppRoleAssignmentOption> buildRoleOptions() {
    return roleLookups
        .map(
          (AccessAdminLookupOption option) => AppRoleAssignmentOption(
            id: option.id,
            label: option.label,
            description: option.meta,
            permissionCount: option.permissionCount,
          ),
        )
        .toList(growable: false);
  }

  Future<Set<String>> loadRolePermissions(String roleId) async {
    final Result<List<AccessAdminRolePermissionAssignment>> result =
        await repository.listRolePermissions(roleId);
    return result.when(
      success: (List<AccessAdminRolePermissionAssignment> assignments) {
        return assignments
            .map(
              (AccessAdminRolePermissionAssignment assignment) =>
                  (assignment.permissionName ?? '').trim(),
            )
            .where((String name) => name.isNotEmpty)
            .toSet();
      },
      failure: (_) => <String>{},
    );
  }

  List<AppPermissionAssignmentOption> buildPermissionOptions() {
    return permissionLookups
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

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(
      mode == UserMutationMode.create
          ? l10n.accessAdminCreateUserAction
          : l10n.accessAdminEditUserAction,
    ),
    icon: Icon(
      mode == UserMutationMode.create
          ? Icons.person_add_alt_1_outlined
          : Icons.edit_outlined,
    ),
    submitLabel: l10n.commonSaveActionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    cancelIcon: Icons.close_outlined,
    maxWidth: 1080,
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
              final bool scopeReady = tenantSelected && facilitySelected;
              final bool fieldsEnabled = !isSubmitting && scopeReady;
              final bool facilityEnabled =
                  !isSubmitting && tenantSelected && !isLoadingFacilities;
              final String? facilityDisabledReason = !tenantSelected
                  ? (showTenantPicker
                        ? l10n.accessAdminCreateUserSelectTenantFirstTooltip
                        : null)
                  : (isLoadingFacilities
                        ? l10n.accessAdminCreateUserLoadingFacilities
                        : null);
              final String? detailsDisabledReason = fieldsEnabled
                  ? null
                  : (isSubmitting
                        ? null
                        : l10n.accessAdminCreateUserSelectScopeTooltip);
              final List<AppRoleAssignmentOption> roleOptions =
                  buildRoleOptions();
              final List<AppPermissionAssignmentOption> permissionOptions =
                  buildPermissionOptions();

              if (showTenantPicker &&
                  !tenantLoadAttempted &&
                  !isLoadingTenants &&
                  !scheduledInitialTenantLoad) {
                scheduledInitialTenantLoad = true;
                unawaited(reloadTenantOptions(setState));
              }

              if (tenantSelected &&
                  !facilityLoadAttempted &&
                  !isLoadingFacilities &&
                  !scheduledInitialFacilityLoad) {
                scheduledInitialFacilityLoad = true;
                unawaited(reloadFacilityOptions(setState));
              }

              // Roles/permissions are managed from User Details, so create mode
              // never loads the roles/permissions catalog.
              if (mode == UserMutationMode.edit &&
                  scopeReady &&
                  !referenceLoadAttempted &&
                  !isLoadingReferenceData &&
                  !scheduledInitialReferenceLoad) {
                scheduledInitialReferenceLoad = true;
                unawaited(reloadReferenceData(setState));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppSectionPanel(
                    title: l10n.accessAdminCreateRoleScopeSectionTitle,
                    description:
                        l10n.accessAdminCreateUserScopeSectionDescription,
                    leadingIcon: Icons.apartment_outlined,
                    tone: AppWorkspaceStatusTone.info,
                    children: <Widget>[
                      if (showTenantPicker) ...<Widget>[
                        if (isLoadingTenants)
                          _UserMutationLoadingIndicator(
                            label: l10n.accessAdminCreateRoleLoadingTenants,
                          )
                        else if (tenantOptions.isEmpty)
                          AppFormInformationBanner(
                            title: l10n.accessAdminTenantContextRequiredTitle,
                            message: l10n.tenantFacilitySelectTenantLoadError,
                            variant: AppFormInformationVariant.warning,
                            icon: Icons.apartment_outlined,
                            children: <Widget>[
                              AppButton.secondary(
                                label: l10n.commonRetryActionLabel,
                                leadingIcon: Icons.refresh,
                                enabled: !isSubmitting,
                                onPressed: () {
                                  setState(() {
                                    tenantLoadAttempted = false;
                                    scheduledInitialTenantLoad = false;
                                  });
                                  unawaited(reloadTenantOptions(setState));
                                },
                              ),
                            ],
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
                                selectedFacilityId = null;
                                facilityLoadAttempted = false;
                                scheduledInitialFacilityLoad = false;
                                referenceLoadAttempted = false;
                                scheduledInitialReferenceLoad = false;
                                selectedRoleIds.clear();
                                selectedPermissionIds.clear();
                              });
                            },
                            validator: (String? value) =>
                                (value ?? '').trim().isEmpty
                                ? l10n.validationRequired
                                : null,
                          ),
                        SizedBox(height: Theme.of(context).spacing.md),
                      ],
                      _UserMutationReasonedField(
                        reason: facilityDisabledReason,
                        child: AppSelectField<String>.searchable(
                          value: selectedFacilityId,
                          enabled:
                              facilityEnabled && facilityOptions.isNotEmpty,
                          isLoading: isLoadingFacilities,
                          labelText: l10n.tenantFacilityFacilitySelectLabel,
                          isRequired: true,
                          menuHeight: 320,
                          options: facilityOptions
                              .map(
                                (AccessAdminLookupOption facility) =>
                                    AppSelectOption<String>(
                                      value: facility.id,
                                      label: facility.label,
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: facilityEnabled
                              ? (String? value) {
                                  setState(() {
                                    selectedFacilityId = value;
                                    referenceLoadAttempted = false;
                                    scheduledInitialReferenceLoad = false;
                                    selectedRoleIds.clear();
                                    selectedPermissionIds.clear();
                                  });
                                }
                              : null,
                          validator: (String? value) =>
                              (value ?? '').trim().isEmpty
                              ? l10n.validationRequired
                              : null,
                        ),
                      ),
                      if (tenantSelected &&
                          facilityLoadAttempted &&
                          !isLoadingFacilities &&
                          facilityOptions.isEmpty) ...<Widget>[
                        SizedBox(height: Theme.of(context).spacing.md),
                        AppFormInformationBanner(
                          title: l10n.accessAdminCreateUserNoFacilitiesTitle,
                          message:
                              l10n.accessAdminCreateUserNoFacilitiesMessage,
                          variant: AppFormInformationVariant.warning,
                          icon: Icons.local_hospital_outlined,
                          children: <Widget>[
                            AppButton.secondary(
                              label: l10n.commonRetryActionLabel,
                              leadingIcon: Icons.refresh,
                              enabled: !isSubmitting,
                              onPressed: () {
                                setState(() {
                                  facilityLoadAttempted = false;
                                  scheduledInitialFacilityLoad = false;
                                });
                                unawaited(reloadFacilityOptions(setState));
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: Theme.of(context).spacing.md),
                  AppSectionPanel(
                    title: l10n.accessAdminCreateUserDetailsSectionTitle,
                    description:
                        l10n.accessAdminCreateUserDetailsSectionDescription,
                    leadingIcon: Icons.badge_outlined,
                    children: <Widget>[
                      _UserMutationReasonedField(
                        reason: detailsDisabledReason,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            AppEmailField(
                              controller: emailController,
                              enabled: fieldsEnabled,
                              labelText: l10n.accessAdminEmailLabel,
                              isRequired: true,
                              requiredMessage: l10n.validationRequired,
                              invalidEmailMessage: l10n.authEmailInvalidMessage,
                            ),
                            SizedBox(height: Theme.of(context).spacing.md),
                            AppPhoneField(
                              controller: phoneController,
                              enabled: fieldsEnabled,
                              labelText: l10n.accessAdminPhoneLabel,
                              countryLabelText: l10n.appPhoneCountryLabel,
                              countrySearchLabelText:
                                  l10n.appPhoneCountrySearchLabel,
                              countryNoResultsText:
                                  l10n.appPhoneCountryNoResults,
                              numberLabelText: l10n.appPhoneNumberLabel,
                              numberHintText: l10n.appPhoneNumberHint,
                              invalidPhoneMessage: l10n.appPhoneInvalidMessage,
                            ),
                            SizedBox(height: Theme.of(context).spacing.md),
                            AppResponsiveFieldRow.two(
                              gap: AppResponsiveFieldRowGap.form,
                              breakpoint: 720,
                              left: AppTextField(
                                controller: titleController,
                                enabled: fieldsEnabled,
                                labelText: l10n.accessAdminPositionLabel,
                                isRequired: true,
                                validator: AppValidators.requiredText(
                                  l10n.validationRequired,
                                ),
                              ),
                              right: AppSelectField<String>(
                                labelText: l10n.accessAdminStatusLabel,
                                value: status,
                                enabled: fieldsEnabled,
                                options: state.data.lookups.userStatuses
                                    .map(
                                      (String value) =>
                                          AppSelectOption<String>(
                                            value: value,
                                            label: value,
                                          ),
                                    )
                                    .toList(growable: false),
                                onChanged: fieldsEnabled
                                    ? (String? value) {
                                        if (value != null) {
                                          setState(() => status = value);
                                        }
                                      }
                                    : null,
                              ),
                            ),
                            SizedBox(height: Theme.of(context).spacing.md),
                            AppTextField(
                              controller: passwordController,
                              enabled: fieldsEnabled,
                              labelText: mode == UserMutationMode.create
                                  ? l10n.accessAdminPasswordLabel
                                  : l10n.accessAdminPasswordOptionalLabel,
                              obscureText: true,
                              enableObscureTextToggle: true,
                              showObscuredTextLabel: l10n.authShowPasswordLabel,
                              hideObscuredTextLabel: l10n.authHidePasswordLabel,
                              helperText: mode == UserMutationMode.create
                                  ? l10n.accessAdminPasswordHint
                                  : l10n.accessAdminPasswordOptionalHint,
                              validator: mode == UserMutationMode.create
                                  ? (String? value) =>
                                        (value ?? '').length >= 8
                                        ? null
                                        : l10n.accessAdminPasswordHint
                                  : (String? value) {
                                      final String normalized = (value ?? '')
                                          .trim();
                                      if (normalized.isEmpty) {
                                        return null;
                                      }
                                      return normalized.length >= 8
                                          ? null
                                          : l10n.accessAdminPasswordHint;
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (mode == UserMutationMode.edit) ...<Widget>[
                  SizedBox(height: Theme.of(context).spacing.md),
                  AppSectionPanel(
                    title: l10n.hrAccessAssignedRolesLabel,
                    description:
                        l10n.accessAdminCreateUserRolesSectionDescription,
                    leadingIcon: Icons.groups_outlined,
                    trailing: roleOptions.isNotEmpty
                        ? _UserMutationSelectionChip(
                            selectedCount: selectedRoleIds.length,
                            totalCount: roleOptions.length,
                          )
                        : null,
                    children: <Widget>[
                      if (!scopeReady)
                        AppMessagePanel(
                          icon: Icons.touch_app_outlined,
                          title: l10n.accessAdminCreateUserSelectScopeTitle,
                          message: l10n.accessAdminCreateUserSelectScopeMessage,
                          density: AppContentPanelDensity.compact,
                        )
                      else if (isLoadingReferenceData)
                        _UserMutationLoadingIndicator(
                          label: l10n.accessAdminCreateRoleLoadingPermissions,
                        )
                      else if (referenceLoadFailure != null)
                        AppFormInformationBanner.failure(
                          context: context,
                          failure: referenceLoadFailure!,
                          children: <Widget>[
                            AppButton.secondary(
                              label: l10n.commonRetryActionLabel,
                              leadingIcon: Icons.refresh,
                              enabled: !isSubmitting,
                              onPressed: () {
                                setState(() {
                                  referenceLoadAttempted = false;
                                  scheduledInitialReferenceLoad = false;
                                  referenceLoadFailure = null;
                                });
                                unawaited(reloadReferenceData(setState));
                              },
                            ),
                          ],
                        )
                      else if (roleOptions.isEmpty)
                        AppFormInformationBanner(
                          title: l10n.accessAdminCreateUserNoRolesTitle,
                          message: l10n.accessAdminCreateUserNoRolesMessage,
                          variant: AppFormInformationVariant.warning,
                          icon: Icons.groups_outlined,
                        )
                      else
                        IgnorePointer(
                          ignoring: !fieldsEnabled,
                          child: Opacity(
                            opacity: fieldsEnabled ? 1 : 0.55,
                            child: AppRoleAssignmentPicker(
                              roles: roleOptions,
                              selectedRoleIds: selectedRoleIds,
                              loadRolePermissions: loadRolePermissions,
                              onSelectionChanged: (Set<String> next) {
                                setState(() {
                                  selectedRoleIds
                                    ..clear()
                                    ..addAll(next);
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: Theme.of(context).spacing.md),
                  AppSectionPanel(
                    title: l10n.hrAccessDirectPermissionsLabel,
                    description:
                        l10n.accessAdminCreateUserPermissionsSectionDescription,
                    leadingIcon: Icons.security_outlined,
                    trailing: permissionOptions.isNotEmpty
                        ? _UserMutationSelectionChip(
                            selectedCount: selectedPermissionIds.length,
                            totalCount: permissionOptions.length,
                          )
                        : null,
                    children: <Widget>[
                      if (!scopeReady)
                        AppMessagePanel(
                          icon: Icons.touch_app_outlined,
                          title: l10n.accessAdminCreateUserSelectScopeTitle,
                          message: l10n.accessAdminCreateUserSelectScopeMessage,
                          density: AppContentPanelDensity.compact,
                        )
                      else if (isLoadingReferenceData)
                        _UserMutationLoadingIndicator(
                          label: l10n.accessAdminCreateRoleLoadingPermissions,
                        )
                      else if (permissionOptions.isEmpty)
                        AppFormInformationBanner(
                          title:
                              l10n.accessAdminPermissionCatalogUnavailableTitle,
                          message: l10n
                              .accessAdminPermissionCatalogUnavailableMessage,
                          variant: AppFormInformationVariant.warning,
                          icon: Icons.security_outlined,
                        )
                      else
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
                    ],
                  ),
                  ],
                ],
              );
            },
          );
        },
    onSubmit: () {
      final String? resolvedTenantId = selectedTenantId;
      final String? resolvedFacilityId = selectedFacilityId;
      if ((resolvedTenantId ?? '').isEmpty ||
          (resolvedFacilityId ?? '').isEmpty) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      if (mode == UserMutationMode.create &&
          passwordController.text.trim().length < 8) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }

      final String passwordValue = passwordController.text.trim();
      final bool isCreate = mode == UserMutationMode.create;
      // Create captures Organization + User details only; roles/permissions are
      // managed from User Details after creation.
      final List<String> submittedPermissionIds = isCreate
          ? const <String>[]
          : selectedPermissionIds.toList(growable: false);
      final List<String> submittedRoleIds = isCreate
          ? const <String>[]
          : selectedRoleIds.toList(growable: false);
      return onSubmit(
        AccessAdminUserDraft(
          tenantId: resolvedTenantId!,
          facilityId: resolvedFacilityId,
          email: emailController.text.trim(),
          phone: phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          positionTitle: titleController.text.trim(),
          password: passwordValue.isEmpty ? null : passwordValue,
          status: status,
          permissionIds: submittedPermissionIds,
        ),
        submittedRoleIds,
      );
    },
  );

  emailController.dispose();
  phoneController.dispose();
  titleController.dispose();
  passwordController.dispose();
  return saved;
}

class _UserMutationReasonedField extends StatelessWidget {
  const _UserMutationReasonedField({
    required this.child,
    this.reason,
  });

  final Widget child;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final String? message = reason?.trim();
    if (message == null || message.isEmpty) {
      return child;
    }

    // Hover (desktop), long-press (mobile), and tap all surface the reason.
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 250),
      triggerMode: TooltipTriggerMode.tap,
      child: child,
    );
  }
}

class _UserMutationLoadingIndicator extends StatelessWidget {
  const _UserMutationLoadingIndicator({required this.label});

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

class _UserMutationSelectionChip extends StatelessWidget {
  const _UserMutationSelectionChip({
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

Future<List<AccessAdminLookupOption>> _loadTenantOptions(
  WidgetRef ref,
  AccessAdminWorkspaceState state,
  bool preferTenantFacilityApi,
) async {
  if (!preferTenantFacilityApi && state.data.lookups.tenants.isNotEmpty) {
    return state.data.lookups.tenants;
  }

  if (preferTenantFacilityApi || state.data.lookups.tenants.isEmpty) {
    final Result<AppPage<TenantProfile>> tenantPageResult = await ref
        .read(tenantFacilityRepositoryProvider)
        .listTenants(request: const AppPageRequest(pageSize: 100));
    final List<AccessAdminLookupOption>? tenantFacilityOptions =
        tenantPageResult.when(
          success: (AppPage<TenantProfile> page) => page.items
              .map(
                (TenantProfile tenant) => AccessAdminLookupOption(
                  id: tenant.mutationId,
                  label: tenant.name,
                ),
              )
              .toList(growable: false),
          failure: (_) => null,
        );
    if (tenantFacilityOptions != null && tenantFacilityOptions.isNotEmpty) {
      return tenantFacilityOptions;
    }
  }

  if (state.data.lookups.tenants.isNotEmpty) {
    return state.data.lookups.tenants;
  }

  final Result<AccessAdminLookups> result = await ref
      .read(accessAdminRepositoryProvider)
      .getReferenceData();
  return result.when(
    success: (AccessAdminLookups lookups) => lookups.tenants,
    failure: (_) => const <AccessAdminLookupOption>[],
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';
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
  final TextEditingController firstNameController = TextEditingController(
    text: initialUser?.firstName,
  );
  final TextEditingController lastNameController = TextEditingController(
    text: initialUser?.lastName,
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

  final bool showTenantPicker =
      isCrossTenantAdmin || (selectedTenantId ?? '').isEmpty;

  List<AccessAdminLookupOption> tenantOptions =
      const <AccessAdminLookupOption>[];
  List<AccessAdminLookupOption> facilityOptions =
      const <AccessAdminLookupOption>[];

  bool isLoadingTenants = false;
  bool tenantLoadAttempted = !showTenantPicker;
  bool scheduledInitialTenantLoad = false;

  bool isLoadingFacilities = false;
  bool facilityLoadAttempted = (selectedTenantId ?? '').isEmpty;
  bool scheduledInitialFacilityLoad = false;

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
    maxWidth: 720,
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

              // Roles/permissions are managed from User Details, so create/edit
              // never loads the roles/permissions catalog in this dialog.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppFormSection(
                    density: AppFormSectionDensity.compact,
                    framed: false,
                    title: l10n.accessAdminCreateRoleScopeSectionTitle,
                    children: <Widget>[
                      if (showTenantPicker &&
                          !isLoadingTenants &&
                          tenantOptions.isEmpty)
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
                      else if (showTenantPicker)
                        AppResponsiveFieldRow.two(
                          gap: AppResponsiveFieldRowGap.form,
                          breakpoint: 560,
                          left: isLoadingTenants
                              ? _UserMutationLoadingIndicator(
                                  label: l10n
                                      .accessAdminCreateRoleLoadingTenants,
                                )
                              : AppSelectField<String>.searchable(
                                  value: selectedTenantId,
                                  enabled: !isSubmitting,
                                  labelText:
                                      l10n.tenantFacilitySelectTenantLabel,
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
                                    });
                                  },
                                  validator: (String? value) =>
                                      (value ?? '').trim().isEmpty
                                      ? l10n.validationRequired
                                      : null,
                                ),
                          right: _UserMutationReasonedField(
                            reason: facilityDisabledReason,
                            child: AppSelectField<String>.searchable(
                              value: selectedFacilityId,
                              enabled: facilityEnabled &&
                                  facilityOptions.isNotEmpty,
                              isLoading: isLoadingFacilities,
                              labelText:
                                  l10n.tenantFacilityFacilitySelectLabel,
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
                                      });
                                    }
                                  : null,
                              validator: (String? value) =>
                                  (value ?? '').trim().isEmpty
                                  ? l10n.validationRequired
                                  : null,
                            ),
                          ),
                        )
                      else
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
                          facilityOptions.isEmpty)
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
                  ),
                  SizedBox(height: Theme.of(context).spacing.md),
                  AppFormSection(
                    density: AppFormSectionDensity.compact,
                    framed: false,
                    title: l10n.accessAdminCreateUserDetailsSectionTitle,
                    children: <Widget>[
                      _UserMutationReasonedField(
                        reason: detailsDisabledReason,
                        child: AppResponsiveFieldRow.two(
                          gap: AppResponsiveFieldRowGap.form,
                          breakpoint: 560,
                          left: AppTextField(
                            controller: firstNameController,
                            enabled: fieldsEnabled,
                            labelText: l10n.accessAdminFirstNameLabel,
                            isRequired: true,
                            textCapitalization: TextCapitalization.words,
                            validator: AppValidators.requiredText(
                              l10n.validationRequired,
                            ),
                          ),
                          right: AppTextField(
                            controller: lastNameController,
                            enabled: fieldsEnabled,
                            labelText: l10n.accessAdminLastNameLabel,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ),
                      _UserMutationReasonedField(
                        reason: detailsDisabledReason,
                        child: AppResponsiveFieldRow.two(
                          gap: AppResponsiveFieldRowGap.form,
                          breakpoint: 560,
                          left: AppEmailField(
                            controller: emailController,
                            enabled: fieldsEnabled,
                            labelText: l10n.accessAdminEmailLabel,
                            isRequired: true,
                            requiredMessage: l10n.validationRequired,
                            invalidEmailMessage: l10n.authEmailInvalidMessage,
                          ),
                          right: AppPhoneField(
                            controller: phoneController,
                            enabled: fieldsEnabled,
                            labelText: l10n.accessAdminPhoneLabel,
                            countryLabelText: l10n.appPhoneCountryLabel,
                            countrySearchLabelText:
                                l10n.appPhoneCountrySearchLabel,
                            countryNoResultsText: l10n.appPhoneCountryNoResults,
                            numberLabelText: l10n.appPhoneNumberLabel,
                            numberHintText: l10n.appPhoneNumberHint,
                            invalidPhoneMessage: l10n.appPhoneInvalidMessage,
                          ),
                        ),
                      ),
                      _UserMutationReasonedField(
                        reason: detailsDisabledReason,
                        child: AppResponsiveFieldRow.two(
                          gap: AppResponsiveFieldRowGap.form,
                          breakpoint: 560,
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
                                  (String value) => AppSelectOption<String>(
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
                      ),
                      _UserMutationReasonedField(
                        reason: detailsDisabledReason,
                        child: AppTextField(
                          controller: passwordController,
                          enabled: fieldsEnabled,
                          labelText: mode == UserMutationMode.create
                              ? l10n.accessAdminCreatePasswordOptionalLabel
                              : l10n.accessAdminPasswordOptionalLabel,
                          obscureText: true,
                          enableObscureTextToggle: true,
                          showObscuredTextLabel: l10n.authShowPasswordLabel,
                          hideObscuredTextLabel: l10n.authHidePasswordLabel,
                          tooltip: mode == UserMutationMode.create
                              ? l10n.accessAdminCreatePasswordOptionalHint
                              : l10n.accessAdminPasswordOptionalHint,
                          validator: (String? value) {
                            final String normalized = (value ?? '').trim();
                            if (normalized.isEmpty) {
                              return null;
                            }
                            return normalized.length >= 8
                                ? null
                                : l10n.accessAdminPasswordHint;
                          },
                        ),
                      ),
                    ],
                  ),
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

      String? labelFor(
        List<AccessAdminLookupOption> options,
        String? id, {
        List<AccessAdminLookupOption> workspaceOptions =
            const <AccessAdminLookupOption>[],
        String? fallback,
      }) {
        if ((id ?? '').isEmpty) {
          return fallback;
        }
        for (final AccessAdminLookupOption option in <AccessAdminLookupOption>[
          ...options,
          ...workspaceOptions,
        ]) {
          if (option.id == id) {
            final String label = option.label.trim();
            if (label.isNotEmpty) {
              return label;
            }
          }
        }
        return fallback;
      }

      final String passwordValue = passwordController.text.trim();
      if (passwordValue.isNotEmpty && passwordValue.length < 8) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
      // Create/edit capture Organization + User details only; roles/permissions
      // are managed from User Details after save.
      return onSubmit(
        AccessAdminUserDraft(
          tenantId: resolvedTenantId!,
          facilityId: resolvedFacilityId,
          tenantName: labelFor(
            tenantOptions,
            resolvedTenantId,
            workspaceOptions: state.data.lookups.tenants,
            fallback: initialUser?.tenantName,
          ),
          facilityName: labelFor(
            facilityOptions,
            resolvedFacilityId,
            workspaceOptions: state.data.lookups.facilities,
            fallback: initialUser?.facilityName,
          ),
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim().isEmpty
              ? null
              : lastNameController.text.trim(),
          email: emailController.text.trim(),
          phone: phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          positionTitle: titleController.text.trim(),
          password: passwordValue.isEmpty ? null : passwordValue,
          status: status,
          permissionIds: const <String>[],
        ),
        const <String>[],
      );
    },
  );

  emailController.dispose();
  firstNameController.dispose();
  lastNameController.dispose();
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

    // Hover (desktop) and long-press (touch) surface the disable reason.
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 300),
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

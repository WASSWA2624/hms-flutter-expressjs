import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_media_url.dart';
import 'package:hosspi_hms/core/utils/app_slug.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/facility_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/facility_similarity_dialog.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_similarity_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/actions/app_workspace_refresh_action.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class TenantFacilitySetupPage extends ConsumerWidget {
  const TenantFacilitySetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final setup = ref.watch(tenantFacilitySetupControllerProvider);

    ref.listen<int>(
      tenantFacilitySetupSubmissionProvider.select(
        (state) => state.successVersion,
      ),
      (int? previous, int next) {
        if (previous == null || next <= previous || !context.mounted) {
          return;
        }

        _showSaved(context);
      },
    );

    return AsyncStateScaffold<FacilitySetupSnapshot>(
      value: setup,
      loadingTitle: l10n.tenantFacilitySetupLoadingTitle,
      loadingBody: l10n.tenantFacilitySetupLoadingBody,
      maxWidth: PageMaxWidth.dashboard,
      centerVertically: false,
      onRetry: () {
        ref.read(tenantFacilitySetupControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, FacilitySetupSnapshot snapshot) {
        return _TenantFacilitySetupContent(snapshot: snapshot);
      },
    );
  }
}

class _TenantFacilitySetupContent extends ConsumerWidget {
  const _TenantFacilitySetupContent({required this.snapshot});

  final FacilitySetupSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canManageTenant = accessPolicy.canManageTenant();
    final bool canManageFacility = accessPolicy.canManageFacility();
    final bool canManageHrSetup = accessPolicy.canManageHrFacilitySetup();
    final bool isHrSetupOnly = accessPolicy.isHrFacilitySetupOnlyUser();
    final bool canManageAccess = accessPolicy.grantsAny(const <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.hrWrite,
    ]);

    return AppWorkspace(
      title: tenantFacilitySetupWorkspaceTitle(
        accessPolicy,
        l10n,
        isHrSetupOnly: isHrSetupOnly,
      ),
      leadingIcon: AppRouteIcons.setup,
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        showGlobalActions: false,
        showFaultReport: false,
        showHousekeepingRequest: false,
      ),
      body: _SetupBody(
        snapshot: snapshot,
        canManageTenant: canManageTenant,
        canManageFacility: canManageFacility,
        canManageHrSetup: canManageHrSetup,
        canManageAccess: canManageAccess,
        isHrSetupOnly: isHrSetupOnly,
      ),
    );
  }
}

typedef _SetupDetailBuilder =
    Widget Function(
      BuildContext context,
      FacilitySetupSnapshot snapshot,
      bool canManageTenant,
      bool canManageFacility,
      bool canEditHrStructure,
    );

class _SetupDetailDialog extends ConsumerWidget {
  const _SetupDetailDialog({
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final _SetupDetailBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final setup = ref.watch(tenantFacilitySetupControllerProvider);

    return AppDialog(
      title: Text(title),
      icon: Icon(icon),
      scrollable: true,
      maxWidth: 880,
      content: setup.when(
        data: (result) => result.when(
          success: (FacilitySetupSnapshot snapshot) => builder(
            context,
            snapshot,
            accessPolicy.canManageTenant(),
            accessPolicy.canManageFacility(),
            accessPolicy.canEditFacilitySetupStructure(),
          ),
          failure: (AppFailure failure) => AppFailureStateView(
            failure: failure,
            onRetry: () {
              ref
                  .read(tenantFacilitySetupControllerProvider.notifier)
                  .refresh();
            },
          ),
        ),
        error: (Object error, StackTrace stackTrace) => AppFailureStateView(
          failure: _setupFailure(error),
          onRetry: () {
            ref.read(tenantFacilitySetupControllerProvider.notifier).refresh();
          },
        ),
        loading: () => AppStateView(
          variant: AppStateViewVariant.loading,
          title: l10n.tenantFacilitySetupLoadingTitle,
          body: l10n.tenantFacilitySetupLoadingBody,
        ),
      ),
    );
  }
}

typedef _ProfileFormSubmitRegistrar =
    void Function(
      Future<bool> Function() submit, {
      bool Function()? canSave,
      VoidCallback? onFormStateChanged,
    });

typedef _SetupProfileFormBuilder =
    Widget Function(
      BuildContext context,
      FacilitySetupSnapshot snapshot,
      bool canManageTenant,
      bool canManageFacility,
      bool canEditHrStructure,
      _ProfileFormSubmitRegistrar registerSubmitHandler,
      VoidCallback onDialogStateChanged,
    );

class _SetupProfileDialog extends ConsumerStatefulWidget {
  const _SetupProfileDialog({
    required this.title,
    required this.icon,
    required this.saveLabel,
    required this.formBuilder,
    this.managementSnapshot,
  });

  final String title;
  final IconData icon;
  final String saveLabel;
  final _SetupProfileFormBuilder formBuilder;
  final FacilitySetupSnapshot? managementSnapshot;

  @override
  ConsumerState<_SetupProfileDialog> createState() =>
      _SetupProfileDialogState();
}

class _SetupProfileDialogState extends ConsumerState<_SetupProfileDialog> {
  Future<bool> Function()? _submitHandler;
  bool Function()? _canSaveChecker;

  void _registerSubmitHandler(
    Future<bool> Function() submit, {
    bool Function()? canSave,
    VoidCallback? onFormStateChanged,
  }) {
    _submitHandler = submit;
    _canSaveChecker = canSave;
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFormStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleSave() async {
    final Future<bool> Function()? submit = _submitHandler;
    if (submit == null) {
      return;
    }
    final bool saved = await submit();
    if (!mounted) {
      return;
    }
    if (saved) {
      if (widget.managementSnapshot == null) {
        _showSaved(context);
      }
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final TenantFacilitySetupSubmissionState submission = ref.watch(
      tenantFacilitySetupSubmissionProvider,
    );
    final setup = ref.watch(tenantFacilitySetupControllerProvider);
    final FacilitySetupSnapshot? managementSnapshot = widget.managementSnapshot;
    final Widget content = managementSnapshot != null
        ? widget.formBuilder(
            context,
            managementSnapshot,
            accessPolicy.canManageTenant(),
            accessPolicy.canManageFacility(),
            accessPolicy.canEditFacilitySetupStructure(),
            _registerSubmitHandler,
            _handleFormStateChanged,
          )
        : setup.when(
            data: (result) => result.when(
              success: (FacilitySetupSnapshot snapshot) => widget.formBuilder(
                context,
                snapshot,
                accessPolicy.canManageTenant(),
                accessPolicy.canManageFacility(),
                accessPolicy.canEditFacilitySetupStructure(),
                _registerSubmitHandler,
                _handleFormStateChanged,
              ),
              failure: (AppFailure failure) => AppFailureStateView(
                failure: failure,
                onRetry: () {
                  ref
                      .read(tenantFacilitySetupControllerProvider.notifier)
                      .refresh();
                },
              ),
            ),
            error: (Object error, StackTrace stackTrace) => AppFailureStateView(
              failure: _setupFailure(error),
              onRetry: () {
                ref
                    .read(tenantFacilitySetupControllerProvider.notifier)
                    .refresh();
              },
            ),
            loading: () => AppStateView(
              variant: AppStateViewVariant.loading,
              title: l10n.tenantFacilitySetupLoadingTitle,
              body: l10n.tenantFacilitySetupLoadingBody,
            ),
          );

    return AppDialog(
      title: Text(widget.title),
      icon: Icon(widget.icon),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 880,
      closeEnabled: !submission.isSubmitting,
      content: content,
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          enabled: !submission.isSubmitting,
          onPressed: submission.isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: widget.saveLabel,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed:
              submission.isSubmitting || !(_canSaveChecker?.call() ?? true)
              ? null
              : _handleSave,
        ),
      ],
    );
  }
}

Future<bool?> _openTenantProfileModal(
  BuildContext context, {
  TenantProfile? tenant,
  bool forceCreate = false,
  bool managementMode = false,
}) {
  final AppLocalizations l10n = context.l10n;
  const FacilitySetupSnapshot managementSnapshot = FacilitySetupSnapshot();
  ProviderScope.containerOf(
    context,
  ).read(tenantFacilitySetupSubmissionProvider.notifier).clearFailure();

  return showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, _) {
        final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
        final String dialogTitle = forceCreate
            ? l10n.tenantFacilityCreateTenantTitle
            : tenant != null
            ? l10n.tenantFacilityEditTenantTitle
            : l10n.tenantFacilityTenantSectionTitle;
        final String saveLabel = forceCreate
            ? l10n.tenantFacilityCreateTenantAction
            : l10n.tenantFacilitySaveTenantAction;

        return _SetupProfileDialog(
          title: dialogTitle,
          icon: Icons.apartment_outlined,
          saveLabel: saveLabel,
          managementSnapshot: managementMode ? managementSnapshot : null,
          formBuilder:
              (
                BuildContext context,
                FacilitySetupSnapshot snapshot,
                bool canManageTenant,
                bool canManageFacility,
                bool canEditHrStructure,
                _ProfileFormSubmitRegistrar registerSubmitHandler,
                VoidCallback onDialogStateChanged,
              ) {
                final TenantProfile? formTenant = forceCreate
                    ? null
                    : (tenant ?? snapshot.tenant);
                final bool isCreate = forceCreate || formTenant == null;

                return _TenantProfileForm(
                  tenant: formTenant,
                  canSubmit: isCreate
                      ? accessPolicy.canCreateTenant()
                      : canManageTenant,
                  framed: false,
                  isCreate: isCreate,
                  sectionBody: isCreate
                      ? l10n.tenantFacilityCreateTenantBody
                      : l10n.tenantFacilityTenantSectionBody,
                  permissionDeniedMessage: isCreate
                      ? l10n.tenantFacilityCreateTenantPermissionRequired
                      : l10n.tenantFacilityPermissionRequired,
                  hideSubmitButton: true,
                  refreshSetupAfterSave: !managementMode,
                  registerSubmitHandler: registerSubmitHandler,
                  onDialogStateChanged: onDialogStateChanged,
                );
              },
        );
      },
    ),
  );
}

Future<bool?> _openFacilityProfileModal(
  BuildContext context, {
  String? tenantId,
  FacilityProfile? facility,
  bool requireTenantPicker = false,
  bool managementMode = false,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool isCreate = facility == null;
  const FacilitySetupSnapshot managementSnapshot = FacilitySetupSnapshot();
  ProviderScope.containerOf(
    context,
  ).read(tenantFacilitySetupSubmissionProvider.notifier).clearFailure();

  return showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, _) {
        return _SetupProfileDialog(
          title: isCreate
              ? l10n.tenantFacilityCreateFacilityTitle
              : l10n.tenantFacilityEditFacilityTitle,
          icon: isCreate ? Icons.add_business_outlined : Icons.edit_outlined,
          saveLabel: isCreate
              ? l10n.tenantFacilitySaveFacilityAction
              : l10n.tenantFacilityEditFacilityAction,
          managementSnapshot: managementMode ? managementSnapshot : null,
          formBuilder:
              (
                BuildContext context,
                FacilitySetupSnapshot snapshot,
                bool canManageTenant,
                bool canManageFacility,
                bool canEditHrStructure,
                _ProfileFormSubmitRegistrar registerSubmitHandler,
                VoidCallback onDialogStateChanged,
              ) => _FacilityProfileForm(
                snapshot: snapshot,
                canSubmit: canManageFacility,
                framed: false,
                tenantId: tenantId,
                facility: facility,
                requireTenantPicker: requireTenantPicker,
                hideSubmitButton: true,
                refreshSetupAfterSave: !managementMode,
                registerSubmitHandler: registerSubmitHandler,
                onDialogStateChanged: onDialogStateChanged,
              ),
        );
      },
    ),
  );
}

Future<void> _openDepartmentsModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityDepartmentsListTitle,
      icon: Icons.groups_2_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
            bool canEditHrStructure,
          ) => _DepartmentSetupSection(
            snapshot: snapshot,
            canSubmit: canEditHrStructure && snapshot.facility != null,
            framed: false,
          ),
    ),
  );
}

Future<void> _openUnitsModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityUnitsListTitle,
      icon: Icons.hub_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
            bool canEditHrStructure,
          ) => _UnitSetupSection(
            snapshot: snapshot,
            canSubmit: canEditHrStructure && snapshot.facility != null,
            framed: false,
          ),
    ),
  );
}

Future<void> _openFacilityCatalogModal(
  BuildContext context,
  FacilitySetupSnapshot snapshot,
) {
  final AppLocalizations l10n = context.l10n;
  final String? facilityId = snapshot.facility?.id;
  final String? tenantId = snapshot.facility?.tenantId ?? snapshot.tenant?.id;
  if (facilityId == null ||
      facilityId.isEmpty ||
      tenantId == null ||
      tenantId.isEmpty) {
    return Future<void>.value();
  }

  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialog(
      title: Text(l10n.clinicalCatalogConfigurationTitle),
      icon: const Icon(Icons.medical_information_outlined),
      scrollable: true,
      maxWidth: 920,
      content: FacilityCatalogConfigPanel(
        facilityId: facilityId,
        tenantId: tenantId,
        defaultCurrency: resolveDefaultCurrency(
          facilityCurrency: snapshot.facility?.currency,
          tenantCurrency: snapshot.tenant?.currency,
        ),
      ),
    ),
  );
}

AppFailure _setupFailure(Object error) {
  if (error is AppFailure) {
    return error;
  }

  return const AppFailure.unexpected();
}

class _SetupBody extends ConsumerStatefulWidget {
  const _SetupBody({
    required this.snapshot,
    required this.canManageTenant,
    required this.canManageFacility,
    required this.canManageHrSetup,
    required this.canManageAccess,
    required this.isHrSetupOnly,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canManageTenant;
  final bool canManageFacility;
  final bool canManageHrSetup;
  final bool canManageAccess;
  final bool isHrSetupOnly;

  @override
  ConsumerState<_SetupBody> createState() => _SetupBodyState();
}

class _SetupBodyState extends ConsumerState<_SetupBody> {
  TenantFacilitySetupDeskSection? _section;

  bool get _canEditStructure =>
      widget.canManageFacility || widget.canManageHrSetup;

  List<TenantFacilitySetupDeskSection> get _visibleSections {
    if (widget.isHrSetupOnly) {
      return const <TenantFacilitySetupDeskSection>[
        TenantFacilitySetupDeskSection.departments,
        TenantFacilitySetupDeskSection.units,
      ];
    }
    return tenantFacilityVisibleSetupDeskSections(
      canManageTenant: widget.canManageTenant,
      canManageFacility: widget.canManageFacility,
      canManageAccess: widget.canManageAccess,
    );
  }

  TenantFacilitySetupDeskSection get _currentSection {
    final List<TenantFacilitySetupDeskSection> sections = _visibleSections;
    if (sections.isEmpty) {
      return TenantFacilitySetupDeskSection.facility;
    }
    final TenantFacilitySetupDeskSection? selected = _section;
    if (selected != null && sections.contains(selected)) {
      return selected;
    }
    return sections.first;
  }

  void _refreshSetup() {
    unawaited(
      ref.read(tenantFacilitySetupControllerProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<TenantFacilitySetupDeskSection> sections = _visibleSections;
    final TenantFacilitySetupDeskSection current = _currentSection;

    if (sections.isEmpty) {
      return AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilitySetupTitle,
        body: l10n.tenantFacilitySetupBody,
      );
    }

    if (widget.isHrSetupOnly) {
      return _HrFacilitySetupBody(
        snapshot: widget.snapshot,
        canEditStructure: _canEditStructure,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTabStrip(
          tabs: <AppTabItem>[
            for (final TenantFacilitySetupDeskSection section in sections)
              AppTabItem(
                id: section.name,
                icon: tenantFacilitySetupDeskSectionIcon(section),
                label: tenantFacilitySetupDeskSectionLabel(l10n, section),
              ),
          ],
          selectedId: current.name,
          onTabTapped: (String tabId) {
            for (final TenantFacilitySetupDeskSection section in sections) {
              if (section.name == tabId) {
                setState(() => _section = section);
                break;
              }
            }
          },
          secondaryActions: <Widget>[
            if (widget.snapshot.facility?.id != null)
              AppTabToolbarAction(
                label: l10n.clinicalCatalogConfigurationTitle,
                icon: Icons.medical_information_outlined,
                onPressed: () {
                  unawaited(
                    _openFacilityCatalogModal(context, widget.snapshot),
                  );
                },
              ),
            AppWorkspaceRefreshAction(
              label: l10n.commonRefreshActionLabel,
              onPressed: _refreshSetup,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        Expanded(child: _buildTabBody(current)),
      ],
    );
  }

  Widget _buildTabBody(TenantFacilitySetupDeskSection section) {
    final FacilitySetupSnapshot snapshot = widget.snapshot;
    final bool canSubmitFacility =
        widget.canManageFacility && snapshot.facility != null;
    final bool canSubmitTenant = widget.canManageTenant;

    return switch (section) {
      TenantFacilitySetupDeskSection.tenants => ManageTenantsPanel(
        onMutated: (_) => _refreshSetup(),
      ),
      TenantFacilitySetupDeskSection.facility => ManageFacilitiesPanel(
        onMutated: (_) => _refreshSetup(),
      ),
      TenantFacilitySetupDeskSection.branches => SingleChildScrollView(
        child: _BranchSetupSection(
          snapshot: snapshot,
          canSubmit: canSubmitTenant,
        ),
      ),
      TenantFacilitySetupDeskSection.departments => SingleChildScrollView(
        child: _DepartmentSetupSection(
          snapshot: snapshot,
          canSubmit: canSubmitFacility || widget.canManageHrSetup,
        ),
      ),
      TenantFacilitySetupDeskSection.units => SingleChildScrollView(
        child: _UnitSetupSection(
          snapshot: snapshot,
          canSubmit: canSubmitFacility || widget.canManageHrSetup,
        ),
      ),
      TenantFacilitySetupDeskSection.wards => SingleChildScrollView(
        child: _WardSetupSection(
          snapshot: snapshot,
          canSubmit: canSubmitFacility,
        ),
      ),
      TenantFacilitySetupDeskSection.rooms => SingleChildScrollView(
        child: _RoomSetupSection(
          snapshot: snapshot,
          canSubmit: canSubmitFacility,
        ),
      ),
      TenantFacilitySetupDeskSection.beds => SingleChildScrollView(
        child: _BedSetupSection(
          snapshot: snapshot,
          canSubmit: canSubmitFacility,
        ),
      ),
      TenantFacilitySetupDeskSection.roles => ManageRolesPermissionsPanel(
        onMutated: (_) => _refreshSetup(),
      ),
      TenantFacilitySetupDeskSection.permissions => ManageRolesPermissionsPanel(
        panel: AccessAdminPanel.permissions,
        onMutated: (_) => _refreshSetup(),
      ),
      TenantFacilitySetupDeskSection.users => ManageUsersPanel(
        onMutated: (_) => _refreshSetup(),
      ),
    };
  }
}

class _HrFacilitySetupBody extends StatelessWidget {
  const _HrFacilitySetupBody({
    required this.snapshot,
    required this.canEditStructure,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canEditStructure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.tenantFacilityHrSetupBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        _SetupGrid(
          children: <Widget>[
            AppScreenSection(
              title: l10n.tenantFacilityDepartmentsListTitle,
              body: l10n.tenantFacilityHrSetupDepartmentsBody,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppInfoTile(
                    label: l10n.settingsWorkspaceRecordsLabel,
                    value: '${snapshot.departments.length}',
                  ),
                  SizedBox(height: theme.spacing.md),
                  AppButton.primary(
                    label: l10n.tenantFacilityHrSetupManageAction,
                    leadingIcon: Icons.groups_2_outlined,
                    onPressed: snapshot.facility?.id == null
                        ? null
                        : () => unawaited(_openDepartmentsModal(context)),
                  ),
                ],
              ),
            ),
            AppScreenSection(
              title: l10n.tenantFacilityUnitsListTitle,
              body: l10n.tenantFacilityHrSetupUnitsBody,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppInfoTile(
                    label: l10n.settingsWorkspaceRecordsLabel,
                    value: '${snapshot.units.length}',
                  ),
                  SizedBox(height: theme.spacing.md),
                  AppButton.primary(
                    label: l10n.tenantFacilityHrSetupManageAction,
                    leadingIcon: Icons.hub_outlined,
                    onPressed: snapshot.facility?.id == null
                        ? null
                        : () => unawaited(_openUnitsModal(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TenantProfileForm extends ConsumerStatefulWidget {
  const _TenantProfileForm({
    required this.tenant,
    required this.canSubmit,
    this.framed = true,
    this.isCreate = false,
    this.sectionBody,
    this.permissionDeniedMessage,
    this.hideSubmitButton = false,
    this.refreshSetupAfterSave = true,
    this.registerSubmitHandler,
    this.onDialogStateChanged,
  });

  final TenantProfile? tenant;
  final bool canSubmit;
  final bool framed;
  final bool isCreate;
  final String? sectionBody;
  final String? permissionDeniedMessage;
  final bool hideSubmitButton;
  final bool refreshSetupAfterSave;
  final _ProfileFormSubmitRegistrar? registerSubmitHandler;
  final VoidCallback? onDialogStateChanged;

  @override
  ConsumerState<_TenantProfileForm> createState() => _TenantProfileFormState();
}

class _TenantProfileFormState extends ConsumerState<_TenantProfileForm> {
  static const AppPageRequest _duplicateLookupRequest = AppPageRequest(
    pageSize: 100,
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late bool _isActive;
  late String _currency;
  bool _slugManuallyEdited = false;
  String? _nameErrorText;
  String? _slugErrorText;
  List<TenantSimilarityMatch> _similarMatches = const <TenantSimilarityMatch>[];
  bool _similarityAccepted = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tenant?.name);
    _slugController = TextEditingController(text: widget.tenant?.slug);
    _isActive = widget.tenant?.isActive ?? true;
    _currency = resolveDefaultCurrency(tenantCurrency: widget.tenant?.currency);
    _slugManuallyEdited =
        widget.tenant?.slug != null && widget.tenant!.slug!.trim().isNotEmpty;
    _nameController.addListener(_handleNameChanged);
    _slugController.addListener(_handleSlugChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.registerSubmitHandler?.call(_submit);
    });
  }

  @override
  void didUpdateWidget(_TenantProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenant?.id != widget.tenant?.id) {
      _nameController.text = widget.tenant?.name ?? '';
      _slugController.text = widget.tenant?.slug ?? '';
      _isActive = widget.tenant?.isActive ?? true;
      _currency = resolveDefaultCurrency(
        tenantCurrency: widget.tenant?.currency,
      );
      _slugManuallyEdited =
          widget.tenant?.slug != null && widget.tenant!.slug!.trim().isNotEmpty;
      _clearDuplicateState();
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    _slugController
      ..removeListener(_handleSlugChanged)
      ..dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    _clearDuplicateState();
    if (!widget.isCreate || _slugManuallyEdited) {
      return;
    }

    final String slug = slugify(_nameController.text);
    if (_slugController.text != slug) {
      _slugController.text = slug;
    }
  }

  void _handleSlugChanged() {
    _clearDuplicateState();
    if (!widget.isCreate) {
      return;
    }

    final String autoSlug = slugify(_nameController.text);
    final String currentSlug = _slugController.text.trim();
    _slugManuallyEdited = currentSlug.isNotEmpty && currentSlug != autoSlug;
  }

  void _clearDuplicateState() {
    if (_nameErrorText == null &&
        _slugErrorText == null &&
        _similarMatches.isEmpty &&
        !_similarityAccepted) {
      return;
    }

    setState(() {
      _nameErrorText = null;
      _slugErrorText = null;
      _similarMatches = const <TenantSimilarityMatch>[];
      _similarityAccepted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final String sectionBody =
        widget.sectionBody ?? l10n.tenantFacilityTenantSectionBody;

    final Widget form = Form(
      key: _formKey,
      child: AppFormSection(
        children: <Widget>[
          AppTextField(
            controller: _nameController,
            enabled: widget.canSubmit && !submission.isSubmitting,
            labelText: l10n.tenantFacilityTenantNameLabel,
            isRequired: true,
            textCapitalization: TextCapitalization.words,
            errorText: _nameErrorText,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppTextField(
            controller: _slugController,
            enabled: widget.canSubmit && !submission.isSubmitting,
            labelText: l10n.tenantFacilityTenantSlugLabel,
            errorText: _slugErrorText,
          ),
          AppSwitchField(
            title: l10n.tenantFacilityActiveLabel,
            value: _isActive,
            enabled: widget.canSubmit && !submission.isSubmitting,
            onChanged: (bool value) {
              setState(() {
                _isActive = value;
              });
            },
          ),
          AppCurrencySelectField(
            value: _currency,
            enabled: widget.canSubmit && !submission.isSubmitting,
            labelText: l10n.tenantFacilityDefaultCurrencyLabel,
            helperText: l10n.tenantFacilityTenantDefaultCurrencyHelper,
            onChanged: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return;
              }
              setState(() {
                _currency = value.trim().toUpperCase();
              });
            },
          ),
          if (_similarMatches.isNotEmpty)
            TenantSimilarityWarningPanel(matches: _similarMatches),
          if (!widget.hideSubmitButton)
            _SubmitButton(
              enabled: widget.canSubmit,
              isLoading: submission.isSubmitting,
              label: widget.isCreate
                  ? l10n.tenantFacilityCreateTenantAction
                  : l10n.tenantFacilitySaveTenantAction,
              onPressed: _submit,
              permissionDeniedMessage: widget.permissionDeniedMessage,
            )
          else
            _SubmissionFeedback(
              enabled: widget.canSubmit,
              failure: submission.failure,
              permissionDeniedMessage: widget.permissionDeniedMessage,
            ),
        ],
      ),
    );

    if (widget.framed) {
      return AppScreenSection(
        title: widget.isCreate
            ? l10n.tenantFacilityCreateTenantTitle
            : l10n.tenantFacilityTenantSectionTitle,
        body: sectionBody,
        child: form,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          sectionBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        form,
      ],
    );
  }

  Future<bool> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return false;
    }

    if (widget.isCreate) {
      final bool canProceed = await _guardAgainstDuplicates();
      if (!canProceed) {
        return false;
      }
    }

    return ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveTenant(
          id: widget.isCreate ? null : widget.tenant?.id,
          name: _nameController.text,
          slug: _slugController.text,
          isActive: _isActive,
          currency: resolveDefaultCurrency(tenantCurrency: _currency),
          refreshSetup: widget.refreshSetupAfterSave,
        );
  }

  Future<bool> _guardAgainstDuplicates() async {
    final AppLocalizations l10n = context.l10n;
    final List<TenantProfile> existing = await _loadExistingTenants();
    final TenantDuplicateCheckResult result = checkTenantDuplicates(
      name: _nameController.text,
      slug: _slugController.text,
      existing: existing,
      excludeTenantId: widget.tenant?.id,
    );

    if (result.hasExactConflict) {
      setState(() {
        _nameErrorText = result.exactNameConflict
            ? l10n.tenantFacilityTenantNameAlreadyInUse
            : null;
        _slugErrorText = result.exactSlugConflict
            ? l10n.tenantFacilityTenantSlugAlreadyInUse
            : null;
        _similarMatches = const <TenantSimilarityMatch>[];
      });
      return false;
    }

    final List<TenantSimilarityMatch> similarMatches =
        result.nonExactSimilarMatches;
    if (similarMatches.isEmpty || _similarityAccepted) {
      setState(() {
        _similarMatches = const <TenantSimilarityMatch>[];
      });
      return true;
    }

    if (!mounted) {
      return false;
    }

    final bool proceed = await showTenantSimilarityDialog(
      context,
      matches: similarMatches,
    );
    if (!mounted) {
      return false;
    }
    if (!proceed) {
      setState(() {
        _similarMatches = similarMatches;
      });
      return false;
    }

    setState(() {
      _similarMatches = similarMatches;
      _similarityAccepted = true;
    });
    return true;
  }

  Future<List<TenantProfile>> _loadExistingTenants() async {
    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final String name = _nameController.text.trim();
    final String slug = _slugController.text.trim();
    final Set<String> seenIds = <String>{};
    final List<TenantProfile> tenants = <TenantProfile>[];

    Future<void> appendMatches(String? search) async {
      final Result<AppPage<TenantProfile>> result = await repository
          .listTenants(request: _duplicateLookupRequest, search: search);
      result.when(
        success: (AppPage<TenantProfile> page) {
          for (final TenantProfile tenant in page.items) {
            if (seenIds.add(tenant.id)) {
              tenants.add(tenant);
            }
          }
        },
        failure: (_) {},
      );
    }

    await appendMatches(name.isEmpty ? null : name);
    if (slug.isNotEmpty && slug != name) {
      await appendMatches(slug);
    }
    if (tenants.isEmpty) {
      await appendMatches(null);
    }

    return tenants;
  }
}

class _FacilityProfileForm extends ConsumerStatefulWidget {
  const _FacilityProfileForm({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
    this.tenantId,
    this.facility,
    this.requireTenantPicker = false,
    this.hideSubmitButton = false,
    this.refreshSetupAfterSave = true,
    this.registerSubmitHandler,
    this.onDialogStateChanged,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;
  final String? tenantId;
  final FacilityProfile? facility;
  final bool requireTenantPicker;
  final bool hideSubmitButton;
  final bool refreshSetupAfterSave;
  final _ProfileFormSubmitRegistrar? registerSubmitHandler;
  final VoidCallback? onDialogStateChanged;

  @override
  ConsumerState<_FacilityProfileForm> createState() =>
      _FacilityProfileFormState();
}

class _FacilityProfileFormState extends ConsumerState<_FacilityProfileForm> {
  static const AppPageRequest _duplicateLookupRequest = AppPageRequest(
    pageSize: 100,
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressLineController;
  late final TextEditingController _cityController;
  late FacilitySetupType _type;
  late bool _isActive;
  late String _currency;
  String? _existingLogoUrl;
  String? _logoFileName;
  List<int>? _logoBytes;
  String? _logoMimeType;
  bool _logoCleared = false;
  AppImageUploadPendingItem? _pendingLogoItem;
  String? _selectedTenantId;
  String? _selectedCountry;
  List<TenantProfile> _tenantOptions = const <TenantProfile>[];
  bool _loadingTenants = false;
  bool _loadingContact = false;
  AppFailure? _tenantLoadFailure;
  String? _nameErrorText;
  List<FacilitySimilarityMatch> _similarMatches =
      const <FacilitySimilarityMatch>[];
  bool _similarityAccepted = false;

  String _baselineName = '';
  FacilitySetupType _baselineType = FacilitySetupType.hospital;
  bool _baselineIsActive = true;
  String _baselineCurrency = appDefaultCurrencyCode;
  String? _baselinePhone;
  String? _baselineEmail;
  String? _baselineAddressLine1;
  String? _baselineCity;
  String? _baselineCountry;
  String? _baselineLogoUrl;

  FacilityProfile? get _activeFacility => widget.facility;

  bool get _isCreate => widget.facility == null;

  String? get _resolvedTenantId {
    if (widget.requireTenantPicker) {
      return _selectedTenantId ?? widget.tenantId;
    }

    return _selectedTenantId ??
        widget.tenantId ??
        widget.snapshot.tenant?.mutationId ??
        widget.snapshot.tenant?.id ??
        _activeFacility?.tenantId;
  }

  /// Prefer a UUID mutation id when the selected tenant is known by public id.
  String _resolveMutationTenantId(String tenantId) {
    final String normalized = tenantId.trim();
    if (normalized.isEmpty) {
      return normalized;
    }

    final TenantProfile? fromOptions = _tenantOptions
        .where(
          (TenantProfile tenant) =>
              tenant.id == normalized ||
              tenant.mutationId == normalized ||
              tenant.displayId == normalized ||
              tenant.slug == normalized,
        )
        .firstOrNull;
    if (fromOptions != null) {
      return fromOptions.mutationId;
    }

    final TenantProfile? fromSnapshot = widget.snapshot.tenant;
    if (fromSnapshot != null &&
        (fromSnapshot.id == normalized ||
            fromSnapshot.mutationId == normalized ||
            fromSnapshot.displayId == normalized ||
            fromSnapshot.slug == normalized)) {
      return fromSnapshot.mutationId;
    }

    return normalized;
  }

  bool get _hasSelectedTenant => (_resolvedTenantId ?? '').trim().isNotEmpty;

  bool _canSave() => widget.canSubmit && _hasSelectedTenant;

  @override
  void initState() {
    super.initState();
    final FacilityProfile? facility = _activeFacility;
    // Create must start blank — never inherit contact/logo from setup snapshot.
    final FacilityContactAddress contact = _isCreate
        ? const FacilityContactAddress()
        : widget.snapshot.contactAddress;
    _selectedTenantId =
        widget.tenantId ??
        (_isCreate ? null : widget.snapshot.tenant?.id) ??
        facility?.tenantId;
    _nameController = TextEditingController(text: facility?.name ?? '');
    _existingLogoUrl = facility?.logoUrl;
    _phoneController = TextEditingController(text: contact.phone ?? '');
    _emailController = TextEditingController(text: contact.email ?? '');
    _addressLineController = TextEditingController(
      text: contact.addressLine1 ?? '',
    );
    _cityController = TextEditingController(text: contact.city ?? '');
    _selectedCountry = contact.country;
    _type = facility?.type ?? FacilitySetupType.hospital;
    _isActive = facility?.isActive ?? true;
    _currency = resolveDefaultCurrency(
      facilityCurrency: facility?.currency,
      tenantCurrency: widget.snapshot.tenant?.currency,
    );
    _captureBaseline();
    _nameController.addListener(_handleNameChanged);
    if (widget.requireTenantPicker) {
      unawaited(_loadTenantOptions());
    }
    if (!_isCreate) {
      unawaited(_hydrateEditContact());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerWithDialog();
    });
  }

  void _captureBaseline() {
    _baselineName = _nameController.text.trim();
    _baselineType = _type;
    _baselineIsActive = _isActive;
    _baselineCurrency = _currency.trim().toUpperCase();
    _baselinePhone = _normalizedOptional(_phoneController.text);
    _baselineEmail = _normalizedOptional(_emailController.text);
    _baselineAddressLine1 = _normalizedOptional(_addressLineController.text);
    _baselineCity = _normalizedOptional(_cityController.text);
    _baselineCountry = _normalizedOptional(_selectedCountry);
    _baselineLogoUrl = _logoCleared
        ? null
        : _normalizedOptional(_existingLogoUrl);
  }

  static String? _normalizedOptional(String? value) {
    final String? normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _coalescePreserved(String current, String? baseline) {
    final String? normalized = _normalizedOptional(current);
    if (normalized != null) {
      return normalized;
    }
    return baseline ?? '';
  }

  String? _coalesceOptionalPreserved(String? current, String? baseline) {
    final String? normalized = _normalizedOptional(current);
    return normalized ?? baseline;
  }

  Future<void> _hydrateEditContact() async {
    final FacilityProfile? facility = _activeFacility;
    if (facility == null) {
      return;
    }
    final FacilityProfile editingFacility = facility;

    final FacilityContactAddress existing = widget.snapshot.contactAddress;
    final bool contactMissing =
        _normalizedOptional(existing.phone) == null &&
        _normalizedOptional(existing.email) == null &&
        _normalizedOptional(existing.addressLine1) == null &&
        _normalizedOptional(existing.city) == null &&
        _normalizedOptional(existing.country) == null;
    final bool logoMissing = _normalizedOptional(_existingLogoUrl) == null;

    if (!contactMissing && !logoMissing) {
      _captureBaseline();
      return;
    }

    setState(() {
      _loadingContact = true;
    });

    final Result<FacilitySetupSnapshot> result = await ref
        .read(tenantFacilityRepositoryProvider)
        .loadSetup(
          facilityId: editingFacility.mutationId,
          tenantId: editingFacility.tenantId,
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (FacilitySetupSnapshot snapshot) {
        final FacilityContactAddress contact = snapshot.contactAddress;
        final FacilityProfile loadedFacility =
            snapshot.facility ?? editingFacility;
        setState(() {
          _loadingContact = false;
          if (_normalizedOptional(_nameController.text) == null &&
              loadedFacility.name.trim().isNotEmpty) {
            _nameController.text = loadedFacility.name;
          }
          _type = loadedFacility.type;
          _isActive = loadedFacility.isActive;
          _currency = resolveDefaultCurrency(
            facilityCurrency: loadedFacility.currency,
            tenantCurrency:
                snapshot.tenant?.currency ?? widget.snapshot.tenant?.currency,
          );
          if (logoMissing) {
            _existingLogoUrl = loadedFacility.logoUrl;
          }
          if (contactMissing) {
            _phoneController.text = contact.phone ?? '';
            _emailController.text = contact.email ?? '';
            _addressLineController.text = contact.addressLine1 ?? '';
            _cityController.text = contact.city ?? '';
            _selectedCountry = contact.country;
          }
          _captureBaseline();
        });
        _notifyDialogState();
      },
      failure: (_) {
        setState(() {
          _loadingContact = false;
        });
        _captureBaseline();
      },
    );
  }

  void _registerWithDialog() {
    widget.registerSubmitHandler?.call(
      _submit,
      canSave: _canSave,
      onFormStateChanged: widget.onDialogStateChanged,
    );
  }

  void _handleNameChanged() {
    if (_nameErrorText != null ||
        _similarMatches.isNotEmpty ||
        _similarityAccepted) {
      setState(() {
        _nameErrorText = null;
        _similarMatches = const <FacilitySimilarityMatch>[];
        _similarityAccepted = false;
      });
      widget.onDialogStateChanged?.call();
    }
  }

  void _notifyDialogState() {
    if (!mounted) {
      return;
    }
    _registerWithDialog();
    widget.onDialogStateChanged?.call();
  }

  Future<void> _loadTenantOptions() async {
    setState(() {
      _loadingTenants = true;
      _tenantLoadFailure = null;
    });
    final result = await ref
        .read(tenantFacilityRepositoryProvider)
        .listTenants(request: const AppPageRequest(pageSize: 100));
    if (!mounted) return;
    result.when(
      success: (AppPage<TenantProfile> page) {
        setState(() {
          _loadingTenants = false;
          _tenantOptions = page.items;
          if (widget.tenantId != null && widget.tenantId!.trim().isNotEmpty) {
            _selectedTenantId = widget.tenantId;
          }
        });
        _notifyDialogState();
      },
      failure: (AppFailure failure) {
        setState(() {
          _loadingTenants = false;
          _tenantLoadFailure = failure;
        });
        _notifyDialogState();
      },
    );
  }

  @override
  void didUpdateWidget(_FacilityProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hideSubmitButton) {
      return;
    }
    if (oldWidget.snapshot.facility?.id != widget.snapshot.facility?.id) {
      _nameController.text = widget.snapshot.facility?.name ?? '';
      _existingLogoUrl = widget.snapshot.facility?.logoUrl;
      _logoFileName = null;
      _logoBytes = null;
      _logoMimeType = null;
      _logoCleared = false;
      _pendingLogoItem = null;
      _phoneController.text = widget.snapshot.contactAddress.phone ?? '';
      _emailController.text = widget.snapshot.contactAddress.email ?? '';
      _addressLineController.text =
          widget.snapshot.contactAddress.addressLine1 ?? '';
      _cityController.text = widget.snapshot.contactAddress.city ?? '';
      _selectedCountry = widget.snapshot.contactAddress.country;
      _type = widget.snapshot.facility?.type ?? FacilitySetupType.hospital;
      _isActive = widget.snapshot.facility?.isActive ?? true;
      _currency = resolveDefaultCurrency(
        facilityCurrency: widget.snapshot.facility?.currency,
        tenantCurrency: widget.snapshot.tenant?.currency,
      );
      _captureBaseline();
      _notifyDialogState();
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressLineController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (!_hasSelectedTenant) {
      return;
    }
    final String facilityName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_activeFacility?.name ?? 'facility');
    final AppImageUploadPendingItem? picked = await pickAppImageFile(
      context.l10n,
      context: context,
      typeGroupLabel: 'facility-logo',
      showCropAspectPresets: true,
      preferredFileName: buildFacilityLogoFileName(facilityName),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _pendingLogoItem = picked;
      _logoFileName = picked.fileName;
      _logoBytes = picked.bytes;
      _logoMimeType = picked.mimeType;
      _logoCleared = false;
    });
  }

  void _clearLogo() {
    setState(() {
      _pendingLogoItem = null;
      _logoFileName = null;
      _logoBytes = null;
      _logoMimeType = null;
      _existingLogoUrl = null;
      _logoCleared = true;
    });
  }

  List<AppImageUploadPendingItem> get _pendingLogoItems {
    if (_pendingLogoItem == null) {
      return const <AppImageUploadPendingItem>[];
    }
    return <AppImageUploadPendingItem>[_pendingLogoItem!];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canEditBase = widget.canSubmit && !submission.isSubmitting;
    final bool fieldsEnabled =
        canEditBase && _hasSelectedTenant && !_loadingContact;
    final bool requireFields = _isCreate;

    final Widget form = Form(
      key: _formKey,
      child: AppFormSection(
        children: <Widget>[
          if (_loadingContact)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          if (widget.requireTenantPicker) ...<Widget>[
            if (_loadingTenants)
              const Center(child: CircularProgressIndicator())
            else if (_tenantLoadFailure != null)
              AppFailureStateView(
                failure: _tenantLoadFailure!,
                onRetry: () => unawaited(_loadTenantOptions()),
              )
            else
              AppSelectField<String>.searchable(
                value: _selectedTenantId,
                enabled: canEditBase,
                labelText: l10n.tenantFacilitySelectTenantLabel,
                isRequired: true,
                menuHeight: 320,
                options: _tenantOptions
                    .map(
                      (TenantProfile tenant) => AppSelectOption<String>(
                        value: tenant.id,
                        label: tenant.name,
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? value) {
                  setState(() {
                    _selectedTenantId = value;
                  });
                  _notifyDialogState();
                },
                validator: (String? value) => (value ?? '').trim().isEmpty
                    ? l10n.validationRequired
                    : null,
              ),
            if (_tenantOptions.isEmpty &&
                !_loadingTenants &&
                _tenantLoadFailure == null) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                l10n.tenantFacilitySelectTenantLoadError,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.md),
          ],
          if (widget.snapshot.facilities.length > 1 && widget.facility == null)
            AppSelectField<String>.searchable(
              value: widget.snapshot.facility?.id,
              enabled: !submission.isSubmitting,
              labelText: l10n.tenantFacilityFacilitySelectLabel,
              menuHeight: 320,
              options: <AppSelectOption<String>>[
                for (final FacilityProfile facility
                    in widget.snapshot.facilities)
                  AppSelectOption<String>(
                    value: facility.id,
                    label: facility.name,
                  ),
              ],
              onChanged: (String? value) {
                if (value == null || value == widget.snapshot.facility?.id) {
                  return;
                }
                ref
                    .read(tenantFacilitySetupControllerProvider.notifier)
                    .selectFacility(value);
              },
            ),
          if (_similarMatches.isNotEmpty)
            FacilitySimilarityWarningPanel(matches: _similarMatches),
          AppTextField(
            controller: _nameController,
            enabled: fieldsEnabled,
            labelText: l10n.authFacilityNameLabel,
            isRequired: requireFields,
            textCapitalization: TextCapitalization.words,
            errorText: _nameErrorText,
            validator: requireFields
                ? AppValidators.requiredText(l10n.validationRequired)
                : null,
          ),
          AppSelectField<FacilitySetupType>(
            value: _type,
            enabled: fieldsEnabled,
            labelText: l10n.authFacilityTypeLabel,
            isRequired: requireFields,
            options: <AppSelectOption<FacilitySetupType>>[
              for (final type in FacilitySetupType.values)
                AppSelectOption<FacilitySetupType>(
                  value: type,
                  label: tenantFacilityFacilityTypeLabel(l10n, type),
                  leadingIcon: Icon(tenantFacilityFacilityTypeIcon(type)),
                ),
            ],
            onChanged: (FacilitySetupType? value) {
              if (value != null) {
                setState(() {
                  _type = value;
                });
              }
            },
          ),
          AppCurrencySelectField(
            value: _currency,
            enabled: fieldsEnabled,
            labelText: l10n.tenantFacilityDefaultCurrencyLabel,
            helperText: l10n.tenantFacilityDefaultCurrencyHelper,
            onChanged: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return;
              }
              setState(() {
                _currency = value.trim().toUpperCase();
              });
            },
          ),
          AppImageUploadField(
            label: l10n.tenantFacilityLogoLabel,
            helperText: l10n.tenantFacilityLogoHelper,
            chooseLabel: l10n.tenantFacilityChooseLogoAction,
            removeLabel: l10n.tenantFacilityRemoveLogoAction,
            enabled: fieldsEnabled,
            existingImageUrl: _logoCleared ? null : _existingLogoUrl,
            pendingItems: _pendingLogoItems,
            previewSize: 104,
            onChoose: _pickLogo,
            onClear: fieldsEnabled ? _clearLogo : null,
          ),
          AppPhoneField(
            controller: _phoneController,
            enabled: fieldsEnabled,
            labelText: l10n.profilePhoneLabel,
            countryLabelText: l10n.appPhoneCountryLabel,
            countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
            countryNoResultsText: l10n.appPhoneCountryNoResults,
            numberLabelText: l10n.appPhoneNumberLabel,
            numberHintText: l10n.appPhoneNumberHint,
            invalidPhoneMessage: l10n.appPhoneInvalidMessage,
            requiredMessage: l10n.validationRequired,
            isRequired: requireFields,
          ),
          AppEmailField(
            controller: _emailController,
            enabled: fieldsEnabled,
            labelText: l10n.profileEmailLabel,
            isRequired: requireFields,
            requiredMessage: l10n.validationRequired,
            invalidEmailMessage: l10n.authEmailInvalidMessage,
          ),
          AppTextField(
            controller: _addressLineController,
            enabled: fieldsEnabled,
            labelText: l10n.tenantFacilityAddressLineLabel,
            textCapitalization: TextCapitalization.words,
          ),
          _TwoColumnFields(
            left: AppTextField(
              controller: _cityController,
              enabled: fieldsEnabled,
              labelText: l10n.tenantFacilityCityLabel,
              textCapitalization: TextCapitalization.words,
            ),
            right: AppCountryField(
              value: _selectedCountry,
              enabled: fieldsEnabled,
              labelText: l10n.tenantFacilityCountryLabel,
              onChanged: (String? value) {
                setState(() {
                  _selectedCountry = value;
                });
              },
            ),
          ),
          AppSwitchField(
            title: l10n.tenantFacilityActiveLabel,
            value: _isActive,
            enabled: fieldsEnabled,
            onChanged: (bool value) {
              setState(() {
                _isActive = value;
              });
            },
          ),
          if (!widget.hideSubmitButton)
            _SubmitButton(
              enabled: widget.canSubmit && _hasSelectedTenant,
              isLoading: submission.isSubmitting,
              label: _isCreate
                  ? l10n.tenantFacilitySaveFacilityAction
                  : l10n.tenantFacilityEditFacilityAction,
              onPressed: _submit,
            )
          else
            _SubmissionFeedback(
              enabled: widget.canSubmit && _hasSelectedTenant,
              failure: submission.failure,
            ),
        ],
      ),
    );

    if (widget.framed) {
      return AppScreenSection(
        title: _isCreate
            ? l10n.tenantFacilityCreateFacilityTitle
            : l10n.tenantFacilityEditFacilityTitle,
        body: l10n.tenantFacilityFacilitySectionBody,
        child: form,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _isCreate
              ? l10n.tenantFacilityCreateFacilityTitle
              : l10n.tenantFacilityEditFacilityTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          l10n.tenantFacilityFacilitySectionBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        form,
      ],
    );
  }

  Future<bool> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return false;
    }

    final String? tenantId = _resolvedTenantId;
    if (tenantId == null) {
      return false;
    }

    final String resolvedName = _isCreate
        ? _nameController.text.trim()
        : _coalescePreserved(_nameController.text, _baselineName);
    if (resolvedName.isEmpty) {
      setState(() {
        _nameErrorText = context.l10n.validationRequired;
      });
      return false;
    }

    final String? resolvedPhone = _isCreate
        ? _normalizedOptional(_phoneController.text)
        : _coalesceOptionalPreserved(_phoneController.text, _baselinePhone);
    final String? resolvedEmail = _isCreate
        ? _normalizedOptional(_emailController.text)
        : _coalesceOptionalPreserved(_emailController.text, _baselineEmail);
    final String? resolvedAddress = _isCreate
        ? _normalizedOptional(_addressLineController.text)
        : _coalesceOptionalPreserved(
            _addressLineController.text,
            _baselineAddressLine1,
          );
    final String? resolvedCity = _isCreate
        ? _normalizedOptional(_cityController.text)
        : _coalesceOptionalPreserved(_cityController.text, _baselineCity);
    final String? resolvedCountry = _isCreate
        ? _normalizedOptional(_selectedCountry)
        : _coalesceOptionalPreserved(_selectedCountry, _baselineCountry);
    final String? resolvedLogoUrl = _logoCleared
        ? null
        : (_normalizedOptional(_existingLogoUrl) ?? _baselineLogoUrl);

    if (!_isCreate) {
      final List<_FacilityFieldChange> changes = _buildFacilityChanges(
        name: resolvedName,
        type: _type,
        isActive: _isActive,
        currency: _currency.trim().toUpperCase(),
        phone: resolvedPhone,
        email: resolvedEmail,
        addressLine1: resolvedAddress,
        city: resolvedCity,
        country: resolvedCountry,
        logoChanged: _logoCleared || _logoBytes != null,
        logoCleared: _logoCleared,
        logoReplaced: _logoBytes != null,
      );
      if (changes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.tenantFacilityNoFacilityChangesMessage,
                ),
              ),
            );
        }
        return false;
      }

      final bool confirmed = await _confirmFacilityChanges(changes);
      if (!confirmed) {
        return false;
      }
    }

    final bool canProceed = await _guardAgainstDuplicates(
      tenantId,
      name: resolvedName,
    );
    if (!canProceed) {
      return false;
    }

    final FacilityProfile? editingFacility = widget.facility ?? _activeFacility;
    final String resolvedTenantId = _resolveMutationTenantId(tenantId);
    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveFacility(
          id: editingFacility?.mutationId ?? editingFacility?.id,
          tenantId: resolvedTenantId,
          name: resolvedName,
          type: _type,
          isActive: _isActive,
          logoUrl: resolvedLogoUrl,
          removeLogo: _logoCleared,
          currency: _currency.trim().toUpperCase(),
          logoBytes: _logoBytes,
          logoFileName: _logoFileName,
          logoMimeType: _logoMimeType,
          phone: resolvedPhone,
          email: resolvedEmail,
          addressLine1: resolvedAddress,
          city: resolvedCity,
          country: resolvedCountry,
          refreshSetup: widget.refreshSetupAfterSave,
        );

    if (!saved && mounted) {
      final AppFailure? failure = ref
          .read(tenantFacilitySetupSubmissionProvider)
          .failure;
      if (failure?.messageKey == 'errors.facility.duplicate_name') {
        setState(() {
          _nameErrorText = context.l10n.tenantFacilityFacilityNameAlreadyInUse;
        });
      }
    }

    return saved;
  }

  List<_FacilityFieldChange> _buildFacilityChanges({
    required String name,
    required FacilitySetupType type,
    required bool isActive,
    required String currency,
    required String? phone,
    required String? email,
    required String? addressLine1,
    required String? city,
    required String? country,
    required bool logoChanged,
    required bool logoCleared,
    required bool logoReplaced,
  }) {
    final AppLocalizations l10n = context.l10n;
    final List<_FacilityFieldChange> changes = <_FacilityFieldChange>[];

    void addChange(String label, String? previous, String? next) {
      final String previousValue = (previous ?? '').trim();
      final String nextValue = (next ?? '').trim();
      if (previousValue == nextValue) {
        return;
      }
      changes.add(
        _FacilityFieldChange(
          label: label,
          previousValue: previousValue.isEmpty ? '—' : previousValue,
          nextValue: nextValue.isEmpty ? '—' : nextValue,
        ),
      );
    }

    addChange(l10n.authFacilityNameLabel, _baselineName, name);
    addChange(
      l10n.authFacilityTypeLabel,
      tenantFacilityFacilityTypeLabel(l10n, _baselineType),
      tenantFacilityFacilityTypeLabel(l10n, type),
    );
    addChange(
      l10n.tenantFacilityActiveLabel,
      _baselineIsActive
          ? l10n.tenantFacilityStatusActive
          : l10n.tenantFacilityStatusInactive,
      isActive
          ? l10n.tenantFacilityStatusActive
          : l10n.tenantFacilityStatusInactive,
    );
    addChange(
      l10n.tenantFacilityDefaultCurrencyLabel,
      _baselineCurrency,
      currency,
    );
    addChange(l10n.profilePhoneLabel, _baselinePhone, phone);
    addChange(l10n.profileEmailLabel, _baselineEmail, email);
    addChange(
      l10n.tenantFacilityAddressLineLabel,
      _baselineAddressLine1,
      addressLine1,
    );
    addChange(l10n.tenantFacilityCityLabel, _baselineCity, city);
    addChange(l10n.tenantFacilityCountryLabel, _baselineCountry, country);
    if (logoChanged) {
      final String? previousUrl = _normalizedOptional(_baselineLogoUrl);
      final List<int>? nextBytes = logoReplaced ? _logoBytes : null;
      changes.add(
        _FacilityFieldChange(
          label: l10n.tenantFacilityLogoLabel,
          previousValue: previousUrl == null
              ? l10n.tenantFacilityFacilityDetailsNoLogo
              : l10n.tenantFacilityLogoLabel,
          nextValue: logoCleared
              ? l10n.tenantFacilityLogoRemovedLabel
              : l10n.tenantFacilityLogoAddedLabel,
          isLogo: true,
          previousLogoUrl: previousUrl,
          nextLogoBytes: nextBytes,
          logoCleared: logoCleared,
        ),
      );
    }

    return changes;
  }

  Future<bool> _confirmFacilityChanges(
    List<_FacilityFieldChange> changes,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        final ColorScheme colorScheme = theme.colorScheme;
        return AppDialog(
          title: Text(l10n.tenantFacilityConfirmFacilityUpdateTitle),
          icon: const Icon(Icons.compare_arrows_outlined),
          scrollable: true,
          maxWidth: 720,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      SizedBox(width: theme.spacing.sm),
                      Expanded(
                        child: Text(
                          l10n.tenantFacilityConfirmFacilityUpdateBody,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.tenantFacilityFieldPreviousLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      l10n.tenantFacilityFieldNewLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              for (final _FacilityFieldChange change in changes) ...<Widget>[
                _FacilityChangeDiffCard(change: change),
                SizedBox(height: theme.spacing.sm),
              ],
            ],
          ),
          actions: <Widget>[
            AppButton.tertiary(
              label: l10n.commonCancelActionLabel,
              leadingIcon: Icons.close,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppButton.primary(
              label: l10n.tenantFacilityConfirmFacilityUpdateAction,
              leadingIcon: Icons.check,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<bool> _guardAgainstDuplicates(
    String tenantId, {
    required String name,
  }) async {
    final AppLocalizations l10n = context.l10n;
    final FacilityProfile? editingFacility = widget.facility ?? _activeFacility;

    // Editing with an unchanged name cannot be a duplicate of itself.
    if (editingFacility != null &&
        normalizeFacilityName(name) == normalizeFacilityName(_baselineName)) {
      setState(() {
        _nameErrorText = null;
        _similarMatches = const <FacilitySimilarityMatch>[];
      });
      return true;
    }

    final List<FacilityProfile> existing = await _loadExistingFacilities(
      tenantId,
    );
    final FacilityDuplicateCheckResult result = checkFacilityDuplicates(
      name: name,
      existing: existing,
      excludeFacility: editingFacility,
      excludeFacilityId: editingFacility?.mutationId ?? editingFacility?.id,
    );

    if (result.hasExactConflict) {
      setState(() {
        _nameErrorText = l10n.tenantFacilityFacilityNameAlreadyInUse;
        _similarMatches = const <FacilitySimilarityMatch>[];
      });
      widget.onDialogStateChanged?.call();
      return false;
    }

    final List<FacilitySimilarityMatch> similarMatches =
        result.nonExactSimilarMatches;
    if (similarMatches.isEmpty || _similarityAccepted) {
      setState(() {
        _similarMatches = const <FacilitySimilarityMatch>[];
      });
      return true;
    }

    if (!mounted) {
      return false;
    }

    final bool proceed = await showFacilitySimilarityDialog(
      context,
      matches: similarMatches,
    );
    if (!mounted) {
      return false;
    }
    if (!proceed) {
      setState(() {
        _similarMatches = similarMatches;
      });
      widget.onDialogStateChanged?.call();
      return false;
    }

    setState(() {
      _similarMatches = similarMatches;
      _similarityAccepted = true;
    });
    return true;
  }

  Future<List<FacilityProfile>> _loadExistingFacilities(String tenantId) async {
    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final String name = _nameController.text.trim();
    final Set<String> seenIds = <String>{};
    final List<FacilityProfile> facilities = <FacilityProfile>[];

    Future<void> appendMatches(String? search) async {
      final Result<AppPage<FacilityProfile>> result = await repository
          .listFacilities(
            request: _duplicateLookupRequest,
            tenantId: tenantId,
            search: search,
          );
      result.when(
        success: (AppPage<FacilityProfile> page) {
          for (final FacilityProfile facility in page.items) {
            if (seenIds.add(facility.id)) {
              facilities.add(facility);
            }
          }
        },
        failure: (_) {},
      );
    }

    await appendMatches(name.isEmpty ? null : name);
    if (facilities.isEmpty) {
      await appendMatches(null);
    }

    return facilities;
  }
}

const String _noneSelection = tenantFacilityNoneSelection;

class _BranchSetupSection extends ConsumerWidget {
  const _BranchSetupSection({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;

    final Widget content = _SearchableEntityGroup<BranchProfile>(
      title: l10n.tenantFacilityBranchesListTitle,
      items: snapshot.branches,
      emptyLabel: l10n.tenantFacilityNoBranches,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityBranchSearchHint,
      addLabel: l10n.tenantFacilityAddBranchAction,
      canManageRecords: canManageRecords,
      canAdd: canManageRecords,
      onAdd: () => _openBranchDialog(context, snapshot),
      titleBuilder: (BranchProfile branch) => branch.name,
      subtitleBuilder: (BranchProfile branch) => branch.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _activeStatusLabel(l10n, branch.isActive),
      isDeletedBuilder: (BranchProfile branch) => branch.isDeleted,
      onEdit: (BranchProfile branch) {
        if (branch.isDeleted) {
          return;
        }
        _openBranchDialog(context, snapshot, branch: branch);
      },
      onDelete: (BranchProfile branch) => _deleteEntity(
        context: context,
        ref: ref,
        name: branch.name,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteBranch(branch.id),
      ),
      onRestore: (BranchProfile branch) => _restoreEntity(
        context: context,
        ref: ref,
        name: branch.name,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreBranch(branch.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityBranchesSectionTitle,
        body: l10n.tenantFacilityBranchesSectionBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityBranchesOptionalHint,
      child: content,
    );
  }
}

class _DepartmentSetupSection extends ConsumerWidget {
  const _DepartmentSetupSection({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;
    final bool prerequisitesMet = snapshot.facility?.id != null;
    final bool canAdd = canManageRecords && prerequisitesMet;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedFacility
        : null;

    final Widget content = _SearchableEntityGroup<DepartmentProfile>(
      title: l10n.tenantFacilityDepartmentsListTitle,
      items: snapshot.departments,
      emptyLabel: l10n.tenantFacilityNoDepartments,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityDepartmentSearchHint,
      addLabel: l10n.tenantFacilityAddDepartmentAction,
      canManageRecords: canManageRecords,
      canAdd: canAdd,
      onAdd: () => _openDepartmentDialog(context, snapshot),
      titleBuilder: (DepartmentProfile department) => department.name,
      subtitleBuilder: (DepartmentProfile department) => department.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _departmentSubtitle(l10n, snapshot, department),
      isDeletedBuilder: (DepartmentProfile department) => department.isDeleted,
      onEdit: (DepartmentProfile department) {
        if (department.isDeleted) {
          return;
        }
        _openDepartmentDialog(context, snapshot, department: department);
      },
      onDelete: (DepartmentProfile department) => _deleteEntity(
        context: context,
        ref: ref,
        name: department.name,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteDepartment(department.id),
      ),
      onRestore: (DepartmentProfile department) => _restoreEntity(
        context: context,
        ref: ref,
        name: department.name,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreDepartment(department.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityDepartmentsListTitle,
        body: l10n.tenantFacilityDepartmentsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityDepartmentsModalBody,
      blockedMessage: blockedMessage,
      child: content,
    );
  }
}

class _UnitSetupSection extends ConsumerWidget {
  const _UnitSetupSection({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;
    final bool prerequisitesMet = snapshot.departments.isNotEmpty;
    final bool canAdd = canManageRecords && prerequisitesMet;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedDepartmentForUnits
        : null;

    final Widget content = _SearchableEntityGroup<UnitProfile>(
      title: l10n.tenantFacilityUnitsListTitle,
      items: snapshot.units,
      emptyLabel: l10n.tenantFacilityNoUnits,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityUnitSearchHint,
      addLabel: l10n.tenantFacilityAddUnitAction,
      canManageRecords: canManageRecords,
      canAdd: canAdd,
      onAdd: () => _openUnitDialog(context, snapshot),
      titleBuilder: (UnitProfile unit) => unit.name,
      subtitleBuilder: (UnitProfile unit) => unit.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _unitSubtitle(l10n, snapshot, unit),
      isDeletedBuilder: (UnitProfile unit) => unit.isDeleted,
      onEdit: (UnitProfile unit) {
        if (unit.isDeleted) {
          return;
        }
        _openUnitDialog(context, snapshot, unit: unit);
      },
      onDelete: (UnitProfile unit) => _deleteEntity(
        context: context,
        ref: ref,
        name: unit.name,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteUnit(unit.id),
      ),
      onRestore: (UnitProfile unit) => _restoreEntity(
        context: context,
        ref: ref,
        name: unit.name,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreUnit(unit.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityUnitsListTitle,
        body: l10n.tenantFacilityUnitsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityUnitsModalBody,
      blockedMessage: blockedMessage,
      child: content,
    );
  }
}

class _WardSetupSection extends ConsumerWidget {
  const _WardSetupSection({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;
    final bool prerequisitesMet = snapshot.departments.isNotEmpty;
    final bool canAdd = canManageRecords && prerequisitesMet;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedDepartmentForWards
        : null;

    final Widget content = _SearchableEntityGroup<WardProfile>(
      title: l10n.tenantFacilityWardsLabel,
      items: snapshot.wards,
      emptyLabel: l10n.tenantFacilityNoWards,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityWardSearchHint,
      addLabel: l10n.tenantFacilityAddWardAction,
      canManageRecords: canManageRecords,
      canAdd: canAdd,
      onAdd: () => _openWardDialog(context, snapshot),
      titleBuilder: (WardProfile ward) => ward.name,
      subtitleBuilder: (WardProfile ward) => ward.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _wardSubtitle(l10n, snapshot, ward),
      isDeletedBuilder: (WardProfile ward) => ward.isDeleted,
      onEdit: (WardProfile ward) {
        if (ward.isDeleted) {
          return;
        }
        _openWardDialog(context, snapshot, ward: ward);
      },
      onDelete: (WardProfile ward) => _deleteEntity(
        context: context,
        ref: ref,
        name: ward.name,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteWard(ward.id),
      ),
      onRestore: (WardProfile ward) => _restoreEntity(
        context: context,
        ref: ref,
        name: ward.name,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreWard(ward.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityWardsLabel,
        body: l10n.tenantFacilityWardsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityWardsModalBody,
      blockedMessage: blockedMessage,
      child: content,
    );
  }
}

class _RoomSetupSection extends ConsumerWidget {
  const _RoomSetupSection({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;
    final bool prerequisitesMet =
        snapshot.departments.isNotEmpty || snapshot.wards.isNotEmpty;
    final bool canAdd = canManageRecords && prerequisitesMet;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedWardOrDepartmentForRooms
        : null;

    final Widget content = _SearchableEntityGroup<RoomProfile>(
      title: l10n.tenantFacilityRoomsLabel,
      items: snapshot.rooms,
      emptyLabel: l10n.tenantFacilityNoRooms,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityRoomSearchHint,
      addLabel: l10n.tenantFacilityAddRoomAction,
      canManageRecords: canManageRecords,
      canAdd: canAdd,
      onAdd: () => _openRoomDialog(context, snapshot),
      titleBuilder: (RoomProfile room) => room.name,
      subtitleBuilder: (RoomProfile room) => room.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _roomSubtitle(l10n, snapshot, room),
      isDeletedBuilder: (RoomProfile room) => room.isDeleted,
      onEdit: (RoomProfile room) {
        if (room.isDeleted) {
          return;
        }
        _openRoomDialog(context, snapshot, room: room);
      },
      onDelete: (RoomProfile room) => _deleteEntity(
        context: context,
        ref: ref,
        name: room.name,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteRoom(room.id),
      ),
      onRestore: (RoomProfile room) => _restoreEntity(
        context: context,
        ref: ref,
        name: room.name,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreRoom(room.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityRoomsLabel,
        body: l10n.tenantFacilityRoomsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityRoomsModalBody,
      blockedMessage: blockedMessage,
      child: content,
    );
  }
}

class _BedSetupSection extends ConsumerWidget {
  const _BedSetupSection({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;
    final bool prerequisitesMet = snapshot.wards.isNotEmpty;
    final bool canAdd = canManageRecords && prerequisitesMet;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedWardsForBeds
        : null;

    final Widget content = _SearchableEntityGroup<BedProfile>(
      title: l10n.tenantFacilityBedsLabel,
      items: snapshot.beds,
      emptyLabel: l10n.tenantFacilityNoBeds,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityBedSearchHint,
      addLabel: l10n.tenantFacilityAddBedAction,
      canManageRecords: canManageRecords,
      canAdd: canAdd,
      onAdd: () => _openBedDialog(context, snapshot),
      titleBuilder: (BedProfile bed) => bed.label,
      subtitleBuilder: (BedProfile bed) => bed.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _bedSubtitle(l10n, snapshot, bed),
      isDeletedBuilder: (BedProfile bed) => bed.isDeleted,
      onEdit: (BedProfile bed) {
        if (bed.isDeleted) {
          return;
        }
        _openBedDialog(context, snapshot, bed: bed);
      },
      onDelete: (BedProfile bed) => _deleteEntity(
        context: context,
        ref: ref,
        name: bed.label,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteBed(bed.id),
      ),
      onRestore: (BedProfile bed) => _restoreEntity(
        context: context,
        ref: ref,
        name: bed.label,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreBed(bed.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityBedsLabel,
        body: l10n.tenantFacilityBedsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityBedsModalBody,
      blockedMessage: blockedMessage,
      child: content,
    );
  }
}

class _ModalSectionBody extends StatelessWidget {
  const _ModalSectionBody({
    required this.body,
    required this.child,
    this.blockedMessage,
  });

  final String body;
  final Widget child;
  final String? blockedMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (blockedMessage != null) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Text(
            blockedMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: theme.spacing.lg),
        child,
      ],
    );
  }
}

class _SearchableEntityGroup<T> extends StatefulWidget {
  const _SearchableEntityGroup({
    required this.title,
    required this.items,
    required this.emptyLabel,
    required this.noResultsLabel,
    required this.searchLabel,
    required this.searchHint,
    required this.addLabel,
    required this.canManageRecords,
    required this.canAdd,
    required this.onAdd,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.isDeletedBuilder,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final String title;
  final List<T> items;
  final String emptyLabel;
  final String noResultsLabel;
  final String searchLabel;
  final String searchHint;
  final String addLabel;
  final bool canManageRecords;
  final bool canAdd;
  final VoidCallback onAdd;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final bool Function(T item) isDeletedBuilder;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;
  final ValueChanged<T> onRestore;

  @override
  State<_SearchableEntityGroup<T>> createState() =>
      _SearchableEntityGroupState<T>();
}

class _SearchableEntityGroupState<T> extends State<_SearchableEntityGroup<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<T> filteredItems = _filteredItems();
    final bool isSearching = _query.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextField(
          controller: _searchController,
          labelText: widget.searchLabel,
          hintText: widget.searchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: isSearching
              ? AppButton(
                  iconOnly: true,
                  leadingIcon: Icons.close,
                  label: l10n.tenantFacilityClearSearchAction,

                  semanticLabel: l10n.tenantFacilityClearSearchAction,
                  tooltip: l10n.tenantFacilityClearSearchAction,
                  onPressed: _clearSearch,
                )
              : null,
          textInputAction: TextInputAction.search,
          onChanged: (String value) {
            setState(() {
              _query = value;
            });
          },
        ),
        SizedBox(height: theme.spacing.md),
        _EntityGroup<T>(
          title: widget.title,
          items: filteredItems,
          emptyLabel: isSearching ? widget.noResultsLabel : widget.emptyLabel,
          addLabel: widget.addLabel,
          canManageRecords: widget.canManageRecords,
          canAdd: widget.canAdd,
          onAdd: widget.onAdd,
          titleBuilder: widget.titleBuilder,
          subtitleBuilder: widget.subtitleBuilder,
          isDeletedBuilder: widget.isDeletedBuilder,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onRestore: widget.onRestore,
        ),
      ],
    );
  }

  List<T> _filteredItems() {
    final String query = _normalizeSearch(_query);
    if (query.isEmpty) {
      return widget.items;
    }

    return widget.items
        .where(
          (T item) => _entitySearchText(
            widget.titleBuilder(item),
            widget.subtitleBuilder(item),
          ).contains(query),
        )
        .toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
    });
  }
}

String _entitySearchText(String title, String subtitle) {
  return _normalizeSearch('$title $subtitle');
}

String _normalizeSearch(String value) {
  return value.trim().toLowerCase();
}

class _EntityGroup<T> extends StatelessWidget {
  const _EntityGroup({
    required this.title,
    required this.items,
    required this.emptyLabel,
    required this.addLabel,
    required this.canManageRecords,
    required this.canAdd,
    required this.onAdd,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.isDeletedBuilder,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final String title;
  final List<T> items;
  final String emptyLabel;
  final String addLabel;
  final bool canManageRecords;
  final bool canAdd;
  final VoidCallback onAdd;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final bool Function(T item) isDeletedBuilder;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;
  final ValueChanged<T> onRestore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            if (canAdd)
              AppButton.secondary(
                label: addLabel,
                leadingIcon: Icons.add,
                onPressed: onAdd,
              ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        if (items.isEmpty)
          Text(
            emptyLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: <Widget>[
              for (final T item in items) ...<Widget>[
                _EntityRow(
                  title: titleBuilder(item),
                  subtitle: subtitleBuilder(item),
                  isDeleted: isDeletedBuilder(item),
                  canEdit: canManageRecords,
                  onEdit: () => onEdit(item),
                  onDelete: () => onDelete(item),
                  onRestore: () => onRestore(item),
                ),
                if (item != items.last) const Divider(height: 1),
              ],
            ],
          ),
      ],
    );
  }
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({
    required this.title,
    required this.subtitle,
    required this.isDeleted,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final String title;
  final String subtitle;
  final bool isDeleted;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? mutedTitleStyle = isDeleted
        ? theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.titleSmall;
    final TextStyle? mutedSubtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: mutedTitleStyle),
                SizedBox(height: theme.spacing.xs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: mutedSubtitleStyle,
                ),
              ],
            ),
          ),
          if (canEdit) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            if (isDeleted)
              AppButton(
                iconOnly: true,
                leadingIcon: Icons.restore_outlined,
                label: l10n.tenantFacilityRestoreStructureAction,
                semanticLabel: l10n.tenantFacilityRestoreStructureAction,
                tooltip: l10n.tenantFacilityRestoreStructureAction,
                onPressed: onRestore,
              )
            else ...<Widget>[
              AppButton(
                iconOnly: true,
                leadingIcon: Icons.edit_outlined,
                label: l10n.tenantFacilityEditAction,

                semanticLabel: l10n.tenantFacilityEditAction,
                onPressed: onEdit,
              ),
              AppButton(
                iconOnly: true,
                icon: Icons.delete_outline,
                label: l10n.tenantFacilityDeleteAction,
                semanticLabel: l10n.tenantFacilityDeleteAction,
                onPressed: onDelete,
                color: theme.statusColors.error,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

final class _FacilityFieldChange {
  const _FacilityFieldChange({
    required this.label,
    required this.previousValue,
    required this.nextValue,
    this.isLogo = false,
    this.previousLogoUrl,
    this.nextLogoBytes,
    this.logoCleared = false,
  });

  final String label;
  final String previousValue;
  final String nextValue;
  final bool isLogo;
  final String? previousLogoUrl;
  final List<int>? nextLogoBytes;
  final bool logoCleared;
}

class _FacilityChangeDiffCard extends StatelessWidget {
  const _FacilityChangeDiffCard({required this.change});

  final _FacilityFieldChange change;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              change.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 420;
                final Widget previousPane = _FacilityChangeValuePane(
                  tone: _FacilityChangePaneTone.previous,
                  caption: l10n.tenantFacilityFieldPreviousLabel,
                  textValue: change.previousValue,
                  isLogo: change.isLogo,
                  logoUrl: change.previousLogoUrl,
                  emptyLogoLabel: l10n.tenantFacilityFacilityDetailsNoLogo,
                );
                final Widget nextPane = _FacilityChangeValuePane(
                  tone: _FacilityChangePaneTone.next,
                  caption: l10n.tenantFacilityFieldNewLabel,
                  textValue: change.nextValue,
                  isLogo: change.isLogo,
                  logoBytes: change.nextLogoBytes,
                  logoCleared: change.logoCleared,
                  emptyLogoLabel: change.logoCleared
                      ? l10n.tenantFacilityLogoRemovedLabel
                      : l10n.tenantFacilityFacilityDetailsNoLogo,
                );
                final Widget arrow = Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: stacked ? 0 : theme.spacing.sm,
                    vertical: stacked ? theme.spacing.sm : 0,
                  ),
                  child: Icon(
                    stacked
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_forward_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                );

                if (stacked) {
                  return Column(
                    children: <Widget>[previousPane, arrow, nextPane],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: previousPane),
                    arrow,
                    Expanded(child: nextPane),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _FacilityChangePaneTone { previous, next }

class _FacilityChangeValuePane extends StatelessWidget {
  const _FacilityChangeValuePane({
    required this.tone,
    required this.caption,
    required this.textValue,
    required this.isLogo,
    required this.emptyLogoLabel,
    this.logoUrl,
    this.logoBytes,
    this.logoCleared = false,
  });

  final _FacilityChangePaneTone tone;
  final String caption;
  final String textValue;
  final bool isLogo;
  final String emptyLogoLabel;
  final String? logoUrl;
  final List<int>? logoBytes;
  final bool logoCleared;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isPrevious = tone == _FacilityChangePaneTone.previous;
    final Color background = isPrevious
        ? colorScheme.errorContainer.withValues(alpha: 0.28)
        : colorScheme.primaryContainer.withValues(alpha: 0.45);
    final Color border = isPrevious
        ? colorScheme.error.withValues(alpha: 0.22)
        : colorScheme.primary.withValues(alpha: 0.28);
    final Color captionColor = isPrevious
        ? colorScheme.onErrorContainer
        : colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (isLogo)
              _FacilityConfirmLogoPreview(
                url: logoUrl,
                bytes: logoBytes,
                cleared: logoCleared,
                emptyLabel: emptyLogoLabel,
                emphasizeRemoval: isPrevious || logoCleared,
              )
            else ...<Widget>[
              Text(
                caption,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: captionColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                textValue,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: isPrevious ? TextDecoration.lineThrough : null,
                  color: isPrevious
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FacilityConfirmLogoPreview extends StatelessWidget {
  const _FacilityConfirmLogoPreview({
    required this.emptyLabel,
    required this.emphasizeRemoval,
    this.url,
    this.bytes,
    this.cleared = false,
  });

  final String? url;
  final List<int>? bytes;
  final bool cleared;
  final String emptyLabel;
  final bool emphasizeRemoval;

  static const double _previewHeight = 128;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool hasBytes = bytes != null && bytes!.isNotEmpty;
    final bool hasUrl = (url ?? '').trim().isNotEmpty;
    final Widget image;

    if (hasBytes) {
      image = Image.memory(
        Uint8List.fromList(bytes!),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                Icon(Icons.broken_image_outlined, color: colorScheme.error),
      );
    } else if (hasUrl && !cleared) {
      final String? resolvedUrl = resolveAppMediaUrl(
        url,
        ProviderScope.containerOf(
          context,
          listen: false,
        ).read(appConfigProvider).apiBaseUrl,
      );
      image = Image.network(
        resolvedUrl ?? url!.trim(),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                Icon(Icons.broken_image_outlined, color: colorScheme.error),
      );
    } else {
      image = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            cleared
                ? Icons.hide_image_outlined
                : Icons.image_not_supported_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 28,
          ),
          SizedBox(height: theme.spacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              emptyLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: double.infinity,
          height: _previewHeight,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Padding(padding: EdgeInsets.all(theme.spacing.sm), child: image),
              if (emphasizeRemoval && (hasUrl || cleared) && !hasBytes)
                ColoredBox(
                  color: colorScheme.error.withValues(alpha: 0.12),
                  child: const SizedBox.expand(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchFormDialog extends ConsumerStatefulWidget {
  const _BranchFormDialog({required this.snapshot, this.branch});

  final FacilitySetupSnapshot snapshot;
  final BranchProfile? branch;

  @override
  ConsumerState<_BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends ConsumerState<_BranchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.branch?.name);
    _isActive = widget.branch?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.branch != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditBranchTitle
            : l10n.tenantFacilityAddBranchTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBranchNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSwitchField(
              title: l10n.tenantFacilityActiveLabel,
              value: _isActive,
              enabled: canEdit,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    if (tenant == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveBranch(
          id: widget.branch?.id,
          tenantId: tenant.id,
          facilityId: widget.snapshot.facility?.id,
          name: _nameController.text,
          isActive: _isActive,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _DepartmentFormDialog extends ConsumerStatefulWidget {
  const _DepartmentFormDialog({required this.snapshot, this.department});

  final FacilitySetupSnapshot snapshot;
  final DepartmentProfile? department;

  @override
  ConsumerState<_DepartmentFormDialog> createState() =>
      _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends ConsumerState<_DepartmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _shortNameController;
  late DepartmentSetupType _type;
  late String _branchId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final DepartmentProfile? department = widget.department;
    _nameController = TextEditingController(text: department?.name);
    _shortNameController = TextEditingController(text: department?.shortName);
    _type = department?.type ?? DepartmentSetupType.clinical;
    _branchId = department?.branchId ?? _noneSelection;
    _isActive = department?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.department != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditDepartmentTitle
            : l10n.tenantFacilityAddDepartmentTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityDepartmentNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _shortNameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityDepartmentShortNameLabel,
            ),
            AppSelectField<DepartmentSetupType>(
              value: _type,
              enabled: canEdit,
              labelText: l10n.tenantFacilityDepartmentTypeLabel,
              isRequired: true,
              options: <AppSelectOption<DepartmentSetupType>>[
                for (final type in DepartmentSetupType.values)
                  AppSelectOption<DepartmentSetupType>(
                    value: type,
                    label: _departmentTypeLabel(l10n, type),
                  ),
              ],
              onChanged: (DepartmentSetupType? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _type = value;
                });
              },
            ),
            AppSelectField<String>.searchable(
              value: _branchId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityDepartmentBranchLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final BranchProfile branch in widget.snapshot.branches)
                  AppSelectOption<String>(value: branch.id, label: branch.name),
              ],
              validator: tenantFacilityValidReferenceSelection(
                validIds: widget.snapshot.branches
                    .map((BranchProfile branch) => branch.id)
                    .toList(growable: false),
                invalidMessage: l10n.tenantFacilityInvalidBranchSelection,
              ),
              onChanged: (String? value) {
                setState(() {
                  _branchId = value ?? _noneSelection;
                });
              },
            ),
            AppSwitchField(
              title: l10n.tenantFacilityActiveLabel,
              value: _isActive,
              enabled: canEdit,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    if (tenant == null || facility == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveDepartment(
          id: widget.department?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          shortName: _shortNameController.text,
          branchId: _optionalSelection(_branchId),
          type: _type,
          isActive: _isActive,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _UnitFormDialog extends ConsumerStatefulWidget {
  const _UnitFormDialog({required this.snapshot, this.unit});

  final FacilitySetupSnapshot snapshot;
  final UnitProfile? unit;

  @override
  ConsumerState<_UnitFormDialog> createState() => _UnitFormDialogState();
}

class _UnitFormDialogState extends ConsumerState<_UnitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _departmentId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.unit?.name);
    _departmentId =
        widget.unit?.departmentId ??
        (widget.snapshot.departments.length == 1
            ? widget.snapshot.departments.first.id
            : _noneSelection);
    _isActive = widget.unit?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.unit != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditUnitTitle
            : l10n.tenantFacilityAddUnitTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityUnitNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>.searchable(
              value: _departmentId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityUnitDepartmentLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final DepartmentProfile department
                    in widget.snapshot.departments)
                  AppSelectOption<String>(
                    value: department.id,
                    label: department.name,
                  ),
              ],
              validator: tenantFacilityValidReferenceSelection(
                validIds: widget.snapshot.departments
                    .map((DepartmentProfile department) => department.id)
                    .toList(growable: false),
                invalidMessage: l10n.tenantFacilityInvalidDepartmentSelection,
              ),
              onChanged: (String? value) {
                setState(() {
                  _departmentId = value ?? _noneSelection;
                });
              },
            ),
            AppSwitchField(
              title: l10n.tenantFacilityActiveLabel,
              value: _isActive,
              enabled: canEdit,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    if (tenant == null || facility == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveUnit(
          id: widget.unit?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          departmentId: _optionalSelection(_departmentId),
          isActive: _isActive,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _WardFormDialog extends ConsumerStatefulWidget {
  const _WardFormDialog({required this.snapshot, this.ward});

  final FacilitySetupSnapshot snapshot;
  final WardProfile? ward;

  @override
  ConsumerState<_WardFormDialog> createState() => _WardFormDialogState();
}

class _WardFormDialogState extends ConsumerState<_WardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late WardSetupType _type;
  late String _departmentId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ward?.name);
    _type = widget.ward?.type ?? WardSetupType.general;
    _departmentId =
        widget.ward?.departmentId ??
        (widget.snapshot.departments.length == 1
            ? widget.snapshot.departments.first.id
            : _noneSelection);
    _isActive = widget.ward?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.ward != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditWardTitle
            : l10n.tenantFacilityAddWardTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityWardNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<WardSetupType>(
              value: _type,
              enabled: canEdit,
              labelText: l10n.tenantFacilityWardTypeLabel,
              isRequired: true,
              options: <AppSelectOption<WardSetupType>>[
                for (final type in WardSetupType.values)
                  AppSelectOption<WardSetupType>(
                    value: type,
                    label: _wardTypeLabel(l10n, type),
                  ),
              ],
              onChanged: (WardSetupType? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _type = value;
                });
              },
            ),
            AppSelectField<String>.searchable(
              value: _departmentId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityWardDepartmentLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final DepartmentProfile department
                    in widget.snapshot.departments)
                  AppSelectOption<String>(
                    value: department.id,
                    label: department.name,
                  ),
              ],
              validator: tenantFacilityValidReferenceSelection(
                validIds: widget.snapshot.departments
                    .map((DepartmentProfile department) => department.id)
                    .toList(growable: false),
                invalidMessage: l10n.tenantFacilityInvalidDepartmentSelection,
              ),
              onChanged: (String? value) {
                setState(() {
                  _departmentId = value ?? _noneSelection;
                });
              },
            ),
            AppSwitchField(
              title: l10n.tenantFacilityActiveLabel,
              value: _isActive,
              enabled: canEdit,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    if (tenant == null || facility == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveWard(
          id: widget.ward?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          type: _type,
          departmentId: _optionalSelection(_departmentId),
          isActive: _isActive,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _RoomFormDialog extends ConsumerStatefulWidget {
  const _RoomFormDialog({required this.snapshot, this.room});

  final FacilitySetupSnapshot snapshot;
  final RoomProfile? room;

  @override
  ConsumerState<_RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends ConsumerState<_RoomFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _floorController;
  late String _wardId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name);
    _floorController = TextEditingController(text: widget.room?.floor);
    _wardId =
        widget.room?.wardId ??
        (widget.snapshot.wards.length == 1
            ? widget.snapshot.wards.first.id
            : _noneSelection);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.room != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditRoomTitle
            : l10n.tenantFacilityAddRoomTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityRoomNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>.searchable(
              value: _wardId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityRoomWardLabel,
              helperText: l10n.tenantFacilityRoomWardOptionalHint,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityRoomOutpatientLabel,
                ),
                for (final WardProfile ward in widget.snapshot.wards)
                  AppSelectOption<String>(value: ward.id, label: ward.name),
              ],
              validator: tenantFacilityValidReferenceSelection(
                validIds: widget.snapshot.wards
                    .map((WardProfile ward) => ward.id)
                    .toList(growable: false),
                invalidMessage: l10n.tenantFacilityInvalidWardSelection,
              ),
              onChanged: (String? value) {
                setState(() {
                  _wardId = value ?? _noneSelection;
                });
              },
            ),
            AppTextField(
              controller: _floorController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityRoomFloorLabel,
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    if (tenant == null || facility == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveRoom(
          id: widget.room?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          wardId: _optionalSelection(_wardId),
          floor: _floorController.text,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _BedFormDialog extends ConsumerStatefulWidget {
  const _BedFormDialog({required this.snapshot, this.bed});

  final FacilitySetupSnapshot snapshot;
  final BedProfile? bed;

  @override
  ConsumerState<_BedFormDialog> createState() => _BedFormDialogState();
}

class _BedFormDialogState extends ConsumerState<_BedFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late String _wardId;
  late String _roomId;
  late BedSetupStatus _status;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.bed?.label);
    _wardId = widget.bed?.wardId ?? _noneSelection;
    _roomId = widget.bed?.roomId ?? _noneSelection;
    _status = widget.bed?.status ?? BedSetupStatus.available;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.bed != null;
    final bool canEdit = !submission.isSubmitting;
    final List<RoomProfile> rooms = _optionalSelection(_wardId) == null
        ? widget.snapshot.rooms
        : widget.snapshot.rooms
              .where((RoomProfile room) => room.wardId == _wardId)
              .toList(growable: false);

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditBedTitle
            : l10n.tenantFacilityAddBedTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _labelController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBedLabelLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.characters,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>.searchable(
              value: _wardId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBedWardLabel,
              isRequired: true,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final WardProfile ward in widget.snapshot.wards)
                  AppSelectOption<String>(value: ward.id, label: ward.name),
              ],
              validator: (String? value) {
                final String? requiredError = tenantFacilityRequiredSelection(
                  l10n,
                )(value);
                if (requiredError != null) {
                  return requiredError;
                }

                return tenantFacilityValidReferenceSelection(
                  validIds: widget.snapshot.wards
                      .map((WardProfile ward) => ward.id)
                      .toList(growable: false),
                  invalidMessage: l10n.tenantFacilityInvalidWardSelection,
                )(value);
              },
              onChanged: (String? value) {
                final String nextWardId = value ?? _noneSelection;
                final List<RoomProfile> nextRooms =
                    _optionalSelection(nextWardId) == null
                    ? widget.snapshot.rooms
                    : widget.snapshot.rooms
                          .where(
                            (RoomProfile room) => room.wardId == nextWardId,
                          )
                          .toList(growable: false);
                setState(() {
                  _wardId = nextWardId;
                  if (nextRooms.every(
                    (RoomProfile room) => room.id != _roomId,
                  )) {
                    _roomId = _noneSelection;
                  }
                });
              },
            ),
            AppSelectField<String>.searchable(
              value: _roomId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBedRoomLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final RoomProfile room in rooms)
                  AppSelectOption<String>(value: room.id, label: room.name),
              ],
              validator: tenantFacilityValidReferenceSelection(
                validIds: rooms
                    .map((RoomProfile room) => room.id)
                    .toList(growable: false),
                invalidMessage: l10n.tenantFacilityInvalidRoomSelection,
              ),
              onChanged: (String? value) {
                setState(() {
                  _roomId = value ?? _noneSelection;
                });
              },
            ),
            AppSelectField<BedSetupStatus>(
              value: _status,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBedStatusLabel,
              isRequired: true,
              options: <AppSelectOption<BedSetupStatus>>[
                for (final status in BedSetupStatus.values)
                  AppSelectOption<BedSetupStatus>(
                    value: status,
                    label: _bedStatusLabel(l10n, status),
                  ),
              ],
              onChanged: (BedSetupStatus? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _status = value;
                });
              },
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    final String? wardId = _optionalSelection(_wardId);
    if (tenant == null || facility == null || wardId == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveBed(
          id: widget.bed?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          wardId: wardId,
          label: _labelController.text,
          status: _status,
          roomId: _optionalSelection(_roomId),
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _SubmissionFailureBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppFailure? failure = ref.watch(
      tenantFacilitySetupSubmissionProvider.select((state) => state.failure),
    );
    if (failure == null) {
      return const SizedBox.shrink();
    }

    return AppFormInformationBanner.failure(context: context, failure: failure);
  }
}

Future<void> _openBranchDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  BranchProfile? branch,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BranchFormDialog(snapshot: snapshot, branch: branch),
  );
}

Future<void> _openDepartmentDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  DepartmentProfile? department,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DepartmentFormDialog(snapshot: snapshot, department: department),
  );
}

Future<void> _openUnitDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  UnitProfile? unit,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UnitFormDialog(snapshot: snapshot, unit: unit),
  );
}

Future<void> _openWardDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  WardProfile? ward,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WardFormDialog(snapshot: snapshot, ward: ward),
  );
}

Future<void> _openRoomDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  RoomProfile? room,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RoomFormDialog(snapshot: snapshot, room: room),
  );
}

Future<void> _openBedDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  BedProfile? bed,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BedFormDialog(snapshot: snapshot, bed: bed),
  );
}

Future<void> _deleteEntity({
  required BuildContext context,
  required WidgetRef ref,
  required String name,
  required Future<bool> Function() deleteAction,
}) async {
  final AppLocalizations l10n = context.l10n;
  await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppConfirmActionDialog(
      title: l10n.tenantFacilitySoftDeleteStructureTitle,
      body: l10n.tenantFacilitySoftDeleteStructureBody(name),
      highlightedText: name,
      submitLabel: l10n.tenantFacilityDeleteConfirmAction,
      destructive: true,
      icon: const Icon(Icons.delete_outline),
      onConfirm: () async {
        final bool deleted = await deleteAction();
        if (deleted) {
          return null;
        }
        return ref.read(tenantFacilitySetupSubmissionProvider).failure ??
            const AppFailure.unexpected();
      },
    ),
  );
}

Future<void> _restoreEntity({
  required BuildContext context,
  required WidgetRef ref,
  required String name,
  required Future<bool> Function() restoreAction,
}) async {
  final AppLocalizations l10n = context.l10n;
  await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppConfirmActionDialog(
      title: l10n.tenantFacilityRestoreStructureTitle,
      body: l10n.tenantFacilityRestoreStructureBody(name),
      highlightedText: name,
      submitLabel: l10n.tenantFacilityRestoreStructureAction,
      icon: const Icon(Icons.restore_outlined),
      onConfirm: () async {
        final bool restored = await restoreAction();
        if (restored) {
          return null;
        }
        return ref.read(tenantFacilitySetupSubmissionProvider).failure ??
            const AppFailure.unexpected();
      },
    ),
  );
}

String? _optionalSelection(String? value) {
  if (value == null || value == _noneSelection) {
    return null;
  }

  return value;
}

String _activeStatusLabel(AppLocalizations l10n, bool isActive) {
  return isActive
      ? l10n.tenantFacilityStatusActive
      : l10n.tenantFacilityStatusInactive;
}

String _departmentSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  DepartmentProfile department,
) {
  return _joinParts(<String?>[
    _departmentTypeLabel(l10n, department.type),
    if (department.shortName != null) department.shortName!,
    _branchName(snapshot, department.branchId),
    _activeStatusLabel(l10n, department.isActive),
  ]);
}

String _unitSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  UnitProfile unit,
) {
  return _joinParts(<String?>[
    _departmentName(snapshot, unit.departmentId),
    _activeStatusLabel(l10n, unit.isActive),
  ]);
}

String _wardSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  WardProfile ward,
) {
  return _joinParts(<String?>[
    _wardTypeLabel(l10n, ward.type),
    _departmentName(snapshot, ward.departmentId),
    _activeStatusLabel(l10n, ward.isActive),
  ]);
}

String _roomSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  RoomProfile room,
) {
  return _joinParts(<String?>[
    room.wardId != null
        ? _wardName(snapshot, room.wardId)
        : l10n.tenantFacilityRoomOutpatientLabel,
    if (room.floor != null) room.floor!,
  ]);
}

String _bedSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  BedProfile bed,
) {
  return _joinParts(<String?>[
    _wardName(snapshot, bed.wardId),
    _roomName(snapshot, bed.roomId),
    _bedStatusLabel(l10n, bed.status),
  ]);
}

String _joinParts(List<String?> parts) {
  return parts
      .whereType<String>()
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .join(', ');
}

String? _branchName(FacilitySetupSnapshot snapshot, String? branchId) {
  return snapshot.branches
      .where((BranchProfile branch) => branch.id == branchId)
      .firstOrNull
      ?.name;
}

String? _departmentName(FacilitySetupSnapshot snapshot, String? departmentId) {
  return snapshot.departments
      .where((DepartmentProfile department) => department.id == departmentId)
      .firstOrNull
      ?.name;
}

String? _wardName(FacilitySetupSnapshot snapshot, String? wardId) {
  return snapshot.wards
      .where((WardProfile ward) => ward.id == wardId)
      .firstOrNull
      ?.name;
}

String? _roomName(FacilitySetupSnapshot snapshot, String? roomId) {
  return snapshot.rooms
      .where((RoomProfile room) => room.id == roomId)
      .firstOrNull
      ?.name;
}

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: <Widget>[
              left,
              SizedBox(height: theme.spacing.md),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            SizedBox(width: theme.spacing.md),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _SetupGrid extends StatelessWidget {
  const _SetupGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useTwoColumns = constraints.maxWidth >= AppBreakpoints.lg;
        final bool compact = constraints.maxWidth < AppBreakpoints.sm;
        final double gap = compact ? theme.spacing.sm : theme.spacing.md;
        final double itemWidth = useTwoColumns
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _SubmissionFeedback extends StatelessWidget {
  const _SubmissionFeedback({
    required this.enabled,
    this.failure,
    this.permissionDeniedMessage,
  });

  final bool enabled;
  final AppFailure? failure;
  final String? permissionDeniedMessage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String deniedMessage =
        permissionDeniedMessage ?? l10n.tenantFacilityPermissionRequired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!enabled) ...<Widget>[
          Text(
            deniedMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (failure != null) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.failureMessage(failure!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.statusColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _SubmitButton extends ConsumerWidget {
  const _SubmitButton({
    required this.enabled,
    required this.isLoading,
    required this.label,
    required this.onPressed,
    this.permissionDeniedMessage,
  });

  final bool enabled;
  final bool isLoading;
  final String label;
  final VoidCallback onPressed;
  final String? permissionDeniedMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool fullWidth = breakpoint.isMobile;
    final failure = ref.watch(
      tenantFacilitySetupSubmissionProvider.select((state) => state.failure),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppButton.primary(
          label: label,
          leadingIcon: Icons.save_outlined,
          isLoading: isLoading,
          enabled: enabled,
          fullWidth: fullWidth,
          onPressed: onPressed,
        ),
        if (!enabled) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.xs),
          Text(
            permissionDeniedMessage ?? l10n.tenantFacilityPermissionRequired,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (failure != null) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.xs),
          Text(
            l10n.failureMessage(failure),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).statusColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

String _departmentTypeLabel(AppLocalizations l10n, DepartmentSetupType type) {
  return switch (type) {
    DepartmentSetupType.clinical => l10n.tenantFacilityDepartmentTypeClinical,
    DepartmentSetupType.administrative =>
      l10n.tenantFacilityDepartmentTypeAdministrative,
    DepartmentSetupType.support => l10n.tenantFacilityDepartmentTypeSupport,
    DepartmentSetupType.diagnostics =>
      l10n.tenantFacilityDepartmentTypeDiagnostics,
    DepartmentSetupType.other => l10n.tenantFacilityDepartmentTypeOther,
  };
}

String _wardTypeLabel(AppLocalizations l10n, WardSetupType type) {
  return switch (type) {
    WardSetupType.general => l10n.tenantFacilityWardTypeGeneral,
    WardSetupType.icu => l10n.tenantFacilityWardTypeIcu,
    WardSetupType.maternity => l10n.tenantFacilityWardTypeMaternity,
    WardSetupType.pediatric => l10n.tenantFacilityWardTypePediatric,
    WardSetupType.surgical => l10n.tenantFacilityWardTypeSurgical,
    WardSetupType.other => l10n.tenantFacilityWardTypeOther,
  };
}

String _bedStatusLabel(AppLocalizations l10n, BedSetupStatus status) {
  return switch (status) {
    BedSetupStatus.available => l10n.tenantFacilityBedStatusAvailable,
    BedSetupStatus.occupied => l10n.tenantFacilityBedStatusOccupied,
    BedSetupStatus.reserved => l10n.tenantFacilityBedStatusReserved,
    BedSetupStatus.cleaning => l10n.tenantFacilityBedStatusCleaning,
    BedSetupStatus.maintenance => l10n.tenantFacilityBedStatusMaintenance,
    BedSetupStatus.blocked => l10n.tenantFacilityBedStatusBlocked,
    BedSetupStatus.outOfService => l10n.tenantFacilityBedStatusOutOfService,
  };
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(context.l10n.tenantFacilitySavedMessage)),
    );
}

/// Opens the tenant profile create/edit dialog from the home dashboard.
Future<bool?> showTenantFacilityTenantFormDialog(
  BuildContext context, {
  TenantProfile? tenant,
  bool forceCreate = false,
  bool managementMode = false,
}) {
  return _openTenantProfileModal(
    context,
    tenant: tenant,
    forceCreate: forceCreate,
    managementMode: managementMode,
  );
}

/// Opens the facility profile create/edit dialog from the home dashboard.
Future<bool?> showTenantFacilityFacilityFormDialog(
  BuildContext context, {
  String? tenantId,
  FacilityProfile? facility,
  bool requireTenantPicker = false,
  bool managementMode = false,
}) {
  return _openFacilityProfileModal(
    context,
    tenantId: tenantId,
    facility: facility,
    requireTenantPicker: requireTenantPicker,
    managementMode: managementMode,
  );
}

/// Shared department create/edit dialog for facility setup.
Future<void> showTenantFacilityDepartmentFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  DepartmentProfile? department,
}) {
  return _openDepartmentDialog(context, snapshot, department: department);
}

/// Shared branch create/edit dialog for facility setup and management.
Future<void> showTenantFacilityBranchFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  BranchProfile? branch,
}) {
  return _openBranchDialog(context, snapshot, branch: branch);
}

/// Shared unit create/edit dialog for facility setup.
Future<void> showTenantFacilityUnitFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  UnitProfile? unit,
}) {
  return _openUnitDialog(context, snapshot, unit: unit);
}

/// Shared ward create/edit dialog for facility setup and management.
Future<void> showTenantFacilityWardFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  WardProfile? ward,
}) {
  return _openWardDialog(context, snapshot, ward: ward);
}

/// Shared room create/edit dialog for facility setup and rooms & beds workspace.
Future<void> showTenantFacilityRoomFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  RoomProfile? room,
}) {
  return _openRoomDialog(context, snapshot, room: room);
}

/// Shared bed create/edit dialog for facility setup and rooms & beds workspace.
Future<void> showTenantFacilityBedFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  BedProfile? bed,
}) {
  return _openBedDialog(context, snapshot, bed: bed);
}

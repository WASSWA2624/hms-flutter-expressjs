import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';
import 'package:hosspi_hms/features/settings/presentation/controllers/settings_workspace_controller.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/features/settings/presentation/state/settings_workspace_state.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

/// Administrative setup workspace tab (`/settings?tab=workspace`).
///
/// Inventory → matrix mapping (reuse [SettingsWorkspaceAtomPermissions];
/// nested cross-module rows are _(n/a)_):
///
/// | Atom | Intent | Gate |
/// | --- | --- | --- |
/// | Section chrome / tab strip entry | read | admin ∨ HR source ([tab]) |
/// | Loading / empty / error / retry | read chrome | [loading] / [empty] / [retry] |
/// | Tenant / facility context selectors | read chrome | [contextSelector] |
/// | Search / group / state / actionable filters | read chrome | [search] / [filters] |
/// | Module groups + row metadata | read | [moduleList] / [moduleRow] |
/// | Open | navigate | [open] + backend `can_read` |
/// | Create | create | matrix `facility:admin` ∪ source HR create + `can_create` |
/// | Update / delete | — | matrix keys; **not mounted** |
class SettingsWorkspaceSection extends ConsumerWidget {
  const SettingsWorkspaceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    if (!settingsWorkspaceSectionVisible(accessPolicy)) {
      return const SizedBox.shrink();
    }

    final AsyncValue<Result<SettingsWorkspaceState>> workspaceState = ref.watch(
      settingsWorkspaceControllerProvider,
    );

    return _SettingsWorkspaceBody(
      workspaceState: workspaceState,
      onRefresh: () => unawaited(
        ref.read(settingsWorkspaceControllerProvider.notifier).refresh(),
      ),
    );
  }
}

class _SettingsWorkspaceBody extends StatelessWidget {
  const _SettingsWorkspaceBody({
    required this.workspaceState,
    required this.onRefresh,
  });

  final AsyncValue<Result<SettingsWorkspaceState>> workspaceState;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppScreenSection(
      title: l10n.settingsWorkspaceSectionTitle,
      body: l10n.settingsWorkspaceSectionBody,
      child: workspaceState.when(
        loading: () => AppStateView(
          variant: AppStateViewVariant.loading,
          title: l10n.settingsWorkspaceLoadingTitle,
          body: l10n.settingsWorkspaceLoadingBody,
        ),
        error: (_, _) => AppFailureStateView(
          failure: const AppFailure.unexpected(),
          title: l10n.settingsWorkspaceErrorTitle,
          onRetry: onRefresh,
        ),
        data: (Result<SettingsWorkspaceState> result) => result.when(
          success: (SettingsWorkspaceState state) => _SettingsWorkspaceContent(
            state: state,
            onRefresh: onRefresh,
          ),
          failure: (AppFailure failure) => AppFailureStateView(
            failure: failure,
            title: l10n.settingsWorkspaceErrorTitle,
            onRetry: onRefresh,
          ),
        ),
      ),
    );
  }
}

class _SettingsWorkspaceContent extends StatelessWidget {
  const _SettingsWorkspaceContent({
    required this.state,
    required this.onRefresh,
  });

  final SettingsWorkspaceState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final SettingsWorkspace workspace = state.workspace;
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (workspace.status == SettingsWorkspaceStatus.tenantContextRequired) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppStateView(
            title: l10n.settingsWorkspaceTenantContextRequiredTitle,
            body: l10n.settingsWorkspaceTenantContextRequiredBody,
          ),
          SizedBox(height: theme.spacing.md),
          _SettingsContextSelector(state: state),
        ],
      );
    }

    if (workspace.moduleGroups.isEmpty) {
      return AppStateView(
        variant: AppStateViewVariant.empty,
        title: l10n.settingsWorkspaceEmptyTitle,
        body: l10n.settingsWorkspaceEmptyBody,
        action: AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          onPressed: onRefresh,
        ),
      );
    }

    // One scroll surface: context → filters → modules (Open/Create sole entries).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsContextSelector(state: state),
        SizedBox(height: theme.spacing.md),
        _SettingsWorkspaceFilters(state: state),
        SizedBox(height: theme.spacing.md),
        _SettingsModuleGroupsPanel(groups: workspace.moduleGroups),
      ],
    );
  }
}

class _SettingsContextSelector extends ConsumerWidget {
  const _SettingsContextSelector({required this.state});

  final SettingsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final SettingsReferenceData referenceData = state.referenceData;
    final bool hasTenants = referenceData.tenants.isNotEmpty;
    final bool hasFacilities = referenceData.facilities.isNotEmpty;

    if (!hasTenants && !hasFacilities) {
      return const SizedBox.shrink();
    }

    return AppSectionPanel(
      title: l10n.settingsWorkspaceTenantSelectorLabel,
      leadingIcon: Icons.tune_outlined,
      density: AppContentPanelDensity.compact,
      borderColor: Colors.transparent,
      children: <Widget>[
        Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.md,
          children: <Widget>[
            if (hasTenants)
              SizedBox(
                width: 260,
                child: AppSelectField<String>(
                  labelText: l10n.settingsWorkspaceTenantLabel,
                  value: state.query.tenantId,
                  options: <AppSelectOption<String>>[
                    for (final SettingsReferenceOption tenant
                        in referenceData.tenants)
                      AppSelectOption<String>(
                        value: tenant.id,
                        label: tenant.label,
                      ),
                  ],
                  onChanged: (String? value) => unawaited(
                    ref
                        .read(settingsWorkspaceControllerProvider.notifier)
                        .selectTenant(value),
                  ),
                ),
              ),
            if (hasFacilities)
              SizedBox(
                width: 260,
                child: AppSelectField<String>(
                  labelText: l10n.settingsWorkspaceFacilitySelectorLabel,
                  value: state.query.facilityId,
                  options: <AppSelectOption<String>>[
                    for (final SettingsReferenceOption facility
                        in referenceData.facilities)
                      AppSelectOption<String>(
                        value: facility.id,
                        label: facility.label,
                      ),
                  ],
                  onChanged: (String? value) => unawaited(
                    ref
                        .read(settingsWorkspaceControllerProvider.notifier)
                        .selectFacility(value),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SettingsWorkspaceFilters extends ConsumerWidget {
  const _SettingsWorkspaceFilters({required this.state});

  final SettingsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final SettingsWorkspaceController controller = ref.read(
      settingsWorkspaceControllerProvider.notifier,
    );
    final List<SettingsModuleGroup> groups = state.workspace.moduleGroups;

    return AppSectionPanel(
      title: l10n.settingsWorkspaceSearchLabel,
      leadingIcon: Icons.filter_list_outlined,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 260,
              child: AppTextField(
                initialValue: state.query.search,
                labelText: l10n.settingsWorkspaceSearchLabel,
                hintText: l10n.settingsWorkspaceSearchHint,
                prefixIcon: const Icon(Icons.search),
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (String value) =>
                    unawaited(controller.applySearch(value)),
              ),
            ),
            SizedBox(
              width: 220,
              child: AppSelectField<String>(
                labelText: l10n.settingsWorkspaceGroupFilterLabel,
                value: state.query.group,
                options: <AppSelectOption<String>>[
                  for (final SettingsModuleGroup group in groups)
                    AppSelectOption<String>(
                      value: group.id,
                      label: _labelForKey(l10n, group.labelKey),
                    ),
                ],
                onChanged: (String? value) =>
                    unawaited(controller.applyGroup(value)),
              ),
            ),
            SizedBox(
              width: 220,
              child: AppSelectField<SettingsModuleState>(
                labelText: l10n.settingsWorkspaceStateFilterLabel,
                value: state.query.state,
                options: <AppSelectOption<SettingsModuleState>>[
                  AppSelectOption<SettingsModuleState>(
                    value: SettingsModuleState.configured,
                    label: l10n.settingsWorkspaceConfiguredStatus,
                  ),
                  AppSelectOption<SettingsModuleState>(
                    value: SettingsModuleState.attention,
                    label: l10n.settingsWorkspaceAttentionStatus,
                  ),
                  AppSelectOption<SettingsModuleState>(
                    value: SettingsModuleState.empty,
                    label: l10n.settingsWorkspaceEmptyStatus,
                  ),
                ],
                onChanged: (SettingsModuleState? value) =>
                    unawaited(controller.applyState(value)),
              ),
            ),
            SizedBox(
              width: 260,
              child: AppCheckboxField(
                title: l10n.settingsWorkspaceActionableOnlyLabel,
                value: state.query.actionableOnly,
                onChanged: (bool value) =>
                    unawaited(controller.toggleActionableOnly(value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsModuleGroupsPanel extends StatelessWidget {
  const _SettingsModuleGroupsPanel({required this.groups});

  final List<SettingsModuleGroup> groups;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (groups.isEmpty) {
      return AppStateView(
        variant: AppStateViewVariant.empty,
        title: l10n.settingsWorkspaceModuleGroupsTitle,
        body: l10n.settingsWorkspaceNoModulesBody,
      );
    }

    return AppSectionPanel(
      title: l10n.settingsWorkspaceModuleGroupsTitle,
      leadingIcon: Icons.view_module_outlined,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        for (final SettingsModuleGroup group in groups) ...<Widget>[
          Text(
            _labelForKey(l10n, group.labelKey),
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          for (final SettingsModuleItem module in group.modules) ...<Widget>[
            _SettingsModuleRow(module: module),
            SizedBox(height: theme.spacing.xs),
          ],
          if (group != groups.last) SizedBox(height: theme.spacing.md),
        ],
      ],
    );
  }
}

class _SettingsModuleRow extends ConsumerWidget {
  const _SettingsModuleRow({required this.module});

  final SettingsModuleItem module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final String? route = _mappedSettingsRoute(module.route);
    final String? createRoute = _mappedSettingsRoute(module.createRoute);
    final bool canOpen = route != null && module.canRead;
    final bool canCreate =
        createRoute != null &&
        module.canCreate &&
        settingsWorkspaceCanCreate(accessPolicy);
    final String reason = _moduleReason(l10n, module);

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      tone: _toneForModule(module.state),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_iconFor(module.icon), size: theme.appTokens.listIconSize),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _labelForKey(l10n, module.labelKey),
                  style: theme.textTheme.titleSmall,
                ),
                SizedBox(height: theme.spacing.xs / 2),
                Text(
                  '${l10n.settingsWorkspaceRecordsLabel}: ${module.count} • ${_stateLabel(l10n, module.state)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (reason.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs / 2),
                  Text(
                    reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              if (canOpen)
                AppButton.tertiary(
                  label: l10n.settingsWorkspaceOpenAction,
                  leadingIcon: Icons.open_in_new,
                  onPressed: () => context.go(route),
                ),
              if (canCreate)
                AppButton.tertiary(
                  label: l10n.settingsWorkspaceCreateAction,
                  leadingIcon: Icons.add,
                  onPressed: () => context.go(createRoute),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _moduleReason(AppLocalizations l10n, SettingsModuleItem module) {
  if (module.attentionReasonKey == 'settings.workspace.reasons.dependencies') {
    return l10n.settingsWorkspaceDependencyBlockedLabel;
  }
  if (module.attentionReasonKey == 'settings.workspace.reasons.required') {
    return l10n.settingsWorkspaceRequiredSetupLabel;
  }
  if (module.state == SettingsModuleState.empty) {
    return l10n.settingsWorkspaceOptionalSetupLabel;
  }
  return '';
}

String _stateLabel(AppLocalizations l10n, SettingsModuleState state) {
  return switch (state) {
    SettingsModuleState.configured => l10n.settingsWorkspaceConfiguredStatus,
    SettingsModuleState.attention => l10n.settingsWorkspaceAttentionStatus,
    SettingsModuleState.empty => l10n.settingsWorkspaceEmptyStatus,
  };
}

AppWorkspaceStatusTone _toneForModule(SettingsModuleState state) {
  return switch (state) {
    SettingsModuleState.configured => AppWorkspaceStatusTone.success,
    SettingsModuleState.attention => AppWorkspaceStatusTone.warning,
    SettingsModuleState.empty => AppWorkspaceStatusTone.neutral,
  };
}

IconData _iconFor(String? icon) {
  return switch (icon) {
    'business-outline' => Icons.business_outlined,
    'git-branch-outline' => Icons.account_tree_outlined,
    'folder-outline' => Icons.folder_outlined,
    'grid-outline' => Icons.grid_view_outlined,
    'home-outline' => Icons.home_outlined,
    'medkit-outline' => Icons.local_hospital_outlined,
    'bed-outline' => Icons.bed_outlined,
    'map-outline' => Icons.map_outlined,
    'people-outline' => Icons.people_outline,
    'person-outline' => Icons.person_outline,
    'shield-outline' => Icons.shield_outlined,
    'shield-checkmark-outline' => Icons.verified_user_outlined,
    'time-outline' => Icons.schedule_outlined,
    'key-outline' => Icons.key_outlined,
    'lock-closed-outline' => Icons.lock_outline,
    'lock-open-outline' => Icons.lock_open_outlined,
    _ => Icons.layers_outlined,
  };
}

String _labelForKey(AppLocalizations l10n, String key) {
  return switch (key) {
    'settings.workspace.summary.organization' =>
      l10n.settingsWorkspaceOrganizationGroup,
    'settings.workspace.summary.usersAndAccess' =>
      l10n.settingsWorkspaceUsersAndAccessGroup,
    'settings.workspace.summary.security' =>
      l10n.settingsWorkspaceSecurityGroup,
    'settings.sidebar.groups.organization' =>
      l10n.settingsWorkspaceOrganizationGroup,
    'settings.sidebar.groups.usersAndAccess' =>
      l10n.settingsWorkspaceUsersAndAccessGroup,
    'settings.sidebar.groups.security' => l10n.settingsWorkspaceSecurityGroup,
    'settings.tabs.tenant' ||
    'settings.workspace.checklist.tenant' => l10n.settingsWorkspaceModuleTenant,
    'settings.tabs.facility' || 'settings.workspace.checklist.facility' =>
      l10n.settingsWorkspaceModuleFacility,
    'settings.tabs.department' || 'settings.workspace.checklist.department' =>
      l10n.settingsWorkspaceModuleDepartment,
    'settings.tabs.unit' => l10n.settingsWorkspaceModuleUnit,
    'settings.tabs.room' => l10n.settingsWorkspaceModuleRoom,
    'settings.tabs.ward' ||
    'settings.workspace.checklist.ward' => l10n.settingsWorkspaceModuleWard,
    'settings.tabs.bed' ||
    'settings.workspace.checklist.bed' => l10n.settingsWorkspaceModuleBed,
    'settings.tabs.address' => l10n.settingsWorkspaceModuleAddress,
    'settings.tabs.contact' => l10n.settingsWorkspaceModuleContact,
    'settings.tabs.user' ||
    'settings.workspace.checklist.user' => l10n.settingsWorkspaceModuleUser,
    'settings.tabs.user-profile' => l10n.settingsWorkspaceModuleUserProfile,
    'settings.tabs.role' ||
    'settings.workspace.checklist.role' => l10n.settingsWorkspaceModuleRole,
    'settings.tabs.permission' || 'settings.workspace.checklist.permission' =>
      l10n.settingsWorkspaceModulePermission,
    'settings.tabs.role-permission' =>
      l10n.settingsWorkspaceModuleRolePermission,
    'settings.tabs.user-role' => l10n.settingsWorkspaceModuleUserRole,
    'settings.tabs.user-session' => l10n.settingsWorkspaceModuleUserSession,
    'settings.tabs.api-key' => l10n.settingsWorkspaceModuleApiKey,
    'settings.tabs.api-key-permission' =>
      l10n.settingsWorkspaceModuleApiKeyPermission,
    'settings.tabs.user-mfa' => l10n.settingsWorkspaceModuleUserMfa,
    'settings.tabs.oauth-account' => l10n.settingsWorkspaceModuleOauthAccount,
    _ => l10n.settingsWorkspaceUnknownLabel,
  };
}

String? _mappedSettingsRoute(String? backendRoute) {
  if (backendRoute == null || backendRoute.trim().isEmpty) {
    return null;
  }

  final String route = backendRoute.trim();
  final String? accessAdminRoute = _accessAdminRouteForSettingsRoute(route);
  if (accessAdminRoute != null) {
    return accessAdminRoute;
  }
  if (_tenantFacilityRoutes.contains(route)) {
    return AppRoutes.tenantFacilitySetup.location();
  }

  // Dedicated security screens (API keys, MFA, OAuth) are not routed yet.
  return null;
}

String? _accessAdminRouteForSettingsRoute(String route) {
  final Map<String, String>? query = _settingsAccessAdminRouteQueries[route];
  if (query == null) {
    return null;
  }

  return AppRoutes.accessAdmin.location(queryParameters: query);
}

const Map<String, Map<String, String>> _settingsAccessAdminRouteQueries =
    <String, Map<String, String>>{
      '/settings/users': <String, String>{
        'resource': 'users',
        'panel': 'directory',
      },
      '/settings/users/create': <String, String>{
        'resource': 'users',
        'panel': 'directory',
      },
      '/settings/roles': <String, String>{
        'resource': 'roles',
        'panel': 'roles',
      },
      '/settings/roles/create': <String, String>{
        'resource': 'roles',
        'panel': 'roles',
      },
      '/settings/permissions': <String, String>{
        'resource': 'permissions',
        'panel': 'permissions',
      },
      '/settings/permissions/create': <String, String>{
        'resource': 'permissions',
        'panel': 'permissions',
      },
      '/settings/role-permissions': <String, String>{
        'resource': 'role-permissions',
        'panel': 'permissions',
      },
      '/settings/role-permissions/create': <String, String>{
        'resource': 'role-permissions',
        'panel': 'permissions',
      },
      '/settings/user-roles': <String, String>{
        'resource': 'user-roles',
        'panel': 'roles',
      },
      '/settings/user-roles/create': <String, String>{
        'resource': 'user-roles',
        'panel': 'roles',
      },
      '/settings/user-profiles': <String, String>{
        'resource': 'users',
        'panel': 'directory',
      },
      '/settings/user-profiles/create': <String, String>{
        'resource': 'users',
        'panel': 'directory',
      },
    };

const Set<String> _tenantFacilityRoutes = <String>{
  '/settings/tenants',
  '/settings/tenants/create',
  '/settings/facilities',
  '/settings/facilities/create',
  '/settings/departments',
  '/settings/departments/create',
  '/settings/units',
  '/settings/units/create',
  '/settings/rooms',
  '/settings/rooms/create',
  '/settings/wards',
  '/settings/wards/create',
  '/settings/beds',
  '/settings/beds/create',
  '/settings/addresses',
  '/settings/addresses/create',
  '/settings/contacts',
  '/settings/contacts/create',
};

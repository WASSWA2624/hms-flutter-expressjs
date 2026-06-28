import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';
import 'package:hosspi_hms/features/settings/presentation/controllers/settings_workspace_controller.dart';
import 'package:hosspi_hms/features/settings/presentation/state/settings_workspace_state.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class SettingsWorkspaceSection extends ConsumerWidget {
  const SettingsWorkspaceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<SettingsWorkspaceState>> workspaceState = ref.watch(
      settingsWorkspaceControllerProvider,
    );

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
          onRetry: () => unawaited(
            ref.read(settingsWorkspaceControllerProvider.notifier).refresh(),
          ),
        ),
        data: (Result<SettingsWorkspaceState> result) => result.when(
          success: (SettingsWorkspaceState state) => _SettingsWorkspaceContent(
            state: state,
            onRefresh: () => unawaited(
              ref.read(settingsWorkspaceControllerProvider.notifier).refresh(),
            ),
          ),
          failure: (AppFailure failure) => AppFailureStateView(
            failure: failure,
            title: l10n.settingsWorkspaceErrorTitle,
            onRetry: () => unawaited(
              ref.read(settingsWorkspaceControllerProvider.notifier).refresh(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsWorkspaceContent extends ConsumerWidget {
  const _SettingsWorkspaceContent({
    required this.state,
    required this.onRefresh,
  });

  final SettingsWorkspaceState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    if (workspace.moduleGroups.isEmpty && workspace.summaryCards.isEmpty) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SettingsContextSummary(state: state),
        SizedBox(height: theme.spacing.md),
        _SettingsSummaryCards(workspace: workspace),
        SizedBox(height: theme.spacing.md),
        _SettingsContextSelector(state: state),
        SizedBox(height: theme.spacing.md),
        _SettingsWorkspaceFilters(state: state),
        SizedBox(height: theme.spacing.md),
        _SettingsChecklistPanel(workspace: workspace),
        SizedBox(height: theme.spacing.md),
        _SettingsQuickActionsPanel(actions: workspace.quickActions),
        SizedBox(height: theme.spacing.md),
        _SettingsModuleGroupsPanel(groups: workspace.moduleGroups),
      ],
    );
  }
}

class _SettingsContextSummary extends StatelessWidget {
  const _SettingsContextSummary({required this.state});

  final SettingsWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SettingsWorkspace workspace = state.workspace;
    final SettingsWorkspaceContext workspaceContext = workspace.context;
    final String unknown = l10n.profileUnknownValue;
    final String roles = workspaceContext.roleKeys.isEmpty
        ? unknown
        : workspaceContext.roleKeys.join(', ');

    return AppSectionPanel(
      title: l10n.settingsWorkspaceContextTitle,
      leadingIcon: Icons.domain_outlined,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        AppInfoTileGrid(
          minItemWidth: 180,
          maxColumns: 3,
          emptyValue: unknown,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.settingsWorkspaceTenantLabel,
              value: workspaceContext.tenantName ?? workspaceContext.tenantId,
            ),
            AppInfoTileData(
              label: l10n.settingsWorkspaceFacilityLabel,
              value:
                  workspaceContext.facilityName ?? workspaceContext.facilityId,
            ),
            AppInfoTileData(
              label: l10n.settingsWorkspaceFacilityTypeLabel,
              value: workspaceContext.facilityType,
            ),
            AppInfoTileData(
              label: l10n.settingsWorkspaceRolesLabel,
              value: roles,
            ),
            AppInfoTileData(
              label: l10n.settingsWorkspaceGeneratedAtLabel,
              value: _dateLabel(workspace.generatedAt),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsSummaryCards extends StatelessWidget {
  const _SettingsSummaryCards({required this.workspace});

  final SettingsWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (workspace.summaryCards.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppInfoTileGrid(
      minItemWidth: 170,
      maxColumns: 3,
      items: <AppInfoTileData>[
        for (final SettingsSummaryCard card in workspace.summaryCards)
          AppInfoTileData(
            label: _labelForKey(l10n, card.labelKey),
            value: _summaryValue(l10n, card),
            icon: _statusIcon(card.state),
          ),
        AppInfoTileData(
          label: l10n.settingsWorkspaceTotalRecordsLabel,
          value: '${workspace.stats.totalRecords}',
          icon: Icons.storage_outlined,
        ),
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

class _SettingsChecklistPanel extends StatelessWidget {
  const _SettingsChecklistPanel({required this.workspace});

  final SettingsWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (workspace.checklist.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppSectionPanel(
      title: l10n.settingsWorkspaceChecklistTitle,
      description:
          '${workspace.checklist.completedCount}/${workspace.checklist.totalCount} ${l10n.settingsWorkspaceConfiguredLabel}',
      leadingIcon: Icons.playlist_add_check_outlined,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        for (final SettingsChecklistItem item
            in workspace.checklist.items) ...<Widget>[
          _SettingsChecklistRow(item: item),
          if (item != workspace.checklist.items.last)
            SizedBox(height: theme.spacing.xs),
        ],
      ],
    );
  }
}

class _SettingsChecklistRow extends StatelessWidget {
  const _SettingsChecklistRow({required this.item});

  final SettingsChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? route = _mappedSettingsRoute(item.createRoute ?? item.route);
    final bool canOpen = route != null;

    return Row(
      children: <Widget>[
        Icon(
          item.completed
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          color: item.completed
              ? theme.statusColors.success
              : theme.colorScheme.onSurfaceVariant,
          size: theme.appTokens.listIconSize,
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(child: Text(_labelForKey(l10n, item.labelKey))),
        SizedBox(width: theme.spacing.sm),
        AppButton.tertiary(
          label: canOpen
              ? l10n.settingsWorkspaceOpenAction
              : l10n.settingsWorkspaceRouteUnavailableLabel,
          leadingIcon: canOpen ? Icons.open_in_new : Icons.block_outlined,
          tooltip: canOpen ? null : l10n.settingsWorkspaceRouteUnavailableBody,
          enabled: canOpen,
          onPressed: canOpen ? () => context.go(route) : null,
        ),
      ],
    );
  }
}

class _SettingsQuickActionsPanel extends StatelessWidget {
  const _SettingsQuickActionsPanel({required this.actions});

  final List<SettingsQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppSectionPanel(
      title: l10n.settingsWorkspaceQuickActionsTitle,
      leadingIcon: Icons.bolt_outlined,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        if (actions.isEmpty)
          Text(
            l10n.settingsWorkspaceNoQuickActionsBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: <Widget>[
              for (final SettingsQuickAction action in actions)
                _SettingsActionButton(action: action),
            ],
          ),
      ],
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({required this.action});

  final SettingsQuickAction action;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? route = _mappedSettingsRoute(action.route);
    final bool canExecute = action.canExecute && route != null;

    return AppButton.secondary(
      label: _quickActionLabel(l10n, action),
      leadingIcon: _iconFor(action.icon),
      enabled: canExecute,
      tooltip: canExecute ? null : l10n.settingsWorkspaceRouteUnavailableBody,
      onPressed: canExecute ? () => context.go(route) : null,
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

class _SettingsModuleRow extends StatelessWidget {
  const _SettingsModuleRow({required this.module});

  final SettingsModuleItem module;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? route = _mappedSettingsRoute(module.route);
    final String? createRoute = _mappedSettingsRoute(module.createRoute);
    final bool canOpen = route != null && module.canRead;
    final bool canCreate = createRoute != null && module.canCreate;
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
              AppButton.tertiary(
                label: canOpen
                    ? l10n.settingsWorkspaceOpenAction
                    : l10n.settingsWorkspaceRouteUnavailableLabel,
                leadingIcon: canOpen ? Icons.open_in_new : Icons.block_outlined,
                enabled: canOpen,
                tooltip: canOpen
                    ? null
                    : l10n.settingsWorkspaceRouteUnavailableBody,
                onPressed: canOpen ? () => context.go(route) : null,
              ),
              if (module.canCreate)
                AppButton.tertiary(
                  label: canCreate
                      ? l10n.settingsWorkspaceCreateAction
                      : l10n.settingsWorkspaceRouteUnavailableLabel,
                  leadingIcon: canCreate ? Icons.add : Icons.block_outlined,
                  enabled: canCreate,
                  tooltip: canCreate
                      ? null
                      : l10n.settingsWorkspaceRouteUnavailableBody,
                  onPressed: canCreate ? () => context.go(createRoute) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _summaryValue(AppLocalizations l10n, SettingsSummaryCard card) {
  return '${card.configuredModules}/${card.totalModules} ${l10n.settingsWorkspaceConfiguredLabel} • ${card.attentionModules} ${l10n.settingsWorkspaceAttentionLabel}';
}

String _quickActionLabel(AppLocalizations l10n, SettingsQuickAction action) {
  if (action.labelKey == 'settings.workspace.quickActions.createModule') {
    return '${l10n.settingsWorkspaceCreateAction} ${_labelForKey(l10n, action.moduleLabelKey)}';
  }
  return _labelForKey(l10n, action.labelKey);
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

IconData _statusIcon(String state) {
  return switch (state) {
    'ready' || 'configured' => Icons.check_circle_outline,
    'attention' => Icons.warning_amber_outlined,
    _ => Icons.pending_actions_outlined,
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
    'settings.tabs.branch' => l10n.settingsWorkspaceModuleBranch,
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

String _dateLabel(DateTime? value) {
  if (value == null) {
    return '';
  }
  return value
      .toLocal()
      .toIso8601String()
      .replaceFirst('T', ' ')
      .split('.')
      .first;
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
  '/settings/branches',
  '/settings/branches/create',
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

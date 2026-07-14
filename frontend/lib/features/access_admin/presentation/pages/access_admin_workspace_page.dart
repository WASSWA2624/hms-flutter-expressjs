import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class AccessAdminWorkspacePage extends ConsumerStatefulWidget {
  const AccessAdminWorkspacePage({this.initialQuery, super.key});

  final AccessAdminWorkspaceQuery? initialQuery;

  @override
  ConsumerState<AccessAdminWorkspacePage> createState() {
    return _AccessAdminWorkspacePageState();
  }
}

class _AccessAdminWorkspacePageState
    extends ConsumerState<AccessAdminWorkspacePage> {
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant AccessAdminWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_querySignature(oldWidget.initialQuery) !=
        _querySignature(widget.initialQuery)) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  void _scheduleRouteQuery(AccessAdminWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) return;
    final String? signature = _querySignature(query);
    if (signature == null || _appliedRouteSignature == signature) return;
    _appliedRouteSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(accessAdminWorkspaceControllerProvider.notifier)
          .applyRouteQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<AccessAdminWorkspaceState>> workspace = ref.watch(
      accessAdminWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<AccessAdminWorkspaceState>(
      value: workspace,
      appBarTitle: context.l10n.accessAdminTitle,
      loadingTitle: context.l10n.accessAdminLoadingTitle,
      loadingBody: context.l10n.accessAdminLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(accessAdminWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, AccessAdminWorkspaceState state) {
        return _AccessAdminWorkspaceContent(state: state);
      },
    );
  }

  String? _querySignature(AccessAdminWorkspaceQuery? query) {
    if (query == null) return null;
    return '${query.panel.serverValue}|${query.resource.serverValue}|${query.recordId}|${query.tenantId}|${query.facilityId}';
  }
}

class _AccessAdminWorkspaceContent extends ConsumerStatefulWidget {
  const _AccessAdminWorkspaceContent({required this.state});

  final AccessAdminWorkspaceState state;

  @override
  ConsumerState<_AccessAdminWorkspaceContent> createState() {
    return _AccessAdminWorkspaceContentState();
  }
}

class _AccessAdminWorkspaceContentState
    extends ConsumerState<_AccessAdminWorkspaceContent> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
  }

  @override
  void didUpdateWidget(covariant _AccessAdminWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AccessAdminWorkspaceState state = widget.state;
    final AccessAdminWorkspaceController controller = ref.read(
      accessAdminWorkspaceControllerProvider.notifier,
    );
    final bool canWrite = state.data.permissions.canWrite;
    final AppFailure? lastFailure = state.lastFailure is AppFailure
        ? state.lastFailure! as AppFailure
        : null;

    return AppWorkspace(
      title: context.l10n.accessAdminTitle,
      leadingIcon: Icons.manage_accounts_outlined,
      toolbar: appWorkspaceToolbarWithLabels(
        context.l10n,
        summaryNotifications: _summaryNotifications(context, state),
        primary: _primaryAction(context, state, canWrite, controller),
        onRefresh: controller.refresh,
        isRefreshing: state.isRefreshing,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lastFailure != null) ...<Widget>[
            AppFailureStateView(
              failure: lastFailure,
              onRetry: controller.refresh,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          if (state.isTenantContextRequired &&
              state.query.panel != AccessAdminPanel.registrations)
            AppStateView(
              title: context.l10n.accessAdminTenantContextRequiredTitle,
              body: context.l10n.accessAdminTenantContextRequiredBody,
              variant: AppStateViewVariant.empty,
            )
          else ...<Widget>[
            _PanelSelector(state: state, controller: controller),
            SizedBox(height: Theme.of(context).spacing.md),
            _FiltersBar(
              state: state,
              searchController: _searchController,
              controller: controller,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            _WorklistPanel(
              state: state,
              controller: controller,
              canWrite: canWrite,
              onItemSelected: (AccessAdminItem item) {
                unawaited(_openDetailDialog(context, item, canWrite));
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget? _primaryAction(
    BuildContext context,
    AccessAdminWorkspaceState state,
    bool canWrite,
    AccessAdminWorkspaceController controller,
  ) {
    if (!canWrite ||
        (state.isTenantContextRequired &&
            state.query.panel != AccessAdminPanel.registrations)) {
      return null;
    }

    return switch (state.query.resource) {
      AccessAdminResource.users ||
      AccessAdminResource.demoUsers => AppButton.primary(
        label: context.l10n.accessAdminCreateUserAction,
        leadingIcon: Icons.person_add_alt_1_outlined,
        onPressed: state.isSaving
            ? null
            : () => unawaited(_showCreateUserDialog(context, state)),
      ),
      AccessAdminResource.roles => AppButton.primary(
        label: context.l10n.accessAdminCreateRoleAction,
        leadingIcon: Icons.badge_outlined,
        onPressed: state.isSaving
            ? null
            : () => unawaited(_showCreateRoleDialog(context, state)),
      ),
      _ => null,
    };
  }

  List<AppWorkspaceSummaryNotification> _summaryNotifications(
    BuildContext context,
    AccessAdminWorkspaceState state,
  ) {
    final AccessAdminOverview overview = state.data.overview;
    return <AppWorkspaceSummaryNotification>[
      AppWorkspaceSummaryNotification(
        label: context.l10n.accessAdminActiveUsersLabel,
        count: overview.activeUsers,
        icon: Icons.people_outline,
        onSelected: () {},
      ),
      AppWorkspaceSummaryNotification(
        label: context.l10n.accessAdminRolesLabel,
        count: overview.totalRoles,
        icon: Icons.badge_outlined,
        onSelected: () {},
      ),
      AppWorkspaceSummaryNotification(
        label: context.l10n.accessAdminPermissionsLabel,
        count: overview.totalPermissions,
        icon: Icons.key_outlined,
        onSelected: () {},
      ),
      AppWorkspaceSummaryNotification(
        label: context.l10n.accessAdminModulesLabel,
        count: overview.activeModulesCount,
        icon: Icons.extension_outlined,
        onSelected: () {},
      ),
    ];
  }

  Future<void> _openDetailDialog(
    BuildContext context,
    AccessAdminItem item,
    bool canWrite,
  ) async {
    final AccessAdminWorkspaceController controller = ref.read(
      accessAdminWorkspaceControllerProvider.notifier,
    );
    controller.selectItem(item);

    if (item.resource == AccessAdminResource.users ||
        item.resource == AccessAdminResource.demoUsers) {
      final AppFailure? failure = await controller.loadUserDetail(item);
      if (failure != null && context.mounted) {
        _showSnack(context, context.l10n.failureMessage(failure));
      }
    }

    List<AccessAdminRolePermissionAssignment> rolePermissions =
        const <AccessAdminRolePermissionAssignment>[];
    if (item.resource == AccessAdminResource.roles) {
      final AccessAdminRepository repository = ref.read(
        accessAdminRepositoryProvider,
      );
      final Result<List<AccessAdminRolePermissionAssignment>>
      permissionsResult = await repository.listRolePermissions(item.id);
      if (!context.mounted) {
        return;
      }
      final AppFailure? permissionsFailure = permissionsResult.when(
        success: (List<AccessAdminRolePermissionAssignment> value) {
          rolePermissions = value;
          return null;
        },
        failure: (AppFailure failure) => failure,
      );
      if (permissionsFailure != null) {
        _showSnack(context, context.l10n.failureMessage(permissionsFailure));
      }
    }

    if (!context.mounted) return;

    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final AsyncValue<Result<AccessAdminWorkspaceState>> workspace = ref
              .watch(accessAdminWorkspaceControllerProvider);
          final AccessAdminWorkspaceState? current = workspace.maybeWhen(
            data: (Result<AccessAdminWorkspaceState> result) => result.when(
              success: (AccessAdminWorkspaceState value) => value,
              failure: (_) => null,
            ),
            orElse: () => null,
          );
          final AccessAdminItem selected = current?.selectedItem ?? item;
          final AccessAdminUserDetail? detail = current?.selectedUserDetail;

          return AppDialog(
            title: Text(selected.title),
            icon: Icon(
              selected.resource == AccessAdminResource.roles
                  ? Icons.badge_outlined
                  : Icons.manage_accounts_outlined,
            ),
            scrollable: true,
            maxWidth: 920,
            content: _DetailContent(
              item: selected,
              detail: detail,
              rolePermissions: rolePermissions,
              state: current ?? widget.state,
              canWrite: canWrite,
            ),
            actions: <Widget>[
              if (canWrite &&
                  selected.resource == AccessAdminResource.roles) ...<Widget>[
                AppButton.secondary(
                  label: context.l10n.accessAdminEditRoleAction,
                  leadingIcon: Icons.edit_outlined,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    unawaited(
                      openAccessAdminEditRoleDialog(
                        context,
                        ref,
                        current ?? widget.state,
                        selected,
                      ),
                    );
                  },
                ),
                if (!selected.isSystemCritical)
                  AppButton.secondary(
                    label: context.l10n.accessAdminDeleteRoleAction,
                    leadingIcon: Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      unawaited(_confirmDeleteRole(context, selected));
                    },
                  ),
              ],
              AppButton.secondary(
                label: context.l10n.commonCloseActionLabel,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteRole(
    BuildContext context,
    AccessAdminItem role,
  ) async {
    if (role.isSystemCritical) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final AccessAdminWorkspaceController controller = ref.read(
      accessAdminWorkspaceControllerProvider.notifier,
    );
    final String body = role.userCount > 0
        ? l10n.accessAdminDeleteRoleAssignedBody(role.title, role.userCount)
        : l10n.accessAdminDeleteRoleBody(role.title);

    await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.accessAdminDeleteRoleAction,
        body: body,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final AppFailure? failure = await controller.deleteRole(role);
          return failure;
        },
      ),
    );
  }

  Future<void> _showCreateUserDialog(
    BuildContext context,
    AccessAdminWorkspaceState state,
  ) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    String status = 'ACTIVE';

    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: Text(context.l10n.accessAdminCreateUserAction),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        content: Form(
          key: formKey,
          child: Column(
            children: <Widget>[
              AppTextField(
                controller: emailController,
                labelText: context.l10n.accessAdminEmailLabel,
                validator: (String? value) => (value ?? '').contains('@')
                    ? null
                    : context.l10n.validationRequired,
              ),
              SizedBox(height: Theme.of(context).spacing.md),
              AppTextField(
                controller: titleController,
                labelText: context.l10n.accessAdminPositionLabel,
                validator: (String? value) => (value ?? '').trim().isEmpty
                    ? context.l10n.validationRequired
                    : null,
              ),
              SizedBox(height: Theme.of(context).spacing.md),
              AppTextField(
                controller: passwordController,
                labelText: context.l10n.accessAdminPasswordLabel,
                obscureText: true,
                validator: (String? value) => (value ?? '').length >= 8
                    ? null
                    : context.l10n.accessAdminPasswordHint,
              ),
              SizedBox(height: Theme.of(context).spacing.md),
              AppSelectField<String>(
                labelText: context.l10n.accessAdminStatusLabel,
                value: status,
                options: state.data.lookups.userStatuses
                    .map(
                      (String value) =>
                          AppSelectOption<String>(value: value, label: value),
                    )
                    .toList(growable: false),
                onChanged: (String? value) {
                  if (value != null) status = value;
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          AppButton.secondary(
            label: context.l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton.primary(
            label: context.l10n.commonSaveActionLabel,
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final String? tenantId =
                  state.query.tenantId ??
                  state.data.lookups.tenants.firstOrNull?.id;
              if (tenantId == null) {
                _showSnack(
                  context,
                  context.l10n.accessAdminTenantContextRequiredBody,
                );
                return;
              }
              final AppFailure? failure = await ref
                  .read(accessAdminWorkspaceControllerProvider.notifier)
                  .createUser(
                    AccessAdminUserDraft(
                      tenantId: tenantId,
                      facilityId: state.query.facilityId,
                      email: emailController.text.trim(),
                      phone: phoneController.text.trim(),
                      positionTitle: titleController.text.trim(),
                      password: passwordController.text,
                      status: status,
                    ),
                  );
              if (!dialogContext.mounted) return;
              if (failure == null) {
                Navigator.of(dialogContext).pop();
              } else {
                _showSnack(dialogContext, context.l10n.failureMessage(failure));
              }
            },
          ),
        ],
      ),
    );

    emailController.dispose();
    phoneController.dispose();
    titleController.dispose();
    passwordController.dispose();
  }

  Future<void> _showCreateRoleDialog(
    BuildContext context,
    AccessAdminWorkspaceState state,
  ) async {
    final bool? saved = await openAccessAdminCreateRoleDialog(
      context,
      ref,
      state,
    );
    if (saved == true && context.mounted) {
      await ref.read(accessAdminWorkspaceControllerProvider.notifier).refresh();
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PanelSelector extends ConsumerWidget {
  const _PanelSelector({required this.state, required this.controller});

  final AccessAdminWorkspaceState state;
  final AccessAdminWorkspaceController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isSuperAdmin = ref.watch(appAccessPolicyProvider).isElevated;
    final List<AccessAdminPanel> panels = AccessAdminPanel.values
        .where(
          (AccessAdminPanel panel) =>
              panel != AccessAdminPanel.registrations || isSuperAdmin,
        )
        .toList(growable: false);

    return Wrap(
      spacing: Theme.of(context).spacing.sm,
      runSpacing: Theme.of(context).spacing.sm,
      children: panels
          .map((AccessAdminPanel panel) {
            final bool selected = state.query.panel == panel;
            return FilterChip(
              label: Text(_panelLabel(context, panel)),
              selected: selected,
              onSelected: state.isSaving
                  ? null
                  : (_) => unawaited(controller.applyPanel(panel)),
            );
          })
          .toList(growable: false),
    );
  }

  String _panelLabel(BuildContext context, AccessAdminPanel panel) {
    return switch (panel) {
      AccessAdminPanel.overview => context.l10n.accessAdminPanelOverview,
      AccessAdminPanel.directory => context.l10n.accessAdminPanelDirectory,
      AccessAdminPanel.roles => context.l10n.accessAdminPanelRoles,
      AccessAdminPanel.permissions => context.l10n.accessAdminPanelPermissions,
      AccessAdminPanel.entitlements =>
        context.l10n.accessAdminPanelEntitlements,
      AccessAdminPanel.registrations =>
        context.l10n.accessAdminPanelRegistrations,
      AccessAdminPanel.demo => context.l10n.accessAdminPanelDemo,
    };
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.state,
    required this.searchController,
    required this.controller,
  });

  final AccessAdminWorkspaceState state;
  final TextEditingController searchController;
  final AccessAdminWorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return AppContentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: searchController,
            labelText: context.l10n.accessAdminSearchLabel,
            hintText: context.l10n.accessAdminSearchHint,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: controller.applySearch,
          ),
          if (state.query.resource == AccessAdminResource.users) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.md),
            AppSelectField<String?>(
              labelText: context.l10n.accessAdminStatusLabel,
              value: state.query.status,
              options: <AppSelectOption<String?>>[
                AppSelectOption<String?>(
                  value: null,
                  label: context.l10n.accessAdminAllStatusesLabel,
                ),
                ...state.data.lookups.userStatuses.map(
                  (String value) =>
                      AppSelectOption<String?>(value: value, label: value),
                ),
              ],
              onChanged: (String? value) {
                unawaited(controller.applyStatusFilter(value));
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _WorklistPanel extends StatelessWidget {
  const _WorklistPanel({
    required this.state,
    required this.controller,
    required this.canWrite,
    required this.onItemSelected,
  });

  final AccessAdminWorkspaceState state;
  final AccessAdminWorkspaceController controller;
  final bool canWrite;
  final ValueChanged<AccessAdminItem> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final AppPage<AccessAdminItem> page = state.data.page;
    if (page.items.isEmpty) {
      return AppStateView(
        title: context.l10n.accessAdminEmptyTitle,
        body: context.l10n.accessAdminEmptyBody,
        variant: AppStateViewVariant.empty,
      );
    }

    return AppContentPanel(
      child: AppListTable<AccessAdminItem>(
        page: page,
        isLoading: state.isRefreshing,
        onRowSelected: onItemSelected,
        onPageChanged: controller.changePage,
        mobileItemBuilder: (BuildContext context, AccessAdminItem item) {
          final bool isRole = state.query.resource == AccessAdminResource.roles;
          return ListTile(
            title: Text(item.title),
            subtitle: Text(item.subtitle ?? item.effectiveDisplayId),
            trailing: isRole
                ? Chip(
                    label: Text(
                      item.isFacilityScopedRole
                          ? context.l10n.accessAdminRoleScopeFacilityBadge
                          : context.l10n.accessAdminRoleScopeTenantBadge,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                  )
                : Text(item.status ?? ''),
            onTap: () => onItemSelected(item),
          );
        },
        columns: <AppListTableColumn<AccessAdminItem>>[
          AppListTableColumn<AccessAdminItem>(
            label: context.l10n.accessAdminColumnId,
            cellBuilder: (BuildContext context, AccessAdminItem item) =>
                Text(item.effectiveDisplayId),
          ),
          AppListTableColumn<AccessAdminItem>(
            label: context.l10n.accessAdminColumnName,
            cellBuilder: (BuildContext context, AccessAdminItem item) =>
                Text(item.title),
          ),
          if (state.query.resource == AccessAdminResource.roles)
            AppListTableColumn<AccessAdminItem>(
              label: context.l10n.accessAdminColumnScope,
              cellBuilder: (BuildContext context, AccessAdminItem item) {
                final bool isFacility = item.isFacilityScopedRole;
                return Chip(
                  avatar: Icon(
                    isFacility
                        ? Icons.local_hospital_outlined
                        : Icons.domain_outlined,
                    size: 16,
                  ),
                  label: Text(
                    isFacility
                        ? (item.facilityName?.trim().isNotEmpty == true
                              ? '${context.l10n.accessAdminRoleScopeFacilityBadge} · ${item.facilityName}'
                              : context.l10n.accessAdminRoleScopeFacilityBadge)
                        : context.l10n.accessAdminRoleScopeTenantBadge,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          AppListTableColumn<AccessAdminItem>(
            label: context.l10n.accessAdminColumnDetails,
            cellBuilder: (BuildContext context, AccessAdminItem item) =>
                Text(item.subtitle ?? '—'),
          ),
          if (state.query.resource != AccessAdminResource.roles)
            AppListTableColumn<AccessAdminItem>(
              label: context.l10n.accessAdminColumnStatus,
              cellBuilder: (BuildContext context, AccessAdminItem item) =>
                  Text(item.status ?? '—'),
            ),
        ],
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({
    required this.item,
    required this.detail,
    required this.state,
    required this.canWrite,
    this.rolePermissions = const <AccessAdminRolePermissionAssignment>[],
  });

  final AccessAdminItem item;
  final AccessAdminUserDetail? detail;
  final AccessAdminWorkspaceState state;
  final bool canWrite;
  final List<AccessAdminRolePermissionAssignment> rolePermissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AccessAdminWorkspaceController controller = ref.read(
      accessAdminWorkspaceControllerProvider.notifier,
    );
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool isRole = item.resource == AccessAdminResource.roles;

    final List<AppPermissionAssignmentOption> rolePermissionOptions =
        rolePermissions
            .map((AccessAdminRolePermissionAssignment assignment) {
              final String code =
                  assignment.permissionName ?? assignment.permissionId ?? '';
              if (code.isEmpty) {
                return null;
              }
              return AppPermissionAssignmentOption(
                id: assignment.permissionId ?? assignment.id,
                code: code,
                label: l10n.permissionCatalogLabelForCode(code),
                description: code,
              );
            })
            .whereType<AppPermissionAssignmentOption>()
            .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DetailRow(
          label: l10n.accessAdminColumnId,
          value: item.effectiveDisplayId,
        ),
        if (isRole) ...<Widget>[
          _DetailRow(
            label: l10n.accessAdminColumnScope,
            value: item.isFacilityScopedRole
                ? (item.facilityName?.trim().isNotEmpty == true
                      ? '${l10n.accessAdminRoleScopeFacilityBadge} · ${item.facilityName}'
                      : l10n.accessAdminRoleScopeFacilityBadge)
                : l10n.accessAdminRoleScopeTenantBadge,
          ),
          if ((item.subtitle ?? '').trim().isNotEmpty)
            _DetailRow(
              label: l10n.accessAdminCreateRoleDetailsSectionTitle,
              value: item.subtitle!,
            ),
          _DetailRow(
            label: l10n.accessAdminRolePermissionsLabel,
            value: l10n.hrAccessPermissionCountLabel(
              rolePermissionOptions.length,
            ),
          ),
          _DetailRow(
            label: l10n.accessAdminRoleDetailUsersLabel,
            value: '${item.userCount}',
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.accessAdminRolePermissionsLabel,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          AppPermissionGroupedView(
            permissions: rolePermissionOptions,
            initiallyExpandAll: rolePermissionOptions.length <= 24,
            emptyMessage: l10n.accessAdminRoleDetailNoPermissionsMessage,
          ),
        ] else ...<Widget>[
          if (item.email != null)
            _DetailRow(label: l10n.accessAdminEmailLabel, value: item.email!),
          if (item.phone != null)
            _DetailRow(label: l10n.accessAdminPhoneLabel, value: item.phone!),
          if (item.positionTitle != null)
            _DetailRow(
              label: l10n.accessAdminPositionLabel,
              value: item.positionTitle!,
            ),
          if (item.status != null)
            _DetailRow(label: l10n.accessAdminStatusLabel, value: item.status!),
          SizedBox(height: theme.spacing.md),
          AppUserAccessPanel(
            roleGroups:
                (detail?.resolvedRoleGroups ??
                        item.roles
                            .map(
                              (AccessAdminRoleRef role) =>
                                  AccessAdminRolePermissionGroup(
                                    roleId: role.id,
                                    roleName: role.name,
                                    userRoleId: role.userRoleId,
                                    resourceUuid: role.resourceUuid,
                                  ),
                            )
                            .toList(growable: false))
                    .map(
                      (AccessAdminRolePermissionGroup group) =>
                          AppUserAccessRoleGroup(
                            roleId: group.roleId,
                            roleName: group.roleName,
                            userRoleId: group.userRoleId,
                            permissions: group.permissions
                                .map(
                                  (AccessAdminRolePermissionPreview preview) =>
                                      preview.name,
                                )
                                .toList(growable: false),
                          ),
                    )
                    .toList(growable: false),
            directPermissions:
                (detail?.directPermissions ??
                        const <AccessAdminPermissionRef>[])
                    .map(
                      (AccessAdminPermissionRef permission) =>
                          AppUserAccessDirectPermission(
                            id: permission.mutationId,
                            name: permission.name,
                          ),
                    )
                    .toList(growable: false),
          ),
        ],
        if (item.staffProfileId != null) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppButton.secondary(
            label: l10n.accessAdminOpenHrProfileAction,
            leadingIcon: AppRouteIcons.hr,
            onPressed: () => context.go(AppRoutes.hr.location()),
          ),
        ],
        if (item.isClinicalFlowRole)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.sm),
            child: Text(
              l10n.accessAdminClinicalRoleHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (canWrite && !isRole) ...<Widget>[
          SizedBox(height: theme.spacing.lg),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: _actions(context, controller),
          ),
        ],
      ],
    );
  }

  List<Widget> _actions(
    BuildContext context,
    AccessAdminWorkspaceController controller,
  ) {
    final List<Widget> actions = <Widget>[];

    if (item.resource == AccessAdminResource.registrationFollowUps) {
      actions.add(
        AppButton.primary(
          label: context.l10n.accessAdminActivateRegistrationAction,
          onPressed: () => unawaited(controller.activateRegistration(item)),
        ),
      );
      actions.add(
        AppButton.secondary(
          label: context.l10n.accessAdminRejectRegistrationAction,
          onPressed: () => unawaited(controller.rejectRegistration(item)),
        ),
      );
    }

    if (item.resource == AccessAdminResource.users ||
        item.resource == AccessAdminResource.demoUsers) {
      if (item.status == 'ACTIVE') {
        actions.add(
          AppButton.secondary(
            label: context.l10n.accessAdminDeactivateAction,
            onPressed: () => unawaited(
              controller.setUserStatus(item, 'INACTIVE').then((
                AppFailure? failure,
              ) {
                if (failure != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.failureMessage(failure)),
                    ),
                  );
                }
              }),
            ),
          ),
        );
      } else {
        actions.add(
          AppButton.secondary(
            label: context.l10n.accessAdminActivateAction,
            onPressed: () =>
                unawaited(controller.setUserStatus(item, 'ACTIVE')),
          ),
        );
      }
    }

    if (item.isDemo && state.data.permissions.canResetDemoPasswords) {
      actions.add(
        AppButton.secondary(
          label: context.l10n.accessAdminResetDemoPasswordAction,
          leadingIcon: Icons.lock_reset_outlined,
          onPressed: () => unawaited(controller.resetDemoPassword(item)),
        ),
      );
    }

    return actions;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: Theme.of(context).spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 160,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

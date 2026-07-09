import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showManageUsersDialog(BuildContext context, WidgetRef ref) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => const _ManageUsersDialog(),
  );
}

Future<void> showManageRolesPermissionsDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => const _ManageRolesPermissionsDialog(),
  );
}

abstract class _ScopedAccessAdminListDialogState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  static const int pageSize = 12;

  final TextEditingController searchController = TextEditingController();
  Timer? searchDebounce;
  bool loading = true;
  bool mutating = false;
  AppFailure? failure;
  AppPageRequest pageRequest = const AppPageRequest(pageSize: pageSize);
  int totalItemCount = 0;
  List<AccessAdminItem> items = const <AccessAdminItem>[];
  AccessAdminWorkspaceData? workspaceData;

  AccessAdminRepository get repository =>
      ref.read(accessAdminRepositoryProvider);

  AccessAdminWorkspaceQuery get listQuery;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    unawaited(reload(resetPage: true));
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(reload(resetPage: true));
    });
  }

  Future<void> reload({required bool resetPage}) async {
    if (resetPage) {
      pageRequest = pageRequest.first();
    }
    setState(() {
      loading = true;
      failure = null;
    });

    final Result<AccessAdminWorkspaceData> result = await repository.getWorkspace(
      listQuery.copyWith(
        search: searchController.text.trim(),
        pageRequest: pageRequest,
      ),
    );

    if (!mounted) return;
    result.when(
      success: (AccessAdminWorkspaceData data) {
        setState(() {
          loading = false;
          workspaceData = data;
          items = data.page.items;
          totalItemCount = data.page.totalItemCount ?? data.page.items.length;
        });
      },
      failure: (AppFailure loadFailure) {
        setState(() {
          loading = false;
          failure = loadFailure;
          items = const <AccessAdminItem>[];
        });
      },
    );
  }

  Future<void> onPageChanged(AppPageRequest request) async {
    pageRequest = request;
    await reload(resetPage: false);
  }

  AccessAdminWorkspaceState? buildWorkspaceState() {
    final AccessAdminWorkspaceData? data = workspaceData;
    if (data == null) {
      return null;
    }
    return AccessAdminWorkspaceState(data: data, query: data.query);
  }

  AppPage<AccessAdminItem> get currentPage => AppPage<AccessAdminItem>(
    items: items,
    request: pageRequest,
    totalItemCount: totalItemCount,
  );

  bool get canWrite => workspaceData?.permissions.canWrite ?? false;

  Widget buildTable({
    required AppLocalizations l10n,
    required ValueChanged<AccessAdminItem>? onRowSelected,
    required List<AppListTableColumn<AccessAdminItem>> columns,
  }) {
    if (failure != null) {
      return AppFailureStateView(
        failure: failure!,
        onRetry: () => unawaited(reload(resetPage: true)),
      );
    }

    return AppListTable<AccessAdminItem>(
      page: currentPage,
      isLoading: loading || mutating,
      onRowSelected: onRowSelected,
      onPageChanged: onPageChanged,
      previousPageLabel: l10n.hrPreviousPageLabel,
      nextPageLabel: l10n.hrNextPageLabel,
      pageLabelBuilder: (AppPage<AccessAdminItem> page) {
        final int total = page.totalItemCount ?? page.items.length;
        if (total == 0) return l10n.commonTableEmptyLabel;
        final int start = page.pageIndex * page.pageSize + 1;
        final int end = start + page.items.length - 1;
        return '$start-$end / $total';
      },
      columns: columns,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.accessAdminEmptyTitle,
        body: l10n.accessAdminEmptyBody,
      ),
      mobileItemBuilder: (BuildContext context, AccessAdminItem item) {
        return ListTile(
          title: Text(item.title),
          subtitle: Text(item.subtitle ?? item.effectiveDisplayId),
          trailing: Text(item.status ?? '—'),
          onTap: onRowSelected == null ? null : () => onRowSelected(item),
        );
      },
    );
  }
}

class _ManageUsersDialog extends ConsumerStatefulWidget {
  const _ManageUsersDialog();

  @override
  ConsumerState<_ManageUsersDialog> createState() => _ManageUsersDialogState();
}

class _ManageUsersDialogState extends _ScopedAccessAdminListDialogState<_ManageUsersDialog> {
  @override
  AccessAdminWorkspaceQuery get listQuery => const AccessAdminWorkspaceQuery();

  Future<void> _openCreateUserDialog() async {
    final AccessAdminWorkspaceState? state = buildWorkspaceState();
    if (state == null || !mounted) {
      return;
    }
    await openAccessAdminCreateUserDialog(context, ref, state);
    if (mounted) {
      await reload(resetPage: true);
    }
  }

  Future<void> _openEditUserDialog(
    AccessAdminItem item, {
    AccessAdminUserDetail? detail,
  }) async {
    final AccessAdminWorkspaceState? state = buildWorkspaceState();
    if (state == null || !mounted) {
      return;
    }

    AccessAdminUserDetail? resolvedDetail = detail;
    if (resolvedDetail == null) {
      setState(() => mutating = true);
      final Result<AccessAdminUserDetail> detailResult = await repository
          .getUserDetail(
            item.id,
            tenantId: workspaceData?.query.tenantId,
            facilityId: workspaceData?.query.facilityId,
          );
      if (!mounted) return;
      setState(() => mutating = false);
      resolvedDetail = detailResult.when(
        success: (AccessAdminUserDetail value) => value,
        failure: (_) => null,
      );
      if (resolvedDetail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detailResult.when(
                success: (_) => '',
                failure: (AppFailure loadFailure) =>
                    context.l10n.failureMessage(loadFailure),
              ),
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    await openAccessAdminEditUserDialog(
      context,
      ref,
      state,
      user: resolvedDetail.item,
      detail: resolvedDetail,
    );
    if (mounted) {
      await reload(resetPage: false);
    }
  }

  Future<void> _confirmDeleteUser(AccessAdminItem user) async {
    if (user.isDemo || user.isSystemCritical) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.accessAdminDeleteUserAction,
        body: l10n.tenantFacilityDeleteConfirmationBody,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<void> result = await repository.deleteUser(user.id);
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      await reload(resetPage: items.length <= 1);
    }
  }

  Future<void> _openUserDetail(AccessAdminItem item) async {
    setState(() => mutating = true);
    final Result<AccessAdminUserDetail> detailResult = await repository
        .getUserDetail(
          item.id,
          tenantId: workspaceData?.query.tenantId,
          facilityId: workspaceData?.query.facilityId,
        );
    if (!mounted) return;
    setState(() => mutating = false);

    final AccessAdminUserDetail? detail = detailResult.when(
      success: (AccessAdminUserDetail value) => value,
      failure: (_) => null,
    );
    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detailResult.when(
              success: (_) => '',
              failure: (AppFailure loadFailure) =>
                  context.l10n.failureMessage(loadFailure),
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => _AccessAdminUserDetailDialog(
        item: detail.item,
        detail: detail,
        canWrite: canWrite,
        onStatusChanged: (String status) async {
          final Result<void> result = await repository.setUserStatus(
            item.id,
            status,
          );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
        onEdit: () {
          Navigator.of(dialogContext).pop();
          unawaited(_openEditUserDialog(detail.item, detail: detail));
        },
        onDelete: () {
          Navigator.of(dialogContext).pop();
          unawaited(_confirmDeleteUser(detail.item));
        },
      ),
    );
    if (mounted) {
      await reload(resetPage: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AppDialog(
      title: Text(l10n.homeManageUsersTitle),
      icon: const Icon(Icons.people_outline),
      pinActionsToBottom: true,
      maxWidth: 1040,
      content: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSearchBar(
              controller: searchController,
              hintText: l10n.accessAdminSearchHint,
              semanticLabel: l10n.accessAdminSearchLabel,
              onSubmitted: (_) => unawaited(reload(resetPage: true)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: buildTable(
                l10n: l10n,
                onRowSelected: (AccessAdminItem item) =>
                    unawaited(_openUserDetail(item)),
                columns: <AppListTableColumn<AccessAdminItem>>[
                  AppListTableColumn<AccessAdminItem>(
                    label: l10n.accessAdminColumnId,
                    cellBuilder: (_, AccessAdminItem item) =>
                        Text(item.effectiveDisplayId),
                  ),
                  AppListTableColumn<AccessAdminItem>(
                    label: l10n.accessAdminColumnName,
                    cellBuilder: (_, AccessAdminItem item) => Text(item.title),
                  ),
                  AppListTableColumn<AccessAdminItem>(
                    label: l10n.accessAdminColumnDetails,
                    cellBuilder: (_, AccessAdminItem item) =>
                        Text(item.subtitle ?? item.email ?? '—'),
                  ),
                  AppListTableColumn<AccessAdminItem>(
                    label: l10n.accessAdminColumnStatus,
                    cellBuilder: (_, AccessAdminItem item) =>
                        Text(item.status ?? '—'),
                  ),
                  if (canWrite)
                    AppListTableColumn<AccessAdminItem>(
                      label: '',
                      alwaysVisible: true,
                      cellBuilder:
                          (BuildContext context, AccessAdminItem user) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            AppButton.tertiary(
                              leadingIcon: Icons.edit_outlined,
                              label: l10n.tenantFacilityEditAction,
                              semanticLabel: l10n.tenantFacilityEditAction,
                              tooltip: l10n.tenantFacilityEditAction,
                              enabled: !loading && !mutating,
                              onPressed: !loading && !mutating
                                  ? () => unawaited(_openEditUserDialog(user))
                                  : null,
                            ),
                            AppButton.tertiary(
                              leadingIcon: Icons.delete_outline,
                              label: l10n.tenantFacilityDeleteAction,
                              semanticLabel: l10n.tenantFacilityDeleteAction,
                              tooltip: l10n.tenantFacilityDeleteAction,
                              color: colorScheme.error,
                              enabled: !loading && !mutating,
                              onPressed: !loading && !mutating
                                  ? () => unawaited(_confirmDeleteUser(user))
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (canWrite)
          AppButton.primary(
            label: l10n.accessAdminCreateUserAction,
            leadingIcon: Icons.person_add_alt_1_outlined,
            onPressed: loading || mutating
                ? null
                : () => unawaited(_openCreateUserDialog()),
          ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ManageRolesPermissionsDialog extends ConsumerStatefulWidget {
  const _ManageRolesPermissionsDialog();

  @override
  ConsumerState<_ManageRolesPermissionsDialog> createState() =>
      _ManageRolesPermissionsDialogState();
}

class _ManageRolesPermissionsDialogState
    extends _ScopedAccessAdminListDialogState<_ManageRolesPermissionsDialog> {
  @override
  AccessAdminWorkspaceQuery get listQuery => const AccessAdminWorkspaceQuery(
    panel: AccessAdminPanel.roles,
    resource: AccessAdminResource.roles,
  );

  Future<void> _openCreateRoleDialog() async {
    final AccessAdminWorkspaceState? state = buildWorkspaceState();
    if (state == null || !mounted) {
      return;
    }
    await openAccessAdminCreateRoleDialog(context, ref, state);
    if (mounted) {
      await reload(resetPage: true);
    }
  }

  Future<void> _openEditRoleDialog(AccessAdminItem role) async {
    final AccessAdminWorkspaceState? state = buildWorkspaceState();
    if (state == null || !mounted) {
      return;
    }
    await openAccessAdminEditRoleDialog(context, ref, state, role);
    if (mounted) {
      await reload(resetPage: false);
    }
  }

  Future<void> _confirmDeleteRole(AccessAdminItem role) async {
    if (role.isSystemCritical) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.accessAdminDeleteRoleAction,
        body: l10n.tenantFacilityDeleteConfirmationBody,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<void> result = await repository.deleteRole(role.id);
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      await reload(resetPage: items.length <= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AppDialog(
      title: Text(l10n.homeManageRolesPermissionsTitle),
      icon: const Icon(Icons.admin_panel_settings_outlined),
      pinActionsToBottom: true,
      maxWidth: 1040,
      content: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSearchBar(
              controller: searchController,
              hintText: l10n.accessAdminSearchHint,
              semanticLabel: l10n.accessAdminSearchLabel,
              onSubmitted: (_) => unawaited(reload(resetPage: true)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: buildTable(
                l10n: l10n,
                onRowSelected: canWrite
                    ? (AccessAdminItem role) =>
                          unawaited(_openEditRoleDialog(role))
                    : null,
                columns: <AppListTableColumn<AccessAdminItem>>[
                  AppListTableColumn<AccessAdminItem>(
                    label: l10n.accessAdminColumnId,
                    cellBuilder: (_, AccessAdminItem item) =>
                        Text(item.effectiveDisplayId),
                  ),
                  AppListTableColumn<AccessAdminItem>(
                    label: l10n.accessAdminColumnName,
                    cellBuilder: (_, AccessAdminItem item) => Text(item.title),
                  ),
                  AppListTableColumn<AccessAdminItem>(
                    label: l10n.accessAdminColumnDetails,
                    cellBuilder: (_, AccessAdminItem item) =>
                        Text(item.subtitle ?? '—'),
                  ),
                  if (canWrite)
                    AppListTableColumn<AccessAdminItem>(
                      label: '',
                      alwaysVisible: true,
                      cellBuilder:
                          (BuildContext context, AccessAdminItem role) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            AppButton.tertiary(
                              leadingIcon: Icons.edit_outlined,
                              label: l10n.tenantFacilityEditAction,
                              semanticLabel: l10n.tenantFacilityEditAction,
                              tooltip: l10n.tenantFacilityEditAction,
                              enabled: !loading && !mutating,
                              onPressed: !loading && !mutating
                                  ? () => unawaited(_openEditRoleDialog(role))
                                  : null,
                            ),
                            if (!role.isSystemCritical)
                              AppButton.tertiary(
                                leadingIcon: Icons.delete_outline,
                                label: l10n.tenantFacilityDeleteAction,
                                semanticLabel: l10n.tenantFacilityDeleteAction,
                                tooltip: l10n.tenantFacilityDeleteAction,
                                color: colorScheme.error,
                                enabled: !loading && !mutating,
                                onPressed: !loading && !mutating
                                    ? () => unawaited(_confirmDeleteRole(role))
                                    : null,
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (canWrite)
          AppButton.primary(
            label: l10n.accessAdminCreateRoleAction,
            leadingIcon: Icons.badge_outlined,
            onPressed: loading || mutating
                ? null
                : () => unawaited(_openCreateRoleDialog()),
          ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _AccessAdminUserDetailDialog extends StatefulWidget {
  const _AccessAdminUserDetailDialog({
    required this.item,
    required this.detail,
    required this.canWrite,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final AccessAdminItem item;
  final AccessAdminUserDetail detail;
  final bool canWrite;
  final Future<AppFailure?> Function(String status) onStatusChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_AccessAdminUserDetailDialog> createState() =>
      _AccessAdminUserDetailDialogState();
}

class _AccessAdminUserDetailDialogState
    extends State<_AccessAdminUserDetailDialog> {
  bool _saving = false;

  Future<void> _toggleStatus() async {
    final String nextStatus = widget.item.status == 'ACTIVE'
        ? 'INACTIVE'
        : 'ACTIVE';
    setState(() => _saving = true);
    final AppFailure? failure = await widget.onStatusChanged(nextStatus);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.failureMessage(failure))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AccessAdminItem item = widget.item;
    final AccessAdminUserDetail detail = widget.detail;
    final int roleCount = item.roles.length;
    final int effectivePermissionCount = detail.effectivePermissions.length;

    return AppDialog(
      title: Text(item.title),
      icon: const Icon(Icons.person_outline),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 840,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _UserDetailSummaryCard(item: item),
          SizedBox(height: theme.spacing.md),
          AppSectionPanel(
            title: l10n.accessAdminUserDetailProfileSectionTitle,
            description: l10n.accessAdminUserDetailProfileSectionDescription,
            leadingIcon: Icons.badge_outlined,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth >= 560;
                  final List<Widget> fields = <Widget>[
                    _UserDetailInfoTile(
                      icon: Icons.tag_outlined,
                      label: l10n.accessAdminColumnId,
                      value: item.effectiveDisplayId,
                    ),
                    if (item.email != null)
                      _UserDetailInfoTile(
                        icon: Icons.mail_outline,
                        label: l10n.accessAdminEmailLabel,
                        value: item.email!,
                      ),
                    if (item.phone != null)
                      _UserDetailInfoTile(
                        icon: Icons.phone_outlined,
                        label: l10n.accessAdminPhoneLabel,
                        value: item.phone!,
                      ),
                    if (item.positionTitle != null)
                      _UserDetailInfoTile(
                        icon: Icons.work_outline,
                        label: l10n.accessAdminPositionLabel,
                        value: item.positionTitle!,
                      ),
                    if (item.tenantId != null)
                      _UserDetailInfoTile(
                        icon: Icons.apartment_outlined,
                        label: l10n.settingsWorkspaceTenantLabel,
                        value: item.tenantId!,
                      ),
                    if (item.facilityId != null)
                      _UserDetailInfoTile(
                        icon: Icons.local_hospital_outlined,
                        label: l10n.settingsWorkspaceFacilityLabel,
                        value: item.facilityId!,
                      ),
                  ];

                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: fields,
                    );
                  }

                  final List<Widget> rows = <Widget>[];
                  for (var index = 0; index < fields.length; index += 2) {
                    rows.add(
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: fields[index]),
                          if (index + 1 < fields.length) ...<Widget>[
                            SizedBox(width: theme.spacing.md),
                            Expanded(child: fields[index + 1]),
                          ],
                        ],
                      ),
                    );
                    if (index + 2 < fields.length) {
                      rows.add(SizedBox(height: theme.spacing.sm));
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rows,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          AppSectionPanel(
            title: l10n.accessAdminAssignedRolesLabel,
            description: l10n.accessAdminUserDetailRolesSectionDescription,
            leadingIcon: Icons.groups_outlined,
            trailing: roleCount > 0
                ? _UserDetailCountChip(count: roleCount)
                : null,
            children: <Widget>[
              if (item.roles.isEmpty)
                AppMessagePanel(
                  icon: Icons.info_outline,
                  message: l10n.accessAdminUserDetailNoRolesMessage,
                  density: AppContentPanelDensity.compact,
                )
              else
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: item.roles
                      .map(
                        (AccessAdminRoleRef role) => Chip(
                          avatar: Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          label: Text(role.name),
                          backgroundColor: colorScheme.primaryContainer,
                          side: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          AppSectionPanel(
            title: l10n.accessAdminEffectivePermissionsLabel,
            description: l10n.accessAdminUserDetailPermissionsSectionDescription,
            leadingIcon: Icons.security_outlined,
            trailing: effectivePermissionCount > 0
                ? _UserDetailCountChip(count: effectivePermissionCount)
                : null,
            children: <Widget>[
              if (effectivePermissionCount == 0)
                AppMessagePanel(
                  icon: Icons.info_outline,
                  message: l10n.accessAdminUserDetailNoPermissionsMessage,
                  density: AppContentPanelDensity.compact,
                )
              else ...<Widget>[
                if (detail.rolePermissionPreview.isNotEmpty) ...<Widget>[
                  Text(
                    l10n.accessAdminUserDetailRolePermissionsLabel,
                    style: theme.textTheme.labelLarge,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Wrap(
                    spacing: theme.spacing.xs,
                    runSpacing: theme.spacing.xs,
                    children: detail.rolePermissionPreview
                        .map(
                          (AccessAdminRolePermissionPreview preview) =>
                              _UserDetailPermissionChip(
                                label: l10n.permissionCatalogLabelForCode(
                                  preview.name,
                                ),
                                source: preview.sourceRole,
                              ),
                        )
                        .toList(growable: false),
                  ),
                  SizedBox(height: theme.spacing.sm),
                ],
                if (detail.directPermissions.isNotEmpty) ...<Widget>[
                  Text(
                    l10n.hrAccessDirectPermissionsLabel,
                    style: theme.textTheme.labelLarge,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Wrap(
                    spacing: theme.spacing.xs,
                    runSpacing: theme.spacing.xs,
                    children: detail.directPermissions
                        .map(
                          (AccessAdminPermissionRef permission) =>
                              _UserDetailPermissionChip(
                                label: l10n.permissionCatalogLabelForCode(
                                  permission.name,
                                ),
                                emphasized: true,
                              ),
                        )
                        .toList(growable: false),
                  ),
                  SizedBox(height: theme.spacing.sm),
                ],
                if (detail.rolePermissionPreview.isEmpty &&
                    detail.directPermissions.isEmpty)
                  Wrap(
                    spacing: theme.spacing.xs,
                    runSpacing: theme.spacing.xs,
                    children: detail.effectivePermissions
                        .map(
                          (String permission) => _UserDetailPermissionChip(
                            label: l10n.permissionCatalogLabelForCode(permission),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ],
          ),
          if (item.isDemo || item.isSystemCritical) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppFormInformationBanner(
              title: item.isDemo
                  ? l10n.accessAdminUserDetailDemoAccountTitle
                  : l10n.accessAdminUserDetailSystemAccountTitle,
              message: item.isDemo
                  ? l10n.accessAdminUserDetailDemoAccountMessage
                  : l10n.accessAdminUserDetailSystemAccountMessage,
              variant: AppFormInformationVariant.warning,
              icon: item.isDemo
                  ? Icons.science_outlined
                  : Icons.admin_panel_settings_outlined,
            ),
          ],
        ],
      ),
      actions: <Widget>[
        if (widget.canWrite) ...<Widget>[
          AppButton.primary(
            leadingIcon: Icons.edit_outlined,
            label: l10n.accessAdminEditUserAction,
            onPressed: _saving ? null : widget.onEdit,
          ),
          AppButton.secondary(
            leadingIcon: item.status == 'ACTIVE'
                ? Icons.person_off_outlined
                : Icons.person_outline,
            label: item.status == 'ACTIVE'
                ? l10n.accessAdminDeactivateAction
                : l10n.accessAdminActivateAction,
            isLoading: _saving,
            onPressed: _saving ? null : _toggleStatus,
          ),
          if (!item.isDemo && !item.isSystemCritical)
            AppButton.secondary(
              leadingIcon: Icons.delete_outline,
              label: l10n.accessAdminDeleteUserAction,
              color: colorScheme.error,
              onPressed: _saving ? null : widget.onDelete,
            ),
        ],
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _UserDetailSummaryCard extends StatelessWidget {
  const _UserDetailSummaryCard({required this.item});

  final AccessAdminItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return AppContentPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text(
              _userInitials(item.title),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((item.positionTitle ?? '').isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    item.positionTitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if ((item.email ?? '').isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.mail_outline,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: theme.spacing.xs),
                      Expanded(
                        child: Text(
                          item.email!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: theme.spacing.sm),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    if (item.status != null)
                      _UserDetailStatusChip(status: item.status!),
                    if (item.isDemo)
                      Chip(
                        avatar: Icon(
                          Icons.science_outlined,
                          size: 16,
                          color: colorScheme.tertiary,
                        ),
                        label: Text(context.l10n.accessAdminPanelDemo),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _userInitials(String value) {
    final List<String> parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length < 2 ? 1 : 2)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _UserDetailStatusChip extends StatelessWidget {
  const _UserDetailStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppWorkspaceStatusTone tone = _statusTone(status);
    final Color foreground = _toneColor(colorScheme, tone);
    final IconData icon = switch (status) {
      'ACTIVE' => Icons.check_circle_outline,
      'INACTIVE' => Icons.pause_circle_outline,
      'SUSPENDED' => Icons.block_outlined,
      'PENDING' => Icons.hourglass_top_outlined,
      _ => Icons.info_outline,
    };

    return Chip(
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(status),
      backgroundColor: foreground.withValues(alpha: 0.12),
      side: BorderSide(color: foreground.withValues(alpha: 0.24)),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  AppWorkspaceStatusTone _statusTone(String value) {
    return switch (value) {
      'ACTIVE' => AppWorkspaceStatusTone.success,
      'SUSPENDED' => AppWorkspaceStatusTone.error,
      'PENDING' => AppWorkspaceStatusTone.warning,
      _ => AppWorkspaceStatusTone.neutral,
    };
  }

  Color _toneColor(ColorScheme colors, AppWorkspaceStatusTone tone) {
    return switch (tone) {
      AppWorkspaceStatusTone.success => colors.primary,
      AppWorkspaceStatusTone.warning => colors.tertiary,
      AppWorkspaceStatusTone.error => colors.error,
      AppWorkspaceStatusTone.info => colors.secondary,
      AppWorkspaceStatusTone.neutral => colors.onSurfaceVariant,
    };
  }
}

class _UserDetailInfoTile extends StatelessWidget {
  const _UserDetailInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colorScheme.primary),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDetailPermissionChip extends StatelessWidget {
  const _UserDetailPermissionChip({
    required this.label,
    this.source,
    this.emphasized = false,
  });

  final String label;
  final String? source;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color background = emphasized
        ? colorScheme.secondaryContainer
        : colorScheme.surfaceContainerHighest;

    return Tooltip(
      message: source == null ? label : '$label · $source',
      child: Chip(
        avatar: Icon(
          emphasized ? Icons.key_outlined : Icons.verified_user_outlined,
          size: 16,
          color: emphasized ? colorScheme.secondary : colorScheme.onSurfaceVariant,
        ),
        label: Text(
          source == null ? label : '$label · $source',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: background,
        visualDensity: VisualDensity.compact,
        labelStyle: theme.textTheme.labelSmall,
      ),
    );
  }
}

class _UserDetailCountChip extends StatelessWidget {
  const _UserDetailCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Chip(
      avatar: Icon(
        Icons.format_list_numbered_outlined,
        size: 16,
        color: colorScheme.primary,
      ),
      label: Text('$count'),
      backgroundColor: colorScheme.primaryContainer,
      visualDensity: VisualDensity.compact,
      labelStyle: theme.textTheme.labelSmall,
    );
  }
}

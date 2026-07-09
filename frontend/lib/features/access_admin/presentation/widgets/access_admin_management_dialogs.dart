import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
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
    await showAccessAdminUserFormDialog(context, ref, state);
    if (mounted) {
      await reload(resetPage: true);
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
      ),
    );
    if (mounted) {
      await reload(resetPage: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

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
                              label: l10n.commonSaveActionLabel,
                              semanticLabel: l10n.commonSaveActionLabel,
                              tooltip: l10n.commonSaveActionLabel,
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
  });

  final AccessAdminItem item;
  final AccessAdminUserDetail detail;
  final bool canWrite;
  final Future<AppFailure?> Function(String status) onStatusChanged;

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
    final AccessAdminItem item = widget.item;
    final AccessAdminUserDetail detail = widget.detail;

    return AppDialog(
      title: Text(item.title),
      icon: const Icon(Icons.person_outline),
      scrollable: true,
      maxWidth: 720,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DetailRow(label: l10n.accessAdminColumnId, value: item.effectiveDisplayId),
          if (item.email != null)
            _DetailRow(label: l10n.accessAdminEmailLabel, value: item.email!),
          if (item.positionTitle != null)
            _DetailRow(
              label: l10n.accessAdminPositionLabel,
              value: item.positionTitle!,
            ),
          if (item.status != null)
            _DetailRow(label: l10n.accessAdminStatusLabel, value: item.status!),
          if (item.roles.isNotEmpty) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.md),
            Text(
              l10n.accessAdminAssignedRolesLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: Theme.of(context).spacing.xs,
              children: item.roles
                  .map((AccessAdminRoleRef role) => Chip(label: Text(role.name)))
                  .toList(growable: false),
            ),
          ],
          if (detail.effectivePermissions.isNotEmpty) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.md),
            Text(
              l10n.accessAdminEffectivePermissionsLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${detail.effectivePermissions.length} ${l10n.accessAdminPermissionsLabel}',
            ),
          ],
        ],
      ),
      actions: <Widget>[
        if (widget.canWrite)
          AppButton.secondary(
            label: item.status == 'ACTIVE'
                ? l10n.accessAdminDeactivateAction
                : l10n.accessAdminActivateAction,
            isLoading: _saving,
            onPressed: _saving ? null : _toggleStatus,
          ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
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

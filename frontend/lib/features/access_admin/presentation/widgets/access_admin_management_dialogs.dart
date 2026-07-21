import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
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
import 'package:hosspi_hms/shared/management/platform_admin_list_config.dart';
import 'package:hosspi_hms/shared/management/platform_management_list_sync.dart';

Future<bool?> showManageUsersDialog(BuildContext context, WidgetRef ref) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => const ManageUsersPanel(dialogMode: true),
  );
}

Future<bool?> showManageRolesPermissionsDialog(
  BuildContext context,
  WidgetRef ref, {
  AccessAdminPanel panel = AccessAdminPanel.roles,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => ManageRolesPermissionsPanel(
      dialogMode: true,
      panel: panel,
    ),
  );
}

abstract class _ScopedAccessAdminListDialogState<
  T extends ConsumerStatefulWidget
>
    extends ConsumerState<T> {
  final TextEditingController searchController = TextEditingController();
  Timer? searchDebounce;
  bool loading = true;
  bool mutating = false;
  bool mutated = false;
  AppFailure? failure;
  AppPageRequest pageRequest = PlatformAdminListConfig.initialPageRequest;
  int totalItemCount = 0;
  List<AccessAdminItem> items = const <AccessAdminItem>[];
  AccessAdminWorkspaceData? workspaceData;
  PlatformManagementListSync? _realtimeSync;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _realtimeSync ??= PlatformManagementListSync(
      ref: ref,
      events: RealtimeEventGroups.platformAdmin,
      onMutated: () => mutated = true,
      reload: ({bool silent = false, RealtimeMessage? message}) async {
        await reload(resetPage: false, silent: silent);
      },
    )..attach();
  }

  @override
  void dispose() {
    _realtimeSync?.dispose();
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 450), () {
      // Keep existing rows visible while search refreshes.
      unawaited(reload(resetPage: true, silent: items.isNotEmpty));
    });
  }

  Future<void> reload({
    required bool resetPage,
    bool silent = false,
    bool refreshLookups = false,
  }) async {
    if (resetPage) {
      pageRequest = pageRequest.first();
    }
    if (!silent) {
      setState(() {
        loading = true;
        failure = null;
      });
    }

    final bool canSkipLookups =
        !refreshLookups &&
        workspaceData != null &&
        (workspaceData!.lookups.tenants.isNotEmpty ||
            workspaceData!.lookups.facilities.isNotEmpty ||
            workspaceData!.lookups.roles.isNotEmpty ||
            workspaceData!.lookups.userStatuses.isNotEmpty);

    final Result<AccessAdminWorkspaceData> result = await repository
        .getWorkspace(
          listQuery.copyWith(
            search: searchController.text.trim(),
            pageRequest: pageRequest,
            skipLookups: canSkipLookups,
          ),
        );

    if (!mounted) return;
    result.when(
      success: (AccessAdminWorkspaceData data) {
        final AccessAdminLookups preservedLookups =
            canSkipLookups &&
                data.lookups.tenants.isEmpty &&
                data.lookups.facilities.isEmpty &&
                data.lookups.roles.isEmpty
            ? workspaceData!.lookups
            : data.lookups;
        setState(() {
          loading = false;
          workspaceData = data.copyWith(lookups: preservedLookups);
          items = data.page.items;
          totalItemCount = data.page.totalItemCount ?? data.page.items.length;
        });
      },
      failure: (AppFailure loadFailure) {
        setState(() {
          loading = false;
          failure = loadFailure;
          if (!silent) {
            items = const <AccessAdminItem>[];
          }
        });
      },
    );
  }

  Future<void> onPageChanged(AppPageRequest request) async {
    pageRequest = request;
    await reload(resetPage: false, silent: items.isNotEmpty);
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
    AppListTableSearch<AccessAdminItem>? search,
    String? columnVisibilityStorageKey,
    List<AppListTableColumn<AccessAdminItem>>? columnChoices,
  }) {
    if (failure != null) {
      return AppFailureStateView(
        failure: failure!,
        onRetry: () => unawaited(reload(resetPage: true)),
      );
    }

    return AppListTable<AccessAdminItem>(
      page: currentPage,
      isLoading: loading,
      onRowSelected: onRowSelected,
      onPageChanged: onPageChanged,
      previousPageLabel: l10n.hrPreviousPageLabel,
      nextPageLabel: l10n.hrNextPageLabel,
      pageLabelBuilder: (AppPage<AccessAdminItem> page) {
        if (loading) {
          return '';
        }
        final int total = page.totalItemCount ?? page.items.length;
        if (total == 0) return l10n.commonTableEmptyLabel;
        final int start = page.pageIndex * page.pageSize + 1;
        final int end = start + page.items.length - 1;
        return '$start-$end / $total';
      },
      columns: columns,
      columnChoices: columnChoices,
      search: search,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: columnVisibilityStorageKey,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.accessAdminEmptyTitle,
        body: l10n.accessAdminEmptyBody,
      ),
      mobileItemBuilder: (BuildContext context, AccessAdminItem item) {
        final bool isRole = item.resource == AccessAdminResource.roles;
        return AppListTableMobileItem(
          title: item.title,
          caption: item.subtitle ?? item.effectiveDisplayId,
          meta: <AppListTableMobileMeta>[
            if (isRole)
              AppListTableMobileMeta(
                label: item.isFacilityScopedRole
                    ? (item.facilityName?.trim().isNotEmpty == true
                          ? '${context.l10n.accessAdminRoleScopeFacilityBadge} · ${item.facilityName}'
                          : context.l10n.accessAdminRoleScopeFacilityBadge)
                    : context.l10n.accessAdminRoleScopeTenantBadge,
                icon: item.isFacilityScopedRole
                    ? Icons.local_hospital_outlined
                    : Icons.domain_outlined,
              )
            else if ((item.status ?? '').isNotEmpty)
              AppListTableMobileMeta(label: item.status!),
          ],
        );
      },
    );
  }

  AppListTableSearch<AccessAdminItem> buildTableSearch({
    required AppLocalizations l10n,
    List<AppSearchBarFilterGroup> filterGroups =
        const <AppSearchBarFilterGroup>[],
    AppSearchBarFilterValue filterValue = AppSearchBarFilterValue.empty,
    ValueChanged<AppSearchBarFilterValue>? onFilterChanged,
    bool hasActiveFilters = false,
    bool showAdvancedFilterButton = false,
    String? advancedFilterTitle,
  }) {
    return AppListTableSearch<AccessAdminItem>(
      controller: searchController,
      semanticLabel: l10n.accessAdminSearchLabel,
      hintText: l10n.accessAdminSearchHint,
      matcher: (_, _) => true,
      onSubmitted: (_) => unawaited(reload(resetPage: true)),
      onClear: () => unawaited(reload(resetPage: true)),
      enableDateFilter: false,
      showAdvancedFilterButton: showAdvancedFilterButton,
      advancedFilterButtonLabel: l10n.accessAdminFiltersAction,
      advancedFilterTitle: advancedFilterTitle ?? l10n.accessAdminFiltersTitle,
      advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
      advancedFilterResetLabel: l10n.opdClearFiltersAction,
      filterGroups: filterGroups,
      filterValue: filterValue,
      hasActiveFilters: hasActiveFilters,
      onFilterChanged: onFilterChanged,
    );
  }
}

/// Users table/CRUD shared by manage dialog and setup Users tab.
class ManageUsersPanel extends ConsumerStatefulWidget {
  const ManageUsersPanel({
    this.dialogMode = false,
    this.showCreateAction = true,
    this.reloadListenable,
    this.onMutated,
    super.key,
  });

  final bool dialogMode;
  final bool showCreateAction;
  final Listenable? reloadListenable;
  final ValueChanged<bool>? onMutated;

  @override
  ConsumerState<ManageUsersPanel> createState() => _ManageUsersPanelState();
}

class _ManageUsersPanelState
    extends _ScopedAccessAdminListDialogState<ManageUsersPanel> {
  String? tenantFilter;
  String? facilityFilter;
  String? roleFilter;
  String? statusFilter;

  /// Defaults to the widest list the actor is allowed to see.
  /// Super admin: all tenants + facilities. Tenant admin: all facilities.
  /// Facility-scoped actors keep their facility from session scope.
  bool allTenants = true;
  bool allFacilities = true;

  static const String _tenantFilterKey = 'tenant';
  static const String _facilityFilterKey = 'facility';
  static const String _roleFilterKey = 'role';
  static const String _statusFilterKey = 'status';

  @override
  void initState() {
    super.initState();
    widget.reloadListenable?.addListener(_onExternalReload);
  }

  @override
  void dispose() {
    widget.reloadListenable?.removeListener(_onExternalReload);
    super.dispose();
  }

  void _onExternalReload() {
    unawaited(reload(resetPage: false, silent: true));
  }

  bool get _canPickTenant {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return policy.canCreateTenant();
  }

  bool get _canFilterAcrossFacilities {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return policy.canCreateTenant() || policy.canCreateTenantWideRole();
  }

  @override
  AccessAdminWorkspaceQuery get listQuery {
    final bool crossTenant =
        _canPickTenant && allTenants && tenantFilter == null;
    final bool tenantWide =
        _canFilterAcrossFacilities && allFacilities && facilityFilter == null;
    return AccessAdminWorkspaceQuery(
      includeDeleted: true,
      lean: true,
      tenantId: crossTenant ? null : tenantFilter,
      facilityId: tenantWide ? null : facilityFilter,
      allTenants: crossTenant,
      allFacilities: tenantWide || crossTenant,
      roleId: roleFilter,
      status: statusFilter,
    );
  }

  Future<void> _applyUserFilters(AppSearchBarFilterValue value) async {
    final String? nextTenant = value.option(_tenantFilterKey);
    final String? nextFacilityRaw = value.option(_facilityFilterKey);
    final String? nextRole = value.option(_roleFilterKey);
    final String? nextStatus = value.option(_statusFilterKey);

    final bool nextAllTenants = _canPickTenant && nextTenant == null;
    final bool nextAllFacilities = nextAllTenants
        ? true
        : (_canFilterAcrossFacilities && nextFacilityRaw == null);
    final String? nextFacility = nextAllFacilities || nextAllTenants
        ? null
        : nextFacilityRaw;

    if (tenantFilter == nextTenant &&
        facilityFilter == nextFacility &&
        allTenants == nextAllTenants &&
        allFacilities == nextAllFacilities &&
        roleFilter == nextRole &&
        statusFilter == nextStatus) {
      return;
    }

    final bool tenantScopeChanged =
        tenantFilter != nextTenant || allTenants != nextAllTenants;

    setState(() {
      tenantFilter = nextTenant;
      facilityFilter = nextFacility;
      allTenants = nextAllTenants;
      allFacilities = nextAllFacilities;
      roleFilter = nextRole;
      statusFilter = nextStatus;
    });
    await reload(
      resetPage: true,
      silent: items.isNotEmpty,
      refreshLookups: tenantScopeChanged,
    );
  }

  Future<void> _openCreateUserDialog() async {
    final AccessAdminWorkspaceState? state = buildWorkspaceState();
    if (state == null || !mounted) {
      return;
    }
    final bool? saved = await openAccessAdminCreateUserDialog(
      context,
      ref,
      state,
    );
    if (saved == true && mounted) {
      mutated = true;
      // Restore widest allowed defaults so the new user is not hidden.
      setState(() {
        if (_canPickTenant) {
          allTenants = true;
          tenantFilter = null;
        }
        if (_canFilterAcrossFacilities) {
          allFacilities = true;
          facilityFilter = null;
        }
        roleFilter = null;
        statusFilter = null;
      });
      await reload(resetPage: true, silent: true);
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
      final Result<AccessAdminUserDetail> detailResult = await repository
          .getUserDetail(
            item.mutationId,
            tenantId: item.tenantId ?? workspaceData?.query.tenantId,
          );
      if (!mounted) return;
      resolvedDetail = detailResult.when(
        success: (AccessAdminUserDetail value) => value,
        failure: (_) => null,
      );
      if (resolvedDetail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detailResult.when(
                success: (_) => context.l10n.accessAdminEmptyTitle,
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
      mutated = true;
      unawaited(reload(resetPage: false, silent: true));
    }
  }

  Future<void> _confirmDeleteUser(AccessAdminItem user) async {
    if (user.isDemo || user.isSystemCritical || user.isDeleted) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilitySoftDeleteUserTitle,
        body: l10n.tenantFacilitySoftDeleteUserBody(user.title),
        highlightedText: user.title,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<void> result = await repository.deleteUser(
            user.mutationId,
          );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      mutated = true;
      setState(() {
        items = <AccessAdminItem>[
          for (final AccessAdminItem entry in items)
            entry.id == user.id || entry.mutationId == user.mutationId
                ? entry.copyWith(deletedAt: DateTime.now().toUtc())
                : entry,
        ];
      });
      unawaited(reload(resetPage: false, silent: true));
    }
  }

  Future<void> _confirmRestoreUser(AccessAdminItem user) async {
    if (!user.isDeleted) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityRestoreUserTitle,
        body: l10n.tenantFacilityRestoreUserBody(user.title),
        highlightedText: user.title,
        submitLabel: l10n.accessAdminRestoreUserAction,
        icon: const Icon(Icons.restore_outlined),
        onConfirm: () async {
          final Result<void> result = await repository.restoreUser(
            user.mutationId,
          );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      mutated = true;
      setState(() {
        items = <AccessAdminItem>[
          for (final AccessAdminItem entry in items)
            entry.id == user.id || entry.mutationId == user.mutationId
                ? entry.copyWith(clearDeletedAt: true)
                : entry,
        ];
      });
      unawaited(reload(resetPage: false, silent: true));
    }
  }

  Future<void> _openUserDetail(AccessAdminItem item) async {
    // Do not flip the table into a global busy state — keep rows interactive.
    final Result<AccessAdminUserDetail> detailResult = await repository
        .getUserDetail(
          item.mutationId,
          tenantId: item.tenantId ?? workspaceData?.query.tenantId,
        );
    if (!mounted) return;

    final AccessAdminUserDetail? detail = detailResult.when(
      success: (AccessAdminUserDetail value) => value,
      failure: (_) => null,
    );
    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detailResult.when(
              success: (_) => context.l10n.accessAdminEmptyTitle,
              failure: (AppFailure loadFailure) =>
                  context.l10n.failureMessage(loadFailure),
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    var detailDidMutate = false;
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => _AccessAdminUserDetailDialog(
        item: detail.item,
        detail: detail,
        canWrite: canWrite,
        repository: repository,
        lookups: workspaceData?.lookups ?? const AccessAdminLookups(),
        tenantId: detail.item.tenantId ?? item.tenantId,
        facilityId: detail.item.facilityId ?? item.facilityId,
        onStatusChanged: (String status) async {
          final Result<void> result = await repository.setUserStatus(
            item.mutationId,
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
        onMutated: () {
          mutated = true;
          detailDidMutate = true;
        },
      ),
    );
    if (mounted && detailDidMutate) {
      unawaited(reload(resetPage: false, silent: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AccessAdminLookups lookups =
        workspaceData?.lookups ?? const AccessAdminLookups();
    final bool canPickTenant = ref
        .watch(appAccessPolicyProvider)
        .canCreateTenant();
    final bool canFilterFacilities = _canFilterAcrossFacilities;
    final bool showFacilityFilter =
        canFilterFacilities && (!canPickTenant || tenantFilter != null);
    final List<String> statusOptions = lookups.userStatuses.isNotEmpty
        ? lookups.userStatuses
        : const <String>['ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING'];

    final List<AppSearchBarFilterGroup> filterGroups =
        <AppSearchBarFilterGroup>[
          if (canPickTenant)
            AppSearchBarFilterGroup(
              key: _tenantFilterKey,
              label: l10n.settingsWorkspaceTenantLabel,
              allLabel: l10n.accessAdminAllTenantsFilterLabel,
              choices: lookups.tenants
                  .map(
                    (AccessAdminLookupOption tenant) =>
                        AppSearchBarFilterChoice(
                          value: tenant.id,
                          label: tenant.label,
                          icon: Icons.apartment_outlined,
                        ),
                  )
                  .toList(growable: false),
            ),
          if (showFacilityFilter)
            AppSearchBarFilterGroup(
              key: _facilityFilterKey,
              label: l10n.settingsWorkspaceFacilityLabel,
              allLabel: l10n.accessAdminAllFacilitiesFilterLabel,
              choices: lookups.facilities
                  .map(
                    (AccessAdminLookupOption facility) =>
                        AppSearchBarFilterChoice(
                          value: facility.id,
                          label: facility.label,
                          icon: Icons.local_hospital_outlined,
                        ),
                  )
                  .toList(growable: false),
            ),
          AppSearchBarFilterGroup(
            key: _roleFilterKey,
            label: l10n.accessAdminFilterRoleLabel,
            allLabel: l10n.accessAdminAllRolesFilterLabel,
            choices: lookups.roles
                .map(
                  (AccessAdminLookupOption role) => AppSearchBarFilterChoice(
                    value: role.id,
                    label: role.label,
                    icon: Icons.badge_outlined,
                  ),
                )
                .toList(growable: false),
          ),
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.accessAdminStatusLabel,
            allLabel: l10n.accessAdminAllStatusesLabel,
            choices: statusOptions
                .map(
                  (String status) => AppSearchBarFilterChoice(
                    value: status,
                    label: status,
                    icon: Icons.flag_outlined,
                  ),
                )
                .toList(growable: false),
          ),
        ];

    final Map<String, String> filterOptions = <String, String>{
      if (tenantFilter != null) _tenantFilterKey: tenantFilter!,
      if (showFacilityFilter && !allFacilities && facilityFilter != null)
        _facilityFilterKey: facilityFilter!,
      if (roleFilter != null) _roleFilterKey: roleFilter!,
      if (statusFilter != null) _statusFilterKey: statusFilter!,
    };

    final bool hasActiveFilters =
        tenantFilter != null ||
        (showFacilityFilter && !allFacilities && facilityFilter != null) ||
        roleFilter != null ||
        statusFilter != null;

    final Widget table = SizedBox.expand(
      child: buildTable(
          l10n: l10n,
          columnVisibilityStorageKey: 'access_admin_manage_users_v3',
          onRowSelected: (AccessAdminItem item) =>
              unawaited(_openUserDetail(item)),
          search: buildTableSearch(
            l10n: l10n,
            showAdvancedFilterButton: true,
            advancedFilterTitle: l10n.accessAdminUsersFiltersTitle,
            filterGroups: filterGroups,
            filterValue: filterOptions.isEmpty
                ? AppSearchBarFilterValue.empty
                : AppSearchBarFilterValue(options: filterOptions),
            hasActiveFilters: hasActiveFilters,
            onFilterChanged: (AppSearchBarFilterValue value) {
              unawaited(_applyUserFilters(value));
            },
          ),
          columns: <AppListTableColumn<AccessAdminItem>>[
            AppListTableColumn<AccessAdminItem>(
              id: 'id',
              label: l10n.accessAdminColumnId,
              cellBuilder: (_, AccessAdminItem item) =>
                  Text(item.effectiveDisplayId),
            ),
            AppListTableColumn<AccessAdminItem>(
              id: 'name',
              label: l10n.accessAdminColumnName,
              cellBuilder: (_, AccessAdminItem item) => Text(item.title),
            ),
            AppListTableColumn<AccessAdminItem>(
              id: 'facility',
              label: l10n.accessAdminColumnFacility,
              cellBuilder: (_, AccessAdminItem item) => Text(
                item.facilityName?.trim().isNotEmpty == true
                    ? item.facilityName!
                    : (item.facilityId ?? '—'),
              ),
            ),
            AppListTableColumn<AccessAdminItem>(
              id: 'roles',
              label: l10n.accessAdminColumnRoles,
              cellBuilder: (_, AccessAdminItem item) {
                if (item.roles.isEmpty) {
                  return const Text('—');
                }
                return Text(
                  item.roles
                      .map((AccessAdminRoleRef role) => role.name)
                      .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            AppListTableColumn<AccessAdminItem>(
              id: 'status',
              label: l10n.accessAdminColumnStatus,
              cellBuilder: (_, AccessAdminItem item) => Text(
                item.isDeleted
                    ? l10n.tenantFacilityStructureDeletedStatus
                    : (item.status ?? '—'),
              ),
            ),
            if (canWrite)
              AppListTableColumn<AccessAdminItem>(
                id: 'actions',
                label: l10n.accessAdminColumnActions,
                alwaysVisible: true,
                cellBuilder: (BuildContext context, AccessAdminItem user) {
                  final ThemeData theme = Theme.of(context);
                  if (user.isDeleted) {
                    return Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: theme.spacing.sm,
                      ),
                      child: AppButton.tertiary(
                        leadingIcon: Icons.restore_outlined,
                        label: l10n.accessAdminRestoreUserAction,
                        semanticLabel: l10n.accessAdminRestoreUserAction,
                        tooltip: l10n.accessAdminRestoreUserAction,
                        enabled: !loading && !mutating,
                        onPressed: !loading && !mutating
                            ? () => unawaited(_confirmRestoreUser(user))
                            : null,
                      ),
                    );
                  }
                  return Padding(
                    padding: EdgeInsetsDirectional.only(end: theme.spacing.sm),
                    child: Row(
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
                          enabled:
                              !loading &&
                              !mutating &&
                              !user.isDemo &&
                              !user.isSystemCritical,
                          onPressed:
                              !loading &&
                                  !mutating &&
                                  !user.isDemo &&
                                  !user.isSystemCritical
                              ? () => unawaited(_confirmDeleteUser(user))
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
          columnChoices: <AppListTableColumn<AccessAdminItem>>[
            AppListTableColumn<AccessAdminItem>(
              id: 'details',
              label: l10n.accessAdminColumnDetails,
              cellBuilder: (_, AccessAdminItem item) =>
                  Text(item.subtitle ?? item.email ?? '—'),
            ),
          ],
        ),
    );

    final Widget createAction = AppButton.primary(
      label: l10n.accessAdminCreateUserAction,
      leadingIcon: Icons.person_add_alt_1_outlined,
      onPressed: loading || mutating
          ? null
          : () => unawaited(_openCreateUserDialog()),
    );

    if (!widget.dialogMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.showCreateAction && canWrite)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: createAction,
            ),
          if (widget.showCreateAction && canWrite) const SizedBox(height: 12),
          Expanded(child: table),
        ],
      );
    }

    return AppDialog(
      title: Text(l10n.homeManageUsersTitle),
      icon: const Icon(Icons.people_outline),
      pinActionsToBottom: true,
      maxWidth: 1200,
      content: table,
      actions: <Widget>[
        if (canWrite) createAction,
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(mutated ? true : null),
        ),
      ],
    );
  }
}

/// Roles/permissions table/CRUD shared by manage dialog and setup tabs.
class ManageRolesPermissionsPanel extends ConsumerStatefulWidget {
  const ManageRolesPermissionsPanel({
    this.dialogMode = false,
    this.showCreateAction = true,
    this.reloadListenable,
    this.panel = AccessAdminPanel.roles,
    this.onMutated,
    super.key,
  });

  final bool dialogMode;
  final bool showCreateAction;
  final Listenable? reloadListenable;
  final AccessAdminPanel panel;
  final ValueChanged<bool>? onMutated;

  @override
  ConsumerState<ManageRolesPermissionsPanel> createState() =>
      _ManageRolesPermissionsPanelState();
}

class _ManageRolesPermissionsPanelState
    extends _ScopedAccessAdminListDialogState<ManageRolesPermissionsPanel> {
  String? roleScopeFilter;
  String? tenantFilter;
  String? facilityFilter;

  /// Match Manage Users: widest list the actor is allowed to see.
  bool allTenants = true;
  bool allFacilities = true;

  static const String _tenantFilterKey = 'tenant';
  static const String _facilityFilterKey = 'facility';

  @override
  void initState() {
    super.initState();
    widget.reloadListenable?.addListener(_onExternalReload);
  }

  @override
  void dispose() {
    widget.reloadListenable?.removeListener(_onExternalReload);
    super.dispose();
  }

  void _onExternalReload() {
    unawaited(reload(resetPage: false, silent: true));
  }

  bool get _canPickTenant {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return policy.canCreateTenant();
  }

  bool get _canFilterAcrossFacilities {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return policy.canCreateTenant() || policy.canCreateTenantWideRole();
  }

  @override
  AccessAdminWorkspaceQuery get listQuery {
    final bool crossTenant =
        _canPickTenant && allTenants && tenantFilter == null;
    final bool tenantWide =
        _canFilterAcrossFacilities && allFacilities && facilityFilter == null;
    final AccessAdminPanel panel = widget.panel;
    final AccessAdminResource resource = panel == AccessAdminPanel.permissions
        ? AccessAdminResource.permissions
        : AccessAdminResource.roles;
    return AccessAdminWorkspaceQuery(
      panel: panel,
      resource: resource,
      roleScope: roleScopeFilter,
      lean: true,
      tenantId: crossTenant ? null : tenantFilter,
      facilityId: tenantWide ? null : facilityFilter,
      allTenants: crossTenant,
      allFacilities: tenantWide || crossTenant,
    );
  }

  Future<void> _applyRoleListFilters(AppSearchBarFilterValue value) async {
    final String? nextTenant = value.option(_tenantFilterKey);
    final String? nextFacilityRaw = value.option(_facilityFilterKey);
    final String? nextRoleScope = value.option(_roleScopeFilterKey);

    final bool nextAllTenants = _canPickTenant && nextTenant == null;
    final bool nextAllFacilities = nextAllTenants
        ? true
        : (_canFilterAcrossFacilities && nextFacilityRaw == null);
    final String? nextFacility = nextAllFacilities || nextAllTenants
        ? null
        : nextFacilityRaw;

    if (tenantFilter == nextTenant &&
        facilityFilter == nextFacility &&
        allTenants == nextAllTenants &&
        allFacilities == nextAllFacilities &&
        roleScopeFilter == nextRoleScope) {
      return;
    }

    final bool tenantScopeChanged =
        tenantFilter != nextTenant || allTenants != nextAllTenants;

    setState(() {
      tenantFilter = nextTenant;
      facilityFilter = nextFacility;
      allTenants = nextAllTenants;
      allFacilities = nextAllFacilities;
      roleScopeFilter = nextRoleScope;
    });
    await reload(
      resetPage: true,
      silent: items.isNotEmpty,
      refreshLookups: tenantScopeChanged,
    );
  }

  Future<void> _openCreateRoleDialog() async {
    final AccessAdminWorkspaceState? state = buildWorkspaceState();
    if (state == null || !mounted) {
      return;
    }
    final bool? saved = await openAccessAdminCreateRoleDialog(
      context,
      ref,
      state,
    );
    if (saved == true && mounted) {
      mutated = true;
      unawaited(reload(resetPage: true, silent: true));
    }
  }

  Future<void> _openRoleDetail(AccessAdminItem role) async {
    if (!mounted) {
      return;
    }

    final Result<List<AccessAdminRolePermissionAssignment>> permissionsResult =
        await repository.listRolePermissions(role.id);
    if (!mounted) {
      return;
    }

    final List<AccessAdminRolePermissionAssignment>? permissions =
        permissionsResult.when(
          success: (List<AccessAdminRolePermissionAssignment> value) => value,
          failure: (AppFailure failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.failureMessage(failure))),
            );
            return null;
          },
        );
    if (permissions == null || !mounted) {
      return;
    }

    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => _AccessAdminRoleDetailDialog(
        role: role,
        permissions: permissions,
        canWrite: canWrite,
        onEdit: () {
          Navigator.of(dialogContext).pop();
          unawaited(_openEditRoleDialog(role));
        },
        onDelete: () {
          Navigator.of(dialogContext).pop();
          unawaited(_confirmDeleteRole(role));
        },
      ),
    );
  }

  Future<void> _openEditRoleDialog(AccessAdminItem role) async {
    final AccessAdminWorkspaceState? state = buildWorkspaceState();
    if (state == null || !mounted) {
      return;
    }
    final bool? saved = await openAccessAdminEditRoleDialog(
      context,
      ref,
      state,
      role,
    );
    if (saved == true && mounted) {
      mutated = true;
      unawaited(reload(resetPage: true, silent: true));
    }
  }

  Future<void> _confirmDeleteRole(AccessAdminItem role) async {
    if (role.isSystemCritical) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final String body = role.userCount > 0
        ? l10n.accessAdminDeleteRoleAssignedBody(role.title, role.userCount)
        : l10n.accessAdminDeleteRoleBody(role.title);
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.accessAdminDeleteRoleAction,
        body: body,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<void> result = await repository.deleteRole(
            role.mutationId,
          );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      mutated = true;
      setState(() {
        items = items
            .where(
              (AccessAdminItem entry) =>
                  entry.id != role.id && entry.mutationId != role.mutationId,
            )
            .toList(growable: false);
        totalItemCount = math.max(0, totalItemCount - 1);
      });
      unawaited(reload(resetPage: items.isEmpty, silent: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canViewTenantRoles = accessPolicy.canCreateTenantWideRole();
    final bool canPickTenant = accessPolicy.canCreateTenant();
    final bool canFilterFacilities = accessPolicy.canCreateTenantWideRole();
    final bool showFacilityFilter =
        canFilterFacilities && (!canPickTenant || tenantFilter != null);

    final List<AppSearchBarFilterGroup> filterGroups =
        <AppSearchBarFilterGroup>[
          if (canPickTenant)
            AppSearchBarFilterGroup(
              key: _tenantFilterKey,
              label: l10n.settingsWorkspaceTenantLabel,
              allLabel: l10n.accessAdminAllTenantsFilterLabel,
              choices:
                  (workspaceData?.lookups.tenants ??
                          const <AccessAdminLookupOption>[])
                      .map(
                        (AccessAdminLookupOption tenant) =>
                            AppSearchBarFilterChoice(
                              value: tenant.id,
                              label: tenant.label,
                              icon: Icons.apartment_outlined,
                            ),
                      )
                      .toList(growable: false),
            ),
          if (showFacilityFilter)
            AppSearchBarFilterGroup(
              key: _facilityFilterKey,
              label: l10n.settingsWorkspaceFacilityLabel,
              allLabel: l10n.accessAdminAllFacilitiesFilterLabel,
              choices:
                  (workspaceData?.lookups.facilities ??
                          const <AccessAdminLookupOption>[])
                      .map(
                        (AccessAdminLookupOption facility) =>
                            AppSearchBarFilterChoice(
                              value: facility.id,
                              label: facility.label,
                              icon: Icons.local_hospital_outlined,
                            ),
                      )
                      .toList(growable: false),
            ),
          if (canViewTenantRoles)
            AppSearchBarFilterGroup(
              key: _roleScopeFilterKey,
              label: l10n.accessAdminColumnScope,
              allLabel: l10n.accessAdminRoleScopeFilterAll,
              choices: <AppSearchBarFilterChoice>[
                AppSearchBarFilterChoice(
                  value: 'tenant',
                  label: l10n.accessAdminRoleScopeFilterTenant,
                  icon: Icons.domain_outlined,
                ),
                AppSearchBarFilterChoice(
                  value: 'facility',
                  label: l10n.accessAdminRoleScopeFilterFacility,
                  icon: Icons.local_hospital_outlined,
                ),
              ],
            ),
        ];

    final Map<String, String> activeOptions = <String, String>{
      if (tenantFilter != null) _tenantFilterKey: tenantFilter!,
      if (showFacilityFilter && !allFacilities && facilityFilter != null)
        _facilityFilterKey: facilityFilter!,
      if (roleScopeFilter != null) _roleScopeFilterKey: roleScopeFilter!,
    };

    final String title = widget.panel == AccessAdminPanel.permissions
        ? l10n.tenantFacilitySetupTabPermissions
        : l10n.homeManageRolesPermissionsTitle;
    final IconData icon = widget.panel == AccessAdminPanel.permissions
        ? Icons.key_outlined
        : Icons.admin_panel_settings_outlined;
    final bool isPermissions = widget.panel == AccessAdminPanel.permissions;
    final Widget table = SizedBox.expand(
      child: buildTable(
          l10n: l10n,
          columnVisibilityStorageKey: isPermissions
              ? 'access_admin_manage_permissions_v1'
              : 'access_admin_manage_roles_v2',
          onRowSelected: isPermissions
              ? null
              : (AccessAdminItem role) => unawaited(_openRoleDetail(role)),
          search: buildTableSearch(
            l10n: l10n,
            showAdvancedFilterButton: filterGroups.isNotEmpty,
            advancedFilterTitle: l10n.accessAdminFiltersTitle,
            filterGroups: filterGroups,
            filterValue: activeOptions.isEmpty
                ? AppSearchBarFilterValue.empty
                : AppSearchBarFilterValue(options: activeOptions),
            hasActiveFilters: activeOptions.isNotEmpty,
            onFilterChanged: filterGroups.isEmpty
                ? null
                : (AppSearchBarFilterValue value) {
                    unawaited(_applyRoleListFilters(value));
                  },
          ),
          columns: <AppListTableColumn<AccessAdminItem>>[
            AppListTableColumn<AccessAdminItem>(
              id: 'id',
              label: l10n.accessAdminColumnId,
              cellBuilder: (_, AccessAdminItem item) =>
                  Text(item.effectiveDisplayId),
            ),
            AppListTableColumn<AccessAdminItem>(
              id: 'name',
              label: l10n.accessAdminColumnName,
              cellBuilder: (_, AccessAdminItem item) => Text(item.title),
            ),
            if (!isPermissions)
              AppListTableColumn<AccessAdminItem>(
                id: 'scope',
                label: l10n.accessAdminColumnScope,
                cellBuilder: (BuildContext context, AccessAdminItem item) =>
                    _RoleScopeBadge(item: item),
              ),
            if (canWrite && !isPermissions)
              AppListTableColumn<AccessAdminItem>(
                id: 'actions',
                label: l10n.accessAdminColumnActions,
                alwaysVisible: true,
                cellBuilder: (BuildContext context, AccessAdminItem role) {
                  final ThemeData theme = Theme.of(context);
                  return Padding(
                    padding: EdgeInsetsDirectional.only(end: theme.spacing.sm),
                    child: Row(
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
                    ),
                  );
                },
              ),
          ],
          columnChoices: <AppListTableColumn<AccessAdminItem>>[
            AppListTableColumn<AccessAdminItem>(
              id: 'details',
              label: l10n.accessAdminColumnDetails,
              cellBuilder: (_, AccessAdminItem item) =>
                  Text(item.subtitle ?? '—'),
            ),
          ],
        ),
    );

    final Widget? createAction = (!isPermissions && canWrite)
        ? AppButton.primary(
            label: l10n.accessAdminCreateRoleAction,
            leadingIcon: Icons.badge_outlined,
            onPressed: loading || mutating
                ? null
                : () => unawaited(_openCreateRoleDialog()),
          )
        : null;

    if (!widget.dialogMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.showCreateAction && createAction != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: createAction,
            ),
          if (widget.showCreateAction && createAction != null)
            const SizedBox(height: 12),
          Expanded(child: table),
        ],
      );
    }

    return AppDialog(
      title: Text(title),
      icon: Icon(icon),
      pinActionsToBottom: true,
      maxWidth: 1200,
      content: table,
      actions: <Widget>[
        if (createAction != null) createAction,
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(mutated ? true : null),
        ),
      ],
    );
  }
}

const String _roleScopeFilterKey = 'role_scope';

class _AccessAdminRoleDetailDialog extends StatelessWidget {
  const _AccessAdminRoleDetailDialog({
    required this.role,
    required this.permissions,
    required this.canWrite,
    required this.onEdit,
    required this.onDelete,
  });

  final AccessAdminItem role;
  final List<AccessAdminRolePermissionAssignment> permissions;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  List<AppPermissionAssignmentOption> _permissionOptions(
    AppLocalizations l10n,
  ) {
    return permissions
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
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<AppPermissionAssignmentOption> permissionOptions =
        _permissionOptions(l10n);

    return AppDialog(
      title: Text(l10n.accessAdminCreateRoleDetailsSectionTitle),
      icon: const Icon(Icons.badge_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 920,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _RoleDetailSummaryCard(
            role: role,
            permissionCount: permissionOptions.length,
          ),
          SizedBox(height: theme.spacing.md),
          AppSectionPanel(
            title: l10n.accessAdminRolePermissionsLabel,
            description: l10n.accessAdminRoleDetailPermissionsDescription,
            leadingIcon: Icons.lock_outline,
            trailing: Text(
              l10n.hrAccessPermissionCountLabel(permissionOptions.length),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            children: <Widget>[
              AppPermissionGroupedView(
                permissions: permissionOptions,
                initiallyExpandAll: permissionOptions.length <= 24,
                emptyMessage: l10n.accessAdminRoleDetailNoPermissionsMessage,
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        if (canWrite) ...<Widget>[
          AppButton.secondary(
            label: l10n.accessAdminEditRoleAction,
            leadingIcon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          if (!role.isSystemCritical)
            AppButton.secondary(
              label: l10n.accessAdminDeleteRoleAction,
              leadingIcon: Icons.delete_outline,
              color: colors.error,
              onPressed: onDelete,
            ),
        ],
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _RoleDetailSummaryCard extends StatelessWidget {
  const _RoleDetailSummaryCard({
    required this.role,
    required this.permissionCount,
  });

  final AccessAdminItem role;
  final int permissionCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    role.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _RoleScopeBadge(item: role),
              ],
            ),
            if ((role.name ?? '').trim().isNotEmpty &&
                role.name != role.title) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                role.name!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if ((role.subtitle ?? '').trim().isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                role.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.md),
            Wrap(
              spacing: theme.spacing.md,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                _AccessAdminDetailMetaChip(
                  icon: Icons.tag_outlined,
                  label: l10n.accessAdminColumnId,
                  value: role.effectiveDisplayId,
                ),
                _AccessAdminDetailMetaChip(
                  icon: Icons.lock_outline,
                  label: l10n.accessAdminRolePermissionsLabel,
                  value: l10n.hrAccessPermissionCountLabel(permissionCount),
                ),
                _AccessAdminDetailMetaChip(
                  icon: Icons.group_outlined,
                  label: l10n.accessAdminRoleDetailUsersLabel,
                  value: '${role.userCount}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessAdminDetailMetaChip extends StatelessWidget {
  const _AccessAdminDetailMetaChip({
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
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          SizedBox(width: theme.spacing.xs),
          Text(
            '$label: ',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _RoleScopeBadge extends StatelessWidget {
  const _RoleScopeBadge({required this.item});

  final AccessAdminItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isFacility = item.isFacilityScopedRole;
    final String label = isFacility
        ? (item.facilityName?.trim().isNotEmpty == true
              ? '${l10n.accessAdminRoleScopeFacilityBadge} · ${item.facilityName}'
              : l10n.accessAdminRoleScopeFacilityBadge)
        : l10n.accessAdminRoleScopeTenantBadge;

    return Chip(
      avatar: Icon(
        isFacility ? Icons.local_hospital_outlined : Icons.domain_outlined,
        size: 16,
        color: isFacility ? colors.tertiary : colors.primary,
      ),
      label: Text(label, style: theme.textTheme.labelSmall),
      visualDensity: VisualDensity.compact,
      backgroundColor: isFacility
          ? colors.tertiaryContainer
          : colors.primaryContainer,
      side: BorderSide(
        color: (isFacility ? colors.tertiary : colors.primary).withValues(
          alpha: 0.28,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
    );
  }
}

class _AccessAdminUserDetailDialog extends StatefulWidget {
  const _AccessAdminUserDetailDialog({
    required this.item,
    required this.detail,
    required this.canWrite,
    required this.repository,
    required this.lookups,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
    this.tenantId,
    this.facilityId,
    this.onMutated,
  });

  final AccessAdminItem item;
  final AccessAdminUserDetail detail;
  final bool canWrite;
  final AccessAdminRepository repository;
  final AccessAdminLookups lookups;
  final String? tenantId;
  final String? facilityId;
  final Future<AppFailure?> Function(String status) onStatusChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMutated;

  @override
  State<_AccessAdminUserDetailDialog> createState() =>
      _AccessAdminUserDetailDialogState();
}

class _AccessAdminUserDetailDialogState
    extends State<_AccessAdminUserDetailDialog> {
  late AccessAdminItem _item;
  late AccessAdminUserDetail _detail;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _detail = widget.detail;
  }

  Future<void> _toggleStatus() async {
    final String nextStatus = _item.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
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

  Future<void> _reloadDetail() async {
    final Result<AccessAdminUserDetail> result = await widget.repository
        .getUserDetail(
          _item.mutationId,
          tenantId: _item.tenantId ?? widget.tenantId,
        );
    if (!mounted) return;
    result.when(
      success: (AccessAdminUserDetail detail) {
        setState(() {
          _detail = detail;
          _item = detail.item;
          _saving = false;
        });
        widget.onMutated?.call();
      },
      failure: (AppFailure failure) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failureMessage(failure))),
        );
      },
    );
  }

  List<AppUserAccessRoleGroup> get _roleGroups {
    return _detail.resolvedRoleGroups
        .map(
          (AccessAdminRolePermissionGroup group) => AppUserAccessRoleGroup(
            roleId: group.roleId,
            roleName: group.roleName,
            userRoleId: group.userRoleId,
            permissions: group.permissions
                .map((AccessAdminRolePermissionPreview preview) => preview.name)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  List<AppUserAccessDirectPermission> get _directPermissions {
    return _detail.directPermissions
        .map(
          (AccessAdminPermissionRef permission) =>
              AppUserAccessDirectPermission(
                id: permission.mutationId,
                name: permission.name,
              ),
        )
        .toList(growable: false);
  }

  Future<void> _addRole() async {
    final AppLocalizations l10n = context.l10n;
    final String? tenantId = (widget.tenantId ?? _item.tenantId)?.trim();
    if (tenantId == null || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accessAdminTenantContextRequiredBody)),
      );
      return;
    }

    // Always load roles for this user's tenant/facility. Workspace list lookups
    // may be empty (lean/skipLookups) or scoped to a different tenant.
    setState(() => _saving = true);
    final Result<AccessAdminLookups> lookupResult = await widget.repository
        .getReferenceData(
          tenantId: tenantId,
          facilityId: widget.facilityId ?? _item.facilityId,
          include: const <String>['roles'],
          forceRefresh: true,
        );
    if (!mounted) return;
    final AccessAdminLookups? resolved = lookupResult.when(
      success: (AccessAdminLookups value) => value,
      failure: (_) => null,
    );
    setState(() => _saving = false);
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lookupResult.when(
              success: (_) =>
                  l10n.accessAdminUserAccessNoAssignableRolesMessage,
              failure: (AppFailure failure) =>
                  context.l10n.failureMessage(failure),
            ),
          ),
        ),
      );
      return;
    }

    final Set<String> assignedRoleIds = <String>{
      for (final AccessAdminRolePermissionGroup group
          in _detail.resolvedRoleGroups) ...<String>[
        group.roleId,
        if ((group.resourceUuid ?? '').trim().isNotEmpty) group.resourceUuid!,
      ],
    };
    final List<AccessAdminLookupOption> availableRoles = resolved.roles
        .where(
          (AccessAdminLookupOption role) =>
              role.id.trim().isNotEmpty && !assignedRoleIds.contains(role.id),
        )
        .toList(growable: false);

    if (availableRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.accessAdminUserAccessNoAssignableRolesMessage),
        ),
      );
      return;
    }

    final List<AppRoleAssignmentOption> roleOptions = availableRoles
        .map(
          (AccessAdminLookupOption role) => AppRoleAssignmentOption(
            id: role.id,
            label: role.label,
            description: role.meta,
            permissionCount: role.permissionCount,
          ),
        )
        .toList(growable: false);
    final Set<String> selectedRoleIds = <String>{};

    Future<Set<String>> loadRolePermissions(String roleId) async {
      final Result<List<AccessAdminRolePermissionAssignment>> result =
          await widget.repository.listRolePermissions(roleId);
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

    final Set<String>? confirmed = await showAppDialog<Set<String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AppDialog(
              title: Text(l10n.accessAdminUserAccessAddRoleDialogTitle),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              maxWidth: 960,
              scrollable: true,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.accessAdminUserAccessAddRoleDialogDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: Theme.of(context).spacing.md),
                  AppRoleAssignmentPicker(
                    roles: roleOptions,
                    selectedRoleIds: selectedRoleIds,
                    loadRolePermissions: loadRolePermissions,
                    // Let the dialog scroll; avoid a nested roles scroller.
                    maxListHeight: null,
                    onSelectionChanged: (Set<String> next) {
                      setDialogState(() {
                        selectedRoleIds
                          ..clear()
                          ..addAll(next);
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                AppButton.primary(
                  label: l10n.accessAdminUserAccessAddRoleAction,
                  leadingIcon: Icons.check,
                  onPressed: selectedRoleIds.isEmpty
                      ? null
                      : () => Navigator.of(
                          dialogContext,
                        ).pop(Set<String>.from(selectedRoleIds)),
                ),
                AppButton.secondary(
                  label: l10n.commonCancelActionLabel,
                  leadingIcon: Icons.close,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == null || confirmed.isEmpty || !mounted) {
      return;
    }
    final Set<String> rolesToAssign = confirmed;

    setState(() => _saving = true);
    AppFailure? lastFailure;
    final List<Result<void>> results = await Future.wait(
      rolesToAssign.map(
        (String roleId) => widget.repository.assignUserRole(
          AccessAdminUserRoleDraft(
            userId: _item.mutationId,
            roleId: roleId,
            tenantId: tenantId,
            facilityId: widget.facilityId ?? _item.facilityId,
          ),
        ),
      ),
    );
    for (final Result<void> result in results) {
      if (result case ResultFailure<void>(:final failure)) {
        lastFailure ??= failure;
      }
    }
    if (!mounted) return;
    if (lastFailure != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(lastFailure))),
      );
      return;
    }
    await _reloadDetail();
  }

  Future<void> _removeRole(AppUserAccessRoleGroup group) async {
    final String? userRoleId = group.userRoleId?.trim();
    if (userRoleId == null || userRoleId.isEmpty) {
      return;
    }

    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.accessAdminUserAccessRemoveRoleConfirmTitle,
        body: l10n.accessAdminUserAccessRemoveRoleConfirmMessage(
          group.roleName,
        ),
        highlightedText: group.roleName,
        submitLabel: l10n.accessAdminUserAccessRemoveRoleAction,
        destructive: true,
        icon: const Icon(Icons.remove_circle_outline),
        onConfirm: () async {
          final Result<void> result = await widget.repository.revokeUserRole(
            userRoleId,
          );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _saving = true);
      await _reloadDetail();
    }
  }

  Future<void> _addDirectPermission() async {
    final AppLocalizations l10n = context.l10n;
    final String? tenantId = (widget.tenantId ?? _item.tenantId)?.trim();
    if (tenantId == null || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accessAdminTenantContextRequiredBody)),
      );
      return;
    }

    setState(() => _saving = true);
    final Result<AccessAdminLookups> lookupResult = await widget.repository
        .getReferenceData(
          tenantId: tenantId,
          facilityId: widget.facilityId ?? _item.facilityId,
          include: const <String>['permissions'],
          forceRefresh: true,
        );
    if (!mounted) return;
    final AccessAdminLookups? resolved = lookupResult.when(
      success: (AccessAdminLookups value) => value,
      failure: (_) => null,
    );
    setState(() => _saving = false);
    if (resolved == null || resolved.permissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lookupResult.when(
              success: (_) =>
                  l10n.accessAdminPermissionCatalogUnavailableMessage,
              failure: (AppFailure failure) =>
                  context.l10n.failureMessage(failure),
            ),
          ),
        ),
      );
      return;
    }

    final Set<String> selectedIds = _resolveDirectPermissionOptionIds(
      directs: _detail.directPermissions,
      permissionLookups: resolved.permissions,
    );
    final List<AppPermissionAssignmentOption> options = resolved.permissions
        .map(
          (AccessAdminLookupOption permission) => AppPermissionAssignmentOption(
            id: permission.id,
            code: permission.label,
            label: l10n.permissionCatalogLabelForCode(permission.label),
            description: permission.meta,
          ),
        )
        .toList(growable: false);

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AppDialog(
              title: Text(
                l10n.accessAdminUserAccessAddDirectPermissionDialogTitle,
              ),
              icon: const Icon(Icons.key_outlined),
              maxWidth: 720,
              scrollable: true,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.accessAdminUserAccessAddDirectPermissionDialogDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: Theme.of(context).spacing.md),
                  AppPermissionAssignmentPicker(
                    permissions: options,
                    selectedPermissionIds: selectedIds,
                    onSelectionChanged: (Set<String> next) {
                      setDialogState(() {
                        selectedIds
                          ..clear()
                          ..addAll(next);
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                AppButton.primary(
                  label: l10n.commonSaveActionLabel,
                  leadingIcon: Icons.save_outlined,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
                AppButton.secondary(
                  label: l10n.commonCancelActionLabel,
                  leadingIcon: Icons.close,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _saving = true);
    final Result<void> result = await widget.repository
        .syncUserDirectPermissions(
          userId: _item.mutationId,
          permissionIds: selectedIds.toList(growable: false),
        );
    if (!mounted) return;
    final AppFailure? failure = result.when(
      success: (_) => null,
      failure: (AppFailure value) => value,
    );
    if (failure != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
      return;
    }
    await _reloadDetail();
  }

  Future<void> _removeDirectPermission(
    AppUserAccessDirectPermission permission,
  ) async {
    final List<String> nextIds = _detail.directPermissions
        .where(
          (AccessAdminPermissionRef entry) =>
              entry.mutationId != permission.id && entry.id != permission.id,
        )
        .map((AccessAdminPermissionRef entry) => entry.mutationId)
        .toList(growable: false);

    setState(() => _saving = true);
    final Result<void> result = await widget.repository
        .syncUserDirectPermissions(
          userId: _item.mutationId,
          permissionIds: nextIds,
        );
    if (!mounted) return;
    final AppFailure? failure = result.when(
      success: (_) => null,
      failure: (AppFailure value) => value,
    );
    if (failure != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
      return;
    }
    await _reloadDetail();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AccessAdminItem item = _item;

    return AppDialog(
      title: Text(l10n.accessAdminCreateUserDetailsSectionTitle),
      icon: const Icon(Icons.person_outline),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 920,
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
                        value: (item.tenantName?.trim().isNotEmpty == true
                            ? item.tenantName!
                            : item.tenantId!),
                      ),
                    if (item.facilityId != null)
                      _UserDetailInfoTile(
                        icon: Icons.local_hospital_outlined,
                        label: l10n.settingsWorkspaceFacilityLabel,
                        value: (item.facilityName?.trim().isNotEmpty == true
                            ? item.facilityName!
                            : item.facilityId!),
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
          AppUserAccessPanel(
            roleGroups: _roleGroups,
            directPermissions: _directPermissions,
            canWrite: widget.canWrite,
            isBusy: _saving,
            onAddRole: widget.canWrite ? _addRole : null,
            onRemoveRole: widget.canWrite ? _removeRole : null,
            onAddDirectPermission: widget.canWrite
                ? _addDirectPermission
                : null,
            onRemoveDirectPermission: widget.canWrite
                ? _removeDirectPermission
                : null,
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

/// Maps existing direct permissions onto catalog lookup option ids for the picker.
Set<String> _resolveDirectPermissionOptionIds({
  required List<AccessAdminPermissionRef> directs,
  required List<AccessAdminLookupOption> permissionLookups,
}) {
  final Map<String, String> idByLookupId = <String, String>{
    for (final AccessAdminLookupOption option in permissionLookups)
      option.id: option.id,
  };
  final Map<String, String> idByName = <String, String>{
    for (final AccessAdminLookupOption option in permissionLookups)
      option.label: option.id,
  };
  final Set<String> resolved = <String>{};

  for (final AccessAdminPermissionRef permission in directs) {
    final List<String> candidates = <String>[
      permission.mutationId,
      permission.id,
      permission.name,
      if (permission.resourceUuid != null) permission.resourceUuid!,
    ];
    String? matched;
    for (final String candidate in candidates) {
      final String trimmed = candidate.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      matched = idByLookupId[trimmed] ?? idByName[trimmed];
      if (matched != null) {
        break;
      }
    }
    if (matched != null) {
      resolved.add(matched);
    } else if (permission.mutationId.trim().isNotEmpty) {
      resolved.add(permission.mutationId.trim());
    }
  }

  return resolved;
}

class _UserDetailSummaryCard extends StatelessWidget {
  const _UserDetailSummaryCard({required this.item});

  final AccessAdminItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
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
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.xs,
                    children: <Widget>[
                      _AccessAdminDetailMetaChip(
                        icon: Icons.tag_outlined,
                        label: l10n.accessAdminColumnId,
                        value: item.effectiveDisplayId,
                      ),
                      if (item.status != null)
                        _UserDetailStatusChip(status: item.status!),
                      if (item.isDemo)
                        Chip(
                          avatar: Icon(
                            Icons.science_outlined,
                            size: 16,
                            color: colorScheme.tertiary,
                          ),
                          label: Text(l10n.accessAdminPanelDemo),
                          visualDensity: VisualDensity.compact,
                        ),
                      _AccessAdminDetailMetaChip(
                        icon: Icons.groups_outlined,
                        label: l10n.accessAdminAssignedRolesLabel,
                        value: '${item.roleCount}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

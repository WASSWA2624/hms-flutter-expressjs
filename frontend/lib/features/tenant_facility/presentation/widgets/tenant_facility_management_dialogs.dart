import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_sync.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/management/platform_admin_list_config.dart';
import 'package:hosspi_hms/shared/management/platform_management_list_sync.dart';

const Set<String> _tenantManagementRealtimeEvents = <String>{
  RealtimeEvents.tenantCreated,
  RealtimeEvents.tenantUpdated,
  RealtimeEvents.tenantDeleted,
  RealtimeEvents.tenantRestored,
  RealtimeEvents.tenantPermanentlyDeleted,
};

const Set<String> _facilityManagementRealtimeEvents = <String>{
  RealtimeEvents.tenantCreated,
  RealtimeEvents.tenantUpdated,
  RealtimeEvents.tenantDeleted,
  RealtimeEvents.facilityCreated,
  RealtimeEvents.facilityUpdated,
  RealtimeEvents.facilityDeleted,
};

String? _managementNonEmptyString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _managementResourceIdFromMessage(
  RealtimeMessage message, {
  required Iterable<String> keys,
}) {
  final Map<String, Object?> payload = message.payload;
  final Object? nested = payload['payload'];
  final Map<String, Object?>? nestedMap = nested is Map<String, Object?>
      ? nested
      : nested is Map<Object?, Object?>
      ? Map<String, Object?>.fromEntries(
          nested.entries
              .where((MapEntry<Object?, Object?> entry) => entry.key != null)
              .map(
                (MapEntry<Object?, Object?> entry) => MapEntry<String, Object?>(
                  entry.key.toString(),
                  entry.value,
                ),
              ),
        )
      : null;

  for (final String key in keys) {
    final String? fromRoot = _managementNonEmptyString(payload[key]);
    if (fromRoot != null) {
      return fromRoot;
    }
    final String? fromNested = _managementNonEmptyString(nestedMap?[key]);
    if (fromNested != null) {
      return fromNested;
    }
  }
  return null;
}

void _syncPlatformDashboard(
  WidgetRef ref, {
  HomeDashboardOptimisticPatch? patch,
}) {
  const HomeDashboardRequest request = HomeDashboardRequest.empty;
  if (patch != null && !patch.isEmpty) {
    homeApplyDashboardOptimisticPatch(ref, request, patch);
  }
  ref.invalidate(homeControllerProvider(request));
}

Future<bool?> showManageTenantsDialog(BuildContext context, WidgetRef ref) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => const _ManageTenantsDialog(),
  );
}

Future<bool?> showManageFacilitiesDialog(BuildContext context, WidgetRef ref) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => const _ManageFacilitiesDialog(),
  );
}

class _ManageTenantsDialog extends ConsumerStatefulWidget {
  const _ManageTenantsDialog();

  @override
  ConsumerState<_ManageTenantsDialog> createState() =>
      _ManageTenantsDialogState();
}

class _ManageTenantsDialogState extends ConsumerState<_ManageTenantsDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loading = true;
  AppFailure? _failure;
  AppPageRequest _pageRequest = PlatformAdminListConfig.initialPageRequest;
  int _totalItemCount = 0;
  List<TenantProfile> _tenants = const <TenantProfile>[];
  bool _mutated = false;
  int _reloadGeneration = 0;
  PlatformManagementListSync? _realtimeSync;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_reload(resetPage: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _realtimeSync ??= PlatformManagementListSync(
      ref: ref,
      events: _tenantManagementRealtimeEvents,
      onMutated: () => _mutated = true,
      reload: ({bool silent = false, RealtimeMessage? message}) async {
        _applyTenantRealtimeMessage(message);
        await _reload(resetPage: false, silent: silent);
      },
    )..attach();
  }

  @override
  void dispose() {
    _realtimeSync?.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_reload(resetPage: true));
    });
  }

  Future<void> _reload({required bool resetPage, bool silent = false}) async {
    if (resetPage) {
      _pageRequest = _pageRequest.first();
    }
    final int generation = ++_reloadGeneration;
    if (!silent) {
      setState(() {
        _loading = true;
        _failure = null;
      });
    }

    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final Result<AppPage<TenantProfile>> result = await repository.listTenants(
      request: _pageRequest,
      search: _searchController.text.trim(),
      includeDeleted: true,
    );

    if (!mounted || generation != _reloadGeneration) return;
    result.when(
      success: (AppPage<TenantProfile> page) {
        final List<TenantProfile> tenants = page.items;
        final int totalItemCount = page.totalItemCount ?? tenants.length;
        homeClearDashboardOptimisticPatch(ref, HomeDashboardRequest.empty);
        homeReconcileTenantsMetricFromList(
          ref,
          _countDashboardActiveTenants(tenants),
          totalCount: _countDashboardTotalTenants(tenants),
        );
        ref.invalidate(homeControllerProvider(HomeDashboardRequest.empty));
        setState(() {
          _loading = false;
          _tenants = tenants;
          _totalItemCount = totalItemCount;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loading = false;
          _failure = failure;
          if (!silent) {
            _tenants = const <TenantProfile>[];
          }
        });
      },
    );
  }

  Future<void> _onPageChanged(AppPageRequest request) async {
    _pageRequest = request;
    await _reload(resetPage: false);
  }

  Future<void> _openTenantForm({
    TenantProfile? tenant,
    bool forceCreate = false,
  }) async {
    final bool? wasActive = tenant?.isActive;
    final bool? saved = await showTenantFacilityTenantFormDialog(
      context,
      tenant: tenant,
      forceCreate: forceCreate,
      managementMode: true,
    );
    if (!mounted || saved != true) {
      return;
    }

    _mutated = true;
    if (forceCreate || tenant == null) {
      _syncPlatformDashboard(
        ref,
        patch: HomeDashboardOptimisticPatch.tenantCreated(),
      );
    }

    await _reload(resetPage: forceCreate, silent: true);
    if (!mounted) {
      return;
    }

    if (forceCreate || tenant == null) {
      return;
    }

    if (wasActive == null) {
      return;
    }

    TenantProfile? updatedTenant;
    for (final TenantProfile entry in _tenants) {
      if (entry.id == tenant.id) {
        updatedTenant = entry;
        break;
      }
    }

    if (updatedTenant != null && updatedTenant.isActive != wasActive) {
      _syncPlatformDashboard(
        ref,
        patch: HomeDashboardOptimisticPatch.tenantActiveChanged(
          wasActive: wasActive,
          isActive: updatedTenant.isActive,
        ),
      );
    }
  }

  Future<void> _confirmDeleteTenant(TenantProfile tenant) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityDeleteConfirmationTitle,
        body: l10n.tenantFacilityDeleteTenantConfirmationBody(tenant.name),
        highlightedText: tenant.name,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(tenantFacilityRepositoryProvider)
              .deleteTenant(tenant.mutationId);
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) {
              if (failure.category == AppFailureCategory.notFound) {
                return null;
              }
              return failure;
            },
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (confirmed == true) {
      _mutated = true;
      _markTenantSoftDeletedLocally(tenant);
      _syncPlatformDashboard(
        ref,
        patch: HomeDashboardOptimisticPatch.tenantDeleted(
          isActive: tenant.isActive && !tenant.isDeleted,
        ),
      );
      unawaited(_reload(resetPage: false, silent: true));
    }
  }

  Future<void> _confirmRestoreTenant(TenantProfile tenant) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityRestoreConfirmationTitle,
        body: l10n.tenantFacilityRestoreTenantConfirmationBody(tenant.name),
        highlightedText: tenant.name,
        submitLabel: l10n.tenantFacilityRestoreTenantAction,
        icon: const Icon(Icons.restore_outlined),
        onConfirm: () async {
          final Result<TenantProfile> result = await ref
              .read(tenantFacilityRepositoryProvider)
              .restoreTenant(tenant.mutationId);
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    _mutated = true;
    _markTenantRestoredLocally(tenant);
    _syncPlatformDashboard(
      ref,
      patch: HomeDashboardOptimisticPatch.tenantRestored(
        isActive: tenant.isActive,
      ),
    );
    unawaited(_reload(resetPage: false, silent: true));
  }

  Future<void> _confirmPermanentDeleteTenant(TenantProfile tenant) async {
    final AppLocalizations l10n = context.l10n;
    final String? typed = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AppTextInputActionDialog(
        title: l10n.tenantFacilityPermanentDeleteConfirmationTitle,
        description: l10n.tenantFacilityPermanentDeleteWarningBody(tenant.name),
        fieldLabel: l10n.tenantFacilityPermanentDeleteConfirmFieldLabel(
          tenant.name,
        ),
        submitLabel: l10n.tenantFacilityPermanentDeleteConfirmAction,
        cancelLabel: l10n.commonCancelActionLabel,
        requiredMessage: l10n.validationRequired,
        destructive: true,
        minLines: 1,
        maxLines: 1,
        icon: const Icon(Icons.delete_forever_outlined),
      ),
    );

    if (!mounted || typed == null) {
      return;
    }
    if (typed.trim() != tenant.name.trim()) {
      return;
    }

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityPermanentDeleteConfirmationTitle,
        body: l10n.tenantFacilityPermanentDeleteConfirmationBody(tenant.name),
        highlightedText: tenant.name,
        submitLabel: l10n.tenantFacilityPermanentDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_forever_outlined),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(tenantFacilityRepositoryProvider)
              .permanentDeleteTenant(tenant.mutationId);
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) {
              // Already purged — treat as success so the dialog closes and
              // the list can drop the stale row immediately.
              if (failure.category == AppFailureCategory.notFound) {
                return null;
              }
              return failure;
            },
          );
        },
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    _mutated = true;
    _removeTenantLocally(tenant);
    _syncPlatformDashboard(ref);
    unawaited(_reload(resetPage: false, silent: true));
  }

  bool _matchesTenant(TenantProfile entry, TenantProfile target) {
    return entry.id == target.id ||
        entry.mutationId == target.mutationId ||
        (target.slug != null &&
            target.slug!.isNotEmpty &&
            entry.slug == target.slug);
  }

  bool _matchesTenantId(TenantProfile entry, String tenantId) {
    return entry.id == tenantId ||
        entry.mutationId == tenantId ||
        entry.slug == tenantId;
  }

  void _markTenantSoftDeletedLocally(TenantProfile tenant) {
    final int index = _tenants.indexWhere(
      (TenantProfile entry) => _matchesTenant(entry, tenant),
    );
    if (index < 0) {
      return;
    }
    final List<TenantProfile> next = List<TenantProfile>.of(_tenants);
    next[index] = tenant.copyWith(deletedAt: DateTime.now().toUtc());
    setState(() {
      _tenants = next;
    });
    _reconcileDashboardFromLocalList();
  }

  void _markTenantRestoredLocally(TenantProfile tenant) {
    final int index = _tenants.indexWhere(
      (TenantProfile entry) => _matchesTenant(entry, tenant),
    );
    if (index < 0) {
      return;
    }
    final List<TenantProfile> next = List<TenantProfile>.of(_tenants);
    next[index] = tenant.copyWith(clearDeletedAt: true);
    setState(() {
      _tenants = next;
    });
    _reconcileDashboardFromLocalList();
  }

  void _removeTenantLocally(TenantProfile tenant) {
    final List<TenantProfile> next = _tenants
        .where((TenantProfile entry) => !_matchesTenant(entry, tenant))
        .toList(growable: false);
    if (next.length == _tenants.length) {
      return;
    }
    setState(() {
      _tenants = next;
      _totalItemCount = math.max(0, _totalItemCount - 1);
    });
    _reconcileDashboardFromLocalList();
  }

  void _removeTenantByIdLocally(String tenantId) {
    final int before = _tenants.length;
    final List<TenantProfile> next = _tenants
        .where((TenantProfile entry) => !_matchesTenantId(entry, tenantId))
        .toList(growable: false);
    if (next.length == before) {
      return;
    }
    setState(() {
      _tenants = next;
      _totalItemCount = math.max(0, _totalItemCount - (before - next.length));
    });
    _reconcileDashboardFromLocalList();
  }

  void _reconcileDashboardFromLocalList() {
    homeClearDashboardOptimisticPatch(ref, HomeDashboardRequest.empty);
    homeReconcileTenantsMetricFromList(
      ref,
      _countDashboardActiveTenants(_tenants),
      totalCount: _countDashboardTotalTenants(_tenants),
    );
    ref.invalidate(homeControllerProvider(HomeDashboardRequest.empty));
  }

  void _applyTenantRealtimeMessage(RealtimeMessage? message) {
    if (message == null) {
      return;
    }

    final String? tenantId = _managementResourceIdFromMessage(
      message,
      keys: const <String>['resource_id', 'tenant_id', 'id'],
    );

    switch (message.event) {
      case RealtimeEvents.tenantDeleted:
        if (tenantId == null) {
          return;
        }
        final int index = _tenants.indexWhere(
          (TenantProfile entry) => _matchesTenantId(entry, tenantId),
        );
        if (index < 0) {
          return;
        }
        final List<TenantProfile> next = List<TenantProfile>.of(_tenants);
        next[index] = next[index].copyWith(deletedAt: DateTime.now().toUtc());
        setState(() {
          _tenants = next;
        });
        _reconcileDashboardFromLocalList();
        return;
      case RealtimeEvents.tenantPermanentlyDeleted:
        if (tenantId != null) {
          _removeTenantByIdLocally(tenantId);
        }
        return;
      case RealtimeEvents.tenantRestored:
      case RealtimeEvents.tenantCreated:
      case RealtimeEvents.tenantUpdated:
        return;
    }
  }

  int _countDashboardActiveTenants(List<TenantProfile> tenants) {
    return tenants
        .where(
          (TenantProfile tenant) => !tenant.isDeleted && tenant.isActive,
        )
        .length;
  }

  int _countDashboardTotalTenants(List<TenantProfile> tenants) {
    return tenants.where((TenantProfile tenant) => !tenant.isDeleted).length;
  }

  String _tenantStatusLabel(AppLocalizations l10n, TenantProfile tenant) {
    if (tenant.isDeleted) {
      return l10n.tenantFacilityTenantStatusDeleted;
    }
    return tenant.isActive
        ? l10n.tenantFacilityTenantStatusActive
        : l10n.commonNoLabel;
  }

  bool get _canCreate => ref.read(appAccessPolicyProvider).canCreateTenant();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.tenantFacilityManageTenantsTitle),
      icon: const Icon(Icons.corporate_fare_outlined),
      pinActionsToBottom: true,
      maxWidth: 960,
      content: SizedBox(
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSearchBar(
              controller: _searchController,
              hintText: l10n.tenantFacilitySearchLabel,
              semanticLabel: l10n.tenantFacilitySearchLabel,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _failure != null
                  ? AppFailureStateView(
                      failure: _failure!,
                      onRetry: () => unawaited(_reload(resetPage: true)),
                    )
                  : AppListTable<TenantProfile>(
                      page: AppPage<TenantProfile>(
                        items: _tenants,
                        request: _pageRequest,
                        totalItemCount: _totalItemCount,
                      ),
                      isLoading: _loading,
                      itemKeyBuilder: (TenantProfile item) =>
                          ValueKey<String>(item.id),
                      onRowSelected: _canCreate
                          ? (TenantProfile tenant) {
                              if (tenant.isDeleted) {
                                return;
                              }
                              unawaited(_openTenantForm(tenant: tenant));
                            }
                          : null,
                      previousPageLabel: l10n.hrPreviousPageLabel,
                      nextPageLabel: l10n.hrNextPageLabel,
                      pageLabelBuilder: (AppPage<TenantProfile> page) {
                        if (_loading) {
                          return '';
                        }
                        final int total =
                            page.totalItemCount ?? page.items.length;
                        if (total == 0) return l10n.commonTableEmptyLabel;
                        final int start = page.pageIndex * page.pageSize + 1;
                        final int end = start + page.items.length - 1;
                        return '$start-$end / $total';
                      },
                      onPageChanged: _onPageChanged,
                      columns: <AppListTableColumn<TenantProfile>>[
                        AppListTableColumn<TenantProfile>(
                          label: l10n.tenantFacilityTenantNameLabel,
                          cellBuilder: (_, TenantProfile tenant) => Text(
                            tenant.name,
                            style: tenant.isDeleted
                                ? Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    )
                                : null,
                          ),
                        ),
                        AppListTableColumn<TenantProfile>(
                          label: l10n.tenantFacilityTenantSlugLabel,
                          cellBuilder: (_, TenantProfile tenant) =>
                              Text(tenant.slug ?? '—'),
                        ),
                        AppListTableColumn<TenantProfile>(
                          label: l10n.tenantFacilityTenantStatusLabel,
                          cellBuilder: (_, TenantProfile tenant) => Text(
                            _tenantStatusLabel(l10n, tenant),
                          ),
                        ),
                        if (_canCreate)
                          AppListTableColumn<TenantProfile>(
                            label: '',
                            alwaysVisible: true,
                            cellBuilder:
                                (BuildContext context, TenantProfile tenant) {
                                  return _TenantManagementRowActions(
                                    enabled: !_loading,
                                    tenant: tenant,
                                    editLabel:
                                        l10n.tenantFacilitySaveTenantAction,
                                    deleteLabel:
                                        l10n.tenantFacilityDeleteAction,
                                    restoreLabel:
                                        l10n.tenantFacilityRestoreTenantAction,
                                    permanentDeleteLabel: l10n
                                        .tenantFacilityPermanentDeleteAction,
                                    onEdit: () => unawaited(
                                      _openTenantForm(tenant: tenant),
                                    ),
                                    onDelete: () => unawaited(
                                      _confirmDeleteTenant(tenant),
                                    ),
                                    onRestore: () => unawaited(
                                      _confirmRestoreTenant(tenant),
                                    ),
                                    onPermanentDelete: () => unawaited(
                                      _confirmPermanentDeleteTenant(tenant),
                                    ),
                                  );
                                },
                          ),
                      ],
                      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                        title: l10n.tenantFacilityManageTenantsTitle,
                        body: l10n.tenantFacilityNoTenants,
                      ),
                      mobileItemBuilder:
                          (BuildContext context, TenantProfile tenant) {
                            return ListTile(
                              title: Text(tenant.name),
                              subtitle: Text(
                                '${tenant.slug ?? tenant.id} · ${_tenantStatusLabel(l10n, tenant)}',
                              ),
                              trailing: _canCreate
                                  ? _TenantManagementRowActions(
                                      enabled: !_loading,
                                      tenant: tenant,
                                      editLabel:
                                          l10n.tenantFacilitySaveTenantAction,
                                      deleteLabel:
                                          l10n.tenantFacilityDeleteAction,
                                      restoreLabel:
                                          l10n.tenantFacilityRestoreTenantAction,
                                      permanentDeleteLabel: l10n
                                          .tenantFacilityPermanentDeleteAction,
                                      onEdit: () => unawaited(
                                        _openTenantForm(tenant: tenant),
                                      ),
                                      onDelete: () => unawaited(
                                        _confirmDeleteTenant(tenant),
                                      ),
                                      onRestore: () => unawaited(
                                        _confirmRestoreTenant(tenant),
                                      ),
                                      onPermanentDelete: () => unawaited(
                                        _confirmPermanentDeleteTenant(tenant),
                                      ),
                                    )
                                  : Text(_tenantStatusLabel(l10n, tenant)),
                              onTap: _canCreate && !tenant.isDeleted
                                  ? () => unawaited(
                                      _openTenantForm(tenant: tenant),
                                    )
                                  : null,
                            );
                          },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (_canCreate)
          AppButton.primary(
            label: l10n.tenantFacilityAddTenantAction,
            leadingIcon: Icons.add_business_outlined,
            onPressed: _loading
                ? null
                : () => unawaited(_openTenantForm(forceCreate: true)),
          ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(_mutated ? true : null),
        ),
      ],
    );
  }
}

class _ManageFacilitiesDialog extends ConsumerStatefulWidget {
  const _ManageFacilitiesDialog();

  @override
  ConsumerState<_ManageFacilitiesDialog> createState() =>
      _ManageFacilitiesDialogState();
}

class _ManageFacilitiesDialogState
    extends ConsumerState<_ManageFacilitiesDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loading = true;
  AppFailure? _failure;
  AppPageRequest _pageRequest = PlatformAdminListConfig.initialPageRequest;
  int _totalItemCount = 0;
  List<FacilityProfile> _facilities = const <FacilityProfile>[];
  List<TenantProfile> _tenantOptions = const <TenantProfile>[];
  String? _tenantFilterId;
  bool _mutated = false;
  int _reloadGeneration = 0;
  PlatformManagementListSync? _realtimeSync;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadTenants());
    });
    unawaited(_reload(resetPage: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _realtimeSync ??= PlatformManagementListSync(
      ref: ref,
      events: _facilityManagementRealtimeEvents,
      onMutated: () => _mutated = true,
      reload: ({bool silent = false, RealtimeMessage? message}) async {
        _applyFacilityRealtimeMessage(message);
        await _loadTenants();
        await _reload(resetPage: false, silent: silent);
      },
    )..attach();
  }

  @override
  void dispose() {
    _realtimeSync?.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTenants() async {
    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final Result<AppPage<TenantProfile>> result = await repository.listTenants(
      request: PlatformAdminListConfig.initialPageRequest,
    );
    if (!mounted) return;
    result.when(
      success: (AppPage<TenantProfile> page) {
        setState(() {
          _tenantOptions = page.items;
        });
      },
      failure: (_) {},
    );
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_reload(resetPage: true));
    });
  }

  Future<void> _reload({required bool resetPage, bool silent = false}) async {
    if (resetPage) {
      _pageRequest = _pageRequest.first();
    }
    final int generation = ++_reloadGeneration;
    if (!silent) {
      setState(() {
        _loading = true;
        _failure = null;
      });
    }

    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final Result<AppPage<FacilityProfile>> result = await repository
        .listFacilities(
          request: _pageRequest,
          tenantId: _tenantFilterId,
          search: _searchController.text.trim(),
        );

    if (!mounted || generation != _reloadGeneration) return;
    result.when(
      success: (AppPage<FacilityProfile> page) {
        final int activeCount = page.items
            .where((FacilityProfile facility) => facility.isActive)
            .length;
        final int totalItemCount = page.totalItemCount ?? page.items.length;
        homeReconcileFacilitiesMetricFromList(
          ref,
          activeCount,
          totalCount: totalItemCount,
        );
        setState(() {
          _loading = false;
          _facilities = page.items;
          _totalItemCount = totalItemCount;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loading = false;
          _failure = failure;
          if (!silent) {
            _facilities = const <FacilityProfile>[];
          }
        });
      },
    );
  }

  Future<void> _onPageChanged(AppPageRequest request) async {
    _pageRequest = request;
    await _reload(resetPage: false);
  }

  Future<void> _openFacilityForm({
    FacilityProfile? facility,
    bool forceCreate = false,
  }) async {
    final bool? saved = await showTenantFacilityFacilityFormDialog(
      context,
      tenantId: facility?.tenantId ?? _tenantFilterId,
      facility: facility,
      requireTenantPicker: forceCreate || facility == null,
      managementMode: true,
    );
    if (!mounted || saved != true) {
      return;
    }

    _mutated = true;
    await _loadTenants();
    await _reload(resetPage: forceCreate, silent: true);
    if (!mounted) {
      return;
    }

    if (forceCreate || facility == null) {
      _syncPlatformDashboard(
        ref,
        patch: HomeDashboardOptimisticPatch.facilityCreated(),
      );
    }
  }

  Future<void> _confirmDeleteFacility(FacilityProfile facility) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityDeleteConfirmationTitle,
        body: l10n.tenantFacilityDeleteFacilityConfirmationBody(facility.name),
        highlightedText: facility.name,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(tenantFacilityRepositoryProvider)
              .deleteFacility(facility.mutationId);
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) {
              if (failure.category == AppFailureCategory.notFound) {
                return null;
              }
              return failure;
            },
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (confirmed == true) {
      _mutated = true;
      _removeFacilityLocally(facility.mutationId);
      _syncPlatformDashboard(
        ref,
        patch: HomeDashboardOptimisticPatch.facilityDeleted(
          isActive: facility.isActive,
        ),
      );
      await _loadTenants();
      await _reload(resetPage: _facilities.isEmpty, silent: true);
    }
  }

  void _removeFacilityLocally(String facilityId) {
    final int before = _facilities.length;
    final List<FacilityProfile> next = _facilities
        .where(
          (FacilityProfile entry) =>
              entry.id != facilityId && entry.mutationId != facilityId,
        )
        .toList(growable: false);
    if (next.length == before) {
      return;
    }
    setState(() {
      _facilities = next;
      _totalItemCount = math.max(0, _totalItemCount - (before - next.length));
    });
  }

  void _applyFacilityRealtimeMessage(RealtimeMessage? message) {
    if (message == null) {
      return;
    }
    if (message.event == RealtimeEvents.facilityDeleted) {
      final String? facilityId = _managementResourceIdFromMessage(
        message,
        keys: const <String>['resource_id', 'facility_id', 'id'],
      );
      if (facilityId != null) {
        _removeFacilityLocally(facilityId);
      }
    }
  }

  bool get _canManage => ref.read(appAccessPolicyProvider).canManageFacility();

  String _tenantLabel(String tenantId) {
    for (final TenantProfile tenant in _tenantOptions) {
      if (tenant.id == tenantId) {
        return tenant.name;
      }
    }
    return tenantId;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.tenantFacilityManageFacilitiesTitle),
      icon: const Icon(Icons.domain_outlined),
      pinActionsToBottom: true,
      maxWidth: 1040,
      content: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_tenantOptions.isNotEmpty) ...<Widget>[
              AppSelectField<String?>(
                labelText: l10n.profileTenantLabel,
                value: _tenantFilterId,
                options: <AppSelectOption<String?>>[
                  AppSelectOption<String?>(
                    value: null,
                    label: l10n.commonAllLabel,
                  ),
                  ..._tenantOptions.map(
                    (TenantProfile tenant) => AppSelectOption<String?>(
                      value: tenant.id,
                      label: tenant.name,
                    ),
                  ),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _tenantFilterId = value;
                  });
                  unawaited(_reload(resetPage: true));
                },
              ),
              SizedBox(height: theme.spacing.md),
            ],
            AppSearchBar(
              controller: _searchController,
              hintText: l10n.tenantFacilitySearchLabel,
              semanticLabel: l10n.tenantFacilitySearchLabel,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _failure != null
                  ? AppFailureStateView(
                      failure: _failure!,
                      onRetry: () => unawaited(_reload(resetPage: true)),
                    )
                  : AppListTable<FacilityProfile>(
                      page: AppPage<FacilityProfile>(
                        items: _facilities,
                        request: _pageRequest,
                        totalItemCount: _totalItemCount,
                      ),
                      isLoading: _loading,
                      itemKeyBuilder: (FacilityProfile item) =>
                          ValueKey<String>(item.id),
                      onRowSelected: _canManage
                          ? (FacilityProfile facility) =>
                                unawaited(_openFacilityForm(facility: facility))
                          : null,
                      previousPageLabel: l10n.hrPreviousPageLabel,
                      nextPageLabel: l10n.hrNextPageLabel,
                      pageLabelBuilder: (AppPage<FacilityProfile> page) {
                        if (_loading) {
                          return '';
                        }
                        final int total =
                            page.totalItemCount ?? page.items.length;
                        if (total == 0) return l10n.commonTableEmptyLabel;
                        final int start = page.pageIndex * page.pageSize + 1;
                        final int end = start + page.items.length - 1;
                        return '$start-$end / $total';
                      },
                      onPageChanged: _onPageChanged,
                      columns: <AppListTableColumn<FacilityProfile>>[
                        AppListTableColumn<FacilityProfile>(
                          label: l10n.authFacilityNameLabel,
                          cellBuilder: (_, FacilityProfile facility) =>
                              Text(facility.name),
                        ),
                        AppListTableColumn<FacilityProfile>(
                          label: l10n.profileTenantLabel,
                          cellBuilder: (_, FacilityProfile facility) =>
                              Text(_tenantLabel(facility.tenantId)),
                        ),
                        AppListTableColumn<FacilityProfile>(
                          label: l10n.profileFacilityTypeLabel,
                          cellBuilder: (_, FacilityProfile facility) =>
                              Text(facility.type.name),
                        ),
                        AppListTableColumn<FacilityProfile>(
                          label: l10n.tenantFacilityActiveLabel,
                          cellBuilder: (_, FacilityProfile facility) => Text(
                            facility.isActive
                                ? l10n.commonYesLabel
                                : l10n.commonNoLabel,
                          ),
                        ),
                        if (_canManage)
                          AppListTableColumn<FacilityProfile>(
                            label: '',
                            alwaysVisible: true,
                            cellBuilder:
                                (
                                  BuildContext context,
                                  FacilityProfile facility,
                                ) {
                                  return _ManagementRowActions(
                                    enabled: !_loading,
                                    editLabel:
                                        l10n.tenantFacilityEditFacilityAction,
                                    deleteLabel:
                                        l10n.tenantFacilityDeleteAction,
                                    onEdit: () => unawaited(
                                      _openFacilityForm(facility: facility),
                                    ),
                                    onDelete: () => unawaited(
                                      _confirmDeleteFacility(facility),
                                    ),
                                  );
                                },
                          ),
                      ],
                      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                        title: l10n.tenantFacilityManageFacilitiesTitle,
                        body: l10n.tenantFacilityNoFacilities,
                      ),
                      mobileItemBuilder:
                          (BuildContext context, FacilityProfile facility) {
                            return ListTile(
                              title: Text(facility.name),
                              subtitle: Text(_tenantLabel(facility.tenantId)),
                              trailing: _canManage
                                  ? _ManagementRowActions(
                                      enabled: !_loading,
                                      editLabel:
                                          l10n.tenantFacilityEditFacilityAction,
                                      deleteLabel:
                                          l10n.tenantFacilityDeleteAction,
                                      onEdit: () => unawaited(
                                        _openFacilityForm(facility: facility),
                                      ),
                                      onDelete: () => unawaited(
                                        _confirmDeleteFacility(facility),
                                      ),
                                    )
                                  : Text(
                                      facility.isActive
                                          ? l10n.commonYesLabel
                                          : l10n.commonNoLabel,
                                    ),
                              onTap: _canManage
                                  ? () => unawaited(
                                      _openFacilityForm(facility: facility),
                                    )
                                  : null,
                            );
                          },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (_canManage)
          AppButton.primary(
            label: l10n.tenantFacilityAddFacilityAction,
            leadingIcon: Icons.add_business_outlined,
            onPressed: _loading
                ? null
                : () => unawaited(_openFacilityForm(forceCreate: true)),
          ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(_mutated ? true : null),
        ),
      ],
    );
  }
}

class _TenantManagementRowActions extends StatelessWidget {
  const _TenantManagementRowActions({
    required this.enabled,
    required this.tenant,
    required this.editLabel,
    required this.deleteLabel,
    required this.restoreLabel,
    required this.permanentDeleteLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  final bool enabled;
  final TenantProfile tenant;
  final String editLabel;
  final String deleteLabel;
  final String restoreLabel;
  final String permanentDeleteLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (tenant.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppButton.tertiary(
            leadingIcon: Icons.restore_outlined,
            label: restoreLabel,
            semanticLabel: restoreLabel,
            tooltip: restoreLabel,
            enabled: enabled,
            onPressed: enabled ? onRestore : null,
          ),
          AppButton.tertiary(
            leadingIcon: Icons.delete_forever_outlined,
            label: permanentDeleteLabel,
            semanticLabel: permanentDeleteLabel,
            tooltip: permanentDeleteLabel,
            color: colorScheme.error,
            enabled: enabled,
            onPressed: enabled ? onPermanentDelete : null,
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppButton.tertiary(
          leadingIcon: Icons.edit_outlined,
          label: editLabel,
          semanticLabel: editLabel,
          tooltip: editLabel,
          enabled: enabled,
          onPressed: enabled ? onEdit : null,
        ),
        AppButton.tertiary(
          leadingIcon: Icons.delete_outline,
          label: deleteLabel,
          semanticLabel: deleteLabel,
          tooltip: deleteLabel,
          color: colorScheme.error,
          enabled: enabled,
          onPressed: enabled ? onDelete : null,
        ),
      ],
    );
  }
}

class _ManagementRowActions extends StatelessWidget {
  const _ManagementRowActions({
    required this.enabled,
    required this.editLabel,
    required this.deleteLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final bool enabled;
  final String editLabel;
  final String deleteLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppButton.tertiary(
          leadingIcon: Icons.edit_outlined,
          label: editLabel,
          semanticLabel: editLabel,
          tooltip: editLabel,
          enabled: enabled,
          onPressed: enabled ? onEdit : null,
        ),
        AppButton.tertiary(
          leadingIcon: Icons.delete_outline,
          label: deleteLabel,
          semanticLabel: deleteLabel,
          tooltip: deleteLabel,
          color: colorScheme.error,
          enabled: enabled,
          onPressed: enabled ? onDelete : null,
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/utils/app_media_url.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_dialogs.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_sync.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
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
  RealtimeEvents.facilityRestored,
  RealtimeEvents.facilityPermanentlyDeleted,
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

Future<bool?> showTenantDetailsDialog(
  BuildContext context, {
  required TenantProfile tenant,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => _TenantDetailsDialog(tenant: tenant),
  );
}

Future<bool?> showManageFacilitiesDialog(BuildContext context, WidgetRef ref) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => const _ManageFacilitiesDialog(),
  );
}

Future<bool?> showFacilityDetailsDialog(
  BuildContext context, {
  required FacilityProfile facility,
  String? tenantName,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => _FacilityDetailsDialog(
      facility: facility,
      tenantName: tenantName,
    ),
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

  Future<void> _openTenantDetails(TenantProfile tenant) async {
    final bool? mutated = await showTenantDetailsDialog(
      context,
      tenant: tenant,
    );
    if (!mounted || mutated != true) {
      return;
    }

    _mutated = true;
    await _reload(resetPage: false, silent: true);
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

  bool get _canEdit => ref.read(appAccessPolicyProvider).canManageTenant();

  bool get _canDelete => _canCreate;

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
                      onRowSelected: (TenantProfile tenant) {
                        if (tenant.isDeleted) {
                          return;
                        }
                        unawaited(_openTenantDetails(tenant));
                      },
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
                        if (_canEdit)
                          AppListTableColumn<TenantProfile>(
                            label: '',
                            alwaysVisible: true,
                            cellBuilder:
                                (BuildContext context, TenantProfile tenant) {
                                  return _TenantManagementRowActions(
                                    enabled: !_loading,
                                    tenant: tenant,
                                    canDelete: _canDelete,
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
                              trailing: _canEdit
                                  ? _TenantManagementRowActions(
                                      enabled: !_loading,
                                      tenant: tenant,
                                      canDelete: _canDelete,
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
                              onTap: tenant.isDeleted
                                  ? null
                                  : () => unawaited(
                                      _openTenantDetails(tenant),
                                    ),
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

class _TenantDetailsDialog extends ConsumerStatefulWidget {
  const _TenantDetailsDialog({required this.tenant});

  final TenantProfile tenant;

  @override
  ConsumerState<_TenantDetailsDialog> createState() =>
      _TenantDetailsDialogState();
}

class _TenantDetailsDialogState extends ConsumerState<_TenantDetailsDialog> {
  late TenantProfile _tenant;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loadingFacilities = true;
  AppFailure? _facilitiesFailure;
  AppPageRequest _pageRequest = PlatformAdminListConfig.initialPageRequest;
  int _totalItemCount = 0;
  List<FacilityProfile> _facilities = const <FacilityProfile>[];
  bool _mutated = false;
  int _reloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _tenant = widget.tenant;
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadFacilities());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _canManageTenant =>
      ref.read(appAccessPolicyProvider).canManageTenant();

  bool get _canDeleteTenant =>
      ref.read(appAccessPolicyProvider).canCreateTenant();

  bool get _canManageFacility =>
      ref.read(appAccessPolicyProvider).canManageFacility();

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_loadFacilities(resetPage: true));
    });
  }

  Future<void> _loadFacilities({
    bool silent = false,
    bool resetPage = false,
  }) async {
    if (resetPage) {
      _pageRequest = _pageRequest.first();
    }
    final int generation = ++_reloadGeneration;
    if (!silent) {
      setState(() {
        _loadingFacilities = true;
        _facilitiesFailure = null;
      });
    }

    final Result<AppPage<FacilityProfile>> result = await ref
        .read(tenantFacilityRepositoryProvider)
        .listFacilities(
          request: _pageRequest,
          tenantId: _tenant.mutationId,
          search: _searchController.text.trim(),
          includeDeleted: true,
        );

    if (!mounted || generation != _reloadGeneration) {
      return;
    }

    result.when(
      success: (AppPage<FacilityProfile> page) {
        setState(() {
          _loadingFacilities = false;
          _facilities = page.items;
          _totalItemCount = page.totalItemCount ?? page.items.length;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loadingFacilities = false;
          _facilitiesFailure = failure;
          if (!silent) {
            _facilities = const <FacilityProfile>[];
          }
        });
      },
    );
  }

  Future<void> _onPageChanged(AppPageRequest request) async {
    _pageRequest = request;
    await _loadFacilities();
  }

  String _tenantStatusLabel(AppLocalizations l10n) {
    if (_tenant.isDeleted) {
      return l10n.tenantFacilityTenantStatusDeleted;
    }
    return _tenant.isActive
        ? l10n.tenantFacilityTenantStatusActive
        : l10n.commonNoLabel;
  }

  AppWorkspaceStatusTone _tenantStatusTone() {
    if (_tenant.isDeleted) {
      return AppWorkspaceStatusTone.error;
    }
    return _tenant.isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral;
  }

  String _facilityStatusLabel(AppLocalizations l10n, FacilityProfile facility) {
    if (facility.isDeleted) {
      return l10n.tenantFacilityTenantStatusDeleted;
    }
    return facility.isActive
        ? l10n.tenantFacilityTenantStatusActive
        : l10n.commonNoLabel;
  }

  Future<void> _editTenant() async {
    final bool wasActive = _tenant.isActive;
    final bool? saved = await showTenantFacilityTenantFormDialog(
      context,
      tenant: _tenant,
      managementMode: true,
    );
    if (!mounted || saved != true) {
      return;
    }

    _mutated = true;
    final Result<AppPage<TenantProfile>> result = await ref
        .read(tenantFacilityRepositoryProvider)
        .listTenants(
          request: const AppPageRequest(pageSize: 25),
          search: _tenant.slug ?? _tenant.name,
          includeDeleted: true,
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<TenantProfile> page) {
        TenantProfile? updated;
        for (final TenantProfile entry in page.items) {
          if (entry.id == _tenant.id ||
              entry.mutationId == _tenant.mutationId) {
            updated = entry;
            break;
          }
        }
        if (updated != null) {
          setState(() {
            _tenant = updated!;
          });
          if (updated.isActive != wasActive) {
            _syncPlatformDashboard(
              ref,
              patch: HomeDashboardOptimisticPatch.tenantActiveChanged(
                wasActive: wasActive,
                isActive: updated.isActive,
              ),
            );
          }
        }
      },
      failure: (_) {},
    );
  }

  Future<void> _deleteTenant() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityDeleteConfirmationTitle,
        body: l10n.tenantFacilityDeleteTenantConfirmationBody(_tenant.name),
        highlightedText: _tenant.name,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(tenantFacilityRepositoryProvider)
              .deleteTenant(_tenant.mutationId);
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

    if (!mounted || confirmed != true) {
      return;
    }

    _syncPlatformDashboard(
      ref,
      patch: HomeDashboardOptimisticPatch.tenantDeleted(
        isActive: _tenant.isActive && !_tenant.isDeleted,
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _editFacility(FacilityProfile facility) async {
    final bool? saved = await showTenantFacilityFacilityFormDialog(
      context,
      tenantId: _tenant.mutationId,
      facility: facility,
      managementMode: true,
    );
    if (!mounted || saved != true) {
      return;
    }

    _mutated = true;
    await _loadFacilities(silent: true);
  }

  Future<void> _deleteFacility(FacilityProfile facility) async {
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

    if (!mounted || confirmed != true) {
      return;
    }

    _mutated = true;
    final int index = _facilities.indexWhere(
      (FacilityProfile entry) =>
          entry.id == facility.id || entry.mutationId == facility.mutationId,
    );
    if (index >= 0) {
      final List<FacilityProfile> next = List<FacilityProfile>.of(_facilities);
      next[index] = facility.copyWith(deletedAt: DateTime.now().toUtc());
      setState(() {
        _facilities = next;
      });
    }
    _syncPlatformDashboard(
      ref,
      patch: HomeDashboardOptimisticPatch.facilityDeleted(
        isActive: facility.isActive && !facility.isDeleted,
      ),
    );
    unawaited(_loadFacilities(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool canMutateTenant = _canManageTenant && !_tenant.isDeleted;
    final bool canDeleteTenant = _canDeleteTenant && !_tenant.isDeleted;
    final bool canMutateFacility = _canManageFacility && !_tenant.isDeleted;

    return AppDialog(
      title: Text(l10n.tenantFacilityTenantDetailsTitle),
      icon: const Icon(Icons.apartment_outlined),
      pinActionsToBottom: true,
      maxWidth: 1040,
      content: SizedBox(
        height: 560,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 720;
            final Widget tenantSummary = _TenantDetailsSummary(
              tenant: _tenant,
              statusLabel: _tenantStatusLabel(l10n),
              statusTone: _tenantStatusTone(),
            );
            final Widget facilitiesPanel = _TenantDetailsFacilitiesPanel(
              searchController: _searchController,
              loading: _loadingFacilities,
              failure: _facilitiesFailure,
              facilities: _facilities,
              pageRequest: _pageRequest,
              totalItemCount: _totalItemCount,
              canManage: canMutateFacility,
              statusLabelBuilder: (FacilityProfile facility) =>
                  _facilityStatusLabel(l10n, facility),
              onRetry: () => unawaited(_loadFacilities()),
              onPageChanged: _onPageChanged,
              onEdit: (FacilityProfile facility) =>
                  unawaited(_editFacility(facility)),
              onDelete: (FacilityProfile facility) =>
                  unawaited(_deleteFacility(facility)),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(width: 300, child: tenantSummary),
                  SizedBox(width: theme.spacing.md),
                  Expanded(child: facilitiesPanel),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                tenantSummary,
                SizedBox(height: theme.spacing.md),
                Expanded(child: facilitiesPanel),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        if (canMutateTenant)
          AppButton.secondary(
            label: l10n.tenantFacilityEditTenantAction,
            leadingIcon: Icons.edit_outlined,
            onPressed: () => unawaited(_editTenant()),
          ),
        if (canDeleteTenant)
          AppButton.primary(
            label: l10n.tenantFacilityDeleteTenantAction,
            leadingIcon: Icons.delete_outline,
            color: colorScheme.error,
            onPressed: () => unawaited(_deleteTenant()),
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

class _TenantDetailsSummary extends StatelessWidget {
  const _TenantDetailsSummary({
    required this.tenant,
    required this.statusLabel,
    required this.statusTone,
  });

  final TenantProfile tenant;
  final String statusLabel;
  final AppWorkspaceStatusTone statusTone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String slug = tenant.slug?.trim().isNotEmpty == true
        ? tenant.slug!
        : '—';
    final String? displayId = tenant.displayId?.trim().isNotEmpty == true
        ? tenant.displayId
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    tenant.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                _TenantStatusBadge(label: statusLabel, tone: statusTone),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            const Divider(height: 1),
            SizedBox(height: theme.spacing.md),
            _TenantMetaRow(
              label: l10n.tenantFacilityTenantSlugLabel,
              value: slug,
            ),
            if (displayId != null)
              _TenantMetaRow(
                label: l10n.tenantFacilityTenantDetailsIdLabel,
                value: displayId,
              ),
            _TenantMetaRow(
              label: l10n.tenantFacilityTenantStatusLabel,
              value: statusLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantStatusBadge extends StatelessWidget {
  const _TenantStatusBadge({required this.label, required this.tone});

  final String label;
  final AppWorkspaceStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color foreground = switch (tone) {
      AppWorkspaceStatusTone.success => colorScheme.primary,
      AppWorkspaceStatusTone.error => colorScheme.error,
      AppWorkspaceStatusTone.warning => colorScheme.tertiary,
      AppWorkspaceStatusTone.info => colorScheme.secondary,
      AppWorkspaceStatusTone.neutral => colorScheme.onSurfaceVariant,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: foreground.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TenantMetaRow extends StatelessWidget {
  const _TenantMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantDetailsFacilitiesPanel extends StatelessWidget {
  const _TenantDetailsFacilitiesPanel({
    required this.searchController,
    required this.loading,
    required this.failure,
    required this.facilities,
    required this.pageRequest,
    required this.totalItemCount,
    required this.canManage,
    required this.statusLabelBuilder,
    required this.onRetry,
    required this.onPageChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final TextEditingController searchController;
  final bool loading;
  final AppFailure? failure;
  final List<FacilityProfile> facilities;
  final AppPageRequest pageRequest;
  final int totalItemCount;
  final bool canManage;
  final String Function(FacilityProfile facility) statusLabelBuilder;
  final VoidCallback onRetry;
  final Future<void> Function(AppPageRequest request) onPageChanged;
  final ValueChanged<FacilityProfile> onEdit;
  final ValueChanged<FacilityProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.tenantFacilityTenantDetailsFacilitiesHeading,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            AppSearchBar(
              controller: searchController,
              hintText: l10n.tenantFacilitySearchLabel,
              semanticLabel: l10n.tenantFacilitySearchLabel,
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: failure != null
                  ? AppFailureStateView(failure: failure!, onRetry: onRetry)
                  : AppListTable<FacilityProfile>(
                      page: AppPage<FacilityProfile>(
                        items: facilities,
                        request: pageRequest,
                        totalItemCount: totalItemCount,
                      ),
                      isLoading: loading,
                      itemKeyBuilder: (FacilityProfile item) =>
                          ValueKey<String>(item.id),
                      previousPageLabel: l10n.hrPreviousPageLabel,
                      nextPageLabel: l10n.hrNextPageLabel,
                      pageLabelBuilder: (AppPage<FacilityProfile> page) {
                        if (loading) {
                          return '';
                        }
                        final int total =
                            page.totalItemCount ?? page.items.length;
                        if (total == 0) {
                          return l10n.commonTableEmptyLabel;
                        }
                        final int start = page.pageIndex * page.pageSize + 1;
                        final int end = start + page.items.length - 1;
                        return '$start-$end / $total';
                      },
                      onPageChanged: onPageChanged,
                      columns: <AppListTableColumn<FacilityProfile>>[
                        AppListTableColumn<FacilityProfile>(
                          label: l10n.authFacilityNameLabel,
                          cellBuilder: (_, FacilityProfile facility) => Text(
                            facility.name,
                            style: facility.isDeleted
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                        ),
                        AppListTableColumn<FacilityProfile>(
                          label: l10n.profileFacilityTypeLabel,
                          cellBuilder: (_, FacilityProfile facility) =>
                              Text(facility.type.name),
                        ),
                        AppListTableColumn<FacilityProfile>(
                          label: l10n.tenantFacilityTenantStatusLabel,
                          cellBuilder: (_, FacilityProfile facility) => Text(
                            statusLabelBuilder(facility),
                          ),
                        ),
                        if (canManage)
                          AppListTableColumn<FacilityProfile>(
                            label: '',
                            alwaysVisible: true,
                            cellBuilder:
                                (
                                  BuildContext context,
                                  FacilityProfile facility,
                                ) {
                                  if (facility.isDeleted) {
                                    return const SizedBox.shrink();
                                  }
                                  return _ManagementRowActions(
                                    enabled: !loading,
                                    editLabel:
                                        l10n.tenantFacilityEditFacilityAction,
                                    deleteLabel:
                                        l10n.tenantFacilityDeleteAction,
                                    onEdit: () => onEdit(facility),
                                    onDelete: () => onDelete(facility),
                                  );
                                },
                          ),
                      ],
                      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                        title:
                            l10n.tenantFacilityTenantDetailsFacilitiesHeading,
                        body: l10n.tenantFacilityTenantDetailsNoFacilities,
                      ),
                      mobileItemBuilder:
                          (BuildContext context, FacilityProfile facility) {
                            return ListTile(
                              title: Text(facility.name),
                              subtitle: Text(
                                '${facility.type.name} · ${statusLabelBuilder(facility)}',
                              ),
                              trailing: canManage && !facility.isDeleted
                                  ? _ManagementRowActions(
                                      enabled: !loading,
                                      editLabel: l10n
                                          .tenantFacilityEditFacilityAction,
                                      deleteLabel:
                                          l10n.tenantFacilityDeleteAction,
                                      onEdit: () => onEdit(facility),
                                      onDelete: () => onDelete(facility),
                                    )
                                  : Text(statusLabelBuilder(facility)),
                            );
                          },
                    ),
            ),
          ],
        ),
      ),
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

enum _FacilityDetailsPanel {
  users,
  branches,
  departments,
  units,
  wards,
  rooms,
  beds,
}

class _FacilityDetailsDialog extends ConsumerStatefulWidget {
  const _FacilityDetailsDialog({
    required this.facility,
    this.tenantName,
  });

  final FacilityProfile facility;
  final String? tenantName;

  @override
  ConsumerState<_FacilityDetailsDialog> createState() =>
      _FacilityDetailsDialogState();
}

class _FacilityDetailsDialogState extends ConsumerState<_FacilityDetailsDialog> {
  late FacilityProfile _facility;
  FacilitySetupSnapshot? _snapshot;
  final TextEditingController _usersSearchController = TextEditingController();
  Timer? _usersSearchDebounce;
  _FacilityDetailsPanel _selectedPanel = _FacilityDetailsPanel.users;
  bool _loadingOverview = true;
  bool _loadingUsers = true;
  AppFailure? _overviewFailure;
  AppFailure? _usersFailure;
  AppPageRequest _pageRequest = PlatformAdminListConfig.initialPageRequest;
  int _totalUserCount = 0;
  List<AccessAdminItem> _users = const <AccessAdminItem>[];
  bool _mutated = false;
  int _usersReloadGeneration = 0;
  int _overviewReloadGeneration = 0;
  bool _logoBusy = false;
  PlatformManagementListSync? _structureRealtimeSync;

  @override
  void initState() {
    super.initState();
    _facility = widget.facility;
    _usersSearchController.addListener(_onUsersSearchChanged);
    unawaited(_loadOverview());
    unawaited(_loadUsers());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _structureRealtimeSync ??= PlatformManagementListSync(
      ref: ref,
      events: <String>{
        RealtimeEvents.facilityLayoutUpdated,
        RealtimeEvents.userCreated,
        RealtimeEvents.userUpdated,
        RealtimeEvents.userDeleted,
        RealtimeEvents.userRestored,
      },
      onMutated: () => _mutated = true,
      reload: ({bool silent = false, RealtimeMessage? message}) async {
        await _loadOverview(silent: true);
        if (_selectedPanel == _FacilityDetailsPanel.users) {
          await _loadUsers(silent: true);
        }
      },
    )..attach();
  }

  @override
  void dispose() {
    _structureRealtimeSync?.dispose();
    _usersSearchDebounce?.cancel();
    _usersSearchController.dispose();
    super.dispose();
  }

  bool get _canManageFacility =>
      ref.read(appAccessPolicyProvider).canManageFacility();

  bool get _canEditStructure =>
      ref.read(appAccessPolicyProvider).canEditFacilitySetupStructure();

  bool get _canMutate => _canManageFacility && !_facility.isDeleted;

  bool get _canMutateStructure => _canEditStructure && !_facility.isDeleted;

  String get _tenantLabel {
    final String? fromWidget = widget.tenantName?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) {
      return fromWidget;
    }
    final String? fromSnapshot = _snapshot?.tenant?.name.trim();
    if (fromSnapshot != null && fromSnapshot.isNotEmpty) {
      return fromSnapshot;
    }
    return _facility.tenantId;
  }

  FacilitySetupSnapshot get _effectiveSnapshot {
    final FacilitySetupSnapshot base =
        _snapshot ?? FacilitySetupSnapshot(facility: _facility);
    final FacilityProfile facility = base.facility ?? _facility;
    final TenantProfile tenant =
        base.tenant ??
        TenantProfile(id: facility.tenantId, name: _tenantLabel);
    if (identical(base.facility, facility) && identical(base.tenant, tenant)) {
      return base;
    }
    return base.copyWith(tenant: tenant, facility: facility);
  }

  void _onUsersSearchChanged() {
    _usersSearchDebounce?.cancel();
    _usersSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_loadUsers(resetPage: true));
    });
  }

  void _selectPanel(_FacilityDetailsPanel panel) {
    if (_selectedPanel == panel) {
      return;
    }
    setState(() {
      _selectedPanel = panel;
    });
    if (panel == _FacilityDetailsPanel.users) {
      unawaited(_loadUsers(resetPage: true));
    }
  }

  Future<void> _loadOverview({bool silent = false}) async {
    final int generation = ++_overviewReloadGeneration;
    if (!silent) {
      setState(() {
        _loadingOverview = true;
        _overviewFailure = null;
      });
    }

    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );

    final Result<FacilityProfile> facilityResult = await repository.getFacility(
      _facility.mutationId,
    );
    if (!mounted || generation != _overviewReloadGeneration) {
      return;
    }

    facilityResult.when(
      success: (FacilityProfile facility) {
        _facility = facility;
      },
      failure: (_) {},
    );

    final Result<FacilitySetupSnapshot> setupResult = await repository
        .loadSetup(
          facilityId: _facility.mutationId,
          tenantId: _facility.tenantId,
          includeDeleted: true,
        );
    if (!mounted || generation != _overviewReloadGeneration) {
      return;
    }

    setupResult.when(
      success: (FacilitySetupSnapshot snapshot) {
        setState(() {
          _loadingOverview = false;
          _snapshot = snapshot;
          if (snapshot.facility != null) {
            _facility = snapshot.facility!;
          }
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loadingOverview = false;
          _overviewFailure = failure;
        });
      },
    );
  }

  Future<void> _loadUsers({
    bool silent = false,
    bool resetPage = false,
  }) async {
    if (resetPage) {
      _pageRequest = _pageRequest.first();
    }
    final int generation = ++_usersReloadGeneration;
    if (!silent) {
      setState(() {
        _loadingUsers = true;
        _usersFailure = null;
      });
    }

    final AccessAdminRepository repository = ref.read(
      accessAdminRepositoryProvider,
    );
    final Result<AccessAdminWorkspaceData> result = await repository
        .getWorkspace(
          AccessAdminWorkspaceQuery(
            tenantId: _facility.tenantId,
            facilityId: _facility.mutationId,
            search: _usersSearchController.text.trim(),
            pageRequest: _pageRequest,
            includeDeleted: true,
          ),
        );

    if (!mounted || generation != _usersReloadGeneration) {
      return;
    }

    result.when(
      success: (AccessAdminWorkspaceData data) {
        setState(() {
          _loadingUsers = false;
          _users = data.page.items;
          _totalUserCount = data.page.totalItemCount ?? data.page.items.length;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loadingUsers = false;
          _usersFailure = failure;
          if (!silent) {
            _users = const <AccessAdminItem>[];
          }
        });
      },
    );
  }

  Future<void> _onUsersPageChanged(AppPageRequest request) async {
    _pageRequest = request;
    await _loadUsers();
  }

  AccessAdminWorkspaceState _usersWorkspaceState() {
    final AccessAdminWorkspaceQuery query = AccessAdminWorkspaceQuery(
      tenantId: _facility.tenantId,
      facilityId: _facility.mutationId,
      search: _usersSearchController.text.trim(),
      pageRequest: _pageRequest,
      includeDeleted: true,
    );
    return AccessAdminWorkspaceState(
      data: AccessAdminWorkspaceData(
        items: _users,
        page: AppPage<AccessAdminItem>(
          items: _users,
          request: _pageRequest,
          totalItemCount: _totalUserCount,
        ),
        query: query,
      ),
      query: query,
    );
  }

  Future<void> _afterStructureMutation() async {
    _mutated = true;
    await _loadOverview(silent: true);
    if (_selectedPanel == _FacilityDetailsPanel.users && mounted) {
      await _loadUsers(silent: true);
    }
  }

  Future<void> _createUser() async {
    final bool? saved = await openAccessAdminCreateUserDialog(
      context,
      ref,
      _usersWorkspaceState(),
    );
    if (!mounted || saved != true) {
      return;
    }
    _mutated = true;
    await _loadUsers(resetPage: true, silent: true);
  }

  Future<void> _editUser(AccessAdminItem user) async {
    if (user.isDeleted) {
      return;
    }
    final AccessAdminRepository repository = ref.read(
      accessAdminRepositoryProvider,
    );
    final Result<AccessAdminUserDetail> detailResult = await repository
        .getUserDetail(
          user.id,
          tenantId: _facility.tenantId,
          facilityId: _facility.mutationId,
        );
    if (!mounted) {
      return;
    }
    final AccessAdminUserDetail? detail = detailResult.when(
      success: (AccessAdminUserDetail value) => value,
      failure: (_) => null,
    );
    if (detail == null) {
      return;
    }
    await openAccessAdminEditUserDialog(
      context,
      ref,
      _usersWorkspaceState(),
      user: detail.item,
      detail: detail,
    );
    if (!mounted) {
      return;
    }
    _mutated = true;
    await _loadUsers(silent: true);
  }

  Future<void> _deleteUser(AccessAdminItem user) async {
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
          final Result<void> result = await ref
              .read(accessAdminRepositoryProvider)
              .deleteUser(user.mutationId);
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
    await _loadUsers(resetPage: _users.length <= 1, silent: true);
  }

  Future<void> _restoreUser(AccessAdminItem user) async {
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
          final Result<void> result = await ref
              .read(accessAdminRepositoryProvider)
              .restoreUser(user.mutationId);
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
    await _loadUsers(silent: true);
  }

  Future<void> _openBranchForm({BranchProfile? branch}) async {
    if (branch != null && branch.isDeleted) {
      return;
    }
    await showTenantFacilityBranchFormDialog(
      context,
      _effectiveSnapshot,
      branch: branch,
    );
    if (!mounted) {
      return;
    }
    await _afterStructureMutation();
  }

  Future<void> _openDepartmentForm({DepartmentProfile? department}) async {
    if (department != null && department.isDeleted) {
      return;
    }
    await showTenantFacilityDepartmentFormDialog(
      context,
      _effectiveSnapshot,
      department: department,
    );
    if (!mounted) {
      return;
    }
    await _afterStructureMutation();
  }

  Future<void> _openUnitForm({UnitProfile? unit}) async {
    if (unit != null && unit.isDeleted) {
      return;
    }
    await showTenantFacilityUnitFormDialog(
      context,
      _effectiveSnapshot,
      unit: unit,
    );
    if (!mounted) {
      return;
    }
    await _afterStructureMutation();
  }

  Future<void> _openWardForm({WardProfile? ward}) async {
    if (ward != null && ward.isDeleted) {
      return;
    }
    await showTenantFacilityWardFormDialog(
      context,
      _effectiveSnapshot,
      ward: ward,
    );
    if (!mounted) {
      return;
    }
    await _afterStructureMutation();
  }

  Future<void> _openRoomForm({RoomProfile? room}) async {
    if (room != null && room.isDeleted) {
      return;
    }
    await showTenantFacilityRoomFormDialog(
      context,
      _effectiveSnapshot,
      room: room,
    );
    if (!mounted) {
      return;
    }
    await _afterStructureMutation();
  }

  Future<void> _openBedForm({BedProfile? bed}) async {
    if (bed != null && bed.isDeleted) {
      return;
    }
    await showTenantFacilityBedFormDialog(
      context,
      _effectiveSnapshot,
      bed: bed,
    );
    if (!mounted) {
      return;
    }
    await _afterStructureMutation();
  }

  Future<void> _confirmDeleteStructure({
    required String name,
    required Future<bool> Function() deleteAction,
  }) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
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
    if (!mounted || confirmed != true) {
      return;
    }
    await _afterStructureMutation();
  }

  Future<void> _confirmRestoreStructure({
    required String name,
    required Future<bool> Function() restoreAction,
  }) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
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
    if (!mounted || confirmed != true) {
      return;
    }
    await _afterStructureMutation();
  }

  String _facilityStatusLabel(AppLocalizations l10n) {
    if (_facility.isDeleted) {
      return l10n.tenantFacilityTenantStatusDeleted;
    }
    return _facility.isActive
        ? l10n.tenantFacilityTenantStatusActive
        : l10n.commonNoLabel;
  }

  AppWorkspaceStatusTone _facilityStatusTone() {
    if (_facility.isDeleted) {
      return AppWorkspaceStatusTone.error;
    }
    return _facility.isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral;
  }

  Future<void> _editFacility() async {
    final bool? saved = await showTenantFacilityFacilityFormDialog(
      context,
      tenantId: _facility.tenantId,
      facility: _facility,
      managementMode: true,
    );
    if (!mounted || saved != true) {
      return;
    }

    _mutated = true;
    await _loadOverview(silent: true);
    await _loadUsers(silent: true);
  }

  Future<void> _addOrChangeLogo() async {
    if (!_canMutate || _logoBusy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final AppImageUploadPendingItem? picked = await pickAppImageFile(
      l10n,
      context: context,
      typeGroupLabel: 'facility-logo',
      showCropAspectPresets: true,
      preferredFileName: buildFacilityLogoFileName(_facility.name),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _logoBusy = true;
    });
    final Result<String> result = await ref
        .read(tenantFacilityRepositoryProvider)
        .uploadFacilityLogo(
          facilityId: _facility.mutationId,
          bytes: picked.bytes,
          fileName: picked.fileName,
          mimeType: picked.mimeType,
        );
    if (!mounted) {
      return;
    }

    result.when(
      success: (String logoUrl) {
        setState(() {
          _logoBusy = false;
          _facility = _facility.copyWith(logoUrl: logoUrl);
          _mutated = true;
          if (_snapshot?.facility != null) {
            _snapshot = _snapshot!.copyWith(
              facility: _snapshot!.facility!.copyWith(logoUrl: logoUrl),
            );
          }
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.tenantFacilityDetailsLogoUpdatedMessage)),
          );
      },
      failure: (AppFailure failure) {
        setState(() {
          _logoBusy = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.failureMessage(failure))),
          );
      },
    );
  }

  Future<void> _removeLogo() async {
    if (!_canMutate || _logoBusy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityDetailsRemoveLogoTitle,
        body: l10n.tenantFacilityDetailsRemoveLogoBody(_facility.name),
        highlightedText: _facility.name,
        submitLabel: l10n.tenantFacilityDetailsRemoveLogoAction,
        destructive: true,
        icon: const Icon(Icons.hide_image_outlined),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(tenantFacilityRepositoryProvider)
              .deleteFacilityLogo(_facility.mutationId);
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

    setState(() {
      _facility = _facility.copyWith(clearLogoUrl: true);
      _mutated = true;
      if (_snapshot?.facility != null) {
        _snapshot = _snapshot!.copyWith(
          facility: _snapshot!.facility!.copyWith(clearLogoUrl: true),
        );
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.tenantFacilityDetailsLogoRemovedMessage)),
      );
  }

  Future<void> _deleteFacility() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityDeleteConfirmationTitle,
        body: l10n.tenantFacilityDeleteFacilityConfirmationBody(_facility.name),
        highlightedText: _facility.name,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(tenantFacilityRepositoryProvider)
              .deleteFacility(_facility.mutationId);
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

    if (!mounted || confirmed != true) {
      return;
    }

    _syncPlatformDashboard(
      ref,
      patch: HomeDashboardOptimisticPatch.facilityDeleted(
        isActive: _facility.isActive && !_facility.isDeleted,
      ),
    );
    Navigator.of(context).pop(true);
  }

  Widget _buildRightPanel(AppLocalizations l10n) {
    final FacilitySetupSnapshot snapshot = _effectiveSnapshot;
    final bool canMutateStructure = _canMutateStructure;

    switch (_selectedPanel) {
      case _FacilityDetailsPanel.users:
        return _FacilityDetailsUsersPanel(
          searchController: _usersSearchController,
          loading: _loadingUsers,
          failure: _usersFailure,
          users: _users,
          pageRequest: _pageRequest,
          totalItemCount: _totalUserCount,
          canManage: _canMutate,
          onRetry: () => unawaited(_loadUsers()),
          onPageChanged: _onUsersPageChanged,
          onAdd: () => unawaited(_createUser()),
          onEdit: (AccessAdminItem user) => unawaited(_editUser(user)),
          onDelete: (AccessAdminItem user) => unawaited(_deleteUser(user)),
          onRestore: (AccessAdminItem user) => unawaited(_restoreUser(user)),
        );
      case _FacilityDetailsPanel.branches:
        return _FacilityStructureCrudPanel<BranchProfile>(
          title: l10n.tenantFacilityBranchesSectionTitle,
          items: snapshot.branches,
          emptyLabel: l10n.tenantFacilityNoBranches,
          addLabel: l10n.tenantFacilityAddBranchAction,
          canManage: canMutateStructure,
          titleBuilder: (BranchProfile item) => item.name,
          subtitleBuilder: (BranchProfile item) => '',
          isDeletedBuilder: (BranchProfile item) => item.isDeleted,
          statusBuilder: (BranchProfile item) => item.isDeleted
              ? l10n.tenantFacilityStructureDeletedStatus
              : l10n.tenantFacilityStructureActiveStatus,
          onAdd: () => unawaited(_openBranchForm()),
          onEdit: (BranchProfile item) =>
              unawaited(_openBranchForm(branch: item)),
          onDelete: (BranchProfile item) => unawaited(
            _confirmDeleteStructure(
              name: item.name,
              deleteAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .deleteBranch(item.id),
            ),
          ),
          onRestore: (BranchProfile item) => unawaited(
            _confirmRestoreStructure(
              name: item.name,
              restoreAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .restoreBranch(item.id),
            ),
          ),
        );
      case _FacilityDetailsPanel.departments:
        return _FacilityStructureCrudPanel<DepartmentProfile>(
          title: l10n.tenantFacilityDepartmentsListTitle,
          items: snapshot.departments,
          emptyLabel: l10n.tenantFacilityNoDepartments,
          addLabel: l10n.tenantFacilityAddDepartmentAction,
          canManage: canMutateStructure,
          titleBuilder: (DepartmentProfile item) => item.name,
          subtitleBuilder: (DepartmentProfile item) => item.type.name,
          isDeletedBuilder: (DepartmentProfile item) => item.isDeleted,
          statusBuilder: (DepartmentProfile item) => item.isDeleted
              ? l10n.tenantFacilityStructureDeletedStatus
              : l10n.tenantFacilityStructureActiveStatus,
          onAdd: () => unawaited(_openDepartmentForm()),
          onEdit: (DepartmentProfile item) =>
              unawaited(_openDepartmentForm(department: item)),
          onDelete: (DepartmentProfile item) => unawaited(
            _confirmDeleteStructure(
              name: item.name,
              deleteAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .deleteDepartment(item.id),
            ),
          ),
          onRestore: (DepartmentProfile item) => unawaited(
            _confirmRestoreStructure(
              name: item.name,
              restoreAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .restoreDepartment(item.id),
            ),
          ),
        );
      case _FacilityDetailsPanel.units:
        return _FacilityStructureCrudPanel<UnitProfile>(
          title: l10n.tenantFacilityUnitsListTitle,
          items: snapshot.units,
          emptyLabel: l10n.tenantFacilityNoUnits,
          addLabel: l10n.tenantFacilityAddUnitAction,
          canManage: canMutateStructure,
          canAdd: canMutateStructure && snapshot.departments.isNotEmpty,
          blockedMessage: canMutateStructure && snapshot.departments.isEmpty
              ? l10n.tenantFacilityGateNeedDepartmentForUnits
              : null,
          titleBuilder: (UnitProfile item) => item.name,
          subtitleBuilder: (UnitProfile item) => '',
          isDeletedBuilder: (UnitProfile item) => item.isDeleted,
          statusBuilder: (UnitProfile item) => item.isDeleted
              ? l10n.tenantFacilityStructureDeletedStatus
              : l10n.tenantFacilityStructureActiveStatus,
          onAdd: () => unawaited(_openUnitForm()),
          onEdit: (UnitProfile item) => unawaited(_openUnitForm(unit: item)),
          onDelete: (UnitProfile item) => unawaited(
            _confirmDeleteStructure(
              name: item.name,
              deleteAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .deleteUnit(item.id),
            ),
          ),
          onRestore: (UnitProfile item) => unawaited(
            _confirmRestoreStructure(
              name: item.name,
              restoreAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .restoreUnit(item.id),
            ),
          ),
        );
      case _FacilityDetailsPanel.wards:
        return _FacilityStructureCrudPanel<WardProfile>(
          title: l10n.tenantFacilityWardsLabel,
          items: snapshot.wards,
          emptyLabel: l10n.tenantFacilityNoWards,
          addLabel: l10n.tenantFacilityAddWardAction,
          canManage: canMutateStructure && _canManageFacility,
          titleBuilder: (WardProfile item) => item.name,
          subtitleBuilder: (WardProfile item) => item.type.name,
          isDeletedBuilder: (WardProfile item) => item.isDeleted,
          statusBuilder: (WardProfile item) => item.isDeleted
              ? l10n.tenantFacilityStructureDeletedStatus
              : l10n.tenantFacilityStructureActiveStatus,
          onAdd: () => unawaited(_openWardForm()),
          onEdit: (WardProfile item) => unawaited(_openWardForm(ward: item)),
          onDelete: (WardProfile item) => unawaited(
            _confirmDeleteStructure(
              name: item.name,
              deleteAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .deleteWard(item.id),
            ),
          ),
          onRestore: (WardProfile item) => unawaited(
            _confirmRestoreStructure(
              name: item.name,
              restoreAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .restoreWard(item.id),
            ),
          ),
        );
      case _FacilityDetailsPanel.rooms:
        return _FacilityStructureCrudPanel<RoomProfile>(
          title: l10n.tenantFacilityRoomsLabel,
          items: snapshot.rooms,
          emptyLabel: l10n.tenantFacilityNoRooms,
          addLabel: l10n.tenantFacilityAddRoomAction,
          canManage: canMutateStructure && _canManageFacility,
          titleBuilder: (RoomProfile item) => item.name,
          subtitleBuilder: (RoomProfile item) =>
              item.floor?.trim().isNotEmpty == true ? item.floor! : '—',
          isDeletedBuilder: (RoomProfile item) => item.isDeleted,
          statusBuilder: (RoomProfile item) => item.isDeleted
              ? l10n.tenantFacilityStructureDeletedStatus
              : l10n.tenantFacilityStructureActiveStatus,
          onAdd: () => unawaited(_openRoomForm()),
          onEdit: (RoomProfile item) => unawaited(_openRoomForm(room: item)),
          onDelete: (RoomProfile item) => unawaited(
            _confirmDeleteStructure(
              name: item.name,
              deleteAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .deleteRoom(item.id),
            ),
          ),
          onRestore: (RoomProfile item) => unawaited(
            _confirmRestoreStructure(
              name: item.name,
              restoreAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .restoreRoom(item.id),
            ),
          ),
        );
      case _FacilityDetailsPanel.beds:
        return _FacilityStructureCrudPanel<BedProfile>(
          title: l10n.tenantFacilityBedsLabel,
          items: snapshot.beds,
          emptyLabel: l10n.tenantFacilityNoBeds,
          addLabel: l10n.tenantFacilityAddBedAction,
          canManage: canMutateStructure && _canManageFacility,
          canAdd: (canMutateStructure && _canManageFacility) &&
              snapshot.wards.isNotEmpty,
          blockedMessage:
              (canMutateStructure && _canManageFacility) &&
                  snapshot.wards.isEmpty
              ? l10n.tenantFacilityGateNeedWardsForBeds
              : null,
          titleBuilder: (BedProfile item) => item.label,
          subtitleBuilder: (BedProfile item) => item.status.name,
          isDeletedBuilder: (BedProfile item) => item.isDeleted,
          statusBuilder: (BedProfile item) => item.isDeleted
              ? l10n.tenantFacilityStructureDeletedStatus
              : l10n.tenantFacilityStructureActiveStatus,
          onAdd: () => unawaited(_openBedForm()),
          onEdit: (BedProfile item) => unawaited(_openBedForm(bed: item)),
          onDelete: (BedProfile item) => unawaited(
            _confirmDeleteStructure(
              name: item.label,
              deleteAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .deleteBed(item.id),
            ),
          ),
          onRestore: (BedProfile item) => unawaited(
            _confirmRestoreStructure(
              name: item.label,
              restoreAction: () => ref
                  .read(tenantFacilitySetupSubmissionProvider.notifier)
                  .restoreBed(item.id),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool canMutate = _canMutate;

    return AppDialog(
      title: Text(l10n.tenantFacilityFacilityDetailsTitle),
      icon: const Icon(Icons.domain_outlined),
      pinActionsToBottom: true,
      maxWidth: 1040,
      content: SizedBox(
        height: 560,
        child: _overviewFailure != null && _snapshot == null
            ? AppFailureStateView(
                failure: _overviewFailure!,
                onRetry: () => unawaited(_loadOverview()),
              )
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth >= 720;
                  final Widget summary = _FacilityDetailsSummary(
                    facility: _facility,
                    tenantLabel: _tenantLabel,
                    statusLabel: _facilityStatusLabel(l10n),
                    statusTone: _facilityStatusTone(),
                    snapshot: _snapshot,
                    userCount: _users
                        .where((AccessAdminItem user) => !user.isDeleted)
                        .length,
                    loading: _loadingOverview,
                    selectedPanel: _selectedPanel,
                    onPanelSelected: _selectPanel,
                    canManageLogo: canMutate,
                    logoBusy: _logoBusy,
                    onAddOrChangeLogo: () => unawaited(_addOrChangeLogo()),
                    onRemoveLogo: () => unawaited(_removeLogo()),
                  );
                  final Widget rightPanel = _buildRightPanel(l10n);

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          width: 320,
                          child: SingleChildScrollView(child: summary),
                        ),
                        SizedBox(width: theme.spacing.md),
                        Expanded(child: rightPanel),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      summary,
                      SizedBox(height: theme.spacing.md),
                      Expanded(child: rightPanel),
                    ],
                  );
                },
              ),
      ),
      actions: <Widget>[
        if (canMutate) ...<Widget>[
          AppButton.secondary(
            label: l10n.tenantFacilityEditFacilityDetailsAction,
            leadingIcon: Icons.edit_outlined,
            onPressed: () => unawaited(_editFacility()),
          ),
          AppButton.primary(
            label: l10n.tenantFacilityDeleteFacilityDetailsAction,
            leadingIcon: Icons.delete_outline,
            color: colorScheme.error,
            onPressed: () => unawaited(_deleteFacility()),
          ),
        ],
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(_mutated ? true : null),
        ),
      ],
    );
  }
}

class _FacilityDetailsSummary extends StatelessWidget {
  const _FacilityDetailsSummary({
    required this.facility,
    required this.tenantLabel,
    required this.statusLabel,
    required this.statusTone,
    required this.snapshot,
    required this.userCount,
    required this.loading,
    required this.selectedPanel,
    required this.onPanelSelected,
    this.canManageLogo = false,
    this.logoBusy = false,
    this.onAddOrChangeLogo,
    this.onRemoveLogo,
  });

  final FacilityProfile facility;
  final String tenantLabel;
  final String statusLabel;
  final AppWorkspaceStatusTone statusTone;
  final FacilitySetupSnapshot? snapshot;
  final int userCount;
  final bool loading;
  final _FacilityDetailsPanel selectedPanel;
  final ValueChanged<_FacilityDetailsPanel> onPanelSelected;
  final bool canManageLogo;
  final bool logoBusy;
  final VoidCallback? onAddOrChangeLogo;
  final VoidCallback? onRemoveLogo;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? displayId = facility.displayId?.trim().isNotEmpty == true
        ? facility.displayId
        : null;
    final bool hasLogo =
        facility.logoUrl != null && facility.logoUrl!.trim().isNotEmpty;
    final FacilityContactAddress contact =
        snapshot?.contactAddress ?? const FacilityContactAddress();
    final String? phone = contact.phone?.trim();
    final String? email = contact.email?.trim();
    final String address = <String?>[
      contact.addressLine1,
      contact.city,
      contact.country,
    ]
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join(', ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _FacilityLogoAvatar(logoUrl: facility.logoUrl),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        facility.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: theme.spacing.xs),
                      _TenantStatusBadge(
                        label: statusLabel,
                        tone: statusTone,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canManageLogo) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              if (logoBusy)
                const LinearProgressIndicator(minHeight: 2)
              else
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    AppButton.secondary(
                      label: hasLogo
                          ? l10n.tenantFacilityDetailsChangeLogoAction
                          : l10n.tenantFacilityDetailsAddLogoAction,
                      leadingIcon: hasLogo
                          ? Icons.sync_outlined
                          : Icons.add_photo_alternate_outlined,
                      onPressed: onAddOrChangeLogo,
                    ),
                    if (hasLogo)
                      AppButton.secondary(
                        label: l10n.tenantFacilityDetailsRemoveLogoAction,
                        leadingIcon: Icons.hide_image_outlined,
                        color: colorScheme.error,
                        onPressed: onRemoveLogo,
                      ),
                  ],
                ),
            ],
            SizedBox(height: theme.spacing.md),
            const Divider(height: 1),
            SizedBox(height: theme.spacing.md),
            _TenantMetaRow(
              label: l10n.profileTenantLabel,
              value: tenantLabel,
            ),
            _TenantMetaRow(
              label: l10n.profileFacilityTypeLabel,
              value: facility.type.name,
            ),
            if (displayId != null)
              _TenantMetaRow(
                label: l10n.tenantFacilityTenantDetailsIdLabel,
                value: displayId,
              ),
            _TenantMetaRow(
              label: l10n.tenantFacilityTenantStatusLabel,
              value: statusLabel,
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              l10n.tenantFacilityFacilityDetailsStructureHeading,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            if (loading && snapshot == null)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  _FacilityMetricChip(
                    label: l10n.tenantFacilityFacilityDetailsUsersHeading,
                    value: userCount,
                    selected: selectedPanel == _FacilityDetailsPanel.users,
                    onTap: () => onPanelSelected(_FacilityDetailsPanel.users),
                  ),
                  _FacilityMetricChip(
                    label: l10n.tenantFacilityBranchesSectionTitle,
                    value: snapshot?.branches
                            .where((BranchProfile item) => !item.isDeleted)
                            .length ??
                        0,
                    selected: selectedPanel == _FacilityDetailsPanel.branches,
                    onTap: () =>
                        onPanelSelected(_FacilityDetailsPanel.branches),
                  ),
                  _FacilityMetricChip(
                    label: l10n.tenantFacilityDepartmentsListTitle,
                    value: snapshot?.departments
                            .where((DepartmentProfile item) => !item.isDeleted)
                            .length ??
                        0,
                    selected:
                        selectedPanel == _FacilityDetailsPanel.departments,
                    onTap: () =>
                        onPanelSelected(_FacilityDetailsPanel.departments),
                  ),
                  _FacilityMetricChip(
                    label: l10n.tenantFacilityUnitsListTitle,
                    value: snapshot?.units
                            .where((UnitProfile item) => !item.isDeleted)
                            .length ??
                        0,
                    selected: selectedPanel == _FacilityDetailsPanel.units,
                    onTap: () => onPanelSelected(_FacilityDetailsPanel.units),
                  ),
                  _FacilityMetricChip(
                    label: l10n.tenantFacilityWardsLabel,
                    value: snapshot?.wards
                            .where((WardProfile item) => !item.isDeleted)
                            .length ??
                        0,
                    selected: selectedPanel == _FacilityDetailsPanel.wards,
                    onTap: () => onPanelSelected(_FacilityDetailsPanel.wards),
                  ),
                  _FacilityMetricChip(
                    label: l10n.tenantFacilityRoomsLabel,
                    value: snapshot?.rooms
                            .where((RoomProfile item) => !item.isDeleted)
                            .length ??
                        0,
                    selected: selectedPanel == _FacilityDetailsPanel.rooms,
                    onTap: () => onPanelSelected(_FacilityDetailsPanel.rooms),
                  ),
                  _FacilityMetricChip(
                    label: l10n.tenantFacilityBedsLabel,
                    value: snapshot?.beds
                            .where((BedProfile item) => !item.isDeleted)
                            .length ??
                        0,
                    selected: selectedPanel == _FacilityDetailsPanel.beds,
                    onTap: () => onPanelSelected(_FacilityDetailsPanel.beds),
                  ),
                ],
              ),
            if (phone != null ||
                email != null ||
                address.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              Text(
                l10n.tenantFacilityFacilityDetailsContactHeading,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              if (phone != null && phone.isNotEmpty)
                _TenantMetaRow(
                  label: l10n.profilePhoneLabel,
                  value: phone,
                ),
              if (email != null && email.isNotEmpty)
                _TenantMetaRow(
                  label: l10n.profileEmailLabel,
                  value: email,
                ),
              if (address.isNotEmpty)
                _TenantMetaRow(
                  label: l10n.tenantFacilityAddressLineLabel,
                  value: address,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FacilityLogoAvatar extends ConsumerWidget {
  const _FacilityLogoAvatar({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? url = resolveAppMediaUrl(
      logoUrl,
      ref.watch(appConfigProvider).apiBaseUrl,
    );
    final bool hasLogo = url != null && url.isNotEmpty;

    return Semantics(
      label: hasLogo
          ? null
          : context.l10n.tenantFacilityFacilityDetailsNoLogo,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 88,
            height: 88,
            child: hasLogo
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.network(
                      url,
                      key: ValueKey<String>(url),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) => Icon(
                            Icons.domain_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : Icon(
                    Icons.domain_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );
  }
}

class _FacilityMetricChip extends StatelessWidget {
  const _FacilityMetricChip({
    required this.label,
    required this.value,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color borderColor = selected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final Color background = selected
        ? colorScheme.primary.withValues(alpha: 0.10)
        : colorScheme.surface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$value',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? colorScheme.primary : null,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FacilityStructureCrudPanel<T> extends StatefulWidget {
  const _FacilityStructureCrudPanel({
    required this.title,
    required this.items,
    required this.emptyLabel,
    required this.addLabel,
    required this.canManage,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.isDeletedBuilder,
    required this.statusBuilder,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
    this.canAdd,
    this.blockedMessage,
  });

  final String title;
  final List<T> items;
  final String emptyLabel;
  final String addLabel;
  final bool canManage;
  final bool? canAdd;
  final String? blockedMessage;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final bool Function(T item) isDeletedBuilder;
  final String Function(T item) statusBuilder;
  final VoidCallback onAdd;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;
  final ValueChanged<T> onRestore;

  @override
  State<_FacilityStructureCrudPanel<T>> createState() =>
      _FacilityStructureCrudPanelState<T>();
}

class _FacilityStructureCrudPanelState<T>
    extends State<_FacilityStructureCrudPanel<T>> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String query = _searchController.text.trim().toLowerCase();
    final List<T> filtered = query.isEmpty
        ? widget.items
        : widget.items
              .where((T item) {
                final String title = widget.titleBuilder(item).toLowerCase();
                final String subtitle =
                    widget.subtitleBuilder(item).toLowerCase();
                final String status = widget.statusBuilder(item).toLowerCase();
                return title.contains(query) ||
                    subtitle.contains(query) ||
                    status.contains(query);
              })
              .toList(growable: false);
    final bool canAdd = widget.canAdd ?? widget.canManage;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
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
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.canManage)
                  AppButton.tertiary(
                    leadingIcon: Icons.add,
                    label: widget.addLabel,
                    semanticLabel: widget.addLabel,
                    tooltip: widget.blockedMessage ?? widget.addLabel,
                    enabled: canAdd,
                    onPressed: canAdd ? widget.onAdd : null,
                  ),
              ],
            ),
            if (widget.blockedMessage != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                widget.blockedMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.sm),
            AppSearchBar(
              controller: _searchController,
              hintText: l10n.tenantFacilitySearchLabel,
              semanticLabel: l10n.tenantFacilitySearchLabel,
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: filtered.isEmpty
                  ? AppWorkspaceStatePanel.empty(
                      title: widget.title,
                      body: widget.items.isEmpty
                          ? widget.emptyLabel
                          : l10n.tenantFacilitySearchNoResults,
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final T item = filtered[index];
                        final bool deleted = widget.isDeletedBuilder(item);
                        final String subtitle = widget.subtitleBuilder(item);
                        final TextStyle? mutedStyle = deleted
                            ? theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              )
                            : null;
                        final AppWorkspaceStatusTone statusTone = deleted
                            ? AppWorkspaceStatusTone.error
                            : AppWorkspaceStatusTone.success;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            widget.titleBuilder(item),
                            style: mutedStyle?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (subtitle.trim().isNotEmpty)
                                Text(subtitle, style: mutedStyle),
                              SizedBox(height: theme.spacing.xs),
                              _TenantStatusBadge(
                                label: widget.statusBuilder(item),
                                tone: statusTone,
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: widget.canManage
                              ? (deleted
                                    ? AppButton.tertiary(
                                        leadingIcon: Icons.restore_outlined,
                                        label: l10n
                                            .tenantFacilityRestoreStructureAction,
                                        semanticLabel: l10n
                                            .tenantFacilityRestoreStructureAction,
                                        tooltip: l10n
                                            .tenantFacilityRestoreStructureAction,
                                        onPressed: () =>
                                            widget.onRestore(item),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          AppButton.tertiary(
                                            leadingIcon: Icons.edit_outlined,
                                            label: l10n
                                                .tenantFacilityEditFacilityAction,
                                            semanticLabel: l10n
                                                .tenantFacilityEditFacilityAction,
                                            tooltip: l10n
                                                .tenantFacilityEditFacilityAction,
                                            onPressed: () =>
                                                widget.onEdit(item),
                                          ),
                                          AppButton.tertiary(
                                            leadingIcon: Icons.delete_outline,
                                            label: l10n
                                                .tenantFacilityDeleteAction,
                                            semanticLabel: l10n
                                                .tenantFacilityDeleteAction,
                                            tooltip: l10n
                                                .tenantFacilityDeleteAction,
                                            color: colorScheme.error,
                                            onPressed: () =>
                                                widget.onDelete(item),
                                          ),
                                        ],
                                      ))
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilityDetailsUsersPanel extends StatelessWidget {
  const _FacilityDetailsUsersPanel({
    required this.searchController,
    required this.loading,
    required this.failure,
    required this.users,
    required this.pageRequest,
    required this.totalItemCount,
    required this.canManage,
    required this.onRetry,
    required this.onPageChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final TextEditingController searchController;
  final bool loading;
  final AppFailure? failure;
  final List<AccessAdminItem> users;
  final AppPageRequest pageRequest;
  final int totalItemCount;
  final bool canManage;
  final VoidCallback onRetry;
  final Future<void> Function(AppPageRequest request) onPageChanged;
  final VoidCallback onAdd;
  final ValueChanged<AccessAdminItem> onEdit;
  final ValueChanged<AccessAdminItem> onDelete;
  final ValueChanged<AccessAdminItem> onRestore;

  String _userStatusLabel(AppLocalizations l10n, AccessAdminItem user) {
    if (user.isDeleted) {
      return l10n.tenantFacilityStructureDeletedStatus;
    }
    if (user.status?.trim().isNotEmpty == true) {
      return user.status!;
    }
    return user.isActive
        ? l10n.tenantFacilityTenantStatusActive
        : l10n.commonNoLabel;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
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
                    l10n.tenantFacilityFacilityDetailsUsersHeading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (canManage)
                  AppButton.tertiary(
                    leadingIcon: Icons.person_add_outlined,
                    label: l10n.accessAdminCreateUserAction,
                    semanticLabel: l10n.accessAdminCreateUserAction,
                    tooltip: l10n.accessAdminCreateUserAction,
                    onPressed: onAdd,
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            AppSearchBar(
              controller: searchController,
              hintText: l10n.tenantFacilitySearchLabel,
              semanticLabel: l10n.tenantFacilitySearchLabel,
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: failure != null
                  ? AppFailureStateView(failure: failure!, onRetry: onRetry)
                  : AppListTable<AccessAdminItem>(
                      page: AppPage<AccessAdminItem>(
                        items: users,
                        request: pageRequest,
                        totalItemCount: totalItemCount,
                      ),
                      isLoading: loading,
                      itemKeyBuilder: (AccessAdminItem item) =>
                          ValueKey<String>(item.id),
                      previousPageLabel: l10n.hrPreviousPageLabel,
                      nextPageLabel: l10n.hrNextPageLabel,
                      pageLabelBuilder: (AppPage<AccessAdminItem> page) {
                        if (loading) {
                          return '';
                        }
                        final int total =
                            page.totalItemCount ?? page.items.length;
                        if (total == 0) {
                          return l10n.commonTableEmptyLabel;
                        }
                        final int start = page.pageIndex * page.pageSize + 1;
                        final int end = start + page.items.length - 1;
                        return '$start-$end / $total';
                      },
                      onPageChanged: onPageChanged,
                      columns: <AppListTableColumn<AccessAdminItem>>[
                        AppListTableColumn<AccessAdminItem>(
                          label: l10n.accessAdminCreateUserDetailsSectionTitle,
                          cellBuilder: (_, AccessAdminItem user) => Text(
                            user.title,
                            style: user.isDeleted
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                        ),
                        AppListTableColumn<AccessAdminItem>(
                          label: l10n.profileEmailLabel,
                          cellBuilder: (_, AccessAdminItem user) => Text(
                            user.email ?? user.subtitle ?? '—',
                            style: user.isDeleted
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                        ),
                        AppListTableColumn<AccessAdminItem>(
                          label: l10n.tenantFacilityTenantStatusLabel,
                          cellBuilder: (_, AccessAdminItem user) => Text(
                            _userStatusLabel(l10n, user),
                            style: user.isDeleted
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                        ),
                        if (canManage)
                          AppListTableColumn<AccessAdminItem>(
                            label: '',
                            alwaysVisible: true,
                            cellBuilder:
                                (BuildContext context, AccessAdminItem user) {
                                  if (user.isDeleted) {
                                    return AppButton.tertiary(
                                      leadingIcon: Icons.restore_outlined,
                                      label: l10n.accessAdminRestoreUserAction,
                                      semanticLabel:
                                          l10n.accessAdminRestoreUserAction,
                                      tooltip:
                                          l10n.accessAdminRestoreUserAction,
                                      onPressed: () => onRestore(user),
                                    );
                                  }
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      AppButton.tertiary(
                                        leadingIcon: Icons.edit_outlined,
                                        label: l10n.accessAdminEditUserAction,
                                        semanticLabel:
                                            l10n.accessAdminEditUserAction,
                                        tooltip: l10n.accessAdminEditUserAction,
                                        onPressed: () => onEdit(user),
                                      ),
                                      AppButton.tertiary(
                                        leadingIcon: Icons.delete_outline,
                                        label: l10n.accessAdminDeleteUserAction,
                                        semanticLabel:
                                            l10n.accessAdminDeleteUserAction,
                                        tooltip:
                                            l10n.accessAdminDeleteUserAction,
                                        color: colorScheme.error,
                                        enabled: !user.isDemo &&
                                            !user.isSystemCritical,
                                        onPressed: user.isDemo ||
                                                user.isSystemCritical
                                            ? null
                                            : () => onDelete(user),
                                      ),
                                    ],
                                  );
                                },
                          ),
                      ],
                      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                        title: l10n.tenantFacilityFacilityDetailsUsersHeading,
                        body: l10n.tenantFacilityFacilityDetailsNoUsers,
                      ),
                      mobileItemBuilder:
                          (BuildContext context, AccessAdminItem user) {
                            final TextStyle? mutedStyle = user.isDeleted
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                : null;
                            return ListTile(
                              title: Text(user.title, style: mutedStyle),
                              subtitle: Text(
                                '${user.email ?? user.subtitle ?? '—'} · ${_userStatusLabel(l10n, user)}',
                                style: mutedStyle,
                              ),
                              trailing: canManage
                                  ? (user.isDeleted
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.restore_outlined,
                                            ),
                                            tooltip: l10n
                                                .accessAdminRestoreUserAction,
                                            onPressed: () => onRestore(user),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                                onPressed: () => onEdit(user),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  color: colorScheme.error,
                                                ),
                                                onPressed: user.isDemo ||
                                                        user.isSystemCritical
                                                    ? null
                                                    : () => onDelete(user),
                                              ),
                                            ],
                                          ))
                                  : Text(
                                      _userStatusLabel(l10n, user),
                                      style: mutedStyle,
                                    ),
                            );
                          },
                    ),
            ),
          ],
        ),
      ),
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
          includeDeleted: true,
        );

    if (!mounted || generation != _reloadGeneration) return;
    result.when(
      success: (AppPage<FacilityProfile> page) {
        final int activeCount = page.items
            .where(
              (FacilityProfile facility) =>
                  !facility.isDeleted && facility.isActive,
            )
            .length;
        final int totalItemCount = page.totalItemCount ?? page.items.length;
        final int visibleTotalCount = page.items
            .where((FacilityProfile facility) => !facility.isDeleted)
            .length;
        homeReconcileFacilitiesMetricFromList(
          ref,
          activeCount,
          totalCount: page.items.length == totalItemCount
              ? visibleTotalCount
              : totalItemCount,
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

  Future<void> _openFacilityDetails(FacilityProfile facility) async {
    final bool? mutated = await showFacilityDetailsDialog(
      context,
      facility: facility,
      tenantName: _tenantLabel(facility.tenantId),
    );
    if (!mounted || mutated != true) {
      return;
    }

    _mutated = true;
    await _loadTenants();
    await _reload(resetPage: false, silent: true);
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
      _markFacilitySoftDeletedLocally(facility);
      _syncPlatformDashboard(
        ref,
        patch: HomeDashboardOptimisticPatch.facilityDeleted(
          isActive: facility.isActive && !facility.isDeleted,
        ),
      );
      await _loadTenants();
      await _reload(resetPage: false, silent: true);
    }
  }

  Future<void> _confirmRestoreFacility(FacilityProfile facility) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityRestoreFacilityConfirmationTitle,
        body: l10n.tenantFacilityRestoreFacilityConfirmationBody(facility.name),
        highlightedText: facility.name,
        submitLabel: l10n.tenantFacilityRestoreTenantAction,
        icon: const Icon(Icons.restore_outlined),
        onConfirm: () async {
          final Result<FacilityProfile> result = await ref
              .read(tenantFacilityRepositoryProvider)
              .restoreFacility(facility.mutationId);
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
    _markFacilityRestoredLocally(facility);
    _syncPlatformDashboard(
      ref,
      patch: HomeDashboardOptimisticPatch.facilityCreated(
        isActive: facility.isActive,
      ),
    );
    await _loadTenants();
    await _reload(resetPage: false, silent: true);
  }

  Future<void> _confirmPermanentDeleteFacility(FacilityProfile facility) async {
    final AppLocalizations l10n = context.l10n;
    final String? typed = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AppTextInputActionDialog(
        title: l10n.tenantFacilityPermanentDeleteFacilityConfirmationTitle,
        description: l10n.tenantFacilityPermanentDeleteFacilityWarningBody(
          facility.name,
        ),
        fieldLabel: l10n.tenantFacilityPermanentDeleteConfirmFieldLabel(
          facility.name,
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
    if (typed.trim() != facility.name.trim()) {
      return;
    }

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityPermanentDeleteFacilityConfirmationTitle,
        body: l10n.tenantFacilityPermanentDeleteFacilityConfirmationBody(
          facility.name,
        ),
        highlightedText: facility.name,
        submitLabel: l10n.tenantFacilityPermanentDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_forever_outlined),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(tenantFacilityRepositoryProvider)
              .permanentDeleteFacility(facility.mutationId);
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

    if (!mounted || confirmed != true) {
      return;
    }

    _mutated = true;
    _removeFacilityLocally(facility.mutationId);
    _syncPlatformDashboard(ref);
    await _loadTenants();
    await _reload(resetPage: false, silent: true);
  }

  void _markFacilitySoftDeletedLocally(FacilityProfile facility) {
    final int index = _facilities.indexWhere(
      (FacilityProfile entry) =>
          entry.id == facility.id || entry.mutationId == facility.mutationId,
    );
    if (index < 0) {
      return;
    }
    final List<FacilityProfile> next = List<FacilityProfile>.of(_facilities);
    next[index] = facility.copyWith(deletedAt: DateTime.now().toUtc());
    setState(() {
      _facilities = next;
    });
  }

  void _markFacilityRestoredLocally(FacilityProfile facility) {
    final int index = _facilities.indexWhere(
      (FacilityProfile entry) =>
          entry.id == facility.id || entry.mutationId == facility.mutationId,
    );
    if (index < 0) {
      return;
    }
    final List<FacilityProfile> next = List<FacilityProfile>.of(_facilities);
    next[index] = facility.copyWith(clearDeletedAt: true);
    setState(() {
      _facilities = next;
    });
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

    final String? facilityId = _managementResourceIdFromMessage(
      message,
      keys: const <String>['resource_id', 'facility_id', 'id'],
    );

    switch (message.event) {
      case RealtimeEvents.facilityDeleted:
        if (facilityId == null) {
          return;
        }
        final int index = _facilities.indexWhere(
          (FacilityProfile entry) =>
              entry.id == facilityId || entry.mutationId == facilityId,
        );
        if (index < 0) {
          return;
        }
        final List<FacilityProfile> next = List<FacilityProfile>.of(_facilities);
        next[index] = next[index].copyWith(deletedAt: DateTime.now().toUtc());
        setState(() {
          _facilities = next;
        });
        return;
      case RealtimeEvents.facilityPermanentlyDeleted:
        if (facilityId != null) {
          _removeFacilityLocally(facilityId);
        }
        return;
      case RealtimeEvents.facilityRestored:
      case RealtimeEvents.facilityCreated:
      case RealtimeEvents.facilityUpdated:
        return;
    }
  }

  String _facilityStatusLabel(AppLocalizations l10n, FacilityProfile facility) {
    if (facility.isDeleted) {
      return l10n.tenantFacilityTenantStatusDeleted;
    }
    return facility.isActive
        ? l10n.tenantFacilityTenantStatusActive
        : l10n.commonNoLabel;
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
                      onRowSelected: (FacilityProfile facility) {
                        if (facility.isDeleted) {
                          return;
                        }
                        unawaited(_openFacilityDetails(facility));
                      },
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
                          label: l10n.tenantFacilityTenantStatusLabel,
                          cellBuilder: (_, FacilityProfile facility) => Text(
                            _facilityStatusLabel(l10n, facility),
                            style: facility.isDeleted
                                ? Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      )
                                : null,
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
                                  return GestureDetector(
                                    onTap: () {},
                                    child: _FacilityManagementRowActions(
                                      enabled: !_loading,
                                      facility: facility,
                                      editLabel:
                                          l10n.tenantFacilityEditFacilityAction,
                                      deleteLabel:
                                          l10n.tenantFacilityDeleteAction,
                                      restoreLabel:
                                          l10n.tenantFacilityRestoreTenantAction,
                                      permanentDeleteLabel: l10n
                                          .tenantFacilityPermanentDeleteAction,
                                      onEdit: () => unawaited(
                                        _openFacilityForm(facility: facility),
                                      ),
                                      onDelete: () => unawaited(
                                        _confirmDeleteFacility(facility),
                                      ),
                                      onRestore: () => unawaited(
                                        _confirmRestoreFacility(facility),
                                      ),
                                      onPermanentDelete: () => unawaited(
                                        _confirmPermanentDeleteFacility(
                                          facility,
                                        ),
                                      ),
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
                              title: Text(
                                facility.name,
                                style: facility.isDeleted
                                    ? Theme.of(context).textTheme.titleMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          )
                                    : null,
                              ),
                              subtitle: Text(
                                '${_tenantLabel(facility.tenantId)} · ${_facilityStatusLabel(l10n, facility)}',
                              ),
                              trailing: _canManage
                                  ? _FacilityManagementRowActions(
                                      enabled: !_loading,
                                      facility: facility,
                                      editLabel: l10n
                                          .tenantFacilityEditFacilityAction,
                                      deleteLabel:
                                          l10n.tenantFacilityDeleteAction,
                                      restoreLabel: l10n
                                          .tenantFacilityRestoreTenantAction,
                                      permanentDeleteLabel: l10n
                                          .tenantFacilityPermanentDeleteAction,
                                      onEdit: () => unawaited(
                                        _openFacilityForm(facility: facility),
                                      ),
                                      onDelete: () => unawaited(
                                        _confirmDeleteFacility(facility),
                                      ),
                                      onRestore: () => unawaited(
                                        _confirmRestoreFacility(facility),
                                      ),
                                      onPermanentDelete: () => unawaited(
                                        _confirmPermanentDeleteFacility(
                                          facility,
                                        ),
                                      ),
                                    )
                                  : Text(_facilityStatusLabel(l10n, facility)),
                              onTap: !facility.isDeleted
                                  ? () => unawaited(
                                      _openFacilityDetails(facility),
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
    required this.canDelete,
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
  final bool canDelete;
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
      if (!canDelete) {
        return const SizedBox.shrink();
      }
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
        if (canDelete)
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

class _FacilityManagementRowActions extends StatelessWidget {
  const _FacilityManagementRowActions({
    required this.enabled,
    required this.facility,
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
  final FacilityProfile facility;
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

    if (facility.isDeleted) {
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

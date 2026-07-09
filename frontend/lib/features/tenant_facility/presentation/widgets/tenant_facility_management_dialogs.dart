import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showManageTenantsDialog(BuildContext context, WidgetRef ref) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => const _ManageTenantsDialog(),
  );
}

Future<void> showManageFacilitiesDialog(BuildContext context, WidgetRef ref) {
  return showAppDialog<void>(
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
  static const int _pageSize = 12;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loading = true;
  AppFailure? _failure;
  AppPageRequest _pageRequest = const AppPageRequest(pageSize: _pageSize);
  int _totalItemCount = 0;
  List<TenantProfile> _tenants = const <TenantProfile>[];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_reload(resetPage: true));
  }

  @override
  void dispose() {
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

  Future<void> _reload({required bool resetPage}) async {
    if (resetPage) {
      _pageRequest = _pageRequest.first();
    }
    setState(() {
      _loading = true;
      _failure = null;
    });

    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final Result<AppPage<TenantProfile>> result = await repository.listTenants(
      request: _pageRequest,
      search: _searchController.text.trim(),
    );

    if (!mounted) return;
    result.when(
      success: (AppPage<TenantProfile> page) {
        setState(() {
          _loading = false;
          _tenants = page.items;
          _totalItemCount = page.totalItemCount ?? page.items.length;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loading = false;
          _failure = failure;
          _tenants = const <TenantProfile>[];
        });
      },
    );
  }

  Future<void> _onPageChanged(AppPageRequest request) async {
    _pageRequest = request;
    await _reload(resetPage: false);
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
                      onRowSelected: (TenantProfile tenant) async {
                        await showTenantFacilityTenantFormDialog(
                          context,
                          tenant: tenant,
                        );
                        if (context.mounted) {
                          unawaited(_reload(resetPage: false));
                        }
                      },
                      previousPageLabel: l10n.hrPreviousPageLabel,
                      nextPageLabel: l10n.hrNextPageLabel,
                      pageLabelBuilder: (AppPage<TenantProfile> page) {
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
                          cellBuilder: (_, TenantProfile tenant) =>
                              Text(tenant.name),
                        ),
                        AppListTableColumn<TenantProfile>(
                          label: l10n.tenantFacilityTenantSlugLabel,
                          cellBuilder: (_, TenantProfile tenant) =>
                              Text(tenant.slug ?? '—'),
                        ),
                        AppListTableColumn<TenantProfile>(
                          label: l10n.tenantFacilityActiveLabel,
                          cellBuilder: (_, TenantProfile tenant) => Text(
                            tenant.isActive
                                ? l10n.commonYesLabel
                                : l10n.commonNoLabel,
                          ),
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
                              subtitle: Text(tenant.slug ?? tenant.id),
                              trailing: Text(
                                tenant.isActive
                                    ? l10n.commonYesLabel
                                    : l10n.commonNoLabel,
                              ),
                            );
                          },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          onPressed: _loading
              ? null
              : () => unawaited(_reload(resetPage: false)),
        ),
        if (_canCreate)
          AppButton.primary(
            label: l10n.tenantFacilityAddTenantAction,
            leadingIcon: Icons.add_business_outlined,
            onPressed: () async {
              await showTenantFacilityTenantFormDialog(
                context,
                forceCreate: true,
              );
              if (context.mounted) {
                unawaited(_reload(resetPage: true));
              }
            },
          ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
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
  static const int _pageSize = 12;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loading = true;
  AppFailure? _failure;
  AppPageRequest _pageRequest = const AppPageRequest(pageSize: _pageSize);
  int _totalItemCount = 0;
  List<FacilityProfile> _facilities = const <FacilityProfile>[];
  List<TenantProfile> _tenantOptions = const <TenantProfile>[];
  String? _tenantFilterId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadTenants());
    unawaited(_reload(resetPage: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTenants() async {
    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final Result<AppPage<TenantProfile>> result = await repository.listTenants(
      request: const AppPageRequest(pageSize: 100),
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

  Future<void> _reload({required bool resetPage}) async {
    if (resetPage) {
      _pageRequest = _pageRequest.first();
    }
    setState(() {
      _loading = true;
      _failure = null;
    });

    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final Result<AppPage<FacilityProfile>> result = await repository
        .listFacilities(
          request: _pageRequest,
          tenantId: _tenantFilterId,
          search: _searchController.text.trim(),
        );

    if (!mounted) return;
    result.when(
      success: (AppPage<FacilityProfile> page) {
        setState(() {
          _loading = false;
          _facilities = page.items;
          _totalItemCount = page.totalItemCount ?? page.items.length;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loading = false;
          _failure = failure;
          _facilities = const <FacilityProfile>[];
        });
      },
    );
  }

  Future<void> _onPageChanged(AppPageRequest request) async {
    _pageRequest = request;
    await _reload(resetPage: false);
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
                      onRowSelected: (FacilityProfile facility) async {
                        await showTenantFacilityFacilityFormDialog(
                          context,
                          tenantId: facility.tenantId,
                          facility: facility,
                        );
                        if (context.mounted) {
                          unawaited(_reload(resetPage: false));
                        }
                      },
                      previousPageLabel: l10n.hrPreviousPageLabel,
                      nextPageLabel: l10n.hrNextPageLabel,
                      pageLabelBuilder: (AppPage<FacilityProfile> page) {
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
                              trailing: Text(
                                facility.isActive
                                    ? l10n.commonYesLabel
                                    : l10n.commonNoLabel,
                              ),
                            );
                          },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          onPressed: _loading
              ? null
              : () => unawaited(_reload(resetPage: false)),
        ),
        if (_canManage)
          AppButton.primary(
            label: l10n.tenantFacilityAddFacilityAction,
            leadingIcon: Icons.add_business_outlined,
            onPressed: () async {
              await showTenantFacilityFacilityFormDialog(
                context,
                requireTenantPicker: true,
                tenantId: _tenantFilterId,
              );
              if (context.mounted) {
                unawaited(_reload(resetPage: true));
              }
            },
          ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

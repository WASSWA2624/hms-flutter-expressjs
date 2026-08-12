import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/tenant_facility_setup_access.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/management/platform_admin_list_config.dart';
import 'package:hosspi_hms/shared/management/platform_management_list_sync.dart';

/// Platform setup tab: pending subscription payments awaiting activation.
class ManageSubscriptionActivationsPanel extends ConsumerStatefulWidget {
  const ManageSubscriptionActivationsPanel({
    super.key,
    this.onListTotalChanged,
  });

  final ValueChanged<int>? onListTotalChanged;

  @override
  ConsumerState<ManageSubscriptionActivationsPanel> createState() =>
      _ManageSubscriptionActivationsPanelState();
}

class _ManageSubscriptionActivationsPanelState
    extends ConsumerState<ManageSubscriptionActivationsPanel> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  PlatformManagementListSync? _realtimeSync;

  bool _loading = true;
  bool _loadingMore = false;
  bool _mutating = false;
  AppFailure? _failure;
  AppPageRequest _pageRequest = PlatformAdminListConfig.initialPageRequest;
  int _totalItemCount = 0;
  List<AccessAdminItem> _items = const <AccessAdminItem>[];

  AccessAdminRepository get _repository =>
      ref.read(accessAdminRepositoryProvider);

  AccessAdminWorkspaceQuery get _listQuery => AccessAdminWorkspaceQuery(
    panel: AccessAdminPanel.payments,
    resource: AccessAdminResource.subscriptionPaymentRequests,
    search: _searchController.text.trim(),
    pageRequest: _pageRequest,
    allTenants: true,
    allFacilities: true,
  );

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
      events: RealtimeEventGroups.platformAdmin,
      onMutated: () {},
      reload: ({bool silent = false, RealtimeMessage? message}) async {
        await _reload(resetPage: false, silent: silent);
      },
    )..attach();
  }

  @override
  void dispose() {
    _realtimeSync?.dispose();
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_reload(resetPage: true, silent: _items.isNotEmpty));
    });
  }

  Future<void> _reload({
    required bool resetPage,
    bool silent = false,
  }) async {
    if (resetPage) {
      _pageRequest = _pageRequest.first();
    }
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _failure = null;
      });
    }

    final Result<AccessAdminWorkspaceData> result = await _repository
        .getWorkspace(_listQuery);

    if (!mounted) {
      return;
    }
    result.when(
      success: (AccessAdminWorkspaceData data) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _failure = null;
          _items = data.page.items;
          _totalItemCount = data.page.totalItemCount ?? data.page.items.length;
        });
        widget.onListTotalChanged?.call(_totalItemCount);
      },
      failure: (AppFailure loadFailure) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _failure = loadFailure;
          if (!silent) {
            _items = const <AccessAdminItem>[];
          }
        });
      },
    );
  }

  Future<void> _onPageChanged(AppPageRequest request) async {
    final AppPageRequest previous = _pageRequest;
    _pageRequest = request;
    final bool silent = _items.isNotEmpty;
    if (silent && mounted) {
      setState(() {
        _loadingMore = true;
        _failure = null;
      });
    }
    await _reload(resetPage: false, silent: silent);
    if (!mounted) {
      return;
    }
    if (_failure != null && silent) {
      setState(() {
        _pageRequest = previous;
        _loadingMore = false;
      });
    }
  }

  Future<void> _activate(AccessAdminItem item) async {
    if (_mutating) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final String subject = item.title.isEmpty
        ? (item.planLabel ?? item.effectiveDisplayId)
        : item.title;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.tenantFacilitySubscriptionActivationsActivateTitle,
        body: l10n.tenantFacilitySubscriptionActivationsActivateBody(subject),
        submitLabel: l10n.tenantFacilitySubscriptionActivationsActivateAction,
        submitLeadingIcon: Icons.check_circle_outline,
        onConfirm: () async => null,
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _mutating = true);
    final Result<void> result = await _repository.activatePaymentRequest(
      item.mutationId,
    );
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) {
        setState(() => _mutating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.tenantFacilitySubscriptionActivationsActivateSuccess,
            ),
          ),
        );
        unawaited(_reload(resetPage: false, silent: true));
      },
      failure: (AppFailure failure) {
        setState(() {
          _mutating = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _reject(AccessAdminItem item) async {
    if (_mutating) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final String subject = item.title.isEmpty
        ? (item.planLabel ?? item.effectiveDisplayId)
        : item.title;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.tenantFacilitySubscriptionActivationsRejectTitle,
        body: l10n.tenantFacilitySubscriptionActivationsRejectBody(subject),
        submitLabel: l10n.tenantFacilitySubscriptionActivationsRejectAction,
        submitLeadingIcon: Icons.cancel_outlined,
        destructive: true,
        noteFieldLabel: l10n.tenantFacilitySubscriptionActivationsRejectReasonLabel,
        noteIsRequired: true,
        noteMaxLines: 4,
        onConfirmWithNote: (String reason) async {
          final Result<void> result = await _repository.rejectPaymentRequest(
            item.mutationId,
            reason,
          );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.tenantFacilitySubscriptionActivationsRejectSuccess),
      ),
    );
    unawaited(_reload(resetPage: false, silent: true));
  }

  AppPage<AccessAdminItem> get _currentPage => AppPage<AccessAdminItem>(
    items: _items,
    request: _pageRequest,
    totalItemCount: _totalItemCount,
  );

  List<AppListTableColumn<AccessAdminItem>> _columns(AppLocalizations l10n) {
    return <AppListTableColumn<AccessAdminItem>>[
      AppListTableColumn<AccessAdminItem>(
        id: 'tenant',
        label: l10n.tenantFacilitySubscriptionActivationsTenantColumn,
        sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
            appListTableCompareText(left.title, right.title),
        exportValue: (AccessAdminItem item) =>
            item.title.isEmpty ? '—' : item.title,
        cellBuilder: (_, AccessAdminItem item) => tenantFacilitySetupAtomicCell(
          item.title.isEmpty ? '—' : item.title,
        ),
      ),
      AppListTableColumn<AccessAdminItem>(
        id: 'plan',
        label: l10n.tenantFacilitySubscriptionActivationsPlanColumn,
        sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
            appListTableCompareText(left.planLabel, right.planLabel),
        exportValue: (AccessAdminItem item) => item.planLabel ?? '—',
        cellBuilder: (_, AccessAdminItem item) =>
            tenantFacilitySetupAtomicCell(item.planLabel ?? '—'),
      ),
      AppListTableColumn<AccessAdminItem>(
        id: 'amount',
        label: l10n.tenantFacilitySubscriptionActivationsAmountColumn,
        sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
            appListTableCompareText(left.positionTitle, right.positionTitle),
        exportValue: (AccessAdminItem item) => item.positionTitle ?? '—',
        cellBuilder: (_, AccessAdminItem item) =>
            tenantFacilitySetupAtomicCell(item.positionTitle ?? '—'),
      ),
      AppListTableColumn<AccessAdminItem>(
        id: 'email',
        label: l10n.accessAdminEmailLabel,
        sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
            appListTableCompareText(left.email, right.email),
        exportValue: (AccessAdminItem item) => item.email ?? '—',
        cellBuilder: (_, AccessAdminItem item) =>
            tenantFacilitySetupAtomicCell(item.email ?? '—'),
      ),
      AppListTableColumn<AccessAdminItem>(
        id: 'actions',
        label: l10n.tenantFacilitySubscriptionApprovalsActionsColumn,
        alwaysVisible: true,
        exportable: false,
        cellBuilder: (BuildContext context, AccessAdminItem item) {
          return Wrap(
            spacing: Theme.of(context).spacing.xs,
            runSpacing: Theme.of(context).spacing.xs,
            children: <Widget>[
              AppButton.tertiary(
                label: l10n.tenantFacilitySubscriptionActivationsActivateAction,
                leadingIcon: Icons.check_circle_outline,
                onPressed: _mutating ? null : () => unawaited(_activate(item)),
              ),
              AppButton.tertiary(
                label: l10n.tenantFacilitySubscriptionActivationsRejectAction,
                leadingIcon: Icons.cancel_outlined,
                onPressed: _mutating ? null : () => unawaited(_reject(item)),
              ),
            ],
          );
        },
      ),
    ];
  }

  List<AppListTableColumn<AccessAdminItem>> _optionalColumns(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<AccessAdminItem>>[
      AppListTableColumn<AccessAdminItem>(
        id: 'phone',
        label: l10n.accessAdminPhoneLabel,
        exportValue: (AccessAdminItem item) => item.phone ?? '—',
        cellBuilder: (_, AccessAdminItem item) =>
            tenantFacilitySetupAtomicCell(item.phone ?? '—'),
      ),
      AppListTableColumn<AccessAdminItem>(
        id: 'status',
        label: l10n.accessAdminColumnStatus,
        exportValue: (AccessAdminItem item) => item.status ?? '—',
        cellBuilder: (_, AccessAdminItem item) =>
            tenantFacilitySetupAtomicCell(item.status ?? '—'),
      ),
      AppListTableColumn<AccessAdminItem>(
        id: 'id',
        label: l10n.accessAdminColumnId,
        exportValue: (AccessAdminItem item) => item.effectiveDisplayId,
        cellBuilder: (_, AccessAdminItem item) =>
            tenantFacilitySetupAtomicCell(item.effectiveDisplayId),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.tenantFacilitySubscriptionActivationsIntro,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.md),
        if (_failure != null) ...<Widget>[
          AppFormInformationBanner.failure(
            context: context,
            failure: _failure!,
            onRetry: () => unawaited(_reload(resetPage: true)),
          ),
          SizedBox(height: theme.spacing.md),
        ],
        Expanded(
          child: AppListTable<AccessAdminItem>(
            page: _currentPage,
            isLoading: _loading || _loadingMore,
            onPageChanged: _onPageChanged,
            previousPageLabel: l10n.hrPreviousPageLabel,
            nextPageLabel: l10n.hrNextPageLabel,
            pageLabelBuilder: (AppPage<AccessAdminItem> page) {
              if (_loading) {
                return '';
              }
              final int total = page.totalItemCount ?? page.items.length;
              if (total == 0) {
                return l10n.commonTableEmptyLabel;
              }
              final int start = page.pageIndex * page.pageSize + 1;
              final int end = start + page.items.length - 1;
              return '$start-$end / $total';
            },
            emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
              title: l10n.tenantFacilitySubscriptionActivationsEmptyTitle,
              body: l10n.tenantFacilitySubscriptionActivationsEmpty,
            ),
            columns: _columns(l10n),
            columnChoices: _optionalColumns(l10n),
            columnVisibilityStorageKey:
                'setup_subscription_activations_columns_v2',
            columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
            columnVisibilityTitle: l10n.commonTableSettingsTitle,
            columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
            columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
            columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
            canExport: canExportTenantFacilitySetup(
              ref.watch(appAccessPolicyProvider),
            ),
            exportLabel: l10n.commonTableExportActionLabel,
            exportDialogTitle: l10n.commonTableExportDialogTitle,
            exportCancelLabel: l10n.commonCancelActionLabel,
            exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
            exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
            exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
            exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
            exportSuccessMessage: l10n.commonTableExportSuccessMessage,
            exportFailureMessage: l10n.commonTableExportFailureMessage,
            exportInvalidDateMessage: l10n.opdInvalidDateMessage,
            enablePrint: true,
            canPrint: canPrintTenantFacilitySetup(
              ref.watch(appAccessPolicyProvider),
            ),
            printLabel: l10n.commonPrintActionLabel,
            onPrint: (List<AccessAdminItem> matching) =>
                printTenantFacilitySetupListTable<AccessAdminItem>(
              ref: ref,
              context: context,
              title: l10n.tenantFacilitySetupTabSubscriptionActivations,
              columns: <AppListTableColumn<AccessAdminItem>>[
                ..._columns(l10n),
                ..._optionalColumns(l10n),
              ],
              items: matching,
              emptyText: l10n.tenantFacilitySubscriptionActivationsEmpty,
            ),
            goToTopLabel: l10n.commonGoToTopActionLabel,
            loadingMoreLabel: l10n.commonLoadingMoreLabel,
            allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
            exportConfig: AppListTableExportConfig<AccessAdminItem>(
              fileNameStem: 'setup_subscription_activations',
              dateOf: (_) => null,
              sheetName: l10n.tenantFacilitySetupTabSubscriptionActivations,
              enableDateFilter: false,
              dateFromLabel: l10n.commonTableExportDateFromLabel,
              dateToLabel: l10n.commonTableExportDateToLabel,
            ),
            search: AppListTableSearch<AccessAdminItem>(
              controller: _searchController,
              semanticLabel:
                  l10n.tenantFacilitySubscriptionActivationsSearchHint,
              hintText: l10n.tenantFacilitySubscriptionActivationsSearchHint,
              matcher: (_, _) => true,
              onSubmitted: (_) => unawaited(_reload(resetPage: true)),
              onClear: () => unawaited(_reload(resetPage: true)),
              enableDateFilter: false,
            ),
            mobileItemBuilder: (BuildContext context, AccessAdminItem item) {
              return AppListTableMobileItem(
                title: item.title.isEmpty
                    ? (item.planLabel ?? item.effectiveDisplayId)
                    : item.title,
                caption: item.planLabel ?? item.subtitle ?? '—',
                meta: <AppListTableMobileMeta>[
                  if ((item.positionTitle ?? '').isNotEmpty)
                    AppListTableMobileMeta(
                      label: item.positionTitle!,
                      icon: Icons.payments_outlined,
                    ),
                  if ((item.email ?? '').isNotEmpty)
                    AppListTableMobileMeta(
                      label: item.email!,
                      icon: Icons.email_outlined,
                    ),
                ],
                trailing: Wrap(
                  spacing: theme.spacing.xs,
                  children: <Widget>[
                    AppButton.tertiary(
                      label: l10n
                          .tenantFacilitySubscriptionActivationsActivateAction,
                      onPressed: _mutating
                          ? null
                          : () => unawaited(_activate(item)),
                    ),
                    AppButton.tertiary(
                      label:
                          l10n.tenantFacilitySubscriptionActivationsRejectAction,
                      onPressed: _mutating
                          ? null
                          : () => unawaited(_reject(item)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

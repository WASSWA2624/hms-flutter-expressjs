import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_price_book_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_price_book_print_helpers.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_dialogs.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Price book CRUD table embedded in the Billing workspace (`?section=prices`).
class BillingPriceBookPanel extends ConsumerStatefulWidget {
  const BillingPriceBookPanel({super.key});

  @override
  ConsumerState<BillingPriceBookPanel> createState() =>
      _BillingPriceBookPanelState();
}

class _BillingPriceBookPanelState extends ConsumerState<BillingPriceBookPanel> {
  static const String _statusFilterKey = 'is_active';
  static const String _catalogFilterKey = 'catalog_type';
  static const String _modeFilterKey = 'payment_mode';
  static const String _schemeFilterKey = 'coverage_plan_id';
  static const String _effectiveFilterKey = 'effective';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<BillingPriceBookEntry>
  _columnController =
      AppListTableColumnVisibilityController<BillingPriceBookEntry>(
        storageKey: 'billing_prices_v1',
      );

  AppPage<BillingPriceBookEntry> _page = const AppPage<BillingPriceBookEntry>(
    items: <BillingPriceBookEntry>[],
    request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    totalItemCount: 0,
  );
  bool _loading = true;
  AppFailure? _failure;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();
  Timer? _searchDebounce;

  String? get _tenantId =>
      ref.read(sessionStateProvider).session?.user?.tenantId;
  String? get _facilityId =>
      ref.read(sessionStateProvider).session?.user?.facilityId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _columnController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_reload());
    });
  }

  bool get _hasActiveFilters {
    return (_filterValue.option(_statusFilterKey) ?? '').isNotEmpty ||
        (_filterValue.option(_catalogFilterKey) ?? '').isNotEmpty ||
        (_filterValue.option(_modeFilterKey) ?? '').isNotEmpty ||
        (_filterValue.text(_schemeFilterKey) ?? '').trim().isNotEmpty ||
        (_filterValue.option(_effectiveFilterKey) ?? '').isNotEmpty ||
        _searchController.text.trim().isNotEmpty;
  }

  Future<void> _reload() async {
    final String? tenantId = _tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() {
        _loading = false;
        _failure = AppFailure.validation();
      });
      return;
    }

    setState(() {
      _loading = true;
      _failure = null;
    });

    final String? activeFilter = _filterValue.option(_statusFilterKey);
    final bool? isActive = activeFilter == null || activeFilter.isEmpty
        ? null
        : activeFilter == 'true';

    final Result<AppPage<BillingPriceBookEntry>> result = await ref
        .read(billingPriceBookRepositoryProvider)
        .listEntries(
          BillingPriceBookQuery(
            search: _searchController.text.trim(),
            catalogType: _filterValue.option(_catalogFilterKey) ?? '',
            paymentMode: _filterValue.option(_modeFilterKey) ?? '',
            coveragePlanId: (_filterValue.text(_schemeFilterKey) ?? '').trim(),
            isActive: isActive,
          ),
          tenantId: tenantId,
          facilityId: _facilityId,
        );

    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<BillingPriceBookEntry> page) {
        final List<BillingPriceBookEntry> filtered = _applyEffectiveFilter(
          page.items,
        );
        setState(() {
          _page = AppPage<BillingPriceBookEntry>(
            items: filtered,
            request: page.request,
            totalItemCount: filtered.length,
          );
          _loading = false;
        });
        // Sibling-style: unfiltered badge = active catalog count; when
        // search/filters narrow this tab, badge = filtered total (tabs.mdc).
        ref
                .read<StateController<int?>>(
                  billingPriceBookActiveCountProvider.notifier,
                )
                .state =
            billingPriceBookTabCount(
              hasActiveFilters: _hasActiveFilters,
              filteredLength: filtered.length,
              pageItemLength: page.items.length,
              pageTotalItemCount: page.totalItemCount,
              activeOnPage: page.items
                  .where((BillingPriceBookEntry e) => e.isActive)
                  .length,
            );
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
        });
      },
    );
  }

  List<BillingPriceBookEntry> _applyEffectiveFilter(
    List<BillingPriceBookEntry> items,
  ) {
    final String? effective = _filterValue.option(_effectiveFilterKey);
    if (effective == null || effective.isEmpty) {
      return items;
    }
    final DateTime now = DateTime.now().toUtc();
    return items.where((BillingPriceBookEntry item) {
      final DateTime? from = item.effectiveFrom?.toUtc();
      final DateTime? to = item.effectiveTo?.toUtc();
      final bool isCurrent =
          (from == null || !from.isAfter(now)) &&
          (to == null || !to.isBefore(now));
      return effective == 'current' ? isCurrent : !isCurrent;
    }).toList(growable: false);
  }

  Future<void> _openCreateOrEdit({BillingPriceBookEntry? editing}) async {
    BillingPriceBookEntry? current = editing;
    while (mounted) {
      final BillingPriceBookDialogResult result =
          await showBillingPriceBookEntryDialog(
            context: context,
            ref: ref,
            editing: current,
          );
      if (!context.mounted) {
        return;
      }
      switch (result.outcome) {
        case BillingPriceBookDialogOutcome.cancelled:
          return;
        case BillingPriceBookDialogOutcome.saved:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.billingActionSaved)),
          );
          await _reload();
          return;
        case BillingPriceBookDialogOutcome.openExisting:
          current = result.existing;
          if (current == null) {
            return;
          }
      }
    }
  }

  Future<void> _printList(List<BillingPriceBookEntry> items) async {
    await printBillingPriceBookList(
      ref: ref,
      context: context,
      entries: items,
    );
  }

  Future<void> _deactivate(BillingPriceBookEntry entry) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.billingPriceBookDeactivateTitle,
        body: l10n.billingPriceBookDeactivateBody(
          billingPriceBookItemDisplayLabel(l10n, entry),
        ),
        highlightedText: billingPriceBookItemDisplayLabel(l10n, entry),
        submitLabel: l10n.billingPriceBookDeactivateAction,
        destructive: true,
        icon: const Icon(Icons.pause_circle_outline),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(billingPriceBookRepositoryProvider)
              .deactivateEntry(entry.id);
          return result.when(
            success: (_) {
              ref
                  .read<StateController<int>>(
                    billingPriceBookRevisionProvider.notifier,
                  )
                  .state++;
              return null;
            },
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.billingActionSaved)),
      );
      await _reload();
    }
  }

  Widget _actionsCell(BuildContext context, BillingPriceBookEntry item) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.spacing.md,
        runSpacing: theme.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          AppButton.tertiary(
            leadingIcon: Icons.edit_outlined,
            label: l10n.commonEditActionLabel,
            tooltip: l10n.commonEditActionLabel,
            dense: true,
            onPressed: () => unawaited(_openCreateOrEdit(editing: item)),
          ),
          if (item.isActive)
            AppButton.tertiary(
              leadingIcon: Icons.pause_circle_outline,
              label: l10n.billingPriceBookDeactivateAction,
              tooltip: l10n.billingPriceBookDeactivateAction,
              dense: true,
              color: colors.error,
              onPressed: () => unawaited(_deactivate(item)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteBillingPriceBook(accessPolicy);
    final bool canExport = canExportBillingWorkspace(accessPolicy);
    final bool canPrint = canPrintBillingWorkspace(accessPolicy);

    return AppListTable<BillingPriceBookEntry>(
      page: _page,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      shrinkWrap: false,
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: 'billing_prices_v1',
      columnWidthStorageKey: 'billing_prices_cw_v1',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
      enableExport: true,
      canExport: canExport,
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
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: (List<BillingPriceBookEntry> items) => _printList(items),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<BillingPriceBookEntry>(
        fileNameStem: 'billing_price_book',
        dateOf: (BillingPriceBookEntry item) => item.effectiveFrom,
        sheetName: l10n.billingPriceBookTab,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      onRowSelected: canWrite
          ? (BillingPriceBookEntry item) =>
                unawaited(_openCreateOrEdit(editing: item))
          : null,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.billingPriceBookEmptyTitle,
        body: l10n.billingPriceBookEmptyBody,
      ),
      search: AppListTableSearch<BillingPriceBookEntry>(
        controller: _searchController,
        semanticLabel: l10n.billingPriceBookSearchHint,
        hintText: l10n.billingPriceBookSearchHint,
        clearLabel: l10n.billingClearSearch,
        matcher: (BillingPriceBookEntry item, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          return billingPriceBookItemDisplayLabel(l10n, item)
                  .toLowerCase()
                  .contains(needle) ||
              billingPriceBookSchemeDisplayLabel(l10n, item)
                  .toLowerCase()
                  .contains(needle) ||
              item.paymentMode.toLowerCase().contains(needle) ||
              (billingPublicLabel(item.displayId)?.toLowerCase().contains(
                    needle,
                  ) ??
                  false);
        },
        onSubmitted: (_) => unawaited(_reload()),
        onClear: () {
          _searchController.clear();
          setState(() => _filterValue = const AppSearchBarFilterValue());
          unawaited(_reload());
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        advancedFilterCloseLabel: l10n.commonCloseActionLabel,
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _schemeFilterKey,
            label: l10n.billingPriceBookSchemeLabel,
            hintText: l10n.billingPriceBookSchemeLabel,
            icon: Icons.health_and_safety_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.billingPriceBookStatusLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'true',
                label: l10n.billingPriceBookStatusActive,
                icon: Icons.check_circle_outline,
              ),
              AppSearchBarFilterChoice(
                value: 'false',
                label: l10n.billingPriceBookStatusInactive,
                icon: Icons.pause_circle_outline,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _catalogFilterKey,
            label: l10n.billingPriceBookCatalogLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'SERVICE',
                label: l10n.billingPriceBookCatalogService,
              ),
              AppSearchBarFilterChoice(
                value: 'CONSULTATION',
                label: l10n.billingPriceBookCatalogConsultation,
              ),
              AppSearchBarFilterChoice(
                value: 'LAB_TEST',
                label: l10n.billingPriceBookCatalogLabTest,
              ),
              AppSearchBarFilterChoice(
                value: 'LAB_PANEL',
                label: l10n.billingPriceBookCatalogLabPanel,
              ),
              AppSearchBarFilterChoice(
                value: 'RADIOLOGY_TEST',
                label: l10n.billingPriceBookCatalogRadiology,
              ),
              AppSearchBarFilterChoice(
                value: 'DRUG',
                label: l10n.billingPriceBookCatalogDrug,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _modeFilterKey,
            label: l10n.billingPriceBookModeLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'SELF_PAY',
                label: l10n.billingPriceBookModeSelfPay,
              ),
              AppSearchBarFilterChoice(
                value: 'INSURANCE',
                label: l10n.billingPriceBookModeInsurance,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _effectiveFilterKey,
            label: l10n.billingPriceBookEffectiveLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'current',
                label: l10n.billingPriceBookEffectiveCurrent,
              ),
              AppSearchBarFilterChoice(
                value: 'other',
                label: l10n.billingPriceBookEffectiveOther,
              ),
            ],
          ),
        ],
        filterValue: _filterValue,
        hasActiveFilters: _hasActiveFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() => _filterValue = value);
          unawaited(_reload());
        },
        trailingActions: <AppSearchBarAction>[
          if (canWrite)
            AppSearchBarAction(
              label: l10n.commonAddActionLabel,
              icon: Icons.add_outlined,
              onPressed: () => unawaited(_openCreateOrEdit()),
            ),
        ],
      ),
      columns: <AppListTableColumn<BillingPriceBookEntry>>[
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'item',
          label: l10n.billingPriceBookItemColumn,
          alwaysVisible: true,
          preferredWidth: 220,
          cellBuilder: (_, BillingPriceBookEntry item) => Text(
            billingPriceBookItemDisplayLabel(l10n, item),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          sortComparator: (BillingPriceBookEntry a, BillingPriceBookEntry b) =>
              billingPriceBookItemDisplayLabel(l10n, a).compareTo(
                billingPriceBookItemDisplayLabel(l10n, b),
              ),
          exportValue: (BillingPriceBookEntry item) =>
              billingPriceBookItemDisplayLabel(l10n, item),
        ),
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'mode',
          label: l10n.billingPriceBookModeColumn,
          preferredWidth: 120,
          cellBuilder: (_, BillingPriceBookEntry item) =>
              Text(billingPriceBookModeLabel(l10n, item.paymentMode)),
          sortComparator: (BillingPriceBookEntry a, BillingPriceBookEntry b) =>
              a.paymentMode.compareTo(b.paymentMode),
          exportValue: (BillingPriceBookEntry item) =>
              billingPriceBookModeLabel(l10n, item.paymentMode),
        ),
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'price',
          label: l10n.billingPriceBookPriceColumn,
          preferredWidth: 120,
          cellBuilder: (BuildContext context, BillingPriceBookEntry item) =>
              Text(billingPriceBookMoney(context, item.unitPrice, item.currency)),
          sortComparator: (BillingPriceBookEntry a, BillingPriceBookEntry b) =>
              a.unitPrice.compareTo(b.unitPrice),
          exportValue: (BillingPriceBookEntry item) =>
              '${item.unitPrice} ${item.currency}',
        ),
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'status',
          label: l10n.billingPriceBookStatusColumn,
          preferredWidth: 110,
          cellBuilder: (_, BillingPriceBookEntry item) => AppStatusBadge(
            label: item.isActive
                ? l10n.billingPriceBookStatusActive
                : l10n.billingPriceBookStatusInactive,
            tone: item.isActive
                ? AppWorkspaceStatusTone.success
                : AppWorkspaceStatusTone.neutral,
            icon: item.isActive
                ? Icons.check_circle_outline
                : Icons.pause_circle_outline,
          ),
          sortComparator: (BillingPriceBookEntry a, BillingPriceBookEntry b) =>
              (a.isActive == b.isActive) ? 0 : (a.isActive ? -1 : 1),
          exportValue: (BillingPriceBookEntry item) => item.isActive
              ? l10n.billingPriceBookStatusActive
              : l10n.billingPriceBookStatusInactive,
        ),
        if (canWrite)
          AppListTableColumn<BillingPriceBookEntry>(
            id: 'actions',
            label: l10n.billingPriceBookActionsColumn,
            alwaysVisible: true,
            preferredWidth: 200,
            cellBuilder: (BuildContext context, BillingPriceBookEntry item) =>
                _actionsCell(context, item),
            exportValue: (_) => '',
          ),
      ],
      columnChoices: <AppListTableColumn<BillingPriceBookEntry>>[
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'item',
          label: l10n.billingPriceBookItemColumn,
          alwaysVisible: true,
          preferredWidth: 220,
          cellBuilder: (_, BillingPriceBookEntry item) => Text(
            billingPriceBookItemDisplayLabel(l10n, item),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          exportValue: (BillingPriceBookEntry item) =>
              billingPriceBookItemDisplayLabel(l10n, item),
        ),
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'mode',
          label: l10n.billingPriceBookModeColumn,
          preferredWidth: 120,
          cellBuilder: (_, BillingPriceBookEntry item) =>
              Text(billingPriceBookModeLabel(l10n, item.paymentMode)),
          exportValue: (BillingPriceBookEntry item) =>
              billingPriceBookModeLabel(l10n, item.paymentMode),
        ),
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'price',
          label: l10n.billingPriceBookPriceColumn,
          preferredWidth: 120,
          cellBuilder: (BuildContext context, BillingPriceBookEntry item) =>
              Text(billingPriceBookMoney(context, item.unitPrice, item.currency)),
          exportValue: (BillingPriceBookEntry item) =>
              '${item.unitPrice} ${item.currency}',
        ),
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'status',
          label: l10n.billingPriceBookStatusColumn,
          preferredWidth: 110,
          cellBuilder: (_, BillingPriceBookEntry item) => AppStatusBadge(
            label: item.isActive
                ? l10n.billingPriceBookStatusActive
                : l10n.billingPriceBookStatusInactive,
            tone: item.isActive
                ? AppWorkspaceStatusTone.success
                : AppWorkspaceStatusTone.neutral,
            icon: item.isActive
                ? Icons.check_circle_outline
                : Icons.pause_circle_outline,
          ),
          exportValue: (BillingPriceBookEntry item) => item.isActive
              ? l10n.billingPriceBookStatusActive
              : l10n.billingPriceBookStatusInactive,
        ),
        if (canWrite)
          AppListTableColumn<BillingPriceBookEntry>(
            id: 'actions',
            label: l10n.billingPriceBookActionsColumn,
            alwaysVisible: true,
            preferredWidth: 200,
            cellBuilder: (BuildContext context, BillingPriceBookEntry item) =>
                _actionsCell(context, item),
            exportValue: (_) => '',
          ),
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'catalog',
          label: l10n.billingPriceBookCatalogColumn,
          preferredWidth: 140,
          cellBuilder: (_, BillingPriceBookEntry item) =>
              Text(billingPriceBookCatalogLabel(l10n, item.catalogType)),
          exportValue: (BillingPriceBookEntry item) =>
              billingPriceBookCatalogLabel(l10n, item.catalogType),
        ),
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'scheme',
          label: l10n.billingPriceBookSchemeColumn,
          preferredWidth: 160,
          cellBuilder: (_, BillingPriceBookEntry item) {
            return Text(billingPriceBookSchemeDisplayLabel(l10n, item));
          },
          exportValue: (BillingPriceBookEntry item) =>
              billingPriceBookSchemeDisplayLabel(l10n, item),
        ),
        AppListTableColumn<BillingPriceBookEntry>(
          id: 'effective',
          label: l10n.billingPriceBookEffectiveColumn,
          preferredWidth: 140,
          cellBuilder: (BuildContext context, BillingPriceBookEntry item) {
            if (item.effectiveFrom == null) {
              return const Text('—');
            }
            return Text(
              AppFormatters.dateTime(
                item.effectiveFrom!,
                Localizations.localeOf(context),
              ),
            );
          },
          exportValue: (BillingPriceBookEntry item) =>
              item.effectiveFrom?.toIso8601String() ?? '',
        ),
      ],
      mobileItemBuilder: (BuildContext context, BillingPriceBookEntry item) {
        return AppListTableMobileItem(
          title: billingPriceBookItemDisplayLabel(l10n, item),
          caption: billingPriceBookMoney(context, item.unitPrice, item.currency),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: billingPriceBookModeLabel(l10n, item.paymentMode),
              icon: Icons.payments_outlined,
            ),
            AppListTableMobileMeta(
              label: item.isActive
                  ? l10n.billingPriceBookStatusActive
                  : l10n.billingPriceBookStatusInactive,
              icon: item.isActive
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
            ),
          ],
        );
      },
    );
  }
}

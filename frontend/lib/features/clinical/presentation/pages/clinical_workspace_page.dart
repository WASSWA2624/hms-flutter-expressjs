import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class ClinicalWorkspacePage extends ConsumerWidget {
  const ClinicalWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<ClinicalWorkspaceState>> state = ref.watch(
      clinicalWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<ClinicalWorkspaceState>(
      value: state,
      loadingTitle: l10n.clinicalLoadingTitle,
      loadingBody: l10n.clinicalLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(clinicalWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, ClinicalWorkspaceState data) {
        return _ClinicalWorkspaceContent(state: data);
      },
    );
  }
}

class _ClinicalWorkspaceContent extends ConsumerStatefulWidget {
  const _ClinicalWorkspaceContent({required this.state});

  final ClinicalWorkspaceState state;

  @override
  ConsumerState<_ClinicalWorkspaceContent> createState() =>
      _ClinicalWorkspaceContentState();
}

class _ClinicalWorkspaceContentState
    extends ConsumerState<_ClinicalWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    activeModules: <String>['encounters-vitals'],
  );

  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
  }

  @override
  void didUpdateWidget(covariant _ClinicalWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalWorkspaceState state = widget.state;
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );

    return AppWorkspace(
      title: l10n.clinicalTitle,
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isSaving
            ? l10n.clinicalSavingStatus
            : l10n.clinicalLiveStatus,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
      ),
      secondaryActions: <Widget>[
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshing,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        AppWorkspaceSummaryCard(
          label: l10n.clinicalWaitingReviewSummaryLabel,
          value: _countLabel(context, state.waitingReviewCount),
          icon: Icons.rate_review_outlined,
          tone: AppWorkspaceStatusTone.info,
          compact: true,
          onPressed: () {
            _openSummaryWorklistDialog(
              context,
              ref,
              category: _ClinicalSummaryCategory.waitingReview,
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.clinicalUrgentSummaryLabel,
          value: _countLabel(context, state.urgentCount),
          icon: Icons.priority_high_outlined,
          tone: AppWorkspaceStatusTone.error,
          compact: true,
          onPressed: () {
            _openSummaryWorklistDialog(
              context,
              ref,
              category: _ClinicalSummaryCategory.urgent,
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.clinicalResultsReadySummaryLabel,
          value: _countLabel(context, state.resultsReadyCount),
          icon: Icons.science_outlined,
          tone: AppWorkspaceStatusTone.success,
          compact: true,
          onPressed: () {
            _openSummaryWorklistDialog(
              context,
              ref,
              category: _ClinicalSummaryCategory.resultsReady,
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.clinicalInConsultationSummaryLabel,
          value: _countLabel(context, state.inConsultationCount),
          icon: Icons.medical_information_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () {
            _openSummaryWorklistDialog(
              context,
              ref,
              category: _ClinicalSummaryCategory.inConsultation,
            );
          },
        ),
      ],
      body: _ClinicalWorklistPanel(
        state: state,
        searchController: _searchController,
        onSearchChanged: _applySearch,
        onSearchSubmitted: _applySearchImmediately,
      ),
    );
  }

  void _applySearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      ref
          .read(clinicalWorkspaceControllerProvider.notifier)
          .applySearch(value, showLoading: false);
    });
  }

  void _applySearchImmediately(String value) {
    _searchDebounce?.cancel();
    ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .applySearch(value, showLoading: false);
  }
}

class _ClinicalWorklistPanel extends ConsumerWidget {
  const _ClinicalWorklistPanel({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final ClinicalWorkspaceState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    return _ClinicalWorklistSurface(
      child: AppPaginatedListTable<ClinicalWorklistEntry>(
        page: state.worklist,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<ClinicalWorklistEntry> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        onRowSelected: (ClinicalWorklistEntry entry) {
          _openClinicalEntryDialog(context, ref, entry);
        },
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.clinicalNoWorklistTitle,
          body: l10n.clinicalNoWorklistBody,
          icon: Icons.assignment_outlined,
        ),
        search: _worklistSearch(
          context,
          controller,
          searchController,
          filters: state.query.filters,
          scope: state.query.scope,
          filterEntries: state.worklist.items,
          onSearchChanged: onSearchChanged,
          onSearchSubmitted: onSearchSubmitted,
        ),
        columns: _clinicalWorklistColumns(l10n),
        mobileItemBuilder: _clinicalWorklistMobileItemBuilder,
        itemKeyBuilder: _clinicalWorklistItemKey,
        rowColorBuilder: _clinicalRowColor,
      ),
    );
  }
}

class _ClinicalWorklistSurface extends StatelessWidget {
  const _ClinicalWorklistSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(padding: EdgeInsets.all(theme.spacing.md), child: child),
    );
  }
}

AppListTableSearch<ClinicalWorklistEntry> _worklistSearch(
  BuildContext context,
  ClinicalWorkspaceController controller,
  TextEditingController searchController, {
  required ClinicalWorklistFilters filters,
  required ClinicalQueueScope scope,
  required List<ClinicalWorklistEntry> filterEntries,
  required ValueChanged<String> onSearchChanged,
  required ValueChanged<String> onSearchSubmitted,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableSearch<ClinicalWorklistEntry>(
    controller: searchController,
    semanticLabel: l10n.clinicalSearchLabel,
    hintText: l10n.clinicalSearchHint,
    clearLabel: l10n.opdClearFiltersAction,
    matcher: (ClinicalWorklistEntry item, String query) {
      return item.matchesSearch(query, filters: filters);
    },
    onChanged: onSearchChanged,
    onSubmitted: onSearchSubmitted,
    showAdvancedFilterButton: true,
    advancedFilterButtonLabel: l10n.clinicalFiltersLabel,
    advancedFilterTitle: l10n.clinicalFiltersLabel,
    advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
    advancedFilterResetLabel: l10n.opdClearFiltersAction,
    advancedFilterCancelLabel: l10n.commonCancelActionLabel,
    textFilters: _clinicalTextFilters(l10n),
    searchFieldLabel: l10n.clinicalSearchLabel,
    allFieldsLabel: l10n.opdAllFieldsFilterLabel,
    dateFilterLabel: l10n.clinicalLastUpdatedLabel,
    dateFromLabel: l10n.opdDateFromLabel,
    dateToLabel: l10n.opdDateToLabel,
    datePickerButtonLabel: l10n.opdDatePickerButtonLabel,
    invalidDateMessage: l10n.opdInvalidDateMessage,
    filterGroups: _clinicalFilterGroups(
      l10n,
      filterEntries,
      includeScope: true,
    ),
    filterValue: _filterValueFromQuery(
      filters,
      scope: scope,
      search: searchController.text,
    ),
    hasActiveFilters: _hasActiveClinicalFilters(
      filters,
      scope,
      search: searchController.text,
    ),
    onFilterChanged: (AppSearchBarFilterValue value) {
      final String search = _searchFromValue(value);
      if (searchController.text != search) {
        searchController.text = search;
      }
      controller.applyWorklistFilters(
        scope: _scopeFromValue(value),
        filters: _filtersFromValue(value),
        search: search,
      );
    },
  );
}

List<AppListTableColumn<ClinicalWorklistEntry>> _clinicalWorklistColumns(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<ClinicalWorklistEntry>>[
    AppListTableColumn<ClinicalWorklistEntry>(
      label: l10n.opdPatientColumnLabel,
      cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
        return _ClinicalPatientCell(item: item);
      },
    ),
    AppListTableColumn<ClinicalWorklistEntry>(
      label: l10n.clinicalSourceQueueLabel,
      cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
        return _ClinicalQueueCell(item: item);
      },
    ),
    AppListTableColumn<ClinicalWorklistEntry>(
      label: l10n.opdStatusColumnLabel,
      cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
        return _ClinicalStatusCell(item: item);
      },
    ),
    AppListTableColumn<ClinicalWorklistEntry>(
      label: l10n.opdProviderColumnLabel,
      cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
        return Text(item.providerDisplayName ?? l10n.profileUnknownValue);
      },
    ),
    AppListTableColumn<ClinicalWorklistEntry>(
      label: l10n.clinicalLastUpdatedLabel,
      cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
        return Text(_dateTimeLabel(context, item.updatedAt ?? item.startedAt));
      },
    ),
  ];
}

class _ClinicalQueueCell extends StatelessWidget {
  const _ClinicalQueueCell({required this.item});

  final ClinicalWorklistEntry item;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _apiLabel(item.sourceQueue),
        tone: _sourceQueueTone(item.sourceQueue),
      ),
    );
  }
}

class _ClinicalStatusCell extends StatelessWidget {
  const _ClinicalStatusCell({required this.item});

  final ClinicalWorklistEntry item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        AppWorkspaceStatusBadge(status: _entryStatus(item)),
        if (item.isUrgent)
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: l10n.clinicalUrgentSummaryLabel,
              tone: AppWorkspaceStatusTone.error,
              icon: Icons.priority_high_outlined,
            ),
          ),
        if (item.resultsReady)
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: l10n.clinicalResultsReadySummaryLabel,
              tone: AppWorkspaceStatusTone.success,
              icon: Icons.science_outlined,
            ),
          ),
      ],
    );
  }
}

Widget _clinicalWorklistMobileItemBuilder(
  BuildContext context,
  ClinicalWorklistEntry item,
) {
  final ThemeData theme = Theme.of(context);
  return Padding(
    padding: EdgeInsets.symmetric(
      horizontal: theme.spacing.sm,
      vertical: theme.spacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ClinicalPatientCell(item: item),
        SizedBox(height: theme.spacing.xs),
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _ClinicalQueueCell(item: item),
            _ClinicalStatusCell(item: item),
            Text(
              _joinDisplay(<String?>[
                item.providerDisplayName,
                _dateTimeLabel(context, item.updatedAt ?? item.startedAt),
              ]),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    ),
  );
}

LocalKey _clinicalWorklistItemKey(ClinicalWorklistEntry item) {
  return ValueKey<String>('${item.sourceQueue}-${item.encounterId}');
}

Color? _clinicalRowColor(BuildContext context, ClinicalWorklistEntry item) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  if (item.isUrgent) {
    return colorScheme.errorContainer.withValues(alpha: 0.18);
  }
  if (item.resultsReady) {
    return colorScheme.tertiaryContainer.withValues(alpha: 0.16);
  }
  if (clinicalWorklistEntryMatchesScope(
    item,
    ClinicalQueueScope.waitingReview,
  )) {
    return colorScheme.secondaryContainer.withValues(alpha: 0.14);
  }
  if (clinicalWorklistEntryMatchesScope(
    item,
    ClinicalQueueScope.inConsultation,
  )) {
    return colorScheme.primaryContainer.withValues(alpha: 0.12);
  }
  return null;
}

enum _ClinicalSummaryCategory {
  waitingReview,
  urgent,
  resultsReady,
  inConsultation,
}

Future<void> _openSummaryWorklistDialog(
  BuildContext context,
  WidgetRef ref, {
  required _ClinicalSummaryCategory category,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _ClinicalSummaryWorklistDialog(category: category),
  );
}

Future<void> _openClinicalEntryDialog(
  BuildContext context,
  WidgetRef ref,
  ClinicalWorklistEntry entry,
) async {
  final ClinicalWorkspaceController controller = ref.read(
    clinicalWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectEntry(entry);
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    _showFailureIfNeeded(context, failure);
    return;
  }

  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ClinicalEncounterDialog(initialEntry: entry),
  );
  controller.clearSelection();
}

class _ClinicalSummaryWorklistDialog extends ConsumerStatefulWidget {
  const _ClinicalSummaryWorklistDialog({required this.category});

  final _ClinicalSummaryCategory category;

  @override
  ConsumerState<_ClinicalSummaryWorklistDialog> createState() =>
      _ClinicalSummaryWorklistDialogState();
}

class _ClinicalSummaryWorklistDialogState
    extends ConsumerState<_ClinicalSummaryWorklistDialog> {
  late final TextEditingController _searchController;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final _ClinicalSummaryDialogConfig config = _summaryDialogConfig(
      l10n,
      widget.category,
    );
    final AsyncValue<Result<ClinicalWorkspaceState>> asyncState = ref.watch(
      clinicalWorkspaceControllerProvider,
    );

    return AppDialog(
      title: Text(config.title),
      icon: Icon(config.icon),
      scrollable: true,
      maxWidth: 1040,
      content: asyncState.when(
        data: (Result<ClinicalWorkspaceState> result) {
          return result.when(
            success: (ClinicalWorkspaceState state) {
              final List<ClinicalWorklistEntry> categoryItems = state
                  .worklist
                  .items
                  .where(
                    (ClinicalWorklistEntry item) =>
                        _matchesSummaryCategory(item, widget.category),
                  )
                  .toList(growable: false);
              final ClinicalWorklistFilters filters = _filtersFromValue(
                _filterValue,
              );
              final String advancedSearch = _searchFromValue(_filterValue);
              final List<ClinicalWorklistEntry> visibleItems = categoryItems
                  .where(
                    (ClinicalWorklistEntry item) =>
                        item.matchesSearch(advancedSearch, filters: filters) &&
                        item.matchesFilters(filters),
                  )
                  .toList(growable: false);

              return AppListTable<ClinicalWorklistEntry>(
                items: visibleItems,
                columns: _clinicalWorklistColumns(l10n),
                mobileItemBuilder: _clinicalWorklistMobileItemBuilder,
                itemKeyBuilder: _clinicalWorklistItemKey,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                rowColorBuilder: _clinicalRowColor,
                onRowSelected: (ClinicalWorklistEntry entry) {
                  _openClinicalEntryDialog(context, ref, entry);
                },
                emptyBuilder: (_) => AppWorkspaceStatePanel.state(
                  variant: AppStateViewVariant.empty,
                  title: config.emptyTitle,
                  body: l10n.clinicalNoWorklistBody,
                  icon: config.icon,
                ),
                search: AppListTableSearch<ClinicalWorklistEntry>(
                  controller: _searchController,
                  semanticLabel: l10n.clinicalSearchLabel,
                  hintText: l10n.clinicalSearchHint,
                  clearLabel: l10n.opdClearFiltersAction,
                  matcher: (ClinicalWorklistEntry item, String query) {
                    return item.matchesSearch(query, filters: filters);
                  },
                  onClear: () {
                    setState(() {
                      _filterValue = _filterValueWithoutText(
                        _filterValue.copyWith(clearField: true),
                        _clinicalTextGeneral,
                      );
                    });
                  },
                  showAdvancedFilterButton: true,
                  advancedFilterButtonLabel: l10n.clinicalFiltersLabel,
                  advancedFilterTitle: l10n.clinicalFiltersLabel,
                  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                  advancedFilterResetLabel: l10n.opdClearFiltersAction,
                  advancedFilterCancelLabel: l10n.commonCancelActionLabel,
                  textFilters: _clinicalTextFilters(l10n),
                  searchFieldLabel: l10n.clinicalSearchLabel,
                  allFieldsLabel: l10n.opdAllFieldsFilterLabel,
                  dateFilterLabel: l10n.clinicalLastUpdatedLabel,
                  dateFromLabel: l10n.opdDateFromLabel,
                  dateToLabel: l10n.opdDateToLabel,
                  datePickerButtonLabel: l10n.opdDatePickerButtonLabel,
                  invalidDateMessage: l10n.opdInvalidDateMessage,
                  filterGroups: _clinicalFilterGroups(l10n, categoryItems),
                  filterValue: _filterValue,
                  hasActiveFilters: _filterValue.isActive,
                  onFilterChanged: (AppSearchBarFilterValue value) {
                    final String search = _searchFromValue(value);
                    if (_searchController.text != search) {
                      _searchController.text = search;
                    }
                    setState(() => _filterValue = value);
                  },
                ),
              );
            },
            failure: (AppFailure failure) {
              return AppFailureStateView(
                failure: failure,
                onRetry: () {
                  ref
                      .read(clinicalWorkspaceControllerProvider.notifier)
                      .refresh();
                },
              );
            },
          );
        },
        error: (_, _) =>
            const AppFailureStateView(failure: AppFailure.unexpected()),
        loading: () => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.loading,
          title: l10n.clinicalLoadingTitle,
          body: l10n.clinicalLoadingBody,
          icon: Icons.assignment_outlined,
        ),
      ),
    );
  }
}

class _ClinicalEncounterDialog extends ConsumerWidget {
  const _ClinicalEncounterDialog({required this.initialEntry});

  final ClinicalWorklistEntry initialEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<ClinicalWorkspaceState>> asyncState = ref.watch(
      clinicalWorkspaceControllerProvider,
    );

    return AppDialog(
      title: Text(initialEntry.displayTitle),
      icon: const Icon(Icons.medical_services_outlined),
      scrollable: true,
      maxWidth: 1120,
      content: asyncState.when(
        data: (Result<ClinicalWorkspaceState> result) {
          return result.when(
            success: (ClinicalWorkspaceState state) {
              final ClinicalEncounterBundle? bundle = state.selectedBundle;
              if (bundle == null ||
                  !_isSameWorklistEntry(bundle.entry, initialEntry)) {
                return AppWorkspaceStatePanel.state(
                  variant: AppStateViewVariant.loading,
                  title: l10n.clinicalLoadingTitle,
                  body: l10n.clinicalLoadingBody,
                  icon: Icons.medical_services_outlined,
                );
              }
              return _ClinicalDetailPanel(state: state);
            },
            failure: (AppFailure failure) {
              return AppFailureStateView(
                failure: failure,
                onRetry: () {
                  ref
                      .read(clinicalWorkspaceControllerProvider.notifier)
                      .selectEntry(initialEntry);
                },
              );
            },
          );
        },
        error: (_, _) =>
            const AppFailureStateView(failure: AppFailure.unexpected()),
        loading: () => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.loading,
          title: l10n.clinicalLoadingTitle,
          body: l10n.clinicalLoadingBody,
          icon: Icons.medical_services_outlined,
        ),
      ),
    );
  }
}

class _ClinicalDetailPanel extends ConsumerWidget {
  const _ClinicalDetailPanel({required this.state});

  final ClinicalWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalEncounterBundle? bundle = state.selectedBundle;
    if (bundle == null) {
      return AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.clinicalNoSelectionTitle,
        body: l10n.clinicalNoSelectionBody,
        icon: Icons.medical_services_outlined,
      );
    }

    final ClinicalWorklistEntry entry = bundle.entry;
    final String patientId = entry.patientPublicId ?? entry.patientId ?? '';
    final String patientNumber = patientId.isEmpty ? entry.id : patientId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: entry.patientDisplayName ?? entry.displayTitle,
          patientNumber: patientNumber,
          patientNumberLabel: patientId.isEmpty ? null : l10n.opdPatientIdLabel,
          status: _entryStatus(entry),
          alerts: <AppWorkspaceStatus>[
            if (entry.isUrgent)
              AppWorkspaceStatus(
                label: l10n.clinicalUrgentSummaryLabel,
                tone: AppWorkspaceStatusTone.error,
              ),
            if (bundle.hasResultsReady)
              AppWorkspaceStatus(
                label: l10n.clinicalResultsReadySummaryLabel,
                tone: AppWorkspaceStatusTone.success,
              ),
          ],
          fields: _clinicalPatientContextFields(context, l10n, entry),
          onCopyPatientNumber: patientId.isEmpty
              ? null
              : () => _copyClinicalPatientId(context, patientId),
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        if (bundle.triageHandoff?.hasContent ?? false) ...<Widget>[
          _ClinicalTriageHandoffPanel(handoff: bundle.triageHandoff!),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        _ClinicalActionBar(bundle: bundle, referenceData: state.referenceData),
        SizedBox(height: Theme.of(context).spacing.md),
        _ClinicalLabOrdersPanel(
          bundle: bundle,
          referenceData: state.referenceData,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _ClinicalResultReview(bundle: bundle),
        SizedBox(height: Theme.of(context).spacing.md),
        _ClinicalRecordSections(bundle: bundle),
      ],
    );
  }
}

class _ClinicalTriageHandoffPanel extends StatelessWidget {
  const _ClinicalTriageHandoffPanel({required this.handoff});

  final ClinicalTriageHandoff handoff;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final int abnormalVitalCount = handoff.vitalSigns.where((
      ClinicalVitalSummary vital,
    ) {
      final String status = vital.status.toUpperCase();
      return status == 'ABNORMAL' || status == 'CRITICAL';
    }).length;

    return AppWorkspaceDetailPanel(
      title: l10n.opdWorkflowTriageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTriageSummaryPanel(
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.opdTriageLevelLabel,
                value: _apiLabel(handoff.triageLevel ?? ''),
                icon: Icons.priority_high_outlined,
              ),
              AppInfoTileData(
                label: l10n.opdRouteDecisionLabel,
                value: _apiLabel(handoff.routeTo ?? ''),
                icon: Icons.alt_route_outlined,
              ),
              AppInfoTileData(
                label: l10n.opdChiefComplaintLabel,
                value: handoff.chiefComplaint,
                icon: Icons.sick_outlined,
              ),
              AppInfoTileData(
                label: l10n.opdStageLabel,
                value: _apiLabel(handoff.stage ?? ''),
                icon: Icons.timeline_outlined,
              ),
              AppInfoTileData(
                label: l10n.opdNextStepColumnLabel,
                value: _apiLabel(handoff.nextStep ?? ''),
                icon: Icons.trending_flat_outlined,
              ),
              AppInfoTileData(
                label: l10n.opdTimeColumnLabel,
                value: _dateTimeLabel(context, handoff.queuedAt),
                icon: Icons.schedule_outlined,
              ),
            ],
            statuses: <AppWorkspaceStatus>[
              if ((handoff.triageLevel ?? '').trim().isNotEmpty)
                AppWorkspaceStatus(
                  label: _apiLabel(handoff.triageLevel!),
                  tone: appTriageToneForValue(handoff.triageLevel),
                  icon: appTriageIconForValue(handoff.triageLevel),
                ),
              if (handoff.emergencyIndicator)
                AppWorkspaceStatus(
                  label: l10n.opdTriageScopeEmergency,
                  tone: AppWorkspaceStatusTone.error,
                  icon: Icons.emergency_outlined,
                ),
            ],
            notesLabel: l10n.opdTriageNotesLabel,
            notes: handoff.triageNotes,
            emptyValue: l10n.profileUnknownValue,
          ),
          SizedBox(height: theme.spacing.md),
          AppVitalsSummaryPanel(
            title: l10n.opdVitalsSummaryLabel,
            status: AppWorkspaceStatus(
              label: _apiLabel(abnormalVitalCount > 0 ? 'ABNORMAL' : 'NORMAL'),
              tone: abnormalVitalCount > 0
                  ? AppWorkspaceStatusTone.warning
                  : AppWorkspaceStatusTone.success,
            ),
            emptyLabel: l10n.opdNoRelatedRecordsLabel,
            items: <AppVitalSummaryItem>[
              for (final ClinicalVitalSummary vital in handoff.vitalSigns)
                AppVitalSummaryItem(
                  label: _apiLabel(vital.vitalType),
                  value: vital.displayValue,
                  recordedAtLabel: _dateTimeLabel(context, vital.recordedAt),
                  status: AppWorkspaceStatus(
                    label: _apiLabel(vital.status),
                    tone: _clinicalVitalTone(vital.status),
                  ),
                ),
            ],
            alerts: <AppClinicalAlertSummary>[
              for (final ClinicalAlertSummary alert in handoff.alerts)
                AppClinicalAlertSummary(
                  status: AppWorkspaceStatus(
                    label: _joinDisplay(<String?>[
                      _apiLabel(alert.severity ?? ''),
                      alert.message,
                    ]),
                    tone: _clinicalAlertTone(alert.severity),
                  ),
                  description: _joinDisplay(<String?>[
                    alert.message,
                    _dateTimeLabel(context, alert.createdAt),
                  ]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClinicalActionBar extends ConsumerWidget {
  const _ClinicalActionBar({required this.bundle, required this.referenceData});

  final ClinicalEncounterBundle bundle;
  final ClinicalReferenceData referenceData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    return AppWorkspaceDetailPanel(
      title: l10n.clinicalActionsTitle,
      child: AppAccessActionGate(
        requirement: _ClinicalWorkspaceContentState._writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return Wrap(
            spacing: Theme.of(context).spacing.xs,
            runSpacing: Theme.of(context).spacing.xs,
            children: <Widget>[
              _actionButton(
                label: l10n.clinicalAddNoteAction,
                icon: Icons.note_add_outlined,
                enabled: isAllowed,
                onPressed: () => _openNoteDialog(context, controller),
              ),
              _actionButton(
                label: l10n.clinicalAddDiagnosisAction,
                icon: Icons.rule_outlined,
                enabled: isAllowed,
                onPressed: () => _openDiagnosisDialog(context),
              ),
              _actionButton(
                label: l10n.clinicalRequestLabAction,
                icon: Icons.science_outlined,
                enabled: isAllowed,
                onPressed: () => _openLabDialog(context, referenceData),
              ),
              _actionButton(
                label: l10n.clinicalRequestRadiologyAction,
                icon: Icons.biotech_outlined,
                enabled: isAllowed,
                onPressed: () => _openRadiologyDialog(context, referenceData),
              ),
              _actionButton(
                label: l10n.clinicalPrescribeAction,
                icon: Icons.medication_outlined,
                enabled: isAllowed,
                onPressed: () =>
                    _openPrescriptionDialog(context, referenceData),
              ),
              _actionButton(
                label: l10n.clinicalRequestProcedureAction,
                icon: Icons.healing_outlined,
                enabled: isAllowed,
                onPressed: () => _openProcedureDialog(context),
              ),
              _actionButton(
                label: l10n.clinicalCarePlanAction,
                icon: Icons.playlist_add_check_outlined,
                enabled: isAllowed,
                onPressed: () => _openCarePlanDialog(context),
              ),
              _actionButton(
                label: l10n.opdReferAction,
                icon: Icons.alt_route_outlined,
                enabled: isAllowed,
                onPressed: () => _openReferralDialog(context),
              ),
              _actionButton(
                label: l10n.clinicalRequestAdmissionAction,
                icon: Icons.bed_outlined,
                enabled: isAllowed,
                onPressed: () => _openAdmissionDialog(context, referenceData),
              ),
              _actionButton(
                label: l10n.opdFollowUpAction,
                icon: Icons.event_repeat_outlined,
                enabled: isAllowed,
                onPressed: () => _openFollowUpDialog(context),
              ),
              _actionButton(
                label: l10n.clinicalCompleteConsultationAction,
                icon: Icons.task_alt_outlined,
                enabled: isAllowed && !bundle.entry.isTerminal,
                onPressed: () => _openCompleteDialog(context, controller),
              ),
              AppReportActionButton.print(
                label: l10n.clinicalPrintSummaryAction,
                onPressed: () async {
                  await printFormTemplateDocument(
                    ref: ref,
                    context: context,
                    title: l10n.clinicalConsultationSummaryTitle,
                    subtitle: bundle.entry.displayTitle,
                    metadata: <PrintFormMetadataItem>[
                      PrintFormMetadataItem(
                        label: l10n.patientsIdentifierLabel,
                        value:
                            bundle.entry.encounterPublicId ??
                            bundle.entry.encounterId,
                      ),
                      PrintFormMetadataItem(
                        label: l10n.opdStageLabel,
                        value: _apiLabel(bundle.entry.stage ?? ''),
                      ),
                    ],
                    bodyHtml: _consultationSummaryHtml(context, bundle),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return AppButton.secondary(
      label: label,
      leadingIcon: icon,
      enabled: enabled,
      onPressed: onPressed,
    );
  }
}

class _ClinicalResultReview extends StatelessWidget {
  const _ClinicalResultReview({required this.bundle});

  final ClinicalEncounterBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRelatedRecord> results =
        <ClinicalRelatedRecord>[...bundle.labOrders, ...bundle.radiologyOrders]
            .where((ClinicalRelatedRecord record) {
              return (record.status ?? '').toUpperCase() == 'COMPLETED';
            })
            .toList(growable: false);

    return AppWorkspaceDetailPanel(
      title: l10n.clinicalResultReviewTitle,
      description: results.isEmpty
          ? l10n.clinicalNoResultsReadyBody
          : l10n.clinicalResultReviewBody,
      child: _ClinicalRecordList(
        records: results,
        emptyLabel: l10n.clinicalNoResultsReadyBody,
      ),
    );
  }
}

class _ClinicalLabOrdersPanel extends ConsumerWidget {
  const _ClinicalLabOrdersPanel({
    required this.bundle,
    required this.referenceData,
  });

  final ClinicalEncounterBundle bundle;
  final ClinicalReferenceData referenceData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<ClinicalRelatedRecord> orders = bundle.labOrders;
    return AppWorkspaceDetailPanel(
      title: l10n.clinicalLabOrdersTitle,
      description: orders.isEmpty
          ? l10n.clinicalNoLabOrdersLabel
          : l10n.clinicalLabOrdersBody,
      child: orders.isEmpty
          ? Text(
              l10n.clinicalNoLabOrdersLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: <Widget>[
                for (var index = 0; index < orders.length; index += 1) ...[
                  if (index > 0) const Divider(height: 1),
                  _ClinicalLabOrderRow(
                    order: orders[index],
                    referenceData: referenceData,
                  ),
                ],
              ],
            ),
    );
  }
}

class _ClinicalLabOrderRow extends ConsumerWidget {
  const _ClinicalLabOrderRow({
    required this.order,
    required this.referenceData,
  });

  final ClinicalRelatedRecord order;
  final ClinicalReferenceData referenceData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    final List<ClinicalCatalogOption> panels = _requestedPanelsForOrder(
      order,
      referenceData,
    );
    final String status = order.status ?? '';
    final bool canEdit = _canEditLabOrder(status);
    final bool canCancel = _canCancelLabOrder(status);
    final bool canDelete = _canDeleteLabOrder(status);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.xs),
              child: Icon(
                Icons.science_outlined,
                size: theme.appTokens.listIconSize,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      order.title ?? order.id,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppWorkspaceStatusBadge(
                      status: AppWorkspaceStatus(
                        label: _apiLabel(status),
                        tone: _statusTone(status),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _joinDisplay(<String?>[
                    l10n.clinicalLabOrderItemCount(
                      order.itemCount == 0
                          ? order.labOrderItems.length
                          : order.itemCount,
                    ),
                    l10n.clinicalLabOrderSampleCount(order.sampleCount),
                    _dateTimeLabel(context, order.occurredAt),
                  ]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                _ClinicalLabOrderTestsList(
                  title: l10n.clinicalLabOrderTestsLabel,
                  emptyLabel: l10n.clinicalNoLabOrderTestsLabel,
                  order: order,
                ),
                SizedBox(height: theme.spacing.xs),
                _ClinicalLabOrderDetailList(
                  title: l10n.clinicalLabOrderPanelsLabel,
                  emptyLabel: l10n.clinicalNoLabOrderPanelsLabel,
                  values: <String>[
                    for (final ClinicalCatalogOption panel in panels)
                      panel.displayTitle,
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          AppAccessActionGate(
            requirement: _ClinicalWorkspaceContentState._writeRequirement,
            builder: (BuildContext context, bool isAllowed) {
              return Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  AppIconButton(
                    icon: Icons.edit_outlined,
                    semanticLabel: l10n.clinicalEditLabOrderAction,
                    tooltip: l10n.clinicalEditLabOrderAction,
                    enabled: isAllowed && canEdit,
                    onPressed: () => _openLabDialog(
                      context,
                      referenceData,
                      existingOrder: order,
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.block_outlined,
                    semanticLabel: l10n.clinicalCancelLabOrderAction,
                    tooltip: l10n.clinicalCancelLabOrderAction,
                    enabled: isAllowed && canCancel,
                    onPressed: () => _confirmLabOrderMutation(
                      context: context,
                      title: l10n.clinicalCancelLabOrderDialogTitle,
                      body: l10n.clinicalCancelLabOrderDialogBody,
                      confirmLabel: l10n.clinicalCancelLabOrderAction,
                      action: () => controller.cancelLabOrder(order.id),
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.delete_outline,
                    semanticLabel: l10n.clinicalDeleteLabOrderAction,
                    tooltip: l10n.clinicalDeleteLabOrderAction,
                    enabled: isAllowed && canDelete,
                    onPressed: () => _confirmLabOrderMutation(
                      context: context,
                      title: l10n.clinicalDeleteLabOrderDialogTitle,
                      body: l10n.clinicalDeleteLabOrderDialogBody,
                      confirmLabel: l10n.clinicalDeleteLabOrderAction,
                      action: () => controller.deleteLabOrder(order.id),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClinicalLabOrderDetailList extends StatelessWidget {
  const _ClinicalLabOrderDetailList({
    required this.title,
    required this.emptyLabel,
    required this.values,
  });

  final String title;
  final String emptyLabel;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        if (values.isEmpty)
          Text(
            emptyLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final String value in values)
                Chip(
                  label: Text(value),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ClinicalLabOrderTestsList extends StatelessWidget {
  const _ClinicalLabOrderTestsList({
    required this.title,
    required this.emptyLabel,
    required this.order,
  });

  final String title;
  final String emptyLabel;
  final ClinicalRelatedRecord order;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ClinicalLabOrderItem> items = order.labOrderItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        if (items.isEmpty)
          Text(
            emptyLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: <Widget>[
              for (var index = 0; index < items.length; index += 1) ...[
                if (index > 0) SizedBox(height: theme.spacing.xs),
                _ClinicalLabOrderTestRow(
                  item: items[index],
                  orderStatus: order.status,
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _ClinicalLabOrderTestRow extends StatelessWidget {
  const _ClinicalLabOrderTestRow({
    required this.item,
    required this.orderStatus,
  });

  final ClinicalLabOrderItem item;
  final String? orderStatus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String status = _effectiveLabOrderItemStatus(item, orderStatus);
    final String? resultStatus = _resultStatusLabel(item, status);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.science_outlined,
              size: theme.appTokens.listIconSize * 0.82,
              color: theme.colorScheme.primary,
            ),
            SizedBox(width: theme.spacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.displayTitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_hasText(item.displaySubtitle))
                    Text(
                      item.displaySubtitle!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.xs),
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label: _apiLabel(status),
                    tone: _statusTone(status),
                  ),
                ),
                if (resultStatus != null)
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: resultStatus,
                      tone: _statusTone(item.resultStatus),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicalRecordSections extends StatelessWidget {
  const _ClinicalRecordSections({required this.bundle});

  final ClinicalEncounterBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ClinicalRecordSection(
          title: l10n.clinicalPatientNotesTitle,
          records: bundle.clinicalNotes,
          emptyLabel: l10n.clinicalNoPatientNotesLabel,
        ),
        SizedBox(height: theme.spacing.md),
        _ClinicalRecordSection(
          title: l10n.clinicalPatientDiagnosesTitle,
          records: bundle.diagnoses,
          emptyLabel: l10n.clinicalNoPatientDiagnosesLabel,
        ),
        SizedBox(height: theme.spacing.md),
        _ClinicalRecordSection(
          title: l10n.opdProceduresSummaryLabel,
          records: bundle.procedures,
        ),
        SizedBox(height: theme.spacing.md),
        _ClinicalRecordSection(
          title: l10n.clinicalCarePlansTitle,
          records: bundle.carePlans,
        ),
        SizedBox(height: theme.spacing.md),
        _ClinicalRecordSection(
          title: l10n.clinicalOrdersTitle,
          records: <ClinicalRelatedRecord>[
            ...bundle.radiologyOrders,
            ...bundle.pharmacyOrders,
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _ClinicalRecordSection(
          title: l10n.clinicalHandoffsTitle,
          records: <ClinicalRelatedRecord>[
            ...bundle.referrals,
            ...bundle.followUps,
            ...bundle.admissions,
          ],
        ),
      ],
    );
  }
}

class _ClinicalRecordSection extends StatelessWidget {
  const _ClinicalRecordSection({
    required this.title,
    required this.records,
    this.emptyLabel,
  });

  final String title;
  final List<ClinicalRelatedRecord> records;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: title,
      child: _ClinicalRecordList(
        records: records,
        emptyLabel: emptyLabel ?? context.l10n.opdNoRelatedRecordsLabel,
      ),
    );
  }
}

class _ClinicalRecordList extends StatelessWidget {
  const _ClinicalRecordList({required this.records, required this.emptyLabel});

  final List<ClinicalRelatedRecord> records;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (records.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (var index = 0; index < records.length; index += 1) ...<Widget>[
          if (index > 0) const Divider(height: 1),
          _ClinicalRecordRow(record: records[index]),
        ],
      ],
    );
  }
}

class _ClinicalRecordRow extends StatelessWidget {
  const _ClinicalRecordRow({required this.record});

  final ClinicalRelatedRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.xs),
              child: Icon(
                _recordIcon(record.kind),
                size: theme.appTokens.listIconSize,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _joinDisplay(<String?>[record.title, record.subtitle]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _joinDisplay(<String?>[
                    _apiLabel(record.kind),
                    record.status == null ? null : _apiLabel(record.status!),
                    _dateTimeLabel(context, record.occurredAt),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _ClinicalPatientCell extends StatelessWidget {
  const _ClinicalPatientCell({required this.item});

  final ClinicalWorklistEntry item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (item.displaySubtitle != null)
          Text(
            item.displaySubtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _ClinicalNoteDialog extends ConsumerStatefulWidget {
  const _ClinicalNoteDialog({
    required this.title,
    required this.label,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final String label;
  final String submitLabel;
  final Future<AppFailure?> Function(String value) onSubmit;

  @override
  ConsumerState<_ClinicalNoteDialog> createState() =>
      _ClinicalNoteDialogState();
}

class _ClinicalNoteDialogState extends ConsumerState<_ClinicalNoteDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.edit_note_outlined),
      maxWidth: 720,
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          title: context.l10n.clinicalPatientNotesTitle,
          density: AppFormSectionDensity.spacious,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _controller,
              labelText: widget.label,
              prefixIcon: const Icon(Icons.notes_outlined),
              minLines: 5,
              maxLines: 6,
              enabled: !_isSaving,
              isRequired: true,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: widget.submitLabel,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(_controller.text.trim());
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _DiagnosisDialog extends ConsumerStatefulWidget {
  const _DiagnosisDialog();

  @override
  ConsumerState<_DiagnosisDialog> createState() => _DiagnosisDialogState();
}

class _DiagnosisDialogState extends ConsumerState<_DiagnosisDialog> {
  static const int _lookupMinLength = 2;
  static const Duration _lookupDebounceDuration = Duration(milliseconds: 350);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _termController;
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  Timer? _termLookupDebounce;
  Timer? _codeLookupDebounce;
  String _diagnosisType = 'PRIMARY';
  List<ClinicalCatalogOption> _termOptions = const <ClinicalCatalogOption>[];
  List<ClinicalCatalogOption> _codeOptions = const <ClinicalCatalogOption>[];
  _DiagnosisLookupTarget? _activeLookup;
  bool _isSaving = false;
  bool _isTermSearching = false;
  bool _isCodeSearching = false;
  bool _termHasText = false;
  bool _codeHasText = false;
  int _termLookupRequest = 0;
  int _codeLookupRequest = 0;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _termController = TextEditingController();
    _codeController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _termLookupDebounce?.cancel();
    _codeLookupDebounce?.cancel();
    _termController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.clinicalAddDiagnosisAction),
      icon: const Icon(Icons.rule_outlined),
      scrollable: true,
      maxWidth: 760,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          title: l10n.clinicalDiagnosisFormTitle,
          density: AppFormSectionDensity.spacious,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _diagnosisType,
              labelText: l10n.opdDiagnosisTypeLabel,
              enabled: !_isSaving,
              isRequired: true,
              options: _statusOptions(_diagnosisTypes),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _diagnosisType = value);
                }
              },
            ),
            _DiagnosisLookupField(
              controller: _termController,
              labelText: l10n.clinicalTermSearchLabel,
              clearLabel: MaterialLocalizations.of(context).clearButtonTooltip,
              options: _activeLookup == _DiagnosisLookupTarget.term
                  ? _termOptions
                  : const <ClinicalCatalogOption>[],
              isLoading:
                  _activeLookup == _DiagnosisLookupTarget.term &&
                  _isTermSearching,
              hasText: _termHasText,
              enabled: !_isSaving,
              onChanged: _handleTermLookupChanged,
              onClear: _clearTermLookup,
              onFocusChanged: (bool hasFocus) =>
                  _setActiveLookup(_DiagnosisLookupTarget.term, hasFocus),
              onSelected: _applyTerm,
              titleBuilder: _diagnosisTermLabel,
              subtitleBuilder: _diagnosisTermSubtitle,
            ),
            _DiagnosisLookupField(
              controller: _codeController,
              labelText: l10n.opdDiagnosisCodeLabel,
              clearLabel: MaterialLocalizations.of(context).clearButtonTooltip,
              options: _activeLookup == _DiagnosisLookupTarget.code
                  ? _codeOptions
                  : const <ClinicalCatalogOption>[],
              isLoading:
                  _activeLookup == _DiagnosisLookupTarget.code &&
                  _isCodeSearching,
              hasText: _codeHasText,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.characters,
              onChanged: _handleCodeLookupChanged,
              onClear: _clearCodeLookup,
              onFocusChanged: (bool hasFocus) =>
                  _setActiveLookup(_DiagnosisLookupTarget.code, hasFocus),
              onSelected: _applyCodeTerm,
              titleBuilder: _diagnosisCodeLabel,
              subtitleBuilder: _diagnosisCodeSubtitle,
            ),
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.opdDiagnosisLabel,
              prefixIcon: const Icon(Icons.medical_information_outlined),
              maxLines: 4,
              enabled: !_isSaving,
              isRequired: true,
              textCapitalization: TextCapitalization.sentences,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.clinicalAddDiagnosisAction,
        _isSaving,
        _submit,
      ),
    );
  }

  void _handleTermLookupChanged(String value) {
    final String query = value.trim();
    final bool hasText = query.isNotEmpty;
    if (_activeLookup != _DiagnosisLookupTarget.term ||
        _termHasText != hasText) {
      setState(() {
        _activeLookup = _DiagnosisLookupTarget.term;
        _termHasText = hasText;
      });
    }
    _scheduleTermLookup(query);
  }

  void _handleCodeLookupChanged(String value) {
    final String query = value.trim();
    final bool hasText = query.isNotEmpty;
    if (_activeLookup != _DiagnosisLookupTarget.code ||
        _codeHasText != hasText) {
      setState(() {
        _activeLookup = _DiagnosisLookupTarget.code;
        _codeHasText = hasText;
      });
    }
    _scheduleCodeLookup(query);
  }

  void _setActiveLookup(_DiagnosisLookupTarget target, bool hasFocus) {
    if (!hasFocus || _activeLookup == target) {
      return;
    }
    setState(() => _activeLookup = target);
  }

  void _scheduleTermLookup(String query) {
    _termLookupDebounce?.cancel();
    _termLookupRequest += 1;
    final int requestId = _termLookupRequest;
    if (query.length < _lookupMinLength) {
      if (_termOptions.isNotEmpty || _isTermSearching) {
        setState(() {
          _termOptions = const <ClinicalCatalogOption>[];
          _isTermSearching = false;
        });
      }
      return;
    }
    _termLookupDebounce = Timer(
      _lookupDebounceDuration,
      () => _loadTermLookup(query, requestId),
    );
  }

  void _scheduleCodeLookup(String query) {
    _codeLookupDebounce?.cancel();
    _codeLookupRequest += 1;
    final int requestId = _codeLookupRequest;
    if (query.length < _lookupMinLength) {
      if (_codeOptions.isNotEmpty || _isCodeSearching) {
        setState(() {
          _codeOptions = const <ClinicalCatalogOption>[];
          _isCodeSearching = false;
        });
      }
      return;
    }
    _codeLookupDebounce = Timer(
      _lookupDebounceDuration,
      () => _loadCodeLookup(query, requestId),
    );
  }

  Future<void> _loadTermLookup(String query, int requestId) async {
    if (!mounted || requestId != _termLookupRequest) {
      return;
    }
    setState(() {
      _termOptions = const <ClinicalCatalogOption>[];
      _isTermSearching = true;
    });
    final Result<List<ClinicalCatalogOption>> result = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .searchClinicalTerms(termType: 'DIAGNOSIS', query: query);
    if (!mounted || requestId != _termLookupRequest) {
      return;
    }
    setState(() {
      _termOptions = result.when(
        success: (List<ClinicalCatalogOption> value) => value,
        failure: (_) => const <ClinicalCatalogOption>[],
      );
      _isTermSearching = false;
    });
  }

  Future<void> _loadCodeLookup(String query, int requestId) async {
    if (!mounted || requestId != _codeLookupRequest) {
      return;
    }
    setState(() {
      _codeOptions = const <ClinicalCatalogOption>[];
      _isCodeSearching = true;
    });
    final Result<List<ClinicalCatalogOption>> result = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .searchClinicalTerms(termType: 'DIAGNOSIS', query: query);
    if (!mounted || requestId != _codeLookupRequest) {
      return;
    }
    setState(() {
      _codeOptions = result.when(
        success: (List<ClinicalCatalogOption> value) => value
            .where(
              (ClinicalCatalogOption option) =>
                  _trimmedOrNull(option.code) != null,
            )
            .toList(growable: false),
        failure: (_) => const <ClinicalCatalogOption>[],
      );
      _isCodeSearching = false;
    });
  }

  void _applyTerm(ClinicalCatalogOption term) {
    setState(() {
      _termController.text = _diagnosisTermLabel(term);
      _termHasText = true;
      _codeOptions = _mergeCatalogOption(_codeOptions, term);
      _codeController.text = term.code ?? '';
      _codeHasText = _trimmedOrNull(term.code) != null;
      _descriptionController.text = term.name ?? '';
      _termOptions = const <ClinicalCatalogOption>[];
      _isTermSearching = false;
      _activeLookup = null;
    });
  }

  void _applyCodeTerm(ClinicalCatalogOption term) {
    setState(() {
      _termOptions = _mergeCatalogOption(_termOptions, term);
      _termController.text = _diagnosisTermLabel(term);
      _termHasText = true;
      _codeController.text = term.code ?? '';
      _codeHasText = _trimmedOrNull(term.code) != null;
      _descriptionController.text = term.name ?? '';
      _codeOptions = const <ClinicalCatalogOption>[];
      _isCodeSearching = false;
      _activeLookup = null;
    });
  }

  void _clearTermLookup() {
    _termLookupDebounce?.cancel();
    _termLookupRequest += 1;
    setState(() {
      _termController.clear();
      _termHasText = false;
      _termOptions = const <ClinicalCatalogOption>[];
      _isTermSearching = false;
      if (_activeLookup == _DiagnosisLookupTarget.term) {
        _activeLookup = null;
      }
    });
  }

  void _clearCodeLookup() {
    _codeLookupDebounce?.cancel();
    _codeLookupRequest += 1;
    setState(() {
      _codeController.clear();
      _codeHasText = false;
      _codeOptions = const <ClinicalCatalogOption>[];
      _isCodeSearching = false;
      if (_activeLookup == _DiagnosisLookupTarget.code) {
        _activeLookup = null;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .addDiagnosis(
          diagnosisType: _diagnosisType,
          code: _codeController.text.trim(),
          description: _descriptionController.text.trim(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

enum _DiagnosisLookupTarget { term, code }

class _DiagnosisLookupField extends StatelessWidget {
  const _DiagnosisLookupField({
    required this.controller,
    required this.labelText,
    required this.clearLabel,
    required this.options,
    required this.hasText,
    required this.isLoading,
    required this.enabled,
    required this.onChanged,
    required this.onClear,
    required this.onFocusChanged,
    required this.onSelected,
    required this.titleBuilder,
    required this.subtitleBuilder,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String labelText;
  final String clearLabel;
  final List<ClinicalCatalogOption> options;
  final bool hasText;
  final bool isLoading;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<bool> onFocusChanged;
  final ValueChanged<ClinicalCatalogOption> onSelected;
  final String Function(ClinicalCatalogOption option) titleBuilder;
  final String Function(ClinicalCatalogOption option) subtitleBuilder;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    final bool showResults = isLoading || options.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          controller: controller,
          labelText: labelText,
          enabled: enabled,
          textCapitalization: textCapitalization,
          suffixIcon: _buildClearButton(context),
          onChanged: onChanged,
          onFocusChanged: onFocusChanged,
        ),
        if (showResults) ...<Widget>[
          SizedBox(height: spacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: options.isEmpty
                  ? SizedBox(
                      height: 48,
                      child: Center(
                        child: SizedBox.square(
                          dimension: theme.appTokens.listIconSize,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final ClinicalCatalogOption option = options[index];
                        return _DiagnosisLookupResult(
                          title: titleBuilder(option),
                          subtitle: subtitleBuilder(option),
                          enabled: enabled,
                          onSelected: () => onSelected(option),
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildClearButton(BuildContext context) {
    if (!enabled || !hasText) {
      return null;
    }
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: Center(
        child: TextButton(
          onPressed: onClear,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
            minimumSize: const Size(72, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(clearLabel, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _DiagnosisLookupResult extends StatelessWidget {
  const _DiagnosisLookupResult({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: enabled ? onSelected : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty) ...<Widget>[
                SizedBox(height: spacing.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcedureDialog extends ConsumerStatefulWidget {
  const _ProcedureDialog();

  @override
  ConsumerState<_ProcedureDialog> createState() => _ProcedureDialogState();
}

class _ProcedureDialogState extends ConsumerState<_ProcedureDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.clinicalRequestProcedureAction),
      icon: const Icon(Icons.healing_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _codeController,
              labelText: l10n.opdProcedureCodeLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.opdProcedureLabel,
              maxLines: 3,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.clinicalRequestProcedureAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .addProcedure(
          code: _codeController.text.trim(),
          description: _descriptionController.text.trim(),
          performedAt: DateTime.now(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _CarePlanDialog extends ConsumerStatefulWidget {
  const _CarePlanDialog();

  @override
  ConsumerState<_CarePlanDialog> createState() => _CarePlanDialogState();
}

class _CarePlanDialogState extends ConsumerState<_CarePlanDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _planController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _planController = TextEditingController();
  }

  @override
  void dispose() {
    _planController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.clinicalCarePlanAction),
      icon: const Icon(Icons.playlist_add_check_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _planController,
              labelText: l10n.clinicalCarePlanLabel,
              maxLines: 5,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.clinicalCarePlanAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .addCarePlan(
          plan: _planController.text.trim(),
          startDate: DateTime.now(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _LabOrderDialog extends ConsumerStatefulWidget {
  const _LabOrderDialog({required this.referenceData, this.existingOrder});

  final ClinicalReferenceData referenceData;
  final ClinicalRelatedRecord? existingOrder;

  @override
  ConsumerState<_LabOrderDialog> createState() => _LabOrderDialogState();
}

enum _LabRequestSelectionKind { tests, panels }

final class _PendingLabRequest {
  const _PendingLabRequest({required this.kind, required this.option});

  final _LabRequestSelectionKind kind;
  final ClinicalCatalogOption option;

  String get id => option.apiId;
}

final class _LabCatalogSearchResults {
  const _LabCatalogSearchResults({
    required this.options,
    required this.totalMatches,
  });

  final List<ClinicalCatalogOption> options;
  final int totalMatches;
}

class _LabOrderDialogState extends ConsumerState<_LabOrderDialog> {
  static const int _maxVisibleCatalogOptions = 80;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 120);

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  _LabRequestSelectionKind _selectionKind = _LabRequestSelectionKind.tests;
  String _searchQuery = '';
  final List<_PendingLabRequest> _requests = <_PendingLabRequest>[];
  int? _editingIndex;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _requests.addAll(_initialRequests());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final double bodyHeight = (MediaQuery.sizeOf(context).height * 0.64)
        .clamp(420.0, 620.0)
        .toDouble();
    final List<ClinicalCatalogOption> catalog = _catalogForSelection();
    final _LabCatalogSearchResults searchResults = _searchCatalog(catalog);
    final bool isEditingOrder = widget.existingOrder != null;
    return AppDialog(
      title: Text(
        isEditingOrder
            ? l10n.clinicalUpdateLabOrderAction
            : l10n.clinicalRequestLabAction,
      ),
      icon: const Icon(Icons.science_outlined),
      maxWidth: 920,
      closeEnabled: !_isSaving,
      content: SizedBox(
        height: bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            SegmentedButton<_LabRequestSelectionKind>(
              segments: <ButtonSegment<_LabRequestSelectionKind>>[
                ButtonSegment<_LabRequestSelectionKind>(
                  value: _LabRequestSelectionKind.tests,
                  icon: const Icon(Icons.science_outlined),
                  label: Text(l10n.clinicalLabRequestTestsModeLabel),
                ),
                ButtonSegment<_LabRequestSelectionKind>(
                  value: _LabRequestSelectionKind.panels,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(l10n.clinicalLabRequestPanelsModeLabel),
                ),
              ],
              selected: <_LabRequestSelectionKind>{_selectionKind},
              onSelectionChanged: _isSaving
                  ? null
                  : (Set<_LabRequestSelectionKind> values) {
                      setState(() {
                        _selectionKind = values.first;
                        _failure = null;
                      });
                    },
            ),
            SizedBox(height: theme.spacing.md),
            AppTextField(
              controller: _searchController,
              labelText: l10n.clinicalLabRequestSearchLabel,
              hintText: l10n.clinicalLabRequestSearchHint,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : AppIconButton(
                      icon: Icons.close,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      onPressed: _isSaving ? null : _clearSearch,
                    ),
              onChanged: _scheduleSearch,
            ),
            if (_editingIndex != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.tertiary(
                  label: l10n.clinicalLabRequestCancelEditAction,
                  leadingIcon: Icons.close,
                  enabled: !_isSaving,
                  onPressed: _cancelEdit,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool twoColumns = constraints.maxWidth >= 760;
                  final Widget catalogPanel = _LabCatalogResultsPanel(
                    results: searchResults,
                    kind: _selectionKind,
                    isSaving: _isSaving,
                    isEditing: _editingIndex != null,
                    onSelected: _addOrUpdateRequest,
                    isDuplicate: _isDuplicateSelection,
                  );
                  final Widget selectedPanel = _LabSelectedRequestsPanel(
                    requests: _requests,
                    editingIndex: _editingIndex,
                    isSaving: _isSaving,
                    onEdit: _editRequest,
                    onDelete: _deleteRequest,
                  );

                  if (!twoColumns) {
                    return Column(
                      children: <Widget>[
                        Expanded(child: catalogPanel),
                        SizedBox(height: theme.spacing.md),
                        Expanded(child: selectedPanel),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: catalogPanel),
                      SizedBox(width: theme.spacing.md),
                      Expanded(child: selectedPanel),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditingOrder
              ? l10n.clinicalUpdateLabOrderAction
              : l10n.clinicalRequestLabAction,
          isLoading: _isSaving,
          enabled: _requests.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  List<_PendingLabRequest> _initialRequests() {
    final ClinicalRelatedRecord? order = widget.existingOrder;
    if (order == null) {
      return const <_PendingLabRequest>[];
    }

    final List<ClinicalCatalogOption> inferredPanels = _requestedPanelsForOrder(
      order,
      widget.referenceData,
    );
    final Set<String> panelChildIds = inferredPanels
        .expand((ClinicalCatalogOption panel) => panel.childIds)
        .map(_normalizedCatalogToken)
        .where((String value) => value.isNotEmpty)
        .toSet();
    final Set<String> panelChildCodes = inferredPanels
        .expand((ClinicalCatalogOption panel) => panel.childCodes)
        .map(_normalizedCatalogToken)
        .where((String value) => value.isNotEmpty)
        .toSet();

    return <_PendingLabRequest>[
      for (final ClinicalCatalogOption panel in inferredPanels)
        _PendingLabRequest(
          kind: _LabRequestSelectionKind.panels,
          option: panel,
        ),
      ...order.labOrderItems
          .where(
            (ClinicalLabOrderItem item) =>
                _hasText(item.labTestId) &&
                !panelChildIds.contains(
                  _normalizedCatalogToken(item.labTestId!),
                ) &&
                !panelChildCodes.contains(
                  _normalizedCatalogToken(item.testCode ?? ''),
                ),
          )
          .map((ClinicalLabOrderItem item) {
            final ClinicalCatalogOption option = _catalogOptionForLabOrderItem(
              item,
            );
            return _PendingLabRequest(
              kind: _LabRequestSelectionKind.tests,
              option: option,
            );
          }),
    ];
  }

  ClinicalCatalogOption _catalogOptionForLabOrderItem(
    ClinicalLabOrderItem item,
  ) {
    for (final ClinicalCatalogOption option in widget.referenceData.labTests) {
      if (option.apiId == item.labTestId ||
          option.id == item.labTestId ||
          option.code == item.testCode) {
        return option;
      }
    }

    return ClinicalCatalogOption(
      id: item.labTestId ?? item.id,
      publicId: item.labTestId,
      name: item.testDisplayName,
      code: item.testCode,
      category: item.category,
      secondaryText: item.specimenType,
      status: item.status,
    );
  }

  List<ClinicalCatalogOption> _catalogForSelection() {
    return switch (_selectionKind) {
      _LabRequestSelectionKind.tests => widget.referenceData.labTests,
      _LabRequestSelectionKind.panels => widget.referenceData.labPanels,
    };
  }

  _LabCatalogSearchResults _searchCatalog(List<ClinicalCatalogOption> catalog) {
    final List<String> tokens = _searchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return _LabCatalogSearchResults(
        options: catalog
            .take(_maxVisibleCatalogOptions)
            .toList(growable: false),
        totalMatches: catalog.length,
      );
    }

    final List<ClinicalCatalogOption> visible = <ClinicalCatalogOption>[];
    var totalMatches = 0;
    for (final ClinicalCatalogOption option in catalog) {
      final String searchText = _catalogSearchText(option);
      final bool isMatch = tokens.every(searchText.contains);
      if (!isMatch) {
        continue;
      }
      totalMatches += 1;
      if (visible.length < _maxVisibleCatalogOptions) {
        visible.add(option);
      }
    }

    return _LabCatalogSearchResults(
      options: visible,
      totalMatches: totalMatches,
    );
  }

  String _catalogSearchText(ClinicalCatalogOption option) {
    return _joinDisplay(<String?>[
      option.apiId,
      option.displayTitle,
      option.displaySubtitle,
      option.name,
      option.code,
      option.category,
      option.secondaryText,
      option.status,
    ]).toLowerCase();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    setState(_resetSearch);
  }

  void _resetSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchQuery = '';
  }

  void _addOrUpdateRequest(ClinicalCatalogOption option) {
    final int? editingIndex = _editingIndex;
    final _PendingLabRequest request = _PendingLabRequest(
      kind: _selectionKind,
      option: option,
    );
    setState(() {
      _failure = null;
      if (editingIndex != null &&
          editingIndex >= 0 &&
          editingIndex < _requests.length) {
        _requests[editingIndex] = request;
        _editingIndex = null;
        _resetSearch();
        return;
      }
      _requests.add(request);
    });
  }

  void _editRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    final _PendingLabRequest request = _requests[index];
    setState(() {
      _selectionKind = request.kind;
      _editingIndex = index;
      _failure = null;
      _searchController.text = request.option.displayTitle;
      _searchQuery = request.option.displayTitle;
    });
  }

  void _deleteRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    setState(() {
      _requests.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _resetSearch();
      } else if (_editingIndex case final int editingIndex
          when editingIndex > index) {
        _editingIndex = editingIndex - 1;
      }
      _failure = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _failure = null;
      _resetSearch();
    });
  }

  bool _isDuplicateSelection(ClinicalCatalogOption option) {
    final int? editingIndex = _editingIndex;
    for (var index = 0; index < _requests.length; index += 1) {
      if (index == editingIndex) {
        continue;
      }
      final _PendingLabRequest request = _requests[index];
      if (request.kind == _selectionKind && request.id == option.apiId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _submit() async {
    if (_requests.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    final List<String> labTestIds = <String>[
      for (final _PendingLabRequest request in _requests)
        if (request.kind == _LabRequestSelectionKind.tests) request.id,
    ];
    final List<String> labPanelIds = <String>[
      for (final _PendingLabRequest request in _requests)
        if (request.kind == _LabRequestSelectionKind.panels) request.id,
    ];
    final ClinicalRelatedRecord? existingOrder = widget.existingOrder;
    final AppFailure? failure = existingOrder == null
        ? await controller.requestLab(
            labTestIds: labTestIds,
            labPanelIds: labPanelIds,
          )
        : await controller.updateLabOrder(
            labOrderId: existingOrder.id,
            labTestIds: labTestIds,
            labPanelIds: labPanelIds,
          );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _LabCatalogResultsPanel extends StatelessWidget {
  const _LabCatalogResultsPanel({
    required this.results,
    required this.kind,
    required this.isSaving,
    required this.isEditing,
    required this.onSelected,
    required this.isDuplicate,
  });

  final _LabCatalogSearchResults results;
  final _LabRequestSelectionKind kind;
  final bool isSaving;
  final bool isEditing;
  final ValueChanged<ClinicalCatalogOption> onSelected;
  final bool Function(ClinicalCatalogOption option) isDuplicate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalCatalogOption> options = results.options;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Text(
              l10n.clinicalLabRequestMatchesLabel(
                options.length,
                results.totalMatches,
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: options.isEmpty
                ? Center(child: Text(l10n.clinicalLabRequestNoCatalogOptions))
                : ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      final ClinicalCatalogOption option = options[index];
                      final bool duplicate = isDuplicate(option);
                      return _LabCatalogOptionRow(
                        option: option,
                        kind: kind,
                        isSaving: isSaving,
                        isEditing: isEditing,
                        isDuplicate: duplicate,
                        onSelected: duplicate ? null : () => onSelected(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LabCatalogOptionRow extends StatelessWidget {
  const _LabCatalogOptionRow({
    required this.option,
    required this.kind,
    required this.isSaving,
    required this.isEditing,
    required this.isDuplicate,
    required this.onSelected,
  });

  final ClinicalCatalogOption option;
  final _LabRequestSelectionKind kind;
  final bool isSaving;
  final bool isEditing;
  final bool isDuplicate;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String actionLabel = isEditing
        ? l10n.clinicalLabRequestUpdateSelectionAction
        : l10n.clinicalLabRequestAddSelectionAction;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            kind == _LabRequestSelectionKind.tests
                ? Icons.science_outlined
                : Icons.inventory_2_outlined,
            color: colorScheme.primary,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  option.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (option.displaySubtitle != null)
                  Text(
                    option.displaySubtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isSaving || isDuplicate ? null : onSelected,
            icon: Icon(
              isEditing ? Icons.done_outlined : Icons.add,
              size: theme.appTokens.listIconSize,
            ),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _LabSelectedRequestsPanel extends StatelessWidget {
  const _LabSelectedRequestsPanel({
    required this.requests,
    required this.editingIndex,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_PendingLabRequest> requests;
  final int? editingIndex;
  final bool isSaving;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.clinicalLabRequestSelectedTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  l10n.clinicalLabRequestSelectedCount(requests.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: requests.isEmpty
                ? Center(child: Text(l10n.clinicalLabRequestNoSelection))
                : ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      return _LabSelectedRequestRow(
                        request: requests[index],
                        isEditing: editingIndex == index,
                        isSaving: isSaving,
                        onEdit: () => onEdit(index),
                        onDelete: () => onDelete(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LabSelectedRequestRow extends StatelessWidget {
  const _LabSelectedRequestRow({
    required this.request,
    required this.isEditing,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final _PendingLabRequest request;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String typeLabel = _labRequestTypeLabel(l10n, request.kind);
    final String subtitle = _joinDisplay(<String?>[
      typeLabel,
      request.option.displaySubtitle,
    ]);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEditing
            ? colorScheme.primaryContainer.withValues(alpha: 0.38)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              request.kind == _LabRequestSelectionKind.tests
                  ? Icons.science_outlined
                  : Icons.inventory_2_outlined,
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    request.option.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.clinicalLabRequestEditSelectionAction,
              onPressed: isSaving ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: l10n.clinicalLabRequestDeleteSelectionAction,
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

String _labRequestTypeLabel(
  AppLocalizations l10n,
  _LabRequestSelectionKind kind,
) {
  return switch (kind) {
    _LabRequestSelectionKind.tests => l10n.clinicalLabRequestTestTypeLabel,
    _LabRequestSelectionKind.panels => l10n.clinicalLabRequestPanelTypeLabel,
  };
}

class _RadiologyOrderDialog extends ConsumerStatefulWidget {
  const _RadiologyOrderDialog({required this.referenceData});

  final ClinicalReferenceData referenceData;

  @override
  ConsumerState<_RadiologyOrderDialog> createState() =>
      _RadiologyOrderDialogState();
}

final class _PendingRadiologyRequest {
  const _PendingRadiologyRequest({
    required this.option,
    this.clinicalNote,
    this.bodyRegion,
    this.laterality,
    this.priority,
  });

  final ClinicalCatalogOption option;
  final String? clinicalNote;
  final String? bodyRegion;
  final String? laterality;
  final String? priority;

  String get id => option.apiId;
}

final class _RadiologyCatalogSearchResults {
  const _RadiologyCatalogSearchResults({
    required this.options,
    required this.totalMatches,
  });

  final List<ClinicalCatalogOption> options;
  final int totalMatches;
}

class _RadiologyOrderDialogState extends ConsumerState<_RadiologyOrderDialog> {
  static const int _maxVisibleCatalogOptions = 100;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 120);

  late final TextEditingController _searchController;
  late final TextEditingController _noteController;
  late final TextEditingController _bodyRegionController;
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _laterality;
  String? _priority;
  final List<_PendingRadiologyRequest> _requests = <_PendingRadiologyRequest>[];
  int? _editingIndex;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _noteController = TextEditingController();
    _bodyRegionController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _noteController.dispose();
    _bodyRegionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final double bodyHeight = (MediaQuery.sizeOf(context).height * 0.68)
        .clamp(460.0, 680.0)
        .toDouble();
    final _RadiologyCatalogSearchResults searchResults = _searchCatalog(
      widget.referenceData.radiologyTests,
    );
    return AppDialog(
      title: Text(l10n.clinicalRequestRadiologyAction),
      icon: const Icon(Icons.biotech_outlined),
      maxWidth: 980,
      closeEnabled: !_isSaving,
      content: SizedBox(
        height: bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _searchController,
              labelText: l10n.clinicalRadiologyRequestSearchLabel,
              hintText: l10n.clinicalRadiologyRequestSearchHint,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : AppIconButton(
                      icon: Icons.close,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      onPressed: _isSaving ? null : _clearSearch,
                    ),
              onChanged: _scheduleSearch,
            ),
            SizedBox(height: theme.spacing.md),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 720;
                final List<Widget> fields = <Widget>[
                  AppSelectField<String>(
                    value: _priority,
                    labelText: l10n.clinicalRadiologyPriorityLabel,
                    enabled: !_isSaving,
                    options: _statusOptions(const <String>[
                      'ROUTINE',
                      'URGENT',
                      'STAT',
                    ]),
                    onChanged: (String? value) {
                      setState(() => _priority = value);
                    },
                  ),
                  AppSelectField<String>(
                    value: _laterality,
                    labelText: l10n.clinicalRadiologyLateralityLabel,
                    enabled: !_isSaving,
                    options: _statusOptions(const <String>[
                      'LEFT',
                      'RIGHT',
                      'BILATERAL',
                      'MIDLINE',
                      'NOT_APPLICABLE',
                    ]),
                    onChanged: (String? value) {
                      setState(() => _laterality = value);
                    },
                  ),
                  AppTextField(
                    controller: _bodyRegionController,
                    labelText: l10n.clinicalRadiologyBodyRegionLabel,
                    enabled: !_isSaving,
                  ),
                ];

                if (compact) {
                  return Column(
                    children: <Widget>[
                      for (final Widget field in fields) ...<Widget>[
                        field,
                        SizedBox(height: theme.spacing.sm),
                      ],
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < fields.length;
                      index += 1
                    ) ...<Widget>[
                      Expanded(child: fields[index]),
                      if (index < fields.length - 1)
                        SizedBox(width: theme.spacing.sm),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: theme.spacing.sm),
            AppTextField(
              controller: _noteController,
              labelText: l10n.opdClinicalNoteLabel,
              enabled: !_isSaving,
              maxLines: 2,
            ),
            if (_editingIndex != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.tertiary(
                  label: l10n.clinicalRadiologyCancelEditAction,
                  leadingIcon: Icons.close,
                  enabled: !_isSaving,
                  onPressed: _cancelEdit,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool twoColumns = constraints.maxWidth >= 760;
                  final Widget catalogPanel = _RadiologyCatalogResultsPanel(
                    results: searchResults,
                    isSaving: _isSaving,
                    isEditing: _editingIndex != null,
                    onSelected: _addOrUpdateRequest,
                    isDuplicate: _isDuplicateSelection,
                  );
                  final Widget selectedPanel = _RadiologySelectedRequestsPanel(
                    requests: _requests,
                    editingIndex: _editingIndex,
                    isSaving: _isSaving,
                    onEdit: _editRequest,
                    onDelete: _deleteRequest,
                  );

                  if (!twoColumns) {
                    return Column(
                      children: <Widget>[
                        Expanded(child: catalogPanel),
                        SizedBox(height: theme.spacing.md),
                        Expanded(child: selectedPanel),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: catalogPanel),
                      SizedBox(width: theme.spacing.md),
                      Expanded(child: selectedPanel),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.clinicalRequestRadiologyAction,
          isLoading: _isSaving,
          enabled: _requests.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  _RadiologyCatalogSearchResults _searchCatalog(
    List<ClinicalCatalogOption> catalog,
  ) {
    final List<String> tokens = _searchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return _RadiologyCatalogSearchResults(
        options: catalog
            .take(_maxVisibleCatalogOptions)
            .toList(growable: false),
        totalMatches: catalog.length,
      );
    }

    final List<ClinicalCatalogOption> visible = <ClinicalCatalogOption>[];
    var totalMatches = 0;
    for (final ClinicalCatalogOption option in catalog) {
      final String searchText = _catalogSearchText(option);
      final bool isMatch = tokens.every(searchText.contains);
      if (!isMatch) {
        continue;
      }
      totalMatches += 1;
      if (visible.length < _maxVisibleCatalogOptions) {
        visible.add(option);
      }
    }

    return _RadiologyCatalogSearchResults(
      options: visible,
      totalMatches: totalMatches,
    );
  }

  String _catalogSearchText(ClinicalCatalogOption option) {
    return _joinDisplay(<String?>[
      option.apiId,
      option.displayTitle,
      option.displaySubtitle,
      option.name,
      option.code,
      option.category,
      option.secondaryText,
      option.status,
      option.searchText,
    ]).toLowerCase();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    setState(_resetSearch);
  }

  void _resetSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchQuery = '';
  }

  void _addOrUpdateRequest(ClinicalCatalogOption option) {
    final int? editingIndex = _editingIndex;
    final _PendingRadiologyRequest request = _PendingRadiologyRequest(
      option: option,
      clinicalNote: _trimmedOrNull(_noteController.text),
      bodyRegion: _trimmedOrNull(_bodyRegionController.text),
      laterality: _laterality,
      priority: _priority,
    );

    setState(() {
      _failure = null;
      if (editingIndex != null &&
          editingIndex >= 0 &&
          editingIndex < _requests.length) {
        _requests[editingIndex] = request;
        _editingIndex = null;
        _resetSearch();
        _resetRequestDetails();
        return;
      }
      _requests.add(request);
      _resetRequestDetails();
    });
  }

  void _editRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    final _PendingRadiologyRequest request = _requests[index];
    setState(() {
      _editingIndex = index;
      _failure = null;
      _searchController.text = request.option.displayTitle;
      _searchQuery = request.option.displayTitle;
      _noteController.text = request.clinicalNote ?? '';
      _bodyRegionController.text = request.bodyRegion ?? '';
      _laterality = request.laterality;
      _priority = request.priority;
    });
  }

  void _deleteRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    setState(() {
      _requests.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _resetSearch();
        _resetRequestDetails();
      } else if (_editingIndex case final int editingIndex
          when editingIndex > index) {
        _editingIndex = editingIndex - 1;
      }
      _failure = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _failure = null;
      _resetSearch();
      _resetRequestDetails();
    });
  }

  void _resetRequestDetails() {
    _noteController.clear();
    _bodyRegionController.clear();
    _laterality = null;
    _priority = null;
  }

  bool _isDuplicateSelection(ClinicalCatalogOption option) {
    final int? editingIndex = _editingIndex;
    for (var index = 0; index < _requests.length; index += 1) {
      if (index == editingIndex) {
        continue;
      }
      if (_requests[index].id == option.apiId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _submit() async {
    if (_requests.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .requestRadiology(
          requests: <ClinicalRadiologyRequest>[
            for (final _PendingRadiologyRequest request in _requests)
              ClinicalRadiologyRequest(
                radiologyTestId: request.id,
                clinicalNote: request.clinicalNote,
                bodyRegion: request.bodyRegion,
                laterality: request.laterality,
                priority: request.priority,
              ),
          ],
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _RadiologyCatalogResultsPanel extends StatelessWidget {
  const _RadiologyCatalogResultsPanel({
    required this.results,
    required this.isSaving,
    required this.isEditing,
    required this.onSelected,
    required this.isDuplicate,
  });

  final _RadiologyCatalogSearchResults results;
  final bool isSaving;
  final bool isEditing;
  final ValueChanged<ClinicalCatalogOption> onSelected;
  final bool Function(ClinicalCatalogOption option) isDuplicate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalCatalogOption> options = results.options;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Text(
              l10n.clinicalRadiologyRequestMatchesLabel(
                options.length,
                results.totalMatches,
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: options.isEmpty
                ? Center(
                    child: Text(l10n.clinicalRadiologyRequestNoCatalogOptions),
                  )
                : ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      final ClinicalCatalogOption option = options[index];
                      final bool duplicate = isDuplicate(option);
                      return _RadiologyCatalogOptionRow(
                        option: option,
                        isSaving: isSaving,
                        isEditing: isEditing,
                        isDuplicate: duplicate,
                        onSelected: duplicate ? null : () => onSelected(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RadiologyCatalogOptionRow extends StatelessWidget {
  const _RadiologyCatalogOptionRow({
    required this.option,
    required this.isSaving,
    required this.isEditing,
    required this.isDuplicate,
    required this.onSelected,
  });

  final ClinicalCatalogOption option;
  final bool isSaving;
  final bool isEditing;
  final bool isDuplicate;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String actionLabel = isEditing
        ? l10n.clinicalRadiologyUpdateSelectionAction
        : l10n.clinicalRadiologyAddSelectionAction;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            _radiologyCatalogIcon(option),
            color: colorScheme.primary,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  option.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (option.displaySubtitle != null)
                  Text(
                    option.displaySubtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isSaving || isDuplicate ? null : onSelected,
            icon: Icon(
              isEditing ? Icons.done_outlined : Icons.add,
              size: theme.appTokens.listIconSize,
            ),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _RadiologySelectedRequestsPanel extends StatelessWidget {
  const _RadiologySelectedRequestsPanel({
    required this.requests,
    required this.editingIndex,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_PendingRadiologyRequest> requests;
  final int? editingIndex;
  final bool isSaving;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.clinicalRadiologyRequestSelectedTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  l10n.clinicalRadiologyRequestSelectedCount(requests.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: requests.isEmpty
                ? Center(child: Text(l10n.clinicalRadiologyRequestNoSelection))
                : ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      return _RadiologySelectedRequestRow(
                        request: requests[index],
                        isEditing: editingIndex == index,
                        isSaving: isSaving,
                        onEdit: () => onEdit(index),
                        onDelete: () => onDelete(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RadiologySelectedRequestRow extends StatelessWidget {
  const _RadiologySelectedRequestRow({
    required this.request,
    required this.isEditing,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final _PendingRadiologyRequest request;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String subtitle = _joinDisplay(<String?>[
      request.option.displaySubtitle,
      request.priority == null ? null : _apiLabel(request.priority!),
      request.laterality == null ? null : _apiLabel(request.laterality!),
      request.bodyRegion,
    ]);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEditing
            ? colorScheme.primaryContainer.withValues(alpha: 0.38)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              _radiologyCatalogIcon(request.option),
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    request.option.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_hasText(request.clinicalNote))
                    Text(
                      request.clinicalNote!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.clinicalRadiologyEditSelectionAction,
              onPressed: isSaving ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: l10n.clinicalRadiologyDeleteSelectionAction,
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionDialog extends ConsumerStatefulWidget {
  const _PrescriptionDialog({required this.referenceData});

  final ClinicalReferenceData referenceData;

  @override
  ConsumerState<_PrescriptionDialog> createState() =>
      _PrescriptionDialogState();
}

class _PrescriptionDialogState extends ConsumerState<_PrescriptionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<_PrescriptionLineFormState> _lines = <_PrescriptionLineFormState>[];
  int _nextLineId = 0;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _lines.add(_createLine());
  }

  @override
  void dispose() {
    for (final _PrescriptionLineFormState line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppSelectOption<String>> drugOptions = _drugCatalogOptions(
      widget.referenceData.drugs,
    );

    return AppDialog(
      title: Text(l10n.clinicalPrescribeAction),
      icon: const Icon(Icons.medication_outlined),
      maxWidth: 980,
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.spacious,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            _PrescriptionIntroPanel(itemCount: _lines.length),
            for (var index = 0; index < _lines.length; index += 1)
              _buildLineCard(index, drugOptions),
            AppButton.secondary(
              label: l10n.clinicalPrescriptionAddMedicineAction,
              leadingIcon: Icons.add_circle_outline,
              enabled: !_isSaving,
              fullWidth: true,
              onPressed: _addLine,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.clinicalPrescribeAction,
          leadingIcon: Icons.send_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildLineCard(
    int index,
    List<AppSelectOption<String>> drugOptions,
  ) {
    final _PrescriptionLineFormState line = _lines[index];
    return _PrescriptionLineCard(
      key: ValueKey<int>(line.id),
      index: index,
      line: line,
      drugOptions: drugOptions,
      selectedDrugLabel: _catalogDisplayLabelById(
        widget.referenceData.drugs,
        line.drugId,
      ),
      enabled: !_isSaving,
      canRemove: !_isSaving && _lines.length > 1,
      onChanged: () => setState(() {}),
      onRemove: () => _removeLine(line),
    );
  }

  _PrescriptionLineFormState _createLine() {
    final _PrescriptionLineFormState line = _PrescriptionLineFormState(
      id: _nextLineId,
    );
    _nextLineId += 1;
    return line;
  }

  void _addLine() {
    setState(() {
      _lines.add(_createLine());
    });
  }

  void _removeLine(_PrescriptionLineFormState line) {
    if (_lines.length <= 1) {
      return;
    }
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final List<Map<String, Object?>> items = <Map<String, Object?>>[
      for (final _PrescriptionLineFormState line in _lines)
        _withoutEmptyValues(<String, Object?>{
          'drug_id': line.drugId,
          'quantity': int.tryParse(line.quantityController.text.trim()) ?? 1,
          'quantity_unit': line.quantityUnit,
          'dose_amount': num.tryParse(line.doseAmountController.text.trim()),
          'dose_unit': line.doseUnit,
          'route': line.route,
          'frequency': line.frequency,
          'duration_value': int.tryParse(line.durationController.text.trim()),
          'duration_unit': line.durationController.text.trim().isEmpty
              ? null
              : line.durationUnit,
          'instructions': line.instructionsController.text.trim(),
        }),
    ];

    final AppFailure? failure = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .prescribe(items: items);
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _PrescriptionLineFormState {
  _PrescriptionLineFormState({required this.id})
    : quantityController = TextEditingController(text: '1'),
      doseAmountController = TextEditingController(),
      durationController = TextEditingController(),
      instructionsController = TextEditingController();

  final int id;
  final TextEditingController quantityController;
  final TextEditingController doseAmountController;
  final TextEditingController durationController;
  final TextEditingController instructionsController;
  String? drugId;
  String? quantityUnit;
  String? doseUnit;
  String? route = 'ORAL';
  String? frequency = 'BID';
  String? durationUnit = 'days';

  void dispose() {
    quantityController.dispose();
    doseAmountController.dispose();
    durationController.dispose();
    instructionsController.dispose();
  }
}

class _PrescriptionIntroPanel extends StatelessWidget {
  const _PrescriptionIntroPanel({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.36),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.sm),
                child: Icon(
                  Icons.medication_liquid_outlined,
                  color: colorScheme.onPrimary,
                  size: theme.appTokens.listIconSize,
                ),
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.clinicalPrescriptionHeaderTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    l10n.clinicalPrescriptionHeaderBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            _PrescriptionCountBadge(count: itemCount),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionCountBadge extends StatelessWidget {
  const _PrescriptionCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.format_list_numbered_outlined,
              size: theme.appTokens.listIconSize,
              color: colorScheme.primary,
            ),
            SizedBox(width: theme.spacing.xs),
            Text(
              count.toString(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionLineCard extends StatelessWidget {
  const _PrescriptionLineCard({
    required this.index,
    required this.line,
    required this.drugOptions,
    required this.selectedDrugLabel,
    required this.enabled,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _PrescriptionLineFormState line;
  final List<AppSelectOption<String>> drugOptions;
  final String? selectedDrugLabel;
  final bool enabled;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            _PrescriptionLineHeader(
              index: index,
              selectedDrugLabel: selectedDrugLabel,
              canRemove: canRemove,
              onRemove: onRemove,
            ),
            AppSelectField<String>.searchable(
              value: line.drugId,
              labelText: l10n.clinicalPrescriptionDrugLabel,
              enabled: enabled,
              isRequired: true,
              options: drugOptions,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (String? value) {
                line.drugId = value;
                onChanged();
              },
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.quantityController,
                  labelText: l10n.opdDrugQuantityLabel,
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  enabled: enabled,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  validator: (String? value) =>
                      _requiredPositiveIntegerValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.quantityUnit,
                  labelText: l10n.clinicalPrescriptionQuantityUnitLabel,
                  enabled: enabled,
                  options: _unitOptions(_quantityUnits),
                  onChanged: (String? value) {
                    line.quantityUnit = value;
                    onChanged();
                  },
                ),
              ],
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.doseAmountController,
                  labelText: l10n.clinicalDoseAmountLabel,
                  prefixIcon: const Icon(Icons.science_outlined),
                  enabled: enabled,
                  isRequired: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalFormatters,
                  validator: (String? value) =>
                      _requiredPositiveNumberValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.doseUnit,
                  labelText: l10n.clinicalDoseUnitLabel,
                  enabled: enabled,
                  options: _unitOptions(_doseUnits),
                  onChanged: (String? value) {
                    line.doseUnit = value;
                    onChanged();
                  },
                ),
              ],
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppSelectField<String>.searchable(
                  value: line.route,
                  labelText: l10n.opdMedicationRouteLabel,
                  enabled: enabled,
                  options: _medicationRouteOptions(),
                  onChanged: (String? value) {
                    line.route = value;
                    onChanged();
                  },
                ),
                AppSelectField<String>.searchable(
                  value: line.frequency,
                  labelText: l10n.opdFrequencyLabel,
                  enabled: enabled,
                  options: _medicationFrequencyOptions(),
                  onChanged: (String? value) {
                    line.frequency = value;
                    onChanged();
                  },
                ),
              ],
            ),
            _PrescriptionDurationField(
              line: line,
              enabled: enabled,
              onChanged: onChanged,
            ),
            AppTextField(
              controller: line.instructionsController,
              labelText: l10n.clinicalInstructionsLabel,
              prefixIcon: const Icon(Icons.notes_outlined),
              enabled: enabled,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionLineHeader extends StatelessWidget {
  const _PrescriptionLineHeader({
    required this.index,
    required this.selectedDrugLabel,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final String? selectedDrugLabel;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String fallback = l10n.clinicalPrescriptionItemDescription;

    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Icon(
              Icons.medication_outlined,
              color: colorScheme.onSecondaryContainer,
              size: theme.appTokens.listIconSize,
            ),
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${l10n.clinicalPrescriptionMedicineLabel} ${index + 1}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                selectedDrugLabel ?? fallback,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.clinicalPrescriptionRemoveMedicineAction,
          onPressed: canRemove ? onRemove : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _PrescriptionDurationField extends StatelessWidget {
  const _PrescriptionDurationField({
    required this.line,
    required this.enabled,
    required this.onChanged,
  });

  final _PrescriptionLineFormState line;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.event_repeat_outlined,
                  color: colorScheme.primary,
                  size: theme.appTokens.listIconSize,
                ),
                SizedBox(width: theme.spacing.xs),
                Text(
                  l10n.clinicalDurationValueLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.durationController,
                  labelText: l10n.clinicalDurationValueLabel,
                  prefixIcon: const Icon(Icons.timer_outlined),
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  validator: (String? value) =>
                      _optionalPositiveIntegerValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.durationUnit,
                  labelText: l10n.clinicalDurationUnitLabel,
                  enabled: enabled,
                  options: _durationUnitOptions(),
                  validator: (String? value) {
                    final bool hasDuration = line.durationController.text
                        .trim()
                        .isNotEmpty;
                    return hasDuration && value == null
                        ? l10n.validationRequired
                        : null;
                  },
                  onChanged: (String? value) {
                    line.durationUnit = value;
                    onChanged();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralDialog extends ConsumerStatefulWidget {
  const _ReferralDialog();

  @override
  ConsumerState<_ReferralDialog> createState() => _ReferralDialogState();
}

class _ReferralDialogState extends ConsumerState<_ReferralDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _facilityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _facilityController = TextEditingController();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _facilityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdReferAction),
      icon: const Icon(Icons.alt_route_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _facilityController,
              labelText: l10n.opdExternalFacilityLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.opdReasonLabel,
              enabled: !_isSaving,
              maxLines: 3,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.opdNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: _dialogActions(context, l10n.opdReferAction, _isSaving, _submit),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .refer(
          externalFacilityName: _facilityController.text.trim(),
          reason: _reasonController.text.trim(),
          notes: _notesController.text.trim(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _FollowUpDialog extends ConsumerStatefulWidget {
  const _FollowUpDialog();

  @override
  ConsumerState<_FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends ConsumerState<_FollowUpDialog> {
  late final TextEditingController _dateController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdFollowUpAction),
      icon: const Icon(Icons.event_repeat_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTextField(
            controller: _dateController,
            labelText: l10n.opdFollowUpDateLabel,
            hintText: l10n.opdDateTimeHint,
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.opdNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.opdFollowUpAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    final DateTime? scheduledAt = DateTime.tryParse(
      _dateController.text.trim(),
    );
    if (scheduledAt == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .scheduleFollowUp(
          scheduledAt: scheduledAt,
          notes: _notesController.text.trim(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _AdmissionDialog extends ConsumerStatefulWidget {
  const _AdmissionDialog({required this.referenceData});

  final ClinicalReferenceData referenceData;

  @override
  ConsumerState<_AdmissionDialog> createState() => _AdmissionDialogState();
}

class _AdmissionDialogState extends ConsumerState<_AdmissionDialog> {
  String? _bedId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.clinicalRequestAdmissionAction),
      icon: const Icon(Icons.bed_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppSelectField<String>.searchable(
            value: _bedId,
            labelText: l10n.clinicalAvailableBedLabel,
            enabled: !_isSaving,
            options: _catalogOptions(widget.referenceData.availableBeds),
            onChanged: (String? value) => setState(() => _bedId = value),
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.clinicalRequestAdmissionAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    final ClinicalCatalogOption? bed = widget.referenceData.availableBeds
        .where((ClinicalCatalogOption option) => option.apiId == _bedId)
        .firstOrNull;
    if (bed == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .requestAdmission(bed);
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

List<Widget> _dialogActions(
  BuildContext context,
  String submitLabel,
  bool isSaving,
  VoidCallback onSubmit,
) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      isLoading: isSaving,
      onPressed: onSubmit,
    ),
  ];
}

Future<void> _openNoteDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClinicalNoteDialog(
        title: context.l10n.clinicalAddNoteTitle,
        label: context.l10n.opdClinicalNoteLabel,
        submitLabel: context.l10n.clinicalAddNoteAction,
        onSubmit: controller.addClinicalNote,
      ),
    ),
  );
}

Future<void> _openCompleteDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClinicalNoteDialog(
        title: context.l10n.clinicalCompleteConsultationAction,
        label: context.l10n.opdNotesLabel,
        submitLabel: context.l10n.clinicalCompleteConsultationAction,
        onSubmit: controller.completeConsultation,
      ),
    ),
  );
}

Future<void> _openDiagnosisDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DiagnosisDialog(),
    ),
  );
}

Future<void> _openProcedureDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProcedureDialog(),
    ),
  );
}

Future<void> _openCarePlanDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CarePlanDialog(),
    ),
  );
}

Future<void> _openLabDialog(
  BuildContext context,
  ClinicalReferenceData referenceData, {
  ClinicalRelatedRecord? existingOrder,
}) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LabOrderDialog(
        referenceData: referenceData,
        existingOrder: existingOrder,
      ),
    ),
  );
}

Future<void> _confirmLabOrderMutation({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  required Future<AppFailure?> Function() action,
}) async {
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: Text(title),
      icon: const Icon(Icons.science_outlined),
      content: Text(body),
      actions: <Widget>[
        AppButton.tertiary(
          label: context.l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: confirmLabel,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  final AppFailure? failure = await action();
  if (!context.mounted) {
    return;
  }
  if (failure == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.clinicalSavedMessage)));
    return;
  }
  _showFailureIfNeeded(context, failure);
}

Future<void> _openRadiologyDialog(
  BuildContext context,
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RadiologyOrderDialog(referenceData: referenceData),
    ),
  );
}

Future<void> _openPrescriptionDialog(
  BuildContext context,
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PrescriptionDialog(referenceData: referenceData),
    ),
  );
}

Future<void> _openReferralDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReferralDialog(),
    ),
  );
}

Future<void> _openFollowUpDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _FollowUpDialog(),
    ),
  );
}

Future<void> _openAdmissionDialog(
  BuildContext context,
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdmissionDialog(referenceData: referenceData),
    ),
  );
}

Future<void> _showActionResult(
  BuildContext context,
  Future<bool?> future,
) async {
  final bool? saved = await future;
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.clinicalSavedMessage)));
  }
}

AppSearchBarFilterValue _filterValueFromQuery(
  ClinicalWorklistFilters filters, {
  ClinicalQueueScope scope = ClinicalQueueScope.all,
  String search = '',
}) {
  return AppSearchBarFilterValue(
    field: filters.searchField,
    dateFrom: filters.dateFrom,
    dateTo: filters.dateTo,
    texts: <String, String>{
      if (_hasText(search)) _clinicalTextGeneral: search.trim(),
      if (_hasText(filters.patient)) _clinicalTextPatient: filters.patient!,
      if (_hasText(filters.patientIdentifier))
        _clinicalTextPatientIdentifier: filters.patientIdentifier!,
      if (_hasText(filters.patientPhone))
        _clinicalTextPatientPhone: filters.patientPhone!,
      if (_hasText(filters.encounter))
        _clinicalTextEncounter: filters.encounter!,
      if (_hasText(filters.queue)) _clinicalTextQueue: filters.queue!,
      if (_hasText(filters.providerText))
        _clinicalTextProvider: filters.providerText!,
      if (_hasText(filters.statusText))
        _clinicalTextStatus: filters.statusText!,
      if (_hasText(filters.location)) _clinicalTextLocation: filters.location!,
    },
    options: <String, String>{
      if (scope != ClinicalQueueScope.all) _clinicalFilterScope: scope.name,
      if (_hasText(filters.sourceQueue))
        _clinicalFilterSource: filters.sourceQueue!,
      if (_hasText(filters.status)) _clinicalFilterStatus: filters.status!,
      if (_hasText(filters.provider))
        _clinicalFilterProvider: filters.provider!,
    },
  );
}

ClinicalWorklistFilters _filtersFromValue(AppSearchBarFilterValue value) {
  return ClinicalWorklistFilters(
    searchField: value.field,
    dateFrom: value.dateFrom,
    dateTo: value.dateTo,
    patient: value.text(_clinicalTextPatient),
    patientIdentifier: value.text(_clinicalTextPatientIdentifier),
    patientPhone: value.text(_clinicalTextPatientPhone),
    encounter: value.text(_clinicalTextEncounter),
    queue: value.text(_clinicalTextQueue),
    providerText: value.text(_clinicalTextProvider),
    statusText: value.text(_clinicalTextStatus),
    location: value.text(_clinicalTextLocation),
    sourceQueue: value.option(_clinicalFilterSource),
    status: value.option(_clinicalFilterStatus),
    provider: value.option(_clinicalFilterProvider),
  );
}

String _searchFromValue(AppSearchBarFilterValue value) {
  return value.text(_clinicalTextGeneral)?.trim() ?? '';
}

AppSearchBarFilterValue _filterValueWithoutText(
  AppSearchBarFilterValue value,
  String key,
) {
  final Map<String, String> texts = Map<String, String>.of(value.texts)
    ..remove(key);
  return value.copyWith(texts: texts);
}

ClinicalQueueScope _scopeFromValue(AppSearchBarFilterValue value) {
  final String? scope = value.option(_clinicalFilterScope);
  if (scope == null) {
    return ClinicalQueueScope.all;
  }
  return ClinicalQueueScope.values.firstWhere(
    (ClinicalQueueScope candidate) => candidate.name == scope,
    orElse: () => ClinicalQueueScope.all,
  );
}

bool _hasActiveClinicalFilters(
  ClinicalWorklistFilters filters,
  ClinicalQueueScope scope, {
  String search = '',
}) {
  return filters.isActive ||
      scope != ClinicalQueueScope.all ||
      _hasText(search);
}

List<AppSearchBarTextFilter> _clinicalTextFilters(AppLocalizations l10n) {
  return <AppSearchBarTextFilter>[
    AppSearchBarTextFilter(
      key: _clinicalTextGeneral,
      label: l10n.clinicalSearchLabel,
      hintText: l10n.clinicalSearchHint,
      icon: Icons.manage_search_outlined,
      textInputAction: TextInputAction.search,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextPatient,
      label: l10n.opdPatientColumnLabel,
      hintText: l10n.patientsSearchHint,
      icon: Icons.person_search_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextPatientIdentifier,
      label: l10n.patientsPatientIdFilterLabel,
      icon: Icons.badge_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextPatientPhone,
      label: l10n.profilePhoneLabel,
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextEncounter,
      label: l10n.clinicalEncounterNumberLabel,
      icon: Icons.tag_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextQueue,
      label: l10n.clinicalSourceQueueLabel,
      icon: Icons.queue_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextProvider,
      label: l10n.opdProviderColumnLabel,
      icon: Icons.medical_information_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextStatus,
      label: l10n.opdStatusColumnLabel,
      icon: Icons.task_alt_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextLocation,
      label: l10n.clinicalLocationLabel,
      icon: Icons.location_on_outlined,
      textInputAction: TextInputAction.done,
    ),
  ];
}

List<AppSearchBarFilterGroup> _clinicalFilterGroups(
  AppLocalizations l10n,
  List<ClinicalWorklistEntry> entries, {
  bool includeScope = false,
}) {
  return <AppSearchBarFilterGroup>[
    if (includeScope)
      AppSearchBarFilterGroup(
        key: _clinicalFilterScope,
        label: l10n.clinicalScopeFilterLabel,
        allLabel: l10n.clinicalAllScopeLabel,
        choices: _scopeFilterChoices(l10n),
      ),
    AppSearchBarFilterGroup(
      key: _clinicalFilterSource,
      label: l10n.clinicalSourceQueueLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: _filterChoices(
        entries.map((ClinicalWorklistEntry entry) => entry.sourceQueue),
        icon: Icons.queue_outlined,
      ),
    ),
    AppSearchBarFilterGroup(
      key: _clinicalFilterStatus,
      label: l10n.opdStatusColumnLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: _filterChoices(
        entries.map(
          (ClinicalWorklistEntry entry) =>
              entry.stage ?? entry.status ?? entry.nextStep,
        ),
        icon: Icons.task_alt_outlined,
      ),
    ),
    AppSearchBarFilterGroup(
      key: _clinicalFilterProvider,
      label: l10n.opdProviderColumnLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: _filterChoices(
        entries.map((ClinicalWorklistEntry entry) => entry.providerDisplayName),
        icon: Icons.badge_outlined,
        formatApiLabel: false,
      ),
    ),
  ];
}

List<AppSearchBarFilterChoice> _scopeFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: ClinicalQueueScope.today.name,
      label: l10n.clinicalTodayScopeLabel,
      icon: Icons.today_outlined,
    ),
    AppSearchBarFilterChoice(
      value: ClinicalQueueScope.urgent.name,
      label: l10n.clinicalUrgentSummaryLabel,
      icon: Icons.priority_high_outlined,
    ),
    AppSearchBarFilterChoice(
      value: ClinicalQueueScope.waitingReview.name,
      label: l10n.clinicalWaitingReviewSummaryLabel,
      icon: Icons.rate_review_outlined,
    ),
    AppSearchBarFilterChoice(
      value: ClinicalQueueScope.inConsultation.name,
      label: l10n.clinicalInConsultationSummaryLabel,
      icon: Icons.medical_information_outlined,
    ),
    AppSearchBarFilterChoice(
      value: ClinicalQueueScope.resultsReady.name,
      label: l10n.clinicalResultsReadySummaryLabel,
      icon: Icons.science_outlined,
    ),
    AppSearchBarFilterChoice(
      value: ClinicalQueueScope.completed.name,
      label: l10n.clinicalCompletedSummaryLabel,
      icon: Icons.task_alt_outlined,
    ),
  ];
}

List<AppSearchBarFilterChoice> _filterChoices(
  Iterable<String?> values, {
  required IconData icon,
  bool formatApiLabel = true,
}) {
  final List<String> normalized =
      values
          .map((String? value) => value?.trim() ?? '')
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort((String left, String right) => left.compareTo(right));

  return <AppSearchBarFilterChoice>[
    for (final String value in normalized)
      AppSearchBarFilterChoice(
        value: value,
        label: formatApiLabel ? _apiLabel(value) : value,
        icon: icon,
      ),
  ];
}

final class _ClinicalSummaryDialogConfig {
  const _ClinicalSummaryDialogConfig({
    required this.title,
    required this.emptyTitle,
    required this.icon,
  });

  final String title;
  final String emptyTitle;
  final IconData icon;
}

_ClinicalSummaryDialogConfig _summaryDialogConfig(
  AppLocalizations l10n,
  _ClinicalSummaryCategory category,
) {
  return switch (category) {
    _ClinicalSummaryCategory.waitingReview => _ClinicalSummaryDialogConfig(
      title: l10n.clinicalWaitingReviewSummaryLabel,
      emptyTitle: l10n.clinicalNoWorklistTitle,
      icon: Icons.rate_review_outlined,
    ),
    _ClinicalSummaryCategory.urgent => _ClinicalSummaryDialogConfig(
      title: l10n.clinicalUrgentSummaryLabel,
      emptyTitle: l10n.clinicalNoWorklistTitle,
      icon: Icons.priority_high_outlined,
    ),
    _ClinicalSummaryCategory.resultsReady => _ClinicalSummaryDialogConfig(
      title: l10n.clinicalResultsReadySummaryLabel,
      emptyTitle: l10n.clinicalNoWorklistTitle,
      icon: Icons.science_outlined,
    ),
    _ClinicalSummaryCategory.inConsultation => _ClinicalSummaryDialogConfig(
      title: l10n.clinicalInConsultationSummaryLabel,
      emptyTitle: l10n.clinicalNoWorklistTitle,
      icon: Icons.medical_information_outlined,
    ),
  };
}

bool _matchesSummaryCategory(
  ClinicalWorklistEntry item,
  _ClinicalSummaryCategory category,
) {
  if (item.isTerminal) {
    return false;
  }
  return switch (category) {
    _ClinicalSummaryCategory.waitingReview => clinicalWorklistEntryMatchesScope(
      item,
      ClinicalQueueScope.waitingReview,
    ),
    _ClinicalSummaryCategory.urgent => item.isUrgent,
    _ClinicalSummaryCategory.resultsReady => item.resultsReady,
    _ClinicalSummaryCategory.inConsultation =>
      clinicalWorklistEntryMatchesScope(
        item,
        ClinicalQueueScope.inConsultation,
      ),
  };
}

List<AppSelectOption<String>> _catalogOptions(
  List<ClinicalCatalogOption> options,
) {
  return <AppSelectOption<String>>[
    for (final ClinicalCatalogOption option in options)
      AppSelectOption<String>(
        value: option.apiId,
        label: _joinDisplay(<String?>[
          option.displayTitle,
          option.displaySubtitle,
        ]),
      ),
  ];
}


List<AppSelectOption<String>> _drugCatalogOptions(
  List<ClinicalCatalogOption> options,
) {
  return <AppSelectOption<String>>[
    for (final ClinicalCatalogOption option in options)
      AppSelectOption<String>(
        value: option.apiId,
        label: _joinDisplay(<String?>[
          option.displayTitle,
          option.displaySubtitle,
        ]),
        leadingIcon: const Icon(Icons.medication_outlined),
      ),
  ];
}

String? _catalogDisplayLabelById(
  List<ClinicalCatalogOption> options,
  String? apiId,
) {
  if (apiId == null) {
    return null;
  }
  for (final ClinicalCatalogOption option in options) {
    if (option.apiId == apiId) {
      return _joinDisplay(<String?>[option.displayTitle, option.displaySubtitle]);
    }
  }
  return null;
}

List<AppSelectOption<String>> _unitOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: value),
  ];
}

List<AppSelectOption<String>> _durationUnitOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _durationUnits)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: const Icon(Icons.event_repeat_outlined),
      ),
  ];
}

List<AppSelectOption<String>> _medicationRouteOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _medicationRoutes)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_medicationRouteIcon(value)),
      ),
  ];
}

List<AppSelectOption<String>> _medicationFrequencyOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _medicationFrequencies)
      AppSelectOption<String>(
        value: value,
        label: _medicationFrequencyLabel(value),
        leadingIcon: Icon(_medicationFrequencyIcon(value)),
      ),
  ];
}

String _medicationFrequencyLabel(String value) {
  final String? description = switch (value) {
    'ONCE' => 'One time',
    'OD' => 'Once daily',
    'BID' => 'Twice daily',
    'TID' => 'Three times daily',
    'QID' => 'Four times daily',
    'Q4H' => 'Every 4 hours',
    'Q6H' => 'Every 6 hours',
    'Q8H' => 'Every 8 hours',
    'Q12H' => 'Every 12 hours',
    'QHS' => 'At bedtime',
    'WEEKLY' => 'Weekly',
    'PRN' => 'As needed',
    'STAT' => 'Immediately',
    'CUSTOM' => 'Custom',
    _ => null,
  };
  return description == null ? _apiLabel(value) : '$value - $description';
}

IconData _medicationFrequencyIcon(String value) {
  return switch (value) {
    'STAT' => Icons.priority_high_outlined,
    'PRN' => Icons.help_outline,
    'Q4H' || 'Q6H' || 'Q8H' || 'Q12H' || 'QHS' => Icons.schedule_outlined,
    'WEEKLY' => Icons.event_repeat_outlined,
    'CUSTOM' => Icons.tune_outlined,
    _ => Icons.repeat_outlined,
  };
}

IconData _medicationRouteIcon(String value) {
  return switch (value) {
    'IV' => Icons.water_drop_outlined,
    'IM' || 'SC' || 'INTRADERMAL' => Icons.vaccines_outlined,
    'TOPICAL' => Icons.spa_outlined,
    'INHALATION' || 'NASAL' => Icons.air_outlined,
    'OPHTHALMIC' => Icons.visibility_outlined,
    'OTIC' => Icons.hearing_outlined,
    'ORAL' || 'SUBLINGUAL' => Icons.medication_outlined,
    _ => Icons.medical_services_outlined,
  };
}

String? _requiredPositiveIntegerValidator(
  AppLocalizations l10n,
  String? value,
) {
  final String normalized = value?.trim() ?? '';
  final int? parsed = int.tryParse(normalized);
  return parsed == null || parsed <= 0 ? l10n.validationRequired : null;
}

String? _optionalPositiveIntegerValidator(
  AppLocalizations l10n,
  String? value,
) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final int? parsed = int.tryParse(normalized);
  return parsed == null || parsed <= 0 ? l10n.validationRequired : null;
}

String? _requiredPositiveNumberValidator(
  AppLocalizations l10n,
  String? value,
) {
  final String normalized = value?.trim() ?? '';
  final num? parsed = num.tryParse(normalized);
  return parsed == null || parsed <= 0 ? l10n.validationRequired : null;
}

Map<String, Object?> _withoutEmptyValues(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPrescriptionValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPrescriptionValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable<Object?>) {
    return value.isEmpty;
  }
  if (value is Map<Object?, Object?>) {
    return value.isEmpty;
  }
  return false;
}

List<ClinicalCatalogOption> _mergeCatalogOption(
  List<ClinicalCatalogOption> options,
  ClinicalCatalogOption option,
) {
  if (options.any((ClinicalCatalogOption item) => item.apiId == option.apiId)) {
    return options;
  }
  return <ClinicalCatalogOption>[option, ...options];
}

String _diagnosisTermLabel(ClinicalCatalogOption option) {
  return _trimmedOrNull(option.name) ?? option.displayTitle;
}

String _diagnosisTermSubtitle(ClinicalCatalogOption option) {
  return _joinDisplay(<String?>[option.code, option.displaySubtitle]);
}

String _diagnosisCodeLabel(ClinicalCatalogOption option) {
  return _trimmedOrNull(option.code) ?? option.displayTitle;
}

String _diagnosisCodeSubtitle(ClinicalCatalogOption option) {
  return _joinDisplay(<String?>[option.name, option.displaySubtitle]);
}

String? _trimmedOrNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

List<AppWorkspacePatientContextField> _clinicalPatientContextFields(
  BuildContext context,
  AppLocalizations l10n,
  ClinicalWorklistEntry entry,
) {
  final String age = _clinicalAgeLabel(entry.patientDateOfBirth);
  final String gender = _clinicalGenderLabel(l10n, entry.patientGender);
  final bool hasStructuredDemographics = age.isNotEmpty || gender.isNotEmpty;
  final DateTime? lastUpdated = entry.updatedAt ?? entry.startedAt;

  return <AppWorkspacePatientContextField>[
    AppWorkspacePatientContextField(
      label: l10n.clinicalEncounterNumberLabel,
      value: entry.encounterPublicId ?? entry.encounterId,
      icon: Icons.tag_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalEncounterQueueLabel,
      value: _apiLabel(entry.sourceQueue),
      icon: Icons.queue_outlined,
      tone: _sourceQueueTone(entry.sourceQueue),
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalAgeLabel,
      value: age,
      icon: Icons.cake_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.patientsGenderLabel,
      value: gender,
      icon: Icons.wc_outlined,
    ),
    if (!hasStructuredDemographics)
      AppWorkspacePatientContextField(
        label: l10n.patientsAgeSexColumnLabel,
        value: entry.patientAgeSex ?? '',
        icon: Icons.badge_outlined,
      ),
    AppWorkspacePatientContextField(
      label: l10n.patientsPhoneLabel,
      value: entry.patientPhone ?? '',
      icon: Icons.phone_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.patientsDobLabel,
      value: entry.patientDateOfBirth == null
          ? ''
          : AppFormatters.mediumDate(
              entry.patientDateOfBirth!,
              Localizations.localeOf(context),
            ),
      icon: Icons.event_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalEncounterTypeLabel,
      value: _apiLabel(entry.encounterType ?? ''),
      icon: Icons.local_hospital_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalLocationLabel,
      value: entry.currentLocation ?? '',
      icon: Icons.location_on_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.opdProviderColumnLabel,
      value: entry.providerDisplayName ?? '',
      icon: Icons.badge_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.opdStageLabel,
      value: _apiLabel(entry.stage ?? entry.nextStep ?? ''),
      icon: Icons.timeline_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalLastUpdatedLabel,
      value: lastUpdated == null ? '' : _dateTimeLabel(context, lastUpdated),
      icon: Icons.schedule_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalAdmissionNumberLabel,
      value: entry.admissionPublicId ?? entry.admissionId ?? '',
      icon: Icons.bed_outlined,
    ),
  ];
}

String _clinicalAgeLabel(DateTime? birthDate) {
  if (birthDate == null) {
    return '';
  }

  final DateTime today = DateTime.now();
  int age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age -= 1;
  }

  return age < 0 ? '' : age.toString();
}

String _clinicalGenderLabel(AppLocalizations l10n, String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'MALE' => l10n.patientsGenderMale,
    'FEMALE' => l10n.patientsGenderFemale,
    'OTHER' => l10n.patientsGenderOther,
    'UNKNOWN' => l10n.patientsGenderUnknown,
    final String normalized when normalized.isNotEmpty => _apiLabel(value!),
    _ => '',
  };
}

Future<void> _copyClinicalPatientId(
  BuildContext context,
  String patientId,
) async {
  await Clipboard.setData(ClipboardData(text: patientId));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(context.l10n.clinicalPatientIdCopiedMessage)),
    );
}

AppWorkspaceStatus _entryStatus(ClinicalWorklistEntry item) {
  final String value =
      item.stage ?? item.status ?? item.nextStep ?? item.sourceQueue;
  return AppWorkspaceStatus(label: _apiLabel(value), tone: _statusTone(value));
}

bool _isSameWorklistEntry(
  ClinicalWorklistEntry left,
  ClinicalWorklistEntry right,
) {
  return left.sourceQueue == right.sourceQueue &&
      left.encounterId == right.encounterId;
}

AppWorkspaceStatusTone _sourceQueueTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'OPD' => AppWorkspaceStatusTone.info,
    'TRIAGE' || 'EMERGENCY' => AppWorkspaceStatusTone.warning,
    'IPD' || 'ADMISSION' => AppWorkspaceStatusTone.success,
    'ICU' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _statusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'COMPLETED' ||
    'DISCHARGED' ||
    'CLOSED' ||
    'NORMAL' => AppWorkspaceStatusTone.success,
    'CANCELLED' || 'CRITICAL' => AppWorkspaceStatusTone.error,
    'URGENT' ||
    'WAITING_DOCTOR_REVIEW' ||
    'WAITING_DISPOSITION' ||
    'ADMITTED' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' ||
    'ORDERED' ||
    'COLLECTED' ||
    'IN_PROCESS' ||
    'OPEN' => AppWorkspaceStatusTone.info,
    'PENDING' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _effectiveLabOrderItemStatus(
  ClinicalLabOrderItem item,
  String? orderStatus,
) {
  final String itemStatus = (item.status ?? '').trim();
  final String normalizedOrderStatus = (orderStatus ?? '').toUpperCase();
  if (normalizedOrderStatus == 'CANCELLED' &&
      itemStatus.toUpperCase() != 'COMPLETED') {
    return 'CANCELLED';
  }
  if (itemStatus.isNotEmpty) {
    return itemStatus;
  }
  return (orderStatus ?? '').trim().isEmpty ? 'ORDERED' : orderStatus!.trim();
}

String? _resultStatusLabel(ClinicalLabOrderItem item, String itemStatus) {
  final String? resultStatus = item.resultStatus;
  if (!_hasText(resultStatus)) {
    return null;
  }
  if (resultStatus!.toUpperCase() == itemStatus.toUpperCase()) {
    return null;
  }
  return 'Result ${_apiLabel(resultStatus)}';
}

AppWorkspaceStatusTone _clinicalVitalTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'ABNORMAL' => AppWorkspaceStatusTone.warning,
    'NORMAL' => AppWorkspaceStatusTone.success,
    'RECORDED' => AppWorkspaceStatusTone.info,
    _ => _statusTone(value),
  };
}

AppWorkspaceStatusTone _clinicalAlertTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'CRITICAL' || 'HIGH' => AppWorkspaceStatusTone.error,
    'MEDIUM' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.info,
    _ => _statusTone(value),
  };
}

IconData _recordIcon(String kind) {
  return switch (kind) {
    'clinical_note' => Icons.edit_note_outlined,
    'diagnosis' => Icons.rule_outlined,
    'procedure' => Icons.healing_outlined,
    'care_plan' => Icons.playlist_add_check_outlined,
    'lab_order' => Icons.science_outlined,
    'radiology_order' => Icons.biotech_outlined,
    'pharmacy_order' => Icons.medication_outlined,
    'referral' => Icons.alt_route_outlined,
    'follow_up' => Icons.event_repeat_outlined,
    'admission' => Icons.bed_outlined,
    _ => Icons.description_outlined,
  };
}

IconData _radiologyCatalogIcon(ClinicalCatalogOption option) {
  return switch ((option.category ?? '').toUpperCase()) {
    'XRAY' => Icons.photo_camera_outlined,
    'CT' => Icons.donut_large_outlined,
    'MRI' => Icons.all_out_outlined,
    'ULTRASOUND' => Icons.graphic_eq_outlined,
    'FLUOROSCOPY' => Icons.video_camera_back_outlined,
    'MAMMOGRAPHY' => Icons.image_search_outlined,
    'PET' || 'NUCLEAR_MEDICINE' => Icons.blur_on_outlined,
    'INTERVENTIONAL_RADIOLOGY' => Icons.medical_services_outlined,
    'ECG' => Icons.monitor_heart_outlined,
    'ECHO' => Icons.favorite_border,
    'ENDO' || 'GASTRO' => Icons.biotech_outlined,
    _ => Icons.biotech_outlined,
  };
}

List<ClinicalCatalogOption> _requestedPanelsForOrder(
  ClinicalRelatedRecord order,
  ClinicalReferenceData referenceData,
) {
  final Set<String> itemIds = order.labOrderItems
      .map((ClinicalLabOrderItem item) => item.labTestId)
      .whereType<String>()
      .map(_normalizedCatalogToken)
      .where((String value) => value.isNotEmpty)
      .toSet();
  final Set<String> itemCodes = order.labOrderItems
      .map((ClinicalLabOrderItem item) => item.testCode)
      .whereType<String>()
      .map(_normalizedCatalogToken)
      .where((String value) => value.isNotEmpty)
      .toSet();

  return referenceData.labPanels
      .where((ClinicalCatalogOption panel) {
        final Set<String> panelIds = panel.childIds
            .map(_normalizedCatalogToken)
            .where((String value) => value.isNotEmpty)
            .toSet();
        final Set<String> panelCodes = panel.childCodes
            .map(_normalizedCatalogToken)
            .where((String value) => value.isNotEmpty)
            .toSet();
        if (panelIds.length <= 1 && panelCodes.length <= 1) {
          return false;
        }
        final bool idsMatch =
            panelIds.isNotEmpty && panelIds.every(itemIds.contains);
        final bool codesMatch =
            panelCodes.isNotEmpty && panelCodes.every(itemCodes.contains);
        return idsMatch || codesMatch;
      })
      .toList(growable: false);
}

String _normalizedCatalogToken(String value) {
  return value.trim().toUpperCase();
}

bool _canEditLabOrder(String? status) {
  return (status ?? '').toUpperCase() == 'ORDERED';
}

bool _canCancelLabOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' || 'CANCELLED' => false,
    _ => true,
  };
}

bool _canDeleteLabOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'CANCELLED' => true,
    _ => false,
  };
}

String _countLabel(BuildContext context, int value) {
  return AppFormatters.compactNumber(value, Localizations.localeOf(context));
}

String _pageLabel(BuildContext context, AppPage<ClinicalWorklistEntry> page) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }
  final int from = page.request.pageIndex * page.request.pageSize + 1;
  final int to = (from + page.items.length - 1).clamp(from, total).toInt();
  return context.l10n.opdPageLabel(from, to, total);
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined;
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _consultationSummaryHtml(
  BuildContext context,
  ClinicalEncounterBundle bundle,
) {
  final AppLocalizations l10n = context.l10n;
  final StringBuffer buffer = StringBuffer()
    ..write(
      PrintFormTemplate.section(
        title: l10n.clinicalPatientNotesTitle,
        bodyHtml: _recordsHtml(bundle.clinicalNotes),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: l10n.clinicalPatientDiagnosesTitle,
        bodyHtml: _recordsHtml(bundle.diagnoses),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: l10n.clinicalOrdersTitle,
        bodyHtml: _recordsHtml(<ClinicalRelatedRecord>[
          ...bundle.labOrders,
          ...bundle.radiologyOrders,
          ...bundle.pharmacyOrders,
        ]),
      ),
    );
  return buffer.toString();
}

String _recordsHtml(List<ClinicalRelatedRecord> records) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final ClinicalRelatedRecord record in records)
      _joinDisplay(<String?>[
        record.title,
        record.subtitle,
        record.status == null ? null : _apiLabel(record.status!),
      ]),
  ], emptyText: 'No records.');
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

const List<String> _diagnosisTypes = <String>[
  'PRIMARY',
  'SECONDARY',
  'DIFFERENTIAL',
];

const List<String> _medicationFrequencies = <String>[
  'ONCE',
  'OD',
  'BID',
  'TID',
  'QID',
  'Q4H',
  'Q6H',
  'Q8H',
  'Q12H',
  'QHS',
  'WEEKLY',
  'PRN',
  'STAT',
  'CUSTOM',
];

const List<String> _medicationRoutes = <String>[
  'ORAL',
  'IV',
  'IM',
  'SC',
  'SUBLINGUAL',
  'RECTAL',
  'VAGINAL',
  'TOPICAL',
  'INHALATION',
  'OPHTHALMIC',
  'OTIC',
  'NASAL',
  'INTRADERMAL',
  'OTHER',
];

const List<String> _quantityUnits = <String>[
  'tablet',
  'capsule',
  'vial',
  'ampoule',
  'bottle',
  'tube',
  'sachet',
  'patch',
  'drop',
  'mL',
  'dose',
  'pack',
];

const List<String> _doseUnits = <String>[
  'mg',
  'g',
  'mcg',
  'mL',
  'IU',
  'unit',
  'tablet',
  'capsule',
  'drop',
  'puff',
  'sachet',
  'patch',
];

const List<String> _durationUnits = <String>[
  'hours',
  'days',
  'weeks',
  'months',
];

const String _clinicalTextGeneral = 'general';
const String _clinicalTextPatient = 'patient';
const String _clinicalTextPatientIdentifier = 'patient_identifier';
const String _clinicalTextPatientPhone = 'patient_phone';
const String _clinicalTextEncounter = 'encounter';
const String _clinicalTextQueue = 'queue';
const String _clinicalTextProvider = 'provider_text';
const String _clinicalTextStatus = 'status_text';
const String _clinicalTextLocation = 'location';
const String _clinicalFilterScope = 'scope';
const String _clinicalFilterSource = 'source';
const String _clinicalFilterStatus = 'status';
const String _clinicalFilterProvider = 'provider';

final List<TextInputFormatter> _integerFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

final List<TextInputFormatter> _decimalFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];

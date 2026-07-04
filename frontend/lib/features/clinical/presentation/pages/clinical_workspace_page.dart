import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
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
import 'package:hosspi_hms/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class ClinicalWorkspacePage extends ConsumerWidget {
  const ClinicalWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    ref.listen<AsyncValue<Result<ClinicalWorkspaceState>>>(
      clinicalWorkspaceControllerProvider,
      (
        AsyncValue<Result<ClinicalWorkspaceState>>? previous,
        AsyncValue<Result<ClinicalWorkspaceState>> next,
      ) {
        final String? notice = next.asData?.value.when(
          success: (ClinicalWorkspaceState value) => value.realtimeNotice,
          failure: (_) => null,
        );
        if (notice == null || notice.isEmpty) {
          return;
        }
        final List<String> parts = notice.split('::');
        if (parts.length < 2) {
          return;
        }
        final String patientName = parts.sublist(1).join('::');
        final String message = switch (parts.first) {
          'LAB_RESULT_CRITICAL' => l10n.clinicalLabResultCriticalNotice(
            patientName,
          ),
          'LAB_RESULT_READY' => l10n.clinicalLabResultReadyNotice(patientName),
          _ => l10n.clinicalLabResultUpdatedNotice(patientName),
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        ref
            .read(clinicalWorkspaceControllerProvider.notifier)
            .clearRealtimeNotice();
      },
    );
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
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.systemAdmin,
    ],
    activeModules: <String>['encounters-vitals'],
  );

  static const AccessRequirement _labOrderRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.systemAdmin,
    ],
    activeModules: <String>['encounters-vitals', 'lab-workflows'],
  );

  static const AccessRequirement _prescribeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.systemAdmin,
    ],
    activeModules: <String>['encounters-vitals', 'pharmacy-dispensing'],
  );

  static const AccessRequirement _radiologyOrderRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.systemAdmin,
    ],
    activeModules: <String>['encounters-vitals', 'radiology-workflows'],
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

  Widget _clinicalToolbarButton({
    required AccessRequirement requirement,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalWorkspaceState state = widget.state;
    final bool hasSelection = state.selectedBundle != null;

    return AppAccessActionGate(
      requirement: requirement,
      builder: (BuildContext context, bool isAllowed) {
        final bool enabled = isAllowed && hasSelection && !state.isSaving;
        final String tooltip = !isAllowed
            ? l10n.tenantFacilityPermissionDenied
            : !hasSelection
            ? l10n.clinicalNoSelectionTitle
            : label;

        return AppButton.secondary(
          label: label,
          leadingIcon: icon,
          semanticLabel: label,
          tooltip: tooltip,
          enabled: enabled,
          onPressed: enabled ? onPressed : null,
        );
      },
    );
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
      leadingIcon: AppRouteIcons.clinical,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: <AppWorkspaceSummaryNotification>[
          if (_pageTotal(state.worklist) > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.clinicalAllScopeLabel,
              count: _pageTotal(state.worklist),
              icon: Icons.inventory_2_outlined,
              onSelected: () => controller.applyScope(ClinicalQueueScope.all),
            ),
          if (state.waitingReviewCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.clinicalWaitingReviewSummaryLabel,
              count: state.waitingReviewCount,
              icon: Icons.rate_review_outlined,
              tone: AppWorkspaceStatusTone.info,
              onSelected: () =>
                  controller.applyScope(ClinicalQueueScope.waitingReview),
            ),
          if (state.urgentCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.clinicalUrgentSummaryLabel,
              count: state.urgentCount,
              icon: Icons.priority_high_outlined,
              tone: AppWorkspaceStatusTone.error,
              onSelected: () =>
                  controller.applyScope(ClinicalQueueScope.urgent),
            ),
          if (state.resultsReadyCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.clinicalResultsReadySummaryLabel,
              count: state.resultsReadyCount,
              icon: Icons.science_outlined,
              tone: AppWorkspaceStatusTone.success,
              onSelected: () =>
                  controller.applyScope(ClinicalQueueScope.resultsReady),
            ),
          if (state.inConsultationCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.clinicalInConsultationSummaryLabel,
              count: state.inConsultationCount,
              icon: Icons.medical_information_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onSelected: () =>
                  controller.applyScope(ClinicalQueueScope.inConsultation),
            ),
        ],
        secondary: <Widget>[
          _clinicalToolbarButton(
            requirement: _writeRequirement,
            label: l10n.clinicalAddNoteAction,
            icon: Icons.note_add_outlined,
            onPressed: () => _openNoteDialog(context, controller),
          ),
          _clinicalToolbarButton(
            requirement: _labOrderRequirement,
            label: l10n.clinicalRequestLabAction,
            icon: Icons.science_outlined,
            onPressed: () =>
                _openLabDialog(context, controller, state.referenceData),
          ),
          _clinicalToolbarButton(
            requirement: _prescribeRequirement,
            label: l10n.clinicalPrescribeAction,
            icon: Icons.medication_outlined,
            onPressed: () => _openPrescriptionDialog(
              context,
              controller,
              state.referenceData,
            ),
          ),
          _clinicalToolbarButton(
            requirement: _radiologyOrderRequirement,
            label: l10n.clinicalRequestRadiologyAction,
            icon: Icons.biotech_outlined,
            onPressed: () =>
                _openRadiologyDialog(context, controller, state.referenceData),
          ),
        ],
        onRefresh: () async {
          final AppFailure? failure = await controller.refresh();
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        isRefreshing: state.isRefreshing,
      ),

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
      child: AppWorkspaceDetailPanel(
        title: l10n.clinicalWorklistTitle,
        description: l10n.clinicalWorklistDescription,
        child: AppListTable<ClinicalWorklistEntry>(
          page: state.worklist,
          columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
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
      sortComparator:
          (ClinicalWorklistEntry left, ClinicalWorklistEntry right) =>
              appListTableCompareText(left.displayTitle, right.displayTitle),
      cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
        return _ClinicalPatientCell(item: item);
      },
    ),
    AppListTableColumn<ClinicalWorklistEntry>(
      label: l10n.clinicalSourceQueueLabel,
      sortComparator:
          (ClinicalWorklistEntry left, ClinicalWorklistEntry right) =>
              appListTableCompareText(left.sourceQueue, right.sourceQueue),
      cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
        return _ClinicalQueueCell(item: item);
      },
    ),
    AppListTableColumn<ClinicalWorklistEntry>(
      label: l10n.opdStatusColumnLabel,
      sortComparator:
          (ClinicalWorklistEntry left, ClinicalWorklistEntry right) =>
              appListTableCompareText(
                left.stage ?? left.status ?? left.nextStep,
                right.stage ?? right.status ?? right.nextStep,
              ),
      cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
        return _ClinicalStatusCell(item: item);
      },
    ),
    AppListTableColumn<ClinicalWorklistEntry>(
      label: l10n.opdProviderColumnLabel,
      sortComparator:
          (ClinicalWorklistEntry left, ClinicalWorklistEntry right) =>
              appListTableCompareText(
                left.providerDisplayName,
                right.providerDisplayName,
              ),
      cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
        return Text(item.providerDisplayName ?? l10n.profileUnknownValue);
      },
    ),
    AppListTableColumn<ClinicalWorklistEntry>(
      label: l10n.clinicalLastUpdatedLabel,
      sortComparator:
          (ClinicalWorklistEntry left, ClinicalWorklistEntry right) =>
              appListTableCompareDateTime(
                left.updatedAt ?? left.startedAt,
                right.updatedAt ?? right.startedAt,
              ),
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
    return _ClinicalStatusText(
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
        _ClinicalStatusText(status: _entryStatus(item)),
        if (item.isUrgent)
          _ClinicalStatusText(
            status: AppWorkspaceStatus(
              label: l10n.clinicalUrgentSummaryLabel,
              tone: AppWorkspaceStatusTone.error,
              icon: Icons.priority_high_outlined,
            ),
          ),
        if (item.resultsReady)
          _ClinicalStatusText(
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

class _ClinicalStatusText extends StatelessWidget {
  const _ClinicalStatusText({required this.status, this.textStyle});

  final AppWorkspaceStatus status;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _clinicalToneColor(theme, status.tone);
    final IconData icon = status.icon ?? _clinicalStatusIcon(status.tone);
    final TextStyle? effectiveStyle = (textStyle ?? theme.textTheme.labelLarge)
        ?.copyWith(color: color, fontWeight: FontWeight.w700);

    return Semantics(
      label: status.label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: theme.appTokens.listIconSize, color: color),
          SizedBox(width: theme.spacing.xs),
          Text(
            status.label,
            overflow: TextOverflow.ellipsis,
            style: effectiveStyle,
          ),
        ],
      ),
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
      vertical: theme.spacing.xs,
    ),
    child: AppListItemRow(
      title: item.displayTitle,
      subtitle: item.patientPublicId ?? item.encounterPublicId,
      padding: EdgeInsets.zero,
      details: <Widget>[_ClinicalStatusCell(item: item)],
      trailing: Icon(Icons.chevron_right, size: theme.appTokens.listIconSize),
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
                if (!state.isRefreshingDetail && !state.isSaving) {
                  return AppWorkspaceStatePanel.state(
                    variant: AppStateViewVariant.empty,
                    title: l10n.clinicalNoSelectionTitle,
                    body: l10n.clinicalNoSelectionBody,
                    icon: Icons.medical_services_outlined,
                  );
                }
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
    final AppWorkspaceStatus primaryStatus = _entryStatus(entry);
    final List<Widget> sections = <Widget>[
      _ClinicalEncounterContextPanel(
        entry: entry,
        status: primaryStatus,
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
      ),
      if (bundle.triageHandoff?.hasContent ?? false)
        _ClinicalTriageHandoffPanel(
          handoff: bundle.triageHandoff!,
          primaryStatus: primaryStatus,
        ),
      _ClinicalActionBar(bundle: bundle, referenceData: state.referenceData),
      if (bundle.labOrders.isNotEmpty)
        _ClinicalLabOrdersPanel(
          bundle: bundle,
          referenceData: state.referenceData,
        ),
      if (_clinicalCompletedResults(bundle).isNotEmpty)
        _ClinicalResultReview(bundle: bundle),
      if (_clinicalHasRecordSections(bundle))
        _ClinicalRecordSections(bundle: bundle),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withClinicalSectionSpacing(context, sections),
    );
  }
}

class _ClinicalEncounterContextPanel extends StatelessWidget {
  const _ClinicalEncounterContextPanel({
    required this.entry,
    required this.status,
    this.alerts = const <AppWorkspaceStatus>[],
  });

  final ClinicalWorklistEntry entry;
  final AppWorkspaceStatus status;
  final List<AppWorkspaceStatus> alerts;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String patientNumber = _clinicalPatientNumber(entry);
    final List<AppWorkspacePatientContextField> fields =
        _clinicalPatientContextFields(context, l10n, entry);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: theme.spacing.md,
              runSpacing: theme.spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (patientNumber.isNotEmpty)
                  _ClinicalCopyableInlineValue(
                    label: l10n.opdPatientIdLabel,
                    value: patientNumber,
                    onCopy: () =>
                        _copyClinicalPatientId(context, patientNumber),
                  ),
                AppWorkspaceStatusBadge(status: status),
                for (final AppWorkspaceStatus alert in alerts)
                  AppWorkspaceStatusBadge(status: alert),
              ],
            ),
            if (fields.any(
              (AppWorkspacePatientContextField field) => field.hasValue,
            )) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              _ClinicalInfoGrid(fields: fields),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClinicalCopyableInlineValue extends StatelessWidget {
  const _ClinicalCopyableInlineValue({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Semantics(
      label: '$label: $value',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '$label  ',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: theme.spacing.xs),
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.copy_outlined,
              label: MaterialLocalizations.of(context).copyButtonLabel,
              semanticLabel: MaterialLocalizations.of(context).copyButtonLabel,
              tooltip: MaterialLocalizations.of(context).copyButtonLabel,
              onPressed: onCopy,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicalInfoGrid extends StatelessWidget {
  const _ClinicalInfoGrid({required this.fields});

  final List<AppWorkspacePatientContextField> fields;

  @override
  Widget build(BuildContext context) {
    final List<AppWorkspacePatientContextField> visibleFields = fields
        .where((AppWorkspacePatientContextField field) => field.hasValue)
        .toList(growable: false);
    if (visibleFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppInfoTileGrid(
      minItemWidth: 180,
      borderedTiles: false,
      items: <AppInfoTileData>[
        for (final AppWorkspacePatientContextField field in visibleFields)
          AppInfoTileData(
            label: field.label,
            value: field.value,
            icon: field.icon,
          ),
      ],
    );
  }
}

class _ClinicalTriageHandoffPanel extends StatelessWidget {
  const _ClinicalTriageHandoffPanel({
    required this.handoff,
    required this.primaryStatus,
  });

  final ClinicalTriageHandoff handoff;
  final AppWorkspaceStatus primaryStatus;

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
    final AppWorkspaceStatus vitalStatus = AppWorkspaceStatus(
      label: _apiLabel(abnormalVitalCount > 0 ? 'ABNORMAL' : 'NORMAL'),
      tone: abnormalVitalCount > 0
          ? AppWorkspaceStatusTone.warning
          : AppWorkspaceStatusTone.success,
    );
    final bool stageRepeatsPrimaryStatus =
        opdStageDisplayLabel(l10n, handoff.stage) == primaryStatus.label;
    final List<AppWorkspacePatientContextField> facts =
        <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: l10n.opdTriageLevelLabel,
            value: triageLevelDisplayLabel(
              l10n,
              handoff.triageLevel,
              emptyAsPending: false,
            ),
            icon: Icons.priority_high_outlined,
            tone: appTriageToneForValue(handoff.triageLevel),
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdRouteDecisionLabel,
            value: _apiLabel(handoff.routeTo ?? ''),
            icon: Icons.alt_route_outlined,
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdChiefComplaintLabel,
            value: handoff.chiefComplaint ?? '',
            icon: Icons.sick_outlined,
          ),
          if (!stageRepeatsPrimaryStatus)
            AppWorkspacePatientContextField(
              label: l10n.opdStageLabel,
              value: opdStageDisplayLabel(l10n, handoff.stage),
              icon: Icons.timeline_outlined,
            ),
          AppWorkspacePatientContextField(
            label: l10n.opdNextStepColumnLabel,
            value: opdNextStepDisplayLabel(l10n, handoff.nextStep),
            icon: Icons.trending_flat_outlined,
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdTimeColumnLabel,
            value: handoff.queuedAt == null
                ? ''
                : _dateTimeLabel(context, handoff.queuedAt),
            icon: Icons.schedule_outlined,
          ),
          if (handoff.emergencyIndicator)
            AppWorkspacePatientContextField(
              label: l10n.opdEmergencyIndicatorsLabel,
              value: l10n.opdTriageScopeEmergency,
              icon: Icons.emergency_outlined,
              tone: AppWorkspaceStatusTone.error,
            ),
          AppWorkspacePatientContextField(
            label: l10n.opdTriageNotesLabel,
            value: handoff.triageNotes ?? '',
            icon: Icons.notes_outlined,
          ),
        ];

    return AppWorkspaceDetailPanel(
      title: l10n.opdWorkflowTriageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ClinicalInfoGrid(fields: facts),
          if (handoff.vitalSigns.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  l10n.opdVitalsSummaryLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _ClinicalStatusText(status: vitalStatus),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            _ClinicalVitalsGrid(vitals: handoff.vitalSigns),
          ],
          if (handoff.alerts.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            Text(
              l10n.opdClinicalAlertsSummaryLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            _ClinicalAlertsWrap(alerts: handoff.alerts),
          ],
        ],
      ),
    );
  }
}

class _ClinicalVitalsGrid extends StatelessWidget {
  const _ClinicalVitalsGrid({required this.vitals});

  final List<ClinicalVitalSummary> vitals;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final double gap = theme.spacing.md;
        final double itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            for (final ClinicalVitalSummary vital in vitals)
              SizedBox(
                width: itemWidth,
                child: _ClinicalVitalSummary(vital: vital),
              ),
          ],
        );
      },
    );
  }
}

class _ClinicalVitalSummary extends StatelessWidget {
  const _ClinicalVitalSummary({required this.vital});

  final ClinicalVitalSummary vital;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color valueColor = _clinicalToneColor(
      theme,
      _clinicalVitalTone(vital.status),
    );
    final String recordedAtLabel = vital.recordedAt == null
        ? ''
        : _dateTimeLabel(context, vital.recordedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          _apiLabel(vital.vitalType),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          vital.displayValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (recordedAtLabel.isNotEmpty)
          Text(
            recordedAtLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _ClinicalAlertsWrap extends StatelessWidget {
  const _ClinicalAlertsWrap({required this.alerts});

  final List<ClinicalAlertSummary> alerts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: theme.spacing.md,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final ClinicalAlertSummary alert in alerts)
          _ClinicalStatusText(
            status: AppWorkspaceStatus(
              label: _joinDisplay(<String?>[
                _apiLabel(alert.severity ?? ''),
                alert.message,
                alert.createdAt == null
                    ? null
                    : _dateTimeLabel(context, alert.createdAt),
              ]),
              tone: _clinicalAlertTone(alert.severity),
              icon: Icons.warning_amber_outlined,
            ),
            textStyle: theme.textTheme.bodySmall,
          ),
      ],
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
    final String dispositionActionLabel = clinicalDispositionActionLabel(
      l10n,
      sourceQueue: bundle.entry.sourceQueue,
      status: bundle.entry.status,
      stage: bundle.entry.stage,
      location: bundle.entry.currentLocation,
      hasAdmission: bundle.entry.admissionId?.trim().isNotEmpty ?? false,
    );
    final bool canCompleteDisposition = isClinicalDispositionActionAvailable(
      sourceQueue: bundle.entry.sourceQueue,
      status: bundle.entry.status,
      stage: bundle.entry.stage,
      location: bundle.entry.currentLocation,
      hasAdmission: bundle.entry.admissionId?.trim().isNotEmpty ?? false,
      hasOpdFlow: bundle.entry.opdFlowApiId?.trim().isNotEmpty ?? false,
    );
    return AppAccessActionGate(
      requirement: _ClinicalWorkspaceContentState._writeRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return ClinicalActionsPanel(
          title: l10n.clinicalActionsTitle,
          actions: <ClinicalActionItem>[
            ClinicalActionItem(
              kind: ClinicalActionKind.addNote,
              label: l10n.clinicalAddNoteAction,
              icon: Icons.note_add_outlined,
              enabled: isAllowed,
              onPressed: () => _openNoteDialog(context, controller),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.addDiagnosis,
              label: l10n.clinicalAddDiagnosisAction,
              icon: Icons.rule_outlined,
              enabled: isAllowed,
              onPressed: () => _openDiagnosisDialog(context, controller),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.requestLab,
              label: l10n.clinicalRequestLabAction,
              icon: Icons.science_outlined,
              enabled: isAllowed,
              onPressed: () =>
                  _openLabDialog(context, controller, referenceData),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.requestRadiology,
              label: l10n.clinicalRequestRadiologyAction,
              icon: Icons.biotech_outlined,
              enabled: isAllowed,
              onPressed: () =>
                  _openRadiologyDialog(context, controller, referenceData),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.prescribe,
              label: l10n.clinicalPrescribeAction,
              icon: Icons.medication_outlined,
              enabled: isAllowed,
              onPressed: () =>
                  _openPrescriptionDialog(context, controller, referenceData),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.addProcedure,
              label: l10n.clinicalRequestProcedureAction,
              icon: Icons.healing_outlined,
              enabled: isAllowed,
              onPressed: () => _openProcedureDialog(context, controller),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.refer,
              label: l10n.opdReferAction,
              icon: Icons.alt_route_outlined,
              enabled: isAllowed,
              onPressed: () => _openReferralDialog(context, controller),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.requestAdmission,
              label: l10n.clinicalRequestAdmissionAction,
              icon: Icons.bed_outlined,
              enabled: isAllowed,
              onPressed: () =>
                  _openAdmissionDialog(context, controller, referenceData),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.followUp,
              label: l10n.opdFollowUpAction,
              icon: Icons.event_repeat_outlined,
              enabled: isAllowed,
              onPressed: () => _openFollowUpDialog(context, controller),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.completeDisposition,
              label: dispositionActionLabel,
              icon: Icons.task_alt_outlined,
              enabled:
                  isAllowed &&
                  !bundle.entry.isTerminal &&
                  canCompleteDisposition,
              onPressed: () => _openCompleteDispositionDialog(
                context,
                ref,
                controller,
                entry: bundle.entry,
                actionLabel: dispositionActionLabel,
              ),
            ),
            ClinicalActionItem(
              kind: ClinicalActionKind.printSummary,
              label: l10n.clinicalPrintSummaryAction,
              icon: Icons.print_outlined,
              onPressed: () async {
                await printFormTemplateDocument(
                  ref: ref,
                  context: context,
                  title: l10n.clinicalConsultationSummaryTitle,
                  patientContext: buildPrintFormPatientContext(
                    l10n,
                    patientName: bundle.entry.displayTitle,
                    patientId: bundle.entry.apiPatientId,
                    encounterId: bundle.entry.encounterPublicId,
                  ),
                  bodyHtml: _consultationSummaryHtml(context, bundle),
                  includeSignatures: true,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ClinicalResultReview extends StatelessWidget {
  const _ClinicalResultReview({required this.bundle});

  final ClinicalEncounterBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRelatedRecord> results = _clinicalCompletedResults(
      bundle,
    );
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkspaceDetailPanel(
      title: l10n.clinicalResultReviewTitle,
      description: l10n.clinicalResultReviewBody,
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
    final List<ClinicalRelatedRecord> orders = bundle.labOrders;
    if (orders.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkspaceDetailPanel(
      title: l10n.clinicalLabOrdersTitle,
      description: l10n.clinicalLabOrdersBody,
      child: Column(
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
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Icon(
              Icons.science_outlined,
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.primary,
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
                      order.title ?? context.l10n.profileUnknownValue,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_hasText(status))
                      _ClinicalStatusText(
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
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.edit_outlined,
                    label: l10n.clinicalEditLabOrderAction,

                    semanticLabel: l10n.clinicalEditLabOrderAction,
                    tooltip: l10n.clinicalEditLabOrderAction,
                    enabled: isAllowed && canEdit,
                    onPressed: () => _openLabDialog(
                      context,
                      controller,
                      referenceData,
                      existingOrder: order,
                    ),
                  ),
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.block_outlined,
                    label: l10n.clinicalCancelLabOrderAction,

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
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.delete_outline,
                    label: l10n.clinicalDeleteLabOrderAction,

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
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final String value in values)
                _ClinicalTextToken(label: value),
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Icon(
              Icons.science_outlined,
              size: theme.appTokens.listIconSize * 0.82,
              color: theme.colorScheme.primary,
            ),
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
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              _ClinicalStatusText(
                status: AppWorkspaceStatus(
                  label: _apiLabel(status),
                  tone: _statusTone(status),
                ),
                textStyle: theme.textTheme.labelMedium,
              ),
              if (resultStatus != null)
                _ClinicalStatusText(
                  status: AppWorkspaceStatus(
                    label: resultStatus,
                    tone: _statusTone(item.resultStatus),
                  ),
                  textStyle: theme.textTheme.labelMedium,
                ),
            ],
          ),
        ],
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
    final List<Widget> sections = <Widget>[
      if (bundle.clinicalNotes.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalPatientNotesTitle,
          records: bundle.clinicalNotes,
        ),
      if (bundle.diagnoses.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalPatientDiagnosesTitle,
          records: bundle.diagnoses,
        ),
      if (bundle.procedures.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.opdProceduresSummaryLabel,
          records: bundle.procedures,
        ),
      if (bundle.carePlans.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalCarePlansTitle,
          records: bundle.carePlans,
        ),
      if (bundle.radiologyOrders.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalRadiologyOrdersTitle,
          records: bundle.radiologyOrders,
        ),
      if (bundle.pharmacyOrders.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalPharmacyOrdersTitle,
          records: bundle.pharmacyOrders,
        ),
      if (bundle.referrals.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.opdReferralsTitle,
          records: bundle.referrals,
        ),
      if (bundle.followUps.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.opdFollowUpsTitle,
          records: bundle.followUps,
        ),
      if (bundle.admissions.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.patientsAdmissionsSectionTitle,
          records: bundle.admissions,
        ),
    ];

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withClinicalSectionSpacing(context, sections),
    );
  }
}

class _ClinicalRecordSection extends StatelessWidget {
  const _ClinicalRecordSection({required this.title, required this.records});

  final String title;
  final List<ClinicalRelatedRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkspaceDetailPanel(
      title: title,
      child: _ClinicalRecordList(records: records),
    );
  }
}

class _ClinicalRecordList extends StatelessWidget {
  const _ClinicalRecordList({required this.records, this.emptyLabel});

  final List<ClinicalRelatedRecord> records;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (records.isEmpty) {
      final String? label = emptyLabel;
      if (label == null || label.trim().isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(
        label,
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
    return switch (record.kind) {
      'radiology_order' => _ClinicalRadiologyOrderRow(record: record),
      'pharmacy_order' => _ClinicalPharmacyOrderRow(record: record),
      _ => _ClinicalGenericRecordRow(record: record),
    };
  }
}

class _ClinicalGenericRecordRow extends StatelessWidget {
  const _ClinicalGenericRecordRow({required this.record});

  final ClinicalRelatedRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? status = record.status;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Icon(
              _recordIcon(record.kind),
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.primary,
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
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      _joinDisplay(<String?>[
                        _apiLabel(record.kind),
                        _dateTimeLabel(context, record.occurredAt),
                      ]),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_hasText(status))
                      _ClinicalStatusText(
                        status: AppWorkspaceStatus(
                          label: _apiLabel(status!),
                          tone: _statusTone(status),
                        ),
                        textStyle: theme.textTheme.labelMedium,
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
}

class _ClinicalRadiologyOrderRow extends ConsumerWidget {
  const _ClinicalRadiologyOrderRow({required this.record});

  final ClinicalRelatedRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    final String status = record.status ?? '';
    final bool canCancel = _canCancelRadiologyOrder(status);
    final bool canDelete = _canDeleteRadiologyOrder(status);
    final List<ClinicalRadiologyOrderItem> items = record.radiologyOrderItems;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Icon(
              Icons.biotech_outlined,
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      record.title ?? record.id,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_hasText(status))
                      _ClinicalStatusText(
                        status: AppWorkspaceStatus(
                          label: _apiLabel(status),
                          tone: _statusTone(status),
                        ),
                        textStyle: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _joinDisplay(<String?>[
                    l10n.clinicalRadiologyOrderItemCount(record.itemCount),
                    _dateTimeLabel(context, record.occurredAt),
                  ]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (items.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  Column(
                    children: <Widget>[
                      for (var index = 0; index < items.length; index += 1)
                        _ClinicalRadiologyOrderItemRow(item: items[index]),
                    ],
                  ),
                ] else if (_hasText(record.subtitle)) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    record.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.block_outlined,
                    label: l10n.clinicalCancelRadiologyOrderAction,

                    semanticLabel: l10n.clinicalCancelRadiologyOrderAction,
                    tooltip: l10n.clinicalCancelRadiologyOrderAction,
                    enabled: isAllowed && canCancel,
                    onPressed: () => _confirmLabOrderMutation(
                      context: context,
                      title: l10n.clinicalCancelRadiologyOrderDialogTitle,
                      body: l10n.clinicalCancelRadiologyOrderDialogBody,
                      confirmLabel: l10n.clinicalCancelRadiologyOrderAction,
                      action: () => controller.cancelRadiologyOrder(record.id),
                    ),
                  ),
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.delete_outline,
                    label: l10n.clinicalDeleteRadiologyOrderAction,

                    semanticLabel: l10n.clinicalDeleteRadiologyOrderAction,
                    tooltip: l10n.clinicalDeleteRadiologyOrderAction,
                    enabled: isAllowed && canDelete,
                    onPressed: () => _confirmLabOrderMutation(
                      context: context,
                      title: l10n.clinicalDeleteRadiologyOrderDialogTitle,
                      body: l10n.clinicalDeleteRadiologyOrderDialogBody,
                      confirmLabel: l10n.clinicalDeleteRadiologyOrderAction,
                      action: () => controller.deleteRadiologyOrder(record.id),
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

class _ClinicalRadiologyOrderItemRow extends StatelessWidget {
  const _ClinicalRadiologyOrderItemRow({required this.item});

  final ClinicalRadiologyOrderItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<AppWorkspacePatientContextField> facts =
        <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: l10n.radiologyModalityLabel,
            value: _apiLabel(item.modality ?? ''),
          ),
          AppWorkspacePatientContextField(
            label: l10n.clinicalRadiologyBodyRegionLabel,
            value: _apiLabel(item.bodyRegion ?? ''),
          ),
          AppWorkspacePatientContextField(
            label: l10n.clinicalRadiologyLateralityLabel,
            value: _apiLabel(item.laterality ?? ''),
          ),
          AppWorkspacePatientContextField(
            label: l10n.clinicalRadiologyPriorityLabel,
            value: _apiLabel(item.priority ?? ''),
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdClinicalNoteLabel,
            value: item.clinicalNote ?? '',
          ),
        ];

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.displayTitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          _ClinicalInfoGrid(fields: facts),
        ],
      ),
    );
  }
}

class _ClinicalPharmacyOrderRow extends ConsumerWidget {
  const _ClinicalPharmacyOrderRow({required this.record});

  final ClinicalRelatedRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    final String status = record.status ?? '';
    final bool canCancel = _canCancelPharmacyOrder(status);
    final bool canDelete = _canDeletePharmacyOrder(status);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Icon(
              Icons.medication_outlined,
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      record.title ?? record.id,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_hasText(status))
                      _ClinicalStatusText(
                        status: AppWorkspaceStatus(
                          label: _apiLabel(status),
                          tone: _statusTone(status),
                        ),
                        textStyle: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _joinDisplay(<String?>[
                    l10n.clinicalPharmacyOrderItemCount(record.itemCount),
                    _dateTimeLabel(context, record.occurredAt),
                  ]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (record.pharmacyOrderItems.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  Column(
                    children: <Widget>[
                      for (
                        var index = 0;
                        index < record.pharmacyOrderItems.length;
                        index += 1
                      )
                        _ClinicalPharmacyOrderItemRow(
                          item: record.pharmacyOrderItems[index],
                        ),
                    ],
                  ),
                ] else if (_hasText(record.subtitle)) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    record.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.block_outlined,
                    label: l10n.clinicalCancelPharmacyOrderAction,

                    semanticLabel: l10n.clinicalCancelPharmacyOrderAction,
                    tooltip: l10n.clinicalCancelPharmacyOrderAction,
                    enabled: isAllowed && canCancel,
                    onPressed: () => _confirmLabOrderMutation(
                      context: context,
                      title: l10n.clinicalCancelPharmacyOrderDialogTitle,
                      body: l10n.clinicalCancelPharmacyOrderDialogBody,
                      confirmLabel: l10n.clinicalCancelPharmacyOrderAction,
                      action: () => controller.cancelPharmacyOrder(record.id),
                    ),
                  ),
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.delete_outline,
                    label: l10n.clinicalDeletePharmacyOrderAction,

                    semanticLabel: l10n.clinicalDeletePharmacyOrderAction,
                    tooltip: l10n.clinicalDeletePharmacyOrderAction,
                    enabled: isAllowed && canDelete,
                    onPressed: () => _confirmLabOrderMutation(
                      context: context,
                      title: l10n.clinicalDeletePharmacyOrderDialogTitle,
                      body: l10n.clinicalDeletePharmacyOrderDialogBody,
                      confirmLabel: l10n.clinicalDeletePharmacyOrderAction,
                      action: () => controller.deletePharmacyOrder(record.id),
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

class _ClinicalPharmacyOrderItemRow extends StatelessWidget {
  const _ClinicalPharmacyOrderItemRow({required this.item});

  final ClinicalPharmacyOrderItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String readableSummary = clinicalPrescriptionItemReadableSummary(
      item,
    );
    final List<AppWorkspacePatientContextField> facts =
        <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: l10n.pharmacyDoseColumnLabel,
            value: item.doseLabel ?? '',
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdMedicationRouteLabel,
            value: _apiLabel(item.route ?? ''),
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdFrequencyLabel,
            value: _apiLabel(item.frequency ?? ''),
          ),
          AppWorkspacePatientContextField(
            label: l10n.clinicalDurationValueLabel,
            value: item.durationLabel ?? '',
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdDrugQuantityLabel,
            value: item.quantityLabel ?? '',
          ),
          AppWorkspacePatientContextField(
            label: l10n.clinicalInstructionsLabel,
            value: item.instructions ?? '',
          ),
        ];
    final String status = item.status ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
                    SizedBox(height: theme.spacing.xs),
                    Text(readableSummary, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (_hasText(status))
                _ClinicalStatusText(
                  status: AppWorkspaceStatus(
                    label: _apiLabel(status),
                    tone: _statusTone(status),
                  ),
                  textStyle: theme.textTheme.labelMedium,
                ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          _ClinicalInfoGrid(fields: facts),
        ],
      ),
    );
  }
}

class _ClinicalTextToken extends StatelessWidget {
  const _ClinicalTextToken({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
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

const List<String> _clinicalDispositionReasons = <String>[
  'TREATMENT_COMPLETED',
  'SYMPTOMS_RESOLVED',
  'STABLE_FOR_HOME_CARE',
  'REFERRED_FOR_SPECIALIST_CARE',
  'FOLLOW_UP_SCHEDULED',
  'ADMISSION_NOT_REQUIRED',
  'PATIENT_TRANSFERRED',
  'PATIENT_DECLINED_CARE',
  'OTHER',
];

Future<void> _openNoteDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: context.l10n.clinicalAddNoteTitle,
        sectionTitle: context.l10n.clinicalPatientNotesTitle,
        label: context.l10n.opdClinicalNoteLabel,
        submitLabel: context.l10n.clinicalAddNoteAction,
        prefixIcon: const Icon(Icons.notes_outlined),
        minLines: 5,
        maxLines: 6,
        onSubmit: controller.addClinicalNote,
      ),
    ),
  );
}

Future<void> _openCompleteDispositionDialog(
  BuildContext context,
  WidgetRef ref,
  ClinicalWorkspaceController controller, {
  required ClinicalWorklistEntry entry,
  required String actionLabel,
}) async {
  if (isClinicalAdmissionDischargeContext(
    sourceQueue: entry.sourceQueue,
    status: entry.status,
    stage: entry.stage,
    location: entry.currentLocation,
    hasAdmission: entry.admissionId?.trim().isNotEmpty ?? false,
  )) {
    final String? admissionId = entry.apiAdmissionId?.trim();
    if (admissionId == null || admissionId.isEmpty) {
      return;
    }

    final bool? saved = await showDischargePlanningDialog(
      context: context,
      ref: ref,
      admissionId: admissionId,
      title: Text(actionLabel),
    );
    if (saved != true || !context.mounted) {
      return;
    }

    await ref.read(clinicalWorkspaceControllerProvider.notifier).refresh();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.clinicalSavedMessage)));
    Navigator.of(context).pop(true);
    return;
  }

  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalDispositionActionDialog(
      title: actionLabel,
      reasons: _clinicalDispositionReasons,
      submitLabel: actionLabel,
      onSubmit: ({required String reason, required String notes}) {
        return controller.completeDisposition(reason: reason, notes: notes);
      },
    ),
  );
  if (saved != true || !context.mounted) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.clinicalSavedMessage)));
  Navigator.of(context).pop(true);
}

Future<void> _openDiagnosisDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalDiagnosisActionDialog(
        onSearchClinicalTerms:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 25,
                source: source,
              );
            },
        onSubmit: controller.addDiagnosis,
      ),
    ),
  );
}

Future<void> _openProcedureDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalProcedureActionDialog(
        onSearchClinicalTerms:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 25,
                source: source,
              );
            },
        onSubmit: controller.addProcedures,
      ),
    ),
  );
}

Future<void> _openLabDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  ClinicalReferenceData referenceData, {
  ClinicalRelatedRecord? existingOrder,
}) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalLabOrderActionDialog(
        referenceData: referenceData,
        existingOrder: existingOrder == null
            ? null
            : _clinicalActionLabOrderRecord(existingOrder),
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
              );
            },
        onRequest: controller.requestLab,
        onUpdate: controller.updateLabOrder,
      ),
    ),
  );
}

ClinicalActionLabOrderRecord _clinicalActionLabOrderRecord(
  ClinicalRelatedRecord record,
) {
  return ClinicalActionLabOrderRecord(
    id: record.id,
    labOrderItems: <ClinicalActionLabOrderItem>[
      for (final ClinicalLabOrderItem item in record.labOrderItems)
        ClinicalActionLabOrderItem(
          id: item.id,
          status: item.status,
          resultStatus: item.resultStatus,
          labTestId: item.labTestId,
          testDisplayName: item.testDisplayName,
          testCode: item.testCode,
          category: item.category,
          specimenType: item.specimenType,
          unit: item.unit,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        ),
    ],
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
    builder: (_) => AppConfirmActionDialog(
      title: title,
      body: body,
      submitLabel: confirmLabel,
      icon: const Icon(Icons.science_outlined),
      onConfirm: action,
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.clinicalSavedMessage)));
}

Future<void> _openRadiologyDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalRadiologyOrderActionDialog(
        referenceData: referenceData,
        onSubmit: controller.requestRadiology,
      ),
    ),
  );
}

Future<void> _openPrescriptionDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        onSubmit: controller.prescribe,
      ),
    ),
  );
}

Future<void> _openReferralDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalReferralActionDialog(onSubmit: controller.refer),
    ),
  );
}

Future<void> _openFollowUpDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ClinicalFollowUpActionDialog(onSubmit: controller.scheduleFollowUp),
    ),
  );
}

Future<void> _openAdmissionDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => ClinicalAdmissionActionDialog(
        referenceData: referenceData,
        requiresBed: false,
        reasonLabel: dialogContext.l10n.patientsAdmissionReasonLabel,
        reasonRequired: true,
        notesLabel: dialogContext.l10n.opdFieldOptionalLabel(
          dialogContext.l10n.patientsNotesLabel,
        ),
        onSubmit: (ClinicalActionAdmissionInput input) =>
            controller.requestAdmission(
              reason: input.reason,
              notes: input.notes,
            ),
      ),
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
      value: entry.encounterPublicId ?? '',
      icon: Icons.tag_outlined,
      copyable: true,
      copyTooltip: l10n.opdCopyEncounterIdAction,
      copiedMessage: l10n.opdEncounterIdCopiedMessage,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalEncounterQueueLabel,
      value: _apiLabel(entry.sourceQueue),
      icon: Icons.queue_outlined,
      tone: _sourceQueueTone(entry.sourceQueue),
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
      label: l10n.clinicalLastUpdatedLabel,
      value: lastUpdated == null ? '' : _dateTimeLabel(context, lastUpdated),
      icon: Icons.schedule_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalAdmissionNumberLabel,
      value: entry.admissionPublicId ?? '',
      icon: Icons.bed_outlined,
      copyable: true,
      copyTooltip: l10n.copyAdmissionIdAction,
      copiedMessage: l10n.admissionIdCopiedMessage,
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
  ];
}

String _clinicalPatientNumber(ClinicalWorklistEntry entry) {
  final String? publicId = entry.patientPublicId?.trim();
  if (publicId != null && publicId.isNotEmpty) {
    return publicId;
  }

  return '';
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

List<Widget> _withClinicalSectionSpacing(
  BuildContext context,
  List<Widget> sections,
) {
  final double spacing = Theme.of(context).spacing.md;
  return <Widget>[
    for (var index = 0; index < sections.length; index += 1) ...<Widget>[
      if (index > 0) SizedBox(height: spacing),
      sections[index],
    ],
  ];
}

List<ClinicalRelatedRecord> _clinicalCompletedResults(
  ClinicalEncounterBundle bundle,
) {
  return <ClinicalRelatedRecord>[...bundle.labOrders, ...bundle.radiologyOrders]
      .where((ClinicalRelatedRecord record) {
        return (record.status ?? '').toUpperCase() == 'COMPLETED';
      })
      .toList(growable: false);
}

bool _clinicalHasRecordSections(ClinicalEncounterBundle bundle) {
  return bundle.clinicalNotes.isNotEmpty ||
      bundle.diagnoses.isNotEmpty ||
      bundle.procedures.isNotEmpty ||
      bundle.carePlans.isNotEmpty ||
      bundle.radiologyOrders.isNotEmpty ||
      bundle.pharmacyOrders.isNotEmpty ||
      bundle.referrals.isNotEmpty ||
      bundle.followUps.isNotEmpty ||
      bundle.admissions.isNotEmpty;
}

IconData _clinicalStatusIcon(AppWorkspaceStatusTone tone) {
  return switch (tone) {
    AppWorkspaceStatusTone.success => Icons.check_circle_outline,
    AppWorkspaceStatusTone.warning => Icons.warning_amber_outlined,
    AppWorkspaceStatusTone.error => Icons.error_outline,
    AppWorkspaceStatusTone.info => Icons.info_outline,
    AppWorkspaceStatusTone.neutral => Icons.radio_button_unchecked,
  };
}

Color _clinicalToneColor(ThemeData theme, AppWorkspaceStatusTone tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  return switch (tone) {
    AppWorkspaceStatusTone.success => colorScheme.tertiary,
    AppWorkspaceStatusTone.warning => colorScheme.secondary,
    AppWorkspaceStatusTone.error => colorScheme.error,
    AppWorkspaceStatusTone.info => colorScheme.primary,
    AppWorkspaceStatusTone.neutral => colorScheme.onSurfaceVariant,
  };
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
    'ABNORMAL' ||
    'WAITING' ||
    'WAITING_REVIEW' ||
    'WAITING_DOCTOR_REVIEW' ||
    'WAITING_DISPOSITION' ||
    'ADMITTED' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' ||
    'ORDERED' ||
    'COLLECTED' ||
    'IN_PROCESS' ||
    'RESULTS_READY' ||
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

bool _canCancelRadiologyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' || 'CANCELLED' => false,
    _ => true,
  };
}

bool _canDeleteRadiologyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'CANCELLED' => true,
    _ => false,
  };
}

bool _canCancelPharmacyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PARTIALLY_DISPENSED' => true,
    _ => false,
  };
}

bool _canDeletePharmacyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'CANCELLED' => true,
    _ => false,
  };
}

int _pageTotal<T>(AppPage<T> page) => page.totalItemCount ?? page.items.length;

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
  final List<String> sections = <String>[];

  void addSection(String title, List<ClinicalRelatedRecord> records) {
    if (records.isEmpty) {
      return;
    }
    sections.add(
      PrintFormTemplate.section(title: title, bodyHtml: _recordsHtml(records)),
    );
  }

  addSection(l10n.clinicalPatientNotesTitle, bundle.clinicalNotes);
  addSection(l10n.clinicalPatientDiagnosesTitle, bundle.diagnoses);
  addSection(l10n.opdProceduresSummaryLabel, bundle.procedures);
  addSection(l10n.clinicalCarePlansTitle, bundle.carePlans);
  addSection(l10n.clinicalLabOrdersTitle, bundle.labOrders);
  addSection(l10n.clinicalRadiologyOrdersTitle, bundle.radiologyOrders);
  addSection(l10n.clinicalPharmacyOrdersTitle, bundle.pharmacyOrders);
  addSection(l10n.opdReferralsTitle, bundle.referrals);
  addSection(l10n.opdFollowUpsTitle, bundle.followUps);
  addSection(l10n.patientsAdmissionsSectionTitle, bundle.admissions);

  return sections.join();
}

String _recordsHtml(List<ClinicalRelatedRecord> records) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final ClinicalRelatedRecord record in records)
      _clinicalRecordSummaryText(record),
  ], emptyText: 'No records.');
}

String _clinicalRecordSummaryText(ClinicalRelatedRecord record) {
  return _joinDisplay(<String?>[
    record.title,
    record.subtitle,
    if (record.labOrderItems.isNotEmpty)
      _joinDisplay(
        record.labOrderItems
            .take(4)
            .map((ClinicalLabOrderItem item) => item.displayTitle),
      ),
    if (record.radiologyOrderItems.isNotEmpty)
      _joinDisplay(
        record.radiologyOrderItems
            .take(4)
            .map((ClinicalRadiologyOrderItem item) => item.displayTitle),
      ),
    if (record.pharmacyOrderItems.isNotEmpty)
      _joinDisplay(
        record.pharmacyOrderItems
            .take(4)
            .map((ClinicalPharmacyOrderItem item) => item.displayTitle),
      ),
    record.status == null ? null : _apiLabel(record.status!),
  ]);
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

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

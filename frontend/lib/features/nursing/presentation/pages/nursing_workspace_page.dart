import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
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
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class NursingWorkspacePage extends ConsumerWidget {
  const NursingWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<NursingWorkspaceState>> state = ref.watch(
      nursingWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<NursingWorkspaceState>(
      value: state,
      loadingTitle: l10n.nursingLoadingTitle,
      loadingBody: l10n.nursingLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(nursingWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, NursingWorkspaceState data) {
        return _NursingWorkspaceContent(state: data);
      },
    );
  }
}

class _NursingWorkspaceContent extends ConsumerStatefulWidget {
  const _NursingWorkspaceContent({required this.state});

  final NursingWorkspaceState state;

  @override
  ConsumerState<_NursingWorkspaceContent> createState() =>
      _NursingWorkspaceContentState();
}

class _NursingWorkspaceContentState
    extends ConsumerState<_NursingWorkspaceContent> {
  static const AccessRequirement writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.patientWrite,
      AppPermissions.lastOfficeWrite,
    ],
    anyRoles: <AppRole>[
      AppRole.nurse,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.facilityAdmin,
      AppRole.tenantAdmin,
      AppRole.superAdmin,
    ],
    activeModules: <String>['inpatient-bed-management'],
  );

  late final TextEditingController _searchController;
  late AppSearchBarFilterValue _filterValue;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _filterValue = _filterValueFromQuery(widget.state.query);
  }

  @override
  void didUpdateWidget(covariant _NursingWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (oldWidget.state.query != widget.state.query) {
      _filterValue = _filterValueFromQuery(widget.state.query);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NursingWorkspaceState state = widget.state;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );

    return AppWorkspace(
      title: l10n.nursingTitle,
      leadingIcon: AppRouteIcons.nursing,
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isSaving
            ? l10n.nursingSavingStatus
            : l10n.nursingLiveStatus,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
      ),
      secondaryActions: <Widget>[
        AppIconButton(
          icon: Icons.assignment_ind_outlined,
          semanticLabel: l10n.nursingShiftContextTitle,
          tooltip: l10n.nursingShiftContextTitle,
          onPressed: () => _openShiftContextDialog(context),
        ),
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshing || state.isRefreshingDetail,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        _summaryCard(
          context,
          label: l10n.nursingAssignedWardSummaryLabel,
          value: state.assignedWardCount,
          icon: Icons.local_hospital_outlined,
          tone: AppWorkspaceStatusTone.info,
          onPressed: () => _openSummaryPatientsDialog(
            context,
            ref,
            NursingQueueScope.assignedWard,
            l10n.nursingAssignedWardSummaryLabel,
            Icons.local_hospital_outlined,
            AppWorkspaceStatusTone.info,
          ),
        ),
        _summaryCard(
          context,
          label: l10n.nursingUrgentSummaryLabel,
          value: state.urgentCount,
          icon: Icons.priority_high_outlined,
          tone: AppWorkspaceStatusTone.error,
          onPressed: () => _openSummaryPatientsDialog(
            context,
            ref,
            NursingQueueScope.urgent,
            l10n.nursingUrgentSummaryLabel,
            Icons.priority_high_outlined,
            AppWorkspaceStatusTone.error,
          ),
        ),
        _summaryCard(
          context,
          label: l10n.nursingMedicationDueSummaryLabel,
          value: state.medicationDueCount,
          icon: Icons.medication_outlined,
          tone: AppWorkspaceStatusTone.warning,
          onPressed: () => _openSummaryPatientsDialog(
            context,
            ref,
            NursingQueueScope.medicationDue,
            l10n.nursingMedicationDueSummaryLabel,
            Icons.medication_outlined,
            AppWorkspaceStatusTone.warning,
          ),
        ),
        _summaryCard(
          context,
          label: l10n.nursingHandoverPendingSummaryLabel,
          value: state.handoverPendingCount,
          icon: Icons.swap_horiz_outlined,
          tone: AppWorkspaceStatusTone.neutral,
          onPressed: () => _openSummaryPatientsDialog(
            context,
            ref,
            NursingQueueScope.handoverPending,
            l10n.nursingHandoverPendingSummaryLabel,
            Icons.swap_horiz_outlined,
            AppWorkspaceStatusTone.neutral,
          ),
        ),
        _summaryCard(
          context,
          label: l10n.nursingTransferPendingSummaryLabel,
          value: state.transferPendingCount,
          icon: Icons.transfer_within_a_station_outlined,
          tone: AppWorkspaceStatusTone.warning,
          onPressed: () => _openSummaryPatientsDialog(
            context,
            ref,
            NursingQueueScope.transferPending,
            l10n.nursingTransferPendingSummaryLabel,
            Icons.transfer_within_a_station_outlined,
            AppWorkspaceStatusTone.warning,
          ),
        ),
        _summaryCard(
          context,
          label: l10n.nursingDischargePendingSummaryLabel,
          value: state.dischargePendingCount,
          icon: Icons.logout_outlined,
          tone: AppWorkspaceStatusTone.success,
          onPressed: () => _openSummaryPatientsDialog(
            context,
            ref,
            NursingQueueScope.dischargePending,
            l10n.nursingDischargePendingSummaryLabel,
            Icons.logout_outlined,
            AppWorkspaceStatusTone.success,
          ),
        ),
      ],
      body: _NursingWorklistPanel(
        state: state,
        searchController: _searchController,
        filterValue: _filterValue,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() {
            _filterValue = value;
          });
          controller
              .applyAdvancedFilters(
                searchField: value.field,
                scope: _scopeFromFilterValue(value.option('scope')),
                patient: value.text('patient'),
                admission: value.text('admission'),
                encounter: value.text('encounter'),
                ward: value.text('ward'),
                room: value.text('room'),
                bed: value.text('bed'),
                observation: value.text('observation'),
                taskType: value.text('task_type'),
                status: value.option('status'),
                priority: value.option('priority'),
                assignedNurse: value.text('assigned_nurse'),
                shift: value.text('shift'),
                transferStatus: value.option('transfer_status'),
                handoverStatus: value.option('handover_status'),
                dischargeStatus: value.option('discharge_status'),
                dateFrom: value.dateFrom,
                dateTo: value.dateTo,
              )
              .then((AppFailure? failure) {
                if (context.mounted) {
                  _showFailureIfNeeded(context, failure);
                }
              });
        },
      ),
    );
  }

  void _openShiftContextDialog(BuildContext context) {
    showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) =>
          const _NursingShiftContextDialog(),
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String label,
    required int value,
    required IconData icon,
    required AppWorkspaceStatusTone tone,
    required VoidCallback onPressed,
  }) {
    return AppWorkspaceSummaryCard(
      label: label,
      value: AppFormatters.compactNumber(
        value,
        Localizations.localeOf(context),
      ),
      icon: icon,
      tone: tone,
      compact: true,
      onPressed: onPressed,
    );
  }
}

class _NursingWorklistPanel extends ConsumerWidget {
  const _NursingWorklistPanel({
    required this.state,
    required this.searchController,
    required this.filterValue,
    required this.onFilterChanged,
  });

  final NursingWorkspaceState state;
  final TextEditingController searchController;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.nursingWorklistTitle,
      description: l10n.nursingWorklistDescription,
      child: AppListTable<NursingWorkItem>(
        page: state.worklist,
        isLoading: state.isRefreshing,
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<NursingWorkItem> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        onRowSelected: (NursingWorkItem item) {
          _openPatientDetailDialog(context, ref, item);
        },
        search: AppListTableSearch<NursingWorkItem>(
          controller: searchController,
          semanticLabel: l10n.nursingSearchLabel,
          hintText: l10n.nursingSearchHint,
          matcher: (NursingWorkItem item, String query) {
            return item.matchesSearchField(state.query.searchField, query);
          },
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
          isLoading: state.isRefreshing,
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.nursingAdvancedFiltersLabel,
          advancedFilterTitle: l10n.nursingAdvancedFiltersTitle,
          advancedFilterApplyLabel: l10n.nursingApplyFiltersLabel,
          advancedFilterResetLabel: l10n.nursingResetFiltersLabel,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
          searchFieldLabel: l10n.nursingSearchFieldLabel,
          allFieldsLabel: l10n.nursingAllFieldsLabel,
          dateFilterLabel: l10n.nursingDateFilterLabel,
          dateFromLabel: l10n.nursingDateFromLabel,
          dateToLabel: l10n.nursingDateToLabel,
          datePickerButtonLabel: l10n.nursingDatePickerLabel,
          invalidDateMessage: l10n.nursingInvalidDateMessage,
          currentDate: DateTime.now(),
          searchFields: _worklistSearchFields(l10n),
          textFilters: _worklistTextFilters(l10n),
          filterGroups: _worklistFilterGroups(l10n),
          filterValue: filterValue,
          hasActiveFilters: state.query.hasAdvancedFilters,
          onFilterChanged: onFilterChanged,
        ),
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.nursingNoWorklistTitle,
          body: l10n.nursingNoWorklistBody,
          icon: Icons.assignment_outlined,
        ),
        columnChoices: _nursingWorklistColumnChoices(l10n),
        columns: _nursingWorklistDefaultColumns(l10n),
        mobileItemBuilder: (BuildContext context, NursingWorkItem item) {
          final ThemeData theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _NursingPatientCell(item: item),
                SizedBox(height: theme.spacing.xs),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(
                      status: _priorityStatus(context, item),
                    ),
                    AppWorkspaceStatusBadge(status: _summaryStatus(item)),
                    Text(
                      _joinDisplay(<String?>[
                        item.locationLabel,
                        _taskTypeLabel(context, item),
                        _dueTimeLabel(context, item),
                      ]),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

List<AppListTableColumn<NursingWorkItem>> _nursingWorklistDefaultColumns(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<NursingWorkItem>>[
    AppListTableColumn<NursingWorkItem>(
      label: l10n.opdPatientColumnLabel,
      sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
          appListTableCompareText(left.displayTitle, right.displayTitle),
      cellBuilder: (BuildContext context, NursingWorkItem item) {
        return _NursingPatientCell(item: item);
      },
    ),
    AppListTableColumn<NursingWorkItem>(
      label: l10n.nursingLocationColumnLabel,
      sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
          appListTableCompareText(left.locationLabel, right.locationLabel),
      cellBuilder: (BuildContext context, NursingWorkItem item) {
        return Text(item.locationLabel ?? l10n.profileUnknownValue);
      },
    ),
    AppListTableColumn<NursingWorkItem>(
      label: l10n.nursingTaskTypeColumnLabel,
      sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
          appListTableCompareText(left.taskTypeCode, right.taskTypeCode),
      cellBuilder: (BuildContext context, NursingWorkItem item) {
        return Text(_taskTypeLabel(context, item));
      },
    ),
    AppListTableColumn<NursingWorkItem>(
      label: l10n.nursingPriorityColumnLabel,
      sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
          appListTableCompareText(left.priorityCode, right.priorityCode),
      cellBuilder: (BuildContext context, NursingWorkItem item) {
        return AppWorkspaceStatusBadge(status: _priorityStatus(context, item));
      },
    ),
    AppListTableColumn<NursingWorkItem>(
      label: l10n.opdStatusColumnLabel,
      sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
          appListTableCompareText(left.admissionStatus, right.admissionStatus),
      cellBuilder: (BuildContext context, NursingWorkItem item) {
        return AppWorkspaceStatusBadge(status: _summaryStatus(item));
      },
    ),
  ];
}

List<AppListTableColumn<NursingWorkItem>> _nursingWorklistColumnChoices(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<NursingWorkItem>>[
    ..._nursingWorklistDefaultColumns(l10n),
    AppListTableColumn<NursingWorkItem>(
      label: l10n.nursingAdmissionColumnLabel,
      sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
          appListTableCompareText(
            left.displayId ?? left.admissionId,
            right.displayId ?? right.admissionId,
          ),
      cellBuilder: (BuildContext context, NursingWorkItem item) {
        return Text(_admissionLabel(context, item));
      },
    ),
    AppListTableColumn<NursingWorkItem>(
      label: l10n.nursingDueTimeColumnLabel,
      sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
          appListTableCompareDateTime(
            left.dueReferenceAt,
            right.dueReferenceAt,
          ),
      cellBuilder: (BuildContext context, NursingWorkItem item) {
        return Text(_dueTimeLabel(context, item));
      },
    ),
    AppListTableColumn<NursingWorkItem>(
      label: l10n.nursingResponsibleNurseColumnLabel,
      sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
          appListTableCompareText(
            _responsibleNurseSortValue(left),
            _responsibleNurseSortValue(right),
          ),
      cellBuilder: (BuildContext context, NursingWorkItem item) {
        return Text(_responsibleNurseLabel(context, item));
      },
    ),
    AppListTableColumn<NursingWorkItem>(
      label: l10n.nursingObservationsTitle,
      sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
          appListTableCompareDateTime(
            left.lastObservationAt,
            right.lastObservationAt,
          ),
      cellBuilder: (BuildContext context, NursingWorkItem item) {
        return Text(_lastObservationLabel(context, item));
      },
    ),
  ];
}

void _openSummaryPatientsDialog(
  BuildContext context,
  WidgetRef ref,
  NursingQueueScope scope,
  String title,
  IconData icon,
  AppWorkspaceStatusTone tone,
) {
  final Future<Result<AppPage<NursingWorkItem>>> future = ref
      .read(nursingWorkspaceControllerProvider.notifier)
      .previewPatientsForScope(scope);

  showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _NursingSummaryPatientsDialog(
        title: title,
        icon: icon,
        tone: tone,
        future: future,
        onPatientSelected: (NursingWorkItem item) {
          Navigator.of(dialogContext).maybePop();
          _openPatientDetailDialog(context, ref, item);
        },
      );
    },
  );
}

class _NursingSummaryPatientsDialog extends StatelessWidget {
  const _NursingSummaryPatientsDialog({
    required this.title,
    required this.icon,
    required this.tone,
    required this.future,
    required this.onPatientSelected,
  });

  final String title;
  final IconData icon;
  final AppWorkspaceStatusTone tone;
  final Future<Result<AppPage<NursingWorkItem>>> future;
  final ValueChanged<NursingWorkItem> onPatientSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(title),
      icon: Icon(icon),
      semanticLabel: title,
      scrollable: true,
      maxWidth: 920,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(label: title, tone: tone),
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          FutureBuilder<Result<AppPage<NursingWorkItem>>>(
            future: future,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<Result<AppPage<NursingWorkItem>>> snapshot,
                ) {
                  final Result<AppPage<NursingWorkItem>>? result =
                      snapshot.data;
                  if (result == null) {
                    return AppWorkspaceStatePanel.loading(
                      title: l10n.nursingLoadingTitle,
                      body: l10n.nursingLoadingBody,
                    );
                  }
                  return result.when(
                    success: (AppPage<NursingWorkItem> page) =>
                        AppListTable<NursingWorkItem>(
                          items: page.items,
                          shrinkWrap: true,
                          columns: _nursingWorklistDefaultColumns(l10n),
                          columnChoices: _nursingWorklistColumnChoices(l10n),
                          onRowSelected: onPatientSelected,
                          emptyBuilder: (_) => AppWorkspaceStatePanel.state(
                            variant: AppStateViewVariant.empty,
                            title: l10n.nursingNoWorklistTitle,
                            body: l10n.nursingNoWorklistBody,
                            icon: Icons.assignment_outlined,
                          ),
                          mobileItemBuilder:
                              (BuildContext context, NursingWorkItem item) {
                                final ThemeData theme = Theme.of(context);
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: theme.spacing.sm,
                                    vertical: theme.spacing.sm,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      _NursingPatientCell(item: item),
                                      SizedBox(height: theme.spacing.xs),
                                      Text(
                                        _joinDisplay(<String?>[
                                          item.locationLabel,
                                          _taskTypeLabel(context, item),
                                          _dueTimeLabel(context, item),
                                        ]),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                );
                              },
                        ),
                    failure: (AppFailure failure) =>
                        AppFailureStateView(failure: failure),
                  );
                },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

Future<void> _openPatientDetailDialog(
  BuildContext context,
  WidgetRef ref,
  NursingPatientSummary summary,
) async {
  final NursingWorkspaceController controller = ref.read(
    nursingWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectPatient(summary);
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    _showFailureIfNeeded(context, failure);
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) =>
        const _NursingPatientDetailDialog(),
  );
}

class _NursingPatientDetailDialog extends ConsumerWidget {
  const _NursingPatientDetailDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<NursingWorkspaceState>> state = ref.watch(
      nursingWorkspaceControllerProvider,
    );
    final NursingPatientDetail? detail = _selectedDetailFromState(state);
    final NursingPatientSummary? summary = detail?.enrichedSummary;

    return AppPatientDetailDialog(
      title: summary?.displayTitle ?? l10n.nursingPatientContextLabel,
      icon: const Icon(Icons.bed_outlined),
      semanticLabel: l10n.nursingPatientContextLabel,
      closeLabel: l10n.commonCloseActionLabel,
      content: detail == null
          ? AppWorkspaceStatePanel.state(
              variant: AppStateViewVariant.empty,
              title: l10n.nursingNoSelectionTitle,
              body: l10n.nursingNoSelectionBody,
              icon: Icons.bed_outlined,
            )
          : _NursingPatientDetailContent(detail: detail),
    );
  }
}

class _NursingPatientDetailContent extends StatelessWidget {
  const _NursingPatientDetailContent({required this.detail});

  final NursingPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NursingPatientSummary summary = detail.enrichedSummary;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: summary.displayTitle,
          patientNumber: summary.patientDisplayId ?? summary.admissionId,
          demographics: _joinDisplay(<String?>[
            detail.patientGender == null
                ? null
                : _apiLabel(detail.patientGender!),
            detail.patientDateOfBirth == null
                ? null
                : AppFormatters.mediumDate(
                    detail.patientDateOfBirth!,
                    Localizations.localeOf(context),
                  ),
          ]),
          status: _summaryStatus(summary),
          semanticLabel: l10n.nursingPatientContextLabel,
          alerts: <AppWorkspaceStatus>[
            if (summary.isUrgent)
              AppWorkspaceStatus(
                label: l10n.nursingUrgentSummaryLabel,
                tone: AppWorkspaceStatusTone.error,
              ),
            if (summary.hasMedicationDue)
              AppWorkspaceStatus(
                label: l10n.nursingMedicationDueSummaryLabel,
                tone: AppWorkspaceStatusTone.warning,
              ),
            if (summary.hasPendingTransfer)
              AppWorkspaceStatus(
                label: l10n.nursingTransferPendingSummaryLabel,
                tone: AppWorkspaceStatusTone.warning,
              ),
          ],
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.nursingAdmissionLabel,
              value: summary.admissionId,
              icon: Icons.tag_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingEncounterLabel,
              value: summary.encounterDisplayId ?? '',
              icon: Icons.medical_information_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingLocationLabel,
              value: summary.locationLabel ?? '',
              icon: Icons.location_on_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingFacilityLabel,
              value: detail.facilityName ?? '',
              icon: Icons.business_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingIcuLabel,
              value: summary.icuStatus == null
                  ? ''
                  : _apiLabel(summary.icuStatus!),
              icon: Icons.monitor_heart_outlined,
              tone: summary.hasCriticalAlert
                  ? AppWorkspaceStatusTone.error
                  : AppWorkspaceStatusTone.neutral,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingBedLabel,
              value: summary.bedDisplayLabel ?? '',
              icon: Icons.bed_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _NursingActionBar(detail: detail),
        SizedBox(height: theme.spacing.md),
        _NursingAdmissionChecklistPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _NursingRecordPanel(
          title: l10n.nursingObservationsTitle,
          records: _vitalRecords(context, detail),
          emptyLabel: l10n.nursingNoRecordsLabel,
        ),
        SizedBox(height: theme.spacing.md),
        _NursingRecordPanel(
          title: l10n.nursingMedicationsTitle,
          records: _medicationRecords(context, detail),
          emptyLabel: l10n.nursingNoRecordsLabel,
        ),
        SizedBox(height: theme.spacing.md),
        _NursingRecordPanel(
          title: l10n.nursingNotesTitle,
          records: _noteRecords(context, detail),
          emptyLabel: l10n.nursingNoRecordsLabel,
        ),
        SizedBox(height: theme.spacing.md),
        _NursingRecordPanel(
          title: l10n.nursingCarePlansTitle,
          records: _carePlanRecords(context, detail),
          emptyLabel: l10n.nursingNoRecordsLabel,
        ),
        SizedBox(height: theme.spacing.md),
        _NursingHandoverPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        AppWorkspaceDetailPanel(
          title: l10n.nursingWardActivityTitle,
          child: AppWardActivityList(
            items: _activityEntries(context, detail),
            emptyLabel: l10n.nursingNoRecordsLabel,
          ),
        ),
      ],
    );
  }
}

NursingPatientDetail? _selectedDetailFromState(
  AsyncValue<Result<NursingWorkspaceState>> state,
) {
  final Result<NursingWorkspaceState>? result = state.asData?.value;
  return result?.when(
    success: (NursingWorkspaceState value) => value.selectedDetail,
    failure: (_) => null,
  );
}

class _NursingActionBar extends ConsumerWidget {
  const _NursingActionBar({required this.detail});

  final NursingPatientDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );

    return AppAccessActionGate(
      requirement: _NursingWorkspaceContentState.writeRequirement,
      builder: (BuildContext context, bool isAllowed) => AppActionPanel(
        title: l10n.nursingActionsTitle,
        actions: <AppActionItem>[
          AppActionItem(
            label: l10n.nursingActionRecordVitals,
            leadingIcon: Icons.monitor_heart_outlined,
            enabled: isAllowed,
            onPressed: () => _openVitalsDialog(context),
          ),
          AppActionItem(
            label: l10n.nursingActionAddNote,
            leadingIcon: Icons.note_add_outlined,
            enabled: isAllowed,
            onPressed: () => _openNoteDialog(context),
          ),
          AppActionItem(
            label: l10n.nursingActionAdministerMedication,
            leadingIcon: Icons.medication_outlined,
            enabled: isAllowed,
            onPressed: () => _openMedicationDialog(context, detail),
          ),
          AppActionItem(
            label: l10n.clinicalPrescribeAction,
            leadingIcon: Icons.add_circle_outline,
            enabled: isAllowed,
            onPressed: () => _openPrescriptionDialog(context, controller),
          ),
          AppActionItem(
            label: l10n.nursingActionCreateHandover,
            leadingIcon: Icons.swap_horiz_outlined,
            enabled: isAllowed,
            onPressed: () => _openHandoverDialog(context),
          ),
          AppActionItem(
            label: l10n.nursingActionEscalate,
            leadingIcon: Icons.report_problem_outlined,
            enabled: isAllowed,
            onPressed: () => _openEscalationDialog(context),
          ),
          AppActionItem(
            label: l10n.nursingActionAcknowledgeTransfer,
            leadingIcon: Icons.transfer_within_a_station_outlined,
            enabled: isAllowed && detail.activeTransfer != null,
            onPressed: () => _openTransferDialog(context, detail),
          ),
          AppActionItem(
            label: l10n.nursingActionPrintSummary,
            leadingIcon: Icons.print_outlined,
            enabled: isAllowed,
            onPressed: () => _openPrintSummaryDialog(context, detail),
          ),
          for (final NursingHandover handover in detail.handovers)
            if (handover.isPending)
              AppActionItem(
                label: l10n.nursingActionAcceptHandover,
                leadingIcon: Icons.done_all_outlined,
                enabled: isAllowed,
                onPressed: () =>
                    _openAcceptHandoverDialog(context, controller, handover),
              ),
        ],
      ),
    );
  }
}

class _NursingPatientCell extends StatelessWidget {
  const _NursingPatientCell({required this.item});

  final NursingPatientSummary item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(item.displayTitle, style: theme.textTheme.titleSmall),
        if (_joinDisplay(<String?>[
          item.patientDisplayId,
          item.encounterDisplayId,
          item.admissionId,
        ]).isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            _joinDisplay(<String?>[
              item.patientDisplayId,
              item.encounterDisplayId,
              item.admissionId,
            ]),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _NursingRecordPanel extends StatelessWidget {
  const _NursingRecordPanel({
    required this.title,
    required this.records,
    required this.emptyLabel,
  });

  final String title;
  final List<AppNursingRecordEntry> records;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: title,
      child: AppNursingRecordList(items: records, emptyLabel: emptyLabel),
    );
  }
}

class _NursingHandoverPanel extends StatelessWidget {
  const _NursingHandoverPanel({required this.detail});

  final NursingPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.nursingHandoversTitle,
      child: AppNursingRecordList(
        items: _handoverRecords(context, detail),
        emptyLabel: l10n.nursingNoRecordsLabel,
      ),
    );
  }
}

class _NursingAdmissionChecklistPanel extends StatelessWidget {
  const _NursingAdmissionChecklistPanel({required this.detail});

  final NursingPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.nursingWardAdmissionChecklistTitle,
      description: l10n.nursingWardAdmissionChecklistDescription,
      child: AppCareTaskChecklist(
        items: _admissionChecklistItems(context, detail),
        emptyLabel: l10n.nursingNoRecordsLabel,
      ),
    );
  }
}

class _NursingShiftContextPanel extends StatelessWidget {
  const _NursingShiftContextPanel({required this.state});

  final NursingWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.nursingShiftContextTitle,
      description: l10n.nursingShiftContextDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.nursingRosterTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: Theme.of(context).spacing.sm),
          AppRosterAssignmentList(
            items: _rosterViews(context, state.rosters),
            emptyLabel: l10n.nursingNoRosterLabel,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          Text(
            l10n.nursingPendingHandoverTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: Theme.of(context).spacing.sm),
          AppWardActivityList(
            items: _handoverActivityEntries(context, state.pendingHandovers),
            emptyLabel: l10n.nursingNoRecordsLabel,
          ),
        ],
      ),
    );
  }
}

class _NursingShiftContextDialog extends ConsumerWidget {
  const _NursingShiftContextDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<NursingWorkspaceState>> value = ref.watch(
      nursingWorkspaceControllerProvider,
    );
    final NursingWorkspaceState? state = value.asData?.value.when(
      success: (NursingWorkspaceState data) => data,
      failure: (_) => null,
    );

    return AppDialog(
      title: Text(l10n.nursingShiftContextTitle),
      icon: const Icon(Icons.assignment_ind_outlined),
      semanticLabel: l10n.nursingShiftContextTitle,
      scrollable: true,
      maxWidth: 760,
      content: state == null
          ? AppWorkspaceStatePanel.loading(
              title: l10n.nursingLoadingTitle,
              body: l10n.nursingLoadingBody,
            )
          : _NursingShiftContextPanel(state: state),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
      ],
    );
  }
}

class _MedicationDialog extends ConsumerStatefulWidget {
  const _MedicationDialog({required this.detail});

  final NursingPatientDetail detail;

  @override
  ConsumerState<_MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends ConsumerState<_MedicationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _doseController;
  late final TextEditingController _unitController;
  late DateTime _administeredDate;
  late TimeOfDay _administeredTime;
  String? _prescriptionId;
  String _route = 'ORAL';
  bool _confirm = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final MedicationSuggestion? firstSuggestion =
        widget.detail.medicationSuggestions.isEmpty
        ? null
        : widget.detail.medicationSuggestions.first;
    final DateTime now = DateTime.now();
    _prescriptionId = firstSuggestion?.id;
    _doseController = TextEditingController(text: firstSuggestion?.dose ?? '');
    _unitController = TextEditingController(text: firstSuggestion?.unit ?? '');
    _administeredDate = DateTime(now.year, now.month, now.day);
    _administeredTime = TimeOfDay.fromDateTime(now);
    _route = _supportedMedicationRoute(firstSuggestion?.route) ?? _route;
  }

  @override
  void dispose() {
    _doseController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.nursingActionAdministerMedication),
      icon: const Icon(Icons.medication_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppMedicationAdministrationForm(
              medicationLabel: l10n.nursingMedicationLabel,
              doseLabel: l10n.nursingDoseLabel,
              unitLabel: l10n.nursingVitalUnitLabel,
              routeLabel: l10n.nursingRouteLabel,
              administeredDateLabel: l10n.nursingAdministeredAtLabel,
              administeredTimeLabel: l10n.opdTimeColumnLabel,
              datePickerLabel: l10n.nursingDatePickerLabel,
              invalidDateMessage: l10n.nursingInvalidDateMessage,
              timePickerLabel: l10n.appTimePickerAction,
              invalidTimeMessage: l10n.appTimeInvalidMessage,
              confirmLabel: l10n.nursingConfirmMedicationLabel,
              confirmSubtitle: l10n.nursingConfirmMedicationSubtitle,
              requiredMessage: l10n.validationRequired,
              doseController: _doseController,
              unitController: _unitController,
              administeredDate: _administeredDate,
              administeredTime: _administeredTime,
              routeValue: _route,
              routeOptions: _statusOptions(_medicationRoutes),
              confirmed: _confirm,
              medicationValue: _prescriptionId,
              medicationOptions: <AppSelectOption<String>>[
                for (final MedicationSuggestion suggestion
                    in widget.detail.medicationSuggestions)
                  AppSelectOption<String>(
                    value: suggestion.id,
                    label: _joinDisplay(<String?>[
                      suggestion.displayTitle,
                      suggestion.dose,
                      suggestion.unit,
                      suggestion.route == null
                          ? null
                          : _apiLabel(suggestion.route!),
                    ]),
                  ),
              ],
              selectedMedicationDescription: _selectedMedicationDescription(
                context,
              ),
              noMedicationMessage: l10n.nursingNoRecordsLabel,
              enabled: !_isSaving,
              onMedicationChanged: _selectMedication,
              onAdministeredDateChanged: (DateTime? value) {
                if (value != null) {
                  setState(() => _administeredDate = value);
                }
              },
              onAdministeredTimeChanged: (TimeOfDay? value) {
                if (value != null) {
                  setState(() => _administeredTime = value);
                }
              },
              onRouteChanged: (String? value) {
                if (value != null) {
                  setState(() => _route = value);
                }
              },
              onConfirmedChanged: (bool value) {
                setState(() => _confirm = value);
              },
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.nursingActionAdministerMedication,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  MedicationSuggestion? get _selectedSuggestion {
    if (_prescriptionId == null) {
      return null;
    }
    for (final MedicationSuggestion suggestion
        in widget.detail.medicationSuggestions) {
      if (suggestion.id == _prescriptionId) {
        return suggestion;
      }
    }
    return null;
  }

  String? _selectedMedicationDescription(BuildContext context) {
    final MedicationSuggestion? suggestion = _selectedSuggestion;
    if (suggestion == null) {
      return null;
    }
    return _joinDisplay(<String?>[
      suggestion.frequency,
      suggestion.orderStatus == null
          ? null
          : _apiLabel(suggestion.orderStatus!),
      suggestion.itemStatus == null ? null : _apiLabel(suggestion.itemStatus!),
      suggestion.route == null ? null : _apiLabel(suggestion.route!),
    ]);
  }

  void _selectMedication(String? value) {
    MedicationSuggestion? suggestion;
    for (final MedicationSuggestion item
        in widget.detail.medicationSuggestions) {
      if (item.id == value) {
        suggestion = item;
        break;
      }
    }
    setState(() {
      _prescriptionId = value;
      if (suggestion != null) {
        _doseController.text = suggestion.dose ?? _doseController.text;
        _unitController.text = suggestion.unit ?? _unitController.text;
        _route = _supportedMedicationRoute(suggestion.route) ?? _route;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if ((_prescriptionId ?? '').trim().isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    final DateTime administeredAt = DateTime(
      _administeredDate.year,
      _administeredDate.month,
      _administeredDate.day,
      _administeredTime.hour,
      _administeredTime.minute,
    );

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .addMedicationAdministration(<String, Object?>{
          'prescription_id': _prescriptionId?.trim(),
          'administered_at': administeredAt.toUtc().toIso8601String(),
          'dose': _doseController.text.trim(),
          'unit': _unitController.text.trim(),
          'route': _route,
        });
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

class _PrintNursingSummaryDialog extends ConsumerWidget {
  const _PrintNursingSummaryDialog({required this.detail});

  final NursingPatientDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingPatientSummary summary = detail.enrichedSummary;
    final String preview = _nursingSummaryText(context, detail);
    return AppDialog(
      title: Text(l10n.nursingActionPrintSummary),
      icon: const Icon(Icons.print_outlined),
      maxWidth: 720,
      scrollable: true,
      content: AppReportPreviewPanel(
        selectable: true,
        title: l10n.nursingReportTitle,
        child: Text(preview, style: Theme.of(context).textTheme.bodyMedium),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppReportActionButton.print(
          label: l10n.nursingActionPrintSummary,
          onPressed: () async {
            await printFormTemplateDocument(
              ref: ref,
              context: context,
              title: l10n.nursingReportTitle,
              subtitle: summary.displayTitle,
              metadata: <PrintFormMetadataItem>[
                PrintFormMetadataItem(
                  label: l10n.nursingAdmissionLabel,
                  value: summary.admissionId,
                ),
                PrintFormMetadataItem(
                  label: l10n.nursingLocationLabel,
                  value: summary.locationLabel ?? l10n.profileUnknownValue,
                ),
                PrintFormMetadataItem(
                  label: l10n.nursingPriorityColumnLabel,
                  value: _priorityStatus(context, summary).label,
                ),
              ],
              bodyHtml: _nursingSummaryHtml(context, detail),
              footerNote: l10n.nursingReportFooter,
            );
          },
        ),
      ],
    );
  }
}

class _HandoverDialog extends ConsumerStatefulWidget {
  const _HandoverDialog({this.escalation = false});

  final bool escalation;

  @override
  ConsumerState<_HandoverDialog> createState() => _HandoverDialogState();
}

class _HandoverDialogState extends ConsumerState<_HandoverDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  String? _toUserId;
  List<NursingUserOption> _userOptions = const <NursingUserOption>[];
  List<XFile> _attachments = const <XFile>[];
  bool _confirm = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    ref.read(nursingWorkspaceControllerProvider.notifier).searchUsers('').then((
      List<NursingUserOption> users,
    ) {
      if (mounted) {
        setState(() => _userOptions = users);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = widget.escalation
        ? l10n.nursingActionEscalate
        : l10n.nursingActionCreateHandover;
    return AppDialog(
      title: Text(title),
      icon: Icon(
        widget.escalation
            ? Icons.report_problem_outlined
            : Icons.swap_horiz_outlined,
      ),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_failure != null) ...<Widget>[
              AppFailureStateView(failure: _failure!),
              SizedBox(height: Theme.of(context).spacing.md),
            ],
            AppHandoverActionForm(
              toUserLabel: l10n.nursingHandoverToUserLabel,
              notesLabel: widget.escalation
                  ? l10n.nursingEscalationMessageLabel
                  : l10n.nursingHandoverNotesLabel,
              requiredMessage: l10n.validationRequired,
              toUserValue: _toUserId,
              userOptions: _userSelectOptions(),
              notesController: _notesController,
              enabled: !_isSaving,
              onToUserChanged: (String? value) {
                setState(() => _toUserId = value);
              },
              onUserSearchTextChanged: _loadUsers,
              confirmLabel: widget.escalation
                  ? l10n.nursingConfirmEscalationLabel
                  : null,
              confirmed: _confirm,
              onConfirmedChanged: widget.escalation
                  ? (bool value) => setState(() => _confirm = value)
                  : null,
              attachmentTitle: widget.escalation
                  ? null
                  : l10n.patientsDocumentUploadTitle,
              attachmentEmptyDescription: widget.escalation
                  ? null
                  : l10n.patientsDocumentUploadEmpty,
              attachmentChooseLabel: widget.escalation
                  ? null
                  : l10n.patientsChooseDocumentAction,
              attachmentClearLabel: widget.escalation
                  ? null
                  : l10n.patientsClearFiltersAction,
              attachmentFileNames: _attachments
                  .map((XFile file) => file.name)
                  .toList(growable: false),
              onChooseAttachments: widget.escalation
                  ? null
                  : _chooseAttachments,
              onClearAttachments: widget.escalation
                  ? null
                  : () => setState(() => _attachments = const <XFile>[]),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: title,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<AppSelectOption<String>> _userSelectOptions() {
    return <AppSelectOption<String>>[
      for (final NursingUserOption user in _userOptions)
        AppSelectOption<String>(value: user.id, label: user.searchableLabel),
    ];
  }

  Future<void> _loadUsers(String query) async {
    final List<NursingUserOption> users = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .searchUsers(query);
    if (!mounted) {
      return;
    }
    setState(() => _userOptions = users);
  }

  Future<void> _chooseAttachments() async {
    final List<XFile> files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: _nursingDocumentsTypeGroupLabel,
          extensions: <String>['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        ),
      ],
    );
    if (mounted && files.isNotEmpty) {
      setState(() => _attachments = files);
    }
  }

  Future<List<PatientDocumentUploadFile>> _documentUploadFiles() async {
    final List<PatientDocumentUploadFile> files = <PatientDocumentUploadFile>[];
    for (final XFile file in _attachments) {
      files.add(
        PatientDocumentUploadFile(
          name: file.name,
          bytes: await file.readAsBytes(),
          contentType: file.mimeType,
        ),
      );
    }
    return files;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? toUserId = _toUserId?.trim();
    if (toUserId == null || toUserId.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );
    final List<PatientDocumentUploadFile> documentFiles;
    try {
      documentFiles = widget.escalation
          ? const <PatientDocumentUploadFile>[]
          : await _documentUploadFiles();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = AppFailure.validation();
        _isSaving = false;
      });
      return;
    }
    final AppFailure? failure = widget.escalation
        ? await controller.escalate(
            toUserId: toUserId,
            message: _notesController.text.trim(),
          )
        : await controller.createHandover(
            toUserId: toUserId,
            notes: _notesController.text.trim(),
            documentFiles: documentFiles,
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

class _TransferDialog extends ConsumerStatefulWidget {
  const _TransferDialog({required this.detail});

  final NursingPatientDetail detail;

  @override
  ConsumerState<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<_TransferDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _bedController;
  late String _action;
  bool _confirm = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _bedController = TextEditingController();
    _action = _defaultTransferAction(widget.detail.activeTransfer?.status);
  }

  @override
  void dispose() {
    _bedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.nursingActionAcknowledgeTransfer),
      icon: const Icon(Icons.transfer_within_a_station_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _action,
              labelText: l10n.nursingTransferActionLabel,
              enabled: !_isSaving,
              options: _statusOptions(_transferActions),
              onChanged: (String? value) =>
                  setState(() => _action = value ?? _action),
            ),
            if (_action == 'COMPLETE')
              AppTextField(
                controller: _bedController,
                labelText: l10n.nursingToBedLabel,
                enabled: !_isSaving,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
            AppCheckboxField(
              title: l10n.nursingConfirmTransferLabel,
              value: _confirm,
              enabled: !_isSaving,
              validator: (bool? value) =>
                  value == true ? null : l10n.validationRequired,
              onChanged: (bool value) => setState(() => _confirm = value),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.nursingActionAcknowledgeTransfer,
        isSaving: _isSaving,
        onSubmit: _submit,
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
        .read(nursingWorkspaceControllerProvider.notifier)
        .updateTransfer(action: _action, toBedId: _bedController.text.trim());
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
  BuildContext context, {
  required String submitLabel,
  required bool isSaving,
  required VoidCallback onSubmit,
}) {
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

Future<void> _openVitalsDialog(
  BuildContext context, {
  NursingVitalSign? vital,
}) async {
  final AppLocalizations l10n = context.l10n;
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppRecordVitalsDialog(
        title: vital == null
            ? l10n.nursingActionRecordVitals
            : l10n.opdEditVitalsAction,
        submitLabel: vital == null
            ? l10n.nursingActionRecordVitals
            : l10n.opdEditVitalsAction,
        cancelLabel: l10n.commonCancelActionLabel,
        temperatureLabel: l10n.patientsTemperatureLabel,
        systolicLabel: l10n.nursingSystolicLabel,
        diastolicLabel: l10n.nursingDiastolicLabel,
        heartRateLabel: l10n.patientsHeartRateLabel,
        respiratoryRateLabel: l10n.patientsRespiratoryRateLabel,
        oxygenSaturationLabel: l10n.patientsOxygenSaturationLabel,
        weightLabel: l10n.patientsWeightLabel,
        heightLabel: l10n.patientsHeightLabel,
        bloodPressureLabel: l10n.patientsBloodPressureLabel,
        unitLabel: l10n.nursingVitalUnitLabel,
        recordedDateLabel: l10n.nursingRecordedAtLabel,
        recordedTimeLabel: l10n.opdTimeColumnLabel,
        datePickerLabel: l10n.nursingDatePickerLabel,
        invalidDateMessage: l10n.nursingInvalidDateMessage,
        timePickerLabel: l10n.appTimePickerAction,
        invalidTimeMessage: l10n.appTimeInvalidMessage,
        requiredMessage: l10n.validationRequired,
        initialValues: vital == null
            ? null
            : AppRecordVitalsInitialValues(
                id: vital.id,
                vitalType: vital.vitalType,
                value: vital.value,
                unit: vital.unit,
                systolicValue: vital.systolicValue,
                diastolicValue: vital.diastolicValue,
                recordedAt: vital.recordedAt,
              ),
        onSubmit: (List<Map<String, Object?>> payloads) {
          return ProviderScope.containerOf(context, listen: false)
              .read(nursingWorkspaceControllerProvider.notifier)
              .recordVitalSet(payloads);
        },
      ),
    ),
  );
}

Future<void> _openNoteDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: context.l10n.nursingActionAddNote,
        label: context.l10n.nursingNoteLabel,
        submitLabel: context.l10n.nursingActionAddNote,
        icon: const Icon(Icons.note_add_outlined),
        onSubmit: (String note) {
          return ProviderScope.containerOf(context, listen: false)
              .read(nursingWorkspaceControllerProvider.notifier)
              .addNursingNote(note);
        },
      ),
    ),
  );
}

Future<void> _openMedicationDialog(
  BuildContext context,
  NursingPatientDetail detail,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MedicationDialog(detail: detail),
    ),
  );
}

Future<void> _openPrescriptionDialog(
  BuildContext context,
  NursingWorkspaceController controller,
) async {
  final ClinicalReferenceData referenceData = await controller
      .prescriptionReferenceData();
  if (!context.mounted) {
    return;
  }
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        onSubmit: controller.prescribeMedication,
      ),
    ),
  );
}

Future<void> _openHandoverDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _HandoverDialog(),
    ),
  );
}

Future<void> _openEscalationDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _HandoverDialog(escalation: true),
    ),
  );
}

Future<void> _openTransferDialog(
  BuildContext context,
  NursingPatientDetail detail,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferDialog(detail: detail),
    ),
  );
}

Future<void> _openPrintSummaryDialog(
  BuildContext context,
  NursingPatientDetail detail,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PrintNursingSummaryDialog(detail: detail),
    ),
  );
}

Future<void> _openAcceptHandoverDialog(
  BuildContext context,
  NursingWorkspaceController controller,
  NursingHandover handover,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: context.l10n.nursingActionAcceptHandover,
        label: context.l10n.nursingHandoverNotesLabel,
        submitLabel: context.l10n.nursingActionAcceptHandover,
        icon: const Icon(Icons.note_add_outlined),
        onSubmit: (String note) => controller.acceptHandover(handover, note),
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
    ).showSnackBar(SnackBar(content: Text(context.l10n.nursingSavedMessage)));
  }
}

List<AppNursingRecordEntry> _vitalRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  final AppLocalizations l10n = context.l10n;
  return detail.vitalSigns
      .map(
        (NursingVitalSign vital) => AppNursingRecordEntry(
          title: _apiLabel(vital.vitalType),
          subtitle: _dateTimeLabel(context, vital.recordedAt),
          body: vital.displayValue,
          icon: Icons.monitor_heart_outlined,
          trailingLabel: l10n.opdEditVitalsAction,
          trailingIcon: Icons.edit_outlined,
          onTrailingPressed: () => _openVitalsDialog(context, vital: vital),
        ),
      )
      .toList(growable: false);
}

String _nursingSummaryText(BuildContext context, NursingPatientDetail detail) {
  final AppLocalizations l10n = context.l10n;
  final NursingPatientSummary summary = detail.enrichedSummary;
  final List<String> lines = <String>[
    l10n.nursingReportTitle,
    '',
    '${l10n.nursingPatientFilterLabel}: ${summary.displayTitle}',
    '${l10n.nursingAdmissionLabel}: ${summary.admissionId}',
    '${l10n.nursingLocationLabel}: ${summary.locationLabel ?? l10n.profileUnknownValue}',
    '${l10n.nursingPriorityColumnLabel}: ${_priorityStatus(context, summary).label}',
    '${l10n.nursingTaskTypeColumnLabel}: ${_taskTypeLabel(context, summary)}',
    '',
    l10n.nursingObservationsTitle,
    ..._recordsAsLines(context, _vitalRecords(context, detail)),
    '',
    l10n.nursingMedicationsTitle,
    ..._recordsAsLines(context, _medicationRecords(context, detail)),
    '',
    l10n.nursingNotesTitle,
    ..._recordsAsLines(context, _noteRecords(context, detail)),
    '',
    l10n.nursingCarePlansTitle,
    ..._recordsAsLines(context, _carePlanRecords(context, detail)),
    '',
    l10n.nursingHandoversTitle,
    ..._recordsAsLines(context, _handoverRecords(context, detail)),
    '',
    l10n.nursingWardAdmissionChecklistTitle,
    for (final AppCareTaskChecklistItem item in _admissionChecklistItems(
      context,
      detail,
    ))
      '- ${item.title}: ${item.isComplete ? l10n.nursingChecklistCompleteStatus : l10n.nursingChecklistPendingStatus}',
  ];
  return lines.join('\n');
}

String _nursingSummaryHtml(BuildContext context, NursingPatientDetail detail) {
  final String text = _nursingSummaryText(context, detail);
  return '<p>${text.split('\n').map(_htmlEscape).join('<br />')}</p>';
}

List<String> _recordsAsLines(
  BuildContext context,
  List<AppNursingRecordEntry> records,
) {
  if (records.isEmpty) {
    return <String>['- ${context.l10n.nursingNoRecordsLabel}'];
  }
  return records
      .map(
        (AppNursingRecordEntry record) =>
            '- ${_joinDisplay(<String?>[record.title, record.subtitle, record.body, record.status?.label])}',
      )
      .toList(growable: false);
}

String _htmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

List<AppNursingRecordEntry> _noteRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.nursingNotes
      .map(
        (NursingNoteRecord note) => AppNursingRecordEntry(
          title: note.nurseName ?? context.l10n.profileUnknownValue,
          subtitle: _dateTimeLabel(context, note.createdAt),
          body: note.note,
          icon: Icons.edit_note_outlined,
        ),
      )
      .toList(growable: false);
}

List<AppNursingRecordEntry> _medicationRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  final List<AppNursingRecordEntry> records = <AppNursingRecordEntry>[
    for (final MedicationReminder reminder in detail.medicationReminders)
      AppNursingRecordEntry(
        title: reminder.displayTitle,
        subtitle: _joinDisplay(<String?>[
          _dateTimeLabel(context, reminder.scheduledAt),
          reminder.frequency,
        ]),
        body: _joinDisplay(<String?>[
          reminder.dose,
          reminder.unit,
          reminder.route == null ? null : _apiLabel(reminder.route!),
        ]),
        icon: Icons.schedule_outlined,
        status: _statusFromValue(reminder.status),
      ),
    for (final MedicationSuggestion suggestion in detail.medicationSuggestions)
      AppNursingRecordEntry(
        title: suggestion.displayTitle,
        subtitle: _joinDisplay(<String?>[
          suggestion.frequency,
          suggestion.orderStatus,
        ]),
        body: _joinDisplay(<String?>[
          suggestion.dose,
          suggestion.unit,
          suggestion.route == null ? null : _apiLabel(suggestion.route!),
        ]),
        icon: Icons.medication_outlined,
        status: _statusFromValue(suggestion.itemStatus),
      ),
    for (final MedicationAdministrationRecord medication
        in detail.medicationAdministrations)
      AppNursingRecordEntry(
        title: _medicationAdministrationTitle(medication, detail),
        subtitle: _dateTimeLabel(context, medication.administeredAt),
        body: _joinDisplay(<String?>[
          medication.dose,
          medication.unit,
          medication.route == null ? null : _apiLabel(medication.route!),
        ]),
        icon: Icons.done_all_outlined,
        status: AppWorkspaceStatus(
          label: _apiLabel('ADMINISTERED'),
          tone: AppWorkspaceStatusTone.success,
        ),
      ),
  ];
  return records;
}

String _medicationAdministrationTitle(
  MedicationAdministrationRecord medication,
  NursingPatientDetail detail,
) {
  final String? prescriptionId = medication.prescriptionId?.trim();
  if (prescriptionId != null && prescriptionId.isNotEmpty) {
    for (final MedicationSuggestion suggestion
        in detail.medicationSuggestions) {
      if (suggestion.id == prescriptionId) {
        return suggestion.displayTitle;
      }
    }
    for (final MedicationReminder reminder in detail.medicationReminders) {
      if (reminder.prescriptionId == prescriptionId) {
        return reminder.displayTitle;
      }
    }
  }
  final String fallback = _joinDisplay(<String?>[
    medication.dose,
    medication.unit,
    medication.route == null ? null : _apiLabel(medication.route!),
  ]);
  return fallback.isEmpty ? _apiLabel('ADMINISTERED') : fallback;
}

List<AppNursingRecordEntry> _carePlanRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.carePlans
      .map(
        (NursingCarePlan plan) => AppNursingRecordEntry(
          title: plan.plan ?? plan.id,
          subtitle: _joinDisplay(<String?>[
            _dateLabel(context, plan.startDate),
            _dateLabel(context, plan.endDate),
          ]),
          icon: Icons.playlist_add_check_outlined,
          status: _statusFromValue(plan.status),
        ),
      )
      .toList(growable: false);
}

List<AppNursingRecordEntry> _handoverRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.handovers
      .map(
        (NursingHandover handover) => AppNursingRecordEntry(
          title: handover.toUserId ?? handover.id,
          subtitle: _dateTimeLabel(context, handover.createdAt),
          body: handover.signoffNotes,
          icon: Icons.swap_horiz_outlined,
          status: _statusFromValue(handover.status),
        ),
      )
      .toList(growable: false);
}

List<AppCareTaskChecklistItem> _admissionChecklistItems(
  BuildContext context,
  NursingPatientDetail detail,
) {
  final AppLocalizations l10n = context.l10n;
  final NursingPatientSummary summary = detail.enrichedSummary;
  AppWorkspaceStatus status(bool complete) {
    return AppWorkspaceStatus(
      label: complete
          ? l10n.nursingChecklistCompleteStatus
          : l10n.nursingChecklistPendingStatus,
      tone: complete
          ? AppWorkspaceStatusTone.success
          : AppWorkspaceStatusTone.warning,
    );
  }

  final bool locationReady =
      summary.locationLabel != null || summary.hasActiveBed;
  final bool handoverReady = detail.handovers.any(
    (NursingHandover item) => item.admissionId == summary.admissionId,
  );
  final bool vitalsReady = detail.vitalSigns.isNotEmpty;
  final bool carePlanReady = detail.carePlans.isNotEmpty;
  final bool medicationReady = !detail.hasMedicationDue;
  final bool dischargeReady = !summary.isDischargePending;

  return <AppCareTaskChecklistItem>[
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistLocationTitle,
      subtitle: locationReady
          ? summary.locationLabel ?? l10n.nursingChecklistLocationReadyBody
          : l10n.nursingChecklistLocationPendingBody,
      isComplete: locationReady,
      status: status(locationReady),
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistHandoverTitle,
      subtitle: handoverReady
          ? l10n.nursingChecklistHandoverReadyBody
          : l10n.nursingChecklistHandoverPendingBody,
      isComplete: handoverReady,
      status: status(handoverReady),
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistVitalsTitle,
      subtitle: vitalsReady
          ? _dateTimeLabel(context, detail.vitalSigns.first.recordedAt)
          : l10n.nursingChecklistVitalsPendingBody,
      isComplete: vitalsReady,
      status: status(vitalsReady),
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistCarePlanTitle,
      subtitle: carePlanReady
          ? l10n.nursingChecklistCarePlanReadyBody
          : l10n.nursingChecklistCarePlanPendingBody,
      isComplete: carePlanReady,
      status: status(carePlanReady),
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistMedicationTitle,
      subtitle: medicationReady
          ? l10n.nursingChecklistMedicationReadyBody
          : l10n.nursingChecklistMedicationPendingBody,
      isComplete: medicationReady,
      status: status(medicationReady),
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistDischargeTitle,
      subtitle: dischargeReady
          ? l10n.nursingChecklistDischargeReadyBody
          : l10n.nursingChecklistDischargePendingBody,
      isComplete: dischargeReady,
      status: status(dischargeReady),
    ),
  ];
}

List<AppRosterAssignmentView> _rosterViews(
  BuildContext context,
  List<NursingRosterAssignment> rosters,
) {
  return rosters
      .map(
        (NursingRosterAssignment roster) => AppRosterAssignmentView(
          title: roster.id,
          subtitle: _joinDisplay(<String?>[
            _dateTimeLabel(context, roster.periodStart),
            _dateTimeLabel(context, roster.periodEnd),
            roster.facilityId,
            roster.departmentId,
          ]),
          status: _statusFromValue(roster.status),
        ),
      )
      .toList(growable: false);
}

List<AppWardActivityEntry> _handoverActivityEntries(
  BuildContext context,
  List<NursingHandover> handovers,
) {
  return handovers
      .map(
        (NursingHandover handover) => AppWardActivityEntry(
          title: handover.toUserId ?? handover.id,
          subtitle: _dateTimeLabel(context, handover.createdAt),
          body: handover.signoffNotes,
          icon: Icons.swap_horiz_outlined,
          status: _statusFromValue(handover.status),
        ),
      )
      .toList(growable: false);
}

List<AppWardActivityEntry> _activityEntries(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return <AppWardActivityEntry>[
    for (final NursingCriticalAlert alert in detail.criticalAlerts)
      AppWardActivityEntry(
        title: alert.severity == null ? alert.id : _apiLabel(alert.severity!),
        subtitle: _dateTimeLabel(context, alert.createdAt),
        body: alert.message,
        icon: Icons.report_problem_outlined,
        status: _statusFromValue(alert.severity),
      ),
    for (final NursingTimelineItem item in <NursingTimelineItem>[
      ...detail.icuObservations,
      ...detail.timeline,
    ])
      AppWardActivityEntry(
        title: _apiLabel(item.type),
        subtitle: _dateTimeLabel(context, item.occurredAt),
        body: item.label,
        icon: _timelineIcon(item.type),
      ),
  ];
}

List<AppSearchBarFieldChoice> _worklistSearchFields(AppLocalizations l10n) {
  return <AppSearchBarFieldChoice>[
    AppSearchBarFieldChoice(
      field: 'patient',
      label: l10n.opdPatientColumnLabel,
    ),
    AppSearchBarFieldChoice(
      field: 'admission',
      label: l10n.nursingAdmissionColumnLabel,
    ),
    AppSearchBarFieldChoice(
      field: 'encounter',
      label: l10n.nursingEncounterLabel,
    ),
    AppSearchBarFieldChoice(field: 'ward', label: l10n.patientsWardLabel),
    AppSearchBarFieldChoice(field: 'room', label: l10n.patientsRoomLabel),
    AppSearchBarFieldChoice(field: 'bed', label: l10n.nursingBedLabel),
    AppSearchBarFieldChoice(
      field: 'observation',
      label: l10n.nursingObservationsTitle,
    ),
    AppSearchBarFieldChoice(
      field: 'task_type',
      label: l10n.nursingTaskTypeColumnLabel,
    ),
    AppSearchBarFieldChoice(field: 'status', label: l10n.opdStatusColumnLabel),
    AppSearchBarFieldChoice(
      field: 'priority',
      label: l10n.nursingPriorityColumnLabel,
    ),
  ];
}

List<AppSearchBarTextFilter> _worklistTextFilters(AppLocalizations l10n) {
  return <AppSearchBarTextFilter>[
    AppSearchBarTextFilter(
      key: 'patient',
      label: l10n.nursingPatientFilterLabel,
      hintText: l10n.nursingPatientFilterHint,
      icon: Icons.person_search_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'admission',
      label: l10n.nursingAdmissionColumnLabel,
      icon: Icons.hotel_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'encounter',
      label: l10n.nursingEncounterLabel,
      icon: Icons.medical_information_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'ward',
      label: l10n.patientsWardLabel,
      hintText: l10n.nursingWardFilterHint,
      icon: Icons.local_hospital_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'room',
      label: l10n.patientsRoomLabel,
      icon: Icons.meeting_room_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'bed',
      label: l10n.nursingBedLabel,
      icon: Icons.bed_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'observation',
      label: l10n.nursingObservationsTitle,
      icon: Icons.monitor_heart_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'task_type',
      label: l10n.nursingTaskTypeColumnLabel,
      hintText: l10n.nursingCareTaskFilterHint,
      icon: Icons.playlist_add_check_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'assigned_nurse',
      label: l10n.nursingResponsibleNurseColumnLabel,
      icon: Icons.badge_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'shift',
      label: l10n.nursingShiftFilterLabel,
      hintText: l10n.nursingShiftFilterHint,
      icon: Icons.schedule_outlined,
    ),
  ];
}

List<AppSearchBarFilterGroup> _worklistFilterGroups(AppLocalizations l10n) {
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: 'scope',
      label: l10n.nursingScopeFilterLabel,
      allLabel: l10n.nursingScopeAllLabel,
      choices: _scopeFilterChoices(l10n),
    ),
    AppSearchBarFilterGroup(
      key: 'status',
      label: l10n.opdStatusColumnLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'ADMITTED_PENDING_BED',
          label: _apiLabel('ADMITTED_PENDING_BED'),
          icon: Icons.hotel_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'ADMITTED_IN_BED',
          label: _apiLabel('ADMITTED_IN_BED'),
          icon: Icons.bed_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'TRANSFER_REQUESTED',
          label: _apiLabel('TRANSFER_REQUESTED'),
          icon: Icons.transfer_within_a_station_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'TRANSFER_IN_PROGRESS',
          label: _apiLabel('TRANSFER_IN_PROGRESS'),
          icon: Icons.transfer_within_a_station_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'DISCHARGE_PLANNED',
          label: _apiLabel('DISCHARGE_PLANNED'),
          icon: Icons.logout_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'DISCHARGED',
          label: _apiLabel('DISCHARGED'),
          icon: Icons.task_alt_outlined,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'priority',
      label: l10n.nursingPriorityFilterLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'HIGH',
          label: l10n.nursingPriorityHighLabel,
          icon: Icons.priority_high_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'MEDIUM',
          label: l10n.nursingPriorityMediumLabel,
          icon: Icons.warning_amber_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'ROUTINE',
          label: l10n.nursingPriorityRoutineLabel,
          icon: Icons.task_alt_outlined,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'transfer_status',
      label: l10n.nursingTransferPendingSummaryLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final String value in <String>[
          'REQUESTED',
          'APPROVED',
          'IN_PROGRESS',
          'COMPLETED',
          'CANCELLED',
        ])
          AppSearchBarFilterChoice(
            value: value,
            label: _apiLabel(value),
            icon: Icons.transfer_within_a_station_outlined,
          ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'handover_status',
      label: l10n.nursingHandoverPendingSummaryLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'PENDING',
          label: _apiLabel('PENDING'),
          icon: Icons.swap_horiz_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'NONE',
          label: l10n.nursingNoRecordsLabel,
          icon: Icons.check_circle_outline,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'discharge_status',
      label: l10n.dischargeStatusFilterLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final String value in <String>[
          'PLANNED',
          'DISCHARGE_PLANNED',
          'COMPLETED',
          'DISCHARGED',
        ])
          AppSearchBarFilterChoice(
            value: value,
            label: _apiLabel(value),
            icon: Icons.logout_outlined,
          ),
      ],
    ),
  ];
}

AppSearchBarFilterValue _filterValueFromQuery(NursingWorklistQuery query) {
  return AppSearchBarFilterValue(
    field: query.searchField.trim().isEmpty ? null : query.searchField,
    dateFrom: query.dateFrom,
    dateTo: query.dateTo,
    texts: Map<String, String>.unmodifiable(<String, String>{
      if (query.patient.trim().isNotEmpty) 'patient': query.patient,
      if (query.admission.trim().isNotEmpty) 'admission': query.admission,
      if (query.encounter.trim().isNotEmpty) 'encounter': query.encounter,
      if (query.ward.trim().isNotEmpty) 'ward': query.ward,
      if (query.room.trim().isNotEmpty) 'room': query.room,
      if (query.bed.trim().isNotEmpty) 'bed': query.bed,
      if (query.observation.trim().isNotEmpty) 'observation': query.observation,
      if (query.taskType.trim().isNotEmpty) 'task_type': query.taskType,
      if (query.assignedNurse.trim().isNotEmpty)
        'assigned_nurse': query.assignedNurse,
      if (query.shift.trim().isNotEmpty) 'shift': query.shift,
    }),
    options: Map<String, String>.unmodifiable(<String, String>{
      if (query.scope != NursingQueueScope.all)
        'scope': _scopeCode(query.scope),
      if (query.status.trim().isNotEmpty) 'status': query.status,
      if (query.priority.trim().isNotEmpty) 'priority': query.priority,
      if (query.transferStatus.trim().isNotEmpty)
        'transfer_status': query.transferStatus,
      if (query.handoverStatus.trim().isNotEmpty)
        'handover_status': query.handoverStatus,
      if (query.dischargeStatus.trim().isNotEmpty)
        'discharge_status': query.dischargeStatus,
    }),
  );
}

List<AppSearchBarFilterChoice> _scopeFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: _scopeCode(NursingQueueScope.assignedWard),
      label: l10n.nursingScopeAssignedWardLabel,
      icon: Icons.local_hospital_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _scopeCode(NursingQueueScope.urgent),
      label: l10n.nursingScopeUrgentLabel,
      icon: Icons.priority_high_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _scopeCode(NursingQueueScope.medicationDue),
      label: l10n.nursingScopeMedicationDueLabel,
      icon: Icons.medication_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _scopeCode(NursingQueueScope.handoverPending),
      label: l10n.nursingScopeHandoverPendingLabel,
      icon: Icons.swap_horiz_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _scopeCode(NursingQueueScope.transferPending),
      label: l10n.nursingScopeTransferPendingLabel,
      icon: Icons.transfer_within_a_station_outlined,
    ),
    AppSearchBarFilterChoice(
      value: _scopeCode(NursingQueueScope.dischargePending),
      label: l10n.nursingScopeDischargePendingLabel,
      icon: Icons.logout_outlined,
    ),
  ];
}

NursingQueueScope _scopeFromFilterValue(String? value) {
  return switch (value) {
    'urgent' => NursingQueueScope.urgent,
    'medication_due' => NursingQueueScope.medicationDue,
    'handover_pending' => NursingQueueScope.handoverPending,
    'transfer_pending' => NursingQueueScope.transferPending,
    'discharge_pending' => NursingQueueScope.dischargePending,
    'assigned_ward' => NursingQueueScope.assignedWard,
    'all' => NursingQueueScope.all,
    _ => NursingQueueScope.all,
  };
}

String _scopeCode(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.assignedWard => 'assigned_ward',
    NursingQueueScope.urgent => 'urgent',
    NursingQueueScope.medicationDue => 'medication_due',
    NursingQueueScope.handoverPending => 'handover_pending',
    NursingQueueScope.transferPending => 'transfer_pending',
    NursingQueueScope.dischargePending => 'discharge_pending',
    NursingQueueScope.all => 'all',
  };
}

const String _nursingDocumentsTypeGroupLabel = 'Documents';

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

AppWorkspaceStatus _summaryStatus(NursingPatientSummary summary) {
  final String value =
      summary.stage ??
      summary.admissionStatus ??
      summary.transferStatus ??
      summary.nextStep ??
      '';
  return AppWorkspaceStatus(label: _apiLabel(value), tone: _statusTone(value));
}

AppWorkspaceStatus? _statusFromValue(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return AppWorkspaceStatus(label: _apiLabel(value), tone: _statusTone(value));
}

AppWorkspaceStatusTone _statusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'DISCHARGED' ||
    'COMPLETED' ||
    'ACCEPTED' ||
    'NORMAL' ||
    'GIVEN' => AppWorkspaceStatusTone.success,
    'CRITICAL' ||
    'HIGH' ||
    'MISSED' ||
    'REFUSED' ||
    'CANCELLED' => AppWorkspaceStatusTone.error,
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' ||
    'DISCHARGE_PLANNED' ||
    'REQUESTED' ||
    'PENDING' ||
    'DELAYED' => AppWorkspaceStatusTone.warning,
    'ADMITTED_IN_BED' ||
    'ACTIVE' ||
    'APPROVED' ||
    'IN_PROGRESS' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData _timelineIcon(String type) {
  return switch (type) {
    'NURSING_NOTE' => Icons.edit_note_outlined,
    'MEDICATION_ADMINISTRATION' => Icons.medication_outlined,
    'MEDICATION_REMINDER' => Icons.schedule_outlined,
    'TRANSFER' => Icons.transfer_within_a_station_outlined,
    'ICU_OBSERVATION' => Icons.monitor_heart_outlined,
    'CRITICAL_ALERT' => Icons.report_problem_outlined,
    _ => Icons.history_outlined,
  };
}

String _admissionLabel(BuildContext context, NursingPatientSummary item) {
  return _joinDisplay(<String?>[
        item.admissionId,
        item.admissionStatus == null ? null : _apiLabel(item.admissionStatus!),
      ]).trim().isEmpty
      ? context.l10n.profileUnknownValue
      : _joinDisplay(<String?>[
          item.admissionId,
          item.admissionStatus == null
              ? null
              : _apiLabel(item.admissionStatus!),
        ]);
}

String _taskTypeLabel(BuildContext context, NursingPatientSummary item) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.taskTypeCode) {
    'MEDICATION_DUE' => l10n.nursingMedicationDueSummaryLabel,
    'HANDOVER_PENDING' => l10n.nursingHandoverPendingSummaryLabel,
    'TRANSFER_PENDING' => l10n.nursingTransferPendingSummaryLabel,
    'DISCHARGE_PENDING' => l10n.nursingDischargePendingSummaryLabel,
    final String value => _apiLabel(value),
  };
}

AppWorkspaceStatus _priorityStatus(
  BuildContext context,
  NursingPatientSummary item,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.priorityCode) {
    'HIGH' => AppWorkspaceStatus(
      label: l10n.nursingPriorityHighLabel,
      tone: AppWorkspaceStatusTone.error,
    ),
    'MEDIUM' => AppWorkspaceStatus(
      label: l10n.nursingPriorityMediumLabel,
      tone: AppWorkspaceStatusTone.warning,
    ),
    _ => AppWorkspaceStatus(label: l10n.nursingPriorityRoutineLabel),
  };
}

String _dueTimeLabel(BuildContext context, NursingPatientSummary item) {
  if (item.isUrgent || item.hasMedicationDue || item.hasPendingTransfer) {
    return context.l10n.nursingDueNowLabel;
  }
  return _dateTimeLabel(context, item.dueReferenceAt);
}

String _lastObservationLabel(BuildContext context, NursingPatientSummary item) {
  final String value = item.lastObservation?.trim() ?? '';
  return value.isEmpty ? context.l10n.profileUnknownValue : value;
}

String _responsibleNurseLabel(
  BuildContext context,
  NursingPatientSummary item,
) {
  if (item.pendingHandoverCount > 0) {
    return context.l10n.nursingHandoverPendingSummaryLabel;
  }
  return context.l10n.nursingAssignedShiftLabel;
}

String _responsibleNurseSortValue(NursingPatientSummary item) {
  return item.pendingHandoverCount > 0 ? 'handover pending' : 'assigned shift';
}

String _pageLabel(BuildContext context, AppPage<NursingWorkItem> page) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }
  final int from = page.request.pageIndex * page.request.pageSize + 1;
  final int to = (from + page.items.length - 1).clamp(from, total);
  return context.l10n.opdPageLabel(from, to, total);
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String? _dateLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.mediumDate(value, Localizations.localeOf(context));
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
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String _defaultTransferAction(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'REQUESTED' => 'APPROVE',
    'APPROVED' => 'START',
    'IN_PROGRESS' => 'COMPLETE',
    _ => 'APPROVE',
  };
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

const List<String> _medicationRoutes = <String>[
  'ORAL',
  'IV',
  'IM',
  'SC',
  'TOPICAL',
  'INHALATION',
  'RECTAL',
  'OTHER',
];

String? _supportedMedicationRoute(String? route) {
  final String normalized = (route ?? '').trim().toUpperCase();
  return _medicationRoutes.contains(normalized) ? normalized : null;
}

const List<String> _transferActions = <String>[
  'APPROVE',
  'START',
  'COMPLETE',
  'CANCEL',
];

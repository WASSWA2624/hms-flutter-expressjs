import 'package:flutter/material.dart';
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
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
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
  late final TextEditingController _wardController;
  late AppSearchBarFilterValue _filterValue;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _wardController = TextEditingController(text: widget.state.query.ward);
    _filterValue = _filterValueFromQuery(widget.state.query);
  }

  @override
  void didUpdateWidget(covariant _NursingWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (oldWidget.state.query.ward != widget.state.query.ward &&
        _wardController.text != widget.state.query.ward) {
      _wardController.text = widget.state.query.ward;
    }
    if (oldWidget.state.query != widget.state.query) {
      _filterValue = _filterValueFromQuery(widget.state.query);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _wardController.dispose();
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
          onPressed: () =>
              controller.applyScope(NursingQueueScope.assignedWard),
        ),
        _summaryCard(
          context,
          label: l10n.nursingUrgentSummaryLabel,
          value: state.urgentCount,
          icon: Icons.priority_high_outlined,
          tone: AppWorkspaceStatusTone.error,
          onPressed: () => controller.applyScope(NursingQueueScope.urgent),
        ),
        _summaryCard(
          context,
          label: l10n.nursingMedicationDueSummaryLabel,
          value: state.medicationDueCount,
          icon: Icons.medication_outlined,
          tone: AppWorkspaceStatusTone.warning,
          onPressed: () =>
              controller.applyScope(NursingQueueScope.medicationDue),
        ),
        _summaryCard(
          context,
          label: l10n.nursingHandoverPendingSummaryLabel,
          value: state.handoverPendingCount,
          icon: Icons.swap_horiz_outlined,
          tone: AppWorkspaceStatusTone.neutral,
          onPressed: () =>
              controller.applyScope(NursingQueueScope.handoverPending),
        ),
        _summaryCard(
          context,
          label: l10n.nursingTransferPendingSummaryLabel,
          value: state.transferPendingCount,
          icon: Icons.transfer_within_a_station_outlined,
          tone: AppWorkspaceStatusTone.warning,
          onPressed: () =>
              controller.applyScope(NursingQueueScope.transferPending),
        ),
        _summaryCard(
          context,
          label: l10n.nursingDischargePendingSummaryLabel,
          value: state.dischargePendingCount,
          icon: Icons.logout_outlined,
          tone: AppWorkspaceStatusTone.success,
          onPressed: () =>
              controller.applyScope(NursingQueueScope.dischargePending),
        ),
      ],
      filters: AppWorkspaceFilterBar(
        semanticLabel: l10n.nursingFiltersLabel,
        expandSearch: true,
        search: AppSearchBar(
          controller: _searchController,
          semanticLabel: l10n.nursingSearchLabel,
          hintText: l10n.nursingSearchHint,
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
          filterValue: _filterValue,
          hasActiveFilters: state.query.hasAdvancedFilters,
          onFilterChanged: (AppSearchBarFilterValue value) {
            setState(() {
              _filterValue = value;
            });
            controller
                .applyAdvancedFilters(
                  patient: value.text('patient'),
                  ward: value.text('ward'),
                  unit: value.text('unit'),
                  shift: value.text('shift'),
                  careTask: value.text('care_task'),
                  admissionStatus: value.text('admission_status'),
                  dischargeReadiness: value.text('discharge_readiness'),
                  priority: value.option('priority'),
                  dateFrom: value.dateFrom,
                  dateTo: value.dateTo,
                )
                .then((AppFailure? failure) {
                  if (context.mounted) {
                    _showFailureIfNeeded(context, failure);
                  }
                });
          },
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
        ),
        filters: <Widget>[
          AppSelectField<NursingQueueScope>(
            value: state.query.scope,
            labelText: l10n.nursingScopeFilterLabel,
            options: _scopeOptions(l10n),
            onChanged: (NursingQueueScope? value) {
              if (value != null) {
                controller.applyScope(value);
              }
            },
          ),
          AppTextField(
            controller: _wardController,
            labelText: l10n.nursingWardFilterLabel,
            hintText: l10n.nursingWardFilterHint,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: controller.applyWard,
          ),
        ],
      ),
      body: _NursingWorklistPanel(state: state),
      detail: _NursingDetailPanel(state: state),
      activity: _NursingShiftContextPanel(state: state),
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
  const _NursingWorklistPanel({required this.state});

  final NursingWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.nursingWorklistTitle,
      description: l10n.nursingWorklistDescription,
      child: AppPaginatedListTable<NursingWorkItem>(
        page: state.worklist,
        isLoading: state.isRefreshing,
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<NursingWorkItem> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        onRowSelected: controller.selectPatient,
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.nursingNoWorklistTitle,
          body: l10n.nursingNoWorklistBody,
          icon: Icons.assignment_outlined,
        ),
        columns: <AppListTableColumn<NursingWorkItem>>[
          AppListTableColumn<NursingWorkItem>(
            label: l10n.opdPatientColumnLabel,
            cellBuilder: (BuildContext context, NursingWorkItem item) {
              return _NursingPatientCell(item: item);
            },
          ),
          AppListTableColumn<NursingWorkItem>(
            label: l10n.nursingLocationColumnLabel,
            cellBuilder: (BuildContext context, NursingWorkItem item) {
              return Text(item.locationLabel ?? l10n.profileUnknownValue);
            },
          ),
          AppListTableColumn<NursingWorkItem>(
            label: l10n.nursingAdmissionColumnLabel,
            cellBuilder: (BuildContext context, NursingWorkItem item) {
              return Text(_admissionLabel(context, item));
            },
          ),
          AppListTableColumn<NursingWorkItem>(
            label: l10n.nursingTaskTypeColumnLabel,
            cellBuilder: (BuildContext context, NursingWorkItem item) {
              return Text(_taskTypeLabel(context, item));
            },
          ),
          AppListTableColumn<NursingWorkItem>(
            label: l10n.nursingPriorityColumnLabel,
            cellBuilder: (BuildContext context, NursingWorkItem item) {
              return AppWorkspaceStatusBadge(status: _priorityStatus(context, item));
            },
          ),
          AppListTableColumn<NursingWorkItem>(
            label: l10n.nursingDueTimeColumnLabel,
            cellBuilder: (BuildContext context, NursingWorkItem item) {
              return Text(_dueTimeLabel(context, item));
            },
          ),
          AppListTableColumn<NursingWorkItem>(
            label: l10n.nursingResponsibleNurseColumnLabel,
            cellBuilder: (BuildContext context, NursingWorkItem item) {
              return Text(_responsibleNurseLabel(context, item));
            },
          ),
          AppListTableColumn<NursingWorkItem>(
            label: l10n.opdStatusColumnLabel,
            cellBuilder: (BuildContext context, NursingWorkItem item) {
              return AppWorkspaceStatusBadge(status: _summaryStatus(item));
            },
          ),
        ],
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
                    AppWorkspaceStatusBadge(status: _priorityStatus(context, item)),
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

class _NursingDetailPanel extends ConsumerWidget {
  const _NursingDetailPanel({required this.state});

  final NursingWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingPatientDetail? detail = state.selectedDetail;
    if (detail == null) {
      return AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.nursingNoSelectionTitle,
        body: l10n.nursingNoSelectionBody,
        icon: Icons.bed_outlined,
      );
    }

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

class _NursingActionBar extends ConsumerWidget {
  const _NursingActionBar({required this.detail});

  final NursingPatientDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.nursingActionsTitle,
      child: AppAccessActionGate(
        requirement: _NursingWorkspaceContentState.writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return AppActionList(
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
                label: l10n.nursingActionCompleteTask,
                leadingIcon: Icons.playlist_add_check_outlined,
                enabled: isAllowed,
                onPressed: () => _openTaskDialog(context),
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
                    onPressed: () => _openAcceptHandoverDialog(
                      context,
                      controller,
                      handover,
                    ),
                  ),
            ],
          );
        },
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
  final List<_NursingRecordView> records;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: title,
      child: _RecordList(records: records, emptyLabel: emptyLabel),
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
      child: _RecordList(
        records: _handoverRecords(context, detail),
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
          Text(l10n.nursingRosterTitle, style: Theme.of(context).textTheme.titleSmall),
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

class _RecordList extends StatelessWidget {
  const _RecordList({required this.records, required this.emptyLabel});

  final List<_NursingRecordView> records;
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
          _RecordRow(record: records[index]),
        ],
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final _NursingRecordView record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            record.icon,
            size: theme.appTokens.listIconSize,
            color: colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(record.title, style: theme.textTheme.titleSmall),
                if (record.subtitle != null) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    record.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (record.body != null) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(record.body!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (record.status != null) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            AppWorkspaceStatusBadge(status: record.status!),
          ],
        ],
      ),
    );
  }
}

final class _NursingRecordView {
  const _NursingRecordView({
    required this.title,
    required this.icon,
    this.subtitle,
    this.body,
    this.status,
  });

  final String title;
  final String? subtitle;
  final String? body;
  final IconData icon;
  final AppWorkspaceStatus? status;
}

class _VitalsDialog extends ConsumerStatefulWidget {
  const _VitalsDialog();

  @override
  ConsumerState<_VitalsDialog> createState() => _VitalsDialogState();
}

class _VitalsDialogState extends ConsumerState<_VitalsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _temperatureController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenSaturationController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _recordedAtController;
  String _bloodPressureUnit = AppVitalsUnits.bloodPressureMmHg;
  String _temperatureUnit = AppVitalsUnits.temperatureCelsius;
  String _weightUnit = AppVitalsUnits.weightKilograms;
  String _heightUnit = AppVitalsUnits.heightCentimeters;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _temperatureController = TextEditingController();
    _systolicController = TextEditingController();
    _diastolicController = TextEditingController();
    _heartRateController = TextEditingController();
    _respiratoryRateController = TextEditingController();
    _oxygenSaturationController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _recordedAtController = TextEditingController(
      text: DateTime.now().toIso8601String(),
    );
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _recordedAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.nursingActionRecordVitals),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      maxWidth: 760,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppVitalsForm(
              temperatureController: _temperatureController,
              systolicController: _systolicController,
              diastolicController: _diastolicController,
              heartRateController: _heartRateController,
              respiratoryRateController: _respiratoryRateController,
              oxygenSaturationController: _oxygenSaturationController,
              weightController: _weightController,
              heightController: _heightController,
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
              bloodPressureUnit: _bloodPressureUnit,
              temperatureUnit: _temperatureUnit,
              weightUnit: _weightUnit,
              heightUnit: _heightUnit,
              onBloodPressureUnitChanged: (String? value) {
                if (value != null) {
                  setState(() => _bloodPressureUnit = value);
                }
              },
              onTemperatureUnitChanged: (String? value) {
                if (value != null) {
                  setState(() => _temperatureUnit = value);
                }
              },
              onWeightUnitChanged: (String? value) {
                if (value != null) {
                  setState(() => _weightUnit = value);
                }
              },
              onHeightUnitChanged: (String? value) {
                if (value != null) {
                  setState(() => _heightUnit = value);
                }
              },
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _recordedAtController,
              labelText: l10n.nursingRecordedAtLabel,
              hintText: l10n.nursingDateTimeHint,
              enabled: !_isSaving,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.nursingActionRecordVitals,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final DateTime? recordedAt = DateTime.tryParse(
      _recordedAtController.text.trim(),
    );
    if (recordedAt == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    final List<Map<String, Object?>> payloads = _vitalPayloads(recordedAt);
    if (payloads.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .recordVitalSet(payloads);
    _finishSubmit(failure);
  }

  List<Map<String, Object?>> _vitalPayloads(DateTime recordedAt) {
    final String recordedAtValue = recordedAt.toUtc().toIso8601String();
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];

    final String systolic = _normalizedNumber(_systolicController.text);
    final String diastolic = _normalizedNumber(_diastolicController.text);
    if (systolic.isNotEmpty || diastolic.isNotEmpty) {
      if (systolic.isEmpty || diastolic.isEmpty) {
        return const <Map<String, Object?>>[];
      }
      payloads.add(<String, Object?>{
        'vital_type': 'BLOOD_PRESSURE',
        'systolic_value': num.tryParse(systolic),
        'diastolic_value': num.tryParse(diastolic),
        'unit': _bloodPressureUnit,
        'recorded_at': recordedAtValue,
      });
    }

    void addValue(String type, TextEditingController controller, String unit) {
      final String value = _normalizedNumber(controller.text);
      if (value.isEmpty) {
        return;
      }
      payloads.add(<String, Object?>{
        'vital_type': type,
        'value': value,
        'unit': unit,
        'recorded_at': recordedAtValue,
      });
    }

    addValue('TEMPERATURE', _temperatureController, _temperatureUnit);
    addValue('HEART_RATE', _heartRateController, AppVitalsUnits.heartRate);
    addValue(
      'RESPIRATORY_RATE',
      _respiratoryRateController,
      AppVitalsUnits.respiratoryRate,
    );
    addValue(
      'OXYGEN_SATURATION',
      _oxygenSaturationController,
      AppVitalsUnits.oxygenSaturation,
    );
    addValue('WEIGHT', _weightController, _weightUnit);
    addValue('HEIGHT', _heightController, _heightUnit);
    return payloads;
  }

  String _normalizedNumber(String value) {
    return value.trim().replaceAll(',', '');
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

class _TaskDialog extends ConsumerStatefulWidget {
  const _TaskDialog();

  @override
  ConsumerState<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<_TaskDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _taskController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _taskController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.nursingActionCompleteTask),
      icon: const Icon(Icons.playlist_add_check_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _taskController,
              labelText: l10n.nursingTaskLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.nursingNoteLabel,
              enabled: !_isSaving,
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: l10n.nursingActionCompleteTask,
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
        .completeTask(
          task: _taskController.text.trim(),
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
  late final TextEditingController _administeredAtController;
  String? _prescriptionId;
  String _route = 'ORAL';
  bool _confirm = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final MedicationSuggestion? firstSuggestion =
        widget.detail.medicationSuggestions.firstOrNull;
    _prescriptionId = firstSuggestion?.id;
    _doseController = TextEditingController(text: firstSuggestion?.dose ?? '');
    _unitController = TextEditingController(text: firstSuggestion?.unit ?? '');
    _administeredAtController = TextEditingController(
      text: DateTime.now().toIso8601String(),
    );
    _route = _supportedMedicationRoute(firstSuggestion?.route) ?? _route;
  }

  @override
  void dispose() {
    _doseController.dispose();
    _unitController.dispose();
    _administeredAtController.dispose();
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
              administeredAtLabel: l10n.nursingAdministeredAtLabel,
              confirmLabel: l10n.nursingConfirmMedicationLabel,
              confirmSubtitle: l10n.nursingConfirmMedicationSubtitle,
              requiredMessage: l10n.validationRequired,
              doseController: _doseController,
              unitController: _unitController,
              administeredAtController: _administeredAtController,
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
                      suggestion.route,
                    ]),
                  ),
              ],
              dateTimeHint: l10n.nursingDateTimeHint,
              enabled: !_isSaving,
              onMedicationChanged: _selectMedication,
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

  void _selectMedication(String? value) {
    final MedicationSuggestion? suggestion = widget.detail.medicationSuggestions
        .where((MedicationSuggestion item) => item.id == value)
        .firstOrNull;
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
    final DateTime? administeredAt = DateTime.tryParse(
      _administeredAtController.text.trim(),
    );
    if (administeredAt == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .addMedicationAdministration(<String, Object?>{
          'prescription_id': _uuidOrNull(_prescriptionId),
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
  late final TextEditingController _toUserController;
  late final TextEditingController _notesController;
  bool _confirm = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _toUserController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _toUserController.dispose();
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
              toUserController: _toUserController,
              notesController: _notesController,
              confirmLabel: widget.escalation
                  ? l10n.nursingConfirmEscalationLabel
                  : null,
              confirmed: _confirm,
              enabled: !_isSaving,
              onConfirmedChanged: (bool value) => setState(() => _confirm = value),
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = widget.escalation
        ? await controller.escalate(
            toUserId: _toUserController.text.trim(),
            message: _notesController.text.trim(),
          )
        : await controller.createHandover(
            toUserId: _toUserController.text.trim(),
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

Future<void> _openVitalsDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _VitalsDialog(),
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

Future<void> _openTaskDialog(BuildContext context) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TaskDialog(),
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

List<_NursingRecordView> _vitalRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.vitalSigns
      .map(
        (NursingVitalSign vital) => _NursingRecordView(
          title: _apiLabel(vital.vitalType),
          subtitle: _dateTimeLabel(context, vital.recordedAt),
          body: vital.displayValue,
          icon: Icons.monitor_heart_outlined,
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
    for (final AppCareTaskChecklistItem item
        in _admissionChecklistItems(context, detail))
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
  List<_NursingRecordView> records,
) {
  if (records.isEmpty) {
    return <String>['- ${context.l10n.nursingNoRecordsLabel}'];
  }
  return records
      .map(
        (_NursingRecordView record) => '- ${_joinDisplay(<String?>[
          record.title,
          record.subtitle,
          record.body,
          record.status?.label,
        ])}',
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

List<_NursingRecordView> _noteRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.nursingNotes
      .map(
        (NursingNoteRecord note) => _NursingRecordView(
          title: note.nurseName ?? context.l10n.profileUnknownValue,
          subtitle: _dateTimeLabel(context, note.createdAt),
          body: note.note,
          icon: Icons.edit_note_outlined,
        ),
      )
      .toList(growable: false);
}

List<_NursingRecordView> _medicationRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  final List<_NursingRecordView> records = <_NursingRecordView>[
    for (final MedicationReminder reminder in detail.medicationReminders)
      _NursingRecordView(
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
      _NursingRecordView(
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
      _NursingRecordView(
        title: _joinDisplay(<String?>[
          medication.dose,
          medication.unit,
          medication.route == null ? null : _apiLabel(medication.route!),
        ]),
        subtitle: _dateTimeLabel(context, medication.administeredAt),
        icon: Icons.done_all_outlined,
      ),
  ];
  return records;
}

List<_NursingRecordView> _carePlanRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.carePlans
      .map(
        (NursingCarePlan plan) => _NursingRecordView(
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

List<_NursingRecordView> _handoverRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.handovers
      .map(
        (NursingHandover handover) => _NursingRecordView(
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

  final bool locationReady = summary.locationLabel != null || summary.hasActiveBed;
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
    AppSearchBarFieldChoice(field: 'patient', label: l10n.opdPatientColumnLabel),
    AppSearchBarFieldChoice(field: 'ward', label: l10n.nursingWardFilterLabel),
    AppSearchBarFieldChoice(field: 'bed', label: l10n.nursingBedLabel),
    AppSearchBarFieldChoice(field: 'task', label: l10n.nursingTaskLabel),
    AppSearchBarFieldChoice(field: 'status', label: l10n.opdStatusColumnLabel),
    AppSearchBarFieldChoice(field: 'priority', label: l10n.nursingPriorityColumnLabel),
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
      key: 'ward',
      label: l10n.nursingWardFilterLabel,
      hintText: l10n.nursingWardFilterHint,
      icon: Icons.local_hospital_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'unit',
      label: l10n.nursingUnitFilterLabel,
      hintText: l10n.nursingUnitFilterHint,
      icon: Icons.meeting_room_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'shift',
      label: l10n.nursingShiftFilterLabel,
      hintText: l10n.nursingShiftFilterHint,
      icon: Icons.schedule_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'care_task',
      label: l10n.nursingCareTaskFilterLabel,
      hintText: l10n.nursingCareTaskFilterHint,
      icon: Icons.playlist_add_check_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'admission_status',
      label: l10n.nursingAdmissionStatusFilterLabel,
      hintText: l10n.nursingAdmissionStatusFilterHint,
      icon: Icons.hotel_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'discharge_readiness',
      label: l10n.nursingDischargeReadinessFilterLabel,
      hintText: l10n.nursingDischargeReadinessFilterHint,
      icon: Icons.logout_outlined,
    ),
  ];
}

List<AppSearchBarFilterGroup> _worklistFilterGroups(AppLocalizations l10n) {
  return <AppSearchBarFilterGroup>[
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
  ];
}

AppSearchBarFilterValue _filterValueFromQuery(NursingWorklistQuery query) {
  return AppSearchBarFilterValue(
    dateFrom: query.dateFrom,
    dateTo: query.dateTo,
    texts: Map<String, String>.unmodifiable(<String, String>{
      if (query.patient.trim().isNotEmpty) 'patient': query.patient,
      if (query.ward.trim().isNotEmpty) 'ward': query.ward,
      if (query.unit.trim().isNotEmpty) 'unit': query.unit,
      if (query.shift.trim().isNotEmpty) 'shift': query.shift,
      if (query.careTask.trim().isNotEmpty) 'care_task': query.careTask,
      if (query.admissionStatus.trim().isNotEmpty)
        'admission_status': query.admissionStatus,
      if (query.dischargeReadiness.trim().isNotEmpty)
        'discharge_readiness': query.dischargeReadiness,
    }),
    options: Map<String, String>.unmodifiable(<String, String>{
      if (query.priority.trim().isNotEmpty) 'priority': query.priority,
    }),
  );
}

List<AppSelectOption<NursingQueueScope>> _scopeOptions(AppLocalizations l10n) {
  return <AppSelectOption<NursingQueueScope>>[
    AppSelectOption<NursingQueueScope>(
      value: NursingQueueScope.assignedWard,
      label: l10n.nursingScopeAssignedWardLabel,
    ),
    AppSelectOption<NursingQueueScope>(
      value: NursingQueueScope.urgent,
      label: l10n.nursingScopeUrgentLabel,
    ),
    AppSelectOption<NursingQueueScope>(
      value: NursingQueueScope.medicationDue,
      label: l10n.nursingScopeMedicationDueLabel,
    ),
    AppSelectOption<NursingQueueScope>(
      value: NursingQueueScope.handoverPending,
      label: l10n.nursingScopeHandoverPendingLabel,
    ),
    AppSelectOption<NursingQueueScope>(
      value: NursingQueueScope.transferPending,
      label: l10n.nursingScopeTransferPendingLabel,
    ),
    AppSelectOption<NursingQueueScope>(
      value: NursingQueueScope.dischargePending,
      label: l10n.nursingScopeDischargePendingLabel,
    ),
    AppSelectOption<NursingQueueScope>(
      value: NursingQueueScope.all,
      label: l10n.nursingScopeAllLabel,
    ),
  ];
}

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
          item.admissionStatus == null ? null : _apiLabel(item.admissionStatus!),
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
    _ => AppWorkspaceStatus(
      label: l10n.nursingPriorityRoutineLabel,
    ),
  };
}

String _dueTimeLabel(BuildContext context, NursingPatientSummary item) {
  if (item.isUrgent || item.hasMedicationDue || item.hasPendingTransfer) {
    return context.l10n.nursingDueNowLabel;
  }
  return _dateTimeLabel(context, item.dueReferenceAt);
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

String? _uuidOrNull(String? value) {
  final String normalized = (value ?? '').trim();
  final RegExp uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  return uuidPattern.hasMatch(normalized) ? normalized : null;
}

const List<String> _transferActions = <String>[
  'APPROVE',
  'START',
  'COMPLETE',
  'CANCEL',
];


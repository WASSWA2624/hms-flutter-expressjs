import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_handover_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_medication_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_cell.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_shift_context_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_transfer_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class NursingWorkspacePage extends ConsumerWidget {
  const NursingWorkspacePage({this.initialQuery, super.key});

  final NursingWorkspaceQuery? initialQuery;

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
        return _NursingWorkspaceContent(
          state: data,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _NursingWorkspaceContent extends ConsumerStatefulWidget {
  const _NursingWorkspaceContent({required this.state, this.initialQuery});

  final NursingWorkspaceState state;
  final NursingWorkspaceQuery? initialQuery;

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
  NursingQueueScope _scope = NursingQueueScope.all;
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _filterValue = _filterValueFromQuery(widget.state.query);
    _scope = _scopeFromQuery(widget.initialQuery?.scope) ??
        widget.state.query.scope;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_handleDeepLink());
    });
  }

  Future<void> _handleDeepLink() async {
    if (_deepLinkHandled) {
      return;
    }
    _deepLinkHandled = true;
    final String? id = widget.initialQuery?.admissionId.trim();
    if (id == null || id.isEmpty) {
      return;
    }
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );
    final NursingPatientSummary? summary =
        await controller.selectPatientByDisplayId(id);
    if (!mounted || summary == null) {
      return;
    }
    unawaited(
      showAppDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) =>
            const NursingPatientDetailDialog(),
      ),
    );
    final NursingDetailPanel? panel = NursingDetailPanel.fromValue(
      widget.initialQuery?.panel,
    );
    if (panel == null || panel == NursingDetailPanel.checklist) {
      return;
    }
    final NursingPatientDetail? detail = nursingSelectedDetailFromState(
      ref.read(nursingWorkspaceControllerProvider),
    );
    if (detail == null || !mounted) {
      return;
    }
    switch (panel) {
      case NursingDetailPanel.vitals:
        await _openVitalsDialogStandalone(context);
      case NursingDetailPanel.medication:
        await _openMedicationDialogStandalone(context, detail);
      case NursingDetailPanel.handover:
        await _openHandoverDialogStandalone(context);
      case NursingDetailPanel.discharge:
        await _openDischargeClearanceDialogStandalone(context, detail);
      case NursingDetailPanel.checklist:
        break;
    }
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

  static String _scopeToQueryValue(NursingQueueScope scope) {
    return switch (scope) {
      NursingQueueScope.all => 'all',
      NursingQueueScope.assignedWard => 'assigned-ward',
      NursingQueueScope.urgent => 'urgent',
      NursingQueueScope.medicationDue => 'medication-due',
      NursingQueueScope.handoverPending => 'handover-pending',
      NursingQueueScope.transferPending => 'transfer-pending',
      NursingQueueScope.dischargePending => 'discharge-pending',
    };
  }

  static NursingQueueScope? _scopeFromQuery(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'all' || '' || null => NursingQueueScope.all,
      'assigned-ward' || 'assigned_ward' || 'ward' =>
        NursingQueueScope.assignedWard,
      'urgent' || 'critical' => NursingQueueScope.urgent,
      'medication-due' || 'medication_due' || 'medication' =>
        NursingQueueScope.medicationDue,
      'handover-pending' || 'handover_pending' || 'handover' =>
        NursingQueueScope.handoverPending,
      'transfer-pending' || 'transfer_pending' || 'transfer' =>
        NursingQueueScope.transferPending,
      'discharge-pending' || 'discharge_pending' || 'discharge' =>
        NursingQueueScope.dischargePending,
      _ => null,
    };
  }

  void _updateUrlForScope(NursingQueueScope scope) {
    if (!mounted) {
      return;
    }
    final String tab = _scopeToQueryValue(scope);
    final String location = AppRoutes.nursing.location(
      queryParameters: <String, String>{
        if (tab.isNotEmpty && tab != 'all') 'scope': tab,
      },
    );
    GoRouter.of(context).replace<void>(location);
  }

  void _onTabTapped(String tabId) {
    final NursingQueueScope? scope = _scopeFromQuery(tabId);
    if (scope == null || scope == _scope) {
      return;
    }
    setState(() => _scope = scope);
    _updateUrlForScope(scope);
    ref.read(nursingWorkspaceControllerProvider.notifier).applyScope(scope);
  }

  String _primaryActionLabel(AppLocalizations l10n, NursingQueueScope scope) {
    return switch (scope) {
      NursingQueueScope.medicationDue => l10n.nursingActionAdministerMedication,
      NursingQueueScope.handoverPending => l10n.nursingActionCreateHandover,
      NursingQueueScope.transferPending =>
        l10n.nursingActionAcknowledgeTransfer,
      NursingQueueScope.dischargePending =>
        l10n.nursingActionDischargeClearance,
      _ => l10n.nursingActionRecordVitals,
    };
  }

  IconData _primaryActionIcon(NursingQueueScope scope) {
    return switch (scope) {
      NursingQueueScope.medicationDue => Icons.medication_outlined,
      NursingQueueScope.handoverPending => Icons.swap_horiz_outlined,
      NursingQueueScope.transferPending =>
        Icons.transfer_within_a_station_outlined,
      NursingQueueScope.dischargePending => Icons.fact_check_outlined,
      _ => Icons.monitor_heart_outlined,
    };
  }

  void _executePrimaryAction() {
    switch (_scope) {
      case NursingQueueScope.medicationDue:
        final NursingPatientDetail? detail = nursingSelectedDetailFromState(
          ref.read(nursingWorkspaceControllerProvider),
        );
        if (detail != null) {
          _openMedicationDialogStandalone(context, detail);
        }
      case NursingQueueScope.handoverPending:
        _openHandoverDialogStandalone(context);
      case NursingQueueScope.transferPending:
        final NursingPatientDetail? detail = nursingSelectedDetailFromState(
          ref.read(nursingWorkspaceControllerProvider),
        );
        if (detail != null) {
          nursingShowActionResult(
            context,
            showAppDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => NursingTransferDialog(detail: detail),
            ),
          );
        }
      case NursingQueueScope.dischargePending:
        final NursingPatientDetail? detail = nursingSelectedDetailFromState(
          ref.read(nursingWorkspaceControllerProvider),
        );
        if (detail != null) {
          _openDischargeClearanceDialogStandalone(context, detail);
        }
      case NursingQueueScope.all:
      case NursingQueueScope.assignedWard:
      case NursingQueueScope.urgent:
        _openVitalsDialogStandalone(context);
    }
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
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: <AppWorkspaceSummaryNotification>[
          if (nursingPageTotal(state.worklist) > 0)
            AppWorkspaceSummaryNotification(
              label: 'All nursing worklist',
              count: nursingPageTotal(state.worklist),
              icon: Icons.inventory_2_outlined,
              tone: AppWorkspaceStatusTone.info,
              onSelected: () {
                _onTabTapped(_scopeToQueryValue(NursingQueueScope.all));
              },
            ),
          if (state.assignedWardCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.nursingAssignedWardSummaryLabel,
              count: state.assignedWardCount,
              icon: Icons.local_hospital_outlined,
              tone: AppWorkspaceStatusTone.info,
              onSelected: () {
                _onTabTapped(
                  _scopeToQueryValue(NursingQueueScope.assignedWard),
                );
              },
            ),
          if (state.urgentCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.nursingUrgentSummaryLabel,
              count: state.urgentCount,
              icon: Icons.priority_high_outlined,
              tone: AppWorkspaceStatusTone.error,
              onSelected: () {
                _onTabTapped(_scopeToQueryValue(NursingQueueScope.urgent));
              },
            ),
          if (state.medicationDueCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.nursingMedicationDueSummaryLabel,
              count: state.medicationDueCount,
              icon: Icons.medication_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onSelected: () {
                _onTabTapped(
                  _scopeToQueryValue(NursingQueueScope.medicationDue),
                );
              },
            ),
          if (state.handoverPendingCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.nursingHandoverPendingSummaryLabel,
              count: state.handoverPendingCount,
              icon: Icons.swap_horiz_outlined,
              tone: AppWorkspaceStatusTone.neutral,
              onSelected: () {
                _onTabTapped(
                  _scopeToQueryValue(NursingQueueScope.handoverPending),
                );
              },
            ),
          if (state.transferPendingCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.nursingTransferPendingSummaryLabel,
              count: state.transferPendingCount,
              icon: Icons.transfer_within_a_station_outlined,
              tone: AppWorkspaceStatusTone.warning,
              onSelected: () {
                _onTabTapped(
                  _scopeToQueryValue(NursingQueueScope.transferPending),
                );
              },
            ),
          if (state.dischargePendingCount > 0)
            AppWorkspaceSummaryNotification(
              label: l10n.nursingDischargePendingSummaryLabel,
              count: state.dischargePendingCount,
              icon: Icons.logout_outlined,
              tone: AppWorkspaceStatusTone.success,
              onSelected: () {
                _onTabTapped(
                  _scopeToQueryValue(NursingQueueScope.dischargePending),
                );
              },
            ),
        ],
        secondary: <Widget>[
          AppButton.secondary(
            leadingIcon: Icons.assignment_ind_outlined,
            label: l10n.nursingShiftContextTitle,
            semanticLabel: l10n.nursingShiftContextTitle,
            tooltip: l10n.nursingShiftContextTitle,
            onPressed: () => _openShiftContextDialog(context),
          ),
          AppAccessActionGate(
            requirement: writeRequirement,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                label: l10n.nursingActionAddNote,
                leadingIcon: Icons.note_add_outlined,
                enabled: isAllowed && !state.isSaving,
                onPressed: () => _openNoteDialogStandalone(context),
              );
            },
          ),
        ],
        onRefresh: () async {
          final AppFailure? failure = await controller.refresh();
          if (context.mounted) {
            nursingShowFailureIfNeeded(context, failure);
          }
        },
        isRefreshing: state.isRefreshing || state.isRefreshingDetail,
      ),
      body: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppTabStrip(
                  tabs: _nursingTabs(l10n),
                  selectedId: _scopeToQueryValue(_scope),
                  onTabTapped: _onTabTapped,
                ),
              ),
              SizedBox(width: Theme.of(context).spacing.sm),
              AppAccessActionGate(
                requirement: writeRequirement,
                builder: (BuildContext context, bool isAllowed) {
                  return AppButton.primary(
                    label: _primaryActionLabel(l10n, _scope),
                    leadingIcon: _primaryActionIcon(_scope),
                    enabled: isAllowed && !state.isSaving,
                    onPressed: isAllowed ? _executePrimaryAction : null,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          Expanded(
            child: _NursingWorklistPanel(
              state: state,
              scope: _scope,
              searchController: _searchController,
              filterValue: _filterValue,
              onFilterChanged: (AppSearchBarFilterValue value) {
                setState(() {
                  _filterValue = value;
                });
                controller
                    .applyAdvancedFilters(
                      searchField: value.field,
                      scope: nursingScopeFromFilterValue(value.option('scope')),
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
                        nursingShowFailureIfNeeded(context, failure);
                      }
                    });
              },
            ),
          ),
        ],
      ),
    );
  }

  List<AppTabItem> _nursingTabs(AppLocalizations l10n) {
    return <AppTabItem>[
      AppTabItem(
        id: _scopeToQueryValue(NursingQueueScope.all),
        icon: Icons.inventory_2_outlined,
        label: l10n.nursingScopeAllLabel,
      ),
      AppTabItem(
        id: _scopeToQueryValue(NursingQueueScope.assignedWard),
        icon: Icons.local_hospital_outlined,
        label: l10n.nursingScopeAssignedWardLabel,
      ),
      AppTabItem(
        id: _scopeToQueryValue(NursingQueueScope.urgent),
        icon: Icons.priority_high_outlined,
        label: l10n.nursingScopeUrgentLabel,
      ),
      AppTabItem(
        id: _scopeToQueryValue(NursingQueueScope.medicationDue),
        icon: Icons.medication_outlined,
        label: l10n.nursingScopeMedicationDueLabel,
      ),
      AppTabItem(
        id: _scopeToQueryValue(NursingQueueScope.handoverPending),
        icon: Icons.swap_horiz_outlined,
        label: l10n.nursingScopeHandoverPendingLabel,
      ),
      AppTabItem(
        id: _scopeToQueryValue(NursingQueueScope.transferPending),
        icon: Icons.transfer_within_a_station_outlined,
        label: l10n.nursingScopeTransferPendingLabel,
      ),
      AppTabItem(
        id: _scopeToQueryValue(NursingQueueScope.dischargePending),
        icon: Icons.logout_outlined,
        label: l10n.nursingScopeDischargePendingLabel,
      ),
    ];
  }

  void _openShiftContextDialog(BuildContext context) {
    showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) =>
          const NursingShiftContextDialog(),
    );
  }

  Future<void> _openVitalsDialogStandalone(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AppRecordVitalsDialog(
          title: l10n.nursingActionRecordVitals,
          submitLabel: l10n.nursingActionRecordVitals,
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
          onSubmit: (List<Map<String, Object?>> payloads) {
            return ProviderScope.containerOf(context, listen: false)
                .read(nursingWorkspaceControllerProvider.notifier)
                .recordVitalSet(payloads);
          },
        ),
      ),
    );
  }

  Future<void> _openNoteDialogStandalone(BuildContext context) async {
    await nursingShowActionResult(
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

  Future<void> _openMedicationDialogStandalone(
    BuildContext context,
    NursingPatientDetail detail,
  ) async {
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => NursingMedicationDialog(detail: detail),
      ),
    );
  }

  Future<void> _openHandoverDialogStandalone(BuildContext context) async {
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const NursingHandoverDialog(),
      ),
    );
  }

  Future<void> _openDischargeClearanceDialogStandalone(
    BuildContext context,
    NursingPatientDetail detail,
  ) async {
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => NursingDischargeClearanceDialog(detail: detail),
      ),
    );
  }
}

class _NursingWorklistPanel extends ConsumerWidget {
  const _NursingWorklistPanel({
    required this.state,
    required this.scope,
    required this.searchController,
    required this.filterValue,
    required this.onFilterChanged,
  });

  final NursingWorkspaceState state;
  final NursingQueueScope scope;
  final TextEditingController searchController;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );

    return AppListTable<NursingWorkItem>(
      page: state.worklist,
      isLoading: state.isRefreshing,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'nursing_${scope.name}',
      columnWidthStorageKey: 'nursing_cw_${scope.name}',
      previousPageLabel: l10n.opdPreviousPageLabel,
      nextPageLabel: l10n.opdNextPageLabel,
      pageLabelBuilder: (AppPage<NursingWorkItem> page) {
        return nursingPageLabel(context, page);
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
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.nursingAdvancedFiltersLabel,
        advancedFilterTitle: l10n.nursingAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.nursingApplyFiltersLabel,
        advancedFilterResetLabel: l10n.nursingResetFiltersLabel,
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
      columnChoices: _columnChoicesForScope(l10n, scope),
      columns: _columnsForScope(l10n, scope),
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
              NursingPatientCell(item: item),
              SizedBox(height: theme.spacing.xs),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  AppWorkspaceStatusBadge(
                    status: nursingPriorityStatus(context, item),
                  ),
                  AppWorkspaceStatusBadge(status: nursingSummaryStatus(item)),
                  Text(
                    nursingJoinDisplay(<String?>[
                      item.locationLabel,
                      nursingTaskTypeLabel(context, item),
                      nursingDueTimeLabel(context, item),
                    ]),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

List<AppListTableColumn<NursingWorkItem>> _columnsForScope(
  AppLocalizations l10n,
  NursingQueueScope scope,
) {
  return switch (scope) {
    NursingQueueScope.urgent => <AppListTableColumn<NursingWorkItem>>[
      _patientColumn(l10n),
      _priorityColumn(l10n),
      _locationColumn(l10n),
      _statusColumn(l10n),
      _dueTimeColumn(l10n),
    ],
    NursingQueueScope.medicationDue => <AppListTableColumn<NursingWorkItem>>[
      _patientColumn(l10n),
      _medicationDueCountColumn(l10n),
      _locationColumn(l10n),
      _dueTimeColumn(l10n),
      _statusColumn(l10n),
    ],
    NursingQueueScope.handoverPending => <AppListTableColumn<NursingWorkItem>>[
      _patientColumn(l10n),
      _responsibleNurseColumn(l10n),
      _locationColumn(l10n),
      _statusColumn(l10n),
      _observationsColumn(l10n),
    ],
    NursingQueueScope.transferPending => <AppListTableColumn<NursingWorkItem>>[
      _patientColumn(l10n),
      _locationColumn(l10n),
      _transferStatusColumn(l10n),
      _admissionColumn(l10n),
      _statusColumn(l10n),
    ],
    NursingQueueScope.dischargePending => <AppListTableColumn<NursingWorkItem>>[
      _patientColumn(l10n),
      _locationColumn(l10n),
      _dischargeStatusColumn(l10n),
      _admissionColumn(l10n),
      _dueTimeColumn(l10n),
    ],
    _ => <AppListTableColumn<NursingWorkItem>>[
      _patientColumn(l10n),
      _locationColumn(l10n),
      _taskTypeColumn(l10n),
      _priorityColumn(l10n),
      _statusColumn(l10n),
    ],
  };
}

List<AppListTableColumn<NursingWorkItem>> _columnChoicesForScope(
  AppLocalizations l10n,
  NursingQueueScope scope,
) {
  final Set<String> defaultLabels =
      _columnsForScope(l10n, scope).map((AppListTableColumn<NursingWorkItem> c) => c.label).toSet();
  return <AppListTableColumn<NursingWorkItem>>[
    ..._columnsForScope(l10n, scope),
    if (!defaultLabels.contains(l10n.nursingAdmissionColumnLabel))
      _admissionColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingDueTimeColumnLabel))
      _dueTimeColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingResponsibleNurseColumnLabel))
      _responsibleNurseColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingObservationsTitle))
      _observationsColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingTaskTypeColumnLabel))
      _taskTypeColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingPriorityColumnLabel))
      _priorityColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingLocationColumnLabel))
      _locationColumn(l10n),
  ];
}

AppListTableColumn<NursingWorkItem> _patientColumn(AppLocalizations l10n) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.opdPatientColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.displayTitle, right.displayTitle),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return NursingPatientCell(item: item);
    },
  );
}

AppListTableColumn<NursingWorkItem> _locationColumn(AppLocalizations l10n) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.nursingLocationColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.locationLabel, right.locationLabel),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(
        item.locationLabel ?? context.l10n.profileUnknownValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<NursingWorkItem> _taskTypeColumn(AppLocalizations l10n) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.nursingTaskTypeColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.taskTypeCode, right.taskTypeCode),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingTaskTypeLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> _priorityColumn(AppLocalizations l10n) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.nursingPriorityColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.priorityCode, right.priorityCode),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return AppWorkspaceStatusBadge(
        status: nursingPriorityStatus(context, item),
      );
    },
  );
}

AppListTableColumn<NursingWorkItem> _statusColumn(AppLocalizations l10n) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.opdStatusColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.admissionStatus, right.admissionStatus),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return AppWorkspaceStatusBadge(status: nursingSummaryStatus(item));
    },
  );
}

AppListTableColumn<NursingWorkItem> _admissionColumn(AppLocalizations l10n) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.nursingAdmissionColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.displayId, right.displayId),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingAdmissionLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> _dueTimeColumn(AppLocalizations l10n) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.nursingDueTimeColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareDateTime(left.dueReferenceAt, right.dueReferenceAt),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingDueTimeLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> _responsibleNurseColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.nursingResponsibleNurseColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(
          nursingResponsibleNurseSortValue(left),
          nursingResponsibleNurseSortValue(right),
        ),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingResponsibleNurseLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> _observationsColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.nursingObservationsTitle,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareDateTime(
          left.lastObservationAt,
          right.lastObservationAt,
        ),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingLastObservationLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> _medicationDueCountColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.nursingMedicationDueSummaryLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        left.medicationDueCount.compareTo(right.medicationDueCount),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(item.medicationDueCount.toString());
    },
  );
}

AppListTableColumn<NursingWorkItem> _transferStatusColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.nursingTransferPendingSummaryLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.transferStatus, right.transferStatus),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      final String? status = item.transferStatus;
      if (status == null || status.trim().isEmpty) {
        return Text(context.l10n.profileUnknownValue);
      }
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: nursingApiLabel(status),
          tone: nursingStatusTone(status),
        ),
      );
    },
  );
}

AppListTableColumn<NursingWorkItem> _dischargeStatusColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    label: l10n.dischargeStatusFilterLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.dischargeStatus, right.dischargeStatus),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      final String? status = item.dischargeStatus;
      if (status == null || status.trim().isEmpty) {
        return Text(context.l10n.profileUnknownValue);
      }
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: nursingApiLabel(status),
          tone: nursingStatusTone(status),
        ),
      );
    },
  );
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
    nursingShowFailureIfNeeded(context, failure);
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => const NursingPatientDetailDialog(),
  );
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
        'scope': nursingScopeCode(query.scope),
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

List<AppSearchBarFieldChoice> _worklistSearchFields(AppLocalizations l10n) {
  return <AppSearchBarFieldChoice>[
    AppSearchBarFieldChoice(field: 'patient', label: l10n.opdPatientColumnLabel),
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
          label: nursingApiLabel('ADMITTED_PENDING_BED'),
          icon: Icons.hotel_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'ADMITTED_IN_BED',
          label: nursingApiLabel('ADMITTED_IN_BED'),
          icon: Icons.bed_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'TRANSFER_REQUESTED',
          label: nursingApiLabel('TRANSFER_REQUESTED'),
          icon: Icons.transfer_within_a_station_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'TRANSFER_IN_PROGRESS',
          label: nursingApiLabel('TRANSFER_IN_PROGRESS'),
          icon: Icons.transfer_within_a_station_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'DISCHARGE_PLANNED',
          label: nursingApiLabel('DISCHARGE_PLANNED'),
          icon: Icons.logout_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'DISCHARGED',
          label: nursingApiLabel('DISCHARGED'),
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
            label: nursingApiLabel(value),
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
          label: nursingApiLabel('PENDING'),
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
            label: nursingApiLabel(value),
            icon: Icons.logout_outlined,
          ),
      ],
    ),
  ];
}

List<AppSearchBarFilterChoice> _scopeFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.assignedWard),
      label: l10n.nursingScopeAssignedWardLabel,
      icon: Icons.local_hospital_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.urgent),
      label: l10n.nursingScopeUrgentLabel,
      icon: Icons.priority_high_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.medicationDue),
      label: l10n.nursingScopeMedicationDueLabel,
      icon: Icons.medication_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.handoverPending),
      label: l10n.nursingScopeHandoverPendingLabel,
      icon: Icons.swap_horiz_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.transferPending),
      label: l10n.nursingScopeTransferPendingLabel,
      icon: Icons.transfer_within_a_station_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.dischargePending),
      label: l10n.nursingScopeDischargePendingLabel,
      icon: Icons.logout_outlined,
    ),
  ];
}

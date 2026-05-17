import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _wardController = TextEditingController(text: widget.state.query.ward);
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
      child: AppPaginatedListTable<NursingPatientSummary>(
        page: state.worklist,
        isLoading: state.isRefreshing,
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<NursingPatientSummary> page) {
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
        columns: <AppListTableColumn<NursingPatientSummary>>[
          AppListTableColumn<NursingPatientSummary>(
            label: l10n.opdPatientColumnLabel,
            cellBuilder: (BuildContext context, NursingPatientSummary item) {
              return _NursingPatientCell(item: item);
            },
          ),
          AppListTableColumn<NursingPatientSummary>(
            label: l10n.nursingLocationColumnLabel,
            cellBuilder: (BuildContext context, NursingPatientSummary item) {
              return Text(item.locationLabel ?? l10n.profileUnknownValue);
            },
          ),
          AppListTableColumn<NursingPatientSummary>(
            label: l10n.opdStatusColumnLabel,
            cellBuilder: (BuildContext context, NursingPatientSummary item) {
              return AppWorkspaceStatusBadge(status: _summaryStatus(item));
            },
          ),
          AppListTableColumn<NursingPatientSummary>(
            label: l10n.nursingDueActionColumnLabel,
            cellBuilder: (BuildContext context, NursingPatientSummary item) {
              return Text(_dueActionLabel(context, item));
            },
          ),
          AppListTableColumn<NursingPatientSummary>(
            label: l10n.nursingLastObservationColumnLabel,
            cellBuilder: (BuildContext context, NursingPatientSummary item) {
              return Text(_lastObservationLabel(context, item));
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, NursingPatientSummary item) {
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
                    AppWorkspaceStatusBadge(status: _summaryStatus(item)),
                    Text(
                      _joinDisplay(<String?>[
                        item.locationLabel,
                        _dueActionLabel(context, item),
                        _lastObservationLabel(context, item),
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
        _NursingRecordPanel(
          title: l10n.nursingWardActivityTitle,
          records: _activityRecords(context, detail),
          emptyLabel: l10n.nursingNoRecordsLabel,
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
          return Wrap(
            spacing: Theme.of(context).spacing.xs,
            runSpacing: Theme.of(context).spacing.xs,
            children: <Widget>[
              _actionButton(
                label: l10n.nursingActionRecordVitals,
                icon: Icons.monitor_heart_outlined,
                enabled: isAllowed,
                onPressed: () => _openVitalsDialog(context),
              ),
              _actionButton(
                label: l10n.nursingActionAddNote,
                icon: Icons.note_add_outlined,
                enabled: isAllowed,
                onPressed: () => _openNoteDialog(context),
              ),
              _actionButton(
                label: l10n.nursingActionAdministerMedication,
                icon: Icons.medication_outlined,
                enabled: isAllowed,
                onPressed: () => _openMedicationDialog(context, detail),
              ),
              _actionButton(
                label: l10n.nursingActionCompleteTask,
                icon: Icons.playlist_add_check_outlined,
                enabled: isAllowed,
                onPressed: () => _openTaskDialog(context),
              ),
              _actionButton(
                label: l10n.nursingActionCreateHandover,
                icon: Icons.swap_horiz_outlined,
                enabled: isAllowed,
                onPressed: () => _openHandoverDialog(context),
              ),
              _actionButton(
                label: l10n.nursingActionEscalate,
                icon: Icons.report_problem_outlined,
                enabled: isAllowed,
                onPressed: () => _openEscalationDialog(context),
              ),
              _actionButton(
                label: l10n.nursingActionAcknowledgeTransfer,
                icon: Icons.transfer_within_a_station_outlined,
                enabled: isAllowed && detail.activeTransfer != null,
                onPressed: () => _openTransferDialog(context, detail),
              ),
              for (final NursingHandover handover in detail.handovers)
                if (handover.isPending)
                  _actionButton(
                    label: l10n.nursingActionAcceptHandover,
                    icon: Icons.done_all_outlined,
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
  late final TextEditingController _valueController;
  late final TextEditingController _unitController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _mapController;
  late final TextEditingController _recordedAtController;
  String _vitalType = 'TEMPERATURE';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController();
    _unitController = TextEditingController(text: 'C');
    _systolicController = TextEditingController();
    _diastolicController = TextEditingController();
    _mapController = TextEditingController();
    _recordedAtController = TextEditingController(
      text: DateTime.now().toIso8601String(),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _unitController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _mapController.dispose();
    _recordedAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isBloodPressure = _vitalType == 'BLOOD_PRESSURE';
    return AppDialog(
      title: Text(l10n.nursingActionRecordVitals),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _vitalType,
              labelText: l10n.nursingVitalsTypeLabel,
              enabled: !_isSaving,
              options: _statusOptions(_vitalTypeOptions),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _vitalType = value;
                    if (value == 'BLOOD_PRESSURE') {
                      _unitController.clear();
                    }
                  });
                }
              },
            ),
            if (isBloodPressure) ...<Widget>[
              AppTextField(
                controller: _systolicController,
                labelText: l10n.nursingSystolicLabel,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: _decimalFormatters,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
              AppTextField(
                controller: _diastolicController,
                labelText: l10n.nursingDiastolicLabel,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: _decimalFormatters,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
              AppTextField(
                controller: _mapController,
                labelText: l10n.nursingMapLabel,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: _decimalFormatters,
              ),
            ] else ...<Widget>[
              AppTextField(
                controller: _valueController,
                labelText: l10n.nursingVitalValueLabel,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: _decimalFormatters,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
              AppTextField(
                controller: _unitController,
                labelText: l10n.nursingVitalUnitLabel,
                enabled: !_isSaving,
              ),
            ],
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

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .recordVitals(
          vitalType: _vitalType,
          value: _valueController.text.trim(),
          unit: _unitController.text.trim(),
          systolicValue: num.tryParse(_systolicController.text.trim()),
          diastolicValue: num.tryParse(_diastolicController.text.trim()),
          mapValue: num.tryParse(_mapController.text.trim()),
          recordedAt: recordedAt,
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

class _SimpleNoteDialog extends ConsumerStatefulWidget {
  const _SimpleNoteDialog({
    required this.title,
    required this.label,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final String label;
  final String submitLabel;
  final Future<AppFailure?> Function(String note) onSubmit;

  @override
  ConsumerState<_SimpleNoteDialog> createState() => _SimpleNoteDialogState();
}

class _SimpleNoteDialogState extends ConsumerState<_SimpleNoteDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.note_add_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _noteController,
              labelText: widget.label,
              enabled: !_isSaving,
              maxLines: 5,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        submitLabel: widget.submitLabel,
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
    final AppFailure? failure = await widget.onSubmit(
      _noteController.text.trim(),
    );
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
  late final TextEditingController _noteController;
  String? _prescriptionId;
  String _route = 'ORAL';
  String _status = 'GIVEN';
  String _frequency = 'ONCE';
  bool _confirm = false;
  bool _scheduleReminders = false;
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
    _noteController = TextEditingController();
    _route = firstSuggestion?.route ?? _route;
    _frequency = firstSuggestion?.frequency ?? _frequency;
  }

  @override
  void dispose() {
    _doseController.dispose();
    _unitController.dispose();
    _administeredAtController.dispose();
    _noteController.dispose();
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
            AppSelectField<String>.searchable(
              value: _prescriptionId,
              labelText: l10n.nursingMedicationLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
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
              onChanged: _selectMedication,
            ),
            AppTextField(
              controller: _doseController,
              labelText: l10n.nursingDoseLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _unitController,
              labelText: l10n.nursingVitalUnitLabel,
              enabled: !_isSaving,
            ),
            AppSelectField<String>(
              value: _route,
              labelText: l10n.nursingRouteLabel,
              enabled: !_isSaving,
              options: _statusOptions(_medicationRoutes),
              onChanged: (String? value) =>
                  setState(() => _route = value ?? _route),
            ),
            AppSelectField<String>(
              value: _status,
              labelText: l10n.nursingAdministrationStatusLabel,
              enabled: !_isSaving,
              options: _statusOptions(_administrationStatuses),
              onChanged: (String? value) =>
                  setState(() => _status = value ?? _status),
            ),
            AppSelectField<String>(
              value: _frequency,
              labelText: l10n.nursingFrequencyLabel,
              enabled: !_isSaving,
              options: _statusOptions(_medicationFrequencies),
              onChanged: (String? value) =>
                  setState(() => _frequency = value ?? _frequency),
            ),
            AppTextField(
              controller: _administeredAtController,
              labelText: l10n.nursingAdministeredAtLabel,
              hintText: l10n.nursingDateTimeHint,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _noteController,
              labelText: l10n.nursingAdministrationNoteLabel,
              enabled: !_isSaving,
              maxLines: 4,
            ),
            AppCheckboxField(
              title: l10n.nursingScheduleRemindersLabel,
              value: _scheduleReminders,
              enabled: !_isSaving,
              onChanged: (bool value) =>
                  setState(() => _scheduleReminders = value),
            ),
            AppCheckboxField(
              title: l10n.nursingConfirmMedicationLabel,
              subtitle: l10n.nursingConfirmMedicationSubtitle,
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
        _route = suggestion.route ?? _route;
        _frequency = suggestion.frequency ?? _frequency;
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
    final MedicationSuggestion? selected = widget.detail.medicationSuggestions
        .where((MedicationSuggestion item) => item.id == _prescriptionId)
        .firstOrNull;

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .addMedicationAdministration(<String, Object?>{
          'prescription_id': _prescriptionId,
          'medication_label': selected?.displayTitle,
          'administered_at': administeredAt.toUtc().toIso8601String(),
          'dose': _doseController.text.trim(),
          'unit': _unitController.text.trim(),
          'route': _route,
          'status': _status,
          'frequency': _frequency,
          'administration_note': _noteController.text.trim(),
          'schedule_reminders': _scheduleReminders,
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
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _toUserController,
              labelText: l10n.nursingHandoverToUserLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _notesController,
              labelText: widget.escalation
                  ? l10n.nursingEscalationMessageLabel
                  : l10n.nursingHandoverNotesLabel,
              enabled: !_isSaving,
              maxLines: 5,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            if (widget.escalation)
              AppCheckboxField(
                title: l10n.nursingConfirmEscalationLabel,
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
      builder: (_) => _SimpleNoteDialog(
        title: context.l10n.nursingActionAddNote,
        label: context.l10n.nursingNoteLabel,
        submitLabel: context.l10n.nursingActionAddNote,
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
      builder: (_) => _SimpleNoteDialog(
        title: context.l10n.nursingActionAcceptHandover,
        label: context.l10n.nursingHandoverNotesLabel,
        submitLabel: context.l10n.nursingActionAcceptHandover,
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

List<_NursingRecordView> _activityRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return <_NursingRecordView>[
    for (final NursingCriticalAlert alert in detail.criticalAlerts)
      _NursingRecordView(
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
      _NursingRecordView(
        title: _apiLabel(item.type),
        subtitle: _dateTimeLabel(context, item.occurredAt),
        body: item.label,
        icon: _timelineIcon(item.type),
      ),
  ];
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

String _dueActionLabel(BuildContext context, NursingPatientSummary item) {
  final AppLocalizations l10n = context.l10n;
  if (item.hasMedicationDue) {
    return l10n.nursingMedicationDueSummaryLabel;
  }
  if (item.pendingHandoverCount > 0) {
    return l10n.nursingHandoverPendingSummaryLabel;
  }
  if (item.hasPendingTransfer) {
    return l10n.nursingTransferPendingSummaryLabel;
  }
  if (item.isDischargePending) {
    return l10n.nursingDischargePendingSummaryLabel;
  }
  final String? nextStep = item.nextStep;
  if (nextStep != null && nextStep.trim().isNotEmpty) {
    return _apiLabel(nextStep);
  }
  return _apiLabel(item.stage ?? item.admissionStatus ?? '');
}

String _lastObservationLabel(BuildContext context, NursingPatientSummary item) {
  final String? observation = item.lastObservation;
  final DateTime? at = item.lastObservationAt;
  if (observation != null && observation.trim().isNotEmpty) {
    return observation;
  }
  return _dateTimeLabel(context, at);
}

String _pageLabel(BuildContext context, AppPage<NursingPatientSummary> page) {
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

const List<String> _vitalTypeOptions = <String>[
  'TEMPERATURE',
  'BLOOD_PRESSURE',
  'HEART_RATE',
  'RESPIRATORY_RATE',
  'OXYGEN_SATURATION',
  'WEIGHT',
  'HEIGHT',
  'BMI',
];

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

const List<String> _administrationStatuses = <String>[
  'GIVEN',
  'MISSED',
  'DELAYED',
  'REFUSED',
];

const List<String> _medicationFrequencies = <String>[
  'ONCE',
  'BID',
  'TID',
  'QID',
  'PRN',
  'STAT',
  'CUSTOM',
];

const List<String> _transferActions = <String>[
  'APPROVE',
  'START',
  'COMPLETE',
  'CANCEL',
];

final List<TextInputFormatter> _decimalFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];

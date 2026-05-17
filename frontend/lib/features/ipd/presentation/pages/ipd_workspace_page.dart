import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class IpdWorkspacePage extends ConsumerWidget {
  const IpdWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<IpdWorkspaceState>> state = ref.watch(
      ipdWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<IpdWorkspaceState>(
      value: state,
      loadingTitle: l10n.ipdLoadingTitle,
      loadingBody: l10n.ipdLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(ipdWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, IpdWorkspaceState data) {
        return _IpdWorkspaceContent(state: data);
      },
    );
  }
}

class _IpdWorkspaceContent extends ConsumerStatefulWidget {
  const _IpdWorkspaceContent({required this.state});

  final IpdWorkspaceState state;

  @override
  ConsumerState<_IpdWorkspaceContent> createState() =>
      _IpdWorkspaceContentState();
}

class _IpdWorkspaceContentState extends ConsumerState<_IpdWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    activeModules: <String>['ipd-flow'],
  );

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
  }

  @override
  void didUpdateWidget(covariant _IpdWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
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
    final IpdWorkspaceState state = widget.state;
    final IpdWorkspaceController controller = ref.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    return AppWorkspace(
      title: l10n.ipdTitle,
      description: l10n.ipdDescription,
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isSaving ? l10n.ipdSavingStatus : l10n.ipdLiveStatus,
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
          label: l10n.ipdAdmissionQueueSummaryLabel,
          value: _countLabel(context, state.admissionQueueCount),
          icon: Icons.bed_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () => controller.applyScope(IpdQueueScope.admissionQueue),
        ),
        AppWorkspaceSummaryCard(
          label: l10n.ipdActivePatientsSummaryLabel,
          value: _countLabel(context, state.activePatientCount),
          icon: Icons.local_hospital_outlined,
          tone: AppWorkspaceStatusTone.info,
          compact: true,
          onPressed: () => controller.applyScope(IpdQueueScope.activePatients),
        ),
        AppWorkspaceSummaryCard(
          label: l10n.ipdTransferPendingSummaryLabel,
          value: _countLabel(context, state.transferPendingCount),
          icon: Icons.swap_horiz,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () => controller.applyScope(IpdQueueScope.transferPending),
        ),
        AppWorkspaceSummaryCard(
          label: l10n.ipdDischargePlannedSummaryLabel,
          value: _countLabel(context, state.dischargePlannedCount),
          icon: Icons.fact_check_outlined,
          tone: AppWorkspaceStatusTone.success,
          compact: true,
          onPressed: () =>
              controller.applyScope(IpdQueueScope.dischargePlanned),
        ),
        AppWorkspaceSummaryCard(
          label: l10n.ipdCriticalAlertsSummaryLabel,
          value: _countLabel(context, state.criticalAlertCount),
          icon: Icons.notification_important_outlined,
          tone: state.criticalAlertCount > 0
              ? AppWorkspaceStatusTone.error
              : AppWorkspaceStatusTone.neutral,
          compact: true,
          onPressed: () => controller.applyScope(IpdQueueScope.all),
        ),
      ],
      filters: AppWorkspaceFilterBar(
        semanticLabel: l10n.ipdFiltersLabel,
        expandSearch: true,
        search: AppSearchBar(
          controller: _searchController,
          semanticLabel: l10n.ipdSearchLabel,
          hintText: l10n.ipdSearchHint,
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
        ),
        filters: <Widget>[
          AppSelectField<IpdQueueScope>(
            value: state.query.scope,
            labelText: l10n.ipdScopeFilterLabel,
            options: _scopeOptions(l10n),
            onChanged: (IpdQueueScope? value) {
              if (value != null) {
                controller.applyScope(value);
              }
            },
          ),
          AppSelectField<String>(
            value: state.query.wardId,
            labelText: l10n.ipdWardFilterLabel,
            hintText: l10n.ipdAllWardsOption,
            options: <AppSelectOption<String>>[
              for (final IpdWardOption ward in state.referenceData.wards)
                AppSelectOption<String>(
                  value: ward.id,
                  label: ward.displayTitle,
                ),
            ],
            onChanged: controller.applyWard,
          ),
        ],
      ),
      body: _IpdBoardPanel(state: state),
      detail: _IpdDetailPanel(
        state: state,
        writeRequirement: _writeRequirement,
      ),
    );
  }
}

class _IpdBoardPanel extends ConsumerWidget {
  const _IpdBoardPanel({required this.state});

  final IpdWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IpdWorkspaceController controller = ref.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.ipdBoardTitle,
      description: l10n.ipdBoardDescription,
      child: AppPaginatedDataList<IpdAdmissionSummary>(
        page: state.admissions,
        isLoading: state.isRefreshing,
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<IpdAdmissionSummary> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        onRowSelected: (IpdAdmissionSummary admission) {
          controller.selectAdmission(admission);
        },
        emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
          title: l10n.ipdNoAdmissionsTitle,
          body: l10n.ipdNoAdmissionsBody,
          icon: Icons.bed_outlined,
        ),
        columns: <AppDataColumn<IpdAdmissionSummary>>[
          AppDataColumn<IpdAdmissionSummary>(
            label: l10n.opdPatientColumnLabel,
            cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
              return _IpdPatientCell(admission: item);
            },
          ),
          AppDataColumn<IpdAdmissionSummary>(
            label: l10n.opdStatusColumnLabel,
            cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
              return AppWorkspaceStatusBadge(
                status: _stageStatus(context, item.stage),
              );
            },
          ),
          AppDataColumn<IpdAdmissionSummary>(
            label: l10n.ipdLocationColumnLabel,
            cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
              return Text(item.location ?? context.l10n.profileUnknownValue);
            },
          ),
          AppDataColumn<IpdAdmissionSummary>(
            label: l10n.ipdPendingActionColumnLabel,
            cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
              return Text(_nextStepLabel(context, item.nextStep));
            },
          ),
          AppDataColumn<IpdAdmissionSummary>(
            label: l10n.ipdAdmittedAtColumnLabel,
            cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
              return Text(_dateTimeLabel(context, item.admittedAt));
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, IpdAdmissionSummary item) {
          return _IpdMobileAdmissionRow(admission: item);
        },
      ),
    );
  }
}

class _IpdPatientCell extends StatelessWidget {
  const _IpdPatientCell({required this.admission});

  final IpdAdmissionSummary admission;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          admission.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          _joinDisplay(<String?>[admission.patientId, admission.displayId]) ??
              context.l10n.profileUnknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _IpdMobileAdmissionRow extends StatelessWidget {
  const _IpdMobileAdmissionRow({required this.admission});

  final IpdAdmissionSummary admission;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _IpdPatientCell(admission: admission)),
              SizedBox(width: theme.spacing.sm),
              AppWorkspaceStatusBadge(
                status: _stageStatus(context, admission.stage),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            _joinDisplay(<String?>[
                  admission.location,
                  _nextStepLabel(context, admission.nextStep),
                ]) ??
                context.l10n.profileUnknownValue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _IpdDetailPanel extends ConsumerWidget {
  const _IpdDetailPanel({required this.state, required this.writeRequirement});

  final IpdWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IpdAdmissionDetail? admission = state.selectedAdmission;

    if (admission == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.ipdAdmissionDetailTitle,
        description: l10n.ipdAdmissionDetailDescription,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.ipdNoSelectionTitle,
          body: l10n.ipdNoSelectionBody,
          icon: Icons.manage_search_outlined,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.ipdAdmissionDetailTitle,
      description: admission.summary.displayId ?? admission.summary.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.isRefreshingDetail)
            const LinearProgressIndicator(minHeight: 2),
          AppWorkspacePatientContextHeader(
            semanticLabel: l10n.ipdPatientContextLabel,
            patientName: admission.patientDisplayName,
            patientNumber:
                admission.summary.patientId ?? l10n.profileUnknownValue,
            demographics: _joinDisplay(<String?>[
              admission.patientGender == null
                  ? null
                  : _apiLabel(admission.patientGender!),
              admission.patientDateOfBirth == null
                  ? null
                  : AppFormatters.mediumDate(
                      admission.patientDateOfBirth!,
                      Localizations.localeOf(context),
                    ),
            ]),
            status: _stageStatus(context, admission.summary.stage),
            alerts: <AppWorkspaceStatus>[
              if (admission.summary.hasCriticalAlert)
                AppWorkspaceStatus(
                  label: _criticalAlertLabel(context, admission.summary),
                  tone: AppWorkspaceStatusTone.error,
                  icon: Icons.notification_important_outlined,
                ),
            ],
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.ipdAdmissionIdLabel,
                value: admission.summary.displayId ?? admission.summary.id,
                icon: Icons.confirmation_number_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.ipdEncounterIdLabel,
                value:
                    admission.summary.encounterId ?? l10n.profileUnknownValue,
                icon: Icons.assignment_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.ipdWardBedLabel,
                value: admission.summary.location ?? l10n.profileUnknownValue,
                icon: Icons.bed_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.ipdFacilityLabel,
                value: admission.facilityName ?? l10n.profileUnknownValue,
                icon: Icons.apartment_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.ipdIcuStatusLabel,
                value: _icuStatusLabel(context, admission.icu.status),
                icon: Icons.monitor_heart_outlined,
                tone: admission.icu.hasCriticalAlert
                    ? AppWorkspaceStatusTone.error
                    : AppWorkspaceStatusTone.neutral,
              ),
            ],
            actions: <Widget>[
              AppAccessActionGate(
                requirement: writeRequirement,
                builder: (BuildContext context, bool isAllowed) {
                  return _IpdDetailActions(
                    admission: admission,
                    state: state,
                    enabled: isAllowed && !state.isSaving,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _IpdBedSection(admission: admission),
          _IpdRecordSection(
            title: l10n.ipdTransfersSectionTitle,
            icon: Icons.swap_horiz,
            records: <IpdClinicalRecord>[
              for (final IpdTransferRequest request
                  in admission.transferRequests)
                IpdClinicalRecord(
                  id: request.id,
                  kind: _ipdTransferKind,
                  status: request.status,
                  title: _joinDisplay(<String?>[
                    request.fromWard?.displayTitle,
                    request.toWard?.displayTitle,
                  ]),
                  occurredAt: request.requestedAt,
                ),
            ],
            emptyTitle: l10n.ipdNoTransfersTitle,
            emptyBody: l10n.ipdNoTransfersBody,
          ),
          _IpdRecordSection(
            title: l10n.ipdRoundsSectionTitle,
            icon: Icons.fact_check_outlined,
            records: admission.wardRounds,
            emptyTitle: l10n.ipdNoRoundsTitle,
            emptyBody: l10n.ipdNoRoundsBody,
          ),
          _IpdRecordSection(
            title: l10n.ipdNursingSectionTitle,
            icon: Icons.note_alt_outlined,
            records: admission.nursingNotes,
            emptyTitle: l10n.ipdNoNursingNotesTitle,
            emptyBody: l10n.ipdNoNursingNotesBody,
          ),
          _IpdRecordSection(
            title: l10n.ipdMedicationSectionTitle,
            icon: Icons.medication_outlined,
            records: <IpdClinicalRecord>[
              ...admission.medicationAdministrations,
              ...admission.medicationReminders,
            ],
            emptyTitle: l10n.ipdNoMedicationTitle,
            emptyBody: l10n.ipdNoMedicationBody,
          ),
          _IpdDischargeSection(admission: admission),
          _IpdTimelineSection(admission: admission),
        ],
      ),
    );
  }
}

class _IpdDetailActions extends ConsumerWidget {
  const _IpdDetailActions({
    required this.admission,
    required this.state,
    required this.enabled,
  });

  final IpdAdmissionDetail admission;
  final IpdWorkspaceState state;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IpdAdmissionSummary summary = admission.summary;
    final bool terminal = summary.isTerminal;
    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      children: <Widget>[
        if (!summary.hasActiveBed && !terminal)
          AppButton.secondary(
            label: l10n.ipdAssignBedAction,
            leadingIcon: Icons.bed_outlined,
            enabled: enabled,
            onPressed: () => _openAssignBedDialog(context, ref),
          ),
        if (summary.hasActiveBed && !terminal)
          AppButton.secondary(
            label: l10n.ipdReleaseBedAction,
            leadingIcon: Icons.cleaning_services_outlined,
            enabled: enabled,
            onPressed: () => _openReleaseBedDialog(context, ref),
          ),
        if (!terminal)
          AppButton.secondary(
            label: l10n.ipdRequestTransferAction,
            leadingIcon: Icons.swap_horiz,
            enabled: enabled,
            onPressed: () => _openTransferRequestDialog(context, ref),
          ),
        if (admission.openTransferRequest != null && !terminal)
          AppButton.secondary(
            label: l10n.ipdManageTransferAction,
            leadingIcon: Icons.move_down_outlined,
            enabled: enabled,
            onPressed: () => _openTransferUpdateDialog(context, ref),
          ),
        if (!terminal)
          AppButton.secondary(
            label: l10n.ipdAddWardRoundAction,
            leadingIcon: Icons.fact_check_outlined,
            enabled: enabled,
            onPressed: () => _openTextActionDialog(
              context,
              ref,
              title: l10n.ipdAddWardRoundAction,
              icon: Icons.fact_check_outlined,
              fieldLabel: l10n.ipdNotesFieldLabel,
              submitLabel: l10n.ipdAddWardRoundAction,
              onSubmit: (String value) => ref
                  .read(ipdWorkspaceControllerProvider.notifier)
                  .addWardRound(summary, value),
            ),
          ),
        if (!terminal)
          AppButton.secondary(
            label: l10n.ipdAddNursingNoteAction,
            leadingIcon: Icons.note_add_outlined,
            enabled: enabled,
            onPressed: () => _openTextActionDialog(
              context,
              ref,
              title: l10n.ipdAddNursingNoteAction,
              icon: Icons.note_add_outlined,
              fieldLabel: l10n.ipdNotesFieldLabel,
              submitLabel: l10n.ipdAddNursingNoteAction,
              onSubmit: (String value) => ref
                  .read(ipdWorkspaceControllerProvider.notifier)
                  .addNursingNote(summary, value),
            ),
          ),
        if (!terminal)
          AppButton.secondary(
            label: l10n.ipdRecordMedicationAction,
            leadingIcon: Icons.medication_outlined,
            enabled: enabled,
            onPressed: () => _openMedicationDialog(context, ref),
          ),
        if (!terminal)
          AppButton.secondary(
            label: l10n.ipdPlanDischargeAction,
            leadingIcon: Icons.fact_check_outlined,
            enabled: enabled,
            onPressed: () => _openTextActionDialog(
              context,
              ref,
              title: l10n.ipdPlanDischargeAction,
              icon: Icons.fact_check_outlined,
              fieldLabel: l10n.ipdSummaryFieldLabel,
              submitLabel: l10n.ipdPlanDischargeAction,
              onSubmit: (String value) => ref
                  .read(ipdWorkspaceControllerProvider.notifier)
                  .planDischarge(summary, value),
            ),
          ),
        if (summary.stage == _stageDischargePlanned)
          AppButton.primary(
            label: l10n.ipdFinalizeDischargeAction,
            leadingIcon: Icons.logout_outlined,
            enabled: enabled,
            onPressed: () => _openTextActionDialog(
              context,
              ref,
              title: l10n.ipdFinalizeDischargeAction,
              icon: Icons.logout_outlined,
              fieldLabel: l10n.ipdSummaryFieldLabel,
              submitLabel: l10n.ipdFinalizeDischargeAction,
              initialValue: admission.latestDischargeSummary?.summary,
              onSubmit: (String value) => ref
                  .read(ipdWorkspaceControllerProvider.notifier)
                  .finalizeDischarge(summary, value),
            ),
          ),
        if (!summary.hasActiveBed && !terminal)
          AppButton.tertiary(
            label: l10n.ipdRejectAdmissionAction,
            leadingIcon: Icons.cancel_outlined,
            enabled: enabled,
            onPressed: () => _openTextActionDialog(
              context,
              ref,
              title: l10n.ipdRejectAdmissionAction,
              icon: Icons.cancel_outlined,
              fieldLabel: l10n.ipdReasonFieldLabel,
              submitLabel: l10n.ipdRejectAdmissionAction,
              onSubmit: (String value) => ref
                  .read(ipdWorkspaceControllerProvider.notifier)
                  .rejectAdmission(summary, value),
            ),
          ),
      ],
    );
  }

  Future<void> _openAssignBedDialog(BuildContext context, WidgetRef ref) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignBedDialog(
        admission: admission.summary,
        beds: state.referenceData.availableBeds,
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openReleaseBedDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReleaseBedDialog(admission: admission.summary),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openTransferRequestDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferRequestDialog(
        admission: admission,
        wards: state.referenceData.wards,
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openTransferUpdateDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferUpdateDialog(
        admission: admission,
        beds: state.referenceData.availableBeds,
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openMedicationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicationAdministrationDialog(admission: admission),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openTextActionDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required IconData icon,
    required String fieldLabel,
    required String submitLabel,
    required Future<AppFailure?> Function(String value) onSubmit,
    String? initialValue,
  }) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IpdTextActionDialog(
        title: title,
        icon: icon,
        fieldLabel: fieldLabel,
        submitLabel: submitLabel,
        initialValue: initialValue,
        onSubmit: onSubmit,
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }
}

class _IpdBedSection extends StatelessWidget {
  const _IpdBedSection({required this.admission});

  final IpdAdmissionDetail admission;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IpdBedAssignment? assignment = admission.activeBedAssignment;
    final IpdBedOption? bed = assignment?.bed;
    return _IpdSection(
      title: l10n.ipdBedSectionTitle,
      icon: Icons.bed_outlined,
      child: _IpdKeyValueGrid(
        values: <_IpdKeyValue>[
          _IpdKeyValue(l10n.ipdBedFieldLabel, bed?.displayTitle),
          _IpdKeyValue(l10n.ipdWardBedLabel, admission.summary.location),
          _IpdKeyValue(
            l10n.opdStatusColumnLabel,
            bed?.status == null ? null : _bedStatusLabel(context, bed!.status),
          ),
          _IpdKeyValue(
            l10n.ipdAdmittedAtColumnLabel,
            _dateTimeLabel(context, admission.summary.admittedAt),
          ),
        ],
      ),
    );
  }
}

class _IpdDischargeSection extends StatelessWidget {
  const _IpdDischargeSection({required this.admission});

  final IpdAdmissionDetail admission;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IpdDischargeSummary? discharge = admission.latestDischargeSummary;
    return _IpdSection(
      title: l10n.ipdDischargeSectionTitle,
      icon: Icons.logout_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _IpdKeyValueGrid(
            values: <_IpdKeyValue>[
              _IpdKeyValue(
                l10n.opdStatusColumnLabel,
                discharge?.status == null
                    ? null
                    : _dischargeStatusLabel(context, discharge!.status),
              ),
              _IpdKeyValue(
                l10n.ipdDischargedAtLabel,
                _dateTimeLabel(context, discharge?.dischargedAt),
              ),
            ],
          ),
          if ((discharge?.summary ?? '').trim().isNotEmpty) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.sm),
            Text(discharge!.summary!),
          ],
        ],
      ),
    );
  }
}

class _IpdTimelineSection extends StatelessWidget {
  const _IpdTimelineSection({required this.admission});

  final IpdAdmissionDetail admission;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> items = admission.timeline
        .map(
          (IpdTimelineItem item) => AppWorkspaceActivityItem(
            title: _timelineTypeLabel(context, item.type),
            subtitle: _dateTimeLabel(context, item.occurredAt),
            description: item.label,
            icon: Icons.timeline_outlined,
          ),
        )
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(top: Theme.of(context).spacing.md),
      child: AppWorkspaceActivityList(
        title: l10n.ipdTimelineSectionTitle,
        items: items,
        emptyTitle: l10n.ipdNoTimelineTitle,
        emptyBody: l10n.ipdNoTimelineBody,
      ),
    );
  }
}

class _IpdRecordSection extends StatelessWidget {
  const _IpdRecordSection({
    required this.title,
    required this.icon,
    required this.records,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final String title;
  final IconData icon;
  final List<IpdClinicalRecord> records;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    return _IpdSection(
      title: title,
      icon: icon,
      child: records.isEmpty
          ? AppStateView(
              variant: AppStateViewVariant.empty,
              title: emptyTitle,
              body: emptyBody,
              crossAxisAlignment: CrossAxisAlignment.center,
              textAlign: TextAlign.center,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  var index = 0;
                  index < records.length;
                  index += 1
                ) ...<Widget>[
                  _IpdRecordRow(record: records[index]),
                  if (index < records.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _IpdRecordRow extends StatelessWidget {
  const _IpdRecordRow({required this.record});

  final IpdClinicalRecord record;

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
            _recordIcon(record.kind),
            size: theme.appTokens.listIconSize,
            color: colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  record.title ?? record.id,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _joinDisplay(<String?>[
                        record.subtitle,
                        record.status == null
                            ? null
                            : _statusLikeLabel(context, record.status),
                        _dateTimeLabel(context, record.occurredAt),
                      ]) ??
                      context.l10n.profileUnknownValue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

class _IpdSection extends StatelessWidget {
  const _IpdSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: theme.appTokens.listIconSize),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

final class _IpdKeyValue {
  const _IpdKeyValue(this.label, this.value);

  final String label;
  final String? value;
}

class _IpdKeyValueGrid extends StatelessWidget {
  const _IpdKeyValueGrid({required this.values});

  final List<_IpdKeyValue> values;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 420 ? 2 : 1;
        final double gap = theme.spacing.sm;
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final _IpdKeyValue value in values)
              SizedBox(
                width: width,
                child: _IpdKeyValueTile(item: value),
              ),
          ],
        );
      },
    );
  }
}

class _IpdKeyValueTile extends StatelessWidget {
  const _IpdKeyValueTile({required this.item});

  final _IpdKeyValue item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          item.value ?? context.l10n.profileUnknownValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class AssignBedDialog extends ConsumerStatefulWidget {
  const AssignBedDialog({
    required this.admission,
    required this.beds,
    super.key,
  });

  final IpdAdmissionSummary admission;
  final List<IpdBedOption> beds;

  @override
  ConsumerState<AssignBedDialog> createState() => _AssignBedDialogState();
}

class _AssignBedDialogState extends ConsumerState<AssignBedDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _bedId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.ipdAssignBedAction),
      icon: const Icon(Icons.bed_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>.searchable(
              value: _bedId,
              labelText: l10n.ipdBedFieldLabel,
              hintText: l10n.ipdSelectBedHint,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredValue<String>(
                l10n.validationRequired,
              ),
              options: <AppSelectOption<String>>[
                for (final IpdBedOption bed in widget.beds)
                  AppSelectOption<String>(
                    value: bed.id,
                    label:
                        _joinDisplay(<String?>[
                          bed.displayTitle,
                          bed.displaySubtitle,
                        ]) ??
                        bed.id,
                  ),
              ],
              onChanged: (String? value) => setState(() => _bedId = value),
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
          label: l10n.ipdAssignBedAction,
          leadingIcon: Icons.bed_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _bedId == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .assignBed(widget.admission, _bedId!);
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

class ReleaseBedDialog extends ConsumerStatefulWidget {
  const ReleaseBedDialog({required this.admission, super.key});

  final IpdAdmissionSummary admission;

  @override
  ConsumerState<ReleaseBedDialog> createState() => _ReleaseBedDialogState();
}

class _ReleaseBedDialogState extends ConsumerState<ReleaseBedDialog> {
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.ipdReleaseBedAction),
      icon: const Icon(Icons.cleaning_services_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          Text(l10n.ipdReleaseBedConfirmationBody),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.ipdReleaseBedAction,
          leadingIcon: Icons.cleaning_services_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .releaseBed(widget.admission);
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

class TransferRequestDialog extends ConsumerStatefulWidget {
  const TransferRequestDialog({
    required this.admission,
    required this.wards,
    super.key,
  });

  final IpdAdmissionDetail admission;
  final List<IpdWardOption> wards;

  @override
  ConsumerState<TransferRequestDialog> createState() =>
      _TransferRequestDialogState();
}

class _TransferRequestDialogState extends ConsumerState<TransferRequestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _wardId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.ipdRequestTransferAction),
      icon: const Icon(Icons.swap_horiz),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>.searchable(
              value: _wardId,
              labelText: l10n.ipdTargetWardFieldLabel,
              hintText: l10n.ipdSelectWardHint,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredValue<String>(
                l10n.validationRequired,
              ),
              options: <AppSelectOption<String>>[
                for (final IpdWardOption ward in widget.wards)
                  AppSelectOption<String>(
                    value: ward.id,
                    label:
                        _joinDisplay(<String?>[
                          ward.displayTitle,
                          ward.wardType == null
                              ? null
                              : _apiLabel(ward.wardType!),
                        ]) ??
                        ward.id,
                  ),
              ],
              onChanged: (String? value) => setState(() => _wardId = value),
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
          label: l10n.ipdRequestTransferAction,
          leadingIcon: Icons.swap_horiz,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _wardId == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .requestTransfer(
          admission: widget.admission.summary,
          fromWardId: widget.admission.activeBedAssignment?.bed?.wardId,
          toWardId: _wardId!,
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

class TransferUpdateDialog extends ConsumerStatefulWidget {
  const TransferUpdateDialog({
    required this.admission,
    required this.beds,
    super.key,
  });

  final IpdAdmissionDetail admission;
  final List<IpdBedOption> beds;

  @override
  ConsumerState<TransferUpdateDialog> createState() =>
      _TransferUpdateDialogState();
}

class _TransferUpdateDialogState extends ConsumerState<TransferUpdateDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _action = _transferApprove;
  String? _bedId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final String status =
        widget.admission.openTransferRequest?.status?.toUpperCase() ?? '';
    if (status == _transferApproved) {
      _action = _transferStart;
    }
    if (status == _transferInProgress) {
      _action = _transferComplete;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.ipdManageTransferAction),
      icon: const Icon(Icons.move_down_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _action,
              labelText: l10n.ipdTransferActionFieldLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _transferApprove,
                  label: l10n.ipdTransferApproveAction,
                ),
                AppSelectOption<String>(
                  value: _transferStart,
                  label: l10n.ipdTransferStartAction,
                ),
                AppSelectOption<String>(
                  value: _transferComplete,
                  label: l10n.ipdTransferCompleteAction,
                ),
                AppSelectOption<String>(
                  value: _transferCancel,
                  label: l10n.ipdTransferCancelAction,
                ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _action = value);
                }
              },
            ),
            if (_action == _transferComplete)
              AppSelectField<String>.searchable(
                value: _bedId,
                labelText: l10n.ipdDestinationBedFieldLabel,
                hintText: l10n.ipdSelectBedHint,
                enabled: !_isSaving,
                isRequired: true,
                validator: AppValidators.requiredValue<String>(
                  l10n.validationRequired,
                ),
                options: <AppSelectOption<String>>[
                  for (final IpdBedOption bed in widget.beds)
                    AppSelectOption<String>(
                      value: bed.id,
                      label:
                          _joinDisplay(<String?>[
                            bed.displayTitle,
                            bed.displaySubtitle,
                          ]) ??
                          bed.id,
                    ),
                ],
                onChanged: (String? value) => setState(() => _bedId = value),
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
          label: l10n.ipdManageTransferAction,
          leadingIcon: Icons.move_down_outlined,
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
    if (_action == _transferComplete && _bedId == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .updateTransfer(
          admission: widget.admission.summary,
          action: _action,
          transferRequestId: widget.admission.openTransferRequest?.id,
          toBedId: _bedId,
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

class IpdTextActionDialog extends StatefulWidget {
  const IpdTextActionDialog({
    required this.title,
    required this.icon,
    required this.fieldLabel,
    required this.submitLabel,
    required this.onSubmit,
    this.initialValue,
    super.key,
  });

  final String title;
  final IconData icon;
  final String fieldLabel;
  final String submitLabel;
  final String? initialValue;
  final Future<AppFailure?> Function(String value) onSubmit;

  @override
  State<IpdTextActionDialog> createState() => _IpdTextActionDialogState();
}

class _IpdTextActionDialogState extends State<IpdTextActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
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
      icon: Icon(widget.icon),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _controller,
              labelText: widget.fieldLabel,
              enabled: !_isSaving,
              minLines: 3,
              maxLines: 8,
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
          leadingIcon: widget.icon,
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

class MedicationAdministrationDialog extends ConsumerStatefulWidget {
  const MedicationAdministrationDialog({required this.admission, super.key});

  final IpdAdmissionDetail admission;

  @override
  ConsumerState<MedicationAdministrationDialog> createState() =>
      _MedicationAdministrationDialogState();
}

class _MedicationAdministrationDialogState
    extends ConsumerState<MedicationAdministrationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _medicationController;
  late final TextEditingController _doseController;
  late final TextEditingController _unitController;
  late final TextEditingController _noteController;
  String? _prescriptionId;
  String _route = _medRouteOral;
  String _frequency = _medFrequencyOnce;
  String _status = _medStatusGiven;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _medicationController = TextEditingController();
    _doseController = TextEditingController();
    _unitController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _doseController.dispose();
    _unitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.ipdRecordMedicationAction),
      icon: const Icon(Icons.medication_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>.searchable(
              value: _prescriptionId,
              labelText: l10n.ipdMedicationOrderFieldLabel,
              hintText: l10n.ipdMedicationOrderHint,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                for (final IpdMedicationSuggestion suggestion
                    in widget.admission.medicationSuggestions)
                  AppSelectOption<String>(
                    value: suggestion.id,
                    label:
                        _joinDisplay(<String?>[
                          suggestion.displayTitle,
                          suggestion.displaySubtitle,
                        ]) ??
                        suggestion.id,
                  ),
              ],
              onChanged: _selectSuggestion,
            ),
            AppTextField(
              controller: _medicationController,
              labelText: l10n.ipdMedicationFieldLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _doseController,
              labelText: l10n.ipdDoseFieldLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _unitController,
              labelText: l10n.ipdUnitFieldLabel,
              enabled: !_isSaving,
            ),
            AppSelectField<String>(
              value: _route,
              labelText: l10n.ipdRouteFieldLabel,
              enabled: !_isSaving,
              options: _routeOptions(l10n),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _route = value);
                }
              },
            ),
            AppSelectField<String>(
              value: _frequency,
              labelText: l10n.ipdFrequencyFieldLabel,
              enabled: !_isSaving,
              options: _frequencyOptions(l10n),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _frequency = value);
                }
              },
            ),
            AppSelectField<String>(
              value: _status,
              labelText: l10n.ipdMedicationStatusFieldLabel,
              enabled: !_isSaving,
              options: _medicationStatusOptions(l10n),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            AppTextField(
              controller: _noteController,
              labelText: l10n.ipdNotesFieldLabel,
              enabled: !_isSaving,
              maxLines: 3,
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
          label: l10n.ipdRecordMedicationAction,
          leadingIcon: Icons.medication_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _selectSuggestion(String? value) {
    final IpdMedicationSuggestion? suggestion = _firstMedicationSuggestion(
      widget.admission.medicationSuggestions,
      value,
    );
    setState(() {
      _prescriptionId = value;
      if (suggestion != null) {
        _medicationController.text = suggestion.medicationLabel ?? '';
        _doseController.text = suggestion.dose ?? '';
        _unitController.text = suggestion.unit ?? '';
        _route = suggestion.route ?? _route;
        _frequency = suggestion.frequency ?? _frequency;
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
        .read(ipdWorkspaceControllerProvider.notifier)
        .addMedicationAdministration(
          widget.admission.summary,
          <String, Object?>{
            'prescription_id': _prescriptionId,
            'medication_label': _medicationController.text.trim(),
            'dose': _doseController.text.trim(),
            'unit': _unitController.text.trim(),
            'route': _route,
            'frequency': _frequency,
            'status': _status,
            'administration_note': _noteController.text.trim(),
            'administered_at': DateTime.now().toUtc().toIso8601String(),
          },
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

List<AppSelectOption<IpdQueueScope>> _scopeOptions(AppLocalizations l10n) {
  return <AppSelectOption<IpdQueueScope>>[
    AppSelectOption<IpdQueueScope>(
      value: IpdQueueScope.admissionQueue,
      label: l10n.ipdScopeAdmissionQueue,
    ),
    AppSelectOption<IpdQueueScope>(
      value: IpdQueueScope.activePatients,
      label: l10n.ipdScopeActivePatients,
    ),
    AppSelectOption<IpdQueueScope>(
      value: IpdQueueScope.transferPending,
      label: l10n.ipdScopeTransferPending,
    ),
    AppSelectOption<IpdQueueScope>(
      value: IpdQueueScope.dischargePlanned,
      label: l10n.ipdScopeDischargePlanned,
    ),
    AppSelectOption<IpdQueueScope>(
      value: IpdQueueScope.awaitingClearance,
      label: l10n.ipdScopeAwaitingClearance,
    ),
    AppSelectOption<IpdQueueScope>(
      value: IpdQueueScope.discharged,
      label: l10n.ipdScopeDischarged,
    ),
    AppSelectOption<IpdQueueScope>(
      value: IpdQueueScope.all,
      label: l10n.ipdScopeAll,
    ),
  ];
}

List<AppSelectOption<String>> _routeOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(value: _medRouteOral, label: l10n.ipdRouteOral),
    AppSelectOption<String>(value: _medRouteIv, label: l10n.ipdRouteIv),
    AppSelectOption<String>(value: _medRouteIm, label: l10n.ipdRouteIm),
    AppSelectOption<String>(
      value: _medRouteTopical,
      label: l10n.ipdRouteTopical,
    ),
    AppSelectOption<String>(
      value: _medRouteInhalation,
      label: l10n.ipdRouteInhalation,
    ),
    AppSelectOption<String>(value: _medRouteOther, label: l10n.ipdRouteOther),
  ];
}

List<AppSelectOption<String>> _frequencyOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _medFrequencyOnce,
      label: l10n.ipdFrequencyOnce,
    ),
    AppSelectOption<String>(
      value: _medFrequencyBid,
      label: l10n.ipdFrequencyBid,
    ),
    AppSelectOption<String>(
      value: _medFrequencyTid,
      label: l10n.ipdFrequencyTid,
    ),
    AppSelectOption<String>(
      value: _medFrequencyQid,
      label: l10n.ipdFrequencyQid,
    ),
    AppSelectOption<String>(
      value: _medFrequencyPrn,
      label: l10n.ipdFrequencyPrn,
    ),
    AppSelectOption<String>(
      value: _medFrequencyStat,
      label: l10n.ipdFrequencyStat,
    ),
    AppSelectOption<String>(
      value: _medFrequencyCustom,
      label: l10n.ipdFrequencyCustom,
    ),
  ];
}

List<AppSelectOption<String>> _medicationStatusOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _medStatusGiven,
      label: l10n.ipdMedicationGiven,
    ),
    AppSelectOption<String>(
      value: _medStatusMissed,
      label: l10n.ipdMedicationMissed,
    ),
    AppSelectOption<String>(
      value: _medStatusDelayed,
      label: l10n.ipdMedicationDelayed,
    ),
    AppSelectOption<String>(
      value: _medStatusRefused,
      label: l10n.ipdMedicationRefused,
    ),
  ];
}

AppWorkspaceStatus _stageStatus(BuildContext context, String? stage) {
  final AppWorkspaceStatusTone tone = switch ((stage ?? '').toUpperCase()) {
    _stageAdmittedInBed => AppWorkspaceStatusTone.info,
    _stageAdmittedPendingBed => AppWorkspaceStatusTone.warning,
    _stageTransferRequested ||
    _stageTransferInProgress => AppWorkspaceStatusTone.warning,
    _stageDischargePlanned => AppWorkspaceStatusTone.success,
    _stageDischarged => AppWorkspaceStatusTone.neutral,
    _stageCancelled => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
  return AppWorkspaceStatus(label: _stageLabel(context, stage), tone: tone);
}

String _stageLabel(BuildContext context, String? stage) {
  final AppLocalizations l10n = context.l10n;
  return switch ((stage ?? '').toUpperCase()) {
    _stageAdmittedPendingBed => l10n.ipdStatusAdmittedPendingBed,
    _stageAdmittedInBed => l10n.ipdStatusAdmittedInBed,
    _stageTransferRequested => l10n.ipdStatusTransferRequested,
    _stageTransferInProgress => l10n.ipdStatusTransferInProgress,
    _stageDischargePlanned => l10n.ipdStatusDischargePlanned,
    _stageDischarged => l10n.ipdStatusDischarged,
    _stageCancelled => l10n.ipdStatusCancelled,
    _ => context.l10n.profileUnknownValue,
  };
}

String _nextStepLabel(BuildContext context, String? nextStep) {
  final AppLocalizations l10n = context.l10n;
  return switch ((nextStep ?? '').toUpperCase()) {
    'ASSIGN_BED' => l10n.ipdNextAssignBed,
    'RECORD_NURSING_NOTE' => l10n.ipdNextRecordNursingNote,
    'APPROVE_TRANSFER' => l10n.ipdNextApproveTransfer,
    'START_TRANSFER' => l10n.ipdNextStartTransfer,
    'COMPLETE_TRANSFER' => l10n.ipdNextCompleteTransfer,
    'FINALIZE_DISCHARGE' => l10n.ipdNextFinalizeDischarge,
    _ => l10n.ipdNextContinueCare,
  };
}

String _bedStatusLabel(BuildContext context, String? status) {
  final AppLocalizations l10n = context.l10n;
  return switch ((status ?? '').toUpperCase()) {
    'AVAILABLE' => l10n.ipdBedStatusAvailable,
    'OCCUPIED' => l10n.ipdBedStatusOccupied,
    'RESERVED' => l10n.ipdBedStatusReserved,
    'OUT_OF_SERVICE' => l10n.ipdBedStatusOutOfService,
    _ => context.l10n.profileUnknownValue,
  };
}

String _dischargeStatusLabel(BuildContext context, String? status) {
  final AppLocalizations l10n = context.l10n;
  return switch ((status ?? '').toUpperCase()) {
    'PLANNED' => l10n.ipdDischargeStatusPlanned,
    'COMPLETED' => l10n.ipdDischargeStatusCompleted,
    _ => context.l10n.profileUnknownValue,
  };
}

String _icuStatusLabel(BuildContext context, String? status) {
  final AppLocalizations l10n = context.l10n;
  return switch ((status ?? '').toUpperCase()) {
    'ACTIVE' => l10n.ipdIcuStatusActive,
    'ENDED' => l10n.ipdIcuStatusEnded,
    'NONE' => l10n.ipdIcuStatusNone,
    _ => l10n.ipdIcuStatusNone,
  };
}

String _statusLikeLabel(BuildContext context, String? status) {
  if (status == null || status.trim().isEmpty) {
    return context.l10n.profileUnknownValue;
  }
  return _apiLabel(status);
}

String _timelineTypeLabel(BuildContext context, String type) {
  final AppLocalizations l10n = context.l10n;
  return switch (type.toUpperCase()) {
    'WARD_ROUND' => l10n.ipdTimelineWardRound,
    'NURSING_NOTE' => l10n.ipdTimelineNursingNote,
    'MEDICATION_ADMINISTRATION' => l10n.ipdTimelineMedication,
    'MEDICATION_REMINDER' => l10n.ipdTimelineMedicationReminder,
    'TRANSFER' => l10n.ipdTimelineTransfer,
    'ICU_OBSERVATION' => l10n.ipdTimelineIcuObservation,
    'CRITICAL_ALERT' => l10n.ipdTimelineCriticalAlert,
    _ => l10n.ipdTimelineCareEvent,
  };
}

String _criticalAlertLabel(BuildContext context, IpdAdmissionSummary summary) {
  final String? severity = summary.criticalSeverity;
  if (severity == null || severity.trim().isEmpty) {
    return context.l10n.ipdCriticalAlertLabel;
  }
  return context.l10n.ipdCriticalSeverityLabel(_apiLabel(severity));
}

IconData _recordIcon(String kind) {
  return switch (kind) {
    _ipdTransferKind => Icons.swap_horiz,
    'ward_round' => Icons.fact_check_outlined,
    'nursing_note' => Icons.note_alt_outlined,
    'medication_administration' ||
    'medication_reminder' => Icons.medication_outlined,
    'critical_alert' => Icons.notification_important_outlined,
    'icu_observation' => Icons.monitor_heart_outlined,
    _ => Icons.circle_outlined,
  };
}

String _countLabel(BuildContext context, int value) {
  return AppFormatters.compactNumber(value, Localizations.localeOf(context));
}

String _pageLabel<T>(BuildContext context, AppPage<T> page) {
  final int total = page.totalItemCount ?? page.lastItemNumber;
  return context.l10n.opdPageLabel(
    page.firstItemNumber,
    page.lastItemNumber,
    total,
  );
}

IpdMedicationSuggestion? _firstMedicationSuggestion(
  Iterable<IpdMedicationSuggestion> suggestions,
  String? id,
) {
  for (final IpdMedicationSuggestion suggestion in suggestions) {
    if (suggestion.id == id) {
      return suggestion;
    }
  }
  return null;
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
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

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.ipdSavedMessage)));
}

const String _stageAdmittedPendingBed = 'ADMITTED_PENDING_BED';
const String _stageAdmittedInBed = 'ADMITTED_IN_BED';
const String _stageTransferRequested = 'TRANSFER_REQUESTED';
const String _stageTransferInProgress = 'TRANSFER_IN_PROGRESS';
const String _stageDischargePlanned = 'DISCHARGE_PLANNED';
const String _stageDischarged = 'DISCHARGED';
const String _stageCancelled = 'CANCELLED';
const String _transferApprove = 'APPROVE';
const String _transferStart = 'START';
const String _transferComplete = 'COMPLETE';
const String _transferCancel = 'CANCEL';
const String _transferApproved = 'APPROVED';
const String _transferInProgress = 'IN_PROGRESS';
const String _ipdTransferKind = 'transfer';
const String _medRouteOral = 'ORAL';
const String _medRouteIv = 'IV';
const String _medRouteIm = 'IM';
const String _medRouteTopical = 'TOPICAL';
const String _medRouteInhalation = 'INHALATION';
const String _medRouteOther = 'OTHER';
const String _medFrequencyOnce = 'ONCE';
const String _medFrequencyBid = 'BID';
const String _medFrequencyTid = 'TID';
const String _medFrequencyQid = 'QID';
const String _medFrequencyPrn = 'PRN';
const String _medFrequencyStat = 'STAT';
const String _medFrequencyCustom = 'CUSTOM';
const String _medStatusGiven = 'GIVEN';
const String _medStatusMissed = 'MISSED';
const String _medStatusDelayed = 'DELAYED';
const String _medStatusRefused = 'REFUSED';

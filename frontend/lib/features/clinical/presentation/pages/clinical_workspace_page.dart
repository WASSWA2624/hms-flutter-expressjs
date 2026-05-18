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
import 'package:hosspi_hms/core/platform/app_print.dart';
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
            controller.applyScope(ClinicalQueueScope.waitingReview);
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.clinicalUrgentSummaryLabel,
          value: _countLabel(context, state.urgentCount),
          icon: Icons.priority_high_outlined,
          tone: AppWorkspaceStatusTone.error,
          compact: true,
          onPressed: () {
            controller.applyScope(ClinicalQueueScope.urgent);
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.clinicalResultsReadySummaryLabel,
          value: _countLabel(context, state.resultsReadyCount),
          icon: Icons.science_outlined,
          tone: AppWorkspaceStatusTone.success,
          compact: true,
          onPressed: () {
            controller.applyScope(ClinicalQueueScope.resultsReady);
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.clinicalInConsultationSummaryLabel,
          value: _countLabel(context, state.inConsultationCount),
          icon: Icons.medical_information_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () {
            controller.applyScope(ClinicalQueueScope.inConsultation);
          },
        ),
      ],
      filters: AppWorkspaceFilterBar(
        semanticLabel: l10n.clinicalFiltersLabel,
        expandSearch: true,
        search: AppSearchBar(
          controller: _searchController,
          semanticLabel: l10n.clinicalSearchLabel,
          hintText: l10n.clinicalSearchHint,
          onSubmitted: (String value) {
            controller.applySearch(value);
          },
          onClear: () {
            controller.applySearch('');
          },
        ),
        filters: <Widget>[
          AppSelectField<ClinicalQueueScope>(
            value: state.query.scope,
            labelText: l10n.clinicalScopeFilterLabel,
            options: _scopeOptions(l10n),
            onChanged: (ClinicalQueueScope? value) {
              if (value != null) {
                controller.applyScope(value);
              }
            },
          ),
        ],
      ),
      body: _ClinicalWorklistPanel(state: state),
      detail: _ClinicalDetailPanel(state: state),
    );
  }
}

class _ClinicalWorklistPanel extends ConsumerWidget {
  const _ClinicalWorklistPanel({required this.state});

  final ClinicalWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    return AppWorkspaceDetailPanel(
      title: l10n.clinicalWorklistTitle,
      description: l10n.clinicalWorklistDescription,
      child: AppPaginatedListTable<ClinicalWorklistEntry>(
        page: state.worklist,
        isLoading: state.isRefreshing,
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<ClinicalWorklistEntry> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        onRowSelected: (ClinicalWorklistEntry entry) {
          controller.selectEntry(entry);
        },
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.clinicalNoWorklistTitle,
          body: l10n.clinicalNoWorklistBody,
          icon: Icons.assignment_outlined,
        ),
        columns: <AppListTableColumn<ClinicalWorklistEntry>>[
          AppListTableColumn<ClinicalWorklistEntry>(
            label: l10n.opdPatientColumnLabel,
            cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
              return _ClinicalPatientCell(item: item);
            },
          ),
          AppListTableColumn<ClinicalWorklistEntry>(
            label: l10n.clinicalSourceQueueLabel,
            cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
              return Text(_apiLabel(item.sourceQueue));
            },
          ),
          AppListTableColumn<ClinicalWorklistEntry>(
            label: l10n.opdStatusColumnLabel,
            cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
              return AppWorkspaceStatusBadge(status: _entryStatus(item));
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
              return Text(
                _dateTimeLabel(context, item.updatedAt ?? item.startedAt),
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, ClinicalWorklistEntry item) {
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
                    AppWorkspaceStatusBadge(status: _entryStatus(item)),
                    Text(
                      _joinDisplay(<String?>[
                        _apiLabel(item.sourceQueue),
                        item.providerDisplayName,
                        _dateTimeLabel(
                          context,
                          item.updatedAt ?? item.startedAt,
                        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: entry.displayTitle,
          patientNumber: entry.patientPublicId ?? entry.patientId ?? entry.id,
          demographics: entry.patientAgeSex,
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
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.clinicalEncounterNumberLabel,
              value: entry.encounterPublicId ?? entry.encounterId,
              icon: Icons.tag_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.clinicalSourceQueueLabel,
              value: _apiLabel(entry.sourceQueue),
              icon: Icons.queue_outlined,
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
          ],
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        if (bundle.triageHandoff?.hasContent ?? false) ...<Widget>[
          _ClinicalTriageHandoffPanel(handoff: bundle.triageHandoff!),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        _ClinicalActionBar(bundle: bundle, referenceData: state.referenceData),
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
                onPressed: () => printHtmlDocument(
                  _consultationSummaryHtml(context, bundle),
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
          title: l10n.opdClinicalNotesSummaryLabel,
          records: bundle.clinicalNotes,
        ),
        SizedBox(height: theme.spacing.md),
        _ClinicalRecordSection(
          title: l10n.clinicalDiagnosesTitle,
          records: bundle.diagnoses,
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
            ...bundle.labOrders,
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
  const _ClinicalRecordSection({required this.title, required this.records});

  final String title;
  final List<ClinicalRelatedRecord> records;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: title,
      child: _ClinicalRecordList(
        records: records,
        emptyLabel: context.l10n.opdNoRelatedRecordsLabel,
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
          Icon(
            _recordIcon(record.kind),
            size: theme.appTokens.listIconSize,
            color: theme.colorScheme.primary,
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
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _controller,
              labelText: widget.label,
              maxLines: 6,
              enabled: !_isSaving,
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  String _diagnosisType = 'PRIMARY';
  List<ClinicalCatalogOption> _terms = const <ClinicalCatalogOption>[];
  bool _isSaving = false;
  bool _isSearching = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadTerms();
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
      title: Text(l10n.clinicalAddDiagnosisAction),
      icon: const Icon(Icons.rule_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _diagnosisType,
              labelText: l10n.opdDiagnosisTypeLabel,
              enabled: !_isSaving,
              options: _statusOptions(_diagnosisTypes),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _diagnosisType = value);
                }
              },
            ),
            AppSelectField<String>.searchable(
              options: _catalogOptions(_terms),
              labelText: l10n.clinicalTermSearchLabel,
              isLoading: _isSearching,
              enabled: !_isSaving,
              onChanged: _applyTerm,
            ),
            AppTextField(
              controller: _codeController,
              labelText: l10n.opdDiagnosisCodeLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.opdDiagnosisLabel,
              maxLines: 3,
              enabled: !_isSaving,
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

  Future<void> _loadTerms() async {
    setState(() => _isSearching = true);
    final Result<List<ClinicalCatalogOption>> result = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .searchClinicalTerms(termType: 'DIAGNOSIS');
    if (!mounted) {
      return;
    }
    setState(() {
      _terms = result.when(
        success: (List<ClinicalCatalogOption> value) => value,
        failure: (_) => const <ClinicalCatalogOption>[],
      );
      _isSearching = false;
    });
  }

  void _applyTerm(String? value) {
    final ClinicalCatalogOption? term = _terms
        .where((ClinicalCatalogOption option) => option.apiId == value)
        .firstOrNull;
    if (term == null) {
      return;
    }
    _codeController.text = term.code ?? '';
    _descriptionController.text = term.name ?? '';
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
  const _LabOrderDialog({required this.referenceData});

  final ClinicalReferenceData referenceData;

  @override
  ConsumerState<_LabOrderDialog> createState() => _LabOrderDialogState();
}

class _LabOrderDialogState extends ConsumerState<_LabOrderDialog> {
  String? _labTestId;
  String? _labPanelId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.clinicalRequestLabAction),
      icon: const Icon(Icons.science_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppSelectField<String>.searchable(
            value: _labTestId,
            labelText: l10n.opdLabTestIdsLabel,
            enabled: !_isSaving,
            options: _catalogOptions(widget.referenceData.labTests),
            onChanged: (String? value) => setState(() => _labTestId = value),
          ),
          AppSelectField<String>.searchable(
            value: _labPanelId,
            labelText: l10n.opdLabPanelIdsLabel,
            enabled: !_isSaving,
            options: _catalogOptions(widget.referenceData.labPanels),
            onChanged: (String? value) => setState(() => _labPanelId = value),
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.clinicalRequestLabAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (_labTestId == null && _labPanelId == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .requestLab(
          labTestIds: <String>[?_labTestId],
          labPanelIds: <String>[?_labPanelId],
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

class _RadiologyOrderDialog extends ConsumerStatefulWidget {
  const _RadiologyOrderDialog({required this.referenceData});

  final ClinicalReferenceData referenceData;

  @override
  ConsumerState<_RadiologyOrderDialog> createState() =>
      _RadiologyOrderDialogState();
}

class _RadiologyOrderDialogState extends ConsumerState<_RadiologyOrderDialog> {
  late final TextEditingController _noteController;
  String? _radiologyTestId;
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
      title: Text(l10n.clinicalRequestRadiologyAction),
      icon: const Icon(Icons.biotech_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppSelectField<String>.searchable(
            value: _radiologyTestId,
            labelText: l10n.opdRadiologyTestIdsLabel,
            enabled: !_isSaving,
            options: _catalogOptions(widget.referenceData.radiologyTests),
            onChanged: (String? value) {
              setState(() => _radiologyTestId = value);
            },
          ),
          AppTextField(
            controller: _noteController,
            labelText: l10n.opdClinicalNoteLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.clinicalRequestRadiologyAction,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (_radiologyTestId == null) {
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
          radiologyTestId: _radiologyTestId!,
          clinicalNote: _noteController.text.trim(),
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

class _PrescriptionDialog extends ConsumerStatefulWidget {
  const _PrescriptionDialog({required this.referenceData});

  final ClinicalReferenceData referenceData;

  @override
  ConsumerState<_PrescriptionDialog> createState() =>
      _PrescriptionDialogState();
}

class _PrescriptionDialogState extends ConsumerState<_PrescriptionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late final TextEditingController _doseAmountController;
  late final TextEditingController _doseUnitController;
  late final TextEditingController _durationController;
  late final TextEditingController _durationUnitController;
  late final TextEditingController _instructionsController;
  String? _drugId;
  String? _route = 'ORAL';
  String? _frequency = 'BID';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _doseAmountController = TextEditingController();
    _doseUnitController = TextEditingController();
    _durationController = TextEditingController();
    _durationUnitController = TextEditingController();
    _instructionsController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _doseAmountController.dispose();
    _doseUnitController.dispose();
    _durationController.dispose();
    _durationUnitController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.clinicalPrescribeAction),
      icon: const Icon(Icons.medication_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>.searchable(
              value: _drugId,
              labelText: l10n.opdDrugLabel,
              enabled: !_isSaving,
              options: _catalogOptions(widget.referenceData.drugs),
              validator: (String? value) =>
                  value == null ? l10n.validationRequired : null,
              onChanged: (String? value) => setState(() => _drugId = value),
            ),
            AppTextField(
              controller: _quantityController,
              labelText: l10n.opdDrugQuantityLabel,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: _integerFormatters,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _doseAmountController,
              labelText: l10n.clinicalDoseAmountLabel,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: _decimalFormatters,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _doseUnitController,
              labelText: l10n.clinicalDoseUnitLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>(
              value: _route,
              labelText: l10n.opdMedicationRouteLabel,
              enabled: !_isSaving,
              options: _statusOptions(_medicationRoutes),
              onChanged: (String? value) => setState(() => _route = value),
            ),
            AppSelectField<String>(
              value: _frequency,
              labelText: l10n.opdFrequencyLabel,
              enabled: !_isSaving,
              options: _statusOptions(_medicationFrequencies),
              onChanged: (String? value) => setState(() => _frequency = value),
            ),
            AppTextField(
              controller: _durationController,
              labelText: l10n.clinicalDurationValueLabel,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: _integerFormatters,
            ),
            AppTextField(
              controller: _durationUnitController,
              labelText: l10n.clinicalDurationUnitLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _instructionsController,
              labelText: l10n.clinicalInstructionsLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.clinicalPrescribeAction,
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
        .prescribe(
          drugId: _drugId!,
          quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
          doseAmount: num.tryParse(_doseAmountController.text.trim()),
          doseUnit: _doseUnitController.text.trim(),
          route: _route,
          frequency: _frequency,
          durationValue: int.tryParse(_durationController.text.trim()),
          durationUnit: _durationUnitController.text.trim(),
          instructions: _instructionsController.text.trim(),
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
        title: context.l10n.clinicalAddNoteAction,
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
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LabOrderDialog(referenceData: referenceData),
    ),
  );
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

List<AppSelectOption<ClinicalQueueScope>> _scopeOptions(AppLocalizations l10n) {
  return <AppSelectOption<ClinicalQueueScope>>[
    AppSelectOption<ClinicalQueueScope>(
      value: ClinicalQueueScope.today,
      label: l10n.clinicalTodayScopeLabel,
    ),
    AppSelectOption<ClinicalQueueScope>(
      value: ClinicalQueueScope.urgent,
      label: l10n.clinicalUrgentSummaryLabel,
    ),
    AppSelectOption<ClinicalQueueScope>(
      value: ClinicalQueueScope.waitingReview,
      label: l10n.clinicalWaitingReviewSummaryLabel,
    ),
    AppSelectOption<ClinicalQueueScope>(
      value: ClinicalQueueScope.inConsultation,
      label: l10n.clinicalInConsultationSummaryLabel,
    ),
    AppSelectOption<ClinicalQueueScope>(
      value: ClinicalQueueScope.resultsReady,
      label: l10n.clinicalResultsReadySummaryLabel,
    ),
    AppSelectOption<ClinicalQueueScope>(
      value: ClinicalQueueScope.completed,
      label: l10n.clinicalCompletedSummaryLabel,
    ),
  ];
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

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

AppWorkspaceStatus _entryStatus(ClinicalWorklistEntry item) {
  final String value =
      item.stage ?? item.status ?? item.nextStep ?? item.sourceQueue;
  return AppWorkspaceStatus(label: _apiLabel(value), tone: _statusTone(value));
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
    'IN_PROCESS' ||
    'OPEN' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
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

String _consultationSummaryHtml(
  BuildContext context,
  ClinicalEncounterBundle bundle,
) {
  final AppLocalizations l10n = context.l10n;
  final ClinicalWorklistEntry entry = bundle.entry;
  final StringBuffer buffer = StringBuffer()
    ..write('<h1>${_escapeHtml(l10n.clinicalConsultationSummaryTitle)}</h1>')
    ..write('<p>${_escapeHtml(entry.displayTitle)}</p>')
    ..write(
      '<p>${_escapeHtml(entry.encounterPublicId ?? entry.encounterId)}</p>',
    )
    ..write('<h2>${_escapeHtml(l10n.opdClinicalNotesSummaryLabel)}</h2>')
    ..write(_recordsHtml(bundle.clinicalNotes))
    ..write('<h2>${_escapeHtml(l10n.clinicalDiagnosesTitle)}</h2>')
    ..write(_recordsHtml(bundle.diagnoses))
    ..write('<h2>${_escapeHtml(l10n.clinicalOrdersTitle)}</h2>')
    ..write(
      _recordsHtml(<ClinicalRelatedRecord>[
        ...bundle.labOrders,
        ...bundle.radiologyOrders,
        ...bundle.pharmacyOrders,
      ]),
    );
  return buffer.toString();
}

String _recordsHtml(List<ClinicalRelatedRecord> records) {
  if (records.isEmpty) {
    return '<p></p>';
  }
  final StringBuffer buffer = StringBuffer('<ul>');
  for (final ClinicalRelatedRecord record in records) {
    buffer
      ..write('<li>')
      ..write(
        _escapeHtml(
          _joinDisplay(<String?>[
            record.title,
            record.subtitle,
            record.status == null ? null : _apiLabel(record.status!),
          ]),
        ),
      )
      ..write('</li>');
  }
  buffer.write('</ul>');
  return buffer.toString();
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
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
  'Q6H',
  'Q8H',
  'Q12H',
  'PRN',
  'STAT',
  'CUSTOM',
];

const List<String> _medicationRoutes = <String>[
  'ORAL',
  'IV',
  'IM',
  'SC',
  'TOPICAL',
  'INHALATION',
  'OTHER',
];

final List<TextInputFormatter> _integerFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

final List<TextInputFormatter> _decimalFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];

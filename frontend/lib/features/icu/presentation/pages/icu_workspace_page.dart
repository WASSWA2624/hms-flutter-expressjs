import 'dart:async';

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
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
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

class IcuWorkspacePage extends ConsumerWidget {
  const IcuWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<IcuWorkspaceState>> state = ref.watch(
      icuWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<IcuWorkspaceState>(
      value: state,
      loadingTitle: 'Loading ICU board',
      loadingBody: 'Loading intensive care patients and alert state.',
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(icuWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, IcuWorkspaceState data) {
        return _IcuWorkspaceContent(state: data);
      },
    );
  }
}

class _IcuWorkspaceContent extends ConsumerStatefulWidget {
  const _IcuWorkspaceContent({required this.state});

  final IcuWorkspaceState state;

  @override
  ConsumerState<_IcuWorkspaceContent> createState() =>
      _IcuWorkspaceContentState();
}

class _IcuWorkspaceContentState extends ConsumerState<_IcuWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.emergencyWrite,
    ],
    activeModules: <String>['icu-critical-care'],
  );

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
  }

  @override
  void didUpdateWidget(covariant _IcuWorkspaceContent oldWidget) {
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
    final IcuWorkspaceState state = widget.state;
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );

    return AppWorkspace(
      title: 'ICU',
      leadingIcon: AppRouteIcons.icu,
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isSaving ? 'Saving' : 'Live sync',
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
      ),
      secondaryActions: <Widget>[
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshingBoard,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        if (_pageTotal(state.board) > 0)
          AppWorkspaceSummaryCard(
            label: _IcuText.allIcu,
            value: _countLabel(context, _pageTotal(state.board)),
            icon: Icons.inventory_2_outlined,
            compact: true,
            onPressed: () => controller.applyScope(IcuBoardScope.all),
          ),
        if (state.activeCount > 0)
          AppWorkspaceSummaryCard(
            label: _IcuText.activeIcu,
            value: _countLabel(context, state.activeCount),
            icon: Icons.bed_outlined,
            tone: AppWorkspaceStatusTone.info,
            compact: true,
            onPressed: () => controller.applyScope(IcuBoardScope.active),
          ),
        if (state.criticalCount > 0)
          AppWorkspaceSummaryCard(
            label: _IcuText.criticalAlerts,
            value: _countLabel(context, state.criticalCount),
            icon: Icons.priority_high_outlined,
            tone: AppWorkspaceStatusTone.error,
            compact: true,
            onPressed: () => controller.applyScope(IcuBoardScope.critical),
          ),
        if (state.transferCount > 0)
          AppWorkspaceSummaryCard(
            label: _IcuText.transfers,
            value: _countLabel(context, state.transferCount),
            icon: Icons.compare_arrows_outlined,
            tone: AppWorkspaceStatusTone.warning,
            compact: true,
            onPressed: () => controller.applyScope(IcuBoardScope.transfer),
          ),
        if (state.dischargeReadyCount > 0)
          AppWorkspaceSummaryCard(
            label: _IcuText.dischargeReady,
            value: _countLabel(context, state.dischargeReadyCount),
            icon: Icons.fact_check_outlined,
            tone: AppWorkspaceStatusTone.success,
            compact: true,
            onPressed: () => controller.applyScope(IcuBoardScope.discharge),
          ),
      ],
      body: _IcuBoardPanel(
        state: state,
        writeRequirement: _writeRequirement,
        searchController: _searchController,
      ),
    );
  }
}

class _IcuBoardPanel extends ConsumerWidget {
  const _IcuBoardPanel({
    required this.state,
    required this.writeRequirement,
    required this.searchController,
  });

  final IcuWorkspaceState state;
  final AccessRequirement writeRequirement;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: 'ICU board',
      description: 'Grouped by bed state and alert level.',
      child: AppListTable<IcuPatientSummary>(
        page: state.board,
        isLoading: state.isRefreshingBoard,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        search: AppListTableSearch<IcuPatientSummary>(
          controller: searchController,
          semanticLabel: 'Search ICU',
          hintText: _IcuText.searchHint,
          matcher: (_, _) => true,
          onSubmitted: controller.applySearch,
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: 'Board scope',
          advancedFilterTitle: 'ICU board filters',
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.opdClearFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
          enableDateFilter: false,
          allFieldsLabel: _IcuText.activeIcu,
          filterGroups: <AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: _icuScopeFilterKey,
              label: 'Board scope',
              allLabel: _IcuText.activeIcu,
              choices: _icuScopeFilterChoices(),
            ),
          ],
          filterValue: _icuFilterValue(state.query),
          hasActiveFilters: state.query.scope != IcuBoardScope.active,
          onFilterChanged: (AppSearchBarFilterValue value) {
            controller.applyScope(
              _icuScopeFromFilter(value.option(_icuScopeFilterKey)),
            );
          },
        ),
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<IcuPatientSummary> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: (AppPageRequest request) {
          controller.changePage(request);
        },
        onRowSelected: (IcuPatientSummary summary) {
          unawaited(
            _openIcuDetailDialog(
              context,
              ref,
              state,
              summary,
              writeRequirement,
            ),
          );
        },
        rowColorBuilder: _rowColor,
        emptyBuilder: (_) => const AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: 'No ICU patients',
          body:
              'Active ICU admissions will appear here after IPD admission and ICU transfer.',
          icon: Icons.bed_outlined,
        ),
        columns: <AppListTableColumn<IcuPatientSummary>>[
          AppListTableColumn<IcuPatientSummary>(
            label: l10n.opdPatientColumnLabel,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(left.displayTitle, right.displayTitle),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return _IcuPatientCell(item: item);
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: _IcuText.bed,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(
                  left.locationLabel,
                  right.locationLabel,
                ),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return Text(item.locationLabel);
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: _IcuText.alert,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(
                  left.criticalSeverity,
                  right.criticalSeverity,
                ),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return AppWorkspaceStatusBadge(status: _alertStatus(item));
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: l10n.opdStatusColumnLabel,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(left.icuStatus, right.icuStatus),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return AppWorkspaceStatusBadge(status: _icuStatus(item));
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: _IcuText.transfer,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(
                  left.transferStatus ?? left.nextStep,
                  right.transferStatus ?? right.nextStep,
                ),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return Text(
                _apiLabel(item.transferStatus ?? item.nextStep ?? ''),
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, IcuPatientSummary item) {
          final ThemeData theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _IcuPatientCell(item: item),
                SizedBox(height: theme.spacing.sm),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(status: _alertStatus(item)),
                    AppWorkspaceStatusBadge(status: _icuStatus(item)),
                    Text(
                      _joinDisplay(<String?>[
                        item.locationLabel,
                        _dateTimeLabel(context, item.admittedAt),
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

  Color? _rowColor(BuildContext context, IcuPatientSummary item) {
    if (!item.hasCriticalAlert) {
      return null;
    }
    return Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.22);
  }
}

class _IcuPatientCell extends StatelessWidget {
  const _IcuPatientCell({required this.item});

  final IcuPatientSummary item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          item.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          _joinDisplay(<String?>[
            item.patientId,
            item.displayId,
            item.encounterId,
          ]),
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

class _IcuDetailPanel extends ConsumerWidget {
  const _IcuDetailPanel({required this.state, required this.writeRequirement});

  final IcuWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final IcuPatientDetail? detail = state.selectedDetail;
    if (state.isRefreshingDetail && detail == null) {
      return const AppWorkspaceStatePanel.loading(
        title: 'Loading ICU stay',
        body: 'Loading observations, alerts, and transfer state.',
      );
    }
    if (detail == null) {
      return const AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: 'No ICU stay selected',
        body:
            'Select an ICU patient to review observations, orders, alerts, and transfer readiness.',
        icon: Icons.monitor_heart_outlined,
      );
    }

    final IcuPatientSummary summary = detail.summary;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: summary.displayTitle,
          patientNumber: summary.patientId ?? summary.displayId ?? summary.id,
          demographics: _joinDisplay(<String?>[
            _apiLabel(detail.patientGender ?? ''),
            _dateLabel(context, detail.patientDateOfBirth),
          ]),
          status: _icuStatus(summary),
          alerts: <AppWorkspaceStatus>[
            if (summary.hasCriticalAlert) _alertStatus(summary),
            if (summary.hasOpenTransfer)
              const AppWorkspaceStatus(
                label: _IcuText.transferPending,
                tone: AppWorkspaceStatusTone.warning,
              ),
            if (summary.isDischargePlanned)
              const AppWorkspaceStatus(
                label: _IcuText.dischargeReady,
                tone: AppWorkspaceStatusTone.success,
              ),
          ],
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: _IcuText.admission,
              value: summary.displayId ?? summary.admissionId,
              icon: Icons.tag_outlined,
            ),
            AppWorkspacePatientContextField(
              label: _IcuText.location,
              value: summary.locationLabel,
              icon: Icons.bed_outlined,
            ),
            AppWorkspacePatientContextField(
              label: _IcuText.facility,
              value: detail.facilityName ?? '',
              icon: Icons.domain_outlined,
            ),
            AppWorkspacePatientContextField(
              label: _IcuText.admitted,
              value: _dateTimeLabel(context, summary.admittedAt),
              icon: Icons.event_available_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _IcuActionPanel(
          detail: detail,
          referenceData: state.referenceData,
          writeRequirement: writeRequirement,
        ),
        SizedBox(height: theme.spacing.md),
        _IcuAlertPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _IcuObservationPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _IcuVitalTrendPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _IcuCarePanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _IcuTransferPanel(detail: detail),
      ],
    );
  }
}

Future<void> _openIcuDetailDialog(
  BuildContext context,
  WidgetRef ref,
  IcuWorkspaceState fallbackState,
  IcuPatientSummary summary,
  AccessRequirement writeRequirement,
) async {
  final IcuWorkspaceController controller = ref.read(
    icuWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectPatient(summary);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final IcuWorkspaceState state = _readIcuState(ref) ?? fallbackState;
  if (state.selectedDetail == null) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.icuStayDialogTitle),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      maxWidth: 980,
      content: _IcuDetailPanel(
        state: state,
        writeRequirement: writeRequirement,
      ),
    ),
  );
}

IcuWorkspaceState? _readIcuState(WidgetRef ref) {
  return ref
      .read(icuWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (IcuWorkspaceState state) => state, failure: (_) => null);
}

class _IcuActionPanel extends ConsumerWidget {
  const _IcuActionPanel({
    required this.detail,
    required this.referenceData,
    required this.writeRequirement,
  });

  final IcuPatientDetail detail;
  final IcuReferenceData referenceData;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final bool hasActiveStay = detail.canRecordIcuAction;
    final bool hasAlert = detail.latestAlert != null;

    return AppAccessActionGate(
      requirement: writeRequirement,
      builder: (BuildContext context, bool isAllowed) => AppActionPanel(
        title: 'Actions',
        actions: <AppActionItem>[
          AppActionItem(
            label: _IcuText.observation,
            leadingIcon: Icons.note_add_outlined,
            enabled: isAllowed && hasActiveStay,
            onPressed: () => _openObservationDialog(context),
          ),
          AppActionItem(
            label: _IcuText.vitals,
            leadingIcon: Icons.monitor_heart_outlined,
            enabled: isAllowed && detail.summary.encounterId != null,
            onPressed: () => _openVitalsDialog(context),
          ),
          AppActionItem(
            label: _IcuText.alert,
            leadingIcon: Icons.notification_important_outlined,
            enabled: isAllowed && hasActiveStay,
            onPressed: () => _openAlertDialog(context),
          ),
          AppActionItem(
            label: _IcuText.acknowledge,
            leadingIcon: Icons.done_all_outlined,
            enabled: isAllowed && hasAlert,
            onPressed: () => _confirmAction(
              context: context,
              title: 'Acknowledge alert',
              body:
                  'This clears the selected critical alert from the active ICU board.',
              actionLabel: _IcuText.acknowledge,
              onConfirmed: controller.acknowledgeLatestAlert,
            ),
          ),
          AppActionItem(
            label: _IcuText.round,
            leadingIcon: Icons.rate_review_outlined,
            enabled: isAllowed,
            onPressed: () => _openRoundDialog(context),
          ),
          AppActionItem(
            label: _IcuText.transfer,
            leadingIcon: Icons.compare_arrows_outlined,
            enabled: isAllowed,
            onPressed: () => _openTransferDialog(context, referenceData),
          ),
          AppActionItem(
            label: _IcuText.readiness,
            leadingIcon: Icons.fact_check_outlined,
            enabled: isAllowed,
            onPressed: () => _openReadinessDialog(context),
          ),
          AppActionItem(
            label: _IcuText.transferOut,
            leadingIcon: Icons.output_outlined,
            enabled: isAllowed && hasActiveStay,
            onPressed: () => _confirmAction(
              context: context,
              title: 'Transfer out of ICU',
              body:
                  'This ends the active ICU stay. Continue only after the receiving ward or discharge workflow is ready.',
              actionLabel: _IcuText.transferOut,
              onConfirmed: controller.transferOut,
            ),
          ),
        ],
        extraActions: <Widget>[
          AppReportActionButton.print(
            label: _IcuText.printSummary,
            onPressed: () async {
              await printFormTemplateDocument(
                ref: ref,
                context: context,
                title: 'ICU stay summary',
                subtitle: detail.summary.displayTitle,
                metadata: <PrintFormMetadataItem>[
                  PrintFormMetadataItem(
                    label: _IcuText.admission,
                    value:
                        detail.summary.displayId ?? detail.summary.admissionId,
                  ),
                  PrintFormMetadataItem(
                    label: _IcuText.location,
                    value: detail.summary.locationLabel,
                  ),
                ],
                bodyHtml: _icuSummaryHtml(context, detail),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IcuAlertPanel extends StatelessWidget {
  const _IcuAlertPanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final IcuCriticalAlertSummary summary = detail.alertSummary;
    return AppWorkspaceDetailPanel(
      title: 'Critical alerts',
      description: summary.total == 0
          ? 'No active ICU critical alerts.'
          : 'Highest severity: ${_apiLabel(summary.highestSeverity ?? '')}',
      child: _RecordList<IcuCriticalAlert>(
        items: detail.alerts,
        emptyLabel: 'No active alerts',
        icon: Icons.notification_important_outlined,
        titleBuilder: (IcuCriticalAlert item) => _joinDisplay(<String?>[
          _apiLabel(item.severity ?? ''),
          item.message,
        ]),
        subtitleBuilder: (BuildContext context, IcuCriticalAlert item) =>
            _dateTimeLabel(context, item.createdAt),
        statusBuilder: (IcuCriticalAlert item) => AppWorkspaceStatus(
          label: _apiLabel(item.severity ?? 'Alert'),
          tone: _severityTone(item.severity),
        ),
      ),
    );
  }
}

class _IcuObservationPanel extends StatelessWidget {
  const _IcuObservationPanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: 'Observations',
      description: 'Recent intensive observations for this ICU stay.',
      child: _RecordList<IcuObservation>(
        items: detail.observations,
        emptyLabel: 'No ICU observations recorded',
        icon: Icons.edit_note_outlined,
        titleBuilder: (IcuObservation item) => item.observation ?? '',
        subtitleBuilder: (BuildContext context, IcuObservation item) =>
            _dateTimeLabel(context, item.observedAt ?? item.createdAt),
      ),
    );
  }
}

class _IcuVitalTrendPanel extends StatelessWidget {
  const _IcuVitalTrendPanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: 'Vitals trend',
      description: 'Latest recorded vital values for the admission encounter.',
      child: _RecordList<IcuVitalSign>(
        items: detail.vitalSigns,
        emptyLabel: 'No vitals recorded',
        icon: Icons.monitor_heart_outlined,
        titleBuilder: (IcuVitalSign item) => _joinDisplay(<String?>[
          _apiLabel(item.vitalType),
          item.displayValue,
        ]),
        subtitleBuilder: (BuildContext context, IcuVitalSign item) =>
            _dateTimeLabel(context, item.recordedAt),
        statusBuilder: (IcuVitalSign item) => AppWorkspaceStatus(
          label: _apiLabel(item.vitalType),
          tone: _vitalTone(item),
        ),
      ),
    );
  }
}

class _IcuCarePanel extends StatelessWidget {
  const _IcuCarePanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final List<_CareItem> items = <_CareItem>[
      for (final IcuRoundNote item in detail.roundNotes)
        _CareItem(
          title: item.notes ?? 'Round note',
          subtitle: _dateTimeLabel(context, item.roundAt ?? item.createdAt),
          icon: Icons.rate_review_outlined,
        ),
      for (final IcuNursingNote item in detail.nursingNotes)
        _CareItem(
          title: item.note ?? 'Nursing note',
          subtitle: _joinDisplay(<String?>[
            item.nurseName,
            _dateTimeLabel(context, item.createdAt),
          ]),
          icon: Icons.assignment_outlined,
        ),
      for (final IcuMedicationTask item in detail.medicationTasks)
        _CareItem(
          title: item.medicationLabel ?? item.note ?? 'Medication task',
          subtitle: _joinDisplay(<String?>[
            _apiLabel(item.status ?? ''),
            item.dose,
            item.unit,
            item.route,
            item.frequency,
            _dateTimeLabel(context, item.scheduledAt),
          ]),
          icon: Icons.medication_outlined,
        ),
      for (final IcuMedicationAdministration item
          in detail.medicationAdministrations)
        _CareItem(
          title: _joinDisplay(<String?>['Dose', item.dose, item.unit]),
          subtitle: _joinDisplay(<String?>[
            _apiLabel(item.route ?? ''),
            _dateTimeLabel(context, item.administeredAt),
          ]),
          icon: Icons.medication_liquid_outlined,
        ),
    ];

    return AppWorkspaceDetailPanel(
      title: 'Rounds, nursing, and orders',
      description: 'Recent care notes and medication tasks linked to IPD.',
      child: _RecordList<_CareItem>(
        items: items,
        emptyLabel: 'No care tasks recorded',
        icon: Icons.playlist_add_check_outlined,
        titleBuilder: (_CareItem item) => item.title,
        subtitleBuilder: (_, _CareItem item) => item.subtitle,
        iconBuilder: (_CareItem item) => item.icon,
      ),
    );
  }
}

class _IcuTransferPanel extends StatelessWidget {
  const _IcuTransferPanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final List<_CareItem> items = <_CareItem>[
      for (final IcuTransferRequest item in detail.transferRequests)
        _CareItem(
          title: _joinDisplay(<String?>[
            'Transfer',
            _apiLabel(item.status ?? ''),
          ]),
          subtitle: _joinDisplay(<String?>[
            item.fromWardName,
            item.toWardName,
            _dateTimeLabel(context, item.requestedAt),
          ]),
          icon: Icons.compare_arrows_outlined,
        ),
      for (final IcuDischargeSummary item in detail.dischargeSummaries)
        _CareItem(
          title: _joinDisplay(<String?>[
            'Discharge',
            _apiLabel(item.status ?? ''),
          ]),
          subtitle: _joinDisplay(<String?>[
            item.summary,
            _dateTimeLabel(context, item.dischargedAt ?? item.updatedAt),
          ]),
          icon: Icons.fact_check_outlined,
        ),
      for (final IcuStaySummary item in detail.recentStays)
        _CareItem(
          title: item.isActive ? 'Active ICU stay' : 'Previous ICU stay',
          subtitle: _joinDisplay(<String?>[
            item.displayId ?? item.id,
            _dateTimeLabel(context, item.startedAt),
            item.endedAt == null
                ? null
                : 'Ended ${_dateTimeLabel(context, item.endedAt)}',
          ]),
          icon: Icons.bed_outlined,
        ),
    ];

    return AppWorkspaceDetailPanel(
      title: 'Transfer and readiness',
      description: 'ICU stay movement, planned discharge, and handoff state.',
      child: _RecordList<_CareItem>(
        items: items,
        emptyLabel: 'No transfer or discharge readiness records',
        icon: Icons.compare_arrows_outlined,
        titleBuilder: (_CareItem item) => item.title,
        subtitleBuilder: (_, _CareItem item) => item.subtitle,
        iconBuilder: (_CareItem item) => item.icon,
      ),
    );
  }
}

class _RecordList<T> extends StatelessWidget {
  const _RecordList({
    required this.items,
    required this.emptyLabel,
    required this.titleBuilder,
    required this.subtitleBuilder,
    this.statusBuilder,
    this.iconBuilder,
    this.icon,
  });

  final List<T> items;
  final String emptyLabel;
  final String Function(T item) titleBuilder;
  final String Function(BuildContext context, T item) subtitleBuilder;
  final AppWorkspaceStatus Function(T item)? statusBuilder;
  final IconData Function(T item)? iconBuilder;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < items.length; index += 1) ...<Widget>[
          if (index > 0) const Divider(height: 1),
          _RecordRow<T>(
            item: items[index],
            titleBuilder: titleBuilder,
            subtitleBuilder: subtitleBuilder,
            statusBuilder: statusBuilder,
            icon: iconBuilder?.call(items[index]) ?? icon,
          ),
        ],
      ],
    );
  }
}

class _RecordRow<T> extends StatelessWidget {
  const _RecordRow({
    required this.item,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.statusBuilder,
    this.icon,
  });

  final T item;
  final String Function(T item) titleBuilder;
  final String Function(BuildContext context, T item) subtitleBuilder;
  final AppWorkspaceStatus Function(T item)? statusBuilder;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppWorkspaceStatus? status = statusBuilder?.call(item);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon ?? Icons.description_outlined,
            size: theme.appTokens.listIconSize,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  titleBuilder(item),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  subtitleBuilder(context, item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (status != null) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            Flexible(child: AppWorkspaceStatusBadge(status: status)),
          ],
        ],
      ),
    );
  }
}

class _CareItem {
  const _CareItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _ObservationDialog extends ConsumerStatefulWidget {
  const _ObservationDialog();

  @override
  ConsumerState<_ObservationDialog> createState() => _ObservationDialogState();
}

class _ObservationDialogState extends ConsumerState<_ObservationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _observationController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _observationController = TextEditingController();
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text(_IcuText.recordIcuObservation),
      icon: const Icon(Icons.note_add_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _observationController,
              labelText: _IcuText.observation,
              enabled: !_isSaving,
              maxLines: 5,
              isRequired: true,
              validator: AppValidators.requiredText(
                context.l10n.validationRequired,
              ),
            ),
          ],
        ),
      ),
      actions: _dialogActions(context, 'Record', _isSaving, _submit),
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
        .read(icuWorkspaceControllerProvider.notifier)
        .recordObservation(observation: _observationController.text.trim());
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

class _VitalsDialog extends ConsumerStatefulWidget {
  const _VitalsDialog();

  @override
  ConsumerState<_VitalsDialog> createState() => _VitalsDialogState();
}

class _VitalsDialogState extends ConsumerState<_VitalsDialog> {
  late final TextEditingController _temperatureController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenController;
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
    _oxygenController = TextEditingController();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text(_IcuText.updateVitals),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 780,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppFormSection(
            title: context.l10n.patientsVitalsSectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppVitalsForm(
                temperatureController: _temperatureController,
                systolicController: _systolicController,
                diastolicController: _diastolicController,
                heartRateController: _heartRateController,
                respiratoryRateController: _respiratoryRateController,
                oxygenSaturationController: _oxygenController,
                temperatureLabel: context.l10n.patientsTemperatureLabel,
                systolicLabel: context.l10n.patientsSystolicLabel,
                diastolicLabel: context.l10n.patientsDiastolicLabel,
                heartRateLabel: context.l10n.patientsHeartRateLabel,
                respiratoryRateLabel: context.l10n.patientsRespiratoryRateLabel,
                oxygenSaturationLabel:
                    context.l10n.patientsOxygenSaturationLabel,
                bloodPressureLabel: context.l10n.patientsBloodPressureLabel,
                unitLabel: context.l10n.patientsVitalUnitLabel,
                enabled: !_isSaving,
              ),
            ],
          ),
        ],
      ),
      actions: _dialogActions(context, 'Update', _isSaving, _submit),
    );
  }

  Future<void> _submit() async {
    final IcuVitalsInput input = IcuVitalsInput(
      temperature: normalizeCurrencyAmount(_temperatureController.text),
      systolic: normalizeCurrencyAmount(_systolicController.text),
      diastolic: normalizeCurrencyAmount(_diastolicController.text),
      heartRate: normalizeCurrencyAmount(_heartRateController.text),
      respiratoryRate: normalizeCurrencyAmount(_respiratoryRateController.text),
      oxygenSaturation: normalizeCurrencyAmount(_oxygenController.text),
      recordedAt: DateTime.now(),
    );
    if (!input.hasAnyValue) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .recordVitals(input);
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

class _CriticalAlertDialog extends ConsumerStatefulWidget {
  const _CriticalAlertDialog();

  @override
  ConsumerState<_CriticalAlertDialog> createState() =>
      _CriticalAlertDialogState();
}

class _CriticalAlertDialogState extends ConsumerState<_CriticalAlertDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _messageController;
  String _severity = 'HIGH';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text(_IcuText.addCriticalAlert),
      icon: const Icon(Icons.notification_important_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _severity,
              labelText: 'Severity',
              enabled: !_isSaving,
              options: _statusOptions(<String>[
                'LOW',
                'MEDIUM',
                'HIGH',
                'CRITICAL',
              ]),
              onChanged: (String? value) {
                setState(() => _severity = value ?? _severity);
              },
            ),
            AppTextField(
              controller: _messageController,
              labelText: 'Alert message',
              enabled: !_isSaving,
              maxLines: 3,
              isRequired: true,
              validator: AppValidators.requiredText(
                context.l10n.validationRequired,
              ),
            ),
          ],
        ),
      ),
      actions: _dialogActions(context, 'Add alert', _isSaving, _submit),
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
        .read(icuWorkspaceControllerProvider.notifier)
        .addCriticalAlert(
          severity: _severity,
          message: _messageController.text.trim(),
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

class _TransferRequestDialog extends ConsumerStatefulWidget {
  const _TransferRequestDialog({required this.referenceData});

  final IcuReferenceData referenceData;

  @override
  ConsumerState<_TransferRequestDialog> createState() =>
      _TransferRequestDialogState();
}

class _TransferRequestDialogState
    extends ConsumerState<_TransferRequestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _wardController;
  String? _wardId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _wardController = TextEditingController();
  }

  @override
  void dispose() {
    _wardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<IcuWardOption> wards = widget.referenceData.wards;
    return AppDialog(
      title: const Text(_IcuText.requestTransfer),
      icon: const Icon(Icons.compare_arrows_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            if (wards.isEmpty)
              AppTextField(
                controller: _wardController,
                labelText: 'Target ward ID',
                enabled: !_isSaving,
                isRequired: true,
                validator: AppValidators.requiredText(
                  context.l10n.validationRequired,
                ),
              )
            else
              AppSelectField<String>.searchable(
                value: _wardId,
                labelText: 'Target ward',
                enabled: !_isSaving,
                options: <AppSelectOption<String>>[
                  for (final IcuWardOption ward in wards)
                    AppSelectOption<String>(
                      value: ward.id,
                      label: _joinDisplay(<String?>[
                        ward.displayTitle,
                        _apiLabel(ward.wardType ?? ''),
                      ]),
                    ),
                ],
                onChanged: (String? value) => setState(() => _wardId = value),
                validator: (String? value) {
                  if ((value ?? '').trim().isEmpty) {
                    return context.l10n.validationRequired;
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
      actions: _dialogActions(context, 'Request', _isSaving, _submit),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String toWardId = _wardId ?? _wardController.text.trim();
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .requestTransfer(toWardId: toWardId);
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

class _ReadinessDialog extends ConsumerStatefulWidget {
  const _ReadinessDialog();

  @override
  ConsumerState<_ReadinessDialog> createState() => _ReadinessDialogState();
}

class _ReadinessDialogState extends ConsumerState<_ReadinessDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _summaryController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text(_IcuText.markDischargeReadiness),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          description:
              'This records a planned discharge readiness note and keeps the patient in the IPD discharge workflow.',
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _summaryController,
              labelText: 'Readiness note',
              enabled: !_isSaving,
              maxLines: 5,
              isRequired: true,
              validator: AppValidators.requiredText(
                context.l10n.validationRequired,
              ),
            ),
          ],
        ),
      ),
      actions: _dialogActions(context, 'Mark ready', _isSaving, _submit),
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
        .read(icuWorkspaceControllerProvider.notifier)
        .markDischargeReady(summary: _summaryController.text.trim());
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

Future<void> _openObservationDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ObservationDialog(),
    ),
  );
}

Future<void> _openVitalsDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _VitalsDialog(),
    ),
  );
}

Future<void> _openAlertDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CriticalAlertDialog(),
    ),
  );
}

Future<void> _openRoundDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: 'Add ICU round note',
        label: _IcuText.roundNote,
        submitLabel: 'Add note',
        icon: const Icon(Icons.rate_review_outlined),
        maxLines: 4,
        onSubmit: (String note) {
          return ProviderScope.containerOf(context, listen: false)
              .read(icuWorkspaceControllerProvider.notifier)
              .addRoundNote(notes: note);
        },
      ),
    ),
  );
}

Future<void> _openTransferDialog(
  BuildContext context,
  IcuReferenceData referenceData,
) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferRequestDialog(referenceData: referenceData),
    ),
  );
}

Future<void> _openReadinessDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReadinessDialog(),
    ),
  );
}

Future<void> _confirmAction({
  required BuildContext context,
  required String title,
  required String body,
  required String actionLabel,
  required Future<AppFailure?> Function() onConfirmed,
}) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppConfirmActionDialog(
        title: title,
        body: body,
        submitLabel: actionLabel,
        icon: const Icon(Icons.warning_amber_outlined),
        onConfirm: onConfirmed,
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
    ).showSnackBar(const SnackBar(content: Text(_IcuText.changesSaved)));
  }
}

List<AppSelectOption<IcuBoardScope>> _scopeOptions() {
  return const <AppSelectOption<IcuBoardScope>>[
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.active,
      label: _IcuText.activeIcu,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.critical,
      label: _IcuText.criticalAlerts,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.transfer,
      label: _IcuText.transferPending,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.discharge,
      label: _IcuText.dischargeReady,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.ended,
      label: _IcuText.endedStays,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.all,
      label: _IcuText.allIcu,
    ),
  ];
}

const String _icuScopeFilterKey = 'scope';

AppSearchBarFilterValue _icuFilterValue(IcuBoardQuery query) {
  if (query.scope == IcuBoardScope.active) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_icuScopeFilterKey: query.scope.name},
  );
}

IcuBoardScope _icuScopeFromFilter(String? value) {
  for (final IcuBoardScope scope in IcuBoardScope.values) {
    if (scope.name == value) {
      return scope;
    }
  }
  return IcuBoardScope.active;
}

List<AppSearchBarFilterChoice> _icuScopeFilterChoices() {
  return <AppSearchBarFilterChoice>[
    for (final AppSelectOption<IcuBoardScope> option in _scopeOptions())
      if (option.value != IcuBoardScope.active)
        AppSearchBarFilterChoice(
          value: option.value.name,
          label: option.label,
          icon: Icons.filter_list,
        ),
  ];
}

abstract final class _IcuText {
  static const String acknowledge = 'Acknowledge';
  static const String activeIcu = 'Active ICU';
  static const String addCriticalAlert = 'Add critical alert';
  static const String admitted = 'Admitted';
  static const String admission = 'Admission';
  static const String alert = 'Alert';
  static const String allIcu = 'All ICU';
  static const String bed = 'Bed';
  static const String changesSaved = 'ICU changes saved.';
  static const String criticalAlerts = 'Critical alerts';
  static const String dischargeReady = 'Discharge ready';
  static const String endedStays = 'Ended stays';
  static const String facility = 'Facility';
  static const String location = 'Location';
  static const String markDischargeReadiness = 'Mark discharge readiness';
  static const String observation = 'Observation';
  static const String printSummary = 'Print summary';
  static const String readiness = 'Readiness';
  static const String recordIcuObservation = 'Record ICU observation';
  static const String requestTransfer = 'Request transfer';
  static const String round = 'Round';
  static const String roundNote = 'Round note';
  static const String searchHint = 'Search patient, admission, bed, or alert';
  static const String transfer = 'Transfer';
  static const String transferOut = 'Transfer out';
  static const String transferPending = 'Transfer pending';
  static const String transfers = 'Transfers';
  static const String updateVitals = 'Update vitals';
  static const String vitals = 'Vitals';
}

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

AppWorkspaceStatus _icuStatus(IcuPatientSummary item) {
  final String value =
      item.icuStatus ?? item.stage ?? item.admissionStatus ?? '';
  return AppWorkspaceStatus(label: _apiLabel(value), tone: _statusTone(value));
}

AppWorkspaceStatus _alertStatus(IcuPatientSummary item) {
  final String severity = item.criticalSeverity ?? 'Stable';
  return AppWorkspaceStatus(
    label: item.hasCriticalAlert ? _apiLabel(severity) : 'No alert',
    tone: item.hasCriticalAlert
        ? _severityTone(severity)
        : AppWorkspaceStatusTone.success,
  );
}

AppWorkspaceStatusTone _statusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'ACTIVE' ||
    'ADMITTED_IN_BED' ||
    'IN_PROGRESS' => AppWorkspaceStatusTone.info,
    'DISCHARGE_PLANNED' ||
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' ||
    'REQUESTED' ||
    'APPROVED' => AppWorkspaceStatusTone.warning,
    'ENDED' || 'DISCHARGED' || 'COMPLETED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _severityTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'CRITICAL' || 'HIGH' => AppWorkspaceStatusTone.error,
    'MEDIUM' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _vitalTone(IcuVitalSign item) {
  final num? numericValue = num.tryParse(item.value ?? '');
  return switch (item.vitalType) {
    'OXYGEN_SATURATION' when numericValue != null && numericValue < 92 =>
      AppWorkspaceStatusTone.error,
    'HEART_RATE'
        when numericValue != null &&
            (numericValue < 50 || numericValue > 120) =>
      AppWorkspaceStatusTone.warning,
    'RESPIRATORY_RATE'
        when numericValue != null && (numericValue < 10 || numericValue > 28) =>
      AppWorkspaceStatusTone.warning,
    'TEMPERATURE'
        when numericValue != null && (numericValue < 35 || numericValue > 39) =>
      AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.info,
  };
}

String _countLabel(BuildContext context, int value) {
  return AppFormatters.compactNumber(value, Localizations.localeOf(context));
}

int _pageTotal<T>(AppPage<T> page) => page.totalItemCount ?? page.items.length;

String _pageLabel(BuildContext context, AppPage<IcuPatientSummary> page) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }
  final int from = page.request.pageIndex * page.request.pageSize + 1;
  final int to = (from + page.items.length - 1).clamp(from, total);
  return context.l10n.opdPageLabel(from, to, total);
}

String _dateLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return '';
  }
  return AppFormatters.mediumDate(value, Localizations.localeOf(context));
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return '';
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
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String _icuSummaryHtml(BuildContext context, IcuPatientDetail detail) {
  final StringBuffer buffer = StringBuffer()
    ..write(
      PrintFormTemplate.section(
        title: 'Alerts',
        bodyHtml: _alertHtml(detail.alerts),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: 'Observations',
        bodyHtml: _observationHtml(detail.observations),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: 'Vitals',
        bodyHtml: _vitalsHtml(detail.vitalSigns),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: 'Transfer and readiness',
        bodyHtml: _readinessHtml(detail),
      ),
    );
  return buffer.toString();
}

String _alertHtml(List<IcuCriticalAlert> alerts) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuCriticalAlert alert in alerts)
      _joinDisplay(<String?>[_apiLabel(alert.severity ?? ''), alert.message]),
  ], emptyText: 'No active alerts.');
}

String _observationHtml(List<IcuObservation> observations) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuObservation observation in observations)
      observation.observation ?? '',
  ], emptyText: 'No observations recorded.');
}

String _vitalsHtml(List<IcuVitalSign> vitals) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuVitalSign vital in vitals)
      _joinDisplay(<String?>[_apiLabel(vital.vitalType), vital.displayValue]),
  ], emptyText: 'No vitals recorded.');
}

String _readinessHtml(IcuPatientDetail detail) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuTransferRequest transfer in detail.transferRequests)
      _joinDisplay(<String?>[
        'Transfer',
        _apiLabel(transfer.status ?? ''),
        transfer.toWardName,
      ]),
    for (final IcuDischargeSummary discharge in detail.dischargeSummaries)
      _joinDisplay(<String?>[
        'Discharge',
        _apiLabel(discharge.status ?? ''),
        discharge.summary,
      ]),
  ], emptyText: 'No transfer or discharge readiness records.');
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

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
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class EmergencyWorkspacePage extends ConsumerWidget {
  const EmergencyWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<EmergencyWorkspaceState>> state = ref.watch(
      emergencyWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<EmergencyWorkspaceState>(
      value: state,
      loadingTitle: 'Loading emergency board',
      loadingBody: 'Loading emergency cases, triage state, and ambulance work.',
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(emergencyWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, EmergencyWorkspaceState data) {
        return _EmergencyWorkspaceContent(state: data);
      },
    );
  }
}

class _EmergencyWorkspaceContent extends ConsumerStatefulWidget {
  const _EmergencyWorkspaceContent({required this.state});

  final EmergencyWorkspaceState state;

  @override
  ConsumerState<_EmergencyWorkspaceContent> createState() =>
      _EmergencyWorkspaceContentState();
}

class _EmergencyWorkspaceContentState
    extends ConsumerState<_EmergencyWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.emergencyWrite],
  );

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
  }

  @override
  void didUpdateWidget(covariant _EmergencyWorkspaceContent oldWidget) {
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
    final EmergencyWorkspaceState state = widget.state;
    final EmergencyWorkspaceController controller = ref.read(
      emergencyWorkspaceControllerProvider.notifier,
    );

    return AppWorkspace(
      title: 'Emergency',
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isSaving ? 'Saving' : 'Live sync',
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
      ),
      primaryAction: AppAccessActionGate(
        requirement: _writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return AppButton.primary(
            label: 'Quick arrival',
            leadingIcon: Icons.add_circle_outline,
            enabled: isAllowed,
            onPressed: () => _openQuickArrivalDialog(context),
          );
        },
      ),
      secondaryActions: <Widget>[
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: 'Refresh emergency board',
          tooltip: 'Refresh',
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
        AppWorkspaceSummaryCard(
          label: 'Active',
          value: _countLabel(context, state.activeCount),
          icon: Icons.emergency_outlined,
          tone: AppWorkspaceStatusTone.info,
          compact: true,
          onPressed: () => controller.applyScope(EmergencyBoardScope.active),
        ),
        AppWorkspaceSummaryCard(
          label: 'Critical',
          value: _countLabel(context, state.criticalCount),
          icon: Icons.priority_high_outlined,
          tone: AppWorkspaceStatusTone.error,
          compact: true,
          onPressed: () => controller.applyScope(EmergencyBoardScope.critical),
        ),
        AppWorkspaceSummaryCard(
          label: 'Ambulance',
          value: _countLabel(context, state.ambulanceCount),
          icon: Icons.airport_shuttle_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () => controller.applyScope(EmergencyBoardScope.ambulance),
        ),
        AppWorkspaceSummaryCard(
          label: 'Handoff',
          value: _countLabel(context, state.handoffCount),
          icon: Icons.output_outlined,
          tone: AppWorkspaceStatusTone.success,
          compact: true,
          onPressed: () => controller.applyScope(EmergencyBoardScope.handoff),
        ),
      ],
      filters: AppWorkspaceFilterBar(
        semanticLabel: 'Emergency board filters',
        expandSearch: true,
        search: AppSearchBar(
          controller: _searchController,
          semanticLabel: 'Search emergency cases',
          hintText: 'Search patient, case, ambulance, or status',
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
        ),
        filters: <Widget>[
          AppSelectField<EmergencyBoardScope>(
            value: state.query.scope,
            labelText: 'Board scope',
            options: _scopeOptions(),
            onChanged: (EmergencyBoardScope? value) {
              if (value != null) {
                controller.applyScope(value);
              }
            },
          ),
        ],
      ),
      body: _EmergencyBoardPanel(state: state),
      detail: _EmergencyDetailPanel(
        state: state,
        writeRequirement: _writeRequirement,
      ),
    );
  }

  Future<void> _openQuickArrivalDialog(BuildContext context) async {
    final EmergencyQuickArrivalInput? input =
        await showAppDialog<EmergencyQuickArrivalInput>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _QuickArrivalDialog(),
        );
    if (input == null || !context.mounted) {
      return;
    }

    final AppFailure? failure = await ref
        .read(emergencyWorkspaceControllerProvider.notifier)
        .createQuickArrival(input);
    if (context.mounted) {
      _showFailureIfNeeded(context, failure, successMessage: 'Arrival opened');
    }
  }
}

class _EmergencyBoardPanel extends ConsumerWidget {
  const _EmergencyBoardPanel({required this.state});

  final EmergencyWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EmergencyWorkspaceController controller = ref.read(
      emergencyWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: 'Emergency board',
      description: 'Open cases remain actionable without billing checkpoints.',
      child: AppPaginatedListTable<EmergencyCaseSummary>(
        page: state.board,
        isLoading: state.isRefreshingBoard,
        previousPageLabel: 'Previous emergency cases',
        nextPageLabel: 'Next emergency cases',
        pageLabelBuilder: (AppPage<EmergencyCaseSummary> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: controller.changePage,
        onRowSelected: controller.selectCase,
        rowColorBuilder: _rowColor,
        emptyBuilder: (_) => const AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: 'No emergency cases',
          body: 'Emergency arrivals and ambulance calls will appear here.',
          icon: Icons.emergency_outlined,
        ),
        columns: <AppListTableColumn<EmergencyCaseSummary>>[
          AppListTableColumn<EmergencyCaseSummary>(
            label: 'Patient',
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return _EmergencyCaseCell(item: item);
            },
          ),
          AppListTableColumn<EmergencyCaseSummary>(
            label: 'Priority',
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return AppWorkspaceStatusBadge(status: _severityStatus(item));
            },
          ),
          AppListTableColumn<EmergencyCaseSummary>(
            label: 'Arrival',
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return Text(_dateTimeLabel(context, item.createdAt));
            },
          ),
          AppListTableColumn<EmergencyCaseSummary>(
            label: 'Response',
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return AppWorkspaceStatusBadge(status: _responseStatus(item));
            },
          ),
          AppListTableColumn<EmergencyCaseSummary>(
            label: 'Location',
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return Text(item.currentLocation);
            },
          ),
          AppListTableColumn<EmergencyCaseSummary>(
            label: 'Next',
            cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
              return Text(item.nextAction);
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, EmergencyCaseSummary item) {
          final ThemeData theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _EmergencyCaseCell(item: item),
                SizedBox(height: theme.spacing.sm),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(status: _severityStatus(item)),
                    AppWorkspaceStatusBadge(status: _responseStatus(item)),
                    Text(
                      _joinDisplay(<String?>[
                        item.currentLocation,
                        _dateTimeLabel(context, item.createdAt),
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

  Color? _rowColor(BuildContext context, EmergencyCaseSummary item) {
    if (!item.isCritical) {
      return null;
    }
    return Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.20);
  }
}

class _EmergencyCaseCell extends StatelessWidget {
  const _EmergencyCaseCell({required this.item});

  final EmergencyCaseSummary item;

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
            item.patientDisplayId,
            item.caseLabel,
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

class _EmergencyDetailPanel extends ConsumerWidget {
  const _EmergencyDetailPanel({
    required this.state,
    required this.writeRequirement,
  });

  final EmergencyWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EmergencyCaseDetail? detail = state.selectedDetail;
    if (state.isRefreshingDetail && detail == null) {
      return const AppWorkspaceStatePanel.loading(
        title: 'Loading emergency case',
        body: 'Loading triage, response, and ambulance activity.',
      );
    }
    if (detail == null) {
      return const AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: 'No case selected',
        body:
            'Select an emergency case to record triage, ambulance activity, response, or handoff.',
        icon: Icons.emergency_outlined,
      );
    }

    final EmergencyCaseSummary summary = detail.summary;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: summary.displayTitle,
          patientNumber: summary.patientDisplayId ?? summary.patientId ?? '',
          demographics: summary.patientLabel,
          status: _caseStatus(summary),
          alerts: <AppWorkspaceStatus>[
            _severityStatus(summary),
            if (detail.latestTriage != null)
              _triageStatus(detail.latestTriage!.triageLevel),
            if (summary.isOpen)
              const AppWorkspaceStatus(
                label: 'Care before billing',
                tone: AppWorkspaceStatusTone.info,
                icon: Icons.bolt_outlined,
              ),
          ],
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: 'Case',
              value: summary.caseLabel,
              icon: Icons.tag_outlined,
            ),
            AppWorkspacePatientContextField(
              label: 'Arrival',
              value: _dateTimeLabel(context, summary.createdAt),
              icon: Icons.event_available_outlined,
            ),
            AppWorkspacePatientContextField(
              label: 'Facility',
              value: summary.facilityLabel ?? '',
              icon: Icons.domain_outlined,
            ),
            AppWorkspacePatientContextField(
              label: 'Location',
              value: summary.currentLocation,
              icon: Icons.place_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _EmergencyActionPanel(
          detail: detail,
          referenceData: state.referenceData,
          writeRequirement: writeRequirement,
        ),
        SizedBox(height: theme.spacing.md),
        _EmergencyTimelinePanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _AmbulancePanel(detail: detail),
      ],
    );
  }
}

class _EmergencyActionPanel extends ConsumerWidget {
  const _EmergencyActionPanel({
    required this.detail,
    required this.referenceData,
    required this.writeRequirement,
  });

  final EmergencyCaseDetail detail;
  final EmergencyReferenceData referenceData;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EmergencyWorkspaceController controller = ref.read(
      emergencyWorkspaceControllerProvider.notifier,
    );
    final bool hasDispatch = detail.latestDispatch != null;
    final bool hasTrip = detail.activeTrip != null;
    final bool canStartTrip =
        !hasTrip &&
        (detail.latestDispatch?.ambulanceId != null ||
            referenceData.availableAmbulances.isNotEmpty);

    return AppWorkspaceDetailPanel(
      title: 'Actions',
      child: AppAccessActionGate(
        requirement: writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return Wrap(
            spacing: Theme.of(context).spacing.xs,
            runSpacing: Theme.of(context).spacing.xs,
            children: <Widget>[
              _actionButton(
                label: 'Priority',
                icon: Icons.priority_high_outlined,
                enabled: isAllowed && detail.summary.isOpen,
                onPressed: () => _openPriorityDialog(context),
              ),
              _actionButton(
                label: 'Triage',
                icon: Icons.monitor_heart_outlined,
                enabled: isAllowed && detail.summary.isOpen,
                onPressed: () => _openTriageDialog(context),
              ),
              _actionButton(
                label: 'Response',
                icon: Icons.medical_services_outlined,
                enabled: isAllowed && detail.summary.isOpen,
                onPressed: () => _openResponseDialog(context),
              ),
              _actionButton(
                label: 'Dispatch',
                icon: Icons.airport_shuttle_outlined,
                enabled: isAllowed && detail.summary.isOpen,
                onPressed: () => _openDispatchDialog(context, referenceData),
              ),
              _actionButton(
                label: 'Dispatch status',
                icon: Icons.route_outlined,
                enabled: isAllowed && detail.summary.isOpen && hasDispatch,
                onPressed: () => _openDispatchStatusDialog(context),
              ),
              _actionButton(
                label: 'Start trip',
                icon: Icons.play_arrow_outlined,
                enabled: isAllowed && detail.summary.isOpen && canStartTrip,
                onPressed: () => _startTrip(context, referenceData),
              ),
              _actionButton(
                label: 'Complete trip',
                icon: Icons.flag_outlined,
                enabled: isAllowed && hasTrip,
                onPressed: () => _confirmAction(
                  context: context,
                  title: 'Complete ambulance trip',
                  body:
                      'This records ambulance arrival for the active emergency trip.',
                  actionLabel: 'Complete trip',
                  onConfirmed: controller.completeTrip,
                ),
              ),
              _actionButton(
                label: 'Handoff',
                icon: Icons.output_outlined,
                enabled: isAllowed && detail.summary.isOpen,
                onPressed: () => _openHandoffDialog(context),
              ),
              AppReportActionButton.print(
                label: 'Print summary',
                onPressed: () async {
                  await printFormTemplateDocument(
                    ref: ref,
                    context: context,
                    title: 'Emergency summary',
                    subtitle: detail.summary.displayTitle,
                    metadata: <PrintFormMetadataItem>[
                      PrintFormMetadataItem(
                        label: 'Case',
                        value: detail.summary.caseLabel,
                      ),
                      PrintFormMetadataItem(
                        label: 'Severity',
                        value: _apiLabel(detail.summary.severity ?? ''),
                      ),
                      PrintFormMetadataItem(
                        label: 'Status',
                        value: _apiLabel(detail.summary.status ?? ''),
                      ),
                      PrintFormMetadataItem(
                        label: 'Arrival',
                        value: _dateTimeLabel(
                          context,
                          detail.summary.createdAt,
                        ),
                      ),
                    ],
                    bodyHtml: _emergencySummaryHtml(context, detail),
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

  Future<void> _openPriorityDialog(BuildContext context) async {
    final String? severity = await showAppDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PriorityDialog(initialSeverity: detail.summary.severity),
    );
    if (severity == null || !context.mounted) {
      return;
    }

    final AppFailure? failure = await _controller(
      context,
    ).updatePriority(severity);
    if (context.mounted) {
      _showFailureIfNeeded(
        context,
        failure,
        successMessage: 'Priority updated',
      );
    }
  }

  Future<void> _openTriageDialog(BuildContext context) async {
    final _TriageInput? input = await showAppDialog<_TriageInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TriageDialog(latestTriage: detail.latestTriage),
    );
    if (input == null || !context.mounted) {
      return;
    }

    final AppFailure? failure = await _controller(
      context,
    ).recordTriage(triageLevel: input.triageLevel, notes: input.notes);
    if (context.mounted) {
      _showFailureIfNeeded(context, failure, successMessage: 'Triage recorded');
    }
  }

  Future<void> _openResponseDialog(BuildContext context) async {
    final String? notes = await showAppDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ResponseDialog(),
    );
    if (notes == null || !context.mounted) {
      return;
    }

    final AppFailure? failure = await _controller(
      context,
    ).markResponse(notes: notes);
    if (context.mounted) {
      _showFailureIfNeeded(context, failure, successMessage: 'Response marked');
    }
  }

  Future<void> _openDispatchDialog(
    BuildContext context,
    EmergencyReferenceData referenceData,
  ) async {
    final _DispatchInput? input = await showAppDialog<_DispatchInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DispatchDialog(referenceData: referenceData),
    );
    if (input == null || !context.mounted) {
      return;
    }

    final AppFailure? failure = await _controller(
      context,
    ).dispatchAmbulance(ambulanceId: input.ambulanceId, status: input.status);
    if (context.mounted) {
      _showFailureIfNeeded(
        context,
        failure,
        successMessage: 'Ambulance dispatched',
      );
    }
  }

  Future<void> _openDispatchStatusDialog(BuildContext context) async {
    final String? status = await showAppDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _DispatchStatusDialog(initialStatus: detail.latestDispatch?.status),
    );
    if (status == null || !context.mounted) {
      return;
    }

    final AppFailure? failure = await _controller(
      context,
    ).updateLatestDispatchStatus(status);
    if (context.mounted) {
      _showFailureIfNeeded(
        context,
        failure,
        successMessage: 'Dispatch status updated',
      );
    }
  }

  Future<void> _startTrip(
    BuildContext context,
    EmergencyReferenceData referenceData,
  ) async {
    String? ambulanceId = detail.latestDispatch?.ambulanceId;
    if (ambulanceId == null && referenceData.availableAmbulances.length == 1) {
      ambulanceId = referenceData.availableAmbulances.first.id;
    }
    if (ambulanceId == null) {
      final _DispatchInput? input = await showAppDialog<_DispatchInput>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DispatchDialog(
          referenceData: referenceData,
          title: 'Select ambulance',
          submitLabel: 'Start trip',
          defaultStatus: 'EN_ROUTE',
        ),
      );
      if (input == null) {
        return;
      }
      ambulanceId = input.ambulanceId;
    }
    if (!context.mounted) {
      return;
    }

    final AppFailure? failure = await _controller(
      context,
    ).startAmbulanceTrip(ambulanceId: ambulanceId);
    if (context.mounted) {
      _showFailureIfNeeded(context, failure, successMessage: 'Trip started');
    }
  }

  Future<void> _openHandoffDialog(BuildContext context) async {
    final _HandoffInput? input = await showAppDialog<_HandoffInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _HandoffDialog(),
    );
    if (input == null || !context.mounted) {
      return;
    }

    final AppFailure? failure = await _controller(context).handoff(
      destination: input.destination,
      notes: input.notes,
      closeCase: input.closeCase,
    );
    if (context.mounted) {
      _showFailureIfNeeded(
        context,
        failure,
        successMessage: 'Handoff recorded',
      );
    }
  }

  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String body,
    required String actionLabel,
    required Future<AppFailure?> Function() onConfirmed,
  }) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ConfirmDialog(title: title, body: body, actionLabel: actionLabel),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final AppFailure? failure = await onConfirmed();
    if (context.mounted) {
      _showFailureIfNeeded(
        context,
        failure,
        successMessage: '$actionLabel done',
      );
    }
  }

  EmergencyWorkspaceController _controller(BuildContext context) {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(emergencyWorkspaceControllerProvider.notifier);
  }
}

class _EmergencyTimelinePanel extends StatelessWidget {
  const _EmergencyTimelinePanel({required this.detail});

  final EmergencyCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final List<_TimelineItem> items =
        <_TimelineItem>[
          for (final EmergencyTriageAssessment item in detail.triageAssessments)
            _TimelineItem(
              title: _joinDisplay(<String?>[
                'Triage',
                _apiLabel(item.triageLevel ?? ''),
              ]),
              subtitle: _dateTimeLabel(context, item.createdAt),
              body: item.notes,
              icon: Icons.monitor_heart_outlined,
              sortAt:
                  item.updatedAt ??
                  item.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              status: _triageStatus(item.triageLevel),
            ),
          for (final EmergencyResponseRecord item in detail.responses)
            _TimelineItem(
              title: 'Response',
              subtitle: _dateTimeLabel(
                context,
                item.responseAt ?? item.createdAt,
              ),
              body: item.notes,
              icon: Icons.medical_services_outlined,
              sortAt:
                  item.responseAt ??
                  item.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              status: const AppWorkspaceStatus(
                label: 'Responded',
                tone: AppWorkspaceStatusTone.success,
              ),
            ),
        ]..sort(
          (_TimelineItem left, _TimelineItem right) =>
              right.sortAt.compareTo(left.sortAt),
        );

    return AppWorkspaceDetailPanel(
      title: 'Triage and response',
      description: 'Clinical activity linked to this emergency case.',
      child: _RecordList<_TimelineItem>(
        items: items,
        emptyLabel: 'No triage or response recorded',
        icon: Icons.timeline_outlined,
        titleBuilder: (_TimelineItem item) => item.title,
        subtitleBuilder: (_, _TimelineItem item) => item.subtitle,
        bodyBuilder: (_TimelineItem item) => item.body,
        iconBuilder: (_TimelineItem item) => item.icon,
        statusBuilder: (_TimelineItem item) => item.status,
      ),
    );
  }
}

class _AmbulancePanel extends StatelessWidget {
  const _AmbulancePanel({required this.detail});

  final EmergencyCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final List<_TimelineItem> items =
        <_TimelineItem>[
          for (final EmergencyAmbulanceDispatch item in detail.dispatches)
            _TimelineItem(
              title: _joinDisplay(<String?>[
                'Dispatch',
                item.ambulanceLabel ??
                    item.ambulanceDisplayId ??
                    item.ambulanceId,
              ]),
              subtitle: _dateTimeLabel(
                context,
                item.dispatchedAt ?? item.createdAt,
              ),
              icon: Icons.airport_shuttle_outlined,
              sortAt:
                  item.dispatchedAt ??
                  item.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              status: AppWorkspaceStatus(
                label: _apiLabel(item.status ?? 'DISPATCHED'),
                tone: _ambulanceTone(item.status),
              ),
            ),
          for (final EmergencyAmbulanceTrip item in detail.trips)
            _TimelineItem(
              title: _joinDisplay(<String?>[
                item.isActive ? 'Active trip' : 'Trip complete',
                item.ambulanceLabel ??
                    item.ambulanceDisplayId ??
                    item.ambulanceId,
              ]),
              subtitle: _joinDisplay(<String?>[
                _dateTimeLabel(context, item.startedAt),
                item.endedAt == null
                    ? null
                    : 'Ended ${_dateTimeLabel(context, item.endedAt)}',
              ]),
              icon: Icons.route_outlined,
              sortAt:
                  item.endedAt ??
                  item.startedAt ??
                  item.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              status: AppWorkspaceStatus(
                label: item.isActive ? 'Transporting' : 'Completed',
                tone: item.isActive
                    ? AppWorkspaceStatusTone.warning
                    : AppWorkspaceStatusTone.success,
              ),
            ),
        ]..sort(
          (_TimelineItem left, _TimelineItem right) =>
              right.sortAt.compareTo(left.sortAt),
        );

    return AppWorkspaceDetailPanel(
      title: 'Ambulance',
      description: 'Dispatch and trip activity for this emergency case.',
      child: _RecordList<_TimelineItem>(
        items: items,
        emptyLabel: 'No ambulance activity recorded',
        icon: Icons.airport_shuttle_outlined,
        titleBuilder: (_TimelineItem item) => item.title,
        subtitleBuilder: (_, _TimelineItem item) => item.subtitle,
        iconBuilder: (_TimelineItem item) => item.icon,
        statusBuilder: (_TimelineItem item) => item.status,
      ),
    );
  }
}

class _RecordList<T> extends StatelessWidget {
  const _RecordList({
    required this.items,
    required this.emptyLabel,
    required this.icon,
    required this.titleBuilder,
    required this.subtitleBuilder,
    this.bodyBuilder,
    this.iconBuilder,
    this.statusBuilder,
  });

  final List<T> items;
  final String emptyLabel;
  final IconData icon;
  final String Function(T item) titleBuilder;
  final String Function(BuildContext context, T item) subtitleBuilder;
  final String? Function(T item)? bodyBuilder;
  final IconData Function(T item)? iconBuilder;
  final AppWorkspaceStatus? Function(T item)? statusBuilder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    if (items.isEmpty) {
      return Row(
        children: <Widget>[
          Icon(icon, color: colorScheme.onSurfaceVariant),
          SizedBox(width: theme.spacing.sm),
          Expanded(child: Text(emptyLabel)),
        ],
      );
    }

    return Column(
      children: <Widget>[
        for (var index = 0; index < items.length; index += 1) ...<Widget>[
          if (index > 0) const Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
            child: _RecordRow<T>(
              item: items[index],
              titleBuilder: titleBuilder,
              subtitleBuilder: subtitleBuilder,
              bodyBuilder: bodyBuilder,
              iconBuilder: iconBuilder,
              statusBuilder: statusBuilder,
              fallbackIcon: icon,
            ),
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
    required this.fallbackIcon,
    this.bodyBuilder,
    this.iconBuilder,
    this.statusBuilder,
  });

  final T item;
  final String Function(T item) titleBuilder;
  final String Function(BuildContext context, T item) subtitleBuilder;
  final String? Function(T item)? bodyBuilder;
  final IconData Function(T item)? iconBuilder;
  final AppWorkspaceStatus? Function(T item)? statusBuilder;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? body = bodyBuilder?.call(item);
    final AppWorkspaceStatus? status = statusBuilder?.call(item);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          iconBuilder?.call(item) ?? fallbackIcon,
          color: colorScheme.primary,
          size: theme.appTokens.listIconSize,
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(titleBuilder(item), style: theme.textTheme.titleSmall),
              SizedBox(height: theme.spacing.xs),
              Text(
                subtitleBuilder(context, item),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (body != null && body.trim().isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                Text(body),
              ],
            ],
          ),
        ),
        if (status != null) ...<Widget>[
          SizedBox(width: theme.spacing.sm),
          Flexible(child: AppWorkspaceStatusBadge(status: status)),
        ],
      ],
    );
  }
}

class _QuickArrivalDialog extends StatefulWidget {
  const _QuickArrivalDialog();

  @override
  State<_QuickArrivalDialog> createState() => _QuickArrivalDialogState();
}

class _QuickArrivalDialogState extends State<_QuickArrivalDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _severity = 'CRITICAL';
  String? _triageLevel = 'LEVEL_2';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text('Quick emergency arrival'),
      icon: const Icon(Icons.emergency_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _firstNameController,
            labelText: 'First name',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: _lastNameController,
            labelText: 'Last name',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          AppPhoneField(
            controller: _phoneController,
            labelText: 'Phone',
            countryLabelText: 'Country',
            countrySearchLabelText: 'Search country',
            countryNoResultsText: 'No countries found',
            numberLabelText: 'Phone number',
            invalidPhoneMessage: 'Enter a valid phone number',
          ),
          AppSelectField<String>(
            value: _severity,
            labelText: 'Priority',
            isRequired: true,
            options: _severityOptions(),
            validator: _requiredSelect,
            onChanged: (String? value) {
              if (value != null) {
                setState(() {
                  _severity = value;
                });
              }
            },
          ),
          AppSelectField<String>(
            value: _triageLevel,
            labelText: 'Initial triage',
            options: _triageOptions(),
            onChanged: (String? value) {
              setState(() {
                _triageLevel = value;
              });
            },
          ),
          AppTextField(
            controller: _notesController,
            labelText: 'Arrival notes',
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: 'Open case',
          leadingIcon: Icons.add_circle_outline,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    Navigator.of(context).pop(
      EmergencyQuickArrivalInput(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        severity: _severity,
        phone: _nonEmpty(_phoneController.text),
        triageLevel: _triageLevel,
        notes: _nonEmpty(_notesController.text),
      ),
    );
  }
}

class _PriorityDialog extends StatefulWidget {
  const _PriorityDialog({required this.initialSeverity});

  final String? initialSeverity;

  @override
  State<_PriorityDialog> createState() => _PriorityDialogState();
}

class _PriorityDialogState extends State<_PriorityDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String _severity = _normalizedOption(
    widget.initialSeverity,
    fallback: 'HIGH',
  );

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text('Update priority'),
      icon: const Icon(Icons.priority_high_outlined),
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _severity,
            labelText: 'Priority',
            isRequired: true,
            options: _severityOptions(),
            validator: _requiredSelect,
            onChanged: (String? value) {
              if (value != null) {
                setState(() {
                  _severity = value;
                });
              }
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: 'Update',
          leadingIcon: Icons.save_outlined,
          onPressed: () {
            if (validateAndSaveAppForm(_formKey)) {
              Navigator.of(context).pop(_severity);
            }
          },
        ),
      ],
    );
  }
}

class _TriageDialog extends StatefulWidget {
  const _TriageDialog({required this.latestTriage});

  final EmergencyTriageAssessment? latestTriage;

  @override
  State<_TriageDialog> createState() => _TriageDialogState();
}

class _TriageDialogState extends State<_TriageDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String _triageLevel = _normalizedOption(
    widget.latestTriage?.triageLevel,
    fallback: 'LEVEL_2',
  );
  late final TextEditingController _notesController = TextEditingController(
    text: widget.latestTriage?.notes ?? '',
  );

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text('Record triage'),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _triageLevel,
            labelText: 'Triage level',
            isRequired: true,
            options: _triageOptions(),
            validator: _requiredSelect,
            onChanged: (String? value) {
              if (value != null) {
                setState(() {
                  _triageLevel = value;
                });
              }
            },
          ),
          AppTextField(
            controller: _notesController,
            labelText: 'Triage notes',
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: 'Save triage',
          leadingIcon: Icons.save_outlined,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      _TriageInput(
        triageLevel: _triageLevel,
        notes: _nonEmpty(_notesController.text),
      ),
    );
  }
}

class _ResponseDialog extends StatefulWidget {
  const _ResponseDialog();

  @override
  State<_ResponseDialog> createState() => _ResponseDialogState();
}

class _ResponseDialogState extends State<_ResponseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text('Mark response'),
      icon: const Icon(Icons.medical_services_outlined),
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _notesController,
            labelText: 'Response notes',
            isRequired: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            validator: _requiredText,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: 'Mark response',
          leadingIcon: Icons.check_circle_outline,
          onPressed: () {
            if (validateAndSaveAppForm(_formKey)) {
              Navigator.of(context).pop(_notesController.text.trim());
            }
          },
        ),
      ],
    );
  }
}

class _DispatchDialog extends StatefulWidget {
  const _DispatchDialog({
    required this.referenceData,
    this.title = 'Dispatch ambulance',
    this.submitLabel = 'Dispatch',
    this.defaultStatus = 'DISPATCHED',
  });

  final EmergencyReferenceData referenceData;
  final String title;
  final String submitLabel;
  final String defaultStatus;

  @override
  State<_DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<_DispatchDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ambulanceIdController = TextEditingController();
  String? _ambulanceId;
  late String _status = widget.defaultStatus;

  @override
  void initState() {
    super.initState();
    final List<EmergencyAmbulance> ambulances =
        widget.referenceData.availableAmbulances;
    if (ambulances.length == 1) {
      _ambulanceId = ambulances.first.id;
    }
  }

  @override
  void dispose() {
    _ambulanceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<EmergencyAmbulance> ambulances =
        widget.referenceData.availableAmbulances;
    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.airport_shuttle_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          if (ambulances.isNotEmpty)
            AppSelectField<String>(
              value: _ambulanceId,
              labelText: 'Ambulance',
              isRequired: true,
              searchable: true,
              options: <AppSelectOption<String>>[
                for (final EmergencyAmbulance ambulance in ambulances)
                  AppSelectOption<String>(
                    value: ambulance.id,
                    label: ambulance.displayTitle,
                    trailingIcon: Text(_apiLabel(ambulance.status ?? '')),
                  ),
              ],
              validator: _requiredSelect,
              onChanged: (String? value) {
                setState(() {
                  _ambulanceId = value;
                });
              },
            )
          else
            AppTextField(
              controller: _ambulanceIdController,
              labelText: 'Ambulance ID',
              isRequired: true,
              validator: _requiredText,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
            ),
          AppSelectField<String>(
            value: _status,
            labelText: 'Dispatch status',
            isRequired: true,
            options: _ambulanceStatusOptions(),
            validator: _requiredSelect,
            onChanged: (String? value) {
              if (value != null) {
                setState(() {
                  _status = value;
                });
              }
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: widget.submitLabel,
          leadingIcon: Icons.airport_shuttle_outlined,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? ambulanceId =
        _ambulanceId ?? _nonEmpty(_ambulanceIdController.text);
    if (ambulanceId == null) {
      return;
    }
    Navigator.of(
      context,
    ).pop(_DispatchInput(ambulanceId: ambulanceId, status: _status));
  }
}

class _DispatchStatusDialog extends StatefulWidget {
  const _DispatchStatusDialog({required this.initialStatus});

  final String? initialStatus;

  @override
  State<_DispatchStatusDialog> createState() => _DispatchStatusDialogState();
}

class _DispatchStatusDialogState extends State<_DispatchStatusDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String _status = _normalizedOption(
    widget.initialStatus,
    fallback: 'EN_ROUTE',
  );

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text('Update dispatch status'),
      icon: const Icon(Icons.route_outlined),
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _status,
            labelText: 'Dispatch status',
            isRequired: true,
            options: _ambulanceStatusOptions(),
            validator: _requiredSelect,
            onChanged: (String? value) {
              if (value != null) {
                setState(() {
                  _status = value;
                });
              }
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: 'Update',
          leadingIcon: Icons.save_outlined,
          onPressed: () {
            if (validateAndSaveAppForm(_formKey)) {
              Navigator.of(context).pop(_status);
            }
          },
        ),
      ],
    );
  }
}

class _HandoffDialog extends StatefulWidget {
  const _HandoffDialog();

  @override
  State<_HandoffDialog> createState() => _HandoffDialogState();
}

class _HandoffDialogState extends State<_HandoffDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  String _destination = 'OPD';
  bool _closeCase = true;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text('Record handoff'),
      icon: const Icon(Icons.output_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _destination,
            labelText: 'Destination',
            isRequired: true,
            options: _handoffOptions(),
            validator: _requiredSelect,
            onChanged: (String? value) {
              if (value != null) {
                setState(() {
                  _destination = value;
                });
              }
            },
          ),
          AppTextField(
            controller: _notesController,
            labelText: 'Handoff notes',
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
          AppCheckboxField(
            title: 'Close emergency case',
            subtitle:
                'Use this after the receiving unit has accepted the patient.',
            value: _closeCase,
            onChanged: (bool value) {
              setState(() {
                _closeCase = value;
              });
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: 'Record handoff',
          leadingIcon: Icons.output_outlined,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      _HandoffInput(
        destination: _destination,
        notes: _nonEmpty(_notesController.text),
        closeCase: _closeCase,
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.actionLabel,
  });

  final String title;
  final String body;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(title),
      icon: const Icon(Icons.help_outline),
      content: Text(body),
      actions: <Widget>[
        AppButton.tertiary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: actionLabel,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

@immutable
final class _TriageInput {
  const _TriageInput({required this.triageLevel, this.notes});

  final String triageLevel;
  final String? notes;
}

@immutable
final class _DispatchInput {
  const _DispatchInput({required this.ambulanceId, required this.status});

  final String ambulanceId;
  final String status;
}

@immutable
final class _HandoffInput {
  const _HandoffInput({
    required this.destination,
    required this.closeCase,
    this.notes,
  });

  final String destination;
  final String? notes;
  final bool closeCase;
}

@immutable
final class _TimelineItem {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sortAt,
    this.body,
    this.status,
  });

  final String title;
  final String subtitle;
  final String? body;
  final IconData icon;
  final AppWorkspaceStatus? status;
  final DateTime sortAt;
}

List<AppSelectOption<EmergencyBoardScope>> _scopeOptions() {
  return const <AppSelectOption<EmergencyBoardScope>>[
    AppSelectOption<EmergencyBoardScope>(
      value: EmergencyBoardScope.active,
      label: 'Active',
    ),
    AppSelectOption<EmergencyBoardScope>(
      value: EmergencyBoardScope.critical,
      label: 'Critical',
    ),
    AppSelectOption<EmergencyBoardScope>(
      value: EmergencyBoardScope.ambulance,
      label: 'Ambulance',
    ),
    AppSelectOption<EmergencyBoardScope>(
      value: EmergencyBoardScope.handoff,
      label: 'Handoff',
    ),
    AppSelectOption<EmergencyBoardScope>(
      value: EmergencyBoardScope.closed,
      label: 'Closed',
    ),
    AppSelectOption<EmergencyBoardScope>(
      value: EmergencyBoardScope.all,
      label: 'All',
    ),
  ];
}

List<AppSelectOption<String>> _severityOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'CRITICAL', label: 'Critical'),
    AppSelectOption<String>(value: 'HIGH', label: 'High'),
    AppSelectOption<String>(value: 'MEDIUM', label: 'Medium'),
    AppSelectOption<String>(value: 'LOW', label: 'Low'),
  ];
}

List<AppSelectOption<String>> _triageOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'LEVEL_1', label: 'Level 1'),
    AppSelectOption<String>(value: 'LEVEL_2', label: 'Level 2'),
    AppSelectOption<String>(value: 'LEVEL_3', label: 'Level 3'),
    AppSelectOption<String>(value: 'LEVEL_4', label: 'Level 4'),
    AppSelectOption<String>(value: 'LEVEL_5', label: 'Level 5'),
  ];
}

List<AppSelectOption<String>> _ambulanceStatusOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'DISPATCHED', label: 'Dispatched'),
    AppSelectOption<String>(value: 'EN_ROUTE', label: 'En route'),
    AppSelectOption<String>(value: 'ON_SCENE', label: 'On scene'),
    AppSelectOption<String>(value: 'TRANSPORTING', label: 'Transporting'),
    AppSelectOption<String>(value: 'AVAILABLE', label: 'Available'),
    AppSelectOption<String>(value: 'OUT_OF_SERVICE', label: 'Out of service'),
  ];
}

List<AppSelectOption<String>> _handoffOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'OPD', label: 'OPD'),
    AppSelectOption<String>(value: 'IPD', label: 'IPD'),
    AppSelectOption<String>(value: 'ICU', label: 'ICU'),
    AppSelectOption<String>(value: 'THEATER', label: 'Theater'),
    AppSelectOption<String>(value: 'REFERRAL', label: 'Referral'),
    AppSelectOption<String>(value: 'DISCHARGE', label: 'Discharge'),
  ];
}

AppWorkspaceStatus _caseStatus(EmergencyCaseSummary item) {
  final String normalized = (item.status ?? 'OPEN').toUpperCase();
  return AppWorkspaceStatus(
    label: _apiLabel(normalized),
    tone: switch (normalized) {
      'CLOSED' || 'COMPLETED' => AppWorkspaceStatusTone.success,
      'CANCELLED' => AppWorkspaceStatusTone.neutral,
      _ => AppWorkspaceStatusTone.info,
    },
  );
}

AppWorkspaceStatus _severityStatus(EmergencyCaseSummary item) {
  final String severity = (item.severity ?? 'MEDIUM').toUpperCase();
  return AppWorkspaceStatus(
    label: _apiLabel(severity),
    tone: _severityTone(severity),
    icon: severity == 'CRITICAL'
        ? Icons.priority_high_outlined
        : Icons.emergency_outlined,
  );
}

AppWorkspaceStatus _triageStatus(String? triageLevel) {
  final String level = (triageLevel ?? '').toUpperCase();
  return AppWorkspaceStatus(
    label: level.isEmpty ? 'Triage pending' : _apiLabel(level),
    tone: switch (level) {
      'LEVEL_1' => AppWorkspaceStatusTone.error,
      'LEVEL_2' => AppWorkspaceStatusTone.warning,
      '' => AppWorkspaceStatusTone.neutral,
      _ => AppWorkspaceStatusTone.info,
    },
    icon: Icons.monitor_heart_outlined,
  );
}

AppWorkspaceStatus _responseStatus(EmergencyCaseSummary item) {
  final bool responded = item.latestResponse != null;
  return AppWorkspaceStatus(
    label: responded ? 'Responded' : 'Awaiting response',
    tone: responded
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.warning,
    icon: responded
        ? Icons.check_circle_outline
        : Icons.notification_important_outlined,
  );
}

AppWorkspaceStatusTone _severityTone(String? severity) {
  return switch ((severity ?? '').toUpperCase()) {
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'HIGH' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.neutral,
    _ => AppWorkspaceStatusTone.info,
  };
}

AppWorkspaceStatusTone _ambulanceTone(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'OUT_OF_SERVICE' => AppWorkspaceStatusTone.error,
    'AVAILABLE' => AppWorkspaceStatusTone.success,
    'TRANSPORTING' ||
    'EN_ROUTE' ||
    'ON_SCENE' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.info,
  };
}

String _pageLabel(BuildContext context, AppPage<EmergencyCaseSummary> page) {
  if (page.items.isEmpty) {
    return 'No emergency cases';
  }
  final String visible = '${page.firstItemNumber}-${page.lastItemNumber}';
  final int? total = page.totalItemCount;
  return total == null ? visible : '$visible of ${_countLabel(context, total)}';
}

String _countLabel(BuildContext context, int value) {
  return AppFormatters.compactNumber(value, Localizations.localeOf(context));
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return 'Not recorded';
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
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

String? _nonEmpty(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String _normalizedOption(String? value, {required String fallback}) {
  final String normalized = value?.trim().toUpperCase() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

String? _requiredText(String? value) {
  return (value ?? '').trim().isEmpty ? 'Required' : null;
}

String? _requiredSelect(Object? value) {
  return value == null || value.toString().trim().isEmpty ? 'Required' : null;
}

String _emergencySummaryHtml(BuildContext context, EmergencyCaseDetail detail) {
  final EmergencyCaseSummary summary = detail.summary;
  final StringBuffer buffer = StringBuffer()
    ..writeln(
      PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(label: 'Case', value: summary.caseLabel),
        PrintFormMetadataItem(label: 'Patient', value: summary.displayTitle),
        PrintFormMetadataItem(
          label: 'Patient no.',
          value: summary.patientDisplayId ?? summary.patientId ?? '',
        ),
        PrintFormMetadataItem(
          label: 'Facility',
          value: summary.facilityLabel ?? '',
        ),
        PrintFormMetadataItem(
          label: 'Arrival',
          value: _dateTimeLabel(context, summary.createdAt),
        ),
        PrintFormMetadataItem(
          label: 'Location',
          value: summary.currentLocation,
        ),
      ]),
    );

  final StringBuffer triageBody = StringBuffer();

  if (detail.triageAssessments.isEmpty) {
    triageBody.writeln(
      '<p class="print-template-empty">No triage recorded.</p>',
    );
  } else {
    for (final EmergencyTriageAssessment triage in detail.triageAssessments) {
      triageBody
        ..writeln(
          '<p><strong>${_escapeHtml(_apiLabel(triage.triageLevel ?? ''))}</strong> ${_escapeHtml(_dateTimeLabel(context, triage.createdAt))}</p>',
        )
        ..writeln(
          '<p class="print-template-note">${_escapeHtml(triage.notes ?? '')}</p>',
        );
    }
  }

  buffer.writeln(
    PrintFormTemplate.section(title: 'Triage', bodyHtml: triageBody.toString()),
  );

  final StringBuffer responseBody = StringBuffer();
  if (detail.responses.isEmpty) {
    responseBody.writeln(
      '<p class="print-template-empty">No response recorded.</p>',
    );
  } else {
    for (final EmergencyResponseRecord response in detail.responses) {
      responseBody
        ..writeln(
          '<p><strong>Response</strong> ${_escapeHtml(_dateTimeLabel(context, response.responseAt ?? response.createdAt))}</p>',
        )
        ..writeln(
          '<p class="print-template-note">${_escapeHtml(response.notes ?? '')}</p>',
        );
    }
  }

  buffer.writeln(
    PrintFormTemplate.section(
      title: 'Response',
      bodyHtml: responseBody.toString(),
    ),
  );

  final StringBuffer ambulance = StringBuffer();
  if (detail.dispatches.isEmpty && detail.trips.isEmpty) {
    ambulance.writeln(
      '<p class="print-template-empty">No ambulance activity recorded.</p>',
    );
  } else {
    for (final EmergencyAmbulanceDispatch dispatch in detail.dispatches) {
      ambulance.writeln(
        '<p>${_escapeHtml(_joinDisplay(<String?>['Dispatch', dispatch.ambulanceLabel, _apiLabel(dispatch.status ?? ''), _dateTimeLabel(context, dispatch.dispatchedAt ?? dispatch.createdAt)]))}</p>',
      );
    }
    for (final EmergencyAmbulanceTrip trip in detail.trips) {
      ambulance.writeln(
        '<p>${_escapeHtml(_joinDisplay(<String?>[trip.isActive ? 'Active trip' : 'Trip complete', trip.ambulanceLabel, _dateTimeLabel(context, trip.startedAt), trip.endedAt == null ? null : 'Ended ${_dateTimeLabel(context, trip.endedAt)}']))}</p>',
      );
    }
  }

  buffer.writeln(
    PrintFormTemplate.section(
      title: 'Ambulance',
      bodyHtml: ambulance.toString(),
    ),
  );
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

void _showFailureIfNeeded(
  BuildContext context,
  AppFailure? failure, {
  String? successMessage,
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  if (failure == null) {
    if (successMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    }
    return;
  }

  final String message = switch (failure.category) {
    AppFailureCategory.validation => 'Check the required emergency fields.',
    AppFailureCategory.forbidden => 'You do not have access to this action.',
    AppFailureCategory.offline => 'You appear to be offline.',
    AppFailureCategory.timeout => 'The request timed out.',
    _ => 'Emergency action failed.',
  };
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

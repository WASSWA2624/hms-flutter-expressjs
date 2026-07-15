import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_billing_guidance.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_patient_actions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';
/// High-volume front-desk workspace composing Patient Registry + OPD.
///
/// Does not fork patient/billing engines. Triage capture stays in Triage/OPD.
class ReceptionWorkspacePage extends ConsumerWidget {
  const ReceptionWorkspacePage({this.initialQuery, super.key});

  final ReceptionWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<OpdWorkspaceState>> opdState = ref.watch(
      opdWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<OpdWorkspaceState>(
      value: opdState,
      loadingTitle: l10n.receptionLoadingTitle,
      loadingBody: l10n.receptionLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      // Show an in-page loading state; shell deferral renders a blank body.
      deferLoadingToShell: false,
      keepPreviousDataDuringRefresh: true,
      onRetry: () {
        ref.read(opdWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, OpdWorkspaceState data) {
        return _ReceptionWorkspaceContent(
          state: data,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _ReceptionWorkspaceContent extends ConsumerStatefulWidget {
  const _ReceptionWorkspaceContent({required this.state, this.initialQuery});

  final OpdWorkspaceState state;
  final ReceptionWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_ReceptionWorkspaceContent> createState() =>
      _ReceptionWorkspaceContentState();
}

class _ReceptionWorkspaceContentState
    extends ConsumerState<_ReceptionWorkspaceContent> {
  late final TextEditingController _searchController;
  late ReceptionDeskSection _section;
  String? _appliedRouteSignature;
  Timer? _searchDebounce;

  static const Set<String> _paymentGateStages = <String>{
    'WAITING_CONSULTATION_PAYMENT',
  };

  static const Set<String> _activeVisitStages = <String>{
    'WAITING_CONSULTATION_PAYMENT',
    'WAITING_VITALS',
    'WAITING_DOCTOR_ASSIGNMENT',
    'WAITING_DOCTOR_REVIEW',
    'LAB_REQUESTED',
    'RADIOLOGY_REQUESTED',
    'LAB_AND_RADIOLOGY_REQUESTED',
    'PHARMACY_REQUESTED',
    'WAITING_DISPOSITION',
  };

  @override
  void initState() {
    super.initState();
    _section = ReceptionDeskSection.appointments;
    _searchController = TextEditingController(
      text: widget.initialQuery?.search ?? '',
    );
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _ReceptionWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleRouteQuery(ReceptionWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_applyDeepLink(query));
    });
  }

  Future<void> _applyDeepLink(ReceptionWorkspaceQuery query) async {
    if (_appliedRouteSignature == query.signature) {
      return;
    }
    _appliedRouteSignature = query.signature;

    final ReceptionDeskSection? section = _sectionFromQuery(query.section);
    if (section != null) {
      setState(() => _section = section);
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
    }

    if (query.flowId.isNotEmpty) {
      final OpdFlowSummary? flow = _findFlow(query.flowId);
      if (flow != null && mounted) {
        await _openFlowActions(flow);
      }
    }
  }

  ReceptionDeskSection? _sectionFromQuery(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'appointments':
      case 'meetings':
        return ReceptionDeskSection.appointments;
      case 'queue':
      case 'desk_queue':
      case 'desk-queue':
        return ReceptionDeskSection.queue;
      case 'in-progress':
      case 'active':
      case 'visits':
      case 'turnaround_pressure':
        return ReceptionDeskSection.activeVisits;
      case 'payment':
      case 'payment-gate':
      case 'follow-up':
      case 'no_show_pressure':
        return ReceptionDeskSection.paymentGate;
      default:
        return null;
    }
  }

  OpdFlowSummary? _findFlow(String id) {
    final String needle = id.trim().toLowerCase();
    if (needle.isEmpty) {
      return null;
    }
    for (final OpdFlowSummary flow in widget.state.flows.items) {
      if (flow.id.toLowerCase() == needle ||
          flow.apiId.toLowerCase() == needle ||
          (flow.publicId ?? '').toLowerCase() == needle) {
        return flow;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final OpdWorkspaceState state = widget.state;
    final OpdWorkspaceController controller = ref.read(
      opdWorkspaceControllerProvider.notifier,
    );
    final String search = _searchController.text.trim().toLowerCase();
    final List<_ReceptionDeskRow> rows = _buildRows(state, search);

    return AppWorkspace(
      title: l10n.receptionTitle,
      leadingIcon: AppRouteIcons.reception,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: _summaryNotifications(context, state),
        primary: AppAccessActionGate(
          requirement: receptionFrontDeskWriteRequirement,
          builder: (BuildContext context, bool isAllowed) {
            return AppButton.primary(
              label: l10n.receptionRegisterPatientAction,
              leadingIcon: Icons.person_add_alt_1_outlined,
              enabled: isAllowed,
              onPressed: isAllowed
                  ? () => unawaited(_openRegisterPatient())
                  : null,
            );
          },
        ),
        secondary: <Widget>[
          AppAccessActionGate(
            requirement: receptionFrontDeskWriteRequirement,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                label: l10n.receptionScheduleAppointmentAction,
                leadingIcon: Icons.event_available_outlined,
                enabled: isAllowed,
                onPressed: isAllowed
                    ? () => unawaited(_scheduleAppointment())
                    : null,
              );
            },
          ),
          AppAccessActionGate(
            requirement: receptionFrontDeskWriteRequirement,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                label: l10n.opdStartWalkInAction,
                leadingIcon: Icons.directions_walk_outlined,
                enabled: isAllowed,
                onPressed: isAllowed
                    ? () => unawaited(
                        openOpdWorkspaceEncounterFlow(context, ref, state),
                      )
                    : null,
              );
            },
          ),
        ],
        onRefresh: () async {
          final AppFailure? failure = await controller.refresh();
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        isRefreshing:
            state.isRefreshingAppointments ||
            state.isRefreshingQueue ||
            state.isRefreshingFlows,
      ),
      // AppWorkspace scrolls the page; do not nest Expanded/ListView flex.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: <Widget>[
              for (final ReceptionDeskSection section
                  in ReceptionDeskSection.values)
                ChoiceChip(
                  label: Text(_sectionLabel(l10n, section)),
                  selected: _section == section,
                  onSelected: (_) => setState(() => _section = section),
                ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          AppTextField(
            controller: _searchController,
            labelText: l10n.receptionSearchHint,
            prefixIcon: const Icon(Icons.search),
            onChanged: (_) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                if (mounted) {
                  setState(() {});
                }
              });
            },
          ),
          SizedBox(height: theme.spacing.md),
          if (rows.isEmpty)
            AppStateView(
              title: l10n.receptionEmptyTitle,
              body: l10n.receptionEmptyBody,
              variant: AppStateViewVariant.empty,
            )
          else
            for (int index = 0; index < rows.length; index++) ...<Widget>[
              if (index > 0) SizedBox(height: theme.spacing.sm),
              _ReceptionDeskCard(
                row: rows[index],
                onOpenAppointment: (OpdAppointment appointment) =>
                    unawaited(_openAppointmentActions(appointment)),
                onCheckIn: (OpdAppointment appointment) =>
                    unawaited(_checkIn(appointment)),
                onStartFromQueue: (OpdQueueEntry entry) =>
                    unawaited(_startFromQueue(entry)),
                onPrioritize: (OpdQueueEntry entry) =>
                    unawaited(_prioritize(entry)),
                onOpenFlow: (OpdFlowSummary flow) =>
                    unawaited(_openFlowActions(flow)),
                onAssignDoctor: (OpdFlowSummary flow) =>
                    unawaited(_assignDoctor(flow)),
                onEditPatient: (String patientId) =>
                    unawaited(_editPatient(patientId)),
                onCaptureInsurance: (String patientId) =>
                    unawaited(_captureInsurance(patientId)),
                onScheduleForPatient: (String patientId) =>
                    unawaited(_scheduleForPatient(patientId)),
              ),
            ],
        ],
      ),
    );
  }

  List<AppWorkspaceSummaryNotification> _summaryNotifications(
    BuildContext context,
    OpdWorkspaceState state,
  ) {
    final AppLocalizations l10n = context.l10n;
    final int appointments = state.appointments.items
        .where((OpdAppointment item) => !_isTerminalStatus(item.status))
        .length;
    final int queue = state.queueEntries.items
        .where((OpdQueueEntry item) => !_isTerminalStatus(item.status))
        .length;
    final int paymentGate = state.flows.items
        .where(
          (OpdFlowSummary flow) =>
              _paymentGateStages.contains((flow.stage ?? '').toUpperCase()),
        )
        .length;
    final int active = state.flows.items
        .where(
          (OpdFlowSummary flow) =>
              _activeVisitStages.contains((flow.stage ?? '').toUpperCase()),
        )
        .length;

    final List<AppWorkspaceSummaryNotification> cards =
        <AppWorkspaceSummaryNotification>[];

    void add(
      int count,
      IconData icon,
      ReceptionDeskSection section, {
      AppWorkspaceStatusTone tone = AppWorkspaceStatusTone.neutral,
    }) {
      if (count <= 0) {
        return;
      }
      cards.add(
        AppWorkspaceSummaryNotification(
          label: _sectionLabel(l10n, section),
          count: count,
          icon: icon,
          tone: tone,
          onSelected: () => setState(() => _section = section),
        ),
      );
    }

    add(
      appointments,
      Icons.event_available_outlined,
      ReceptionDeskSection.appointments,
    );
    add(
      queue,
      Icons.queue_outlined,
      ReceptionDeskSection.queue,
    );
    add(
      active,
      Icons.pending_actions_outlined,
      ReceptionDeskSection.activeVisits,
    );
    add(
      paymentGate,
      Icons.payments_outlined,
      ReceptionDeskSection.paymentGate,
      tone: AppWorkspaceStatusTone.warning,
    );
    return cards;
  }

  String _sectionLabel(AppLocalizations l10n, ReceptionDeskSection section) {
    return switch (section) {
      ReceptionDeskSection.appointments => l10n.receptionSectionAppointments,
      ReceptionDeskSection.queue => l10n.receptionSectionQueue,
      ReceptionDeskSection.activeVisits => l10n.receptionSectionActiveVisits,
      ReceptionDeskSection.paymentGate => l10n.receptionSectionPaymentGate,
    };
  }

  List<_ReceptionDeskRow> _buildRows(OpdWorkspaceState state, String search) {
    switch (_section) {
      case ReceptionDeskSection.appointments:
        return <_ReceptionDeskRow>[
          for (final OpdAppointment appointment in state.appointments.items)
            if (!_isTerminalStatus(appointment.status) &&
                _matchesSearch(
                  search,
                  appointment.patientDisplayName,
                  appointment.patientId,
                  appointment.publicId ?? appointment.id,
                ))
              _ReceptionDeskRow.appointment(appointment),
        ];
      case ReceptionDeskSection.queue:
        return <_ReceptionDeskRow>[
          for (final OpdQueueEntry entry in state.queueEntries.items)
            if (!_isTerminalStatus(entry.status) &&
                _matchesSearch(
                  search,
                  entry.patientDisplayName,
                  entry.patientId,
                  entry.publicId ?? entry.id,
                ))
              _ReceptionDeskRow.queue(entry),
        ];
      case ReceptionDeskSection.activeVisits:
        return <_ReceptionDeskRow>[
          for (final OpdFlowSummary flow in state.flows.items)
            if (_activeVisitStages.contains((flow.stage ?? '').toUpperCase()) &&
                _matchesSearch(
                  search,
                  flow.patientDisplayName,
                  flow.patientId,
                  flow.publicId ?? flow.id,
                ))
              _ReceptionDeskRow.flow(flow),
        ];
      case ReceptionDeskSection.paymentGate:
        return <_ReceptionDeskRow>[
          for (final OpdFlowSummary flow in state.flows.items)
            if (_paymentGateStages.contains((flow.stage ?? '').toUpperCase()) &&
                _matchesSearch(
                  search,
                  flow.patientDisplayName,
                  flow.patientId,
                  flow.publicId ?? flow.id,
                ))
              _ReceptionDeskRow.flow(flow),
        ];
    }
  }

  bool _matchesSearch(
    String search,
    String? name,
    String? patientId,
    String? displayId,
  ) {
    if (search.isEmpty) {
      return true;
    }
    return <String?>[name, patientId, displayId]
        .whereType<String>()
        .any((String value) => value.toLowerCase().contains(search));
  }

  bool _isTerminalStatus(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'COMPLETED':
      case 'CANCELLED':
      case 'NO_SHOW':
      case 'DISCHARGED':
      case 'ADMITTED':
      case 'CLOSED':
        return true;
      default:
        return false;
    }
  }

  Future<void> _openRegisterPatient() async {
    final AsyncValue<Result<PatientRegistryState>> registryAsync = ref.read(
      patientRegistryControllerProvider,
    );
    final PatientRegistryState? registry = registryAsync.asData?.value.when(
      success: (PatientRegistryState state) => state,
      failure: (_) => null,
    );
    if (registry == null) {
      final AppFailure? failure = await ref
          .read(patientRegistryControllerProvider.notifier)
          .refresh();
      if (!mounted) {
        return;
      }
      if (failure != null) {
        _showFailureIfNeeded(context, failure);
        return;
      }
    }

    final PatientRegistryState? loaded =
        ref.read(patientRegistryControllerProvider).asData?.value.when(
          success: (PatientRegistryState state) => state,
          failure: (_) => null,
        );
    if (loaded == null || !mounted) {
      return;
    }

    final Patient? created = await showAppDialog<Patient>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegisterNewPatientDialog(
        referenceData: loaded.referenceData,
        registrationScope: PatientRegistrationScope.resolve(
          referenceData: loaded.referenceData,
          accessPolicy: ref.read(appAccessPolicyProvider),
        ),
        onLookupDuplicates: (PatientDuplicateQuery query) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .loadDuplicateCandidates(query);
        },
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .createPatient(payload);
        },
      ),
    );

    if (created == null || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.patientsSavedMessage)),
    );
  }

  Future<void> _scheduleAppointment() async {
    final bool saved = await openReceptionScheduleAppointment(
      context: context,
      ref: ref,
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
      await ref.read(opdWorkspaceControllerProvider.notifier).refresh();
    }
  }

  Future<void> _scheduleForPatient(String patientId) async {
    final Patient? patient = await _resolvePatient(patientId);
    if (patient == null || !mounted) {
      return;
    }
    final bool saved = await openReceptionScheduleAppointment(
      context: context,
      ref: ref,
      patient: patient,
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
      await ref.read(opdWorkspaceControllerProvider.notifier).refresh();
    }
  }

  Future<Patient?> _resolvePatient(String patientId) async {
    final Result<AppPage<Patient>> result = await ref
        .read(patientRegistryControllerProvider.notifier)
        .loadPatientPage(
          PatientListQuery(
            patientId: patientId,
            pageRequest: const AppPageRequest(pageSize: 1),
          ),
        );
    return result.when(
      success: (AppPage<Patient> page) =>
          page.items.isEmpty ? null : page.items.first,
      failure: (AppFailure failure) {
        if (mounted) {
          _showFailureIfNeeded(context, failure);
        }
        return null;
      },
    );
  }

  Future<void> _editPatient(String patientId) async {
    await openReceptionPatientEditor(context, ref, patientId);
  }

  Future<void> _captureInsurance(String patientId) async {
    await openReceptionInsuranceCapture(
      context: context,
      ref: ref,
      patientId: patientId,
    );
  }

  Future<void> _openAppointmentActions(OpdAppointment appointment) async {
    final bool? changed = await showOpdAppointmentActionsDialog(
      context: context,
      appointment: appointment,
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }

  Future<void> _checkIn(OpdAppointment appointment) async {
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .checkInAppointment(appointment);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
      return;
    }
    _showFailureIfNeeded(context, failure);
  }

  Future<void> _startFromQueue(OpdQueueEntry entry) async {
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .startOpdFromQueue(entry);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
      return;
    }
    _showFailureIfNeeded(context, failure);
  }

  Future<void> _prioritize(OpdQueueEntry entry) async {
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .prioritizeQueueEntry(entry, null);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
      return;
    }
    _showFailureIfNeeded(context, failure);
  }

  Future<void> _openFlowActions(OpdFlowSummary flow) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FlowActionsDialog(flow: flow),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }

  Future<void> _assignDoctor(OpdFlowSummary flow) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignDoctorDialog(flow: flow),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }

  void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
    showAppFailureSnackBar(context, failure);
  }
}

@immutable
final class _ReceptionDeskRow {
  const _ReceptionDeskRow._({this.appointment, this.queueEntry, this.flow});

  factory _ReceptionDeskRow.appointment(OpdAppointment appointment) {
    return _ReceptionDeskRow._(appointment: appointment);
  }

  factory _ReceptionDeskRow.queue(OpdQueueEntry entry) {
    return _ReceptionDeskRow._(queueEntry: entry);
  }

  factory _ReceptionDeskRow.flow(OpdFlowSummary flow) {
    return _ReceptionDeskRow._(flow: flow);
  }

  final OpdAppointment? appointment;
  final OpdQueueEntry? queueEntry;
  final OpdFlowSummary? flow;

  String get id =>
      appointment?.id ?? queueEntry?.id ?? flow?.id ?? '';

  String patientName(BuildContext context) {
    return appointment?.patientDisplayName ??
        queueEntry?.patientDisplayName ??
        flow?.patientDisplayName ??
        context.l10n.profileUnknownValue;
  }

  String? get patientId =>
      appointment?.patientId ?? queueEntry?.patientId ?? flow?.patientId;

  String? get displayId =>
      appointment?.publicId ??
      queueEntry?.publicId ??
      flow?.publicId ??
      appointment?.id ??
      queueEntry?.id ??
      flow?.id;

  String? get status =>
      appointment?.status ?? queueEntry?.status ?? flow?.stage;

  DateTime? get time =>
      appointment?.scheduledStart ?? queueEntry?.queuedAt ?? flow?.startedAt;
}

class _ReceptionDeskCard extends ConsumerWidget {
  const _ReceptionDeskCard({
    required this.row,
    required this.onOpenAppointment,
    required this.onCheckIn,
    required this.onStartFromQueue,
    required this.onPrioritize,
    required this.onOpenFlow,
    required this.onAssignDoctor,
    required this.onEditPatient,
    required this.onCaptureInsurance,
    required this.onScheduleForPatient,
  });

  final _ReceptionDeskRow row;
  final ValueChanged<OpdAppointment> onOpenAppointment;
  final ValueChanged<OpdAppointment> onCheckIn;
  final ValueChanged<OpdQueueEntry> onStartFromQueue;
  final ValueChanged<OpdQueueEntry> onPrioritize;
  final ValueChanged<OpdFlowSummary> onOpenFlow;
  final ValueChanged<OpdFlowSummary> onAssignDoctor;
  final ValueChanged<String> onEditPatient;
  final ValueChanged<String> onCaptureInsurance;
  final ValueChanged<String> onScheduleForPatient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final OpdFlowSummary? flow = row.flow;
    final List<AppWorkflowStepItem> steps = flow == null
        ? const <AppWorkflowStepItem>[]
        : _receptionWorkflowSteps(context, flow);

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(theme.radius.md),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppPatientDetails(
              patientName: row.patientName(context),
              patientNumber: row.displayId ?? '',
              patientNumberLabel: l10n.opdPatientIdLabel,
              showAvatar: false,
              persistExpandPreference: false,
              initiallyExpanded: false,
              compactSupportingText: row.time == null
                  ? null
                  : AppFormatters.dateTime(row.time!, locale),
              status: (row.status ?? '').isEmpty
                  ? null
                  : AppWorkspaceStatus(
                      label: opdStageDisplayLabel(l10n, row.status!),
                      tone: AppWorkspaceStatusTone.info,
                    ),
            ),
            if (steps.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              AppWorkflowStepper(steps: steps),
            ],
            if (flow != null) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              ReceptionBillingGuidancePanel(flow: flow),
            ] else if (row.queueEntry != null) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              ReceptionBillingGuidancePanel(queueEntry: row.queueEntry),
            ],
            SizedBox(height: theme.spacing.sm),
            AppPermissionActionList(actions: _actions(context, l10n)),
          ],
        ),
      ),
    );
  }

  List<AppPermissionActionItem> _actions(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[];
    final OpdAppointment? appointment = row.appointment;
    final OpdQueueEntry? queueEntry = row.queueEntry;
    final OpdFlowSummary? flow = row.flow;
    final String? patientId = row.patientId;

    if (appointment != null) {
      actions.add(
        AppPermissionActionItem(
          requirement: receptionFrontDeskWriteRequirement,
          label: l10n.receptionAppointmentActionsAction,
          icon: Icons.event_available_outlined,
          variant: AppButtonVariant.primary,
          onPressed: () => onOpenAppointment(appointment),
        ),
      );
      actions.add(
        AppPermissionActionItem(
          requirement: receptionFrontDeskWriteRequirement,
          label: l10n.opdCheckInAction,
          icon: Icons.login_outlined,
          onPressed: () => onCheckIn(appointment),
        ),
      );
    }

    if (queueEntry != null) {
      actions.add(
        AppPermissionActionItem(
          requirement: receptionFrontDeskWriteRequirement,
          label: l10n.opdStartConsultationAction,
          icon: Icons.play_arrow_outlined,
          variant: AppButtonVariant.primary,
          onPressed: () => onStartFromQueue(queueEntry),
        ),
      );
      actions.add(
        AppPermissionActionItem(
          requirement: receptionFrontDeskWriteRequirement,
          label: l10n.opdPrioritizeAction,
          icon: Icons.priority_high_outlined,
          onPressed: () => onPrioritize(queueEntry),
        ),
      );
    }

    if (flow != null) {
      actions.add(
        AppPermissionActionItem(
          requirement: receptionFrontDeskWriteRequirement,
          label: l10n.receptionRoutePatientAction,
          icon: Icons.assignment_ind_outlined,
          variant: AppButtonVariant.primary,
          onPressed: () => onAssignDoctor(flow),
        ),
      );
      actions.add(
        AppPermissionActionItem(
          requirement: receptionWorkspaceRequirement,
          label: l10n.receptionOpenEncounterAction,
          icon: Icons.medical_services_outlined,
          hideWhenDenied: false,
          onPressed: () => onOpenFlow(flow),
        ),
      );
    }

    if (patientId != null && patientId.isNotEmpty) {
      actions.add(
        AppPermissionActionItem(
          requirement: receptionFrontDeskWriteRequirement,
          label: l10n.receptionEditPatientAction,
          icon: Icons.person_outline,
          onPressed: () => onEditPatient(patientId),
        ),
      );
      actions.add(
        AppPermissionActionItem(
          requirement: receptionFrontDeskWriteRequirement,
          label: l10n.receptionScheduleAppointmentAction,
          icon: Icons.calendar_month_outlined,
          onPressed: () => onScheduleForPatient(patientId),
        ),
      );
      actions.add(
        AppPermissionActionItem(
          requirement: receptionInsuranceCaptureRequirement,
          label: l10n.receptionCaptureInsuranceAction,
          icon: Icons.badge_outlined,
          onPressed: () => onCaptureInsurance(patientId),
        ),
      );
    }

    return actions;
  }

  List<AppWorkflowStepItem> _receptionWorkflowSteps(
    BuildContext context,
    OpdFlowSummary flow,
  ) {
    final AppLocalizations l10n = context.l10n;
    final String stage = (flow.stage ?? '').toUpperCase();
    final List<({String id, String label})> sequence =
        <({String id, String label})>[
          (id: 'WAITING_CONSULTATION_PAYMENT', label: l10n.receptionStepPayment),
          (id: 'WAITING_VITALS', label: l10n.receptionStepVitals),
          (
            id: 'WAITING_DOCTOR_ASSIGNMENT',
            label: l10n.receptionStepAssignDoctor,
          ),
          (id: 'WAITING_DOCTOR_REVIEW', label: l10n.receptionStepConsultation),
          (id: 'WAITING_DISPOSITION', label: l10n.receptionStepDisposition),
        ];

    final int currentIndex = sequence.indexWhere(
      (({String id, String label}) step) => step.id == stage,
    );

    return <AppWorkflowStepItem>[
      for (int i = 0; i < sequence.length; i++)
        AppWorkflowStepItem(
          id: sequence[i].id,
          label: sequence[i].label,
          state: currentIndex < 0
              ? AppWorkflowStepState.upcoming
              : i < currentIndex
              ? AppWorkflowStepState.completed
              : i == currentIndex
              ? AppWorkflowStepState.current
              : AppWorkflowStepState.upcoming,
        ),
    ];
  }
}

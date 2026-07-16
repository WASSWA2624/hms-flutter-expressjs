import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_encounter_dialog_controller.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';

class PatientPinnedOpdEncounterDialog extends ConsumerStatefulWidget {
  const PatientPinnedOpdEncounterDialog({
    required this.patient,
    this.onExistingActiveEncounter,
    super.key,
  });

  final Patient patient;
  final ValueChanged<OpdFlowSummary>? onExistingActiveEncounter;

  @override
  ConsumerState<PatientPinnedOpdEncounterDialog> createState() =>
      _PatientPinnedOpdEncounterDialogState();
}

class _PatientPinnedOpdEncounterDialogState
    extends ConsumerState<PatientPinnedOpdEncounterDialog> {
  bool _isLoading = true;
  List<OpdProviderSchedule> _providerSchedules = const <OpdProviderSchedule>[];
  List<OpdAppointment> _appointments = const <OpdAppointment>[];
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEncounterData());
  }

  Future<void> _loadEncounterData() async {
    final String search =
        widget.patient.effectiveIdentifier ?? widget.patient.id;
    final Result<List<OpdProviderSchedule>> scheduleResult = await ref
        .read(opdEncounterDialogControllerProvider)
        .listProviderSchedules();
    final Result<AppPage<OpdAppointment>> appointmentResult = await ref
        .read(opdEncounterDialogControllerProvider)
        .listAppointments(OpdAppointmentQuery(search: search));
    if (!mounted) {
      return;
    }
    AppFailure? failure;
    var schedules = const <OpdProviderSchedule>[];
    var appointments = const <OpdAppointment>[];
    scheduleResult.when(
      success: (List<OpdProviderSchedule> value) => schedules = value,
      failure: (AppFailure value) => failure = value,
    );
    appointmentResult.when(
      success: (AppPage<OpdAppointment> value) => appointments = value.items,
      failure: (AppFailure value) => failure ??= value,
    );
    setState(() {
      _providerSchedules = schedules;
      _appointments = appointments;
      _failure = failure;
      _isLoading = false;
    });
  }

  void _retryLoad() {
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    unawaited(_loadEncounterData());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading || _failure != null) {
      return AppDialog(
        title: Text(l10n.opdWalkInDialogTitle),
        icon: const Icon(opdEncounterIcon),
        scrollable: true,
        pinActionsToBottom: true,
        closeEnabled: !_isLoading,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            if (_isLoading)
              AppLoadingIndicator(
                size: AppLoadingIndicatorSize.compact,
                title: l10n.opdLoadingTitle,
                body: l10n.opdLoadingBody,
              ),
          ],
        ),
        actions: <Widget>[
          AppButton.secondary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: AppActionIcons.cancel,
            enabled: !_isLoading,
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          ),
          if (_failure != null && !_isLoading)
            AppButton.primary(
              label: l10n.commonRetryActionLabel,
              leadingIcon: AppActionIcons.refresh,
              onPressed: _retryLoad,
            ),
        ],
      );
    }

    return OpdEncounterDialog(
      providerSchedules: _providerSchedules,
      appointments: _appointments,
      initialPatient: widget.patient,
      initialPatientId: patientApiId(widget.patient),
      onExistingActiveEncounter: widget.onExistingActiveEncounter,
      onCancelEncounter: (String flowId, Map<String, Object?> payload) {
        return ref
            .read(opdEncounterDialogControllerProvider)
            .cancelEncounter(flowId, payload);
      },
      onCloseEncounter: (String flowId, Map<String, Object?> payload) {
        return ref
            .read(opdEncounterDialogControllerProvider)
            .closeEncounter(flowId, payload);
      },
      onSubmit: (Map<String, Object?> payload) {
        return ref
            .read(opdEncounterDialogControllerProvider)
            .submitPatientEncounter(widget.patient, payload);
      },
    );
  }
}

Future<OpdEncounterDialogResult?> showPatientPinnedOpdEncounterDialog({
  required BuildContext context,
  required Patient patient,
  ValueChanged<OpdFlowSummary>? onExistingActiveEncounter,
}) {
  return showAppDialog<OpdEncounterDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PatientPinnedOpdEncounterDialog(
      patient: patient,
      onExistingActiveEncounter: onExistingActiveEncounter,
    ),
  );
}

Future<void> openPatientOpdEncounterFlow(
  BuildContext context,
  WidgetRef ref,
  Patient patient, {
  required Future<void> Function() onSaved,
}) async {
  OpdFlowSummary? activeEncounterToOpen;
  final OpdEncounterDialogResult? result =
      await showPatientPinnedOpdEncounterDialog(
        context: context,
        patient: patient,
        onExistingActiveEncounter: (OpdFlowSummary flow) {
          activeEncounterToOpen = flow;
        },
      );

  if (result == null || !context.mounted) {
    return;
  }

  if (result.action == OpdEncounterDialogAction.continueWorkflow &&
      result.flow != null) {
    if (!context.mounted) {
      return;
    }
    await showFlowActionsDialog(context: context, flow: result.flow!);
    if (!context.mounted) {
      return;
    }
    await onSaved();
    return;
  }

  if (result.action == OpdEncounterDialogAction.cancelled ||
      result.action == OpdEncounterDialogAction.closed) {
    if (!context.mounted) {
      return;
    }
    await onSaved();
    return;
  }

  if (!context.mounted) {
    return;
  }
  await onSaved();

  final OpdFlowSummary? activeEncounter = result.flow ?? activeEncounterToOpen;
  if (activeEncounter == null || !context.mounted) {
    return;
  }

  await showFlowActionsDialog(context: context, flow: activeEncounter);
}

OpdEncounterDialog buildOpdWorkspaceEncounterDialog({
  required WidgetRef ref,
  required OpdWorkspaceState state,
  OpdAppointment? initialAppointment,
  String? initialAppointmentId,
  String defaultArrivalMode = 'WALK_IN',
  String? defaultProviderId,
  ValueChanged<OpdFlowSummary>? onExistingActiveEncounter,
  bool includeEncounterLifecycleCallbacks = true,
}) {
  return OpdEncounterDialog(
    providerSchedules: state.providerSchedules,
    appointments: state.appointments.items,
    activeFlows: <OpdFlowSummary>[
      ...state.flows.items,
      ...state.triageQueue.items,
    ],
    initialAppointment: initialAppointment,
    initialAppointmentId: initialAppointmentId,
    defaultArrivalMode: defaultArrivalMode,
    defaultProviderId: defaultProviderId,
    onSubmit: (Map<String, Object?> payload) {
      return ref
          .read(opdWorkspaceControllerProvider.notifier)
          .submitOpdEncounter(payload);
    },
    onExistingActiveEncounter: onExistingActiveEncounter,
    onCancelEncounter: includeEncounterLifecycleCallbacks
        ? (String flowId, Map<String, Object?> payload) {
            return ref
                .read(opdWorkspaceControllerProvider.notifier)
                .cancelOpdEncounter(flowId, payload);
          }
        : null,
    onCloseEncounter: includeEncounterLifecycleCallbacks
        ? (String flowId, Map<String, Object?> payload) {
            return ref
                .read(opdWorkspaceControllerProvider.notifier)
                .closeOpdEncounter(flowId, payload);
          }
        : null,
  );
}

Future<void> openOpdWorkspaceEncounterFlow(
  BuildContext context,
  WidgetRef ref,
  OpdWorkspaceState state,
) async {
  OpdFlowSummary? activeEncounterToOpen;
  final OpdEncounterDialogResult? result = await showOpdEncounterDialog(
    context: context,
    dialog: buildOpdWorkspaceEncounterDialog(
      ref: ref,
      state: state,
      onExistingActiveEncounter: (OpdFlowSummary flow) {
        activeEncounterToOpen = flow;
      },
    ),
  );

  if (result == null || !context.mounted) {
    return;
  }

  void showSavedMessage() {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }

  if (result.action == OpdEncounterDialogAction.continueWorkflow &&
      result.flow != null) {
    final bool? changed = await showFlowActionsDialog(
      context: context,
      flow: result.flow!,
    );
    if (changed == true && context.mounted) {
      showSavedMessage();
    }
    return;
  }

  if (result.action == OpdEncounterDialogAction.cancelled ||
      result.action == OpdEncounterDialogAction.closed) {
    showSavedMessage();
    return;
  }

  final OpdFlowSummary? existingFlow = result.flow ?? activeEncounterToOpen;
  if (existingFlow != null) {
    final bool? changed = await showFlowActionsDialog(
      context: context,
      flow: existingFlow,
    );
    if (changed == true && context.mounted) {
      showSavedMessage();
    }
    return;
  }

  showSavedMessage();
}

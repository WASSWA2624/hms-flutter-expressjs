import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_encounter_dialog_controller.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';

/// Patient-registry host for the shared OPD encounter surface with a pinned patient.
///
/// Does not own a parallel clinical body — it composes [OpdEncounterDialog] with
/// patient identity already resolved. Prefer [showPatientPinnedOpdEncounterDialog]
/// / [openPatientOpdEncounterFlow] at call sites.
class PatientPinnedOpdEncounterDialog extends ConsumerWidget {
  const PatientPinnedOpdEncounterDialog({
    required this.patient,
    this.onExistingActiveEncounter,
    super.key,
  });

  final Patient patient;
  final ValueChanged<OpdFlowSummary>? onExistingActiveEncounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return buildPatientPinnedOpdEncounterDialog(
      ref: ref,
      patient: patient,
      onExistingActiveEncounter: onExistingActiveEncounter,
    );
  }
}

/// Builds the canonical [OpdEncounterDialog] for a patient-registry pin.
///
/// Schedules, appointments, and providers are loaded by the encounter dialog
/// through [OpdEncounterDialogController]; callers only pass resolved patient IDs.
OpdEncounterDialog buildPatientPinnedOpdEncounterDialog({
  required WidgetRef ref,
  required Patient patient,
  ValueChanged<OpdFlowSummary>? onExistingActiveEncounter,
}) {
  return OpdEncounterDialog(
    providerSchedules: const <OpdProviderSchedule>[],
    appointments: const <OpdAppointment>[],
    initialPatient: patient,
    initialPatientId: patientApiId(patient),
    onExistingActiveEncounter: onExistingActiveEncounter,
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
          .submitPatientEncounter(patient, payload);
    },
  );
}

/// Builds the canonical encounter dialog when only appointment context exists.
///
/// This keeps sparse appointment action hosts on the same shared start surface
/// instead of falling back to a direct check-in mutation.
OpdEncounterDialog buildAppointmentPinnedOpdEncounterDialog({
  required WidgetRef ref,
  required OpdAppointment appointment,
  ValueChanged<OpdFlowSummary>? onExistingActiveEncounter,
}) {
  return OpdEncounterDialog(
    providerSchedules: const <OpdProviderSchedule>[],
    appointments: <OpdAppointment>[appointment],
    initialAppointment: appointment,
    initialAppointmentId: appointment.apiId,
    defaultArrivalMode: 'ONLINE_APPOINTMENT',
    defaultProviderId: appointment.providerUserId,
    onExistingActiveEncounter: onExistingActiveEncounter,
    onSubmit: (Map<String, Object?> payload) {
      return ref
          .read(opdEncounterDialogControllerProvider)
          .submitEncounter(payload);
    },
  );
}

/// Opens the pinned-patient OPD encounter through [showOpdEncounterDialog].
///
/// Prefer [openPatientOpdEncounterFlow] when a [WidgetRef] is available so the
/// encounter opens via [buildPatientPinnedOpdEncounterDialog] directly.
Future<OpdEncounterDialogResult?> showPatientPinnedOpdEncounterDialog({
  required BuildContext context,
  required Patient patient,
  ValueChanged<OpdFlowSummary>? onExistingActiveEncounter,
}) {
  return showOpdEncounterDialog(
    context: context,
    dialog: PatientPinnedOpdEncounterDialog(
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
  final OpdEncounterDialogResult? result = await showOpdEncounterDialog(
    context: context,
    dialog: buildPatientPinnedOpdEncounterDialog(
      ref: ref,
      patient: patient,
      onExistingActiveEncounter: (OpdFlowSummary flow) {
        activeEncounterToOpen = flow;
      },
    ),
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
  Patient? initialPatient,
  String? initialPatientId,
  String? visitQueueId,
  String defaultArrivalMode = 'WALK_IN',
  String? defaultProviderId,
  ValueChanged<OpdFlowSummary>? onExistingActiveEncounter,
  bool includeEncounterLifecycleCallbacks = true,
}) {
  final String? linkedVisitQueueId = visitQueueId?.trim();
  return OpdEncounterDialog(
    providerSchedules: state.providerSchedules,
    appointments: state.appointments.items,
    activeFlows: <OpdFlowSummary>[
      ...state.flows.items,
      ...state.triageQueue.items,
    ],
    initialPatient: initialPatient,
    initialPatientId: initialPatientId,
    initialAppointment: initialAppointment,
    initialAppointmentId: initialAppointmentId,
    defaultArrivalMode: defaultArrivalMode,
    defaultProviderId: defaultProviderId,
    onSubmit: (Map<String, Object?> payload) {
      final bool linkingVisitQueue =
          linkedVisitQueueId != null && linkedVisitQueueId.isNotEmpty;
      final Map<String, Object?> merged = <String, Object?>{...payload};
      if (linkingVisitQueue) {
        merged['visit_queue_id'] = linkedVisitQueueId;
        // startOpdFlow already reuses open encounters for the queue/patient.
        // Avoid PATCH /context when linking a desk queue row — that path 404s
        // when the dialog's "active encounter" id is stale or unresolvable.
        merged.remove('existing_encounter_id');
        if (merged['force_new_encounter'] != true) {
          merged['reuse_open_encounter'] = true;
        }
      }
      return ref
          .read(opdWorkspaceControllerProvider.notifier)
          .submitOpdEncounter(merged);
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

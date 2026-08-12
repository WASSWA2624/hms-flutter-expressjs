import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/opd/presentation/opd_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_encounter_flow.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart'
    show opdFrontDeskActionRequirement;
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Result of [showQueueActionsDialog].
///
/// When [startedFlow] is set, the caller should open Flow Actions with that
/// summary (queue hub closes first so clinical actions are not nested under it).
final class QueueActionsOutcome {
  const QueueActionsOutcome({this.changed = false, this.startedFlow});

  final bool changed;
  final OpdFlowSummary? startedFlow;

  bool get didChange => changed || startedFlow != null;
}

/// Shared queue status / doctor / prioritize actions for OPD and Reception.
///
/// Set [allowStartEncounter] on OPD so staff can open the clinical Flow Actions
/// hub (vitals, triage routing, doctor/nurse work) after starting the visit.
Future<QueueActionsOutcome?> showQueueActionsDialog({
  required BuildContext context,
  required OpdQueueEntry entry,
  AccessRequirement actionRequirement = opdFrontDeskActionRequirement,
  AccessRequirement startEncounterRequirement = opdStartEncounterRequirement,
  bool allowStartEncounter = false,
}) {
  return showAppDialog<QueueActionsOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => QueueActionsDialog(
      entry: entry,
      actionRequirement: actionRequirement,
      startEncounterRequirement: startEncounterRequirement,
      allowStartEncounter: allowStartEncounter,
    ),
  );
}

bool isOpdQueueTerminalStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'CLOSED' => true,
    _ => false,
  };
}

bool _queueEntryHasProvider(OpdQueueEntry entry) {
  final String? providerId = entry.providerUserId?.trim();
  return providerId != null && providerId.isNotEmpty;
}

String? _queueEntryPatientApiId(OpdQueueEntry entry) => entry.patientApiId;

class QueueActionsDialog extends ConsumerWidget {
  const QueueActionsDialog({
    required this.entry,
    this.actionRequirement = opdFrontDeskActionRequirement,
    this.startEncounterRequirement = opdStartEncounterRequirement,
    this.allowStartEncounter = false,
    super.key,
  });

  final OpdQueueEntry entry;

  /// Front-desk write gate. Reception passes `receptionFrontDeskWriteRequirement`.
  final AccessRequirement actionRequirement;

  /// Gate for starting an OPD encounter from this queue row (OPD only).
  final AccessRequirement startEncounterRequirement;

  /// When true (OPD Queue), shows Start encounter and opens Flow Actions after.
  final bool allowStartEncounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final bool terminal = isOpdQueueTerminalStatus(entry.status);
    final bool hasProvider = _queueEntryHasProvider(entry);
    final String doctorActionLabel = hasProvider
        ? l10n.opdChangeDoctorAction
        : l10n.opdAssignDoctorAction;
    final bool alreadyPrioritized = entry.isPrioritized;

    return AppDialog(
      title: Text(l10n.opdQueueActionsTitle),
      icon: const Icon(AppActionIcons.queue),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 680,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          OpdWorkflowContextPanel(
            patientName: entry.displayTitle,
            patientNumber: entry.patientIdentifier ?? '',
            currentStep: opdStageDisplayLabel(l10n, entry.status),
            currentStepCode: entry.status,
            phoneLabel: entry.patientPhone,
            // Single patient section — do not wrap in "Encounter context".
            showTitle: false,
            initiallyExpanded: true,
            expandedFields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.opdProviderColumnLabel,
                value: entry.providerDisplayName ?? l10n.profileUnknownValue,
                icon: Icons.medical_services_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.opdTimeColumnLabel,
                value: entry.queuedAt == null
                    ? l10n.profileUnknownValue
                    : AppFormatters.dateTime(entry.queuedAt!, locale),
                icon: Icons.schedule_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.opdReasonLabel,
                value: entry.appointmentReason ?? l10n.profileUnknownValue,
                icon: Icons.notes_outlined,
              ),
            ],
          ),
          if (!terminal)
            AppQuickActions(
              title: l10n.patientsQuickActionsTitle,
              permissionActions: <AppPermissionActionItem>[
                if (allowStartEncounter)
                  AppPermissionActionItem(
                    requirement: startEncounterRequirement,
                    label: l10n.opdStartEncounterAction,
                    icon: AppActionIcons.personAdd,
                    fullWidth: true,
                    variant: AppButtonVariant.primary,
                    tooltip: l10n.opdStartEncounterTooltip,
                    onPressed: () =>
                        unawaited(_openStartEncounter(context, ref)),
                  ),
                if (!alreadyPrioritized)
                  AppPermissionActionItem(
                    requirement: actionRequirement,
                    label: l10n.opdPrioritizeAction,
                    icon: AppActionIcons.priority,
                    fullWidth: true,
                    tooltip: l10n.opdPrioritizeQueueDescription,
                    onPressed: () => unawaited(_openPrioritize(context, ref)),
                  ),
                AppPermissionActionItem(
                  requirement: actionRequirement,
                  label: l10n.opdMoveQueueAction,
                  icon: AppActionIcons.move,
                  fullWidth: true,
                  tooltip: l10n.opdMoveQueueTitle,
                  onPressed: () => unawaited(_openChangeStatus(context)),
                ),
                AppPermissionActionItem(
                  requirement: actionRequirement,
                  label: doctorActionLabel,
                  icon: AppActionIcons.assignDoctor,
                  fullWidth: true,
                  onPressed: () => unawaited(_openAssignDoctor(context)),
                ),
              ],
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _openStartEncounter(BuildContext context, WidgetRef ref) async {
    OpdWorkspaceState? workspace = _readWorkspaceState(ref);
    if (workspace == null) {
      await ref.read(opdWorkspaceControllerProvider.notifier).refresh();
      if (!context.mounted) {
        return;
      }
      workspace = _readWorkspaceState(ref);
    }
    if (workspace == null || !context.mounted) {
      return;
    }

    // Match startOpdFromQueue: desk queue rows already carry appointment linkage
    // on the backend. Forcing ONLINE_APPOINTMENT / appointment mode here caused
    // start failures (terminal appointments, patient mismatches, missing IDs).
    final String? patientId = _queueEntryPatientApiId(entry);

    OpdFlowSummary? activeEncounterToOpen;
    final OpdEncounterDialogResult? dialogResult = await showOpdEncounterDialog(
      context: context,
      dialog: buildOpdWorkspaceEncounterDialog(
        ref: ref,
        state: workspace,
        initialPatientId: patientId,
        defaultArrivalMode: 'WALK_IN',
        defaultProviderId: entry.providerUserId,
        visitQueueId: entry.apiId,
        includeEncounterLifecycleCallbacks: false,
        onExistingActiveEncounter: (OpdFlowSummary flow) {
          activeEncounterToOpen = flow;
        },
      ),
    );
    if (!context.mounted || dialogResult == null) {
      return;
    }

    final OpdFlowSummary? startedFlow =
        switch (dialogResult.action) {
          OpdEncounterDialogAction.submit ||
          OpdEncounterDialogAction.continueWorkflow =>
            dialogResult.flow ?? activeEncounterToOpen,
          OpdEncounterDialogAction.cancelled ||
          OpdEncounterDialogAction.closed => null,
        };

    Navigator.of(context).pop(
      QueueActionsOutcome(changed: true, startedFlow: startedFlow),
    );
  }

  OpdWorkspaceState? _readWorkspaceState(WidgetRef ref) {
    return ref
        .read(opdWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (OpdWorkspaceState state) => state,
          failure: (_) => null,
        );
  }

  Future<void> _openPrioritize(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppTextActionDialog(
        title: l10n.opdPrioritizeQueueTitle,
        description: l10n.opdPrioritizeQueueDescription,
        fieldLabel: l10n.opdFieldOptionalLabel(l10n.opdReasonLabel),
        submitLabel: l10n.opdPrioritizeAction,
        submitLeadingIcon: AppActionIcons.priority,
        icon: const Icon(AppActionIcons.priority),
        isRequired: false,
        onSubmit: (String reason) => ref
            .read(opdWorkspaceControllerProvider.notifier)
            .prioritizeQueueEntry(entry, reason),
      ),
    );
    if (changed == true && context.mounted) {
      Navigator.of(context).pop(const QueueActionsOutcome(changed: true));
    }
  }

  Future<void> _openChangeStatus(BuildContext context) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangeQueueStatusDialog(entry: entry),
    );
    if (changed == true && context.mounted) {
      Navigator.of(context).pop(const QueueActionsOutcome(changed: true));
    }
  }

  Future<void> _openAssignDoctor(BuildContext context) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AssignQueueDoctorDialog(entry: entry),
    );
    if (changed == true && context.mounted) {
      Navigator.of(context).pop(const QueueActionsOutcome(changed: true));
    }
  }
}

class _ChangeQueueStatusDialog extends ConsumerStatefulWidget {
  const _ChangeQueueStatusDialog({required this.entry});

  final OpdQueueEntry entry;

  @override
  ConsumerState<_ChangeQueueStatusDialog> createState() =>
      _ChangeQueueStatusDialogState();
}

class _ChangeQueueStatusDialogState
    extends ConsumerState<_ChangeQueueStatusDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _status;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _status = _queueStatuses.contains(widget.entry.status)
        ? widget.entry.status
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isBusy = _isSaving;

    return AppDialog(
      title: Text(l10n.opdMoveQueueTitle),
      icon: const Icon(AppActionIcons.move),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !isBusy,
      maxWidth: 720,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppRadioGroup<String>(
              value: _status,
              labelText: l10n.opdFieldRequiredLabel(l10n.opdQueueStatusLabel),
              enabled: !isBusy,
              layout: AppRadioGroupLayout.wrap,
              wrapColumns: 2,
              itemMinWidth: 260,
              validator: (String? value) =>
                  value == null ? l10n.validationRequired : null,
              onChanged: (String? value) => setState(() => _status = value),
              options: <AppRadioOption<String>>[
                for (final String value in _queueStatuses)
                  AppRadioOption<String>(
                    value: value,
                    label: opdStageDisplayLabel(l10n, value),
                    description: opdQueueStatusDescription(l10n, value),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.opdMoveQueueAction,
        isBusy,
        isBusy ? null : _submit,
        submitLeadingIcon: AppActionIcons.move,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .moveQueueEntry(widget.entry, <String, Object?>{'status': _status});
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

class _AssignQueueDoctorDialog extends ConsumerStatefulWidget {
  const _AssignQueueDoctorDialog({required this.entry});

  final OpdQueueEntry entry;

  @override
  ConsumerState<_AssignQueueDoctorDialog> createState() =>
      _AssignQueueDoctorDialogState();
}

class _AssignQueueDoctorDialogState
    extends ConsumerState<_AssignQueueDoctorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _providerId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _providerId = widget.entry.providerUserId;
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(opdWorkspaceControllerProvider.notifier)
            .ensureQueueProviderOptionsLoaded(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<OpdWorkspaceState>> workspace = ref.watch(
      opdWorkspaceControllerProvider,
    );
    OpdWorkspaceState? workspaceState;
    workspace.asData?.value.when(
      success: (OpdWorkspaceState value) => workspaceState = value,
      failure: (_) {},
    );
    final bool isLoadingProviders =
        workspace.isLoading ||
        (workspaceState?.isRefreshingQueueProviders ?? false);
    // Keep the doctor select enabled while options load so users can type to
    // search immediately; only block input while the mutation is in flight.
    final bool isSaving = _isSaving;
    final List<OpdProviderOption> providers =
        workspaceState?.queueProviderOptions ?? const <OpdProviderOption>[];
    final List<OpdProviderSchedule> schedules =
        workspaceState?.providerSchedules ?? const <OpdProviderSchedule>[];
    final Object? providerFailure = workspaceState?.lastFailure;
    final AppFailure? displayFailure =
        _failure ??
        (providerFailure is AppFailure &&
                providers.isEmpty &&
                !isLoadingProviders
            ? providerFailure
            : null);
    final String actionLabel = _queueEntryHasProvider(widget.entry)
        ? l10n.opdChangeDoctorAction
        : l10n.opdAssignDoctorAction;

    return AppDialog(
      title: Text(actionLabel),
      icon: const Icon(AppActionIcons.assignDoctor),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !isSaving,
      maxWidth: 680,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            if (displayFailure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: displayFailure,
              ),
            AppSelectField<String>.searchable(
              value: _providerId,
              options: opdProviderSelectOptions(
                providers: providers,
                schedules: schedules,
                unknownProviderLabel: l10n.profileUnknownValue,
              ),
              labelText: l10n.opdFieldRequiredLabel(l10n.opdSearchProviderLabel),
              helperText:
                  providers.isEmpty && schedules.isEmpty && !isLoadingProviders
                  ? l10n.opdNoProvidersHelper
                  : l10n.opdSearchProviderHelper,
              emptyResultsText: l10n.appSelectNoResults,
              semanticLabel: l10n.opdFieldRequiredLabel(
                l10n.opdSearchProviderLabel,
              ),
              enabled: !isSaving,
              isLoading: isLoadingProviders,
              validator: (String? value) {
                final String? trimmed = value?.trim();
                if (trimmed == null || trimmed.isEmpty) {
                  return l10n.validationRequired;
                }
                return null;
              },
              onChanged: (String? value) {
                setState(() {
                  _providerId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        actionLabel,
        isSaving,
        isSaving || isLoadingProviders ? null : _submit,
        submitLeadingIcon: AppActionIcons.assignDoctor,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? providerId = _providerId?.trim();
    if (providerId == null || providerId.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .moveQueueEntry(widget.entry, <String, Object?>{
          'provider_user_id': providerId,
        });
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

const List<String> _queueStatuses = <String>[
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW',
];

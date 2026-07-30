import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_detail_panel.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_format.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> openIcuDetailDialog(
  BuildContext context,
  WidgetRef ref,
  IcuWorkspaceState fallbackState,
  IcuPatientSummary summary,
  AccessRequirement writeRequirement, {
  AccessRequirement readRequirement = icuWorkspaceReadRequirement,
  IcuNextActionKind? omitNextActionKind,
}) async {
  final IcuWorkspaceController controller = ref.read(
    icuWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectPatient(summary);
  if (context.mounted) {
    showIcuFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final IcuWorkspaceState state = readIcuWorkspaceState(ref) ?? fallbackState;
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
      content: Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final IcuWorkspaceState current =
              readIcuWorkspaceState(ref) ?? state;
          return IcuStayDetailPanel(
            state: current,
            writeRequirement: writeRequirement,
            readRequirement: readRequirement,
            omitNextActionKind: omitNextActionKind,
          );
        },
      ),
    ),
  );
}

/// Panel deep links open the mutation dialog directly (no empty detail shell).
///
/// When the user lacks the mutation gate, falls back to read-only detail
/// (forbidden deep-link write) instead of mounting the write dialog.
Future<void> openIcuFocusedAction(
  BuildContext context,
  WidgetRef ref,
  IcuWorkspaceState fallbackState,
  IcuPatientSummary summary,
  IcuDetailPanel panel, {
  AccessRequirement writeRequirement = icuWorkspaceWriteRequirement,
  AccessRequirement readRequirement = icuWorkspaceReadRequirement,
}) async {
  final IcuWorkspaceController controller = ref.read(
    icuWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectPatient(summary);
  if (context.mounted) {
    showIcuFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final IcuWorkspaceState state = readIcuWorkspaceState(ref) ?? fallbackState;
  if (state.selectedDetail == null) {
    return;
  }

  final AccessRequirement panelRequirement = icuFocusedPanelRequirement(panel);
  if (!panelRequirement.isAllowed(ref.read(appAccessPolicyProvider))) {
    await openIcuDetailDialog(
      context,
      ref,
      state,
      summary,
      writeRequirement,
      readRequirement: readRequirement,
    );
    return;
  }

  await openIcuFocusPanel(context, panel, state.referenceData);
}

Future<void> openIcuFocusPanel(
  BuildContext context,
  IcuDetailPanel panel,
  IcuReferenceData referenceData,
) async {
  switch (panel) {
    case IcuDetailPanel.vitals:
      await openIcuVitalsDialog(context);
    case IcuDetailPanel.alerts:
      await openIcuAlertDialog(context);
    case IcuDetailPanel.observations:
      await openIcuObservationDialog(context);
    case IcuDetailPanel.orders:
      await openIcuLabOrderDialog(context);
    case IcuDetailPanel.transfer:
      await openIcuTransferDialog(context, referenceData);
    case IcuDetailPanel.discharge:
      await openIcuReadinessDialog(context);
  }
}

IcuWorkspaceState? readIcuWorkspaceState(WidgetRef ref) {
  return ref
      .read(icuWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (IcuWorkspaceState state) => state, failure: (_) => null);
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
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.icuObservationDialogTitle),
      icon: const Icon(Icons.note_add_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppTextField(
              controller: _observationController,
              labelText: l10n.icuObservationFieldLabel,
              enabled: !_isSaving,
              maxLines: 5,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.icuRecordActionLabel,
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
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.icuVitalsDialogTitle),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 780,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          AppVitalsForm(
            temperatureController: _temperatureController,
            systolicController: _systolicController,
            diastolicController: _diastolicController,
            heartRateController: _heartRateController,
            respiratoryRateController: _respiratoryRateController,
            oxygenSaturationController: _oxygenController,
            temperatureLabel: l10n.patientsTemperatureLabel,
            systolicLabel: l10n.patientsSystolicLabel,
            diastolicLabel: l10n.patientsDiastolicLabel,
            heartRateLabel: l10n.patientsHeartRateLabel,
            respiratoryRateLabel: l10n.patientsRespiratoryRateLabel,
            oxygenSaturationLabel: l10n.patientsOxygenSaturationLabel,
            bloodPressureLabel: l10n.patientsBloodPressureLabel,
            unitLabel: l10n.patientsVitalUnitLabel,
            enabled: !_isSaving,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.icuVitalsUpdateActionLabel,
        _isSaving,
        _submit,
      ),
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
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.icuAlertDialogTitle),
      icon: const Icon(Icons.notification_important_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppSelectField<String>(
              value: _severity,
              labelText: l10n.icuAlertSeverityLabel,
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
              labelText: l10n.icuAlertMessageLabel,
              enabled: !_isSaving,
              maxLines: 3,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.icuAlertAddActionLabel,
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

class _TransferRequestDialog extends ConsumerWidget {
  const _TransferRequestDialog({required this.referenceData});

  final IcuReferenceData referenceData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceState? state = ref.watch(icuWorkspaceControllerProvider)
        .asData
        ?.value
        .when(success: (IcuWorkspaceState s) => s, failure: (_) => null);
    final String? fromWardId = _resolveIcuFromWardId(
      state?.selectedDetail,
      referenceData.wards,
    );

    final List<IcuWardOption> destinationWards = _icuDestinationWards(
      referenceData.wards,
      fromWardId,
    );

    return AppTransferRequestDialog(
      title: l10n.icuTransferDialogTitle,
      wardLabel: l10n.icuTransferTargetWardLabel,
      wardIdLabel: l10n.icuTransferTargetWardIdLabel,
      submitLabel: l10n.icuActionRequestTransfer,
      requiredMessage: l10n.validationRequired,
      wardOptions: <AppSelectOption<String>>[
        for (final IcuWardOption ward in destinationWards)
          AppSelectOption<String>(
            value: ward.id,
            label: joinDisplay(<String?>[
              ward.displayTitle,
              apiLabel(ward.wardType ?? ''),
            ]),
          ),
      ],
      onSubmit: (String toWardId) {
        return ref
            .read(icuWorkspaceControllerProvider.notifier)
            .requestTransfer(toWardId: toWardId, fromWardId: fromWardId);
      },
    );
  }
}

List<IcuWardOption> _icuDestinationWards(
  List<IcuWardOption> wards,
  String? currentWardId,
) {
  if (currentWardId == null || currentWardId.isEmpty) {
    return wards;
  }
  return wards
      .where((IcuWardOption ward) => ward.id != currentWardId)
      .toList(growable: false);
}

String? _resolveIcuFromWardId(
  IcuPatientDetail? detail,
  List<IcuWardOption> wards,
) {
  final String? wardName = detail?.summary.wardName?.trim();
  if (wardName == null || wardName.isEmpty || wards.isEmpty) {
    return null;
  }
  for (final IcuWardOption ward in wards) {
    final String name = (ward.name ?? '').trim();
    if (ward.id == wardName ||
        (name.isNotEmpty && name.toLowerCase() == wardName.toLowerCase()) ||
        ward.displayTitle.toLowerCase() == wardName.toLowerCase()) {
      return ward.id;
    }
  }
  return null;
}

class _ManageTransferDialog extends ConsumerStatefulWidget {
  const _ManageTransferDialog();

  @override
  ConsumerState<_ManageTransferDialog> createState() =>
      _ManageTransferDialogState();
}

class _ManageTransferDialogState extends ConsumerState<_ManageTransferDialog> {
  String? _bedId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final IcuWorkspaceState? state = ref
        .read(icuWorkspaceControllerProvider)
        .asData
        ?.value
        .when(success: (IcuWorkspaceState s) => s, failure: (_) => null);
    if (state != null && state.bedBoard.beds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(icuWorkspaceControllerProvider.notifier).loadBedBoard();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceState? state = ref
        .watch(icuWorkspaceControllerProvider)
        .asData
        ?.value
        .when(success: (IcuWorkspaceState s) => s, failure: (_) => null);
    final IcuPatientDetail? detail = state?.selectedDetail;
    final IcuTransferRequest? open = detail?.transferRequests
        .where((IcuTransferRequest item) => _isOpenTransfer(item.status))
        .firstOrNull;

    if (open == null) {
      return AppDialog(
        title: Text(l10n.icuManageTransferDialogTitle),
        icon: const Icon(Icons.published_with_changes_outlined),
        content: Text(l10n.icuTransferNoOpenLabel),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      );
    }

    final List<IcuBed> availableBeds =
        (state?.bedBoard.beds ?? const <IcuBed>[])
            .where((IcuBed bed) => bed.isAvailable)
            .toList(growable: false);
    final String status = (open.status ?? '').toUpperCase();
    final List<IcuTransferAction> actions = _availableActions(status);

    return AppDialog(
      title: Text(l10n.icuManageTransferDialogTitle),
      icon: const Icon(Icons.published_with_changes_outlined),
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          Text(
            joinDisplay(<String?>[
              apiLabel(open.status ?? ''),
              open.fromWardName,
              open.toWardName,
            ]),
          ),
          if (actions.contains(IcuTransferAction.complete))
            AppSelectField<String>.searchable(
              value: _bedId,
              labelText: l10n.icuTransferSelectBedLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                for (final IcuBed bed in availableBeds)
                  AppSelectOption<String>(
                    value: bed.id,
                    label: bed.locationLabel,
                  ),
              ],
              onChanged: (String? value) => setState(() => _bedId = value),
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        for (final IcuTransferAction action in actions)
          AppButton.primary(
            label: _actionLabel(l10n, action),
            isLoading: _isSaving,
            onPressed: () => _submit(open, action),
          ),
      ],
    );
  }

  List<IcuTransferAction> _availableActions(String status) {
    return switch (status) {
      'REQUESTED' => <IcuTransferAction>[
        IcuTransferAction.approve,
        IcuTransferAction.cancel,
      ],
      'APPROVED' => <IcuTransferAction>[
        IcuTransferAction.start,
        IcuTransferAction.cancel,
      ],
      'IN_PROGRESS' => <IcuTransferAction>[
        IcuTransferAction.complete,
        IcuTransferAction.cancel,
      ],
      _ => <IcuTransferAction>[IcuTransferAction.cancel],
    };
  }

  String _actionLabel(AppLocalizations l10n, IcuTransferAction action) {
    return switch (action) {
      IcuTransferAction.approve => l10n.icuTransferActionApprove,
      IcuTransferAction.start => l10n.icuTransferActionStart,
      IcuTransferAction.complete => l10n.icuTransferActionComplete,
      IcuTransferAction.cancel => l10n.icuTransferActionCancel,
    };
  }

  Future<void> _submit(
    IcuTransferRequest open,
    IcuTransferAction action,
  ) async {
    if (action.requiresBed && (_bedId == null || _bedId!.isEmpty)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.updateTransfer(
      transferRequestId: open.id,
      action: action,
      toBedId: action.requiresBed ? _bedId : null,
    );
    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _failure = failure;
        _isSaving = false;
      });
      return;
    }
    Navigator.of(context).pop(true);
    // After a completed step-down, prompt to end the ICU stay if still active.
    if (action == IcuTransferAction.complete) {
      final IcuWorkspaceState? latest = readIcuWorkspaceState(ref);
      final bool stillActive = latest?.selectedDetail?.activeStay != null;
      if (stillActive && context.mounted) {
        unawaited(promptIcuEndStayAfterStepDown(context));
      }
    }
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
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.icuReadinessDialogTitle),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          description: l10n.icuReadinessDescription,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppTextField(
              controller: _summaryController,
              labelText: l10n.icuReadinessNoteLabel,
              enabled: !_isSaving,
              maxLines: 5,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.icuReadinessMarkActionLabel,
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

class _AssignBedDialog extends ConsumerStatefulWidget {
  const _AssignBedDialog();

  @override
  ConsumerState<_AssignBedDialog> createState() => _AssignBedDialogState();
}

class _AssignBedDialogState extends ConsumerState<_AssignBedDialog> {
  final GlobalKey<FormState> _loadFailureFormKey = GlobalKey<FormState>();
  bool _isLoadingBeds = false;
  AppFailure? _loadFailure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureBedsLoaded());
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceState? state = ref
        .watch(icuWorkspaceControllerProvider)
        .asData
        ?.value
        .when(success: (IcuWorkspaceState s) => s, failure: (_) => null);
    final IcuBedBoard bedBoard = state?.bedBoard ?? const IcuBedBoard();
    final bool isRefreshingBeds = state?.isRefreshingBeds ?? false;
    final bool isInitialBedLoad =
        (_isLoadingBeds || isRefreshingBeds) && bedBoard.beds.isEmpty;

    if (isInitialBedLoad) {
      return AppDialog(
        title: Text(l10n.icuAssignBedDialogTitle),
        icon: const Icon(Icons.bed_outlined),
        closeEnabled: false,
        initialMaximized: false,
        pinActionsToBottom: true,
        content: Center(
          child: AppLoadingIndicator.compact(
            title: l10n.icuLoadingBoardTitle,
            body: l10n.icuLoadingBoardBody,
            semanticLabel: l10n.icuLoadingBoardTitle,
          ),
        ),
        actions: clinicalActionDialogActions(
          context,
          l10n.icuActionAssignBed,
          true,
          null,
          submitLeadingIcon: Icons.bed_outlined,
        ),
      );
    }

    if (_loadFailure != null && bedBoard.beds.isEmpty) {
      return AppDialog(
        title: Text(l10n.icuAssignBedDialogTitle),
        icon: const Icon(Icons.bed_outlined),
        initialMaximized: false,
        pinActionsToBottom: true,
        content: AppFormShell(
          formKey: _loadFailureFormKey,
          formStatus: appFormFailureStatus(context, _loadFailure),
          children: const <Widget>[],
        ),
        actions: clinicalActionDialogActions(
          context,
          l10n.icuActionAssignBed,
          false,
          null,
          submitLeadingIcon: Icons.bed_outlined,
        ),
      );
    }

    return ClinicalAdmissionActionDialog(
      title: l10n.icuAssignBedDialogTitle,
      submitLabel: l10n.icuActionAssignBed,
      submitLeadingIcon: Icons.bed_outlined,
      initialMaximized: false,
      maxWidth: 560,
      referenceData: _icuAssignBedReferenceData(context, bedBoard),
      onSubmit: (ClinicalActionAdmissionInput input) {
        final ClinicalActionCatalogOption? bed = input.bed;
        if (bed == null) {
          return Future<AppFailure?>.value(AppFailure.validation());
        }
        return ref
            .read(icuWorkspaceControllerProvider.notifier)
            .assignBed(bed.apiId);
      },
    );
  }

  Future<void> _ensureBedsLoaded() async {
    if (!mounted) {
      return;
    }
    final IcuWorkspaceState? state = ref
        .read(icuWorkspaceControllerProvider)
        .asData
        ?.value
        .when(success: (IcuWorkspaceState s) => s, failure: (_) => null);
    if (state != null && state.bedBoard.beds.isNotEmpty) {
      return;
    }
    setState(() {
      _isLoadingBeds = true;
      _loadFailure = null;
    });
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .loadBedBoard();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingBeds = false;
      _loadFailure = failure;
    });
  }
}

ClinicalActionReferenceData _icuAssignBedReferenceData(
  BuildContext context,
  IcuBedBoard bedBoard,
) {
  final AppLocalizations l10n = context.l10n;
  final Map<String, ClinicalActionCatalogOption> wards =
      <String, ClinicalActionCatalogOption>{
        for (final IcuBedWard ward in bedBoard.wards)
          ward.id: ClinicalActionCatalogOption(
            id: ward.id,
            name: ward.displayTitle,
            category: ward.wardType,
            status: 'ACTIVE',
          ),
      };
  final Map<String, ClinicalActionCatalogOption> rooms =
      <String, ClinicalActionCatalogOption>{};
  final List<ClinicalActionCatalogOption> beds =
      <ClinicalActionCatalogOption>[];

  for (final IcuBed bed in bedBoard.beds) {
    if (!bed.isAvailable) {
      continue;
    }
    final String wardId = _icuAssignBedWardId(bed);
    final String roomId = _icuAssignBedRoomId(bed, wardId);
    wards.putIfAbsent(
      wardId,
      () => ClinicalActionCatalogOption(
        id: wardId,
        name: _icuAssignBedFirstDisplay(<String?>[
          bed.wardName,
          bed.wardId,
          l10n.profileUnknownValue,
        ]),
        category: bed.wardType,
      ),
    );
    rooms.putIfAbsent(
      roomId,
      () => ClinicalActionCatalogOption(
        id: roomId,
        name: _icuAssignBedFirstDisplay(<String?>[
          bed.roomName,
          bed.roomId,
          l10n.profileUnknownValue,
        ]),
        secondaryText: bed.floor,
        parentId: wardId,
      ),
    );
    beds.add(
      ClinicalActionCatalogOption(
        id: bed.id,
        name: bed.label ?? bed.id,
        status: bed.status,
        parentId: wardId,
        secondaryId: roomId,
        secondaryText: bed.locationLabel,
      ),
    );
  }

  return ClinicalActionReferenceData(
    wards: wards.values.toList(growable: false),
    rooms: rooms.values.toList(growable: false),
    availableBeds: beds,
  );
}

const String _icuAssignBedUnknownWardId = 'icu-unknown-ward';
const String _icuAssignBedUnknownRoomIdPrefix = 'icu-unknown-room:';

String _icuAssignBedWardId(IcuBed bed) {
  final String? wardId = bed.wardId?.trim();
  if (wardId == null || wardId.isEmpty) {
    return _icuAssignBedUnknownWardId;
  }
  return wardId;
}

String _icuAssignBedRoomId(IcuBed bed, String wardId) {
  final String? roomId = bed.roomId?.trim();
  if (roomId != null && roomId.isNotEmpty) {
    return roomId;
  }
  final String? roomName = bed.roomName?.trim();
  return '$_icuAssignBedUnknownRoomIdPrefix$wardId:${roomName ?? 'room'}';
}

String _icuAssignBedFirstDisplay(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

class _IcuRoundActionDialog extends ConsumerStatefulWidget {
  const _IcuRoundActionDialog();

  @override
  ConsumerState<_IcuRoundActionDialog> createState() =>
      _IcuRoundActionDialogState();
}

class _IcuRoundActionDialogState extends ConsumerState<_IcuRoundActionDialog> {
  final TextEditingController _notesController = TextEditingController();
  ClinicalRequestBillingSubmit? _billing;
  bool _submitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final ClinicalRequestBillingSubmit? billing = _billing;
    final bool charge =
        billing != null &&
        billing.paymentStatus != ClinicalRequestPaymentStatus.notBilled &&
        billing.totalAmount > 0;
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .addRoundNote(
          notes: _notesController.text.trim(),
          billing: charge ? billing.toPayloadMap() : null,
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
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRequestBillingLineItem> lineItems =
        <ClinicalRequestBillingLineItem>[
          ClinicalRequestBillingLineItem(
            id: 'WARD_ROUND_FEE',
            label: l10n.icuRoundFeeLabel,
          ),
        ];

    return AppDialog(
      title: Text(l10n.icuRoundDialogTitle),
      icon: const Icon(Icons.rate_review_outlined),
      maxWidth: 560,
      scrollable: true,
      closeEnabled: !_submitting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.icuRoundNoteLabel,
            minLines: 3,
            maxLines: 8,
            enabled: !_submitting,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppAccessGate(
            requirement: icuBillingPanelReadRequirement,
            child: ClinicalRequestBillingPanel(
              lineItems: lineItems,
              enabled: !_submitting,
              // Dialog already provides titled chrome — keep sections flat.
              embedded: true,
              onChanged: (ClinicalRequestBillingSubmit value) {
                _billing = value;
              },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_submitting,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.icuRoundAddActionLabel,
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _StartIcuStayDialog extends ConsumerStatefulWidget {
  const _StartIcuStayDialog();

  @override
  ConsumerState<_StartIcuStayDialog> createState() =>
      _StartIcuStayDialogState();
}

class _StartIcuStayDialogState extends ConsumerState<_StartIcuStayDialog> {
  ClinicalRequestBillingSubmit? _billing;
  bool _submitting = false;
  AppFailure? _failure;

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final ClinicalRequestBillingSubmit? billing = _billing;
    final bool charge =
        billing != null &&
        billing.paymentStatus != ClinicalRequestPaymentStatus.notBilled &&
        billing.totalAmount > 0;
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .startIcuStay(billing: charge ? billing.toPayloadMap() : null);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRequestBillingLineItem> lineItems =
        <ClinicalRequestBillingLineItem>[
          ClinicalRequestBillingLineItem(
            id: 'ICU_CRITICAL_CARE_PACKAGE',
            label: l10n.icuCriticalCarePackageFeeLabel,
          ),
          ClinicalRequestBillingLineItem(
            id: 'ICU_BED_DAY',
            label: l10n.icuBedDayFeeLabel,
          ),
        ];

    return AppDialog(
      title: Text(l10n.icuStartStayTitle),
      icon: const Icon(Icons.play_circle_outline),
      maxWidth: 560,
      scrollable: true,
      closeEnabled: !_submitting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          Text(l10n.icuStartStayBody),
          SizedBox(height: Theme.of(context).spacing.md),
          AppAccessGate(
            requirement: icuBillingPanelReadRequirement,
            child: ClinicalRequestBillingPanel(
              lineItems: lineItems,
              enabled: !_submitting,
              // Dialog already provides titled chrome — keep sections flat.
              embedded: true,
              onChanged: (ClinicalRequestBillingSubmit value) {
                _billing = value;
              },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_submitting,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.icuStartStayActionLabel,
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
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

Future<void> openIcuObservationDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ObservationDialog(),
    ),
  );
}

Future<void> openIcuVitalsDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _VitalsDialog(),
    ),
  );
}

Future<void> openIcuAlertDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CriticalAlertDialog(),
    ),
  );
}

Future<void> openIcuRoundDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _IcuRoundActionDialog(),
    ),
  );
}

Future<void> openIcuStartStayDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _StartIcuStayDialog(),
    ),
  );
}

Future<void> openIcuTransferDialog(
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

Future<void> openIcuManageTransferDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ManageTransferDialog(),
    ),
  );
}

Future<void> openIcuReadinessDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReadinessDialog(),
    ),
  );
}

Future<void> openIcuAssignBedDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AssignBedDialog(),
    ),
  );
}

Future<void> openIcuLabOrderDialog(BuildContext context) async {
  final IcuWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(icuWorkspaceControllerProvider.notifier);
  final ClinicalReferenceData referenceData = await controller
      .clinicalReferenceData();
  if (!context.mounted) {
    return;
  }
  final IcuPatientSummary? summary =
      ProviderScope.containerOf(context, listen: false)
          .read(icuWorkspaceControllerProvider)
          .value
          ?.when(
            success: (IcuWorkspaceState state) => state.selectedDetail?.summary,
            failure: (_) => null,
          );
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalLabOrderActionDialog(
        referenceData: referenceData,
        patientContext: ClinicalRequestPatientContext(
          patientName: summary?.patientDisplayName ?? summary?.displayTitle,
          patientId: summary?.patientId,
          encounterId: summary?.encounterId,
        ),
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
              );
            },
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return controller.orderLab(
                labTestIds: labTestIds,
                labPanelIds: labPanelIds,
                billing: billing,
              );
            },
        onUpdate:
            ({
              required String labOrderId,
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return controller.orderLab(
                labTestIds: labTestIds,
                labPanelIds: labPanelIds,
                billing: billing,
              );
            },
      ),
    ),
  );
}

Future<void> openIcuRadiologyOrderDialog(BuildContext context) async {
  final IcuWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(icuWorkspaceControllerProvider.notifier);
  final ClinicalReferenceData referenceData = await controller
      .clinicalReferenceData();
  if (!context.mounted) {
    return;
  }
  final IcuPatientSummary? summary =
      ProviderScope.containerOf(context, listen: false)
          .read(icuWorkspaceControllerProvider)
          .value
          ?.when(
            success: (IcuWorkspaceState state) => state.selectedDetail?.summary,
            failure: (_) => null,
          );
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalRadiologyOrderActionDialog(
        referenceData: referenceData,
        patientContext: ClinicalRequestPatientContext(
          patientName: summary?.patientDisplayName ?? summary?.displayTitle,
          patientId: summary?.patientId,
          encounterId: summary?.encounterId,
        ),
        onSearchRadiologyTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
              );
            },
        onSubmit: controller.orderRadiology,
      ),
    ),
  );
}

Future<void> openIcuPrescriptionDialog(BuildContext context) async {
  final IcuWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(icuWorkspaceControllerProvider.notifier);
  final ClinicalReferenceData referenceData = await controller
      .clinicalReferenceData();
  if (!context.mounted) {
    return;
  }
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        onSubmit: controller.prescribeMedication,
      ),
    ),
  );
}

void openIpdWorkspace(BuildContext context, IcuPatientSummary summary) {
  final String? displayId = summary.displayId?.trim();
  final String location = displayId == null || displayId.isEmpty
      ? AppRoutes.ipd.path
      : AppRoutes.ipd.location(
          queryParameters: <String, String>{'id': displayId},
        );
  context.go(location);
}

/// Opens Billing for the patient — never an ICU-local cashier.
void openIcuBillingWorkspace(BuildContext context, IcuPatientSummary summary) {
  final String? patientId = summary.patientId?.trim();
  final String location = (patientId == null || patientId.isEmpty)
      ? AppRoutes.billing.path
      : AppRoutes.billing.location(
          queryParameters: <String, String>{'patient_id': patientId},
        );
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
  if (context.mounted) {
    context.go(location);
  }
}

void openIpdDischargeClearance(
  BuildContext context,
  IcuPatientSummary summary,
) {
  final String? displayId = summary.displayId?.trim();
  if (displayId == null || displayId.isEmpty) {
    context.go(AppRoutes.ipd.path);
    return;
  }
  context.go(
    AppRoutes.ipd.location(
      queryParameters: <String, String>{'id': displayId, 'panel': 'discharge'},
    ),
  );
}

Future<void> promptIcuEndStayAfterStepDown(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return confirmIcuAction(
    context: context,
    title: l10n.icuStepDownPromptTitle,
    body: l10n.icuStepDownPromptBody,
    actionLabel: l10n.icuActionEndStay,
    onConfirmed: () => ProviderScope.containerOf(
      context,
      listen: false,
    ).read(icuWorkspaceControllerProvider.notifier).transferOut(),
  );
}

Future<void> confirmIcuAction({
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.icuChangesSavedMessage)),
    );
  }
}

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: apiLabel(value)),
  ];
}

bool _isOpenTransfer(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'REQUESTED' || 'APPROVED' || 'IN_PROGRESS' => true,
    _ => false,
  };
}

String icuSummaryHtml(BuildContext context, IcuPatientDetail detail) {
  final AppLocalizations l10n = context.l10n;
  final StringBuffer buffer = StringBuffer()
    ..write(
      PrintFormTemplate.section(
        title: l10n.icuPrintAlertsSection,
        bodyHtml: _alertHtml(l10n, detail.alerts),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: l10n.icuPrintObservationsSection,
        bodyHtml: _observationHtml(l10n, detail.observations),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: l10n.icuPrintVitalsSection,
        bodyHtml: _vitalsHtml(l10n, detail.vitalSigns),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: l10n.icuPrintTransferSection,
        bodyHtml: _readinessHtml(l10n, detail),
      ),
    );
  return buffer.toString();
}

String _alertHtml(AppLocalizations l10n, List<IcuCriticalAlert> alerts) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuCriticalAlert alert in alerts)
      joinDisplay(<String?>[apiLabel(alert.severity ?? ''), alert.message]),
  ], emptyText: l10n.icuNoActiveAlertsListLabel);
}

String _observationHtml(
  AppLocalizations l10n,
  List<IcuObservation> observations,
) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuObservation observation in observations)
      observation.observation ?? '',
  ], emptyText: l10n.icuNoObservationsLabel);
}

String _vitalsHtml(AppLocalizations l10n, List<IcuVitalSign> vitals) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuVitalSign vital in vitals)
      joinDisplay(<String?>[apiLabel(vital.vitalType), vital.displayValue]),
  ], emptyText: l10n.icuNoVitalsLabel);
}

String _readinessHtml(AppLocalizations l10n, IcuPatientDetail detail) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuTransferRequest transfer in detail.transferRequests)
      joinDisplay(<String?>[
        l10n.icuTransferRecordLabel,
        apiLabel(transfer.status ?? ''),
        transfer.toWardName,
      ]),
    for (final IcuDischargeSummary discharge in detail.dischargeSummaries)
      joinDisplay(<String?>[
        l10n.icuDischargeRecordLabel,
        apiLabel(discharge.status ?? ''),
        discharge.summary,
      ]),
  ], emptyText: l10n.icuNoTransferRecordsLabel);
}

void showIcuFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

@immutable
final class DispatchInput {
  const DispatchInput({required this.ambulanceId, required this.status});

  final String ambulanceId;
  final String status;
}

@immutable
final class HandoffInput {
  const HandoffInput({
    required this.destination,
    required this.closeCase,
    this.notes,
  });

  final String destination;
  final String? notes;
  final bool closeCase;
}

typedef QuickArrivalSubmit =
    Future<AppFailure?> Function(EmergencyQuickArrivalInput input);

Future<bool?> showEmergencyQuickArrivalDialog({
  required BuildContext context,
  required QuickArrivalSubmit onSubmit,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => QuickArrivalDialog(onSubmit: onSubmit),
  );
}

class QuickArrivalDialog extends StatefulWidget {
  const QuickArrivalDialog({required this.onSubmit, super.key});

  final QuickArrivalSubmit onSubmit;

  @override
  State<QuickArrivalDialog> createState() => _QuickArrivalDialogState();
}

class _QuickArrivalDialogState extends State<QuickArrivalDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _severity = 'CRITICAL';
  String? _triageLevel = 'LEVEL_2';
  bool _isSubmitting = false;
  AppFailure? _failure;

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
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.emergencyQuickArrivalDialogTitle),
      icon: const Icon(Icons.emergency_outlined),
      semanticLabel: l10n.emergencyQuickArrivalDialogSemanticLabel,
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSubmitting,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSubmitting,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppTextField(
            controller: _firstNameController,
            labelText: l10n.patientsFirstNameLabel,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: _lastNameController,
            labelText: l10n.patientsLastNameLabel,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          AppPhoneField(
            controller: _phoneController,
            labelText: l10n.patientsPhoneLabel,
            countryLabelText: l10n.appPhoneCountryLabel,
            countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
            countryNoResultsText: l10n.appPhoneCountryNoResults,
            numberLabelText: l10n.appPhoneNumberLabel,
            invalidPhoneMessage: l10n.appPhoneInvalidMessage,
          ),
          AppSelectField<String>(
            value: _severity,
            labelText: l10n.emergencyQuickArrivalPriorityLabel,
            isRequired: true,
            options: _quickArrivalSeverityOptions(l10n),
            validator: (String? value) =>
                value == null ? l10n.validationRequired : null,
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
            labelText: l10n.emergencyQuickArrivalInitialTriageLabel,
            options: _quickArrivalTriageOptions(l10n),
            onChanged: (String? value) {
              setState(() {
                _triageLevel = value;
              });
            },
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.emergencyQuickArrivalNotesLabel,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.emergencyQuickArrivalOpenCaseAction,
        _isSubmitting,
        _isSubmitting ? null : _submit,
        submitLeadingIcon: AppActionIcons.add,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final AppFailure? failure = await widget.onSubmit(
      EmergencyQuickArrivalInput(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        severity: _severity,
        phone: nonEmpty(_phoneController.text),
        triageLevel: _triageLevel,
        notes: nonEmpty(_notesController.text),
      ),
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
      _isSubmitting = false;
    });
  }
}

Future<bool?> showEmergencyPriorityDialog({
  required BuildContext context,
  required Future<AppFailure?> Function(String severity) onSubmit,
  String? initialSeverity,
}) {
  final AppLocalizations l10n = context.l10n;
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppSelectActionDialog<String>(
      title: l10n.emergencyPriorityDialogTitle,
      semanticLabel: l10n.emergencyPriorityDialogSemanticLabel,
      icon: const Icon(AppActionIcons.priority),
      fieldLabel: l10n.emergencyPriorityFieldLabel,
      initialValue: normalizedOption(initialSeverity, fallback: 'HIGH'),
      options: severityOptions(l10n),
      cancelLabel: l10n.commonCancelActionLabel,
      submitLabel: l10n.patientsEditAction,
      requiredMessage: l10n.validationRequired,
      submitLeadingIcon: AppActionIcons.edit,
      onSubmit: onSubmit,
    ),
  );
}

typedef EmergencyResponseSubmit = Future<AppFailure?> Function(String notes);

Future<bool?> showEmergencyResponseDialog({
  required BuildContext context,
  required EmergencyResponseSubmit onSubmit,
  String? initialNotes,
}) {
  final AppLocalizations l10n = context.l10n;
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppTextActionDialog(
      title: l10n.emergencyResponseDialogTitle,
      semanticLabel: l10n.emergencyResponseDialogSemanticLabel,
      icon: const Icon(Icons.medical_services_outlined),
      fieldLabel: l10n.emergencyResponseNotesLabel,
      submitLabel: l10n.emergencyResponseMarkAction,
      submitLeadingIcon: AppActionIcons.save,
      initialValue: initialNotes,
      onSubmit: onSubmit,
    ),
  );
}

List<AppSelectOption<String>> _quickArrivalSeverityOptions(
  AppLocalizations l10n,
) {
  return severityOptions(l10n);
}

List<AppSelectOption<String>> _quickArrivalTriageOptions(
  AppLocalizations l10n,
) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'LEVEL_1',
      label: l10n.emergencyTriageLevel1Label,
    ),
    AppSelectOption<String>(
      value: 'LEVEL_2',
      label: l10n.emergencyTriageLevel2Label,
    ),
    AppSelectOption<String>(
      value: 'LEVEL_3',
      label: l10n.emergencyTriageLevel3Label,
    ),
    AppSelectOption<String>(
      value: 'LEVEL_4',
      label: l10n.emergencyTriageLevel4Label,
    ),
    AppSelectOption<String>(
      value: 'LEVEL_5',
      label: l10n.emergencyTriageLevel5Label,
    ),
  ];
}

typedef DispatchSubmit = Future<AppFailure?> Function(DispatchInput input);

enum DispatchDialogPurpose { dispatch, editStatus, selectAmbulance }

Future<bool?> showEmergencyDispatchDialog({
  required BuildContext context,
  required EmergencyReferenceData referenceData,
  required DispatchSubmit onSubmit,
  DispatchDialogPurpose purpose = DispatchDialogPurpose.dispatch,
  String? initialAmbulanceId,
  String initialStatus = 'DISPATCHED',
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DispatchDialog(
      referenceData: referenceData,
      onSubmit: onSubmit,
      purpose: purpose,
      initialAmbulanceId: initialAmbulanceId,
      initialStatus: initialStatus,
    ),
  );
}

class DispatchDialog extends StatefulWidget {
  const DispatchDialog({
    required this.referenceData,
    required this.onSubmit,
    this.purpose = DispatchDialogPurpose.dispatch,
    this.initialAmbulanceId,
    this.initialStatus = 'DISPATCHED',
    super.key,
  });

  final EmergencyReferenceData referenceData;
  final DispatchSubmit onSubmit;
  final DispatchDialogPurpose purpose;
  final String? initialAmbulanceId;
  final String initialStatus;

  @override
  State<DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<DispatchDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ambulanceIdController = TextEditingController();
  String? _ambulanceId;
  late String _status = widget.initialStatus;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _ambulanceId = widget.initialAmbulanceId;
    final List<EmergencyAmbulance> ambulances =
        widget.referenceData.availableAmbulances;
    if (_ambulanceId == null && ambulances.length == 1) {
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
    final AppLocalizations l10n = context.l10n;
    final List<EmergencyAmbulance> ambulances =
        widget.referenceData.availableAmbulances;
    final bool showAmbulance =
        widget.purpose != DispatchDialogPurpose.editStatus;
    final bool showStatus =
        widget.purpose != DispatchDialogPurpose.selectAmbulance;
    return AppDialog(
      title: Text(_title(l10n)),
      icon: Icon(
        widget.purpose == DispatchDialogPurpose.editStatus
            ? Icons.route_outlined
            : Icons.airport_shuttle_outlined,
      ),
      semanticLabel: _semanticLabel(l10n),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSubmitting,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSubmitting,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          if (showAmbulance && ambulances.isNotEmpty)
            AppSelectField<String>(
              value: _ambulanceId,
              labelText: l10n.emergencyDispatchAmbulanceLabel,
              isRequired: true,
              searchable: true,
              options: <AppSelectOption<String>>[
                for (final EmergencyAmbulance ambulance in ambulances)
                  AppSelectOption<String>(
                    value: ambulance.id,
                    label: ambulance.displayTitle,
                    trailingIcon: Text(
                      _ambulanceStatusLabel(l10n, ambulance.status),
                    ),
                  ),
              ],
              validator: (String? value) =>
                  value == null ? l10n.validationRequired : null,
              onChanged: (String? value) {
                setState(() {
                  _ambulanceId = value;
                });
              },
            )
          else if (showAmbulance)
            AppTextField(
              controller: _ambulanceIdController,
              labelText: l10n.emergencyDispatchAmbulanceIdLabel,
              isRequired: true,
              autofocus: true,
              validator: (String? value) =>
                  (value ?? '').trim().isEmpty ? l10n.validationRequired : null,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
            ),
          if (showStatus)
            AppSelectField<String>(
              value: _status,
              labelText: l10n.emergencyDispatchStatusLabel,
              isRequired: true,
              options: _ambulanceStatusOptions(l10n),
              validator: (String? value) =>
                  value == null ? l10n.validationRequired : null,
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
      actions: clinicalActionDialogActions(
        context,
        _submitLabel(l10n),
        _isSubmitting,
        _isSubmitting ? null : _submit,
        submitLeadingIcon: widget.purpose == DispatchDialogPurpose.editStatus
            ? AppActionIcons.edit
            : Icons.airport_shuttle_outlined,
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    return switch (widget.purpose) {
      DispatchDialogPurpose.dispatch => l10n.emergencyDispatchDialogTitle,
      DispatchDialogPurpose.editStatus => l10n.emergencyDispatchEditDialogTitle,
      DispatchDialogPurpose.selectAmbulance =>
        l10n.emergencyDispatchSelectAmbulanceDialogTitle,
    };
  }

  String _semanticLabel(AppLocalizations l10n) {
    return switch (widget.purpose) {
      DispatchDialogPurpose.dispatch =>
        l10n.emergencyDispatchDialogSemanticLabel,
      DispatchDialogPurpose.editStatus =>
        l10n.emergencyDispatchEditDialogSemanticLabel,
      DispatchDialogPurpose.selectAmbulance =>
        l10n.emergencyDispatchSelectAmbulanceDialogSemanticLabel,
    };
  }

  String _submitLabel(AppLocalizations l10n) {
    return switch (widget.purpose) {
      DispatchDialogPurpose.dispatch => l10n.emergencyDispatchAction,
      DispatchDialogPurpose.editStatus => l10n.patientsEditAction,
      DispatchDialogPurpose.selectAmbulance =>
        l10n.emergencyDispatchStartTripAction,
    };
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? ambulanceId =
        _ambulanceId ?? nonEmpty(_ambulanceIdController.text);
    if (ambulanceId == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final AppFailure? failure = await widget.onSubmit(
      DispatchInput(ambulanceId: ambulanceId, status: _status),
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
      _isSubmitting = false;
    });
  }
}

List<AppSelectOption<String>> _ambulanceStatusOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'DISPATCHED',
      label: l10n.emergencyDispatchStatusDispatched,
    ),
    AppSelectOption<String>(
      value: 'EN_ROUTE',
      label: l10n.emergencyDispatchStatusEnRoute,
    ),
    AppSelectOption<String>(
      value: 'ON_SCENE',
      label: l10n.emergencyDispatchStatusOnScene,
    ),
    AppSelectOption<String>(
      value: 'TRANSPORTING',
      label: l10n.emergencyDispatchStatusTransporting,
    ),
    AppSelectOption<String>(
      value: 'AVAILABLE',
      label: l10n.emergencyDispatchStatusAvailable,
    ),
    AppSelectOption<String>(
      value: 'OUT_OF_SERVICE',
      label: l10n.emergencyDispatchStatusOutOfService,
    ),
  ];
}

String _ambulanceStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'DISPATCHED' => l10n.emergencyDispatchStatusDispatched,
    'EN_ROUTE' => l10n.emergencyDispatchStatusEnRoute,
    'ON_SCENE' => l10n.emergencyDispatchStatusOnScene,
    'TRANSPORTING' => l10n.emergencyDispatchStatusTransporting,
    'AVAILABLE' => l10n.emergencyDispatchStatusAvailable,
    'OUT_OF_SERVICE' => l10n.emergencyDispatchStatusOutOfService,
    _ => l10n.emergencyDispatchStatusUnknown,
  };
}

typedef HandoffSubmit = Future<AppFailure?> Function(HandoffInput input);

Future<bool?> showEmergencyHandoffDialog({
  required BuildContext context,
  required HandoffSubmit onSubmit,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => HandoffDialog(onSubmit: onSubmit),
  );
}

class HandoffDialog extends StatefulWidget {
  const HandoffDialog({required this.onSubmit, super.key});

  final HandoffSubmit onSubmit;

  @override
  State<HandoffDialog> createState() => _HandoffDialogState();
}

class _HandoffDialogState extends State<HandoffDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  String _destination = 'OPD';
  bool _closeCase = true;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.emergencyHandoffDialogTitle),
      icon: const Icon(AppActionIcons.handoff),
      semanticLabel: l10n.emergencyHandoffDialogSemanticLabel,
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSubmitting,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSubmitting,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppSelectField<String>(
            value: _destination,
            labelText: l10n.emergencyHandoffDestinationLabel,
            isRequired: true,
            options: _handoffDestinationOptions(l10n),
            validator: (String? value) =>
                value == null ? l10n.validationRequired : null,
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
            labelText: l10n.emergencyHandoffNotesLabel,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
          AppCheckboxField(
            title: l10n.emergencyHandoffCloseCaseLabel,
            subtitle: l10n.emergencyHandoffCloseCaseSubtitle,
            value: _closeCase,
            enabled: !_isSubmitting,
            onChanged: (bool value) {
              setState(() {
                _closeCase = value;
              });
            },
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.emergencyHandoffAction,
        _isSubmitting,
        _isSubmitting ? null : _submit,
        submitLeadingIcon: AppActionIcons.handoff,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final AppFailure? failure = await widget.onSubmit(
      HandoffInput(
        destination: _destination,
        notes: nonEmpty(_notesController.text),
        closeCase: _closeCase,
      ),
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
      _isSubmitting = false;
    });
  }
}

List<AppSelectOption<String>> _handoffDestinationOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'OPD',
      label: l10n.emergencyHandoffDestinationOpd,
    ),
    AppSelectOption<String>(
      value: 'IPD',
      label: l10n.emergencyHandoffDestinationIpd,
    ),
    AppSelectOption<String>(
      value: 'ICU',
      label: l10n.emergencyHandoffDestinationIcu,
    ),
    AppSelectOption<String>(
      value: 'THEATER',
      label: l10n.emergencyHandoffDestinationTheater,
    ),
    AppSelectOption<String>(
      value: 'REFERRAL',
      label: l10n.emergencyHandoffDestinationReferral,
    ),
    AppSelectOption<String>(
      value: 'DISCHARGE',
      label: l10n.emergencyHandoffDestinationDischarge,
    ),
  ];
}

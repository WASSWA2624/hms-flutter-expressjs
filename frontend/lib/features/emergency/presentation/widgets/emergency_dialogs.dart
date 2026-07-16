import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
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
      title: const Text(EmergencyText.quickEmergencyArrival),
      icon: const Icon(Icons.emergency_outlined),
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
            labelText: EmergencyText.priority,
            isRequired: true,
            options: severityOptions(),
            validator: requiredSelect,
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
            labelText: EmergencyText.initialTriage,
            options: triageOptions(),
            onChanged: (String? value) {
              setState(() {
                _triageLevel = value;
              });
            },
          ),
          AppTextField(
            controller: _notesController,
            labelText: EmergencyText.arrivalNotes,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        EmergencyText.openCase,
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

typedef DispatchSubmit = Future<AppFailure?> Function(DispatchInput input);

Future<bool?> showEmergencyDispatchDialog({
  required BuildContext context,
  required EmergencyReferenceData referenceData,
  required DispatchSubmit onSubmit,
  String title = EmergencyText.dispatchAmbulance,
  String submitLabel = EmergencyText.dispatch,
  String defaultStatus = 'DISPATCHED',
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DispatchDialog(
      referenceData: referenceData,
      onSubmit: onSubmit,
      title: title,
      submitLabel: submitLabel,
      defaultStatus: defaultStatus,
    ),
  );
}

class DispatchDialog extends StatefulWidget {
  const DispatchDialog({
    required this.referenceData,
    required this.onSubmit,
    this.title = EmergencyText.dispatchAmbulance,
    this.submitLabel = EmergencyText.dispatch,
    this.defaultStatus = 'DISPATCHED',
    super.key,
  });

  final EmergencyReferenceData referenceData;
  final DispatchSubmit onSubmit;
  final String title;
  final String submitLabel;
  final String defaultStatus;

  @override
  State<DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<DispatchDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ambulanceIdController = TextEditingController();
  String? _ambulanceId;
  late String _status = widget.defaultStatus;
  bool _isSubmitting = false;
  AppFailure? _failure;

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
      pinActionsToBottom: true,
      closeEnabled: !_isSubmitting,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSubmitting,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          if (ambulances.isNotEmpty)
            AppSelectField<String>(
              value: _ambulanceId,
              labelText: EmergencyText.ambulance,
              isRequired: true,
              searchable: true,
              options: <AppSelectOption<String>>[
                for (final EmergencyAmbulance ambulance in ambulances)
                  AppSelectOption<String>(
                    value: ambulance.id,
                    label: ambulance.displayTitle,
                    trailingIcon: Text(apiLabel(ambulance.status ?? '')),
                  ),
              ],
              validator: requiredSelect,
              onChanged: (String? value) {
                setState(() {
                  _ambulanceId = value;
                });
              },
            )
          else
            AppTextField(
              controller: _ambulanceIdController,
              labelText: EmergencyText.ambulanceId,
              isRequired: true,
              validator: requiredText,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
            ),
          AppSelectField<String>(
            value: _status,
            labelText: EmergencyText.dispatchStatus,
            isRequired: true,
            options: ambulanceStatusOptions(),
            validator: requiredSelect,
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
        widget.submitLabel,
        _isSubmitting,
        _isSubmitting ? null : _submit,
        submitLeadingIcon: Icons.airport_shuttle_outlined,
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

typedef HandoffSubmit = Future<AppFailure?> Function(HandoffInput input);

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
    return AppDialog(
      title: const Text(EmergencyText.handoff),
      icon: const Icon(Icons.output_outlined),
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
            labelText: EmergencyText.handoffDestination,
            isRequired: true,
            options: handoffOptions(),
            validator: requiredSelect,
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
            labelText: EmergencyText.handoffNotes,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
          AppCheckboxField(
            title: EmergencyText.closeEmergencyCase,
            subtitle: EmergencyText.closeEmergencyCaseSubtitle,
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
        EmergencyText.recordHandoff,
        _isSubmitting,
        _isSubmitting ? null : _submit,
        submitLeadingIcon: Icons.output_outlined,
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

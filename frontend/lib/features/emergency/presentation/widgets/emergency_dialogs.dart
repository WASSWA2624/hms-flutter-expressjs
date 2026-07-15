import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
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

class QuickArrivalDialog extends StatefulWidget {
  const QuickArrivalDialog({super.key});

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
      title: const Text(EmergencyText.quickEmergencyArrival),
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
            labelText: 'Initial triage',
            options: triageOptions(),
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
          label: EmergencyText.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: EmergencyText.openCase,
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
        phone: nonEmpty(_phoneController.text),
        triageLevel: _triageLevel,
        notes: nonEmpty(_notesController.text),
      ),
    );
  }
}

class DispatchDialog extends StatefulWidget {
  const DispatchDialog({
    required this.referenceData,
    this.title = 'Dispatch ambulance',
    this.submitLabel = 'Dispatch',
    this.defaultStatus = 'DISPATCHED',
    super.key,
  });

  final EmergencyReferenceData referenceData;
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
              labelText: 'Ambulance ID',
              isRequired: true,
              validator: requiredText,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
            ),
          AppSelectField<String>(
            value: _status,
            labelText: 'Dispatch status',
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
      actions: <Widget>[
        AppButton.tertiary(
          label: EmergencyText.cancel,
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
        _ambulanceId ?? nonEmpty(_ambulanceIdController.text);
    if (ambulanceId == null) {
      return;
    }
    Navigator.of(
      context,
    ).pop(DispatchInput(ambulanceId: ambulanceId, status: _status));
  }
}

class HandoffDialog extends StatefulWidget {
  const HandoffDialog({super.key});

  @override
  State<HandoffDialog> createState() => _HandoffDialogState();
}

class _HandoffDialogState extends State<HandoffDialog> {
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
      title: const Text(EmergencyText.recordHandoff),
      icon: const Icon(Icons.output_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _destination,
            labelText: 'Destination',
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
          label: EmergencyText.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: EmergencyText.recordHandoff,
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
      HandoffInput(
        destination: _destination,
        notes: nonEmpty(_notesController.text),
        closeCase: _closeCase,
      ),
    );
  }
}

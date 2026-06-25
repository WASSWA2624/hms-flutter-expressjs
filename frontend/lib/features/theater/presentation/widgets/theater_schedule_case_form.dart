import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/presentation/controllers/theater_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_panel.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_procedure_catalog_dialog.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class TheaterScheduleCaseForm extends ConsumerStatefulWidget {
  const TheaterScheduleCaseForm({
    this.theaterCase,
    this.rescheduleOnly = false,
    this.initialPatientId,
    this.initialEncounterId,
    super.key,
  });

  final TheaterCase? theaterCase;
  final bool rescheduleOnly;
  final String? initialPatientId;
  final String? initialEncounterId;

  @override
  ConsumerState<TheaterScheduleCaseForm> createState() =>
      _TheaterScheduleCaseFormState();
}

class _TheaterScheduleCaseFormState
    extends ConsumerState<TheaterScheduleCaseForm> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;

  Timer? _patientSearchDebounce;
  Timer? _roomSearchDebounce;
  Timer? _surgeonSearchDebounce;
  Timer? _anesthetistSearchDebounce;
  int _patientSearchGeneration = 0;
  int _patientContextGeneration = 0;
  int _roomSearchGeneration = 0;
  int _surgeonSearchGeneration = 0;
  int _anesthetistSearchGeneration = 0;

  String? _selectedPatientId;
  String? _selectedEncounterId;
  String? _selectedRoomId;
  String? _selectedSurgeonId;
  String? _selectedAnesthetistId;
  String? _derivedSourceKind;
  _ScheduleSelectOption? _selectedPatientOption;
  final List<_ScheduleSelectOption> _searchedPatientOptions =
      <_ScheduleSelectOption>[];
  final List<TheaterScheduleEncounter> _patientEncounters =
      <TheaterScheduleEncounter>[];
  final List<_ScheduleSelectOption> _roomOptions = <_ScheduleSelectOption>[];
  final List<_ScheduleSelectOption> _surgeonOptions = <_ScheduleSelectOption>[];
  final List<_ScheduleSelectOption> _anesthetistOptions =
      <_ScheduleSelectOption>[];
  final List<ClinicalActionCatalogOption> _selectedProcedures =
      <ClinicalActionCatalogOption>[];

  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTime;
  bool _isLoadingPatients = false;
  bool _isLoadingPatientContext = false;
  bool _isLoadingRooms = false;
  bool _isLoadingSurgeons = false;
  bool _isLoadingAnesthetists = false;
  AppFailure? _failure;
  ClinicalRequestBillingSubmit? _billing;

  @override
  void initState() {
    super.initState();
    final TheaterCase? theaterCase = widget.theaterCase;
    final DateTime defaultAt =
        theaterCase?.scheduledAt ??
        DateTime.now().add(const Duration(hours: 1));
    _scheduledDate = _dateOnly(defaultAt);
    _scheduledTime = TimeOfDay.fromDateTime(defaultAt);
    _notesController = TextEditingController(text: theaterCase?.stageNotes);
    _selectedPatientId = _emptyToNull(
      widget.initialPatientId ?? theaterCase?.patientDisplayId,
    );
    _selectedEncounterId = _emptyToNull(
      widget.initialEncounterId ?? theaterCase?.encounterDisplayId,
    );
    _selectedRoomId = _emptyToNull(theaterCase?.roomDisplayId);
    _selectedSurgeonId = _emptyToNull(theaterCase?.surgeonUserDisplayId);
    _selectedAnesthetistId = _emptyToNull(
      theaterCase?.anesthetistUserDisplayId,
    );
    _derivedSourceKind = theaterCase?.sourceKind;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_searchPatients(''));
      unawaited(_searchRooms(''));
      unawaited(_searchSurgeons(''));
      unawaited(_searchAnesthetists(''));
      final String? patientId = _selectedPatientId;
      if (patientId != null) {
        unawaited(_loadPatientContext(patientId));
      }
    });
  }

  @override
  void dispose() {
    _patientSearchDebounce?.cancel();
    _roomSearchDebounce?.cancel();
    _surgeonSearchDebounce?.cancel();
    _anesthetistSearchDebounce?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        if (_failure != null) AppFailureStateView(failure: _failure!),
        if (!widget.rescheduleOnly) ...<Widget>[
          AppSelectField<String>.searchable(
            value: _selectedPatientId,
            labelText: l10n.theaterPatientLabel,
            hintText: l10n.theaterPatientSearchHint,
            isRequired: true,
            isLoading: _isLoadingPatients,
            options: _toSelectOptions(_patientOptions),
            validator: AppValidators.requiredValue(
              l10n.theaterFieldRequiredLabel(l10n.theaterPatientLabel),
            ),
            onSearchTextChanged: _schedulePatientSearch,
            onChanged: _selectPatient,
          ),
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppSelectField<String>.searchable(
              value: _selectedEncounterId,
              labelText: l10n.theaterEncounterLabel,
              hintText: l10n.theaterEncounterSearchHint,
              isRequired: true,
              enabled: _selectedPatientId != null,
              isLoading: _isLoadingPatientContext,
              options: _toSelectOptions(_encounterOptions),
              validator: AppValidators.requiredValue(
                l10n.theaterFieldRequiredLabel(l10n.theaterEncounterLabel),
              ),
              onChanged: _selectEncounter,
            ),
            right: _derivedSourceKind == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: theme.spacing.sm),
                      child: AppWorkspaceStatusBadge(
                        status: AppWorkspaceStatus(
                          label:
                              '${l10n.theaterSourceContextLabel}: ${_sourceKindLabel(l10n, _derivedSourceKind)}',
                          icon: Icons.hub_outlined,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
        AppResponsiveFieldRow.two(
          gap: AppResponsiveFieldRowGap.form,
          left: AppDateField(
            value: _scheduledDate,
            labelText: l10n.theaterScheduledAtLabel,
            hintText: l10n.appDateFormatHint,
            isRequired: true,
            firstDate: _dateOnly(DateTime.now()),
            lastDate: _dateOnly(DateTime.now().add(const Duration(days: 365))),
            currentDate: _dateOnly(DateTime.now()),
            pickerButtonLabel: l10n.theaterPickScheduleDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            validator: AppValidators.requiredValue<DateTime>(
              l10n.theaterFieldRequiredLabel(l10n.theaterScheduledAtLabel),
            ),
            onChanged: (DateTime? value) {
              if (value == null) {
                return;
              }
              setState(() => _scheduledDate = _dateOnly(value));
            },
          ),
          right: AppTimeField(
            value: _scheduledTime,
            labelText: l10n.theaterScheduledTimeLabel,
            hintText: l10n.appTimeFormatHint,
            isRequired: true,
            pickerButtonLabel: l10n.appTimePickerAction,
            invalidTimeMessage: l10n.appTimeInvalidMessage,
            validator: AppValidators.requiredValue<TimeOfDay>(
              l10n.theaterFieldRequiredLabel(l10n.theaterScheduledTimeLabel),
            ),
            onChanged: (TimeOfDay? value) {
              if (value == null) {
                return;
              }
              setState(() => _scheduledTime = value);
            },
          ),
        ),
        AppSelectField<String>.searchable(
          value: _selectedRoomId,
          labelText: l10n.theaterRoomLabel,
          hintText: l10n.theaterOperatingRoomHint,
          isLoading: _isLoadingRooms,
          options: _toSelectOptions(_roomOptions),
          onSearchTextChanged: _scheduleRoomSearch,
          onChanged: (String? value) {
            setState(() => _selectedRoomId = _emptyToNull(value));
          },
        ),
        AppResponsiveFieldRow.two(
          gap: AppResponsiveFieldRowGap.form,
          left: AppSelectField<String>.searchable(
            value: _selectedSurgeonId,
            labelText: l10n.theaterSurgeonLabel,
            hintText: l10n.theaterSurgeonSearchHint,
            isLoading: _isLoadingSurgeons,
            options: _toSelectOptions(_surgeonOptions),
            onSearchTextChanged: _scheduleSurgeonSearch,
            onChanged: (String? value) {
              setState(() => _selectedSurgeonId = _emptyToNull(value));
            },
          ),
          right: AppSelectField<String>.searchable(
            value: _selectedAnesthetistId,
            labelText: l10n.theaterAnesthetistLabel,
            hintText: l10n.theaterAnesthetistSearchHint,
            isLoading: _isLoadingAnesthetists,
            options: _toSelectOptions(_anesthetistOptions),
            onSearchTextChanged: _scheduleAnesthetistSearch,
            onChanged: (String? value) {
              setState(() => _selectedAnesthetistId = _emptyToNull(value));
            },
          ),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.theaterStageNotesLabel,
          maxLines: 3,
        ),
        if (!widget.rescheduleOnly) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Text(
            l10n.theaterProceduresSectionLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          ClinicalRequestFlowToolbar(
            addItemsLabel: l10n.theaterAddProcedureAction,
            showBillingAction: false,
            onAddItems: _openProcedureCatalog,
          ),
          if (_selectedProcedures.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: theme.spacing.sm),
              child: Text(
                l10n.theaterNoProceduresSelectedLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(top: theme.spacing.sm),
              child: Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  for (final ClinicalActionCatalogOption procedure
                      in _selectedProcedures)
                    InputChip(
                      label: Text(procedure.displayTitle),
                      onDeleted: () => _removeProcedure(procedure),
                    ),
                ],
              ),
            ),
          ClinicalRequestBillingPanel(
            lineItems: clinicalRequestBillingLineItems(
              options: _selectedProcedures,
            ),
            onChanged: (ClinicalRequestBillingSubmit value) {
              _billing = value;
            },
          ),
        ],
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.rescheduleOnly
              ? l10n.theaterRescheduleAction
              : l10n.theaterScheduleCaseAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  List<_ScheduleSelectOption> get _patientOptions {
    return _mergeOptions(<_ScheduleSelectOption>[
      ?_selectedPatientOption,
      ..._searchedPatientOptions,
    ]);
  }

  List<_ScheduleSelectOption> get _encounterOptions {
    return _mergeOptions(
      _patientEncounters
          .map(_encounterOption)
          .whereType<_ScheduleSelectOption>(),
    );
  }

  void _schedulePatientSearch(String value) {
    _patientSearchDebounce?.cancel();
    _patientSearchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_searchPatients(value));
    });
  }

  void _scheduleRoomSearch(String value) {
    _roomSearchDebounce?.cancel();
    _roomSearchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_searchRooms(value));
    });
  }

  void _scheduleSurgeonSearch(String value) {
    _surgeonSearchDebounce?.cancel();
    _surgeonSearchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_searchSurgeons(value));
    });
  }

  void _scheduleAnesthetistSearch(String value) {
    _anesthetistSearchDebounce?.cancel();
    _anesthetistSearchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_searchAnesthetists(value));
    });
  }

  Future<void> _searchPatients(String query) async {
    final int generation = ++_patientSearchGeneration;
    setState(() {
      _isLoadingPatients = true;
      _failure = null;
    });
    final Result<List<TheaterSchedulePatient>> result = await ref
        .read(theaterWorkspaceControllerProvider.notifier)
        .searchSchedulePatients(query);
    if (!mounted || generation != _patientSearchGeneration) {
      return;
    }
    result.when(
      success: (List<TheaterSchedulePatient> patients) {
        setState(() {
          _searchedPatientOptions
            ..clear()
            ..addAll(
              patients.map(_patientOption).whereType<_ScheduleSelectOption>(),
            );
          _isLoadingPatients = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingPatients = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _loadPatientContext(String patientId) async {
    final int generation = ++_patientContextGeneration;
    setState(() {
      _isLoadingPatientContext = true;
      _failure = null;
    });
    final Result<TheaterSchedulePatientDetail> result = await ref
        .read(theaterWorkspaceControllerProvider.notifier)
        .loadSchedulePatientEncounters(patientId);
    if (!mounted || generation != _patientContextGeneration) {
      return;
    }
    result.when(
      success: (TheaterSchedulePatientDetail detail) {
        setState(() {
          _selectedPatientOption ??= _patientOption(detail.patient);
          _patientEncounters
            ..clear()
            ..addAll(detail.encounters);
          _isLoadingPatientContext = false;
          if (_selectedEncounterId != null) {
            _applyEncounterSelection(_selectedEncounterId);
          }
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingPatientContext = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _searchRooms(String query) async {
    final int generation = ++_roomSearchGeneration;
    setState(() {
      _isLoadingRooms = true;
      _failure = null;
    });
    final Result<List<TheaterRoomOption>> result = await ref
        .read(theaterWorkspaceControllerProvider.notifier)
        .searchTheatreRooms(query);
    if (!mounted || generation != _roomSearchGeneration) {
      return;
    }
    result.when(
      success: (List<TheaterRoomOption> rooms) {
        setState(() {
          _roomOptions
            ..clear()
            ..addAll(rooms.map(_roomOption).whereType<_ScheduleSelectOption>());
          _isLoadingRooms = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingRooms = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _searchSurgeons(String query) async {
    final int generation = ++_surgeonSearchGeneration;
    setState(() {
      _isLoadingSurgeons = true;
      _failure = null;
    });
    final Result<List<TheaterStaffOption>> result = await ref
        .read(theaterWorkspaceControllerProvider.notifier)
        .searchTheatreStaff(query, role: 'SURGEON');
    if (!mounted || generation != _surgeonSearchGeneration) {
      return;
    }
    result.when(
      success: (List<TheaterStaffOption> staff) {
        setState(() {
          _surgeonOptions
            ..clear()
            ..addAll(
              staff.map(_staffOption).whereType<_ScheduleSelectOption>(),
            );
          _isLoadingSurgeons = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingSurgeons = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _searchAnesthetists(String query) async {
    final int generation = ++_anesthetistSearchGeneration;
    setState(() {
      _isLoadingAnesthetists = true;
      _failure = null;
    });
    final Result<List<TheaterStaffOption>> result = await ref
        .read(theaterWorkspaceControllerProvider.notifier)
        .searchTheatreStaff(query, role: 'ANESTHETIST');
    if (!mounted || generation != _anesthetistSearchGeneration) {
      return;
    }
    result.when(
      success: (List<TheaterStaffOption> staff) {
        setState(() {
          _anesthetistOptions
            ..clear()
            ..addAll(
              staff.map(_staffOption).whereType<_ScheduleSelectOption>(),
            );
          _isLoadingAnesthetists = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingAnesthetists = false;
          _failure = failure;
        });
      },
    );
  }

  void _selectPatient(String? patientId) {
    final String? normalizedPatientId = _emptyToNull(patientId);
    final _ScheduleSelectOption? option = _optionByValue(
      _patientOptions,
      normalizedPatientId,
    );
    setState(() {
      _selectedPatientId = normalizedPatientId;
      _selectedPatientOption = option;
      _selectedEncounterId = null;
      _derivedSourceKind = null;
      _patientEncounters.clear();
      _failure = null;
      if (normalizedPatientId == null) {
        _patientSearchGeneration += 1;
        _patientContextGeneration += 1;
        _isLoadingPatients = false;
        _isLoadingPatientContext = false;
      }
    });
    if (normalizedPatientId == null) {
      return;
    }
    unawaited(_loadPatientContext(normalizedPatientId));
  }

  void _selectEncounter(String? encounterId) {
    setState(() => _applyEncounterSelection(encounterId));
  }

  void _applyEncounterSelection(String? encounterId) {
    final String? normalizedEncounterId = _emptyToNull(encounterId);
    _selectedEncounterId = normalizedEncounterId;
    if (normalizedEncounterId == null) {
      _derivedSourceKind = null;
      return;
    }
    for (final TheaterScheduleEncounter encounter in _patientEncounters) {
      if (encounter.id == normalizedEncounterId) {
        _derivedSourceKind = encounter.sourceKind;
        return;
      }
    }
  }

  Future<void> _openProcedureCatalog() async {
    await showClinicalProcedureCatalogDialog(
      context: context,
      onSearchClinicalTerms:
          ({
            required String termType,
            String? query,
            int? limit,
            String source = 'ALL',
          }) {
            return ref
                .read(theaterWorkspaceControllerProvider.notifier)
                .searchClinicalTerms(
                  termType: termType,
                  query: query,
                  limit: limit ?? 80,
                  source: source,
                );
          },
      isDuplicate: (ClinicalActionCatalogOption option) =>
          _selectedProcedures.any(
            (ClinicalActionCatalogOption item) => item.apiId == option.apiId,
          ),
      onAdd: (ClinicalActionCatalogOption procedure) {
        setState(() => _selectedProcedures.add(procedure));
      },
    );
  }

  void _removeProcedure(ClinicalActionCatalogOption procedure) {
    setState(() {
      _selectedProcedures.removeWhere(
        (ClinicalActionCatalogOption item) => item.apiId == procedure.apiId,
      );
    });
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final ClinicalRequestBillingSubmit? billing = _billing;
    final bool charge =
        !widget.rescheduleOnly &&
        billing != null &&
        billing.paymentStatus != ClinicalRequestPaymentStatus.notBilled &&
        billing.totalAmount > 0;
    final DateTime scheduledAt = _combineDateAndTime(
      _scheduledDate,
      _scheduledTime,
    );
    final String? procedureName = _selectedProcedures.isEmpty
        ? null
        : _selectedProcedures
              .map((ClinicalActionCatalogOption p) => p.displayTitle)
              .join(', ');
    Navigator.of(context).pop(<String, Object?>{
      if (!widget.rescheduleOnly) 'encounter_id': _selectedEncounterId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      if (_selectedRoomId != null) 'room_id': _selectedRoomId,
      if (_selectedSurgeonId != null) 'surgeon_user_id': _selectedSurgeonId,
      if (_selectedAnesthetistId != null)
        'anesthetist_user_id': _selectedAnesthetistId,
      if (!widget.rescheduleOnly && _derivedSourceKind != null)
        'source_kind': _derivedSourceKind,
      if (!widget.rescheduleOnly && procedureName != null)
        'procedure_name': procedureName,
      'workflow_stage': widget.rescheduleOnly ? null : 'PRE_OP',
      'stage_notes': _notesController.text.trim(),
      if (charge) 'billing': billing.toPayloadMap(),
    });
  }

  _ScheduleSelectOption? _patientOption(TheaterSchedulePatient patient) {
    final String value = _firstNonEmpty(<String?>[
      patient.id,
      patient.displayId,
    ]);
    if (value.isEmpty) {
      return null;
    }
    return _ScheduleSelectOption(
      value: value,
      label: patient.displayTitle,
      subtitle: patient.displaySubtitle,
      icon: Icons.person_outline,
      searchText: patient.searchText,
    );
  }

  _ScheduleSelectOption? _encounterOption(TheaterScheduleEncounter encounter) {
    if (encounter.id.trim().isEmpty) {
      return null;
    }
    return _ScheduleSelectOption(
      value: encounter.id,
      label: encounter.displayTitle,
      subtitle: encounter.displaySubtitle,
      icon: Icons.medical_information_outlined,
      searchText: encounter.searchText,
    );
  }

  _ScheduleSelectOption? _roomOption(TheaterRoomOption room) {
    return _ScheduleSelectOption(
      value: room.id,
      label: room.displayTitle,
      subtitle: room.displaySubtitle,
      icon: Icons.meeting_room_outlined,
      searchText: room.searchText,
    );
  }

  _ScheduleSelectOption? _staffOption(TheaterStaffOption staff) {
    return _ScheduleSelectOption(
      value: staff.id,
      label: staff.displayLabel,
      subtitle: staff.positionTitle,
      icon: Icons.badge_outlined,
      searchText: staff.searchableLabel,
    );
  }

  List<AppSelectOption<String>> _toSelectOptions(
    List<_ScheduleSelectOption> options,
  ) {
    return <AppSelectOption<String>>[
      for (final _ScheduleSelectOption option in options)
        AppSelectOption<String>(
          value: option.value,
          label: option.label,
          labelWidget: _ScheduleSelectOptionLabel(option: option),
          leadingIcon: Icon(option.icon),
          searchText: option.searchText,
        ),
    ];
  }

  _ScheduleSelectOption? _optionByValue(
    List<_ScheduleSelectOption> options,
    String? value,
  ) {
    if (value == null) {
      return null;
    }
    for (final _ScheduleSelectOption option in options) {
      if (option.value == value) {
        return option;
      }
    }
    return null;
  }

  List<_ScheduleSelectOption> _mergeOptions(
    Iterable<_ScheduleSelectOption?> options,
  ) {
    final Set<String> seen = <String>{};
    final List<_ScheduleSelectOption> result = <_ScheduleSelectOption>[];
    for (final _ScheduleSelectOption? option in options) {
      final String value = option?.value.trim() ?? '';
      if (option == null || value.isEmpty || !seen.add(value.toLowerCase())) {
        continue;
      }
      result.add(option);
    }
    return result.take(20).toList(growable: false);
  }
}

@immutable
final class _ScheduleSelectOption {
  const _ScheduleSelectOption({
    required this.value,
    required this.label,
    required this.icon,
    this.subtitle,
    this.searchText,
  });

  final String value;
  final String label;
  final String? subtitle;
  final IconData icon;
  final String? searchText;
}

class _ScheduleSelectOptionLabel extends StatelessWidget {
  const _ScheduleSelectOptionLabel({required this.option});

  final _ScheduleSelectOption option;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (option.subtitle != null)
          Text(
            option.subtitle!,
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

String _sourceKindLabel(AppLocalizations l10n, String? sourceKind) {
  return switch ((sourceKind ?? '').trim().toUpperCase()) {
    'EMERGENCY' => l10n.theaterSourceEmergency,
    'OPD' => l10n.theaterSourceOpd,
    'IPD' => l10n.theaterSourceIpd,
    _ => sourceKind ?? '',
  };
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String? _emptyToNull(String? value) {
  final String trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '';
}

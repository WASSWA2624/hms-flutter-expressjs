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

Future<Map<String, Object?>?> showTheaterScheduleCaseDialog({
  required BuildContext context,
  required String title,
  required Widget icon,
  TheaterCase? theaterCase,
  bool rescheduleOnly = false,
  String? initialPatientId,
  String? initialEncounterId,
  String? initialEmergencyCaseId,
}) {
  final GlobalKey<TheaterScheduleCaseFormState> formKey =
      GlobalKey<TheaterScheduleCaseFormState>();
  final AppLocalizations l10n = context.l10n;
  final String submitLabel = rescheduleOnly
      ? l10n.theaterRescheduleAction
      : l10n.theaterScheduleCaseAction;

  return showAppWorkspaceActionDialog<Map<String, Object?>>(
    context: context,
    title: Text(title),
    icon: icon,
    maxWidth: 680,
    content: TheaterScheduleCaseForm(
      key: formKey,
      theaterCase: theaterCase,
      rescheduleOnly: rescheduleOnly,
      initialPatientId: initialPatientId,
      initialEncounterId: initialEncounterId,
      initialEmergencyCaseId: initialEmergencyCaseId,
    ),
    actions: <Widget>[
      AppButton.tertiary(
        label: l10n.commonCancelActionLabel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      AppButton.primary(
        label: submitLabel,
        leadingIcon: Icons.save_outlined,
        onPressed: () {
          final Map<String, Object?>? payload = formKey.currentState
              ?.submitIfValid();
          if (payload != null) {
            Navigator.of(context).pop(payload);
          }
        },
      ),
    ],
  );
}

class TheaterScheduleCaseForm extends ConsumerStatefulWidget {
  const TheaterScheduleCaseForm({
    this.theaterCase,
    this.rescheduleOnly = false,
    this.initialPatientId,
    this.initialEncounterId,
    this.initialEmergencyCaseId,
    super.key,
  });

  final TheaterCase? theaterCase;
  final bool rescheduleOnly;
  final String? initialPatientId;
  final String? initialEncounterId;
  final String? initialEmergencyCaseId;

  @override
  ConsumerState<TheaterScheduleCaseForm> createState() =>
      TheaterScheduleCaseFormState();
}

class TheaterScheduleCaseFormState
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
  String? _selectedEmergencyCaseId;
  String? _selectedRoomId;
  String? _selectedSurgeonId;
  String? _selectedAnesthetistId;
  String? _derivedSourceKind;
  _ScheduleSelectOption? _selectedPatientOption;
  final List<_ScheduleSelectOption> _searchedPatientOptions =
      <_ScheduleSelectOption>[];
  final List<TheaterScheduleEncounter> _patientEncounters =
      <TheaterScheduleEncounter>[];
  final List<TheaterScheduleEmergencyCase> _patientEmergencyCases =
      <TheaterScheduleEmergencyCase>[];
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
  AppFailure? _patientFailure;
  AppFailure? _encounterFailure;
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
    _selectedEmergencyCaseId = _emptyToNull(
      widget.initialEmergencyCaseId ?? theaterCase?.emergencyCaseDisplayId,
    );
    _selectedRoomId = _emptyToNull(theaterCase?.roomDisplayId);
    _selectedSurgeonId = _emptyToNull(theaterCase?.surgeonUserDisplayId);
    _selectedAnesthetistId = _emptyToNull(
      theaterCase?.anesthetistUserDisplayId,
    );
    _derivedSourceKind = theaterCase?.sourceKind;
    _seedRescheduleSelections(theaterCase);

    if (!widget.rescheduleOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_searchPatients(''));
        final String? patientId = _selectedPatientId;
        if (patientId != null) {
          unawaited(_loadPatientContext(patientId));
        }
      });
    }
  }

  void _seedRescheduleSelections(TheaterCase? theaterCase) {
    if (theaterCase == null) {
      return;
    }
    final String? roomId = _selectedRoomId;
    if (roomId != null) {
      _roomOptions.add(
        _ScheduleSelectOption(
          value: roomId,
          label: theaterCase.roomDisplayLabel ?? roomId,
          icon: Icons.meeting_room_outlined,
        ),
      );
    }
    final String? surgeonId = _selectedSurgeonId;
    if (surgeonId != null) {
      _surgeonOptions.add(
        _ScheduleSelectOption(
          value: surgeonId,
          label: theaterCase.surgeonDisplayName ?? surgeonId,
          icon: Icons.badge_outlined,
        ),
      );
    }
    final String? anesthetistId = _selectedAnesthetistId;
    if (anesthetistId != null) {
      _anesthetistOptions.add(
        _ScheduleSelectOption(
          value: anesthetistId,
          label: theaterCase.anesthetistDisplayName ?? anesthetistId,
          icon: Icons.badge_outlined,
        ),
      );
    }
  }

  Map<String, Object?>? submitIfValid() {
    if (!validateAndSaveAppForm(_formKey)) {
      return null;
    }
    return _buildPayload();
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
    final ColorScheme colorScheme = theme.colorScheme;

    return AppFormShell(
      formKey: _formKey,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        Text(
          l10n.theaterScheduleCaseDialogBody,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (!widget.rescheduleOnly)
          AppFormSection(
            density: AppFormSectionDensity.compact,
            title: l10n.theaterSchedulePatientContextSection,
            children: <Widget>[
              if (_patientFailure != null)
                AppFailureStateView(
                  failure: _patientFailure!,
                  onRetry: () => unawaited(_searchPatients('')),
                ),
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
              AppSelectField<String>.searchable(
                value: _selectedEncounterId,
                labelText: l10n.theaterEncounterLabel,
                hintText: _selectedPatientId == null
                    ? l10n.theaterEncounterSelectPatientFirstHint
                    : l10n.theaterEncounterSearchHint,
                isRequired: true,
                enabled: _selectedPatientId != null,
                isLoading: _isLoadingPatientContext,
                options: _toSelectOptions(_encounterOptions),
                validator: AppValidators.requiredValue(
                  l10n.theaterFieldRequiredLabel(l10n.theaterEncounterLabel),
                ),
                onChanged: _selectEncounter,
              ),
              if (_encounterFailure != null)
                AppFailureStateView(
                  failure: _encounterFailure!,
                  onRetry: () {
                    final String? patientId = _selectedPatientId;
                    if (patientId != null) {
                      unawaited(_loadPatientContext(patientId));
                    }
                  },
                ),
              if (_showEmergencyCaseField)
                AppSelectField<String>(
                  value: _selectedEmergencyCaseId,
                  labelText: l10n.theaterEmergencyCaseLabel,
                  hintText: _selectedPatientId == null
                      ? l10n.theaterEmergencyCaseSelectPatientFirstHint
                      : l10n.theaterEmergencyCaseSearchHint,
                  isRequired: _requiresEmergencyCaseLink,
                  enabled: _selectedPatientId != null,
                  options: _toSelectOptions(_emergencyCaseOptions),
                  validator: _requiresEmergencyCaseLink
                      ? AppValidators.requiredValue(
                          l10n.theaterFieldRequiredLabel(
                            l10n.theaterEmergencyCaseLabel,
                          ),
                        )
                      : null,
                  onChanged: _selectEmergencyCase,
                ),
              if (_isEmergencyScheduling)
                AppMessagePanel(
                  tone: AppWorkspaceStatusTone.warning,
                  icon: Icons.emergency_outlined,
                  title: l10n.theaterScheduleEmergencyPanelTitle,
                  message: l10n.theaterScheduleEmergencyHint,
                ),
              if (_effectiveSourceKind != null)
                AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label:
                        '${l10n.theaterSourceContextLabel}: ${_sourceKindLabel(l10n, _effectiveSourceKind)}',
                    icon: _effectiveSourceKind == 'EMERGENCY'
                        ? Icons.emergency_outlined
                        : Icons.hub_outlined,
                    tone: _effectiveSourceKind == 'EMERGENCY'
                        ? AppWorkspaceStatusTone.warning
                        : AppWorkspaceStatusTone.info,
                  ),
                ),
            ],
          ),
        AppFormSection(
          density: AppFormSectionDensity.compact,
          title: l10n.theaterScheduleDetailsSection,
          children: <Widget>[
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppDateField(
                value: _scheduledDate,
                labelText: l10n.theaterScheduledAtLabel,
                hintText: l10n.appDateFormatHint,
                isRequired: true,
                firstDate: _dateOnly(DateTime.now()),
                lastDate: _dateOnly(
                  DateTime.now().add(const Duration(days: 365)),
                ),
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
                  l10n.theaterFieldRequiredLabel(
                    l10n.theaterScheduledTimeLabel,
                  ),
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
          ],
        ),
        if (!widget.rescheduleOnly)
          AppFormSection(
            density: AppFormSectionDensity.compact,
            title: l10n.theaterScheduleBillingSection,
            description: l10n.theaterScheduleBillingSectionBody,
            children: <Widget>[
              ClinicalRequestFlowToolbar(
                addItemsLabel: l10n.theaterAddProcedureAction,
                showBillingAction: false,
                onAddItems: _openProcedureCatalog,
              ),
              if (_selectedProcedures.isEmpty)
                Text(
                  l10n.theaterNoProceduresSelectedLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
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
              ClinicalRequestBillingPanel(
                lineItems: clinicalRequestBillingLineItems(
                  options: _selectedProcedures,
                ),
                onChanged: (ClinicalRequestBillingSubmit value) {
                  _billing = value;
                },
              ),
            ],
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
    final List<TheaterScheduleEncounter> encounters =
        List<TheaterScheduleEncounter>.from(_patientEncounters)
          ..sort(compareTheaterScheduleEncounters);
    return _mergeOptions(
      encounters.map(_encounterOption).whereType<_ScheduleSelectOption>(),
    );
  }

  List<_ScheduleSelectOption> get _emergencyCaseOptions {
    return _mergeOptions(
      _patientEmergencyCases
          .map(_emergencyCaseOption)
          .whereType<_ScheduleSelectOption>(),
    );
  }

  bool get _showEmergencyCaseField => _patientEmergencyCases.isNotEmpty;

  bool get _requiresEmergencyCaseLink {
    if (_patientEmergencyCases.isEmpty) {
      return false;
    }
    if ((_derivedSourceKind ?? '').toUpperCase() == 'EMERGENCY') {
      return true;
    }
    return _selectedEmergencyCaseId != null;
  }

  bool get _isEmergencyScheduling {
    return (_effectiveSourceKind ?? '').toUpperCase() == 'EMERGENCY';
  }

  String? get _effectiveSourceKind {
    if ((_selectedEmergencyCaseId ?? '').trim().isNotEmpty) {
      return 'EMERGENCY';
    }
    return _derivedSourceKind;
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
      _patientFailure = null;
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
          _patientFailure = failure;
        });
      },
    );
  }

  Future<void> _loadPatientContext(String patientId) async {
    final int generation = ++_patientContextGeneration;
    setState(() {
      _isLoadingPatientContext = true;
      _encounterFailure = null;
    });
    final TheaterWorkspaceController controller = ref.read(
      theaterWorkspaceControllerProvider.notifier,
    );
    final List<Object> results = await Future.wait<Object>(<Future<Object>>[
      controller.loadSchedulePatientEncounters(patientId),
      controller.searchScheduleEmergencyCases(patientId),
    ]);
    if (!mounted || generation != _patientContextGeneration) {
      return;
    }
    final Result<TheaterSchedulePatientDetail> encounterResult =
        results[0] as Result<TheaterSchedulePatientDetail>;
    final Result<List<TheaterScheduleEmergencyCase>> emergencyResult =
        results[1] as Result<List<TheaterScheduleEmergencyCase>>;

    encounterResult.when(
      success: (TheaterSchedulePatientDetail detail) {
        final List<TheaterScheduleEmergencyCase> emergencyCases =
            emergencyResult.when(
              success: (List<TheaterScheduleEmergencyCase> value) => value,
              failure: (_) => const <TheaterScheduleEmergencyCase>[],
            );
        setState(() {
          _selectedPatientOption ??= _patientOption(detail.patient);
          _patientEncounters
            ..clear()
            ..addAll(detail.encounters);
          _patientEmergencyCases
            ..clear()
            ..addAll(emergencyCases);
          _isLoadingPatientContext = false;
          _applyInitialEmergencyCaseSelection();
          if (_selectedEncounterId != null) {
            _applyEncounterSelection(_selectedEncounterId);
          }
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingPatientContext = false;
          _encounterFailure = failure;
        });
      },
    );
  }

  Future<void> _searchRooms(String query) async {
    final int generation = ++_roomSearchGeneration;
    setState(() => _isLoadingRooms = true);
    final Result<List<TheaterRoomOption>> result = await ref
        .read(theaterWorkspaceControllerProvider.notifier)
        .searchTheatreRooms(query);
    if (!mounted || generation != _roomSearchGeneration) {
      return;
    }
    result.when(
      success: (List<TheaterRoomOption> rooms) {
        final _ScheduleSelectOption? pinned = _pinnedOption(
          _roomOptions,
          _selectedRoomId,
        );
        setState(() {
          _roomOptions
            ..clear()
            ..addAll(rooms.map(_roomOption).whereType<_ScheduleSelectOption>());
          _restorePinnedOption(_roomOptions, pinned);
          _isLoadingRooms = false;
        });
      },
      failure: (_) {
        setState(() => _isLoadingRooms = false);
      },
    );
  }

  Future<void> _searchSurgeons(String query) async {
    final int generation = ++_surgeonSearchGeneration;
    setState(() => _isLoadingSurgeons = true);
    final Result<List<TheaterStaffOption>> result = await ref
        .read(theaterWorkspaceControllerProvider.notifier)
        .searchTheatreStaff(query, role: 'SURGEON');
    if (!mounted || generation != _surgeonSearchGeneration) {
      return;
    }
    result.when(
      success: (List<TheaterStaffOption> staff) {
        final _ScheduleSelectOption? pinned = _pinnedOption(
          _surgeonOptions,
          _selectedSurgeonId,
        );
        setState(() {
          _surgeonOptions
            ..clear()
            ..addAll(
              staff.map(_staffOption).whereType<_ScheduleSelectOption>(),
            );
          _restorePinnedOption(_surgeonOptions, pinned);
          _isLoadingSurgeons = false;
        });
      },
      failure: (_) {
        setState(() => _isLoadingSurgeons = false);
      },
    );
  }

  Future<void> _searchAnesthetists(String query) async {
    final int generation = ++_anesthetistSearchGeneration;
    setState(() => _isLoadingAnesthetists = true);
    final Result<List<TheaterStaffOption>> result = await ref
        .read(theaterWorkspaceControllerProvider.notifier)
        .searchTheatreStaff(query, role: 'ANESTHETIST');
    if (!mounted || generation != _anesthetistSearchGeneration) {
      return;
    }
    result.when(
      success: (List<TheaterStaffOption> staff) {
        final _ScheduleSelectOption? pinned = _pinnedOption(
          _anesthetistOptions,
          _selectedAnesthetistId,
        );
        setState(() {
          _anesthetistOptions
            ..clear()
            ..addAll(
              staff.map(_staffOption).whereType<_ScheduleSelectOption>(),
            );
          _restorePinnedOption(_anesthetistOptions, pinned);
          _isLoadingAnesthetists = false;
        });
      },
      failure: (_) {
        setState(() => _isLoadingAnesthetists = false);
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
      _selectedEmergencyCaseId = null;
      _derivedSourceKind = null;
      _patientEncounters.clear();
      _patientEmergencyCases.clear();
      _patientFailure = null;
      _encounterFailure = null;
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

  void _selectEmergencyCase(String? emergencyCaseId) {
    setState(() {
      _selectedEmergencyCaseId = _emptyToNull(emergencyCaseId);
      if (_selectedEmergencyCaseId == null) {
        return;
      }
      if (_selectedEncounterId == null) {
        final TheaterScheduleEncounter? emergencyEncounter =
            _firstEmergencyEncounter();
        if (emergencyEncounter != null) {
          _applyEncounterSelection(emergencyEncounter.id);
        }
      }
    });
  }

  void _applyInitialEmergencyCaseSelection() {
    final String? initialId = _emptyToNull(widget.initialEmergencyCaseId);
    if (initialId != null) {
      _selectedEmergencyCaseId = _resolveEmergencyCaseId(initialId);
      return;
    }
    if (_selectedEmergencyCaseId != null) {
      _selectedEmergencyCaseId = _resolveEmergencyCaseId(
        _selectedEmergencyCaseId,
      );
      return;
    }
    if (_patientEmergencyCases.length == 1) {
      _selectedEmergencyCaseId = _patientEmergencyCases.first.id;
    }
  }

  String? _resolveEmergencyCaseId(String? candidate) {
    final String normalized = (candidate ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final TheaterScheduleEmergencyCase emergencyCase
        in _patientEmergencyCases) {
      if (emergencyCase.id == normalized ||
          emergencyCase.displayId == normalized) {
        return emergencyCase.id;
      }
    }
    return normalized;
  }

  TheaterScheduleEncounter? _firstEmergencyEncounter() {
    for (final TheaterScheduleEncounter encounter in _patientEncounters) {
      if ((encounter.sourceKind ?? '').toUpperCase() == 'EMERGENCY') {
        return encounter;
      }
    }
    return null;
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
        if ((_derivedSourceKind ?? '').toUpperCase() == 'EMERGENCY' &&
            _selectedEmergencyCaseId == null &&
            _patientEmergencyCases.length == 1) {
          _selectedEmergencyCaseId = _patientEmergencyCases.first.id;
        }
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

  Map<String, Object?> _buildPayload() {
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
    final String? sourceKind = _effectiveSourceKind;
    return <String, Object?>{
      if (!widget.rescheduleOnly) 'encounter_id': _selectedEncounterId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      if (_selectedRoomId != null) 'room_id': _selectedRoomId,
      if (_selectedSurgeonId != null) 'surgeon_user_id': _selectedSurgeonId,
      if (_selectedAnesthetistId != null)
        'anesthetist_user_id': _selectedAnesthetistId,
      if (!widget.rescheduleOnly && sourceKind != null)
        'source_kind': sourceKind,
      if (!widget.rescheduleOnly && _selectedEmergencyCaseId != null)
        'emergency_case_id': _selectedEmergencyCaseId,
      if (!widget.rescheduleOnly && procedureName != null)
        'procedure_name': procedureName,
      'workflow_stage': widget.rescheduleOnly ? null : 'PRE_OP',
      'stage_notes': _notesController.text.trim(),
      if (charge) 'billing': billing.toPayloadMap(),
    };
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
      icon: (encounter.sourceKind ?? '').toUpperCase() == 'EMERGENCY'
          ? Icons.emergency_outlined
          : Icons.medical_information_outlined,
      searchText: encounter.searchText,
    );
  }

  _ScheduleSelectOption? _emergencyCaseOption(
    TheaterScheduleEmergencyCase emergencyCase,
  ) {
    if (emergencyCase.id.trim().isEmpty) {
      return null;
    }
    return _ScheduleSelectOption(
      value: emergencyCase.id,
      label: emergencyCase.displayTitle,
      subtitle: emergencyCase.displaySubtitle,
      icon: Icons.emergency_outlined,
      searchText: emergencyCase.searchText,
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

  _ScheduleSelectOption? _pinnedOption(
    List<_ScheduleSelectOption> options,
    String? selectedId,
  ) {
    if (selectedId == null) {
      return null;
    }
    return _optionByValue(options, selectedId);
  }

  void _restorePinnedOption(
    List<_ScheduleSelectOption> options,
    _ScheduleSelectOption? pinned,
  ) {
    if (pinned == null) {
      return;
    }
    final bool alreadyPresent = options.any(
      (_ScheduleSelectOption option) => option.value == pinned.value,
    );
    if (!alreadyPresent) {
      options.insert(0, pinned);
    }
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

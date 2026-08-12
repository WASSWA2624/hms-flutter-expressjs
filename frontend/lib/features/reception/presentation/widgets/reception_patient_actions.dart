import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/widgets/claims_insurance_config_dialogs.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_visitor_appointment_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';

Future<void> openReceptionPatientEditor(
  BuildContext context,
  WidgetRef ref,
  String patientId,
) {
  return showPatientDetailDialog(
    context,
    ref,
    patientId,
    allowBillingNavigation: false,
  );
}

Future<bool> openReceptionInsuranceCapture({
  required BuildContext context,
  required WidgetRef ref,
  required String patientId,
}) async {
  final Result<ClaimsReferenceData> lookups = await ref
      .read(claimsRepositoryProvider)
      .loadReferenceData();
  if (!context.mounted) {
    return false;
  }
  final ClaimsReferenceData? referenceData = lookups.when(
    success: (ClaimsReferenceData value) => value,
    failure: (_) => null,
  );
  if (referenceData == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.receptionInsuranceLookupFailed)),
    );
    return false;
  }
  await openClaimsEnrollmentDialog(
    context: context,
    ref: ref,
    referenceData: referenceData,
    patientId: patientId,
  );
  return true;
}

/// Opens the reception patient picker (search + select, no mutation).
Future<Patient?> showReceptionPatientPickerDialog({
  required BuildContext context,
}) {
  return showAppDialog<Patient>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ReceptionPatientPickerDialog(),
  );
}

Future<bool> openReceptionScheduleAppointment({
  required BuildContext context,
  required WidgetRef ref,
  Patient? patient,
}) async {
  final AsyncValue<Result<PatientRegistryState>> registryAsync = ref.read(
    patientRegistryControllerProvider,
  );
  PatientRegistryState? registry = registryAsync.asData?.value.when(
    success: (PatientRegistryState state) => state,
    failure: (_) => null,
  );
  if (registry == null) {
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .refresh();
    if (!context.mounted) {
      return false;
    }
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
      return false;
    }
    registry = ref
        .read(patientRegistryControllerProvider)
        .asData
        ?.value
        .when(
          success: (PatientRegistryState state) => state,
          failure: (_) => null,
        );
  }
  if (registry == null || !context.mounted) {
    return false;
  }
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReceptionScheduleAppointmentDialog(
      initialPatient: patient,
      referenceData: registry!.referenceData,
      registrationScope: PatientRegistrationScope.resolve(
        referenceData: registry.referenceData,
        accessPolicy: ref.read(appAccessPolicyProvider),
      ),
    ),
  );
  return saved == true;
}

enum _SchedulePatientMode { existing, newPatient, visitor }

class _ReceptionScheduleAppointmentDialog extends ConsumerStatefulWidget {
  const _ReceptionScheduleAppointmentDialog({
    required this.referenceData,
    required this.registrationScope,
    this.initialPatient,
  });

  final Patient? initialPatient;
  final PatientReferenceData referenceData;
  final PatientRegistrationScope registrationScope;

  @override
  ConsumerState<_ReceptionScheduleAppointmentDialog> createState() =>
      _ReceptionScheduleAppointmentDialogState();
}

class _ReceptionScheduleAppointmentDialogState
    extends ConsumerState<_ReceptionScheduleAppointmentDialog> {
  final GlobalKey<FormState> _registrationFormKey = GlobalKey<FormState>();
  final GlobalKey<RegisterNewPatientFormState> _registrationKey =
      GlobalKey<RegisterNewPatientFormState>();
  final GlobalKey<ReceptionVisitorAppointmentDialogState> _visitorKey =
      GlobalKey<ReceptionVisitorAppointmentDialogState>();
  final GlobalKey<PatientAppointmentQuickDialogState> _appointmentKey =
      GlobalKey<PatientAppointmentQuickDialogState>();
  _SchedulePatientMode _mode = _SchedulePatientMode.existing;
  Patient? _patient;
  bool _isRegistering = false;
  bool _isAppointmentBusy = false;

  bool get _isBusy => _isRegistering || _isAppointmentBusy;

  bool get _isPatientStep => _patient == null;

  @override
  void initState() {
    super.initState();
    _patient = widget.initialPatient;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.patientsAppointmentDialogTitle),
      icon: const Icon(AppActionIcons.calendar),
      scrollable: false,
      pinActionsToBottom: true,
      closeEnabled: !_isBusy,
      maxWidth: 720,
      content: _isPatientStep
          ? _buildPatientStep(context)
          : _buildAppointmentStep(context),
      actions: _isPatientStep
          ? _patientStepActions(context)
          : _appointmentStepActions(context),
    );
  }

  Widget _buildPatientStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Widget tabBody;
    if (_mode == _SchedulePatientMode.existing) {
      tabBody = _ReceptionPatientPickerDialog(
        embedded: true,
        onSelected: (Patient? value) {
          if (value != null) {
            setState(() => _patient = value);
          }
        },
      );
    } else if (_mode == _SchedulePatientMode.newPatient) {
      tabBody = SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: AppFormShell(
          formKey: _registrationFormKey,
          enabled: !_isRegistering,
          formStatus: appFormFailureStatus(
            context,
            _registrationKey.currentState?.failure,
            messageBuilder: (AppFailure failure) =>
                failure.displayMessage(l10n),
          ),
          children: <Widget>[
            RegisterNewPatientForm(
              key: _registrationKey,
              referenceData: widget.referenceData,
              registrationScope: widget.registrationScope,
              enabled: !_isRegistering,
              onLookupDuplicates: (PatientDuplicateQuery query) => ref
                  .read(patientRegistryControllerProvider.notifier)
                  .loadDuplicateCandidates(query),
              onDuplicateStateChanged: () => setState(() {}),
              onUseExistingPatient: (Patient patient) {
                setState(() {
                  _patient = patient;
                  _isRegistering = false;
                });
              },
            ),
          ],
        ),
      );
    } else {
      tabBody = SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ReceptionVisitorAppointmentDialog(
          key: _visitorKey,
          embedded: true,
          onBusyChanged: (bool value) {
            if (mounted && value != _isAppointmentBusy) {
              setState(() => _isAppointmentBusy = value);
            }
          },
          onSaved: () => Navigator.of(context).pop(true),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTabStrip(
          tabs: <AppTabItem>[
            AppTabItem(
              id: _SchedulePatientMode.existing.name,
              label: l10n.receptionScheduleExistingPatientTab,
            ),
            AppTabItem(
              id: _SchedulePatientMode.newPatient.name,
              label: l10n.receptionScheduleNewPatientTab,
            ),
            AppTabItem(
              id: _SchedulePatientMode.visitor.name,
              label: l10n.receptionScheduleVisitorTab,
            ),
          ],
          selectedId: _mode.name,
          onTabTapped: (String id) {
            if (_isBusy) {
              return;
            }
            setState(() {
              _mode = _SchedulePatientMode.values.byName(id);
            });
          },
        ),
        const SizedBox(height: 16),
        Expanded(child: tabBody),
      ],
    );
  }

  Widget _buildAppointmentStep(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: PatientAppointmentQuickDialog(
        key: _appointmentKey,
        patient: _patient!,
        referenceData: widget.referenceData,
        embedded: true,
        allowClinicalActions: false,
        allowVitalsActions: false,
        onCancel: () => setState(() {
          _patient = null;
          _isAppointmentBusy = false;
        }),
        onBusyChanged: (bool value) {
          if (mounted && value != _isAppointmentBusy) {
            setState(() => _isAppointmentBusy = value);
          }
        },
        onSaved: () => Navigator.of(context).pop(true),
      ),
    );
  }

  List<Widget> _patientStepActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return <Widget>[
      AppButton.close(
        label: l10n.commonCancelActionLabel,
        leadingIcon: AppActionIcons.cancel,
        enabled: !_isBusy,
        onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
      ),
      if (_mode == _SchedulePatientMode.newPatient)
        AppButton.primary(
          label: _registrationKey.currentState?.duplicateWarningAccepted == true
              ? l10n.patientsRegisterAnywayAction
              : l10n.patientsRegisterNewPatientAction,
          leadingIcon: AppActionIcons.personAdd,
          isLoading: _isRegistering,
          enabled: !_isBusy,
          onPressed: _isBusy ? null : _registerPatient,
        ),
      if (_mode == _SchedulePatientMode.visitor)
        AppButton.primary(
          label: l10n.receptionScheduleAppointmentAction,
          leadingIcon: AppActionIcons.calendar,
          isLoading: _visitorKey.currentState?.isSaving ?? false,
          enabled: !_isBusy,
          onPressed: _isBusy
              ? null
              : () => unawaited(_scheduleVisitorAppointment()),
        ),
    ];
  }

  List<Widget> _appointmentStepActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PatientAppointmentQuickDialogState? appointmentState =
        _appointmentKey.currentState;
    final bool canSubmit = appointmentState?.canSubmit ?? !_isBusy;
    return clinicalActionDialogActions(
      context,
      l10n.patientsQuickAppointmentAction,
      appointmentState?.isSaving ?? false,
      canSubmit ? () => unawaited(_schedulePatientAppointment()) : null,
      onCancel: () {
        if (_isBusy) {
          return;
        }
        setState(() {
          _patient = null;
          _isAppointmentBusy = false;
        });
      },
      submitLeadingIcon: AppActionIcons.calendar,
    );
  }

  Future<void> _schedulePatientAppointment() async {
    final PatientAppointmentQuickDialogState? appointmentState =
        _appointmentKey.currentState;
    if (appointmentState == null || _isBusy) {
      return;
    }
    await appointmentState.submit();
  }

  Future<void> _scheduleVisitorAppointment() async {
    final ReceptionVisitorAppointmentDialogState? visitorState =
        _visitorKey.currentState;
    if (visitorState == null || _isBusy) {
      return;
    }
    await visitorState.submit();
  }

  Future<void> _registerPatient() async {
    if (_isBusy || !validateAndSaveAppForm(_registrationFormKey)) {
      return;
    }
    final RegisterNewPatientFormState? formState =
        _registrationKey.currentState;
    if (formState == null) {
      return;
    }
    setState(() => _isRegistering = true);
    formState.clearFailure();
    final bool canContinue = await formState.prepareSubmit();
    if (!mounted) {
      return;
    }
    if (!canContinue) {
      setState(() => _isRegistering = false);
      return;
    }
    final Result<Patient> result = await ref
        .read(patientRegistryControllerProvider.notifier)
        .createPatient(formState.buildPayload());
    if (!mounted) {
      return;
    }
    result.when(
      success: (Patient patient) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.patientsSavedMessage)),
        );
        setState(() {
          _patient = patient;
          _isRegistering = false;
        });
      },
      failure: (AppFailure failure) {
        formState.setFailure(failure);
        setState(() => _isRegistering = false);
      },
    );
  }
}

class _ReceptionPatientPickerDialog extends ConsumerStatefulWidget {
  const _ReceptionPatientPickerDialog({this.embedded = false, this.onSelected});

  final bool embedded;
  final ValueChanged<Patient?>? onSelected;

  @override
  ConsumerState<_ReceptionPatientPickerDialog> createState() =>
      _ReceptionPatientPickerDialogState();
}

class _ReceptionPatientPickerDialogState
    extends ConsumerState<_ReceptionPatientPickerDialog> {
  static const Duration _searchDebounce = Duration(milliseconds: 250);
  static const String _genderFilterKey = 'gender';
  static const String _statusFilterKey = 'status';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<Patient> _columnController =
      AppListTableColumnVisibilityController<Patient>();
  Timer? _debounce;
  int _searchGeneration = 0;
  bool _isLoading = false;
  AppFailure? _failure;
  List<Patient> _patients = const <Patient>[];
  AppPageRequest _pageRequest = const AppPageRequest(pageSize: 20);
  int? _totalItemCount;
  Patient? _selected;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _columnController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String raw) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }
      unawaited(_search(raw, resetPage: true));
    });
  }

  PatientListQuery _buildQuery(String raw, {AppPageRequest? pageRequest}) {
    final String? gender = _filterValue.option(_genderFilterKey)?.trim();
    final String? status = _filterValue.option(_statusFilterKey)?.trim();
    return PatientListQuery(
      search: raw.trim(),
      gender: (gender == null || gender.isEmpty) ? null : gender,
      isActive: switch (status) {
        'active' => true,
        'inactive' => false,
        _ => null,
      },
      pageRequest: pageRequest ?? _pageRequest,
    );
  }

  Future<void> _search(String raw, {bool resetPage = false}) async {
    final int generation = ++_searchGeneration;
    final AppPageRequest pageRequest = resetPage
        ? _pageRequest.first()
        : _pageRequest;
    setState(() {
      _isLoading = true;
      _failure = null;
      if (resetPage) {
        _pageRequest = pageRequest;
      }
    });
    final Result<AppPage<Patient>> result = await ref
        .read(patientRegistryControllerProvider.notifier)
        .loadPatientPage(_buildQuery(raw, pageRequest: pageRequest));
    if (!mounted || generation != _searchGeneration) {
      return;
    }
    result.when(
      success: (AppPage<Patient> page) {
        final String? selectedKey = _patientOptionValue(_selected);
        Patient? nextSelected = _selected;
        if (selectedKey != null) {
          nextSelected = null;
          for (final Patient patient in page.items) {
            if (_patientOptionValue(patient) == selectedKey) {
              nextSelected = patient;
              break;
            }
          }
          // Keep the prior selection visible when it falls outside this page.
          nextSelected ??= _selected;
        }
        setState(() {
          _patients = page.items;
          _totalItemCount = page.totalItemCount;
          _pageRequest = page.request;
          _selected = nextSelected;
          _isLoading = false;
          _failure = null;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _patients = const <Patient>[];
          _totalItemCount = 0;
          _selected = null;
          _isLoading = false;
        });
      },
    );
  }

  void _selectPatient(Patient patient) {
    setState(() {
      _selected = patient;
      _failure = null;
    });
    if (widget.embedded) {
      widget.onSelected?.call(patient);
    }
  }

  void _confirmSelection() {
    if (_isLoading) {
      return;
    }
    final Patient? selected = _selected;
    if (selected == null) {
      return;
    }
    Navigator.of(context).pop(selected);
  }

  void _onFilterChanged(AppSearchBarFilterValue value) {
    setState(() => _filterValue = value);
    unawaited(_search(_searchController.text, resetPage: true));
  }

  Future<void> _onPageChanged(AppPageRequest request) async {
    setState(() => _pageRequest = request);
    await _search(_searchController.text);
  }

  static String? _patientOptionValue(Patient? patient) {
    if (patient == null) {
      return null;
    }
    final String? publicId = patient.publicId?.trim();
    if (publicId != null && publicId.isNotEmpty) {
      return publicId;
    }
    final String id = patient.id.trim();
    return id.isEmpty ? null : id;
  }

  String _genderLabel(AppLocalizations l10n, String? gender) {
    return switch ((gender ?? '').trim().toUpperCase()) {
      'MALE' || 'M' => l10n.patientsGenderMale,
      'FEMALE' || 'F' => l10n.patientsGenderFemale,
      'OTHER' => l10n.patientsGenderOther,
      'UNKNOWN' => l10n.patientsGenderUnknown,
      final String value when value.isNotEmpty => value,
      _ => l10n.profileUnknownValue,
    };
  }

  List<AppListTableColumn<Patient>> _columns(AppLocalizations l10n) {
    final String selectedKey = _patientOptionValue(_selected) ?? '';
    return <AppListTableColumn<Patient>>[
      AppListTableColumn<Patient>(
        id: 'select',
        label: '',
        alwaysVisible: true,
        fixedWidth: 48,
        cellBuilder: (BuildContext context, Patient patient) {
          final bool selected =
              _patientOptionValue(patient) == selectedKey &&
              selectedKey.isNotEmpty;
          return Center(
            child: IgnorePointer(
              child: Checkbox(
                value: selected,
                onChanged: (_) {},
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          );
        },
      ),
      AppListTableColumn<Patient>(
        id: 'patient',
        label: l10n.patientsPatientColumnLabel,
        alwaysVisible: true,
        sortComparator: (Patient left, Patient right) =>
            appListTableCompareText(
              left.effectiveDisplayName,
              right.effectiveDisplayName,
            ),
        cellBuilder: (_, Patient patient) => AppListItemText(
          title: patient.effectiveDisplayName,
          subtitle:
              patient.effectiveIdentifier ??
              patient.publicId ??
              l10n.profileUnknownValue,
        ),
      ),
      AppListTableColumn<Patient>(
        id: 'contact',
        label: l10n.patientsPhoneIdentifierColumnLabel,
        sortComparator: (Patient left, Patient right) =>
            appListTableCompareText(
              left.primaryPhone ?? left.primaryEmail,
              right.primaryPhone ?? right.primaryEmail,
            ),
        cellBuilder: (_, Patient patient) => Text(
          patient.primaryPhone?.trim().isNotEmpty == true
              ? patient.primaryPhone!
              : (patient.primaryEmail ?? l10n.profileUnknownValue),
        ),
      ),
      AppListTableColumn<Patient>(
        id: 'gender',
        label: l10n.patientsGenderColumnLabel,
        sortComparator: (Patient left, Patient right) =>
            appListTableCompareText(left.gender, right.gender),
        cellBuilder: (_, Patient patient) =>
            Text(_genderLabel(l10n, patient.gender)),
      ),
      AppListTableColumn<Patient>(
        id: 'status',
        label: l10n.patientsStatusColumnLabel,
        sortComparator: (Patient left, Patient right) =>
            left.isActive == right.isActive
            ? 0
            : (left.isActive ? -1 : 1),
        cellBuilder: (_, Patient patient) => Text(
          patient.isActive
              ? l10n.patientsActiveFilter
              : l10n.patientsInactiveFilter,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool canConfirm = !_isLoading && _selected != null;
    final String selectedKey = _patientOptionValue(_selected) ?? '';
    final AppPage<Patient> page = AppPage<Patient>(
      items: _patients,
      request: _pageRequest,
      totalItemCount: _totalItemCount,
    );

    final Widget table = AppListTable<Patient>(
      page: page,
      isLoading: _isLoading,
      shrinkWrap: false,
      tableHorizontalMargin: 0,
      enableExport: false,
      forceCompact: true,
      showRowNumbers: false,
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: 'reception_patient_picker',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      onPageChanged: _onPageChanged,
      pageLabelBuilder: (AppPage<Patient> page) {
        final int total = page.totalItemCount ?? page.items.length;
        if (total == 0) {
          return l10n.patientsPageLabel(0, 0, 0);
        }
        return l10n.patientsPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          total,
        );
      },
      previousPageLabel: l10n.patientsPreviousPageLabel,
      nextPageLabel: l10n.patientsNextPageLabel,
      onRowSelected: _selectPatient,
      itemKeyBuilder: (Patient patient) =>
          ValueKey<String>(_patientOptionValue(patient) ?? patient.id),
      rowColorBuilder: (BuildContext context, Patient patient) {
        if (_patientOptionValue(patient) != selectedKey || selectedKey.isEmpty) {
          return null;
        }
        return colorScheme.primaryContainer.withValues(alpha: 0.35);
      },
      emptyBuilder: (BuildContext context) => Center(
        child: Text(
          l10n.receptionPatientPickerEmpty,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      search: AppListTableSearch<Patient>(
        controller: _searchController,
        semanticLabel: l10n.patientsSearchLabel,
        hintText: l10n.patientsSearchHint,
        clearLabel: l10n.patientsClearFiltersAction,
        matcher: (_, _) => true,
        isLoading: _isLoading,
        enableDateFilter: false,
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.patientsAdvancedFiltersAction,
        hasActiveFilters: _filterValue.isActive,
        filterValue: _filterValue,
        onFilterChanged: _onFilterChanged,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _genderFilterKey,
            label: l10n.patientsGenderFilterLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'MALE',
                label: l10n.patientsGenderMale,
              ),
              AppSearchBarFilterChoice(
                value: 'FEMALE',
                label: l10n.patientsGenderFemale,
              ),
              AppSearchBarFilterChoice(
                value: 'OTHER',
                label: l10n.patientsGenderOther,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.patientsStatusColumnLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'active',
                label: l10n.patientsActiveFilter,
              ),
              AppSearchBarFilterChoice(
                value: 'inactive',
                label: l10n.patientsInactiveFilter,
              ),
            ],
          ),
        ],
        onChanged: _scheduleSearch,
        onSubmitted: (String value) => unawaited(_search(value, resetPage: true)),
        onClear: () {
          _searchController.clear();
          setState(() => _filterValue = AppSearchBarFilterValue.empty);
          unawaited(_search('', resetPage: true));
        },
      ),
      columns: _columns(l10n),
      columnChoices: _columns(l10n)
          .where((AppListTableColumn<Patient> column) => column.id != 'select')
          .toList(growable: false),
      mobileItemBuilder: (BuildContext context, Patient patient) {
        final bool selected =
            _patientOptionValue(patient) == selectedKey &&
            selectedKey.isNotEmpty;
        return AppListTableMobileItem(
          leading: IgnorePointer(
            child: Checkbox(
              value: selected,
              onChanged: (_) {},
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          title: patient.effectiveDisplayName,
          caption:
              patient.effectiveIdentifier ??
              patient.publicId ??
              l10n.profileUnknownValue,
        );
      },
    );

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_failure != null)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          ),
        Expanded(child: table),
      ],
    );

    if (widget.embedded) {
      return content;
    }
    return AppDialog(
      title: Text(l10n.receptionPatientPickerTitle),
      icon: const Icon(AppActionIcons.person),
      scrollable: false,
      pinActionsToBottom: true,
      closeEnabled: !_isLoading,
      maxWidth: 920,
      content: content,
      actions: <Widget>[
        AppButton.close(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !_isLoading,
          onPressed: _isLoading ? null : () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: l10n.commonSelectActionLabel,
          leadingIcon: AppActionIcons.person,
          enabled: canConfirm,
          onPressed: canConfirm ? _confirmSelection : null,
        ),
      ],
    );
  }
}

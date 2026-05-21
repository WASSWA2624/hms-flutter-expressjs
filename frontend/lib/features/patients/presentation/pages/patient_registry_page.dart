import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class PatientRegistryPage extends ConsumerWidget {
  const PatientRegistryPage({super.key});

  static const AccessRequirement _readRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientRead],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<Result<PatientRegistryState>> state = ref.watch(
      patientRegistryControllerProvider,
    );

    return AppAccessGate(
      requirement: _readRequirement,
      deniedBuilder: (_, _) => AppStateScaffold(
        variant: AppStateViewVariant.forbidden,
        title: l10n.routeForbiddenTitle,
        body: l10n.routeForbiddenBody,
      ),
      child: AsyncStateScaffold<PatientRegistryState>(
        value: state,
        loadingTitle: l10n.patientsLoadingTitle,
        loadingBody: l10n.patientsLoadingBody,
        maxWidth: PageMaxWidth.dataHeavy,
        centerVertically: false,
        onRetry: () {
          ref.read(patientRegistryControllerProvider.notifier).refresh();
        },
        dataBuilder: (BuildContext context, PatientRegistryState data) {
          return _PatientRegistryContent(state: data);
        },
      ),
    );
  }
}

class _PatientRegistryContent extends ConsumerStatefulWidget {
  const _PatientRegistryContent({required this.state});

  final PatientRegistryState state;

  static const AccessRequirement _writeRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientWrite],
  );

  @override
  ConsumerState<_PatientRegistryContent> createState() =>
      _PatientRegistryContentState();
}

class _PatientRegistryContentState
    extends ConsumerState<_PatientRegistryContent> {
  late final TextEditingController _tableSearchController;
  late final AppListTableColumnVisibilityController<Patient>
  _tableColumnController;
  Timer? _tableSearchDebounce;

  @override
  void initState() {
    super.initState();
    _tableSearchController = TextEditingController(
      text: widget.state.query.search,
    );
    _tableColumnController = AppListTableColumnVisibilityController<Patient>();
    _tableSearchController.addListener(_handleTableSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _PatientRegistryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextSearch = widget.state.query.search;
    if (oldWidget.state.query.search != nextSearch &&
        _tableSearchController.text != nextSearch) {
      _tableSearchController.text = nextSearch;
    }
  }

  @override
  void dispose() {
    _tableSearchDebounce?.cancel();
    _tableSearchController
      ..removeListener(_handleTableSearchChanged)
      ..dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final PatientRegistryController controller = ref.read(
      patientRegistryControllerProvider.notifier,
    );

    return AppWorkspace(
      title: l10n.patientsTitle,
      leadingIcon: AppRouteIcons.patients,
      compactSummaryCards: true,
      primaryAction: AppAccessActionGate(
        requirement: _PatientRegistryContent._writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          final AppBreakpoint breakpoint = AppBreakpoints.of(context);
          final bool iconOnly =
              breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;
          if (iconOnly) {
            return AppIconButton(
              icon: Icons.person_add_alt_1_outlined,
              semanticLabel: l10n.patientsAddAction,
              tooltip: l10n.patientsAddAction,
              enabled: isAllowed,
              onPressed: () {
                _openPatientForm(context, ref);
              },
            );
          }

          return AppButton.primary(
            label: l10n.patientsAddAction,
            leadingIcon: Icons.person_add_alt_1_outlined,
            enabled: isAllowed,
            onPressed: () {
              _openPatientForm(context, ref);
            },
          );
        },
      ),
      secondaryActions: <Widget>[
        AppAccessActionGate(
          requirement: _PatientRegistryContent._writeRequirement,
          builder: (BuildContext context, bool isAllowed) => AppIconButton(
            icon: Icons.emergency_outlined,
            semanticLabel: l10n.patientsEmergencyRegisterAction,
            tooltip: l10n.patientsEmergencyRegisterAction,
            enabled: isAllowed,
            onPressed: () {
              _openEmergencyRegistration(context, ref);
            },
          ),
        ),
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: widget.state.isRefreshingList,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              await _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        if (widget.state.overview.totalPatients > 0)
          AppWorkspaceSummaryCard(
            label: _PatientSummaryText.allPatients,
            value: AppFormatters.compactNumber(
              widget.state.overview.totalPatients,
              Localizations.localeOf(context),
            ),
            icon: Icons.groups_outlined,
            compact: true,
            onPressed: () {
              unawaited(
                _applySummaryQuery(
                  PatientListQuery(
                    pageRequest: widget.state.query.pageRequest.first(),
                  ),
                ),
              );
            },
          ),
        if (widget.state.overview.activePatients > 0)
          AppWorkspaceSummaryCard(
            label: l10n.patientsActiveSummaryLabel,
            value: AppFormatters.compactNumber(
              widget.state.overview.activePatients,
              Localizations.localeOf(context),
            ),
            icon: Icons.how_to_reg_outlined,
            compact: true,
            onPressed: () {
              unawaited(
                _applySummaryQuery(
                  PatientListQuery(
                    isActive: true,
                    pageRequest: widget.state.query.pageRequest.first(),
                  ),
                ),
              );
            },
          ),
      ],
      body: _PatientList(
        state: widget.state,
        searchController: _tableSearchController,
        columnVisibilityController: _tableColumnController,
      ),
    );
  }

  void _handleTableSearchChanged() {
    final String query = _tableSearchController.text;
    _tableSearchDebounce?.cancel();
    _tableSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        unawaited(_applyTableSearch(query));
      }
    });
  }

  Future<void> _applyTableSearch(String query) async {
    final String search = query.trim();
    if (search == widget.state.query.search.trim()) {
      return;
    }

    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .applyQuery(
          widget.state.query.copyWith(
            search: search,
            pageRequest: widget.state.query.pageRequest.first(),
          ),
        );
    if (mounted) {
      await _showFailureIfNeeded(context, failure);
    }
  }

  Future<void> _openPatientForm(BuildContext context, WidgetRef ref) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PatientFormDialog(
        referenceData: widget.state.referenceData,
        onLookupDuplicates: (PatientDuplicateQuery query) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .loadDuplicateCandidates(query);
        },
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .createPatient(payload);
        },
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsSavedMessage)),
      );
    }
  }

  Future<void> _openEmergencyRegistration(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmergencyPatientFormDialog(
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .createPatient(payload);
        },
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsEmergencySavedMessage)),
      );
    }
  }

  Future<void> _applySummaryQuery(PatientListQuery query) async {
    _tableSearchDebounce?.cancel();
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .applyQuery(query);
    if (mounted) {
      await _showFailureIfNeeded(context, failure);
    }
  }
}

abstract final class _PatientSummaryText {
  static const String allPatients = 'All patients';
}

@immutable
final class _PatientFilterDraft {
  const _PatientFilterDraft({
    required this.patientId,
    required this.contact,
    required this.facilityId,
    required this.gender,
    required this.status,
    required this.consentState,
    required this.appointmentStatus,
    required this.visitDate,
    required this.visitFrom,
    required this.visitTo,
    required this.createdFrom,
    required this.createdTo,
    required this.dateOfBirthFrom,
    required this.dateOfBirthTo,
    required this.hasActiveAdmission,
    required this.hasOutstandingBalance,
  });

  final String patientId;
  final String contact;
  final String? facilityId;
  final String? gender;
  final String? status;
  final String? consentState;
  final String? appointmentStatus;
  final DateTime? visitDate;
  final DateTime? visitFrom;
  final DateTime? visitTo;
  final DateTime? createdFrom;
  final DateTime? createdTo;
  final DateTime? dateOfBirthFrom;
  final DateTime? dateOfBirthTo;
  final bool? hasActiveAdmission;
  final bool? hasOutstandingBalance;
}

class _PatientAdvancedFiltersDialog extends StatefulWidget {
  const _PatientAdvancedFiltersDialog({
    required this.patientId,
    required this.contact,
    required this.facilityId,
    required this.gender,
    required this.status,
    required this.consentState,
    required this.appointmentStatus,
    required this.visitDate,
    required this.visitFrom,
    required this.visitTo,
    required this.createdFrom,
    required this.createdTo,
    required this.dateOfBirthFrom,
    required this.dateOfBirthTo,
    required this.hasActiveAdmission,
    required this.hasOutstandingBalance,
    required this.facilities,
    required this.appointmentStatuses,
    required this.consentStatuses,
  });

  final String patientId;
  final String contact;
  final String? facilityId;
  final String? gender;
  final String? status;
  final String? consentState;
  final String? appointmentStatus;
  final DateTime? visitDate;
  final DateTime? visitFrom;
  final DateTime? visitTo;
  final DateTime? createdFrom;
  final DateTime? createdTo;
  final DateTime? dateOfBirthFrom;
  final DateTime? dateOfBirthTo;
  final bool? hasActiveAdmission;
  final bool? hasOutstandingBalance;
  final List<PatientReferenceOption> facilities;
  final List<String> appointmentStatuses;
  final List<String> consentStatuses;

  @override
  State<_PatientAdvancedFiltersDialog> createState() =>
      _PatientAdvancedFiltersDialogState();
}

class _PatientAdvancedFiltersDialogState
    extends State<_PatientAdvancedFiltersDialog> {
  late final TextEditingController _patientIdController;
  late final TextEditingController _contactController;
  String? _facilityId;
  String? _gender;
  String? _status;
  String? _consentState;
  String? _appointmentStatus;
  DateTime? _visitDate;
  DateTime? _visitFrom;
  DateTime? _visitTo;
  DateTime? _createdFrom;
  DateTime? _createdTo;
  DateTime? _dateOfBirthFrom;
  DateTime? _dateOfBirthTo;
  bool? _hasActiveAdmission;
  bool? _hasOutstandingBalance;

  @override
  void initState() {
    super.initState();
    _patientIdController = TextEditingController(text: widget.patientId);
    _contactController = TextEditingController(text: widget.contact);
    _facilityId = widget.facilityId;
    _gender = widget.gender;
    _status = widget.status;
    _consentState = widget.consentState;
    _appointmentStatus = widget.appointmentStatus;
    _visitDate = widget.visitDate;
    _visitFrom = widget.visitFrom;
    _visitTo = widget.visitTo;
    _createdFrom = widget.createdFrom;
    _createdTo = widget.createdTo;
    _dateOfBirthFrom = widget.dateOfBirthFrom;
    _dateOfBirthTo = widget.dateOfBirthTo;
    _hasActiveAdmission = widget.hasActiveAdmission;
    _hasOutstandingBalance = widget.hasOutstandingBalance;
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.patientsAdvancedFiltersTitle),
      icon: const Icon(Icons.tune),
      scrollable: true,
      maxWidth: 760,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          AppFormSection(
            title: l10n.patientsFilterIdentitySectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                left: AppTextField(
                  controller: _patientIdController,
                  labelText: l10n.patientsPatientIdFilterLabel,
                  textInputAction: TextInputAction.search,
                ),
                right: AppTextField(
                  controller: _contactController,
                  labelText: l10n.patientsContactFilterLabel,
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (widget.facilities.length > 1)
                AppResponsiveFieldRow.two(
                  left: PatientFacilitySelectField(
                    facilities: widget.facilities,
                    value: _facilityId,
                    labelText: l10n.patientsFacilityLabel,
                    onChanged: (String? value) =>
                        setState(() => _facilityId = value),
                  ),
                  right: AppGenderField(
                    value: _gender,
                    labelText: l10n.patientsGenderFilterLabel,
                    maleLabel: l10n.patientsGenderMale,
                    femaleLabel: l10n.patientsGenderFemale,
                    otherLabel: l10n.patientsGenderOther,
                    unknownLabel: l10n.patientsGenderUnknown,
                    onChanged: (String? value) =>
                        setState(() => _gender = value),
                  ),
                )
              else
                AppGenderField(
                  value: _gender,
                  labelText: l10n.patientsGenderFilterLabel,
                  maleLabel: l10n.patientsGenderMale,
                  femaleLabel: l10n.patientsGenderFemale,
                  otherLabel: l10n.patientsGenderOther,
                  unknownLabel: l10n.patientsGenderUnknown,
                  onChanged: (String? value) => setState(() => _gender = value),
                ),
            ],
          ),
          AppFormSection(
            title: l10n.patientsFilterVisitSectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              PatientDateField(
                value: _visitDate,
                firstDate: _patientFilterFirstDate,
                lastDate: _patientFilterLastDate,
                labelText: l10n.patientsVisitDateFilterLabel,
                onChanged: (DateTime? value) => _visitDate = value,
              ),
              AppResponsiveFieldRow.two(
                left: PatientDateField(
                  value: _visitFrom,
                  firstDate: _patientFilterFirstDate,
                  lastDate: _patientFilterLastDate,
                  labelText: l10n.patientsVisitFromFilterLabel,
                  onChanged: (DateTime? value) => _visitFrom = value,
                ),
                right: PatientDateField(
                  value: _visitTo,
                  firstDate: _patientFilterFirstDate,
                  lastDate: _patientFilterLastDate,
                  labelText: l10n.patientsVisitToFilterLabel,
                  onChanged: (DateTime? value) => _visitTo = value,
                ),
              ),
              AppSelectField<String>.searchable(
                value: _appointmentStatus,
                labelText: l10n.patientsAppointmentStatusLabel,
                onChanged: (String? value) =>
                    setState(() => _appointmentStatus = value),
                options: <AppSelectOption<String>>[
                  for (final String value in widget.appointmentStatuses)
                    AppSelectOption<String>(
                      value: value,
                      label: _apiLabel(value),
                      leadingIcon: Icon(_appointmentStatusIcon(value)),
                    ),
                ],
              ),
            ],
          ),
          AppFormSection(
            title: l10n.patientsFilterRecordSectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                left: AppSelectField<String>(
                  value: _status,
                  labelText: l10n.patientsStatusFilterLabel,
                  onChanged: (String? value) => setState(() => _status = value),
                  options: <AppSelectOption<String>>[
                    AppSelectOption<String>(
                      value: _statusActive,
                      label: l10n.patientsActiveFilter,
                    ),
                    AppSelectOption<String>(
                      value: _statusInactive,
                      label: l10n.patientsInactiveFilter,
                    ),
                  ],
                ),
                right: AppSelectField<String>(
                  value: _consentState,
                  labelText: l10n.patientsConsentFilterLabel,
                  onChanged: (String? value) =>
                      setState(() => _consentState = value),
                  options: <AppSelectOption<String>>[
                    for (final String value in widget.consentStatuses)
                      AppSelectOption<String>(
                        value: value,
                        label: _apiLabel(value),
                      ),
                  ],
                ),
              ),
              AppResponsiveFieldRow.two(
                left: AppSelectField<bool>(
                  value: _hasActiveAdmission,
                  labelText: l10n.patientsActiveAdmissionFilterLabel,
                  onChanged: (bool? value) =>
                      setState(() => _hasActiveAdmission = value),
                  options: _booleanFilterOptions(l10n),
                ),
                right: AppSelectField<bool>(
                  value: _hasOutstandingBalance,
                  labelText: l10n.patientsOutstandingBalanceFilterLabel,
                  onChanged: (bool? value) =>
                      setState(() => _hasOutstandingBalance = value),
                  options: _booleanFilterOptions(l10n),
                ),
              ),
              AppResponsiveFieldRow.two(
                left: PatientDateField(
                  value: _dateOfBirthFrom,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  labelText: l10n.patientsDobFromFilterLabel,
                  onChanged: (DateTime? value) => _dateOfBirthFrom = value,
                ),
                right: PatientDateField(
                  value: _dateOfBirthTo,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  labelText: l10n.patientsDobToFilterLabel,
                  onChanged: (DateTime? value) => _dateOfBirthTo = value,
                ),
              ),
              AppResponsiveFieldRow.two(
                left: PatientDateField(
                  value: _createdFrom,
                  firstDate: _patientFilterFirstDate,
                  lastDate: _patientFilterLastDate,
                  labelText: l10n.patientsCreatedFromFilterLabel,
                  onChanged: (DateTime? value) => _createdFrom = value,
                ),
                right: PatientDateField(
                  value: _createdTo,
                  firstDate: _patientFilterFirstDate,
                  lastDate: _patientFilterLastDate,
                  labelText: l10n.patientsCreatedToFilterLabel,
                  onChanged: (DateTime? value) => _createdTo = value,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.patientsClearFiltersAction,
          leadingIcon: Icons.filter_alt_off_outlined,
          onPressed: () {
            Navigator.of(context).pop(
              const _PatientFilterDraft(
                patientId: '',
                contact: '',
                facilityId: null,
                gender: null,
                status: null,
                consentState: null,
                appointmentStatus: null,
                visitDate: null,
                visitFrom: null,
                visitTo: null,
                createdFrom: null,
                createdTo: null,
                dateOfBirthFrom: null,
                dateOfBirthTo: null,
                hasActiveAdmission: null,
                hasOutstandingBalance: null,
              ),
            );
          },
        ),
        AppButton.primary(
          label: l10n.patientsApplyFiltersAction,
          leadingIcon: Icons.filter_alt_outlined,
          onPressed: () {
            Navigator.of(context).pop(
              _PatientFilterDraft(
                patientId: _patientIdController.text.trim(),
                contact: _contactController.text.trim(),
                facilityId: _facilityId,
                gender: _gender,
                status: _status,
                consentState: _consentState,
                appointmentStatus: _appointmentStatus,
                visitDate: _visitDate,
                visitFrom: _visitFrom,
                visitTo: _visitTo,
                createdFrom: _createdFrom,
                createdTo: _createdTo,
                dateOfBirthFrom: _dateOfBirthFrom,
                dateOfBirthTo: _dateOfBirthTo,
                hasActiveAdmission: _hasActiveAdmission,
                hasOutstandingBalance: _hasOutstandingBalance,
              ),
            );
          },
        ),
      ],
    );
  }
}

bool _hasPatientAdvancedFilters(PatientListQuery query) {
  return query.patientId.trim().isNotEmpty ||
      query.contact.trim().isNotEmpty ||
      query.facilityId != null ||
      query.gender != null ||
      query.isActive != null ||
      query.consentState != null ||
      query.appointmentStatus != null ||
      query.visitDate != null ||
      query.visitFrom != null ||
      query.visitTo != null ||
      query.createdFrom != null ||
      query.createdTo != null ||
      query.dateOfBirthFrom != null ||
      query.dateOfBirthTo != null ||
      query.hasActiveAdmission != null ||
      query.hasOutstandingBalance != null;
}

_PatientFilterDraft _patientFilterDraftFromQuery(PatientListQuery query) {
  return _PatientFilterDraft(
    patientId: query.patientId,
    contact: query.contact,
    facilityId: query.facilityId,
    gender: query.gender,
    status: _statusValue(query.isActive),
    consentState: query.consentState,
    appointmentStatus: query.appointmentStatus,
    visitDate: query.visitDate,
    visitFrom: query.visitFrom,
    visitTo: query.visitTo,
    createdFrom: query.createdFrom,
    createdTo: query.createdTo,
    dateOfBirthFrom: query.dateOfBirthFrom,
    dateOfBirthTo: query.dateOfBirthTo,
    hasActiveAdmission: query.hasActiveAdmission,
    hasOutstandingBalance: query.hasOutstandingBalance,
  );
}

Future<void> _openPatientAdvancedFilters(
  BuildContext context,
  WidgetRef ref,
  PatientRegistryState state,
  TextEditingController searchController,
) async {
  final PatientRegistryState currentState = _readCurrentState(ref) ?? state;
  final PatientListQuery query = currentState.query;
  final _PatientFilterDraft? draft = await showAppDialog<_PatientFilterDraft>(
    context: context,
    builder: (_) => _PatientAdvancedFiltersDialog(
      patientId: query.patientId,
      contact: query.contact,
      facilityId: query.facilityId,
      gender: query.gender,
      status: _statusValue(query.isActive),
      consentState: query.consentState,
      appointmentStatus: query.appointmentStatus,
      visitDate: query.visitDate,
      visitFrom: query.visitFrom,
      visitTo: query.visitTo,
      createdFrom: query.createdFrom,
      createdTo: query.createdTo,
      dateOfBirthFrom: query.dateOfBirthFrom,
      dateOfBirthTo: query.dateOfBirthTo,
      hasActiveAdmission: query.hasActiveAdmission,
      hasOutstandingBalance: query.hasOutstandingBalance,
      facilities: currentState.referenceData.facilities,
      appointmentStatuses: currentState.referenceData.appointmentStatuses,
      consentStatuses: _filterConsentStatuses(currentState),
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }

  await _applyPatientFilterDraft(
    context,
    ref,
    currentState,
    searchController,
    draft,
  );
}

Future<void> _applyPatientFilterDraft(
  BuildContext context,
  WidgetRef ref,
  PatientRegistryState state,
  TextEditingController searchController,
  _PatientFilterDraft draft,
) async {
  final PatientListQuery nextQuery = state.query.copyWith(
    search: searchController.text.trim(),
    patientId: draft.patientId.trim(),
    contact: draft.contact.trim(),
    facilityId: draft.facilityId,
    gender: draft.gender,
    isActive: _activeValue(draft.status),
    consentState: draft.consentState,
    appointmentStatus: draft.appointmentStatus,
    visitDate: draft.visitDate,
    visitFrom: draft.visitFrom,
    visitTo: draft.visitTo,
    createdFrom: draft.createdFrom,
    createdTo: draft.createdTo,
    dateOfBirthFrom: draft.dateOfBirthFrom,
    dateOfBirthTo: draft.dateOfBirthTo,
    hasActiveAdmission: draft.hasActiveAdmission,
    hasOutstandingBalance: draft.hasOutstandingBalance,
    pageRequest: state.query.pageRequest.first(),
    clearFacilityId: draft.facilityId == null,
    clearGender: draft.gender == null,
    clearIsActive: draft.status == null,
    clearConsentState: draft.consentState == null,
    clearAppointmentStatus: draft.appointmentStatus == null,
    clearVisitDate: draft.visitDate == null,
    clearVisitFrom: draft.visitFrom == null,
    clearVisitTo: draft.visitTo == null,
    clearCreatedFrom: draft.createdFrom == null,
    clearCreatedTo: draft.createdTo == null,
    clearDateOfBirthFrom: draft.dateOfBirthFrom == null,
    clearDateOfBirthTo: draft.dateOfBirthTo == null,
    clearHasActiveAdmission: draft.hasActiveAdmission == null,
    clearHasOutstandingBalance: draft.hasOutstandingBalance == null,
  );
  final AppFailure? failure = await ref
      .read(patientRegistryControllerProvider.notifier)
      .applyQuery(nextQuery);
  if (context.mounted) {
    await _showFailureIfNeeded(context, failure);
  }
}

class _PatientList extends ConsumerWidget {
  const _PatientList({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final PatientRegistryState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<Patient>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return AppListTable<Patient>(
      page: state.page,
      title: l10n.patientsTableTitle,
      description: l10n.patientsTableDescription,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      search: AppListTableSearch<Patient>(
        controller: searchController,
        semanticLabel: l10n.patientsSearchLabel,
        hintText: l10n.patientsSearchHint,
        clearLabel: l10n.patientsClearFiltersAction,
        matcher: (Patient patient, String query) {
          return _matchesPatientTableSearch(context, patient, query);
        },
        onClear: () {
          unawaited(
            _applyPatientFilterDraft(
              context,
              ref,
              state,
              searchController,
              _patientFilterDraftFromQuery(state.query),
            ),
          );
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.patientsAdvancedFiltersAction,
        hasActiveFilters: _hasPatientAdvancedFilters(state.query),
        onAdvancedFilterPressed: () {
          unawaited(
            _openPatientAdvancedFilters(context, ref, state, searchController),
          );
        },
      ),
      isLoading: state.isRefreshingList,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columns: <AppListTableColumn<Patient>>[
        AppListTableColumn<Patient>(
          label: l10n.patientsPatientNumberColumnLabel,
          sortComparator: (Patient left, Patient right) =>
              appListTableCompareText(
                left.publicId ?? left.id,
                right.publicId ?? right.id,
              ),
          cellBuilder: (_, Patient patient) =>
              _PatientNumberCell(patient: patient),
        ),
        AppListTableColumn<Patient>(
          label: l10n.patientsPatientColumnLabel,
          sortComparator: (Patient left, Patient right) =>
              appListTableCompareText(
                left.effectiveDisplayName,
                right.effectiveDisplayName,
              ),
          cellBuilder: (_, Patient patient) =>
              _PatientNameCell(patient: patient),
        ),
        AppListTableColumn<Patient>(
          label: l10n.patientsAgeSexColumnLabel,
          sortComparator: (Patient left, Patient right) =>
              appListTableCompareDateTime(left.dateOfBirth, right.dateOfBirth),
          cellBuilder: (_, Patient patient) => _AgeSexText(patient: patient),
        ),
        AppListTableColumn<Patient>(
          label: l10n.patientsPhoneIdentifierColumnLabel,
          sortComparator: (Patient left, Patient right) =>
              appListTableCompareText(
                left.primaryPhone ??
                    left.primaryEmail ??
                    left.effectiveIdentifier,
                right.primaryPhone ??
                    right.primaryEmail ??
                    right.effectiveIdentifier,
              ),
          cellBuilder: (_, Patient patient) =>
              _PatientContactIdentifierCell(patient: patient),
        ),
        AppListTableColumn<Patient>(
          label: l10n.patientsAlertColumnLabel,
          sortComparator: (Patient left, Patient right) =>
              appListTableCompareText(
                _patientAlertSortValue(left),
                _patientAlertSortValue(right),
              ),
          cellBuilder: (_, Patient patient) =>
              _PatientAlertCell(patient: patient),
        ),
        AppListTableColumn<Patient>(
          label: l10n.patientsVisitColumnLabel,
          sortComparator: (Patient left, Patient right) =>
              appListTableCompareDateTime(
                left.currentVisit?.occurredAt,
                right.currentVisit?.occurredAt,
              ),
          cellBuilder: (_, Patient patient) =>
              _VisitContextCell(patient: patient),
        ),
        AppListTableColumn<Patient>(
          label: l10n.patientsStatusColumnLabel,
          sortComparator: (Patient left, Patient right) =>
              appListTableCompareText(
                left.isActive ? 'active' : 'inactive',
                right.isActive ? 'active' : 'inactive',
              ),
          cellBuilder: (BuildContext context, Patient patient) =>
              _patientActiveStatusText(context, patient.isActive),
        ),
        AppListTableColumn<Patient>(
          label: l10n.patientsNextActionColumnLabel,
          cellBuilder: (_, Patient patient) => _NextActionCell(
            patient: patient,
            onPressed: () {
              unawaited(_openPatientDetail(context, ref, patient.id));
            },
          ),
        ),
      ],
      mobileItemBuilder: (_, Patient patient) =>
          _PatientMobileRow(patient: patient),
      itemKeyBuilder: (Patient patient) => ValueKey<String>(patient.id),
      onRowSelected: (Patient patient) async {
        await _openPatientDetail(context, ref, patient.id);
      },
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.patientsEmptyTitle,
        body: l10n.patientsEmptyBody,
        icon: Icons.person_search_outlined,
        minHeight: 260,
      ),
      pageLabelBuilder: (AppPage<Patient> page) {
        return l10n.patientsPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.lastItemNumber,
        );
      },
      previousPageLabel: l10n.patientsPreviousPageLabel,
      nextPageLabel: l10n.patientsNextPageLabel,
      onPageChanged: (AppPageRequest request) async {
        final AppFailure? failure = await ref
            .read(patientRegistryControllerProvider.notifier)
            .applyQuery(state.query.copyWith(pageRequest: request));
        if (context.mounted) {
          await _showFailureIfNeeded(context, failure);
        }
      },
    );
  }
}

Future<void> _openPatientDetail(
  BuildContext context,
  WidgetRef ref,
  String patientId,
) async {
  unawaited(
    ref
        .read(patientRegistryControllerProvider.notifier)
        .selectPatient(patientId)
        .then((AppFailure? failure) async {
          if (context.mounted) {
            await _showFailureIfNeeded(context, failure);
          }
        }),
  );

  await showAppDialog<void>(
    context: context,
    builder: (_) => _PatientDetailDialog(patientId: patientId),
  );

  if (context.mounted) {
    ref.read(patientRegistryControllerProvider.notifier).clearSelection();
  }
}

class _PatientNameCell extends StatelessWidget {
  const _PatientNameCell({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppListItemText(
          title: patient.effectiveDisplayName,
          subtitle: patient.facilityLabel,
          titleStyle: theme.textTheme.titleSmall,
        ),
        if (patient.requiresCompletion)
          AppStatusText(
            label: context.l10n.patientsRegistrationIncompleteValue,
            tone: AppWorkspaceStatusTone.warning,
            icon: Icons.error_outline,
          ),
      ],
    );
  }
}

class _PatientNumberCell extends StatelessWidget {
  const _PatientNumberCell({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Text(
      patient.publicId ?? patient.id,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _AgeSexText extends StatelessWidget {
  const _AgeSexText({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String age = _patientAgeLabel(context, patient.dateOfBirth);
    final String sex = patient.gender == null
        ? l10n.profileUnknownValue
        : _genderLabel(l10n, patient.gender!);

    return Text(
      _ageSexLabel(age, sex),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String _ageSexLabel(String age, String sex) => '$age / $sex';

class _PatientContactIdentifierCell extends StatelessWidget {
  const _PatientContactIdentifierCell({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final String primary =
        patient.primaryPhone ??
        patient.primaryEmail ??
        patient.effectiveIdentifier ??
        l10n.profileUnknownValue;
    final String? secondary = primary == patient.effectiveIdentifier
        ? null
        : patient.effectiveIdentifier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(primary, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (secondary != null)
          Text(
            secondary,
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

class _PatientAlertCell extends StatelessWidget {
  const _PatientAlertCell({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final List<Widget> alerts = <Widget>[
      if (patient.hasAllergyAlert)
        AppStatusText(
          icon: Icons.warning_amber_outlined,
          label: patient.allergyAlertLabel ?? l10n.patientsAllergyAlertLabel,
          tone: AppWorkspaceStatusTone.warning,
        ),
      if (patient.requiresCompletion)
        AppStatusText(
          icon: Icons.error_outline,
          label: l10n.patientsRegistrationIncompleteValue,
          tone: AppWorkspaceStatusTone.warning,
        ),
    ];

    if (alerts.isEmpty) {
      return Text(
        l10n.patientsNoAlertsLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: alerts,
    );
  }
}

String _patientAlertSortValue(Patient patient) {
  return _joinDisplay(<String?>[
    patient.hasAllergyAlert ? patient.allergyAlertLabel ?? 'allergy' : null,
    patient.requiresCompletion ? 'incomplete' : null,
  ]);
}

class _VisitContextCell extends StatelessWidget {
  const _VisitContextCell({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final PatientVisitContext? visit = patient.currentVisit;
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    if (visit == null) {
      return Text(
        l10n.patientsNoVisitLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          _joinDisplay(<String?>[
            visit.title,
            visit.status == null ? null : _apiLabel(visit.status!),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          _formatOptionalDate(context, visit.occurredAt),
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

class _NextActionCell extends StatelessWidget {
  const _NextActionCell({required this.patient, required this.onPressed});

  final Patient patient;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!patient.requiresCompletion) {
      return AppButton.tertiary(
        label: l10n.patientsOpenRecordAction,
        leadingIcon: Icons.open_in_new,
        onPressed: onPressed,
      );
    }

    return AppAccessActionGate(
      requirement: const AccessRequirement(
        allPermissions: <AppPermission>[AppPermissions.patientWrite],
      ),
      builder: (_, bool isAllowed) => AppButton.secondary(
        label: l10n.patientsCompleteRecordAction,
        leadingIcon: Icons.edit_note_outlined,
        enabled: isAllowed,
        onPressed: isAllowed ? onPressed : null,
      ),
    );
  }
}

class _PatientMobileRow extends StatelessWidget {
  const _PatientMobileRow({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return AppListItemRow(
      leadingIcon: Icons.account_circle_outlined,
      title: patient.effectiveDisplayName,
      details: <Widget>[
        Text(patient.effectiveIdentifier ?? l10n.profileUnknownValue),
        _AgeSexText(patient: patient),
        if (patient.primaryPhone != null || patient.primaryEmail != null)
          Text(patient.primaryPhone ?? patient.primaryEmail!),
        _VisitContextCell(patient: patient),
        _patientActiveStatusText(context, patient.isActive),
        _PatientAlertCell(patient: patient),
        if (patient.requiresCompletion)
          AppStatusText(
            label: l10n.patientsRegistrationIncompleteValue,
            tone: AppWorkspaceStatusTone.warning,
            icon: Icons.error_outline,
          ),
      ],
      trailing: Icon(Icons.chevron_right, size: theme.appTokens.listIconSize),
    );
  }
}

Widget _patientActiveStatusText(BuildContext context, bool isActive) {
  final l10n = context.l10n;
  return AppStatusText(
    label: isActive ? l10n.patientsActiveFilter : l10n.patientsInactiveFilter,
    tone: isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral,
    icon: isActive ? Icons.check_circle_outline : Icons.block_outlined,
    fontWeight: FontWeight.w500,
  );
}

bool _matchesPatientTableSearch(
  BuildContext context,
  Patient patient,
  String query,
) {
  final List<String> tokens = _searchTokens(query);
  if (tokens.isEmpty) {
    return true;
  }

  final l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  final DateTime? dateOfBirth = patient.dateOfBirth;
  final String status = patient.isActive
      ? l10n.patientsActiveFilter
      : l10n.patientsInactiveFilter;
  final String haystack = <String?>[
    patient.effectiveDisplayName,
    patient.displayName,
    patient.firstName,
    patient.lastName,
    patient.effectiveIdentifier,
    patient.id,
    patient.publicId,
    patient.primaryIdentifierType,
    patient.primaryIdentifierValue,
    patient.primaryPhone,
    patient.primaryEmail,
    dateOfBirth == null ? null : AppFormatters.mediumDate(dateOfBirth, locale),
    dateOfBirth?.toIso8601String(),
    status,
    patient.isActive ? 'active' : 'inactive',
    patient.requiresCompletion ? 'incomplete registration emergency' : null,
    patient.registrationSource,
    patient.registrationStatus,
    patient.hasAllergyAlert ? context.l10n.patientsAllergyAlertLabel : null,
    patient.allergyAlertLabel,
    patient.currentVisit?.title,
    patient.currentVisit?.status,
    patient.currentVisit?.publicId,
    patient.currentVisit?.occurredAt?.toIso8601String(),
    patient.facilityLabel,
    patient.tenantLabel,
  ].whereType<String>().join(' ').toLowerCase();

  return tokens.every(haystack.contains);
}

List<String> _searchTokens(String query) {
  return query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

String _patientAgeLabel(BuildContext context, DateTime? dateOfBirth) {
  if (dateOfBirth == null) {
    return context.l10n.profileUnknownValue;
  }

  final DateTime today = DateTime.now();
  var years = today.year - dateOfBirth.year;
  if (today.month < dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
    years -= 1;
  }
  if (years > 0) {
    return years.toString();
  }

  var months = (today.year - dateOfBirth.year) * 12;
  months += today.month - dateOfBirth.month;
  if (today.day < dateOfBirth.day) {
    months -= 1;
  }
  if (months > 0) {
    return months.toString();
  }

  return today.difference(dateOfBirth).inDays.clamp(0, 30).toString();
}

class _PatientDetailDialog extends ConsumerWidget {
  const _PatientDetailDialog({required this.patientId});

  final String patientId;

  static const AccessRequirement _writeRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientWrite],
  );
  static const AccessRequirement _deleteRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientDelete],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Result<PatientRegistryState>? result = ref
        .watch(patientRegistryControllerProvider)
        .asData
        ?.value;
    final PatientRegistryState? state = switch (result) {
      ResultSuccess<PatientRegistryState>(value: final value) => value,
      _ => null,
    };
    final PatientDetail? selectedDetail = state?.selectedDetail;
    final PatientDetail? detail = selectedDetail?.patient.id == patientId
        ? selectedDetail
        : null;

    if ((state?.isRefreshingDetail ?? true) && detail == null) {
      return AppDialog(
        title: Text(l10n.patientsDetailTitle),
        icon: const Icon(Icons.assignment_ind_outlined),
        maxWidth: 960,
        scrollable: true,
        content: AppWorkspaceStatePanel.loading(
          title: l10n.patientsDetailLoadingTitle,
          body: l10n.patientsDetailLoadingBody,
          minHeight: 320,
        ),
      );
    }

    if (detail == null) {
      final Object? failure = state?.lastFailure;
      return AppDialog(
        title: Text(l10n.patientsDetailTitle),
        icon: const Icon(Icons.assignment_ind_outlined),
        maxWidth: 960,
        scrollable: true,
        content: failure is AppFailure
            ? AppFailureStateView(failure: failure)
            : AppWorkspaceStatePanel.empty(
                title: l10n.patientsNoSelectionTitle,
                body: l10n.patientsNoSelectionBody,
                icon: Icons.badge_outlined,
                minHeight: 320,
              ),
      );
    }

    final Patient patient = detail.patient;
    return AppDialog(
      title: Text(patient.effectiveDisplayName),
      icon: const Icon(Icons.assignment_ind_outlined),
      maxWidth: 980,
      scrollable: true,
      actions: <Widget>[
        AppAccessActionGate(
          requirement: _writeRequirement,
          builder: (_, bool isAllowed) => AppButton.secondary(
            label: l10n.patientsEditAction,
            leadingIcon: Icons.edit_outlined,
            onPressed: isAllowed
                ? () => _openPatientForm(context, ref, patient)
                : null,
          ),
        ),
        AppAccessActionGate(
          requirement: _deleteRequirement,
          builder: (_, bool isAllowed) => AppButton.tertiary(
            label: l10n.patientsDeleteAction,
            leadingIcon: Icons.delete_outline,
            onPressed: isAllowed
                ? () => _confirmDeletePatient(context, ref, patient)
                : null,
          ),
        ),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state?.isRefreshingDetail ?? false)
            const LinearProgressIndicator(),
          _PatientContextHeader(detail: detail),
          const Divider(),
          _QuickActions(patient: patient),
          const Divider(),
          AppExpandableRecordSection<PatientIdentifier>(
            title: l10n.patientsIdentifiersSectionTitle,
            emptyLabel: l10n.patientsNoIdentifiers,
            items: detail.identifiers,
            itemTitle: (PatientIdentifier item) => item.value,
            itemSubtitle: (PatientIdentifier item) => item.type,
            addLabel: l10n.patientsAddRelatedAction,
            editLabel: l10n.patientsEditAction,
            deleteLabel: l10n.patientsDeleteAction,
            addRequirement: _writeRequirement,
            editRequirement: _writeRequirement,
            deleteRequirement: _deleteRequirement,
            onAdd: () =>
                _openRelatedForm<PatientIdentifier>(context, ref, detail),
            onEdit: (PatientIdentifier item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientIdentifier item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          AppExpandableRecordSection<PatientContact>(
            title: l10n.patientsContactsSectionTitle,
            emptyLabel: l10n.patientsNoContacts,
            items: detail.contacts,
            itemTitle: (PatientContact item) => item.value,
            itemSubtitle: (PatientContact item) => _apiLabel(item.type),
            addLabel: l10n.patientsAddRelatedAction,
            editLabel: l10n.patientsEditAction,
            deleteLabel: l10n.patientsDeleteAction,
            addRequirement: _writeRequirement,
            editRequirement: _writeRequirement,
            deleteRequirement: _deleteRequirement,
            onAdd: () => _openRelatedForm<PatientContact>(context, ref, detail),
            onEdit: (PatientContact item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientContact item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          AppExpandableRecordSection<PatientGuardian>(
            title: l10n.patientsGuardiansSectionTitle,
            emptyLabel: l10n.patientsNoGuardians,
            items: detail.guardians,
            itemTitle: (PatientGuardian item) => item.name,
            itemSubtitle: (PatientGuardian item) =>
                item.relationship ?? l10n.profileUnknownValue,
            addLabel: l10n.patientsAddRelatedAction,
            editLabel: l10n.patientsEditAction,
            deleteLabel: l10n.patientsDeleteAction,
            addRequirement: _writeRequirement,
            editRequirement: _writeRequirement,
            deleteRequirement: _deleteRequirement,
            onAdd: () =>
                _openRelatedForm<PatientGuardian>(context, ref, detail),
            onEdit: (PatientGuardian item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientGuardian item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          AppExpandableRecordSection<PatientAllergy>(
            title: l10n.patientsAllergiesSectionTitle,
            emptyLabel: l10n.patientsNoAllergies,
            items: detail.allergies,
            itemTitle: (PatientAllergy item) => item.allergen,
            itemSubtitle: (PatientAllergy item) => _apiLabel(item.severity),
            addLabel: l10n.patientsAddRelatedAction,
            editLabel: l10n.patientsEditAction,
            deleteLabel: l10n.patientsDeleteAction,
            addRequirement: _writeRequirement,
            editRequirement: _writeRequirement,
            deleteRequirement: _deleteRequirement,
            onAdd: () => _openRelatedForm<PatientAllergy>(context, ref, detail),
            onEdit: (PatientAllergy item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientAllergy item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          AppExpandableRecordSection<PatientMedicalHistory>(
            title: l10n.patientsMedicalHistorySectionTitle,
            emptyLabel: l10n.patientsNoMedicalHistory,
            items: detail.medicalHistories,
            itemTitle: (PatientMedicalHistory item) => item.condition,
            itemSubtitle: (PatientMedicalHistory item) =>
                _formatOptionalDate(context, item.diagnosisDate),
            addLabel: l10n.patientsAddRelatedAction,
            editLabel: l10n.patientsEditAction,
            deleteLabel: l10n.patientsDeleteAction,
            addRequirement: _writeRequirement,
            editRequirement: _writeRequirement,
            deleteRequirement: _deleteRequirement,
            onAdd: () =>
                _openRelatedForm<PatientMedicalHistory>(context, ref, detail),
            onEdit: (PatientMedicalHistory item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientMedicalHistory item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          AppExpandableRecordSection<PatientDocument>(
            title: l10n.patientsDocumentsSectionTitle,
            emptyLabel: l10n.patientsNoDocuments,
            items: detail.documents,
            itemTitle: (PatientDocument item) =>
                item.fileName ?? item.documentType,
            itemSubtitle: (PatientDocument item) =>
                _apiLabel(item.documentType),
            addLabel: l10n.patientsAddRelatedAction,
            editLabel: l10n.patientsEditAction,
            deleteLabel: l10n.patientsDeleteAction,
            addRequirement: _writeRequirement,
            editRequirement: _writeRequirement,
            deleteRequirement: _deleteRequirement,
            onAdd: () =>
                _openRelatedForm<PatientDocument>(context, ref, detail),
            onEdit: (PatientDocument item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientDocument item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          AppExpandableRecordSection<PatientConsent>(
            title: l10n.patientsConsentsSectionTitle,
            emptyLabel: l10n.patientsNoConsents,
            items: detail.consents,
            itemTitle: (PatientConsent item) => _apiLabel(item.consentType),
            itemSubtitle: (PatientConsent item) => _apiLabel(item.status),
            addLabel: l10n.patientsAddRelatedAction,
            editLabel: l10n.patientsEditAction,
            deleteLabel: l10n.patientsDeleteAction,
            addRequirement: _writeRequirement,
            editRequirement: _writeRequirement,
            deleteRequirement: _deleteRequirement,
            onAdd: () => _openRelatedForm<PatientConsent>(context, ref, detail),
            onEdit: (PatientConsent item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientConsent item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          PatientTimelineList(items: detail.timeline),
        ],
      ),
    );
  }

  Future<void> _openPatientForm(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PatientFormDialog(
        patient: patient,
        referenceData:
            _readCurrentState(ref)?.referenceData ??
            const PatientReferenceData(),
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .updatePatient(patient.id, payload);
        },
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsSavedMessage)),
      );
    }
  }

  Future<void> _confirmDeletePatient(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final bool? confirmed = await _showDeleteDialog(
      context,
      title: context.l10n.patientsDeleteTitle,
      body: context.l10n.patientsDeleteBody(patient.effectiveDisplayName),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .deletePatient(patient.id);
    if (context.mounted && failure == null) {
      final NavigatorState navigator = Navigator.of(context);
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      final String message = context.l10n.patientsDeletedMessage;
      await navigator.maybePop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } else if (context.mounted) {
      await _showFailureIfNeeded(context, failure);
    }
  }

  Future<void> _openRelatedForm<T>(
    BuildContext context,
    WidgetRef ref,
    PatientDetail detail, {
    T? item,
  }) async {
    final PatientRelatedResource resource = _resourceForItem<T>(item);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PatientRelatedRecordDialog<T>(
        detail: detail,
        resource: resource,
        item: item,
        referenceData:
            _readCurrentState(ref)?.referenceData ??
            const PatientReferenceData(),
        onCreate: (Map<String, Object?> payload) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .createRelatedRecord(resource, payload);
        },
        onUpdate: (String recordId, Map<String, Object?> payload) {
          return ref
              .read(patientRegistryControllerProvider.notifier)
              .updateRelatedRecord(resource, recordId, payload);
        },
        onUploadDocuments:
            ({
              required String patientId,
              required String documentType,
              required List<PatientDocumentUploadFile> files,
            }) {
              return ref
                  .read(patientRegistryControllerProvider.notifier)
                  .uploadPatientDocuments(
                    patientId: patientId,
                    documentType: documentType,
                    files: files,
                  );
            },
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsSavedMessage)),
      );
    }
  }

  Future<void> _confirmDeleteRelated(
    BuildContext context,
    WidgetRef ref,
    PatientDetail detail,
    String recordId,
  ) async {
    final bool? confirmed = await _showDeleteDialog(
      context,
      title: context.l10n.patientsRelatedDeleteTitle,
      body: context.l10n.patientsRelatedDeleteBody,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final PatientRelatedResource resource = _resourceForRecordId(
      detail,
      recordId,
    );
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .deleteRelatedRecord(resource, recordId);
    if (context.mounted && failure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsDeletedMessage)),
      );
    } else if (context.mounted) {
      await _showFailureIfNeeded(context, failure);
    }
  }
}

class _PatientContextHeader extends StatelessWidget {
  const _PatientContextHeader({required this.detail});

  final PatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final Patient patient = detail.patient;
    final l10n = context.l10n;
    final String gender = patient.gender == null
        ? l10n.profileUnknownValue
        : _genderLabel(l10n, patient.gender!);
    final String demographics = _joinDisplay(<String?>[
      _patientAgeLabel(context, patient.dateOfBirth),
      gender,
    ]);
    final PatientVisitContext? visit = patient.currentVisit;

    return AppWorkspacePatientContextHeader(
      patientName: patient.effectiveDisplayName,
      patientNumber: patient.effectiveIdentifier ?? patient.id,
      demographics: demographics,
      semanticLabel: l10n.patientsDetailTitle,
      status: AppWorkspaceStatus(
        label: patient.isActive
            ? l10n.patientsActiveFilter
            : l10n.patientsInactiveFilter,
        tone: patient.isActive
            ? AppWorkspaceStatusTone.success
            : AppWorkspaceStatusTone.neutral,
        icon: patient.isActive
            ? Icons.check_circle_outline
            : Icons.block_outlined,
      ),
      alerts: <AppWorkspaceStatus>[
        if (patient.hasAllergyAlert)
          AppWorkspaceStatus(
            label: patient.allergyAlertLabel ?? l10n.patientsAllergyAlertLabel,
            tone: AppWorkspaceStatusTone.warning,
            icon: Icons.warning_amber_outlined,
          ),
        if (patient.requiresCompletion)
          AppWorkspaceStatus(
            label: l10n.patientsRegistrationIncompleteValue,
            tone: AppWorkspaceStatusTone.warning,
            icon: Icons.error_outline,
          ),
      ],
      fieldStyle: AppWorkspacePatientContextFieldStyle.inline,
      fields: <AppWorkspacePatientContextField>[
        AppWorkspacePatientContextField(
          label: l10n.patientsDobLabel,
          value: _formatOptionalDate(context, patient.dateOfBirth),
          icon: Icons.cake_outlined,
        ),
        AppWorkspacePatientContextField(
          label: l10n.patientsPhoneLabel,
          value: patient.primaryPhone ?? '',
          icon: Icons.phone_outlined,
        ),
        AppWorkspacePatientContextField(
          label: l10n.patientsFacilityLabel,
          value: patient.facilityLabel ?? '',
          icon: Icons.business_outlined,
        ),
        if (visit != null)
          AppWorkspacePatientContextField(
            label: l10n.patientsVisitColumnLabel,
            value: _joinDisplay(<String?>[
              visit.title,
              visit.publicId,
              visit.status == null ? null : _apiLabel(visit.status!),
            ]),
            icon: Icons.assignment_turned_in_outlined,
            tone: AppWorkspaceStatusTone.info,
          ),
      ],
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final PatientVisitContext? visit = patient.currentVisit;
    final bool hasActiveOpdEncounter = _isActiveOpdVisit(visit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.patientsQuickActionsTitle, style: theme.textTheme.titleSmall),
        SizedBox(height: theme.spacing.sm),
        AppPermissionActionList(
          actions: <AppPermissionActionItem>[
            AppPermissionActionItem(
              label: l10n.patientsQuickAppointmentAction,
              icon: Icons.event_available_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.appointment,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.patientWrite],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.patientsQuickOpdCheckInAction,
              icon: opdEncounterIcon,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.opdCheckIn,
              ),
              requirement: opdEncounterPermissionRequirement,
            ),
            if (hasActiveOpdEncounter)
              AppPermissionActionItem(
                label: l10n.patientsQuickViewActiveOpdAction,
                icon: Icons.open_in_new_outlined,
                onPressed: () => _openQuickAction(
                  context,
                  ref,
                  patient,
                  _PatientQuickAction.opdActions,
                ),
                requirement: const AccessRequirement(
                  anyPermissions: <AppPermission>[
                    AppPermissions.clinicalRead,
                    AppPermissions.clinicalWrite,
                    AppPermissions.billingRead,
                    AppPermissions.billingWrite,
                  ],
                ),
              ),
            AppPermissionActionItem(
              label: l10n.patientsQuickTriageAction,
              icon: Icons.monitor_heart_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.triage,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.emergencyWrite],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.opdRecordVitalsAction,
              icon: Icons.monitor_heart_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.opdActions,
              ),
              requirement: const AccessRequirement(
                anyPermissions: <AppPermission>[
                  AppPermissions.clinicalWrite,
                  AppPermissions.emergencyWrite,
                ],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.opdAssignDoctorAction,
              icon: Icons.assignment_ind_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.opdActions,
              ),
              requirement: const AccessRequirement(
                anyPermissions: <AppPermission>[
                  AppPermissions.patientWrite,
                  AppPermissions.operationsWrite,
                  AppPermissions.clinicalWrite,
                ],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.opdDoctorReviewAction,
              icon: Icons.edit_note_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.opdActions,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.opdManageConsultationBillingAction,
              icon: Icons.receipt_long_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                hasActiveOpdEncounter
                    ? _PatientQuickAction.opdActions
                    : _PatientQuickAction.billing,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.billingWrite],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.clinicalRequestLabAction,
              icon: Icons.science_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.opdActions,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.clinicalRequestRadiologyAction,
              icon: Icons.biotech_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.opdActions,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.clinicalPrescribeAction,
              icon: Icons.medication_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.opdActions,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.patientsQuickAdmissionAction,
              icon: Icons.local_hospital_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.admission,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.patientsQuickReportAction,
              icon: Icons.summarize_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.report,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.reportsRead],
              ),
            ),
            AppPermissionActionItem(
              label: l10n.opdCopyPatientIdAction,
              icon: Icons.copy_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.copyPatientId,
              ),
              requirement: const AccessRequirement(
                anyPermissions: <AppPermission>[
                  AppPermissions.patientRead,
                  AppPermissions.patientWrite,
                ],
              ),
            ),
            if (hasActiveOpdEncounter)
              AppPermissionActionItem(
                label: l10n.opdCopyEncounterIdAction,
                icon: Icons.copy_outlined,
                onPressed: () => _openQuickAction(
                  context,
                  ref,
                  patient,
                  _PatientQuickAction.copyEncounterId,
                ),
                requirement: const AccessRequirement(
                  anyPermissions: <AppPermission>[
                    AppPermissions.clinicalRead,
                    AppPermissions.clinicalWrite,
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

enum _PatientQuickAction {
  appointment,
  opdCheckIn,
  opdActions,
  triage,
  billing,
  admission,
  report,
  copyPatientId,
  copyEncounterId,
}

Future<void> _openQuickAction(
  BuildContext context,
  WidgetRef ref,
  Patient patient,
  _PatientQuickAction action,
) async {
  final PatientRegistryState? state = _readCurrentState(ref);
  final PatientReferenceData referenceData =
      state?.referenceData ?? const PatientReferenceData();
  final PatientDetail? detail = state?.selectedDetail?.patient.id == patient.id
      ? state?.selectedDetail
      : null;
  if (action == _PatientQuickAction.copyPatientId) {
    await Clipboard.setData(ClipboardData(text: _patientApiId(patient)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.clinicalPatientIdCopiedMessage)),
      );
    }
    return;
  }
  if (action == _PatientQuickAction.copyEncounterId) {
    final String? encounterId = patient.currentVisit?.publicId;
    if (encounterId != null && encounterId.trim().isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: encounterId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.opdEncounterIdCopiedMessage)),
        );
      }
    }
    return;
  }
  if (action == _PatientQuickAction.opdActions) {
    await _openActiveOpdActions(context, ref, patient);
    return;
  }

  final bool? changed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return switch (action) {
        _PatientQuickAction.appointment => PatientAppointmentQuickDialog(
          patient: patient,
          referenceData: referenceData,
        ),
        _PatientQuickAction.triage => _PatientTriageQuickDialog(
          patient: patient,
          referenceData: referenceData,
        ),
        _PatientQuickAction.admission => _PatientAdmissionQuickDialog(
          patient: patient,
          referenceData: referenceData,
        ),
        _PatientQuickAction.report => _PatientReportPrintPreviewDialog(
          detail: detail,
          patient: patient,
        ),
        _PatientQuickAction.opdCheckIn => OpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          initialPatient: patient,
          initialPatientId: _patientApiId(patient),
          source: 'patient_registry',
          onSubmit: (Map<String, Object?> payload) async {
            final Object? existingEncounterId =
                payload['existing_encounter_id'];
            if (existingEncounterId is String &&
                existingEncounterId.trim().isNotEmpty) {
              final Result<OpdFlowDetail> result = await ref
                  .read(opdRepositoryProvider)
                  .getOpdFlow(existingEncounterId.trim());
              return _failureOrNull(result);
            }

            final Result<OpdFlowDetail> result = await ref
                .read(opdRepositoryProvider)
                .startOpdFlow(
                  _withoutEmptyPayload(<String, Object?>{
                    'tenant_id': patient.tenantId,
                    'facility_id': patient.facilityId,
                    ...payload,
                  }),
                );
            return _failureOrNull(result);
          },
        ),
        _ => _PatientFlowQuickDialog(
          patient: patient,
          referenceData: referenceData,
          action: action,
        ),
      };
    },
  );

  if (changed == true && context.mounted) {
    await ref
        .read(patientRegistryControllerProvider.notifier)
        .selectPatient(patient.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsQuickActionSavedMessage)),
      );
    }
  }
}

bool _isActiveOpdVisit(PatientVisitContext? visit) {
  if (visit == null) {
    return false;
  }
  final String title = (visit.title ?? '').toUpperCase();
  final String status = (visit.status ?? '').toUpperCase();
  return visit.kind == 'encounter' &&
      (title.contains('OPD') || title.contains('EMERGENCY')) &&
      !isOpdTerminalStatus(status);
}

Future<void> _openActiveOpdActions(
  BuildContext context,
  WidgetRef ref,
  Patient patient,
) async {
  final String? encounterId = patient.currentVisit?.publicId;
  if (encounterId == null || encounterId.trim().isEmpty) {
    return;
  }
  final Result<OpdFlowDetail> result = await ref
      .read(opdRepositoryProvider)
      .getOpdFlow(encounterId.trim());
  if (!context.mounted) {
    return;
  }
  final OpdFlowDetail? detail = result.when(
    success: (OpdFlowDetail value) => value,
    failure: (AppFailure failure) {
      _showFailureIfNeeded(context, failure);
      return null;
    },
  );
  if (detail == null || !context.mounted) {
    return;
  }
  final bool? changed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FlowActionsDialog(flow: detail.summary),
  );
  if (changed == true && context.mounted) {
    await ref
        .read(patientRegistryControllerProvider.notifier)
        .selectPatient(patient.id);
  }
}

class PatientAppointmentQuickDialog extends ConsumerStatefulWidget {
  const PatientAppointmentQuickDialog({
    required this.patient,
    required this.referenceData,
    super.key,
  });

  final Patient patient;
  final PatientReferenceData referenceData;

  @override
  ConsumerState<PatientAppointmentQuickDialog> createState() =>
      _PatientAppointmentQuickDialogState();
}

class _PatientAppointmentQuickDialogState
    extends ConsumerState<PatientAppointmentQuickDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _timeController = TextEditingController(
    text: '09:00',
  );
  final TextEditingController _durationController = TextEditingController(
    text: '30',
  );
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _date = DateTime.now();
  String? _facilityId;
  String? _providerId;
  String _status = 'SCHEDULED';
  List<OpdProviderOption> _providers = const <OpdProviderOption>[];
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _facilityId = widget.patient.facilityId;
    unawaited(_loadProviders());
  }

  @override
  void dispose() {
    _timeController.dispose();
    _durationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.patientsAppointmentDialogTitle),
      icon: const Icon(Icons.event_available_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 720,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: _failure == null
            ? null
            : AppFailureStateView(
                failure: _failure!,
                body: _workflowFailureMessage(context, _failure!),
              ),
        children: <Widget>[
          if (widget.referenceData.facilities.length > 1)
            _facilitySelect(context),
          _appointmentScheduleFields(context),
          AppResponsiveFieldRow.two(
            left: _statusSelect(context),
            right: _providerSelect(context),
          ),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.patientsAppointmentReasonLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
        AppButton.primary(
          label: l10n.patientsQuickAppointmentAction,
          leadingIcon: Icons.event_available_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _appointmentScheduleFields(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = theme.spacing.sm;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget dateField = _appointmentDateField(context);
        final Widget timeField = _appointmentTimeField(context);
        final Widget durationField = _appointmentDurationField(context);

        if (constraints.maxWidth >= 680) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 6, child: dateField),
              SizedBox(width: gap),
              SizedBox(width: 136, child: timeField),
              SizedBox(width: gap),
              SizedBox(width: 164, child: durationField),
            ],
          );
        }

        if (constraints.maxWidth >= 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              dateField,
              SizedBox(height: gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 136, child: timeField),
                  SizedBox(width: gap),
                  SizedBox(width: 164, child: durationField),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            dateField,
            SizedBox(height: gap),
            timeField,
            SizedBox(height: gap),
            durationField,
          ],
        );
      },
    );
  }

  Widget _appointmentDateField(BuildContext context) {
    final l10n = context.l10n;

    return PatientDateField(
      value: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      labelText: l10n.patientsAppointmentDateLabel,
      isRequired: true,
      enabled: !_isSaving,
      validator: AppValidators.requiredValue(l10n.validationRequired),
      onChanged: (DateTime? value) => _date = value,
    );
  }

  Widget _appointmentTimeField(BuildContext context) {
    final l10n = context.l10n;

    return AppTextField(
      controller: _timeController,
      labelText: l10n.patientsAppointmentTimeLabel,
      hintText: l10n.patientsTimeHint,
      enabled: !_isSaving,
      isRequired: true,
      keyboardType: TextInputType.datetime,
      validator: _timeValidator(context),
    );
  }

  Widget _appointmentDurationField(BuildContext context) {
    return AppTextField(
      controller: _durationController,
      labelText: context.l10n.patientsAppointmentDurationLabel,
      enabled: !_isSaving,
      isRequired: true,
      keyboardType: TextInputType.number,
      validator: _durationValidator(context),
    );
  }

  Widget _facilitySelect(BuildContext context) {
    return PatientFacilitySelectField(
      facilities: widget.referenceData.facilities,
      value: _facilityId,
      labelText: context.l10n.patientsFacilityLabel,
      enabled: !_isSaving,
      onChanged: (String? value) => setState(() => _facilityId = value),
    );
  }

  Widget _statusSelect(BuildContext context) {
    return AppSelectField<String>.searchable(
      value: _status,
      labelText: context.l10n.patientsAppointmentStatusLabel,
      enabled: !_isSaving,
      onChanged: (String? value) =>
          setState(() => _status = value ?? 'SCHEDULED'),
      options: _simpleStatusOptions(const <String>['SCHEDULED', 'CONFIRMED']),
    );
  }

  Widget _providerSelect(BuildContext context) {
    return AppSelectField<String>.searchable(
      value: _providerId,
      labelText: context.l10n.patientsProviderLabel,
      helperText: context.l10n.patientsProviderOptionalHelper,
      enabled: !_isSaving,
      isLoading: _isLoadingProviders,
      onChanged: (String? value) => setState(() => _providerId = value),
      options: _providerSelectOptions(_providers),
    );
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoadingProviders = true);
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }
    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providers = providers;
          _isLoadingProviders = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingProviders = false;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final DateTime scheduledStart = _combineDateAndTime(
      _date!,
      _timeController.text,
    )!;
    final int duration = int.parse(_durationController.text.trim());

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final Result<OpdAppointment> result = await ref
        .read(opdRepositoryProvider)
        .createAppointment(
          _withoutEmptyPayload(<String, Object?>{
            'tenant_id': widget.patient.tenantId,
            'facility_id': _facilityId,
            'patient_id': widget.patient.id,
            'provider_user_id': _providerId,
            'status': _status,
            'scheduled_start': scheduledStart.toUtc().toIso8601String(),
            'scheduled_end': scheduledStart
                .add(Duration(minutes: duration))
                .toUtc()
                .toIso8601String(),
            'reason': _reasonController.text.trim(),
          }),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (AppFailure failure) {
        setState(() {
          _isSaving = false;
          _failure = failure;
        });
      },
    );
  }
}

class _PatientTriageQuickDialog extends ConsumerStatefulWidget {
  const _PatientTriageQuickDialog({
    required this.patient,
    required this.referenceData,
  });

  final Patient patient;
  final PatientReferenceData referenceData;

  @override
  ConsumerState<_PatientTriageQuickDialog> createState() =>
      _PatientTriageQuickDialogState();
}

class _PatientTriageQuickDialogState
    extends ConsumerState<_PatientTriageQuickDialog> {
  String? _facilityId;
  String? _providerId;
  List<OpdProviderOption> _providers = const <OpdProviderOption>[];
  bool _isLoadingProviders = false;
  AppFailure? _providerFailure;

  @override
  void initState() {
    super.initState();
    _facilityId = widget.patient.facilityId;
    unawaited(_loadProviders());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppTriageActionDialog(
      title: l10n.patientsTriageDialogTitle,
      submitLabel: l10n.patientsQuickTriageAction,
      cancelLabel: l10n.commonCancelActionLabel,
      requiredMessage: l10n.validationRequired,
      prioritySectionTitle: l10n.patientsTriagePrioritySectionTitle,
      severityLabel: l10n.patientsEmergencySeverityLabel,
      severityOptions: _statusTriageOptions(_emergencySeverityOptions),
      initialSeverity: 'HIGH',
      triageLevelLabel: l10n.patientsTriageLevelLabel,
      triageLevelRequired: false,
      triageLevelOptions: _statusTriageOptions(_triageLevelOptions),
      chiefComplaintLabel: l10n.patientsChiefComplaintLabel,
      chiefComplaintRequired: true,
      notesSectionTitle: l10n.patientsNotesSectionTitle,
      notesLabel: l10n.patientsNotesLabel,
      vitalsSectionTitle: l10n.patientsVitalsSectionTitle,
      vitalsReference: AppVitalsReference.fromPatientData(
        dateOfBirth: widget.patient.dateOfBirth,
        gender: widget.patient.gender,
      ),
      requireVitals: true,
      vitalsRequiredMessage: l10n.patientsVitalsRequiredMessage,
      bloodPressureLabel: l10n.patientsBloodPressureLabel,
      temperatureLabel: l10n.patientsTemperatureLabel,
      systolicLabel: l10n.patientsSystolicLabel,
      diastolicLabel: l10n.patientsDiastolicLabel,
      heartRateLabel: l10n.patientsHeartRateLabel,
      respiratoryRateLabel: l10n.patientsRespiratoryRateLabel,
      oxygenSaturationLabel: l10n.patientsOxygenSaturationLabel,
      weightLabel: l10n.patientsWeightLabel,
      heightLabel: l10n.patientsHeightLabel,
      unitLabel: l10n.patientsVitalUnitLabel,
      failureBodyBuilder: _workflowFailureMessage,
      leadingSectionsBuilder: _workflowFields,
      onSubmit: _submitTriage,
    );
  }

  List<Widget> _workflowFields(BuildContext context, bool enabled) {
    final l10n = context.l10n;
    return <Widget>[
      if (_providerFailure != null)
        AppFailureStateView(
          failure: _providerFailure!,
          body: _workflowFailureMessage(context, _providerFailure!),
        ),
      AppFormSection(
        title: l10n.patientsWorkflowSectionTitle,
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (widget.referenceData.facilities.length > 1)
            _facilitySelect(context, enabled),
          _providerSelect(context, enabled),
        ],
      ),
    ];
  }

  Widget _facilitySelect(BuildContext context, bool enabled) {
    return PatientFacilitySelectField(
      facilities: widget.referenceData.facilities,
      value: _facilityId,
      labelText: context.l10n.patientsFacilityLabel,
      enabled: enabled,
      onChanged: (String? value) => setState(() => _facilityId = value),
    );
  }

  Widget _providerSelect(BuildContext context, bool enabled) {
    return AppSelectField<String>.searchable(
      value: _providerId,
      labelText: context.l10n.patientsProviderLabel,
      helperText: context.l10n.patientsProviderOptionalHelper,
      enabled: enabled,
      isLoading: _isLoadingProviders,
      onChanged: (String? value) => setState(() => _providerId = value),
      options: _providerSelectOptions(_providers),
    );
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoadingProviders = true);
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }
    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providers = providers;
          _providerFailure = null;
          _isLoadingProviders = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _providerFailure = failure;
          _isLoadingProviders = false;
        });
      },
    );
  }

  Future<AppFailure?> _submitTriage(AppTriageActionInput input) async {
    final List<Map<String, Object?>> vitals = _vitalPayload(input.vitals);
    if (vitals.isEmpty) {
      return AppFailure.validation(validationFields: const <String>{'vitals'});
    }

    final Result<OpdFlowDetail> flowResult = await ref
        .read(opdRepositoryProvider)
        .startOpdFlow(
          _baseFlowPayload(input, <String, Object?>{
            'arrival_mode': 'EMERGENCY',
            'emergency': _emergencyPayload(input),
            'initial_stage': 'WAITING_VITALS',
            'notes': input.chiefComplaint,
            'require_consultation_payment': false,
            'create_consultation_invoice': false,
          }),
        );
    final OpdFlowDetail? flow = _successOrNull(flowResult);
    if (flow == null) {
      return _failureOrNull(flowResult);
    }

    final Result<OpdFlowDetail> vitalsResult = await ref
        .read(opdRepositoryProvider)
        .recordVitals(
          flow.summary.apiId,
          _withoutEmptyPayload(<String, Object?>{
            'vitals': vitals,
            'triage_level': input.triageLevel,
            'triage_priority': input.triageLevel,
            'chief_complaint': input.chiefComplaint,
            'emergency': true,
            'triage_notes': input.notes,
          }),
        );
    final OpdFlowDetail? triaged = _successOrNull(vitalsResult);
    if (triaged == null) {
      return _failureOrNull(vitalsResult);
    }

    if (_providerId == null) {
      return null;
    }

    final Result<OpdFlowDetail> assignResult = await ref
        .read(opdRepositoryProvider)
        .assignDoctor(triaged.summary.apiId, <String, Object?>{
          'provider_user_id': _providerId,
        });
    return _failureOrNull(assignResult);
  }

  Map<String, Object?> _baseFlowPayload(
    AppTriageActionInput input,
    Map<String, Object?> extra,
  ) {
    return _withoutEmptyPayload(<String, Object?>{
      'tenant_id': widget.patient.tenantId,
      'facility_id': _facilityId,
      'patient_id': widget.patient.id,
      'provider_user_id': _providerId,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
      'notes': input.notes,
      ...extra,
    });
  }

  Map<String, Object?> _emergencyPayload(AppTriageActionInput input) {
    return _withoutEmptyPayload(<String, Object?>{
      'severity': input.severity,
      'triage_level': input.triageLevel,
      'notes': input.notes,
    });
  }

  List<Map<String, Object?>> _vitalPayload(AppTriageVitalsInput? input) {
    if (input == null) {
      return const <Map<String, Object?>>[];
    }
    final List<Map<String, Object?>> vitals = <Map<String, Object?>>[];
    final String now = DateTime.now().toUtc().toIso8601String();
    final String systolic = _bloodPressurePayloadValue(
      input.systolic,
      input.bloodPressureUnit,
    );
    final String diastolic = _bloodPressurePayloadValue(
      input.diastolic,
      input.bloodPressureUnit,
    );
    if (systolic.isNotEmpty && diastolic.isNotEmpty) {
      vitals.add(<String, Object?>{
        'vital_type': 'BLOOD_PRESSURE',
        'systolic_value': systolic,
        'diastolic_value': diastolic,
        'unit': AppVitalsUnits.bloodPressureMmHg,
        'recorded_at': now,
      });
    }
    if (input.temperature.trim().isNotEmpty) {
      vitals.add(<String, Object?>{
        'vital_type': 'TEMPERATURE',
        'value': normalizeCurrencyAmount(input.temperature),
        'unit': input.temperatureUnit,
        'recorded_at': now,
      });
    }
    if (input.heartRate.trim().isNotEmpty) {
      vitals.add(<String, Object?>{
        'vital_type': 'HEART_RATE',
        'value': input.heartRate.trim(),
        'unit': 'BPM',
        'recorded_at': now,
      });
    }
    if (input.respiratoryRate.trim().isNotEmpty) {
      vitals.add(<String, Object?>{
        'vital_type': 'RESPIRATORY_RATE',
        'value': input.respiratoryRate.trim(),
        'unit': 'BREATHS_PER_MIN',
        'recorded_at': now,
      });
    }
    if (input.oxygenSaturation.trim().isNotEmpty) {
      vitals.add(<String, Object?>{
        'vital_type': 'OXYGEN_SATURATION',
        'value': input.oxygenSaturation.trim(),
        'unit': 'PERCENT',
        'recorded_at': now,
      });
    }
    if (input.weight.trim().isNotEmpty) {
      vitals.add(<String, Object?>{
        'vital_type': 'WEIGHT',
        'value': normalizeCurrencyAmount(input.weight),
        'unit': input.weightUnit,
        'recorded_at': now,
      });
    }
    if (input.height.trim().isNotEmpty) {
      vitals.add(<String, Object?>{
        'vital_type': 'HEIGHT',
        'value': normalizeCurrencyAmount(input.height),
        'unit': input.heightUnit,
        'recorded_at': now,
      });
    }
    return vitals;
  }

  String _bloodPressurePayloadValue(String value, String unit) {
    final double? parsed = parseAppVitalInput(value);
    if (parsed == null) {
      return '';
    }

    final double mmHg = unit == AppVitalsUnits.bloodPressureKpa
        ? parsed / AppVitalsUnits.bloodPressureKpaFactor
        : parsed;
    return formatAppVitalNumber(mmHg, decimals: 2);
  }
}

class _PatientAdmissionQuickDialog extends ConsumerStatefulWidget {
  const _PatientAdmissionQuickDialog({
    required this.patient,
    required this.referenceData,
  });

  final Patient patient;
  final PatientReferenceData referenceData;

  @override
  ConsumerState<_PatientAdmissionQuickDialog> createState() =>
      _PatientAdmissionQuickDialogState();
}

class _PatientAdmissionQuickDialogState
    extends ConsumerState<_PatientAdmissionQuickDialog> {
  String? _facilityId;

  @override
  void initState() {
    super.initState();
    _facilityId = widget.patient.facilityId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ClinicalAdmissionActionDialog(
      referenceData: _clinicalAdmissionReferenceData(),
      reasonLabel: l10n.patientsAdmissionReasonLabel,
      reasonRequired: true,
      notesLabel: l10n.patientsNotesLabel,
      leadingSectionsBuilder: _workflowFields,
      onSubmit: _submitAdmission,
    );
  }

  List<Widget> _workflowFields(BuildContext context, bool enabled) {
    if (widget.referenceData.facilities.length <= 1) {
      return const <Widget>[];
    }
    return <Widget>[
      AppFormSection(
        title: context.l10n.patientsWorkflowSectionTitle,
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          PatientFacilitySelectField(
            facilities: widget.referenceData.facilities,
            value: _facilityId,
            labelText: context.l10n.patientsFacilityLabel,
            enabled: enabled,
            onChanged: (String? value) => setState(() => _facilityId = value),
          ),
        ],
      ),
    ];
  }

  ClinicalActionReferenceData _clinicalAdmissionReferenceData() {
    return ClinicalActionReferenceData(
      wards: <ClinicalActionCatalogOption>[
        for (final PatientReferenceOption option in _facilityFiltered(
          widget.referenceData.wards,
        ))
          ClinicalActionCatalogOption(
            id: option.id,
            name: option.label,
            status: option.status,
            parentId: option.facilityId,
          ),
      ],
      rooms: <ClinicalActionCatalogOption>[
        for (final PatientReferenceOption option in _facilityFiltered(
          widget.referenceData.rooms,
        ))
          ClinicalActionCatalogOption(
            id: option.id,
            name: option.label,
            status: option.status,
            parentId: option.wardId,
            secondaryId: option.facilityId,
          ),
      ],
      availableBeds: <ClinicalActionCatalogOption>[
        for (final PatientReferenceOption option in _facilityFiltered(
          widget.referenceData.beds,
        ))
          ClinicalActionCatalogOption(
            id: option.id,
            name: option.label,
            category: option.type,
            status: option.status,
            parentId: option.wardId,
            secondaryId: option.roomId,
          ),
      ],
    );
  }

  List<PatientReferenceOption> _facilityFiltered(
    List<PatientReferenceOption> options,
  ) {
    if (_facilityId == null) {
      return options;
    }
    return options
        .where(
          (PatientReferenceOption option) =>
              option.facilityId == null || option.facilityId == _facilityId,
        )
        .toList(growable: false);
  }

  Future<AppFailure?> _submitAdmission(
    ClinicalActionAdmissionInput input,
  ) async {
    final Result<OpdFlowDetail> flowResult = await ref
        .read(opdRepositoryProvider)
        .startOpdFlow(
          _withoutEmptyPayload(<String, Object?>{
            'tenant_id': widget.patient.tenantId,
            'facility_id': _facilityId,
            'patient_id': widget.patient.id,
            'queued_at': DateTime.now().toUtc().toIso8601String(),
            'arrival_mode': 'WALK_IN',
            'initial_stage': 'WAITING_DOCTOR_REVIEW',
            'require_consultation_payment': false,
            'create_consultation_invoice': false,
            'notes': input.notes,
          }),
        );
    final OpdFlowDetail? flow = _successOrNull(flowResult);
    if (flow == null) {
      return _failureOrNull(flowResult);
    }

    final Result<OpdFlowDetail> reviewResult = await ref
        .read(opdRepositoryProvider)
        .doctorReview(flow.summary.apiId, <String, Object?>{
          'note': input.reason ?? '',
        });
    final OpdFlowDetail? reviewed = _successOrNull(reviewResult);
    if (reviewed == null) {
      return _failureOrNull(reviewResult);
    }

    final Result<OpdFlowDetail> dispositionResult = await ref
        .read(opdRepositoryProvider)
        .disposition(
          reviewed.summary.apiId,
          _withoutEmptyPayload(<String, Object?>{
            'decision': 'ADMIT',
            'admission_facility_id': _facilityId,
            'notes': input.notes,
          }),
        );
    final OpdFlowDetail? admitted = _successOrNull(dispositionResult);
    if (admitted == null) {
      return _failureOrNull(dispositionResult);
    }

    final String? admissionId = admitted.admissions.isEmpty
        ? null
        : admitted.admissions.first.id;
    if (admissionId == null) {
      return null;
    }

    final Result<void> bedResult = await ref
        .read(ipdRepositoryProvider)
        .assignBed(admissionId, <String, Object?>{
          'bed_id': input.bed.apiId,
          'assigned_at': DateTime.now().toUtc().toIso8601String(),
        });
    return _failureOrNull(bedResult);
  }
}

class _PatientFlowQuickDialog extends ConsumerStatefulWidget {
  const _PatientFlowQuickDialog({
    required this.patient,
    required this.referenceData,
    required this.action,
  });

  final Patient patient;
  final PatientReferenceData referenceData;
  final _PatientQuickAction action;

  @override
  ConsumerState<_PatientFlowQuickDialog> createState() =>
      _PatientFlowQuickDialogState();
}

class _PatientFlowQuickDialogState
    extends ConsumerState<_PatientFlowQuickDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _transactionRefController =
      TextEditingController();
  String? _facilityId;
  String? _providerId;
  String _currency = appDefaultCurrencyCode;
  String _paymentMethod = 'CASH';
  bool _markPaid = false;
  List<OpdProviderOption> _providers = const <OpdProviderOption>[];
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _facilityId = widget.patient.facilityId;
    unawaited(_loadProviders());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _feeController.dispose();
    _transactionRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(_dialogTitle(l10n)),
      icon: Icon(_dialogIcon),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 780,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: _failure == null
            ? null
            : AppFailureStateView(
                failure: _failure!,
                body: _workflowFailureMessage(context, _failure!),
              ),
        children: <Widget>[
          AppFormSection(
            title: l10n.patientsWorkflowSectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              if (widget.referenceData.facilities.length > 1)
                _facilitySelect(context),
              if (_usesProvider) _providerSelect(context),
            ],
          ),
          ..._modeFields(context),
          AppFormSection(
            title: l10n.patientsNotesSectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppTextField(
                controller: _notesController,
                labelText: l10n.patientsNotesLabel,
                enabled: !_isSaving,
                maxLines: 3,
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
        AppButton.primary(
          label: _primaryActionLabel(l10n),
          leadingIcon: _dialogIcon,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  bool get _usesProvider => widget.action != _PatientQuickAction.billing;

  IconData get _dialogIcon {
    return switch (widget.action) {
      _PatientQuickAction.triage => Icons.monitor_heart_outlined,
      _PatientQuickAction.billing => Icons.receipt_long_outlined,
      _PatientQuickAction.admission => Icons.local_hospital_outlined,
      _ => Icons.play_arrow_outlined,
    };
  }

  String _dialogTitle(AppLocalizations l10n) {
    return switch (widget.action) {
      _PatientQuickAction.triage => l10n.patientsTriageDialogTitle,
      _PatientQuickAction.billing => l10n.patientsBillingDialogTitle,
      _PatientQuickAction.admission => l10n.patientsAdmissionDialogTitle,
      _ => l10n.patientsQuickActionsTitle,
    };
  }

  String _primaryActionLabel(AppLocalizations l10n) {
    return switch (widget.action) {
      _PatientQuickAction.triage => l10n.patientsQuickTriageAction,
      _PatientQuickAction.billing => l10n.patientsQuickBillingAction,
      _PatientQuickAction.admission => l10n.patientsQuickAdmissionAction,
      _ => l10n.patientsSaveAction,
    };
  }

  List<Widget> _modeFields(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.action) {
      _PatientQuickAction.billing => <Widget>[
        AppFormSection(
          title: l10n.patientsBillingSectionTitle,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            _consultationFeeField(context, required: true),
            AppCheckboxField(
              title: l10n.patientsMarkPaymentReceivedLabel,
              value: _markPaid,
              enabled: !_isSaving,
              onChanged: (bool value) => setState(() => _markPaid = value),
            ),
            if (_markPaid)
              AppResponsiveFieldRow.two(
                left: AppSelectField<String>.searchable(
                  value: _paymentMethod,
                  labelText: l10n.patientsPaymentMethodLabel,
                  enabled: !_isSaving,
                  onChanged: (String? value) =>
                      setState(() => _paymentMethod = value ?? 'CASH'),
                  options: _paymentMethodSelectOptions(),
                ),
                right: AppTextField(
                  controller: _transactionRefController,
                  labelText: l10n.patientsTransactionReferenceLabel,
                  enabled: !_isSaving,
                ),
              ),
          ],
        ),
      ],
      _ => const <Widget>[],
    };
  }

  Widget _consultationFeeField(BuildContext context, {required bool required}) {
    final l10n = context.l10n;
    return AppCurrencyAmountField(
      amountController: _feeController,
      currency: _currency,
      amountLabelText: l10n.patientsConsultationFeeLabel,
      currencyLabelText: l10n.patientsCurrencyLabel,
      enabled: !_isSaving,
      isRequired: required,
      validator: required
          ? AppValidators.requiredText(l10n.validationRequired)
          : null,
      onCurrencyChanged: (String? value) {
        setState(() {
          _currency = value ?? appDefaultCurrencyCode;
        });
      },
    );
  }

  Widget _facilitySelect(BuildContext context) {
    return PatientFacilitySelectField(
      facilities: widget.referenceData.facilities,
      value: _facilityId,
      labelText: context.l10n.patientsFacilityLabel,
      enabled: !_isSaving,
      onChanged: (String? value) {
        setState(() => _facilityId = value);
      },
    );
  }

  Widget _providerSelect(BuildContext context) {
    return AppSelectField<String>.searchable(
      value: _providerId,
      labelText: context.l10n.patientsProviderLabel,
      helperText: context.l10n.patientsProviderOptionalHelper,
      enabled: !_isSaving,
      isLoading: _isLoadingProviders,
      onChanged: (String? value) => setState(() => _providerId = value),
      options: _providerSelectOptions(_providers),
    );
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoadingProviders = true);
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }
    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providers = providers;
          _isLoadingProviders = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingProviders = false;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final AppFailure? failure = await (switch (widget.action) {
      _PatientQuickAction.billing => _submitBilling(),
      _ => Future<AppFailure?>.value(),
    });

    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSaving = false;
      _failure = failure;
    });
  }

  Future<AppFailure?> _submitBilling() {
    final String amount = normalizeCurrencyAmount(_feeController.text);
    return _startFlow(<String, Object?>{
      'arrival_mode': 'WALK_IN',
      'consultation_fee': amount,
      'currency': _currency,
      'create_consultation_invoice': true,
      'require_consultation_payment': true,
      if (_markPaid)
        'pay_now': _withoutEmptyPayload(<String, Object?>{
          'method': _paymentMethod,
          'amount': amount,
          'status': 'COMPLETED',
          'transaction_ref': _transactionRefController.text.trim(),
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        }),
    });
  }

  Future<AppFailure?> _startFlow(Map<String, Object?> payload) async {
    final Result<OpdFlowDetail> result = await ref
        .read(opdRepositoryProvider)
        .startOpdFlow(_baseFlowPayload(payload));
    return _failureOrNull(result);
  }

  Map<String, Object?> _baseFlowPayload(Map<String, Object?> extra) {
    return _withoutEmptyPayload(<String, Object?>{
      'tenant_id': widget.patient.tenantId,
      'facility_id': _facilityId,
      'patient_id': widget.patient.id,
      'provider_user_id': _providerId,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
      'notes': _notesController.text.trim(),
      ...extra,
    });
  }
}

class _PatientReportPrintPreviewDialog extends ConsumerStatefulWidget {
  const _PatientReportPrintPreviewDialog({required this.patient, this.detail});

  final Patient patient;
  final PatientDetail? detail;

  @override
  ConsumerState<_PatientReportPrintPreviewDialog> createState() =>
      _PatientReportPrintPreviewDialogState();
}

class _PatientReportPrintPreviewDialogState
    extends ConsumerState<_PatientReportPrintPreviewDialog> {
  late final DateTime _generatedAt;
  _PatientReportPeriodMode _periodMode = _PatientReportPeriodMode.allDates;
  DateTime? _singleDate;
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<_PatientReportSection> _selectedSections = <_PatientReportSection>{
    ..._defaultPatientReportSections,
  };

  @override
  void initState() {
    super.initState();
    _generatedAt = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final PatientDetail effectiveDetail = _effectivePatientDetail(
      widget.patient,
      widget.detail,
    );
    final _PatientReportSelection selection = _PatientReportSelection(
      periodMode: _periodMode,
      singleDate: _singleDate,
      startDate: _startDate,
      endDate: _endDate,
      sections: Set<_PatientReportSection>.unmodifiable(_selectedSections),
    );
    final _PatientReportDocument document = _buildPatientReportDocument(
      context,
      detail: effectiveDetail,
      selection: selection,
      generatedAt: _generatedAt,
    );
    final bool periodIsValid = _periodRangeIsValid;

    return AppDialog(
      title: Text(l10n.patientsReportPreviewDialogTitle),
      icon: const Icon(Icons.preview_outlined),
      scrollable: true,
      maxWidth: 1080,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PatientReportPreviewControls(
            detail: effectiveDetail,
            selection: selection,
            periodIsValid: periodIsValid,
            onPeriodModeChanged: (_PatientReportPeriodMode? value) {
              setState(() {
                _periodMode = value ?? _PatientReportPeriodMode.allDates;
              });
            },
            onSingleDateChanged: (DateTime? value) {
              setState(() => _singleDate = value);
            },
            onStartDateChanged: (DateTime? value) {
              setState(() => _startDate = value);
            },
            onEndDateChanged: (DateTime? value) {
              setState(() => _endDate = value);
            },
            onSectionChanged: _toggleSection,
          ),
          SizedBox(height: theme.spacing.lg),
          Text(
            l10n.patientsReportPreviewSectionTitle,
            style: theme.textTheme.titleMedium,
          ),
          SizedBox(height: theme.spacing.sm),
          _PatientReportPreviewPages(document: document),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
        AppReportActionButton.print(
          label: l10n.patientsReportPrintNowAction,
          enabled: periodIsValid,
          onPressed: periodIsValid
              ? () async {
                  await printFormTemplateDocument(
                    ref: ref,
                    context: context,
                    title: document.title,
                    subtitle: document.patientName,
                    metadata: <PrintFormMetadataItem>[
                      PrintFormMetadataItem(
                        label: l10n.patientsIdentifierLabel,
                        value: document.patientIdentifier,
                      ),
                      PrintFormMetadataItem(
                        label: l10n.patientsReportPeriodLabel,
                        value: document.periodLabel,
                      ),
                      PrintFormMetadataItem(
                        label: l10n.patientsReportPreparedOnLabel,
                        value: document.generatedAtLabel,
                      ),
                    ],
                    pages: _patientReportPrintPages(document),
                  );
                }
              : null,
        ),
      ],
    );
  }

  bool get _periodRangeIsValid {
    if (_periodMode != _PatientReportPeriodMode.dateRange ||
        _startDate == null ||
        _endDate == null) {
      return true;
    }
    return !_dateOnly(_startDate!).isAfter(_dateOnly(_endDate!));
  }

  void _toggleSection(_PatientReportSection section, bool selected) {
    setState(() {
      if (selected) {
        _selectedSections.add(section);
        return;
      }
      if (_selectedSections.length > 1) {
        _selectedSections.remove(section);
      }
    });
  }
}

class _PatientReportPreviewControls extends StatelessWidget {
  const _PatientReportPreviewControls({
    required this.detail,
    required this.selection,
    required this.periodIsValid,
    required this.onPeriodModeChanged,
    required this.onSingleDateChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onSectionChanged,
  });

  final PatientDetail detail;
  final _PatientReportSelection selection;
  final bool periodIsValid;
  final ValueChanged<_PatientReportPeriodMode?> onPeriodModeChanged;
  final ValueChanged<DateTime?> onSingleDateChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final void Function(_PatientReportSection section, bool selected)
  onSectionChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppFormSection(
          title: l10n.patientsReportPeriodLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _periodModeField(context),
                      if (_dateFieldForMode(context)
                          case final Widget field) ...<Widget>[
                        SizedBox(height: theme.spacing.sm),
                        field,
                      ],
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 240, child: _periodModeField(context)),
                    SizedBox(width: theme.spacing.sm),
                    Expanded(
                      child:
                          _dateFieldForMode(context) ?? const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
            if (!periodIsValid)
              Text(
                l10n.patientsReportDateRangeInvalidMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        AppFormSection(
          title: l10n.patientsReportSectionsLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = constraints.maxWidth >= 920
                    ? 3
                    : constraints.maxWidth >= 620
                    ? 2
                    : 1;
                final double gap = theme.spacing.sm;
                final double tileWidth =
                    (constraints.maxWidth - (gap * (columns - 1))) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final _PatientReportSection section
                        in _patientReportSections)
                      SizedBox(
                        width: math.max(tileWidth, 0),
                        child: _PatientReportSectionTile(
                          title: _patientReportSectionLabel(l10n, section),
                          count: _patientReportSectionCount(
                            detail,
                            section,
                            selection,
                          ),
                          icon: _patientReportSectionIcon(section),
                          selected: selection.sections.contains(section),
                          onChanged: (bool value) =>
                              onSectionChanged(section, value),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _periodModeField(BuildContext context) {
    final l10n = context.l10n;
    return AppSelectField<_PatientReportPeriodMode>(
      value: selection.periodMode,
      labelText: l10n.patientsReportPeriodLabel,
      options: <AppSelectOption<_PatientReportPeriodMode>>[
        for (final _PatientReportPeriodMode value
            in _PatientReportPeriodMode.values)
          AppSelectOption<_PatientReportPeriodMode>(
            value: value,
            label: _patientReportPeriodModeLabel(l10n, value),
          ),
      ],
      onChanged: onPeriodModeChanged,
    );
  }

  Widget? _dateFieldForMode(BuildContext context) {
    final l10n = context.l10n;
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(1900);
    final DateTime lastDate = DateTime(now.year + 1, 12, 31);

    return switch (selection.periodMode) {
      _PatientReportPeriodMode.allDates => null,
      _PatientReportPeriodMode.singleDate => PatientDateField(
        value: selection.singleDate,
        firstDate: firstDate,
        lastDate: lastDate,
        currentDate: now,
        initialPickerDate: selection.singleDate ?? now,
        labelText: l10n.patientsReportDateLabel,
        onChanged: onSingleDateChanged,
      ),
      _PatientReportPeriodMode.dateRange => AppResponsiveFieldRow.two(
        left: PatientDateField(
          value: selection.startDate,
          firstDate: firstDate,
          lastDate: lastDate,
          currentDate: now,
          initialPickerDate: selection.startDate ?? now,
          labelText: l10n.patientsReportStartDateLabel,
          onChanged: onStartDateChanged,
        ),
        right: PatientDateField(
          value: selection.endDate,
          firstDate: firstDate,
          lastDate: lastDate,
          currentDate: now,
          initialPickerDate: selection.endDate ?? selection.startDate ?? now,
          labelText: l10n.patientsReportEndDateLabel,
          onChanged: onEndDateChanged,
        ),
      ),
    };
  }
}

class _PatientReportSectionTile extends StatelessWidget {
  const _PatientReportSectionTile({
    required this.title,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final int count;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      checked: selected,
      child: InkWell(
        onTap: () => onChanged(!selected),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                : colorScheme.surface,
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Checkbox(
                  value: selected,
                  visualDensity: VisualDensity.compact,
                  onChanged: (bool? value) => onChanged(value ?? false),
                ),
                Icon(
                  icon,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: theme.appTokens.listIconSize,
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Text(
                  count.toString(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientReportPreviewPages extends StatelessWidget {
  const _PatientReportPreviewPages({required this.document});

  final _PatientReportDocument document;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < document.pages.length; index++) ...<Widget>[
          _PatientReportPreviewPage(
            document: document,
            page: document.pages[index],
            pageNumber: index + 1,
            totalPages: document.pages.length,
          ),
          if (index < document.pages.length - 1)
            SizedBox(height: theme.spacing.md),
        ],
      ],
    );
  }
}

class _PatientReportPreviewPage extends StatelessWidget {
  const _PatientReportPreviewPage({
    required this.document,
    required this.page,
    required this.pageNumber,
    required this.totalPages,
  });

  final _PatientReportDocument document;
  final _PatientReportPage page;
  final int pageNumber;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 680),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _PatientReportPageHeader(document: document),
              SizedBox(height: theme.spacing.md),
              for (
                var index = 0;
                index < page.blocks.length;
                index++
              ) ...<Widget>[
                _PatientReportBlockPreview(block: page.blocks[index]),
                if (index < page.blocks.length - 1)
                  SizedBox(height: theme.spacing.md),
              ],
              SizedBox(height: theme.spacing.md),
              Divider(color: theme.colorScheme.outlineVariant),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  l10n.patientsReportPageNumberLabel(pageNumber, totalPages),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientReportPageHeader extends StatelessWidget {
  const _PatientReportPageHeader({required this.document});

  final _PatientReportDocument document;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    document.hospitalName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    document.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    document.patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    document.patientIdentifier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${l10n.patientsReportPeriodLabel}: ${document.periodLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientReportBlockPreview extends StatelessWidget {
  const _PatientReportBlockPreview({required this.block});

  final _PatientReportBlock block;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          block.title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffd1d5db)),
          ),
          child: block.rows.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(theme.spacing.sm),
                  child: Text(
                    block.emptyText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (var index = 0; index < block.rows.length; index++)
                      _PatientReportRowPreview(
                        row: block.rows[index],
                        showDivider: index < block.rows.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PatientReportRowPreview extends StatelessWidget {
  const _PatientReportRowPreview({
    required this.row,
    required this.showDivider,
  });

  final _PatientReportRow row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.black87,
      fontWeight: FontWeight.w800,
    );
    final TextStyle? valueStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.black,
    );
    final TextStyle? detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.black87,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xffe5e7eb)))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget value = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(row.value, style: valueStyle),
                if (row.detail != null) Text(row.detail!, style: detailStyle),
              ],
            );
            final Widget? meta = row.meta == null
                ? null
                : Text(row.meta!, textAlign: TextAlign.end, style: detailStyle);

            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    row.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  value,
                  if (meta != null) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: meta,
                    ),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: Text(
                    row.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(child: value),
                if (meta != null) ...<Widget>[
                  SizedBox(width: theme.spacing.sm),
                  SizedBox(width: 128, child: meta),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

PatientDetail _effectivePatientDetail(Patient patient, PatientDetail? detail) {
  return detail ??
      PatientDetail(
        patient: patient,
        workspace: const PatientWorkspaceSnapshot(),
      );
}

enum _PatientReportPeriodMode { allDates, singleDate, dateRange }

enum _PatientReportSection {
  summary,
  timeline,
  vitalSigns,
  appointments,
  encounters,
  admissions,
  invoices,
  payments,
  identifiers,
  contacts,
  guardians,
  allergies,
  medicalHistory,
  documents,
  consents,
}

const List<_PatientReportSection> _patientReportSections =
    <_PatientReportSection>[
      _PatientReportSection.summary,
      _PatientReportSection.timeline,
      _PatientReportSection.vitalSigns,
      _PatientReportSection.appointments,
      _PatientReportSection.encounters,
      _PatientReportSection.admissions,
      _PatientReportSection.invoices,
      _PatientReportSection.payments,
      _PatientReportSection.identifiers,
      _PatientReportSection.contacts,
      _PatientReportSection.guardians,
      _PatientReportSection.allergies,
      _PatientReportSection.medicalHistory,
      _PatientReportSection.documents,
      _PatientReportSection.consents,
    ];

const Set<_PatientReportSection> _defaultPatientReportSections =
    <_PatientReportSection>{
      _PatientReportSection.summary,
      _PatientReportSection.timeline,
      _PatientReportSection.vitalSigns,
      _PatientReportSection.appointments,
      _PatientReportSection.encounters,
      _PatientReportSection.admissions,
      _PatientReportSection.identifiers,
      _PatientReportSection.contacts,
      _PatientReportSection.medicalHistory,
    };

@immutable
final class _PatientReportSelection {
  const _PatientReportSelection({
    required this.periodMode,
    required this.sections,
    this.singleDate,
    this.startDate,
    this.endDate,
  });

  final _PatientReportPeriodMode periodMode;
  final DateTime? singleDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<_PatientReportSection> sections;
}

@immutable
final class _PatientReportRow {
  const _PatientReportRow({
    required this.label,
    required this.value,
    this.detail,
    this.meta,
  });

  final String label;
  final String value;
  final String? detail;
  final String? meta;
}

@immutable
final class _PatientReportBlock {
  const _PatientReportBlock({
    required this.title,
    required this.rows,
    required this.emptyText,
  });

  final String title;
  final List<_PatientReportRow> rows;
  final String emptyText;
}

@immutable
final class _PatientReportPage {
  const _PatientReportPage({required this.blocks});

  final List<_PatientReportBlock> blocks;
}

@immutable
final class _PatientReportDocument {
  const _PatientReportDocument({
    required this.title,
    required this.hospitalName,
    required this.patientName,
    required this.patientIdentifier,
    required this.periodLabel,
    required this.generatedAtLabel,
    required this.pages,
  });

  final String title;
  final String hospitalName;
  final String patientName;
  final String patientIdentifier;
  final String periodLabel;
  final String generatedAtLabel;
  final List<_PatientReportPage> pages;
}

_PatientReportDocument _buildPatientReportDocument(
  BuildContext context, {
  required PatientDetail detail,
  required _PatientReportSelection selection,
  required DateTime generatedAt,
}) {
  final l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  final Patient patient = detail.patient;
  final PatientWorkspaceSnapshot workspace = detail.workspace;
  final String hospitalName =
      patient.facilityLabel ?? patient.tenantLabel ?? l10n.appTitle;
  final String emptyText = l10n.patientsReportNoRecordsForSection;

  final List<_PatientReportBlock> leadingBlocks = <_PatientReportBlock>[
    _PatientReportBlock(
      title: l10n.patientsReportHospitalInfoSectionTitle,
      emptyText: emptyText,
      rows: <_PatientReportRow>[
        _PatientReportRow(
          label: l10n.patientsReportHospitalNameLabel,
          value: hospitalName,
        ),
        _PatientReportRow(
          label: l10n.patientsFacilityLabel,
          value: patient.facilityLabel ?? l10n.profileUnknownValue,
        ),
        _PatientReportRow(
          label: l10n.profileTenantLabel,
          value: patient.tenantLabel ?? l10n.profileUnknownValue,
        ),
        _PatientReportRow(
          label: l10n.patientsReportHospitalContactLabel,
          value: l10n.profileUnknownValue,
        ),
        _PatientReportRow(
          label: l10n.patientsReportHospitalLocationLabel,
          value: l10n.profileUnknownValue,
        ),
        _PatientReportRow(
          label: l10n.patientsReportHospitalAddressLabel,
          value: l10n.profileUnknownValue,
        ),
      ],
    ),
    _PatientReportBlock(
      title: l10n.patientsReportPatientInfoSectionTitle,
      emptyText: emptyText,
      rows: <_PatientReportRow>[
        _PatientReportRow(
          label: l10n.patientsNameLabel,
          value: patient.effectiveDisplayName,
        ),
        _PatientReportRow(
          label: l10n.patientsIdentifierLabel,
          value: patient.effectiveIdentifier ?? patient.id,
        ),
        _PatientReportRow(
          label: l10n.patientsDobLabel,
          value: _formatOptionalDate(context, patient.dateOfBirth),
        ),
        _PatientReportRow(
          label: l10n.patientsGenderLabel,
          value: patient.gender == null
              ? l10n.profileUnknownValue
              : _genderLabel(l10n, patient.gender!),
        ),
        _PatientReportRow(
          label: l10n.patientsPhoneLabel,
          value: patient.primaryPhone ?? l10n.profileUnknownValue,
        ),
        _PatientReportRow(
          label: l10n.patientsEmailLabel,
          value: patient.primaryEmail ?? l10n.profileUnknownValue,
        ),
      ],
    ),
  ];

  final List<_PatientReportBlock> bodyBlocks = <_PatientReportBlock>[
    if (selection.sections.contains(_PatientReportSection.summary))
      _PatientReportBlock(
        title: l10n.patientsReportSummarySectionTitle,
        emptyText: emptyText,
        rows: <_PatientReportRow>[
          _PatientReportRow(
            label: l10n.patientsAppointmentsSectionTitle,
            value: _filteredSummaryRecords(
              workspace.appointments,
              selection,
            ).length.toString(),
          ),
          _PatientReportRow(
            label: l10n.patientsEncountersSectionTitle,
            value: _filteredSummaryRecords(
              workspace.encounters,
              selection,
            ).length.toString(),
          ),
          _PatientReportRow(
            label: l10n.patientsReportVitalsSectionTitle,
            value: _filteredTimelineItems(
              detail.timeline.where(_isVitalTimelineItem),
              selection,
            ).length.toString(),
          ),
          _PatientReportRow(
            label: l10n.patientsAdmissionsSectionTitle,
            value: _filteredSummaryRecords(
              workspace.admissions,
              selection,
            ).length.toString(),
          ),
          _PatientReportRow(
            label: l10n.patientsInvoicesSectionTitle,
            value: _filteredSummaryRecords(
              workspace.invoices,
              selection,
            ).length.toString(),
          ),
          _PatientReportRow(
            label: l10n.patientsReportPaymentsSectionTitle,
            value: _filteredSummaryRecords(
              workspace.payments,
              selection,
            ).length.toString(),
          ),
        ],
      ),
    if (selection.sections.contains(_PatientReportSection.timeline))
      _PatientReportBlock(
        title: l10n.patientsTimelineSectionTitle,
        rows: _timelineRows(context, detail.timeline, selection),
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.vitalSigns))
      _PatientReportBlock(
        title: l10n.patientsReportVitalsSectionTitle,
        rows: _timelineRows(
          context,
          detail.timeline.where(_isVitalTimelineItem),
          selection,
        ),
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.appointments))
      _PatientReportBlock(
        title: l10n.patientsAppointmentsSectionTitle,
        rows: _summaryRecordRows(context, workspace.appointments, selection),
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.encounters))
      _PatientReportBlock(
        title: l10n.patientsEncountersSectionTitle,
        rows: _summaryRecordRows(context, workspace.encounters, selection),
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.admissions))
      _PatientReportBlock(
        title: l10n.patientsAdmissionsSectionTitle,
        rows: _summaryRecordRows(context, workspace.admissions, selection),
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.invoices))
      _PatientReportBlock(
        title: l10n.patientsInvoicesSectionTitle,
        rows: _summaryRecordRows(context, workspace.invoices, selection),
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.payments))
      _PatientReportBlock(
        title: l10n.patientsReportPaymentsSectionTitle,
        rows: _summaryRecordRows(context, workspace.payments, selection),
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.identifiers))
      _PatientReportBlock(
        title: l10n.patientsIdentifiersSectionTitle,
        rows: <_PatientReportRow>[
          for (final PatientIdentifier item in detail.identifiers)
            _PatientReportRow(
              label: _apiLabel(item.type),
              value: item.value,
              meta: item.isPrimary ? l10n.patientsPrimaryRecordLabel : null,
            ),
        ],
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.contacts))
      _PatientReportBlock(
        title: l10n.patientsContactsSectionTitle,
        rows: <_PatientReportRow>[
          for (final PatientContact item in detail.contacts)
            _PatientReportRow(
              label: _apiLabel(item.type),
              value: item.value,
              meta: item.isPrimary ? l10n.patientsPrimaryRecordLabel : null,
            ),
        ],
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.guardians))
      _PatientReportBlock(
        title: l10n.patientsGuardiansSectionTitle,
        rows: <_PatientReportRow>[
          for (final PatientGuardian item in detail.guardians)
            _PatientReportRow(
              label: item.name,
              value: item.relationship ?? l10n.profileUnknownValue,
              detail: _joinDisplay(<String?>[item.phone, item.email]),
            ),
        ],
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.allergies))
      _PatientReportBlock(
        title: l10n.patientsAllergiesSectionTitle,
        rows: <_PatientReportRow>[
          for (final PatientAllergy item in detail.allergies)
            _PatientReportRow(
              label: item.allergen,
              value: _apiLabel(item.severity),
              detail: _joinDisplay(<String?>[item.reaction, item.notes]),
            ),
        ],
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.medicalHistory))
      _PatientReportBlock(
        title: l10n.patientsMedicalHistorySectionTitle,
        rows: <_PatientReportRow>[
          for (final PatientMedicalHistory item in detail.medicalHistories)
            _PatientReportRow(
              label: item.condition,
              value: _formatOptionalDate(context, item.diagnosisDate),
              detail: item.notes,
            ),
        ],
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.documents))
      _PatientReportBlock(
        title: l10n.patientsDocumentsSectionTitle,
        rows: <_PatientReportRow>[
          for (final PatientDocument item in detail.documents)
            _PatientReportRow(
              label: _apiLabel(item.documentType),
              value: item.fileName ?? item.storageKey,
              detail: item.contentType,
            ),
        ],
        emptyText: emptyText,
      ),
    if (selection.sections.contains(_PatientReportSection.consents))
      _PatientReportBlock(
        title: l10n.patientsConsentsSectionTitle,
        rows: <_PatientReportRow>[
          for (final PatientConsent item in detail.consents)
            _PatientReportRow(
              label: _apiLabel(item.consentType),
              value: _apiLabel(item.status),
              meta: _formatOptionalDateTime(
                context,
                item.grantedAt ?? item.revokedAt ?? item.updatedAt,
              ),
            ),
        ],
        emptyText: emptyText,
      ),
    _PatientReportBlock(
      title: l10n.patientsReportGeneratedSectionTitle,
      emptyText: emptyText,
      rows: <_PatientReportRow>[
        _PatientReportRow(
          label: l10n.patientsReportPreparedOnLabel,
          value: AppFormatters.dateTime(generatedAt, locale),
        ),
      ],
    ),
  ];

  return _PatientReportDocument(
    title: l10n.patientsReportDialogTitle,
    hospitalName: hospitalName,
    patientName: patient.effectiveDisplayName,
    patientIdentifier: patient.effectiveIdentifier ?? patient.id,
    periodLabel: _patientReportPeriodLabel(context, selection),
    generatedAtLabel: AppFormatters.dateTime(generatedAt, locale),
    pages: _paginatePatientReportBlocks(leadingBlocks, bodyBlocks),
  );
}

List<_PatientReportPage> _paginatePatientReportBlocks(
  List<_PatientReportBlock> leadingBlocks,
  List<_PatientReportBlock> bodyBlocks,
) {
  const int firstPageCapacity = 22;
  const int regularPageCapacity = 26;
  const int maxBlockRows = 18;
  final List<_PatientReportPage> pages = <_PatientReportPage>[];
  final List<_PatientReportBlock> currentBlocks = <_PatientReportBlock>[];
  var capacity = firstPageCapacity;
  var used = 0;

  void pushPage() {
    if (currentBlocks.isEmpty) {
      return;
    }
    pages.add(
      _PatientReportPage(blocks: List<_PatientReportBlock>.of(currentBlocks)),
    );
    currentBlocks.clear();
    capacity = regularPageCapacity;
    used = 0;
  }

  void addBlock(_PatientReportBlock block) {
    for (final _PatientReportBlock chunk in _chunkPatientReportBlock(
      block,
      maxBlockRows,
    )) {
      final int weight = math.max(chunk.rows.length, 1) + 2;
      if (currentBlocks.isNotEmpty && used + weight > capacity) {
        pushPage();
      }
      currentBlocks.add(chunk);
      used += weight;
    }
  }

  for (final _PatientReportBlock block in leadingBlocks) {
    addBlock(block);
  }
  for (final _PatientReportBlock block in bodyBlocks) {
    addBlock(block);
  }
  pushPage();

  return pages.isEmpty
      ? <_PatientReportPage>[
          const _PatientReportPage(blocks: <_PatientReportBlock>[]),
        ]
      : pages;
}

List<_PatientReportBlock> _chunkPatientReportBlock(
  _PatientReportBlock block,
  int maxRows,
) {
  if (block.rows.length <= maxRows) {
    return <_PatientReportBlock>[block];
  }

  final List<_PatientReportBlock> chunks = <_PatientReportBlock>[];
  for (var index = 0; index < block.rows.length; index += maxRows) {
    chunks.add(
      _PatientReportBlock(
        title: block.title,
        rows: block.rows.skip(index).take(maxRows).toList(growable: false),
        emptyText: block.emptyText,
      ),
    );
  }
  return chunks;
}

List<_PatientReportRow> _summaryRecordRows(
  BuildContext context,
  Iterable<PatientSummaryRecord> records,
  _PatientReportSelection selection,
) {
  final List<PatientSummaryRecord> filtered = _filteredSummaryRecords(
    records,
    selection,
  );
  return <_PatientReportRow>[
    for (final PatientSummaryRecord record in filtered)
      _PatientReportRow(
        label: record.title ?? _apiLabel(record.kind),
        value: _joinDisplay(<String?>[
          record.status == null ? null : _apiLabel(record.status!),
          record.subtitle,
        ]),
        meta: _joinDisplay(<String?>[
          _formatOptionalDateTime(context, record.occurredAt),
          _formatSummaryRecordAmount(context, record),
        ]),
      ),
  ];
}

List<_PatientReportRow> _timelineRows(
  BuildContext context,
  Iterable<PatientTimelineItem> items,
  _PatientReportSelection selection,
) {
  return <_PatientReportRow>[
    for (final PatientTimelineItem item in _filteredTimelineItems(
      items,
      selection,
    ))
      _PatientReportRow(
        label: _apiLabel(item.resource),
        value: item.title ?? item.subtitle ?? context.l10n.profileUnknownValue,
        detail: item.title == null ? null : item.subtitle,
        meta: _formatOptionalDateTime(context, item.occurredAt),
      ),
  ];
}

List<PatientSummaryRecord> _filteredSummaryRecords(
  Iterable<PatientSummaryRecord> records,
  _PatientReportSelection selection,
) {
  return records
      .where(
        (PatientSummaryRecord record) =>
            _matchesPatientReportPeriod(record.occurredAt, selection),
      )
      .toList(growable: false);
}

List<PatientTimelineItem> _filteredTimelineItems(
  Iterable<PatientTimelineItem> items,
  _PatientReportSelection selection,
) {
  return items
      .where(
        (PatientTimelineItem item) =>
            _matchesPatientReportPeriod(item.occurredAt, selection),
      )
      .toList(growable: false);
}

bool _matchesPatientReportPeriod(
  DateTime? value,
  _PatientReportSelection selection,
) {
  if (selection.periodMode == _PatientReportPeriodMode.allDates) {
    return true;
  }
  if (value == null) {
    return false;
  }

  final DateTime date = _dateOnly(value);
  return switch (selection.periodMode) {
    _PatientReportPeriodMode.allDates => true,
    _PatientReportPeriodMode.singleDate =>
      selection.singleDate == null || date == _dateOnly(selection.singleDate!),
    _PatientReportPeriodMode.dateRange =>
      (selection.startDate == null ||
              !date.isBefore(_dateOnly(selection.startDate!))) &&
          (selection.endDate == null ||
              !date.isAfter(_dateOnly(selection.endDate!))),
  };
}

String? _formatSummaryRecordAmount(
  BuildContext context,
  PatientSummaryRecord record,
) {
  if (record.amount == null) {
    return null;
  }
  return AppFormatters.currency(
    record.amount!,
    Localizations.localeOf(context),
    currencyCode: record.currency,
  );
}

bool _isVitalTimelineItem(PatientTimelineItem item) {
  final String searchable = <String>[
    item.resource,
    item.title ?? '',
    item.subtitle ?? '',
  ].join(' ').toLowerCase();
  return searchable.contains('vital');
}

int _patientReportSectionCount(
  PatientDetail detail,
  _PatientReportSection section,
  _PatientReportSelection selection,
) {
  final PatientWorkspaceSnapshot workspace = detail.workspace;
  return switch (section) {
    _PatientReportSection.summary => 6,
    _PatientReportSection.timeline => _filteredTimelineItems(
      detail.timeline,
      selection,
    ).length,
    _PatientReportSection.vitalSigns => _filteredTimelineItems(
      detail.timeline.where(_isVitalTimelineItem),
      selection,
    ).length,
    _PatientReportSection.appointments => _filteredSummaryRecords(
      workspace.appointments,
      selection,
    ).length,
    _PatientReportSection.encounters => _filteredSummaryRecords(
      workspace.encounters,
      selection,
    ).length,
    _PatientReportSection.admissions => _filteredSummaryRecords(
      workspace.admissions,
      selection,
    ).length,
    _PatientReportSection.invoices => _filteredSummaryRecords(
      workspace.invoices,
      selection,
    ).length,
    _PatientReportSection.payments => _filteredSummaryRecords(
      workspace.payments,
      selection,
    ).length,
    _PatientReportSection.identifiers => detail.identifiers.length,
    _PatientReportSection.contacts => detail.contacts.length,
    _PatientReportSection.guardians => detail.guardians.length,
    _PatientReportSection.allergies => detail.allergies.length,
    _PatientReportSection.medicalHistory => detail.medicalHistories.length,
    _PatientReportSection.documents => detail.documents.length,
    _PatientReportSection.consents => detail.consents.length,
  };
}

String _patientReportSectionLabel(
  AppLocalizations l10n,
  _PatientReportSection section,
) {
  return switch (section) {
    _PatientReportSection.summary => l10n.patientsReportSummarySectionTitle,
    _PatientReportSection.timeline => l10n.patientsTimelineSectionTitle,
    _PatientReportSection.vitalSigns => l10n.patientsReportVitalsSectionTitle,
    _PatientReportSection.appointments => l10n.patientsAppointmentsSectionTitle,
    _PatientReportSection.encounters => l10n.patientsEncountersSectionTitle,
    _PatientReportSection.admissions => l10n.patientsAdmissionsSectionTitle,
    _PatientReportSection.invoices => l10n.patientsInvoicesSectionTitle,
    _PatientReportSection.payments => l10n.patientsReportPaymentsSectionTitle,
    _PatientReportSection.identifiers => l10n.patientsIdentifiersSectionTitle,
    _PatientReportSection.contacts => l10n.patientsContactsSectionTitle,
    _PatientReportSection.guardians => l10n.patientsGuardiansSectionTitle,
    _PatientReportSection.allergies => l10n.patientsAllergiesSectionTitle,
    _PatientReportSection.medicalHistory =>
      l10n.patientsMedicalHistorySectionTitle,
    _PatientReportSection.documents => l10n.patientsDocumentsSectionTitle,
    _PatientReportSection.consents => l10n.patientsConsentsSectionTitle,
  };
}

IconData _patientReportSectionIcon(_PatientReportSection section) {
  return switch (section) {
    _PatientReportSection.summary => Icons.summarize_outlined,
    _PatientReportSection.timeline => Icons.timeline_outlined,
    _PatientReportSection.vitalSigns => Icons.monitor_heart_outlined,
    _PatientReportSection.appointments => Icons.event_available_outlined,
    _PatientReportSection.encounters => Icons.medical_services_outlined,
    _PatientReportSection.admissions => Icons.local_hospital_outlined,
    _PatientReportSection.invoices => Icons.receipt_long_outlined,
    _PatientReportSection.payments => Icons.payments_outlined,
    _PatientReportSection.identifiers => Icons.badge_outlined,
    _PatientReportSection.contacts => Icons.contact_phone_outlined,
    _PatientReportSection.guardians => Icons.supervisor_account_outlined,
    _PatientReportSection.allergies => Icons.warning_amber_outlined,
    _PatientReportSection.medicalHistory => Icons.history_edu_outlined,
    _PatientReportSection.documents => Icons.description_outlined,
    _PatientReportSection.consents => Icons.fact_check_outlined,
  };
}

String _patientReportPeriodModeLabel(
  AppLocalizations l10n,
  _PatientReportPeriodMode value,
) {
  return switch (value) {
    _PatientReportPeriodMode.allDates => l10n.patientsReportAllDatesOption,
    _PatientReportPeriodMode.singleDate => l10n.patientsReportSingleDateOption,
    _PatientReportPeriodMode.dateRange => l10n.patientsReportDateRangeOption,
  };
}

String _patientReportPeriodLabel(
  BuildContext context,
  _PatientReportSelection selection,
) {
  final l10n = context.l10n;
  return switch (selection.periodMode) {
    _PatientReportPeriodMode.allDates => l10n.patientsReportAllDatesOption,
    _PatientReportPeriodMode.singleDate =>
      selection.singleDate == null
          ? l10n.patientsReportSingleDateOption
          : _formatOptionalDate(context, selection.singleDate),
    _PatientReportPeriodMode.dateRange =>
      _joinDisplay(<String?>[
            selection.startDate == null
                ? null
                : _formatOptionalDate(context, selection.startDate),
            selection.endDate == null
                ? null
                : _formatOptionalDate(context, selection.endDate),
          ]).isEmpty
          ? l10n.patientsReportDateRangeOption
          : _joinDisplay(<String?>[
              selection.startDate == null
                  ? null
                  : _formatOptionalDate(context, selection.startDate),
              selection.endDate == null
                  ? null
                  : _formatOptionalDate(context, selection.endDate),
            ]),
  };
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

List<PrintFormPage> _patientReportPrintPages(_PatientReportDocument report) {
  String row(_PatientReportRow value) {
    final String detail = value.detail == null
        ? ''
        : '<div class="detail">${printHtmlEscape(value.detail!)}</div>';
    final String meta = value.meta == null
        ? ''
        : '<div class="meta">${printHtmlEscape(value.meta!)}</div>';
    return '''
      <tr>
        <th>${printHtmlEscape(value.label)}</th>
        <td>${printHtmlEscape(value.value)}$detail</td>
        <td>$meta</td>
      </tr>
''';
  }

  String block(_PatientReportBlock value) {
    final String rows = value.rows.isEmpty
        ? '<tr><td colspan="3" class="empty">${printHtmlEscape(value.emptyText)}</td></tr>'
        : value.rows.map(row).join();
    return '''
      <section class="print-template-section print-template-section--avoid-break">
        <h2>${printHtmlEscape(value.title)}</h2>
        <table>$rows</table>
      </section>
''';
  }

  const String patientReportStyle = '''
<style>
  .print-template-section table { width: 100%; border-collapse: collapse; }
  .print-template-section th,
  .print-template-section td { border: 1px solid #d1d5db; padding: 6px 8px; text-align: left; vertical-align: top; font-size: 11px; }
  .print-template-section th { width: 28%; background: #f3f4f6; font-weight: 700; }
  .print-template-section td:last-child { width: 20%; text-align: right; color: #374151; }
  .detail { color: #374151; margin-top: 2px; }
  .meta { color: #374151; }
  .empty { color: #6b7280; text-align: left !important; }
</style>
''';

  return <PrintFormPage>[
    for (final _PatientReportPage page in report.pages)
      PrintFormPage(
        title: report.title,
        bodyHtml: '$patientReportStyle${page.blocks.map(block).join()}',
      ),
  ];
}

class PatientDuplicateReviewDialog extends ConsumerStatefulWidget {
  const PatientDuplicateReviewDialog({required this.duplicates, super.key});

  final List<PatientDuplicateCandidate> duplicates;

  @override
  ConsumerState<PatientDuplicateReviewDialog> createState() =>
      _PatientDuplicateReviewDialogState();
}

class _PatientDuplicateReviewDialogState
    extends ConsumerState<PatientDuplicateReviewDialog> {
  late List<PatientDuplicateCandidate> _duplicates;
  PatientDuplicateCandidate? _selectedDuplicate;
  PatientMergePreview? _preview;
  bool _isLoadingPreview = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _duplicates = widget.duplicates.toList(growable: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.patientsDuplicateReviewTitle),
      icon: const Icon(Icons.content_copy_outlined),
      maxWidth: 920,
      scrollable: true,
      closeEnabled: !_isSaving && !_isLoadingPreview,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null) ...<Widget>[
            AppFailureStateView(failure: _failure!),
            SizedBox(height: theme.spacing.md),
          ],
          if (_duplicates.isEmpty)
            AppWorkspaceStatePanel.empty(
              title: l10n.patientsNoDuplicateReviewsTitle,
              body: l10n.patientsNoDuplicateReviewsBody,
              icon: Icons.verified_user_outlined,
              minHeight: 240,
            )
          else
            for (final PatientDuplicateCandidate duplicate in _duplicates)
              Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.sm),
                child: _DuplicateReviewCard(
                  duplicate: duplicate,
                  isBusy: _isSaving || _isLoadingPreview,
                  onPreview: () => _previewMerge(duplicate),
                  onDismiss: () => _dismissDuplicate(duplicate),
                ),
              ),
          if (_isLoadingPreview)
            AppWorkspaceStatePanel.loading(
              title: l10n.patientsMergePreviewLoadingTitle,
              body: l10n.patientsMergePreviewLoadingBody,
              minHeight: 180,
            )
          else if (_preview != null && _selectedDuplicate != null)
            _PatientMergePreviewPanel(
              preview: _preview!,
              isSaving: _isSaving,
              onMerge: () => _mergeDuplicate(_selectedDuplicate!),
            ),
        ],
      ),
    );
  }

  Future<void> _previewMerge(PatientDuplicateCandidate duplicate) async {
    setState(() {
      _isLoadingPreview = true;
      _failure = null;
      _selectedDuplicate = duplicate;
      _preview = null;
    });
    final Result<PatientMergePreview> result = await ref
        .read(patientRegistryControllerProvider.notifier)
        .previewDuplicateMerge(duplicate);
    if (!mounted) {
      return;
    }
    result.when(
      success: (PatientMergePreview preview) {
        setState(() {
          _preview = preview;
          _isLoadingPreview = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingPreview = false;
        });
      },
    );
  }

  Future<void> _dismissDuplicate(PatientDuplicateCandidate duplicate) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .dismissDuplicateCandidate(duplicate);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      setState(() {
        _duplicates.removeWhere(
          (PatientDuplicateCandidate item) =>
              item.reviewId == duplicate.reviewId,
        );
        if (_selectedDuplicate?.reviewId == duplicate.reviewId) {
          _selectedDuplicate = null;
          _preview = null;
        }
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsDuplicateDismissedMessage)),
      );
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  Future<void> _mergeDuplicate(PatientDuplicateCandidate duplicate) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .mergeDuplicateCandidate(duplicate);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsMergedMessage)),
      );
      await Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _DuplicateReviewCard extends StatelessWidget {
  const _DuplicateReviewCard({
    required this.duplicate,
    required this.isBusy,
    required this.onPreview,
    required this.onDismiss,
  });

  final PatientDuplicateCandidate duplicate;
  final bool isBusy;
  final VoidCallback onPreview;
  final VoidCallback onDismiss;

  static const AccessRequirement _writeRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientWrite],
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final Patient? primary = duplicate.primaryPatient;
    final Patient? secondary =
        duplicate.secondaryPatient ?? duplicate.candidatePatient;

    return AppContentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: l10n.patientsDuplicateScoreLabel(
                    duplicate.confidenceScore,
                  ),
                  tone: AppWorkspaceStatusTone.warning,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  _apiLabel(duplicate.classification),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          _DuplicatePatientPair(primary: primary, secondary: secondary),
          if (duplicate.matchReasons.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              duplicate.matchReasons.map(_apiLabel).join(', '),
              style: theme.textTheme.bodySmall,
            ),
          ],
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              AppAccessActionGate(
                requirement: _writeRequirement,
                builder: (_, bool isAllowed) => AppButton.secondary(
                  label: l10n.patientsReviewMergeAction,
                  leadingIcon: Icons.merge_type_outlined,
                  enabled:
                      isAllowed &&
                      !isBusy &&
                      primary != null &&
                      secondary != null,
                  onPressed: onPreview,
                ),
              ),
              AppAccessActionGate(
                requirement: _writeRequirement,
                builder: (_, bool isAllowed) => AppButton.tertiary(
                  label: l10n.patientsDismissDuplicateAction,
                  leadingIcon: Icons.block_outlined,
                  enabled:
                      isAllowed &&
                      !isBusy &&
                      primary != null &&
                      secondary != null,
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuplicatePatientPair extends StatelessWidget {
  const _DuplicatePatientPair({required this.primary, required this.secondary});

  final Patient? primary;
  final Patient? secondary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked = constraints.maxWidth < 560;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _DuplicatePatientSummary(patient: primary),
              SizedBox(height: theme.spacing.sm),
              _DuplicatePatientSummary(patient: secondary),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: _DuplicatePatientSummary(patient: primary)),
            SizedBox(width: theme.spacing.sm),
            Expanded(child: _DuplicatePatientSummary(patient: secondary)),
          ],
        );
      },
    );
  }
}

class _DuplicatePatientSummary extends StatelessWidget {
  const _DuplicatePatientSummary({required this.patient});

  final Patient? patient;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Patient? value = patient;

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value?.effectiveDisplayName ?? context.l10n.profileUnknownValue,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            _joinDisplay(<String?>[
              value?.effectiveIdentifier,
              value?.primaryPhone,
              value?.primaryEmail,
            ]),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PatientMergePreviewPanel extends StatelessWidget {
  const _PatientMergePreviewPanel({
    required this.preview,
    required this.isSaving,
    required this.onMerge,
  });

  final PatientMergePreview preview;
  final bool isSaving;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final List<MapEntry<String, int>> counts = preview.transferCounts.entries
        .where((MapEntry<String, int> entry) => entry.value > 0)
        .toList(growable: false);

    return AppSectionPanel(
      title: l10n.patientsMergePreviewTitle,
      leadingIcon: Icons.merge_type_outlined,
      tone: AppWorkspaceStatusTone.warning,
      children: <Widget>[
        _DuplicatePatientPair(
          primary: preview.primaryPatient,
          secondary: preview.secondaryPatient,
        ),
        if (counts.isNotEmpty)
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final MapEntry<String, int> count in counts)
                AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label: l10n.patientsMergeTransferCountLabel(
                      _apiLabel(count.key),
                      count.value,
                    ),
                    tone: AppWorkspaceStatusTone.info,
                  ),
                ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AppButton.primary(
            label: l10n.patientsMergePatientsAction,
            leadingIcon: Icons.merge_type_outlined,
            isLoading: isSaving,
            onPressed: onMerge,
          ),
        ),
      ],
    );
  }
}

class PatientFormDialog extends StatefulWidget {
  const PatientFormDialog({
    required this.referenceData,
    required this.onSubmit,
    this.patient,
    this.onLookupDuplicates,
    super.key,
  });

  final Patient? patient;
  final PatientReferenceData referenceData;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;
  final Future<Result<AppPage<PatientDuplicateCandidate>>> Function(
    PatientDuplicateQuery query,
  )?
  onLookupDuplicates;

  @override
  State<PatientFormDialog> createState() => _PatientFormDialogState();
}

class _PatientFormDialogState extends State<PatientFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _identifierTypeController;
  late final TextEditingController _identifierValueController;
  DateTime? _dateOfBirth;
  String? _gender;
  String? _facilityId;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isCheckingDuplicates = false;
  bool _duplicateWarningAccepted = false;
  List<PatientDuplicateCandidate> _duplicateCandidates =
      const <PatientDuplicateCandidate>[];
  AppFailure? _failure;

  bool get _isEditing => widget.patient != null;

  @override
  void initState() {
    super.initState();
    final Patient? patient = widget.patient;
    _firstNameController = TextEditingController(text: patient?.firstName);
    _lastNameController = TextEditingController(text: patient?.lastName);
    _phoneController = TextEditingController(text: patient?.primaryPhone);
    _emailController = TextEditingController(text: patient?.primaryEmail);
    _identifierTypeController = TextEditingController(
      text: patient?.primaryIdentifierType,
    );
    _identifierValueController = TextEditingController(
      text: patient?.primaryIdentifierValue,
    );
    _dateOfBirth = patient?.dateOfBirth;
    _gender = patient?.gender;
    _facilityId = patient?.facilityId;
    _isActive = patient?.isActive ?? true;
    if (!_isEditing) {
      _firstNameController.addListener(_clearDuplicateWarning);
      _lastNameController.addListener(_clearDuplicateWarning);
      _phoneController.addListener(_clearDuplicateWarning);
      _identifierValueController.addListener(_clearDuplicateWarning);
    }
  }

  @override
  void dispose() {
    if (!_isEditing) {
      _firstNameController.removeListener(_clearDuplicateWarning);
      _lastNameController.removeListener(_clearDuplicateWarning);
      _phoneController.removeListener(_clearDuplicateWarning);
      _identifierValueController.removeListener(_clearDuplicateWarning);
    }
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _identifierTypeController.dispose();
    _identifierValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(_isEditing ? l10n.patientsEditTitle : l10n.patientsAddTitle),
      icon: const Icon(Icons.assignment_ind_outlined),
      closeEnabled: !_isSaving,
      maxWidth: 760,
      content: SizedBox(
        height: _formBodyHeight(context),
        child: AppFormShell(
          formKey: _formKey,
          enabled: !_isSaving && !_isCheckingDuplicates,
          scrollable: true,
          density: AppFormSectionDensity.compact,
          formStatus: _failure == null
              ? null
              : AppFailureStateView(failure: _failure!),
          children: <Widget>[
            if (_duplicateCandidates.isNotEmpty)
              PatientDuplicateWarningPanel(duplicates: _duplicateCandidates),
            AppResponsiveFieldRow.two(
              left: AppTextField(
                controller: _firstNameController,
                labelText: l10n.patientsFirstNameLabel,
                isRequired: true,
                textCapitalization: TextCapitalization.words,
                enabled: !_isSaving,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
              right: AppTextField(
                controller: _lastNameController,
                labelText: l10n.patientsLastNameLabel,
                textCapitalization: TextCapitalization.words,
                enabled: !_isSaving,
              ),
            ),
            AppResponsiveFieldRow.two(
              left: PatientDateField(
                value: _dateOfBirth,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                labelText: l10n.patientsDobLabel,
                enabled: !_isSaving,
                onChanged: (DateTime? value) {
                  _dateOfBirth = value;
                },
              ),
              right: AppGenderField(
                value: _gender,
                labelText: l10n.patientsGenderLabel,
                maleLabel: l10n.patientsGenderMale,
                femaleLabel: l10n.patientsGenderFemale,
                otherLabel: l10n.patientsGenderOther,
                unknownLabel: l10n.patientsGenderUnknown,
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _gender = value;
                  });
                },
              ),
            ),
            if (widget.referenceData.facilities.length > 1)
              PatientFacilitySelectField(
                facilities: widget.referenceData.facilities,
                value: _facilityId,
                labelText: l10n.patientsFacilityLabel,
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _facilityId = value;
                  });
                },
              ),
            PatientPhoneField(
              controller: _phoneController,
              labelText: l10n.patientsPhoneLabel,
              enabled: !_isSaving,
            ),
            PatientEmailField(
              controller: _emailController,
              labelText: l10n.patientsEmailLabel,
              enabled: !_isSaving,
            ),
            AppResponsiveFieldRow.two(
              left: AppSelectField<String>.searchable(
                value: _selectedIdentifierType(_identifierTypeController.text),
                labelText: l10n.patientsIdentifierTypeLabel,
                enabled: !_isSaving,
                menuHeight: 320,
                onChanged: (String? value) {
                  setState(() {
                    _identifierTypeController.text = value ?? '';
                  });
                },
                options: _identifierTypeSelectOptions(
                  _identifierTypeController.text,
                ),
              ),
              right: AppTextField(
                controller: _identifierValueController,
                labelText: l10n.patientsIdentifierValueLabel,
                enabled: !_isSaving,
              ),
            ),
            AppCheckboxField(
              title: l10n.patientsActiveCheckboxLabel,
              value: _isActive,
              enabled: !_isSaving,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: _isSaving ? null : () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: _duplicateCandidates.isNotEmpty && _duplicateWarningAccepted
              ? l10n.patientsSaveAnywayAction
              : l10n.patientsSaveAction,
          isLoading: _isSaving || _isCheckingDuplicates,
          onPressed: _submit,
        ),
      ],
    );
  }

  double _formBodyHeight(BuildContext context) {
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    return math.min(640, viewportHeight * 0.72);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final bool shouldCheckDuplicates =
        !_isEditing &&
        !_duplicateWarningAccepted &&
        widget.onLookupDuplicates != null;
    if (shouldCheckDuplicates) {
      final bool canContinue = await _checkDuplicatesBeforeSave();
      if (!canContinue) {
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final Map<String, Object?> payload = <String, Object?>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'date_of_birth': _dateOfBirth?.toIso8601String(),
      'gender': _gender,
      'facility_id': _facilityId,
      'primary_phone': _phoneController.text.trim(),
      'primary_email': _emailController.text.trim(),
      'primary_identifier_type': _identifierTypeController.text
          .trim()
          .toUpperCase(),
      'primary_identifier_value': _identifierValueController.text.trim(),
      'is_active': _isActive,
    };
    final AppFailure? failure = await widget.onSubmit(payload);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = false;
      _failure = failure;
    });
  }

  Future<bool> _checkDuplicatesBeforeSave() async {
    setState(() {
      _isCheckingDuplicates = true;
      _failure = null;
    });

    final Result<AppPage<PatientDuplicateCandidate>> result =
        await widget.onLookupDuplicates!(
          PatientDuplicateQuery(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _dateOfBirth,
            phone: _phoneController.text.trim(),
            identifierValue: _identifierValueController.text.trim(),
          ),
        );
    if (!mounted) {
      return false;
    }

    return result.when(
      success: (AppPage<PatientDuplicateCandidate> page) {
        if (page.items.isEmpty) {
          setState(() {
            _isCheckingDuplicates = false;
            _duplicateCandidates = const <PatientDuplicateCandidate>[];
          });
          return true;
        }

        setState(() {
          _isCheckingDuplicates = false;
          _duplicateCandidates = page.items;
          _duplicateWarningAccepted = true;
        });
        return false;
      },
      failure: (AppFailure failure) {
        setState(() {
          _isCheckingDuplicates = false;
          _failure = failure;
        });
        return false;
      },
    );
  }

  void _clearDuplicateWarning() {
    if (_duplicateCandidates.isEmpty && !_duplicateWarningAccepted) {
      return;
    }

    setState(() {
      _duplicateCandidates = const <PatientDuplicateCandidate>[];
      _duplicateWarningAccepted = false;
    });
  }
}

class PatientDuplicateWarningPanel extends StatelessWidget {
  const PatientDuplicateWarningPanel({required this.duplicates, super.key});

  final List<PatientDuplicateCandidate> duplicates;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Iterable<PatientDuplicateCandidate> visible = duplicates.take(3);

    return AppMessagePanel(
      title: l10n.patientsDuplicateWarningTitle,
      message: l10n.patientsDuplicateWarningBody,
      icon: Icons.content_copy_outlined,
      tone: AppWorkspaceStatusTone.warning,
      children: <Widget>[
        for (final PatientDuplicateCandidate duplicate in visible)
          _DuplicateCandidateLine(duplicate: duplicate),
      ],
    );
  }
}

class _DuplicateCandidateLine extends StatelessWidget {
  const _DuplicateCandidateLine({required this.duplicate});

  final PatientDuplicateCandidate duplicate;

  @override
  Widget build(BuildContext context) {
    final Patient? patient =
        duplicate.secondaryPatient ??
        duplicate.candidatePatient ??
        duplicate.primaryPatient;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.patientsDuplicateScoreLabel(duplicate.confidenceScore),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              _joinDisplay(<String?>[
                patient?.effectiveDisplayName,
                patient?.effectiveIdentifier,
                duplicate.matchReasons.map(_apiLabel).join(', '),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class EmergencyPatientFormDialog extends StatefulWidget {
  const EmergencyPatientFormDialog({required this.onSubmit, super.key});

  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  State<EmergencyPatientFormDialog> createState() =>
      _EmergencyPatientFormDialogState();
}

class _EmergencyPatientFormDialogState
    extends State<EmergencyPatientFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
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
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.patientsEmergencyRegisterTitle),
      icon: const Icon(Icons.emergency_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: _failure == null
            ? null
            : AppFailureStateView(failure: _failure!),
        children: <Widget>[
          Text(l10n.patientsEmergencyRegisterBody),
          AppResponsiveFieldRow.two(
            left: AppTextField(
              controller: _firstNameController,
              labelText: l10n.patientsEmergencyFirstNameLabel,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.words,
            ),
            right: AppTextField(
              controller: _lastNameController,
              labelText: l10n.patientsEmergencyLastNameLabel,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          PatientPhoneField(
            controller: _phoneController,
            labelText: l10n.patientsPhoneLabel,
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.patientsNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: _isSaving ? null : () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: l10n.patientsEmergencySaveAction,
          leadingIcon: Icons.emergency_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final DateTime registeredAt = DateTime.now().toUtc();
    final String firstName = _firstNameController.text.trim();
    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'first_name': firstName.isEmpty ? 'Emergency' : firstName,
      'last_name': _lastNameController.text.trim(),
      'gender': 'UNKNOWN',
      'primary_phone': _phoneController.text.trim(),
      'is_active': true,
      'extension_json': <String, Object?>{
        'registration': <String, Object?>{
          'source': 'EMERGENCY',
          'status': 'INCOMPLETE',
          'requires_completion': true,
          'registered_at': registeredAt.toIso8601String(),
          'notes': _notesController.text.trim(),
        },
      },
    });
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = false;
      _failure = failure;
    });
  }
}

class PatientRelatedRecordDialog<T> extends StatefulWidget {
  const PatientRelatedRecordDialog({
    required this.detail,
    required this.resource,
    required this.referenceData,
    required this.onCreate,
    required this.onUpdate,
    this.onUploadDocuments,
    this.item,
    super.key,
  });

  final PatientDetail detail;
  final PatientRelatedResource resource;
  final PatientReferenceData referenceData;
  final T? item;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onCreate;
  final Future<AppFailure?> Function(
    String recordId,
    Map<String, Object?> payload,
  )
  onUpdate;
  final Future<AppFailure?> Function({
    required String patientId,
    required String documentType,
    required List<PatientDocumentUploadFile> files,
  })?
  onUploadDocuments;

  @override
  State<PatientRelatedRecordDialog<T>> createState() =>
      _PatientRelatedRecordDialogState<T>();
}

class _PatientRelatedRecordDialogState<T>
    extends State<PatientRelatedRecordDialog<T>> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _first = TextEditingController();
  final TextEditingController _second = TextEditingController();
  final TextEditingController _third = TextEditingController();
  final TextEditingController _fourth = TextEditingController();
  String? _choice;
  bool _isPrimary = false;
  DateTime? _date;
  List<XFile> _documentFiles = const <XFile>[];
  bool _isPickingDocuments = false;
  bool _isSaving = false;
  AppFailure? _failure;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _third.dispose();
    _fourth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(
        _isEditing
            ? l10n.patientsEditRelatedTitle
            : l10n.patientsAddRelatedTitle,
      ),
      icon: Icon(_resourceIcon(widget.resource)),
      scrollable: true,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: _failure == null
            ? null
            : AppFailureStateView(failure: _failure!),
        children: _fieldsForResource(context),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: _isSaving ? null : () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: l10n.patientsSaveAction,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  List<Widget> _fieldsForResource(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.resource) {
      PatientRelatedResource.identifier => <Widget>[
        AppSelectField<String>.searchable(
          value: _selectedIdentifierType(_first.text),
          labelText: l10n.patientsIdentifierTypeLabel,
          enabled: !_isSaving,
          isRequired: true,
          menuHeight: 320,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onChanged: (String? value) =>
              setState(() => _first.text = value ?? ''),
          options: _identifierTypeSelectOptions(_first.text),
        ),
        AppTextField(
          controller: _second,
          labelText: l10n.patientsIdentifierValueLabel,
          enabled: !_isSaving,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppCheckboxField(
          title: l10n.patientsPrimaryRecordLabel,
          value: _isPrimary,
          enabled: !_isSaving,
          onChanged: (bool value) => setState(() => _isPrimary = value),
        ),
      ],
      PatientRelatedResource.contact => <Widget>[
        AppSelectField<String>.searchable(
          value: _choice,
          labelText: l10n.patientsContactTypeLabel,
          isRequired: true,
          enabled: !_isSaving,
          menuHeight: 320,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onChanged: (String? value) => setState(() {
            _choice = value;
            _first.clear();
          }),
          options: _contactTypeSelectOptions(),
        ),
        _contactValueField(context),
        AppCheckboxField(
          title: l10n.patientsPrimaryRecordLabel,
          value: _isPrimary,
          enabled: !_isSaving,
          onChanged: (bool value) => setState(() => _isPrimary = value),
        ),
      ],
      PatientRelatedResource.guardian => <Widget>[
        AppTextField(
          controller: _first,
          labelText: l10n.patientsGuardianNameLabel,
          enabled: !_isSaving,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppSelectField<String>.searchable(
          value: _second.text.trim().isEmpty
              ? null
              : _second.text.trim().toUpperCase(),
          labelText: l10n.patientsGuardianRelationshipLabel,
          enabled: !_isSaving,
          menuHeight: 360,
          onChanged: (String? value) =>
              setState(() => _second.text = value ?? ''),
          options: _relationshipSelectOptions(_second.text),
        ),
        PatientPhoneField(
          controller: _third,
          labelText: l10n.patientsPhoneLabel,
          enabled: !_isSaving,
        ),
        PatientEmailField(
          controller: _fourth,
          labelText: l10n.patientsEmailLabel,
          enabled: !_isSaving,
        ),
      ],
      PatientRelatedResource.allergy => <Widget>[
        AppTextField(
          controller: _first,
          labelText: l10n.patientsAllergenLabel,
          enabled: !_isSaving,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppSelectField<String>(
          value: _choice,
          labelText: l10n.patientsSeverityLabel,
          enabled: !_isSaving,
          isRequired: true,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onChanged: (String? value) => setState(() => _choice = value),
          options: <AppSelectOption<String>>[
            for (final String value in _severityOptions)
              AppSelectOption<String>(value: value, label: _apiLabel(value)),
          ],
        ),
        AppTextField(
          controller: _second,
          labelText: l10n.patientsReactionLabel,
          enabled: !_isSaving,
        ),
        AppTextField(
          controller: _third,
          labelText: l10n.patientsNotesLabel,
          maxLines: 3,
          enabled: !_isSaving,
        ),
      ],
      PatientRelatedResource.medicalHistory => <Widget>[
        AppTextField(
          controller: _first,
          labelText: l10n.patientsConditionLabel,
          enabled: !_isSaving,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        PatientDateField(
          value: _date,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          labelText: l10n.patientsDiagnosisDateLabel,
          enabled: !_isSaving,
          onChanged: (DateTime? value) => _date = value,
        ),
        AppTextField(
          controller: _second,
          labelText: l10n.patientsNotesLabel,
          maxLines: 3,
          enabled: !_isSaving,
        ),
      ],
      PatientRelatedResource.document => <Widget>[
        AppSelectField<String>.searchable(
          value: _choice,
          labelText: l10n.patientsDocumentTypeLabel,
          enabled: !_isSaving,
          isRequired: true,
          menuHeight: 320,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onChanged: (String? value) => setState(() => _choice = value),
          options: _documentTypeSelectOptions(
            widget.referenceData.documentTypes.isEmpty
                ? _documentTypes
                : widget.referenceData.documentTypes,
          ),
        ),
        AppFileUploadPanel(
          title: l10n.patientsDocumentUploadTitle,
          emptyDescription: l10n.patientsDocumentUploadEmpty,
          chooseLabel: l10n.patientsChooseDocumentAction,
          clearLabel: l10n.patientsClearFiltersAction,
          fileNames: _documentFiles
              .map((XFile file) => file.name)
              .toList(growable: false),
          enabled:
              !_isSaving &&
              !_isPickingDocuments &&
              widget.onUploadDocuments != null,
          isLoading: _isPickingDocuments,
          onChoose: _pickDocumentFiles,
          onClear: () => setState(() => _documentFiles = const <XFile>[]),
        ),
        AppTextField(
          controller: _first,
          labelText: l10n.patientsStorageKeyAdvancedLabel,
          helperText: l10n.patientsStorageKeyAdvancedHelper,
          enabled: !_isSaving,
          isRequired:
              _documentFiles.isEmpty &&
              (_isEditing || widget.onUploadDocuments == null),
          validator: (String? value) {
            if (_documentFiles.isNotEmpty) {
              return null;
            }
            if (!_isEditing && widget.onUploadDocuments != null) {
              return AppValidators.requiredText(l10n.validationRequired)(value);
            }
            return AppValidators.requiredText(l10n.validationRequired)(value);
          },
        ),
        AppTextField(
          controller: _second,
          labelText: l10n.patientsFileNameLabel,
          enabled: !_isSaving,
        ),
        AppTextField(
          controller: _third,
          labelText: l10n.patientsContentTypeLabel,
          enabled: !_isSaving,
        ),
      ],
      PatientRelatedResource.consent => <Widget>[
        AppSelectField<String>.searchable(
          value: _choice,
          labelText: l10n.patientsConsentTypeLabel,
          enabled: !_isSaving,
          isRequired: true,
          menuHeight: 320,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onChanged: (String? value) => setState(() => _choice = value),
          options: _consentTypeSelectOptions(
            widget.referenceData.consentTypes.isEmpty
                ? _consentTypes
                : widget.referenceData.consentTypes,
          ),
        ),
        AppSelectField<String>(
          value: _first.text.isEmpty ? null : _first.text,
          labelText: l10n.patientsConsentStatusLabel,
          enabled: !_isSaving,
          isRequired: true,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onChanged: (String? value) =>
              setState(() => _first.text = value ?? ''),
          options: <AppSelectOption<String>>[
            for (final String value
                in widget.referenceData.consentStatuses.isEmpty
                    ? _consentStates
                    : widget.referenceData.consentStatuses)
              AppSelectOption<String>(value: value, label: _apiLabel(value)),
          ],
        ),
        PatientDateField(
          value: _date,
          firstDate: DateTime(1900),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          labelText: l10n.patientsConsentDateLabel,
          enabled: !_isSaving,
          onChanged: (DateTime? value) => _date = value,
        ),
      ],
    };
  }

  Widget _contactValueField(BuildContext context) {
    final l10n = context.l10n;
    final String type = (_choice ?? '').toUpperCase();
    if (<String>{'PHONE', 'WHATSAPP', 'FAX'}.contains(type)) {
      return PatientPhoneField(
        controller: _first,
        labelText: l10n.patientsContactValueLabel,
        requiredMessage: l10n.validationRequired,
        enabled: !_isSaving,
        isRequired: true,
      );
    }

    if (type == 'EMAIL') {
      return PatientEmailField(
        controller: _first,
        labelText: l10n.patientsContactValueLabel,
        requiredMessage: l10n.validationRequired,
        enabled: !_isSaving,
        isRequired: true,
      );
    }

    return AppTextField(
      controller: _first,
      labelText: l10n.patientsContactValueLabel,
      enabled: !_isSaving,
      isRequired: true,
      validator: AppValidators.compose<String>(<FormFieldValidator<String>>[
        AppValidators.requiredText(l10n.validationRequired),
        AppValidators.maxLength(
          255,
          l10n.patientsContactInvalidMessage,
          allowEmpty: false,
          trim: true,
        ),
      ]),
    );
  }

  Future<void> _pickDocumentFiles() async {
    setState(() {
      _isPickingDocuments = true;
      _failure = null;
    });
    try {
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: context.l10n.patientsDocumentsSectionTitle,
            extensions: const <String>['pdf', 'jpg', 'jpeg', 'png'],
            mimeTypes: const <String>[
              'application/pdf',
              'image/jpeg',
              'image/jpg',
              'image/png',
            ],
          ),
        ],
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _documentFiles = files.take(5).toList(growable: false);
        _isPickingDocuments = false;
        if (_documentFiles.isNotEmpty) {
          _first.clear();
          if (_documentFiles.length == 1) {
            _second.text = _documentFiles.first.name;
            _third.text = _documentFiles.first.mimeType ?? '';
          }
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPickingDocuments = false;
      });
    }
  }

  void _hydrate() {
    final Object? item = widget.item;
    switch (item) {
      case final PatientIdentifier value:
        _first.text = value.type;
        _second.text = value.value;
        _isPrimary = value.isPrimary;
      case final PatientContact value:
        _choice = value.type;
        _first.text = value.value;
        _isPrimary = value.isPrimary;
      case final PatientGuardian value:
        _first.text = value.name;
        _second.text = value.relationship ?? '';
        _third.text = value.phone ?? '';
        _fourth.text = value.email ?? '';
      case final PatientAllergy value:
        _first.text = value.allergen;
        _choice = value.severity;
        _second.text = value.reaction ?? '';
        _third.text = value.notes ?? '';
      case final PatientMedicalHistory value:
        _first.text = value.condition;
        _date = value.diagnosisDate;
        _second.text = value.notes ?? '';
      case final PatientDocument value:
        _choice = value.documentType;
        _first.text = value.storageKey;
        _second.text = value.fileName ?? '';
        _third.text = value.contentType ?? '';
      case final PatientConsent value:
        _choice = value.consentType;
        _first.text = value.status;
        _date = value.grantedAt ?? value.revokedAt;
      default:
        _choice = _defaultChoice(widget.resource, widget.referenceData);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final String? recordId = _recordId(widget.item);
    if (widget.resource == PatientRelatedResource.document &&
        recordId == null &&
        _documentFiles.isNotEmpty &&
        widget.onUploadDocuments != null) {
      final AppFailure? failure = await _uploadDocuments();
      if (!mounted) {
        return;
      }
      if (failure == null) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _isSaving = false;
        _failure = failure;
      });
      return;
    }

    final Map<String, Object?> payload = _payload();
    final AppFailure? failure = recordId == null
        ? await widget.onCreate(payload)
        : await widget.onUpdate(recordId, payload);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSaving = false;
      _failure = failure;
    });
  }

  Future<AppFailure?> _uploadDocuments() async {
    final List<PatientDocumentUploadFile> files = <PatientDocumentUploadFile>[];
    for (final XFile file in _documentFiles) {
      files.add(
        PatientDocumentUploadFile(
          name: file.name,
          bytes: await file.readAsBytes(),
          contentType: file.mimeType,
        ),
      );
    }

    return widget.onUploadDocuments!(
      patientId: widget.detail.patient.id,
      documentType: _choice ?? 'OTHER',
      files: files,
    );
  }

  Map<String, Object?> _payload() {
    final Patient patient = widget.detail.patient;
    final Map<String, Object?> createContext = <String, Object?>{
      'tenant_id': patient.tenantId,
      'patient_id': patient.id,
    };

    return switch (widget.resource) {
      PatientRelatedResource.identifier => <String, Object?>{
        ...createContext,
        'identifier_type': _first.text.trim().toUpperCase(),
        'identifier_value': _second.text.trim(),
        'is_primary': _isPrimary,
      },
      PatientRelatedResource.contact => <String, Object?>{
        ...createContext,
        'contact_type': _choice,
        'value': _first.text.trim(),
        'is_primary': _isPrimary,
      },
      PatientRelatedResource.guardian => <String, Object?>{
        ...createContext,
        'name': _first.text.trim(),
        'relationship': _second.text.trim().toUpperCase(),
        'phone': _third.text.trim(),
        'email': _fourth.text.trim(),
      },
      PatientRelatedResource.allergy => <String, Object?>{
        ...createContext,
        'allergen': _first.text.trim(),
        'severity': _choice,
        'reaction': _second.text.trim(),
        'notes': _third.text.trim(),
      },
      PatientRelatedResource.medicalHistory => <String, Object?>{
        ...createContext,
        'condition': _first.text.trim(),
        'diagnosis_date': _date?.toUtc().toIso8601String(),
        'notes': _second.text.trim(),
      },
      PatientRelatedResource.document => <String, Object?>{
        ...createContext,
        'document_type': _choice,
        'storage_key': _first.text.trim(),
        'file_name': _second.text.trim(),
        'content_type': _third.text.trim(),
      },
      PatientRelatedResource.consent => <String, Object?>{
        'patient_id': patient.id,
        'consent_type': _choice,
        'status': _first.text.trim(),
        if (_first.text.trim() == 'GRANTED')
          'granted_at': _date?.toUtc().toIso8601String(),
        if (_first.text.trim() == 'REVOKED')
          'revoked_at': _date?.toUtc().toIso8601String(),
      },
    };
  }
}

Future<bool?> _showDeleteDialog(
  BuildContext context, {
  required String title,
  required String body,
}) {
  final l10n = context.l10n;

  return showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(title),
      icon: const Icon(Icons.warning_amber_outlined),
      content: Text(body),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.patientsDeleteAction,
          leadingIcon: Icons.delete_outline,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
}

PatientRegistryState? _readCurrentState(WidgetRef ref) {
  final Result<PatientRegistryState>? result = ref
      .read(patientRegistryControllerProvider)
      .asData
      ?.value;
  return switch (result) {
    ResultSuccess<PatientRegistryState>(value: final value) => value,
    _ => null,
  };
}

Future<void> _showFailureIfNeeded(
  BuildContext context,
  AppFailure? failure,
) async {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

PatientRelatedResource _resourceForItem<T>(T? item) {
  if (item is PatientIdentifier || T == PatientIdentifier) {
    return PatientRelatedResource.identifier;
  }
  if (item is PatientContact || T == PatientContact) {
    return PatientRelatedResource.contact;
  }
  if (item is PatientGuardian || T == PatientGuardian) {
    return PatientRelatedResource.guardian;
  }
  if (item is PatientAllergy || T == PatientAllergy) {
    return PatientRelatedResource.allergy;
  }
  if (item is PatientMedicalHistory || T == PatientMedicalHistory) {
    return PatientRelatedResource.medicalHistory;
  }
  if (item is PatientDocument || T == PatientDocument) {
    return PatientRelatedResource.document;
  }
  return PatientRelatedResource.consent;
}

PatientRelatedResource _resourceForRecordId(
  PatientDetail detail,
  String recordId,
) {
  if (detail.identifiers.any((PatientIdentifier item) => item.id == recordId)) {
    return PatientRelatedResource.identifier;
  }
  if (detail.contacts.any((PatientContact item) => item.id == recordId)) {
    return PatientRelatedResource.contact;
  }
  if (detail.guardians.any((PatientGuardian item) => item.id == recordId)) {
    return PatientRelatedResource.guardian;
  }
  if (detail.allergies.any((PatientAllergy item) => item.id == recordId)) {
    return PatientRelatedResource.allergy;
  }
  if (detail.medicalHistories.any(
    (PatientMedicalHistory item) => item.id == recordId,
  )) {
    return PatientRelatedResource.medicalHistory;
  }
  if (detail.documents.any((PatientDocument item) => item.id == recordId)) {
    return PatientRelatedResource.document;
  }
  return PatientRelatedResource.consent;
}

String? _recordId(Object? item) {
  return switch (item) {
    final PatientIdentifier value => value.id,
    final PatientContact value => value.id,
    final PatientGuardian value => value.id,
    final PatientAllergy value => value.id,
    final PatientMedicalHistory value => value.id,
    final PatientDocument value => value.id,
    final PatientConsent value => value.id,
    _ => null,
  };
}

String? _defaultChoice(
  PatientRelatedResource resource,
  PatientReferenceData referenceData,
) {
  return switch (resource) {
    PatientRelatedResource.contact => 'PHONE',
    PatientRelatedResource.allergy => 'MILD',
    PatientRelatedResource.document =>
      referenceData.documentTypes.firstOrNull ?? _documentTypes.first,
    PatientRelatedResource.consent =>
      referenceData.consentTypes.firstOrNull ?? _consentTypes.first,
    _ => null,
  };
}

IconData _resourceIcon(PatientRelatedResource resource) {
  return switch (resource) {
    PatientRelatedResource.identifier => Icons.badge_outlined,
    PatientRelatedResource.contact => Icons.contact_phone_outlined,
    PatientRelatedResource.guardian => Icons.supervisor_account_outlined,
    PatientRelatedResource.allergy => Icons.warning_amber_outlined,
    PatientRelatedResource.medicalHistory => Icons.history_edu_outlined,
    PatientRelatedResource.document => Icons.description_outlined,
    PatientRelatedResource.consent => Icons.assignment_turned_in_outlined,
  };
}

String? _statusValue(bool? active) {
  return active == null
      ? null
      : active
      ? _statusActive
      : _statusInactive;
}

bool? _activeValue(String? status) {
  return switch (status) {
    _statusActive => true,
    _statusInactive => false,
    _ => null,
  };
}

List<String> _filterConsentStatuses(PatientRegistryState? state) {
  final List<String> values =
      state?.referenceData.consentStatuses ?? const <String>[];
  return values.isEmpty ? _consentStates : values;
}

String _genderLabel(AppLocalizations l10n, String value) {
  return switch (value.toUpperCase()) {
    'MALE' => l10n.patientsGenderMale,
    'FEMALE' => l10n.patientsGenderFemale,
    'OTHER' => l10n.patientsGenderOther,
    'UNKNOWN' => l10n.patientsGenderUnknown,
    _ => _apiLabel(value),
  };
}

String _formatOptionalDate(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.mediumDate(value, Localizations.localeOf(context));
}

String _formatOptionalDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? ''
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

List<AppSelectOption<String>> _simpleStatusOptions(Iterable<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

List<AppTriageOption> _statusTriageOptions(Iterable<String> values) {
  return <AppTriageOption>[
    for (final String value in values)
      AppTriageOption(
        value: value,
        label: _apiLabel(value),
        tone: appTriageToneForValue(value),
        icon: appTriageIconForValue(value),
      ),
  ];
}

List<AppSelectOption<String>> _providerSelectOptions(
  List<OpdProviderOption> providers,
) {
  return <AppSelectOption<String>>[
    for (final OpdProviderOption provider in providers)
      AppSelectOption<String>(
        value: provider.id,
        label: provider.displayTitle,
        leadingIcon: const Icon(Icons.person_search_outlined),
        labelWidget: AppListItemText(
          title: provider.displayTitle,
          subtitle: _joinDisplay(<String?>[
            provider.positionTitle,
            provider.practitionerType,
          ]),
        ),
      ),
  ];
}

FormFieldValidator<String> _timeValidator(BuildContext context) {
  return (String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return context.l10n.validationRequired;
    }
    return _parseTime(normalized) == null
        ? context.l10n.patientsTimeInvalidMessage
        : null;
  };
}

FormFieldValidator<String> _durationValidator(BuildContext context) {
  return (String? value) {
    final int? minutes = int.tryParse(value?.trim() ?? '');
    if (minutes == null) {
      return context.l10n.validationRequired;
    }
    return minutes <= 0 || minutes > 720
        ? context.l10n.patientsDurationInvalidMessage
        : null;
  };
}

DateTime? _combineDateAndTime(DateTime date, String time) {
  final (int, int)? parsed = _parseTime(time);
  if (parsed == null) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, parsed.$1, parsed.$2);
}

(int, int)? _parseTime(String value) {
  final RegExpMatch? match = RegExp(
    r'^([01]?\d|2[0-3]):([0-5]\d)$',
  ).firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  return (int.parse(match.group(1)!), int.parse(match.group(2)!));
}

Map<String, Object?> _withoutEmptyPayload(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_payloadValueIsEmpty(entry.value)) entry.key: entry.value,
  };
}

bool _payloadValueIsEmpty(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable) {
    return value.isEmpty;
  }
  if (value is Map) {
    return value.isEmpty;
  }
  return false;
}

T? _successOrNull<T>(Result<T> result) {
  return result.when(success: (T value) => value, failure: (_) => null);
}

AppFailure? _failureOrNull<T>(Result<T> result) {
  return result.when(
    success: (_) => null,
    failure: (AppFailure value) => value,
  );
}

String _workflowFailureMessage(BuildContext context, AppFailure failure) {
  final l10n = context.l10n;
  if (failure.validationFields.isEmpty) {
    return l10n.failureMessage(failure);
  }
  final String fields = failure.validationFields.map(_apiLabel).join(', ');
  return l10n.patientsWorkflowValidationMessage(fields);
}

String _apiLabel(String value) {
  return AppDisplay.apiLabel(value);
}

List<String> _identifierTypeOptions(String currentValue) {
  final String normalized = currentValue.trim().toUpperCase();
  if (normalized.isEmpty || _identifierTypes.contains(normalized)) {
    return _identifierTypes;
  }

  return <String>[normalized, ..._identifierTypes];
}

List<AppSelectOption<String>> _identifierTypeSelectOptions(
  String currentValue,
) {
  return <AppSelectOption<String>>[
    for (final String value in _identifierTypeOptions(currentValue))
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_identifierTypeIcon(value)),
      ),
  ];
}

String? _selectedIdentifierType(String currentValue) {
  final String normalized = currentValue.trim().toUpperCase();
  return normalized.isEmpty ? null : normalized;
}

List<AppSelectOption<String>> _contactTypeSelectOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _contactTypes)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_contactTypeIcon(value)),
      ),
  ];
}

List<AppSelectOption<String>> _relationshipSelectOptions(String currentValue) {
  final String normalized = currentValue.trim().toUpperCase();
  final List<String> values =
      normalized.isEmpty || _relationshipTypes.contains(normalized)
      ? _relationshipTypes
      : <String>[normalized, ..._relationshipTypes];
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_relationshipIcon(value)),
      ),
  ];
}

List<AppSelectOption<String>> _documentTypeSelectOptions(
  Iterable<String> values,
) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_documentTypeIcon(value)),
      ),
  ];
}

List<AppSelectOption<String>> _consentTypeSelectOptions(
  Iterable<String> values,
) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_consentTypeIcon(value)),
      ),
  ];
}

List<AppSelectOption<String>> _paymentMethodSelectOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _paymentMethods)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_paymentMethodIcon(value)),
      ),
  ];
}

List<AppSelectOption<bool>> _booleanFilterOptions(AppLocalizations l10n) {
  return <AppSelectOption<bool>>[
    AppSelectOption<bool>(
      value: true,
      label: l10n.patientsYesFilterLabel,
      leadingIcon: const Icon(Icons.check_circle_outline),
    ),
    AppSelectOption<bool>(
      value: false,
      label: l10n.patientsNoFilterLabel,
      leadingIcon: const Icon(Icons.block_outlined),
    ),
  ];
}

IconData _identifierTypeIcon(String value) {
  return switch (value.toUpperCase()) {
    'MRN' => Icons.local_hospital_outlined,
    'NATIONAL_ID' => Icons.credit_card_outlined,
    'PASSPORT' => Icons.flight_takeoff_outlined,
    'INSURANCE' => Icons.health_and_safety_outlined,
    'DRIVER_LICENSE' => Icons.badge_outlined,
    'BIRTH_CERTIFICATE' => Icons.child_care_outlined,
    _ => Icons.perm_identity_outlined,
  };
}

IconData _appointmentStatusIcon(String value) {
  return switch (value.toUpperCase()) {
    'SCHEDULED' => Icons.event_available_outlined,
    'CONFIRMED' => Icons.verified_outlined,
    'IN_PROGRESS' => Icons.pending_actions_outlined,
    'COMPLETED' => Icons.check_circle_outline,
    'CANCELLED' => Icons.cancel_outlined,
    'NO_SHOW' => Icons.event_busy_outlined,
    _ => Icons.event_note_outlined,
  };
}

IconData _contactTypeIcon(String value) {
  return switch (value.toUpperCase()) {
    'PHONE' => Icons.phone_outlined,
    'EMAIL' => Icons.alternate_email_outlined,
    'WHATSAPP' => Icons.chat_outlined,
    'TELEGRAM' => Icons.send_outlined,
    'FAX' => Icons.print_outlined,
    'FACEBOOK' => Icons.groups_outlined,
    'LINKEDIN' => Icons.work_outline,
    'X' => Icons.public_outlined,
    'YOUTUBE' => Icons.play_circle_outline,
    'DISCORD' => Icons.forum_outlined,
    _ => Icons.contact_mail_outlined,
  };
}

IconData _relationshipIcon(String value) {
  return switch (value.toUpperCase()) {
    'SPOUSE' || 'PARTNER' => Icons.favorite_border,
    'PARENT' || 'MOTHER' || 'FATHER' => Icons.family_restroom_outlined,
    'CHILD' || 'SON' || 'DAUGHTER' => Icons.child_care_outlined,
    'SIBLING' || 'BROTHER' || 'SISTER' => Icons.people_alt_outlined,
    'GUARDIAN' || 'CAREGIVER' => Icons.supervisor_account_outlined,
    'NEXT_OF_KIN' => Icons.contact_emergency_outlined,
    _ => Icons.person_outline,
  };
}

IconData _documentTypeIcon(String value) {
  return switch (value.toUpperCase()) {
    'IDENTITY' => Icons.badge_outlined,
    'INSURANCE' => Icons.health_and_safety_outlined,
    'REFERRAL' => Icons.forward_to_inbox_outlined,
    'LAB_RESULT' => Icons.science_outlined,
    'RADIOLOGY' => Icons.biotech_outlined,
    'PRESCRIPTION' => Icons.medication_outlined,
    'CONSENT' => Icons.assignment_turned_in_outlined,
    'DISCHARGE' => Icons.logout_outlined,
    _ => Icons.description_outlined,
  };
}

IconData _consentTypeIcon(String value) {
  return switch (value.toUpperCase()) {
    'TREATMENT' => Icons.medical_services_outlined,
    'DATA_SHARING' => Icons.share_outlined,
    'RESEARCH' => Icons.science_outlined,
    'BILLING' => Icons.receipt_long_outlined,
    _ => Icons.verified_user_outlined,
  };
}

IconData _paymentMethodIcon(String value) {
  return switch (value.toUpperCase()) {
    'CASH' => Icons.payments_outlined,
    'CREDIT_CARD' || 'DEBIT_CARD' || 'PREPAID_CARD' => Icons.credit_card,
    'MOBILE_MONEY' => Icons.phone_android_outlined,
    'BANK_TRANSFER' || 'BANK_CHECK' => Icons.account_balance_outlined,
    'INSURANCE' => Icons.health_and_safety_outlined,
    'VOUCHER' || 'GIFT_CARD' => Icons.confirmation_number_outlined,
    _ => Icons.receipt_long_outlined,
  };
}

String _joinDisplay(Iterable<String?> values) {
  return AppDisplay.joinNonEmpty(values);
}

String _patientApiId(Patient patient) {
  for (final String? value in <String?>[patient.publicId, patient.id]) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return patient.id;
}

const List<String> _identifierTypes = <String>[
  'MRN',
  'NATIONAL_ID',
  'PASSPORT',
  'INSURANCE',
  'DRIVER_LICENSE',
  'BIRTH_CERTIFICATE',
  'OTHER',
];
const List<String> _contactTypes = <String>[
  'PHONE',
  'EMAIL',
  'WHATSAPP',
  'TELEGRAM',
  'TIKTOK',
  'INSTAGRAM',
  'FACEBOOK',
  'LINKEDIN',
  'X',
  'YOUTUBE',
  'PINTEREST',
  'REDDIT',
  'DISCORD',
  'FAX',
  'OTHER',
];
const List<String> _relationshipTypes = <String>[
  'SPOUSE',
  'PARTNER',
  'PARENT',
  'MOTHER',
  'FATHER',
  'CHILD',
  'SON',
  'DAUGHTER',
  'SIBLING',
  'BROTHER',
  'SISTER',
  'GRANDPARENT',
  'GRANDCHILD',
  'AUNT',
  'UNCLE',
  'COUSIN',
  'GUARDIAN',
  'CAREGIVER',
  'NEXT_OF_KIN',
  'FRIEND',
  'OTHER',
];
const List<String> _severityOptions = <String>['MILD', 'MODERATE', 'SEVERE'];
const List<String> _emergencySeverityOptions = <String>[
  'LOW',
  'MEDIUM',
  'HIGH',
  'CRITICAL',
];
const List<String> _triageLevelOptions = <String>[
  'LEVEL_1',
  'LEVEL_2',
  'LEVEL_3',
  'LEVEL_4',
  'LEVEL_5',
  'IMMEDIATE',
  'URGENT',
  'LESS_URGENT',
  'NON_URGENT',
];
const List<String> _paymentMethods = <String>[
  'CASH',
  'CREDIT_CARD',
  'DEBIT_CARD',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'INSURANCE',
  'OTHER',
];
const List<String> _consentStates = <String>['GRANTED', 'REVOKED', 'PENDING'];
const List<String> _consentTypes = <String>[
  'TREATMENT',
  'DATA_SHARING',
  'RESEARCH',
  'BILLING',
  'OTHER',
];
const List<String> _documentTypes = <String>[
  'IDENTITY',
  'INSURANCE',
  'REFERRAL',
  'LAB_RESULT',
  'RADIOLOGY',
  'PRESCRIPTION',
  'CONSENT',
  'DISCHARGE',
  'OTHER',
];
final DateTime _patientFilterFirstDate = DateTime(1900);
final DateTime _patientFilterLastDate = DateTime.now().add(
  const Duration(days: 730),
);
const String _statusActive = 'active';
const String _statusInactive = 'inactive';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

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

class _PatientRegistryContent extends ConsumerWidget {
  const _PatientRegistryContent({required this.state});

  final PatientRegistryState state;

  static const AccessRequirement _writeRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientWrite],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final PatientRegistryController controller = ref.read(
      patientRegistryControllerProvider.notifier,
    );

    return AppWorkspace(
      title: l10n.patientsTitle,
      description: '',
      compactSummaryCards: true,
      primaryAction: AppAccessActionGate(
        requirement: _writeRequirement,
        builder: (_, bool isAllowed) => AppButton.primary(
          label: l10n.patientsAddAction,
          leadingIcon: Icons.person_add_alt_1_outlined,
          enabled: isAllowed,
          onPressed: () {
            _openPatientForm(context, ref);
          },
        ),
      ),
      secondaryActions: <Widget>[
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshingList,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              await _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        AppWorkspaceSummaryCard(
          label: l10n.patientsTotalSummaryLabel,
          value: AppFormatters.compactNumber(
            state.overview.totalPatients,
            Localizations.localeOf(context),
          ),
          icon: Icons.groups_outlined,
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              ref,
              title: l10n.patientsTotalSummaryLabel,
              query: const PatientListQuery(
                pageRequest: AppPageRequest(pageSize: 8),
              ),
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.patientsActiveSummaryLabel,
          value: AppFormatters.compactNumber(
            state.overview.activePatients,
            Localizations.localeOf(context),
          ),
          icon: Icons.how_to_reg_outlined,
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              ref,
              title: l10n.patientsActiveSummaryLabel,
              query: const PatientListQuery(
                isActive: true,
                pageRequest: AppPageRequest(pageSize: 8),
              ),
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.patientsQueueSummaryLabel,
          value: AppFormatters.compactNumber(
            state.overview.waitingQueue,
            Localizations.localeOf(context),
          ),
          icon: Icons.queue_outlined,
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              ref,
              title: l10n.patientsQueueSummaryLabel,
              patients: state.overview.waitingQueuePatients,
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.patientsDuplicateSummaryLabel,
          value: AppFormatters.compactNumber(
            state.overview.duplicates.length,
            Localizations.localeOf(context),
          ),
          icon: Icons.content_copy_outlined,
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              ref,
              title: l10n.patientsDuplicateSummaryLabel,
              patients: _patientsFromDuplicates(state.overview.duplicates),
            );
          },
        ),
      ],
      filters: _PatientFilters(query: state.query),
      body: _PatientList(state: state),
      activity: _PatientActivityPanel(state: state),
    );
  }

  Future<void> _openPatientForm(BuildContext context, WidgetRef ref) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PatientFormDialog(
        referenceData: state.referenceData,
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

  Future<void> _openSummaryPatientList(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    PatientListQuery? query,
    List<Patient>? patients,
  }) async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => _PatientSummaryListDialog(
        title: title,
        query: query,
        patients: patients,
      ),
    );
  }
}

class _PatientFilters extends ConsumerStatefulWidget {
  const _PatientFilters({required this.query});

  final PatientListQuery query;

  @override
  ConsumerState<_PatientFilters> createState() => _PatientFiltersState();
}

class _PatientFiltersState extends ConsumerState<_PatientFilters> {
  late final TextEditingController _searchController;
  late final TextEditingController _patientIdController;
  String? _gender;
  String? _status;
  String? _consentState;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query.search);
    _patientIdController = TextEditingController(text: widget.query.patientId);
    _gender = widget.query.gender;
    _status = _statusValue(widget.query.isActive);
    _consentState = widget.query.consentState;
  }

  @override
  void didUpdateWidget(covariant _PatientFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _searchController.text = widget.query.search;
      _patientIdController.text = widget.query.patientId;
      _gender = widget.query.gender;
      _status = _statusValue(widget.query.isActive);
      _consentState = widget.query.consentState;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _patientIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppWorkspaceFilterBar(
      semanticLabel: l10n.patientsFiltersLabel,
      expandSearch: true,
      search: AppTextField(
        controller: _searchController,
        semanticLabel: l10n.patientsSearchLabel,
        hintText: l10n.patientsSearchHint,
        prefixIcon: const Icon(Icons.search),
        textInputAction: TextInputAction.search,
        onFieldSubmitted: (_) => _apply(),
      ),
      actions: <Widget>[
        AppIconButton(
          icon: Icons.tune,
          semanticLabel: l10n.patientsAdvancedFiltersAction,
          tooltip: l10n.patientsAdvancedFiltersAction,
          color: _hasAdvancedFilters
              ? Theme.of(context).colorScheme.primary
              : null,
          onPressed: () {
            _openAdvancedFilters(context);
          },
        ),
        AppIconButton(
          icon: Icons.search,
          semanticLabel: l10n.patientsApplyFiltersAction,
          tooltip: l10n.patientsApplyFiltersAction,
          onPressed: _apply,
        ),
        if (_hasAnyFilter)
          AppIconButton(
            icon: Icons.filter_alt_off_outlined,
            semanticLabel: l10n.patientsClearFiltersAction,
            tooltip: l10n.patientsClearFiltersAction,
            onPressed: _clear,
          ),
      ],
    );
  }

  bool get _hasAdvancedFilters {
    return _patientIdController.text.trim().isNotEmpty ||
        _gender != null ||
        _status != null ||
        _consentState != null;
  }

  bool get _hasAnyFilter {
    return _searchController.text.trim().isNotEmpty || _hasAdvancedFilters;
  }

  Future<void> _openAdvancedFilters(BuildContext context) async {
    final PatientRegistryState? state = _readCurrentState(ref);
    final _PatientFilterDraft? draft = await showAppDialog<_PatientFilterDraft>(
      context: context,
      builder: (_) => _PatientAdvancedFiltersDialog(
        patientId: _patientIdController.text,
        gender: _gender,
        status: _status,
        consentState: _consentState,
        consentStatuses: _filterConsentStatuses(state),
      ),
    );
    if (draft == null || !mounted) {
      return;
    }

    _patientIdController.text = draft.patientId;
    setState(() {
      _gender = draft.gender;
      _status = draft.status;
      _consentState = draft.consentState;
    });
    await _apply();
  }

  Future<void> _apply() async {
    final PatientListQuery nextQuery = widget.query.copyWith(
      search: _searchController.text.trim(),
      patientId: _patientIdController.text.trim(),
      gender: _gender,
      isActive: _activeValue(_status),
      consentState: _consentState,
      pageRequest: widget.query.pageRequest.first(),
      clearGender: _gender == null,
      clearIsActive: _status == null,
      clearConsentState: _consentState == null,
    );
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .applyQuery(nextQuery);
    if (mounted) {
      await _showFailureIfNeeded(context, failure);
    }
  }

  Future<void> _clear() async {
    _searchController.clear();
    _patientIdController.clear();
    setState(() {
      _gender = null;
      _status = null;
      _consentState = null;
    });
    final AppFailure? failure = await ref
        .read(patientRegistryControllerProvider.notifier)
        .applyQuery(const PatientListQuery());
    if (mounted) {
      await _showFailureIfNeeded(context, failure);
    }
  }
}

@immutable
final class _PatientFilterDraft {
  const _PatientFilterDraft({
    required this.patientId,
    required this.gender,
    required this.status,
    required this.consentState,
  });

  final String patientId;
  final String? gender;
  final String? status;
  final String? consentState;
}

class _PatientAdvancedFiltersDialog extends StatefulWidget {
  const _PatientAdvancedFiltersDialog({
    required this.patientId,
    required this.gender,
    required this.status,
    required this.consentState,
    required this.consentStatuses,
  });

  final String patientId;
  final String? gender;
  final String? status;
  final String? consentState;
  final List<String> consentStatuses;

  @override
  State<_PatientAdvancedFiltersDialog> createState() =>
      _PatientAdvancedFiltersDialogState();
}

class _PatientAdvancedFiltersDialogState
    extends State<_PatientAdvancedFiltersDialog> {
  late final TextEditingController _patientIdController;
  String? _gender;
  String? _status;
  String? _consentState;

  @override
  void initState() {
    super.initState();
    _patientIdController = TextEditingController(text: widget.patientId);
    _gender = widget.gender;
    _status = widget.status;
    _consentState = widget.consentState;
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.patientsAdvancedFiltersTitle),
      icon: const Icon(Icons.tune),
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          AppTextField(
            controller: _patientIdController,
            labelText: l10n.patientsPatientIdFilterLabel,
            textInputAction: TextInputAction.search,
          ),
          AppGenderField(
            value: _gender,
            labelText: l10n.patientsGenderFilterLabel,
            maleLabel: l10n.patientsGenderMale,
            femaleLabel: l10n.patientsGenderFemale,
            otherLabel: l10n.patientsGenderOther,
            unknownLabel: l10n.patientsGenderUnknown,
            onChanged: (String? value) {
              setState(() {
                _gender = value;
              });
            },
          ),
          AppSelectField<String>(
            value: _status,
            labelText: l10n.patientsStatusFilterLabel,
            onChanged: (String? value) {
              setState(() {
                _status = value;
              });
            },
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
          AppSelectField<String>(
            value: _consentState,
            labelText: l10n.patientsConsentFilterLabel,
            onChanged: (String? value) {
              setState(() {
                _consentState = value;
              });
            },
            options: <AppSelectOption<String>>[
              for (final String value in widget.consentStatuses)
                AppSelectOption<String>(value: value, label: _apiLabel(value)),
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
                gender: null,
                status: null,
                consentState: null,
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
                gender: _gender,
                status: _status,
                consentState: _consentState,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PatientList extends ConsumerWidget {
  const _PatientList({required this.state});

  final PatientRegistryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);

    return AppPaginatedDataList<Patient>(
      page: state.page,
      isLoading: state.isRefreshingList,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columns: <AppDataColumn<Patient>>[
        AppDataColumn<Patient>(
          label: l10n.patientsPatientColumnLabel,
          cellBuilder: (_, Patient patient) =>
              _PatientNameCell(patient: patient),
        ),
        AppDataColumn<Patient>(
          label: l10n.patientsIdentifierColumnLabel,
          cellBuilder: (_, Patient patient) =>
              Text(patient.effectiveIdentifier ?? l10n.profileUnknownValue),
        ),
        AppDataColumn<Patient>(
          label: l10n.patientsContactColumnLabel,
          cellBuilder: (_, Patient patient) => Text(
            patient.primaryPhone ??
                patient.primaryEmail ??
                l10n.profileUnknownValue,
          ),
        ),
        AppDataColumn<Patient>(
          label: l10n.patientsDobColumnLabel,
          cellBuilder: (_, Patient patient) => Text(
            patient.dateOfBirth == null
                ? l10n.profileUnknownValue
                : AppFormatters.mediumDate(patient.dateOfBirth!, locale),
          ),
        ),
        AppDataColumn<Patient>(
          label: l10n.patientsStatusColumnLabel,
          cellBuilder: (_, Patient patient) =>
              _StatusText(isActive: patient.isActive),
        ),
      ],
      mobileItemBuilder: (_, Patient patient) => Padding(
        padding: EdgeInsets.all(Theme.of(context).spacing.md),
        child: _PatientMobileRow(patient: patient),
      ),
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

class _PatientSummaryListDialog extends ConsumerStatefulWidget {
  const _PatientSummaryListDialog({
    required this.title,
    this.query,
    this.patients,
  });

  final String title;
  final PatientListQuery? query;
  final List<Patient>? patients;

  @override
  ConsumerState<_PatientSummaryListDialog> createState() =>
      _PatientSummaryListDialogState();
}

class _PatientSummaryListDialogState
    extends ConsumerState<_PatientSummaryListDialog> {
  late final TextEditingController _searchController;
  AppPage<Patient>? _page;
  AppFailure? _failure;
  Timer? _searchDebounce;
  String _search = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _search = widget.query?.search ?? '';
    _searchController = TextEditingController(text: _search);
    _searchController.addListener(_handleSearchChanged);
    final PatientListQuery? query = widget.query;
    if (query != null) {
      unawaited(_load(query.pageRequest));
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<Patient>? patients = widget.patients == null
        ? null
        : _filterPatients(widget.patients!);
    final AppPage<Patient>? page = _page;
    final Widget list = _failure != null
        ? AppFailureStateView(failure: _failure!)
        : patients != null
        ? _SummaryPatientList(
            page: AppPage<Patient>(
              items: patients,
              request: AppPageRequest(
                pageSize: patients.length.clamp(1, 20).toInt(),
              ),
              totalItemCount: patients.length,
            ),
            isLoading: false,
            onPageChanged: null,
          )
        : page == null && _isLoading
        ? AppWorkspaceStatePanel.loading(
            title: l10n.patientsSummaryLoadingTitle,
            body: l10n.patientsSummaryLoadingBody,
          )
        : _SummaryPatientList(
            page:
                page ??
                const AppPage<Patient>(
                  items: <Patient>[],
                  request: AppPageRequest(pageSize: 8),
                  totalItemCount: 0,
                ),
            isLoading: _isLoading,
            onPageChanged: (AppPageRequest request) {
              unawaited(_load(request));
            },
          );

    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.groups_outlined),
      maxWidth: 920,
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _searchController,
            semanticLabel: l10n.patientsSearchLabel,
            hintText: l10n.patientsSearchHint,
            prefixIcon: const Icon(Icons.search),
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (_) => _runSearchImmediately(),
          ),
          SizedBox(height: theme.spacing.md),
          list,
        ],
      ),
    );
  }

  void _handleSearchChanged() {
    final String value = _searchController.text.trim();
    if (value == _search) {
      return;
    }
    setState(() {
      _search = value;
    });

    if (widget.query == null) {
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        unawaited(_load(widget.query!.pageRequest.first()));
      }
    });
  }

  void _runSearchImmediately() {
    _searchDebounce?.cancel();
    final PatientListQuery? query = widget.query;
    if (query != null) {
      unawaited(_load(query.pageRequest.first()));
    }
  }

  Future<void> _load(AppPageRequest request) async {
    final PatientListQuery? query = widget.query;
    if (query == null) {
      return;
    }
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final Result<AppPage<Patient>> result = await ref
        .read(patientRegistryControllerProvider.notifier)
        .loadPatientPage(query.copyWith(search: _search, pageRequest: request));
    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<Patient> page) {
        setState(() {
          _page = page;
          _isLoading = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoading = false;
        });
      },
    );
  }

  List<Patient> _filterPatients(List<Patient> patients) {
    final String needle = _search.toLowerCase();
    if (needle.isEmpty) {
      return patients;
    }

    return patients
        .where((Patient patient) {
          return <String?>[
            patient.effectiveDisplayName,
            patient.effectiveIdentifier,
            patient.publicId,
            patient.primaryPhone,
            patient.primaryEmail,
            patient.facilityLabel,
          ].whereType<String>().any(
            (String value) => value.toLowerCase().contains(needle),
          );
        })
        .toList(growable: false);
  }
}

class _SummaryPatientList extends ConsumerWidget {
  const _SummaryPatientList({
    required this.page,
    required this.isLoading,
    required this.onPageChanged,
  });

  final AppPage<Patient> page;
  final bool isLoading;
  final ValueChanged<AppPageRequest>? onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);

    return AppPaginatedDataList<Patient>(
      page: page,
      isLoading: isLoading,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columns: <AppDataColumn<Patient>>[
        AppDataColumn<Patient>(
          label: l10n.patientsPatientColumnLabel,
          cellBuilder: (_, Patient patient) =>
              _PatientNameCell(patient: patient),
        ),
        AppDataColumn<Patient>(
          label: l10n.patientsIdentifierColumnLabel,
          cellBuilder: (_, Patient patient) =>
              Text(patient.effectiveIdentifier ?? l10n.profileUnknownValue),
        ),
        AppDataColumn<Patient>(
          label: l10n.patientsDobColumnLabel,
          cellBuilder: (_, Patient patient) => Text(
            patient.dateOfBirth == null
                ? l10n.profileUnknownValue
                : AppFormatters.mediumDate(patient.dateOfBirth!, locale),
          ),
        ),
      ],
      mobileItemBuilder: (_, Patient patient) => Padding(
        padding: EdgeInsets.all(Theme.of(context).spacing.md),
        child: _PatientMobileRow(patient: patient),
      ),
      itemKeyBuilder: (Patient patient) => ValueKey<String>(patient.id),
      onRowSelected: (Patient patient) async {
        await _openPatientDetail(context, ref, patient.id);
      },
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.patientsEmptyTitle,
        body: l10n.patientsEmptyBody,
        icon: Icons.person_search_outlined,
        minHeight: 240,
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
      onPageChanged: onPageChanged,
    );
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
        Text(patient.effectiveDisplayName, style: theme.textTheme.titleSmall),
        if (patient.facilityLabel != null)
          Text(
            patient.facilityLabel!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.account_circle_outlined,
          color: theme.colorScheme.primary,
          size: theme.appTokens.listIconSize,
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                patient.effectiveDisplayName,
                style: theme.textTheme.titleSmall,
              ),
              SizedBox(height: theme.spacing.xs),
              Text(patient.effectiveIdentifier ?? l10n.profileUnknownValue),
              if (patient.primaryPhone != null || patient.primaryEmail != null)
                Text(patient.primaryPhone ?? patient.primaryEmail!),
              SizedBox(height: theme.spacing.xs),
              _StatusText(isActive: patient.isActive),
            ],
          ),
        ),
        Icon(Icons.chevron_right, size: theme.appTokens.listIconSize),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final Color color = isActive
        ? theme.statusColors.success
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          isActive ? Icons.check_circle_outline : Icons.block_outlined,
          size: theme.appTokens.listIconSize,
          color: color,
        ),
        SizedBox(width: theme.spacing.xs),
        Flexible(
          child: Text(
            isActive ? l10n.patientsActiveFilter : l10n.patientsInactiveFilter,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
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
          _PatientDemographics(detail: detail),
          const Divider(),
          _QuickActions(patient: patient),
          const Divider(),
          _RelatedSection<PatientIdentifier>(
            title: l10n.patientsIdentifiersSectionTitle,
            emptyLabel: l10n.patientsNoIdentifiers,
            items: detail.identifiers,
            resource: PatientRelatedResource.identifier,
            itemTitle: (PatientIdentifier item) => item.value,
            itemSubtitle: (PatientIdentifier item) => item.type,
            onAdd: () =>
                _openRelatedForm<PatientIdentifier>(context, ref, detail),
            onEdit: (PatientIdentifier item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientIdentifier item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          _RelatedSection<PatientContact>(
            title: l10n.patientsContactsSectionTitle,
            emptyLabel: l10n.patientsNoContacts,
            items: detail.contacts,
            resource: PatientRelatedResource.contact,
            itemTitle: (PatientContact item) => item.value,
            itemSubtitle: (PatientContact item) => _apiLabel(item.type),
            onAdd: () => _openRelatedForm<PatientContact>(context, ref, detail),
            onEdit: (PatientContact item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientContact item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          _RelatedSection<PatientGuardian>(
            title: l10n.patientsGuardiansSectionTitle,
            emptyLabel: l10n.patientsNoGuardians,
            items: detail.guardians,
            resource: PatientRelatedResource.guardian,
            itemTitle: (PatientGuardian item) => item.name,
            itemSubtitle: (PatientGuardian item) =>
                item.relationship ?? l10n.profileUnknownValue,
            onAdd: () =>
                _openRelatedForm<PatientGuardian>(context, ref, detail),
            onEdit: (PatientGuardian item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientGuardian item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          _RelatedSection<PatientAllergy>(
            title: l10n.patientsAllergiesSectionTitle,
            emptyLabel: l10n.patientsNoAllergies,
            items: detail.allergies,
            resource: PatientRelatedResource.allergy,
            itemTitle: (PatientAllergy item) => item.allergen,
            itemSubtitle: (PatientAllergy item) => _apiLabel(item.severity),
            onAdd: () => _openRelatedForm<PatientAllergy>(context, ref, detail),
            onEdit: (PatientAllergy item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientAllergy item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          _RelatedSection<PatientMedicalHistory>(
            title: l10n.patientsMedicalHistorySectionTitle,
            emptyLabel: l10n.patientsNoMedicalHistory,
            items: detail.medicalHistories,
            resource: PatientRelatedResource.medicalHistory,
            itemTitle: (PatientMedicalHistory item) => item.condition,
            itemSubtitle: (PatientMedicalHistory item) =>
                _formatOptionalDate(context, item.diagnosisDate),
            onAdd: () =>
                _openRelatedForm<PatientMedicalHistory>(context, ref, detail),
            onEdit: (PatientMedicalHistory item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientMedicalHistory item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          _RelatedSection<PatientDocument>(
            title: l10n.patientsDocumentsSectionTitle,
            emptyLabel: l10n.patientsNoDocuments,
            items: detail.documents,
            resource: PatientRelatedResource.document,
            itemTitle: (PatientDocument item) =>
                item.fileName ?? item.documentType,
            itemSubtitle: (PatientDocument item) =>
                _apiLabel(item.documentType),
            onAdd: () =>
                _openRelatedForm<PatientDocument>(context, ref, detail),
            onEdit: (PatientDocument item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientDocument item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          _RelatedSection<PatientConsent>(
            title: l10n.patientsConsentsSectionTitle,
            emptyLabel: l10n.patientsNoConsents,
            items: detail.consents,
            resource: PatientRelatedResource.consent,
            itemTitle: (PatientConsent item) => _apiLabel(item.consentType),
            itemSubtitle: (PatientConsent item) => _apiLabel(item.status),
            onAdd: () => _openRelatedForm<PatientConsent>(context, ref, detail),
            onEdit: (PatientConsent item) =>
                _openRelatedForm(context, ref, detail, item: item),
            onDelete: (PatientConsent item) =>
                _confirmDeleteRelated(context, ref, detail, item.id),
          ),
          _TimelineList(items: detail.timeline),
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

class _PatientDemographics extends StatelessWidget {
  const _PatientDemographics({required this.detail});

  final PatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final Patient patient = detail.patient;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _InfoRow(
          label: l10n.patientsNameLabel,
          value: patient.effectiveDisplayName,
        ),
        _InfoRow(
          label: l10n.patientsIdentifierLabel,
          value: patient.effectiveIdentifier,
        ),
        _InfoRow(
          label: l10n.patientsDobLabel,
          value: _formatOptionalDate(context, patient.dateOfBirth),
        ),
        _InfoRow(
          label: l10n.patientsGenderLabel,
          value: patient.gender == null
              ? null
              : _genderLabel(l10n, patient.gender!),
        ),
        _InfoRow(label: l10n.patientsPhoneLabel, value: patient.primaryPhone),
        _InfoRow(label: l10n.patientsEmailLabel, value: patient.primaryEmail),
        _InfoRow(
          label: l10n.patientsFacilityLabel,
          value: patient.facilityLabel,
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.patientsQuickActionsTitle, style: theme.textTheme.titleSmall),
        SizedBox(height: theme.spacing.sm),
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            _QuickActionButton(
              label: l10n.patientsQuickAppointmentAction,
              icon: Icons.event_available_outlined,
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.patientWrite],
              ),
            ),
            _QuickActionButton(
              label: l10n.patientsQuickTriageAction,
              icon: Icons.monitor_heart_outlined,
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.emergencyWrite],
              ),
            ),
            _QuickActionButton(
              label: l10n.patientsQuickClinicalAction,
              icon: Icons.medical_services_outlined,
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
              ),
            ),
            _QuickActionButton(
              label: l10n.patientsQuickBillingAction,
              icon: Icons.receipt_long_outlined,
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.billingWrite],
              ),
            ),
            _QuickActionButton(
              label: l10n.patientsQuickAdmissionAction,
              icon: Icons.local_hospital_outlined,
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.requirement,
  });

  final String label;
  final IconData icon;
  final AccessRequirement requirement;

  @override
  Widget build(BuildContext context) {
    return AppAccessActionGate(
      requirement: requirement,
      builder: (_, bool isAllowed) => AppButton.secondary(
        leadingIcon: icon,
        label: label,
        enabled: isAllowed,
        onPressed: isAllowed
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.patientsQuickActionQueuedMessage,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }
}

class _RelatedSection<T> extends StatelessWidget {
  const _RelatedSection({
    required this.title,
    required this.emptyLabel,
    required this.items,
    required this.resource,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String emptyLabel;
  final List<T> items;
  final PatientRelatedResource resource;
  final String Function(T item) itemTitle;
  final String Function(T item) itemSubtitle;
  final VoidCallback onAdd;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;

  static const AccessRequirement _writeRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientWrite],
  );
  static const AccessRequirement _deleteRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientDelete],
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(bottom: theme.spacing.sm),
      title: Text(title, style: theme.textTheme.titleSmall),
      trailing: AppAccessActionGate(
        requirement: _writeRequirement,
        builder: (_, bool isAllowed) => AppIconButton(
          icon: Icons.add,
          semanticLabel: l10n.patientsAddRelatedAction,
          tooltip: l10n.patientsAddRelatedAction,
          onPressed: isAllowed ? onAdd : null,
        ),
      ),
      children: <Widget>[
        if (items.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final T item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(itemTitle(item)),
              subtitle: Text(itemSubtitle(item)),
              trailing: Wrap(
                children: <Widget>[
                  AppAccessActionGate(
                    requirement: _writeRequirement,
                    builder: (_, bool isAllowed) => AppIconButton(
                      icon: Icons.edit_outlined,
                      semanticLabel: l10n.patientsEditAction,
                      tooltip: l10n.patientsEditAction,
                      onPressed: isAllowed ? () => onEdit(item) : null,
                    ),
                  ),
                  AppAccessActionGate(
                    requirement: _deleteRequirement,
                    builder: (_, bool isAllowed) => AppIconButton(
                      icon: Icons.delete_outline,
                      semanticLabel: l10n.patientsDeleteAction,
                      tooltip: l10n.patientsDeleteAction,
                      onPressed: isAllowed ? () => onDelete(item) : null,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.items});

  final List<PatientTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        l10n.patientsTimelineSectionTitle,
        style: theme.textTheme.titleSmall,
      ),
      children: <Widget>[
        if (items.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(l10n.patientsNoTimeline),
          )
        else
          for (final PatientTimelineItem item in items.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_outlined),
              title: Text(item.title ?? _apiLabel(item.resource)),
              subtitle: Text(
                _joinDisplay(<String?>[
                  _apiLabel(item.resource),
                  _formatOptionalDateTime(context, item.occurredAt),
                ]),
              ),
            ),
      ],
    );
  }
}

class _PatientActivityPanel extends StatelessWidget {
  const _PatientActivityPanel({required this.state});

  final PatientRegistryState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<AppWorkspaceActivityItem> items = <AppWorkspaceActivityItem>[
      for (final PatientDuplicateCandidate duplicate
          in state.overview.duplicates.take(3))
        AppWorkspaceActivityItem(
          title: l10n.patientsDuplicateActivityTitle,
          subtitle: l10n.patientsDuplicateActivitySubtitle(
            duplicate.confidenceScore,
          ),
          description:
              duplicate.secondaryPatient?.effectiveDisplayName ??
              duplicate.candidatePatient?.effectiveDisplayName,
          icon: Icons.content_copy_outlined,
          tone: AppWorkspaceStatusTone.warning,
        ),
      if (state.overview.consentExceptions > 0)
        AppWorkspaceActivityItem(
          title: l10n.patientsConsentActivityTitle,
          subtitle: l10n.patientsConsentActivitySubtitle(
            state.overview.consentExceptions,
          ),
          icon: Icons.assignment_late_outlined,
          tone: AppWorkspaceStatusTone.warning,
        ),
      if (state.overview.missingDocuments > 0)
        AppWorkspaceActivityItem(
          title: l10n.patientsDocumentsActivityTitle,
          subtitle: l10n.patientsDocumentsActivitySubtitle(
            state.overview.missingDocuments,
          ),
          icon: Icons.description_outlined,
          tone: AppWorkspaceStatusTone.info,
        ),
    ];

    return AppWorkspaceActivityList(
      title: l10n.patientsActivityTitle,
      description: l10n.patientsActivityBody,
      emptyTitle: l10n.patientsActivityEmptyTitle,
      emptyBody: l10n.patientsActivityEmptyBody,
      items: items,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(value ?? l10n.profileUnknownValue)),
        ],
      ),
    );
  }
}

class PatientFormDialog extends StatefulWidget {
  const PatientFormDialog({
    required this.referenceData,
    required this.onSubmit,
    this.patient,
    super.key,
  });

  final Patient? patient;
  final PatientReferenceData referenceData;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

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
  }

  @override
  void dispose() {
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
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _firstNameController,
              labelText: l10n.patientsFirstNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _lastNameController,
              labelText: l10n.patientsLastNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppDateField(
              value: _dateOfBirth,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              labelText: l10n.patientsDobLabel,
              hintText: l10n.appDateFormatHint,
              enabled: !_isSaving,
              onChanged: (DateTime? value) {
                _dateOfBirth = value;
              },
            ),
            AppGenderField(
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
            if (widget.referenceData.facilities.isNotEmpty)
              AppSelectField<String>(
                value: _facilityId,
                labelText: l10n.patientsFacilityLabel,
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _facilityId = value;
                  });
                },
                options: <AppSelectOption<String>>[
                  for (final PatientReferenceOption option
                      in widget.referenceData.facilities)
                    AppSelectOption<String>(
                      value: option.id,
                      label: option.label,
                    ),
                ],
              ),
            AppPhoneField(
              controller: _phoneController,
              labelText: l10n.patientsPhoneLabel,
              countryLabelText: l10n.appPhoneCountryLabel,
              numberLabelText: l10n.appPhoneNumberLabel,
              invalidPhoneMessage: l10n.appPhoneInvalidMessage,
              enabled: !_isSaving,
            ),
            AppEmailField(
              controller: _emailController,
              labelText: l10n.patientsEmailLabel,
              invalidEmailMessage: l10n.authEmailInvalidMessage,
              enabled: !_isSaving,
            ),
            _ResponsiveFieldPair(
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
                options: <AppSelectOption<String>>[
                  for (final String value in _identifierTypeOptions(
                    _identifierTypeController.text,
                  ))
                    AppSelectOption<String>(
                      value: value,
                      label: _apiLabel(value),
                    ),
                ],
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
          label: l10n.patientsSaveAction,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
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
}

class _ResponsiveFieldPair extends StatelessWidget {
  const _ResponsiveFieldPair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              left,
              SizedBox(height: theme.spacing.sm),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            SizedBox(width: theme.spacing.sm),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class PatientRelatedRecordDialog<T> extends StatefulWidget {
  const PatientRelatedRecordDialog({
    required this.detail,
    required this.resource,
    required this.referenceData,
    required this.onCreate,
    required this.onUpdate,
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
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            ..._fieldsForResource(context),
          ],
        ),
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
        AppTextField(
          controller: _first,
          labelText: l10n.patientsIdentifierTypeLabel,
          enabled: !_isSaving,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.validationRequired),
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
        AppSelectField<String>(
          value: _choice,
          labelText: l10n.patientsContactTypeLabel,
          enabled: !_isSaving,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onChanged: (String? value) => setState(() => _choice = value),
          options: <AppSelectOption<String>>[
            for (final String value in _contactTypes)
              AppSelectOption<String>(value: value, label: _apiLabel(value)),
          ],
        ),
        AppTextField(
          controller: _first,
          labelText: l10n.patientsContactValueLabel,
          enabled: !_isSaving,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
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
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppTextField(
          controller: _second,
          labelText: l10n.patientsGuardianRelationshipLabel,
          enabled: !_isSaving,
        ),
        AppPhoneField(
          controller: _third,
          labelText: l10n.patientsPhoneLabel,
          countryLabelText: l10n.appPhoneCountryLabel,
          numberLabelText: l10n.appPhoneNumberLabel,
          invalidPhoneMessage: l10n.appPhoneInvalidMessage,
          enabled: !_isSaving,
        ),
        AppEmailField(
          controller: _fourth,
          labelText: l10n.patientsEmailLabel,
          invalidEmailMessage: l10n.authEmailInvalidMessage,
          enabled: !_isSaving,
        ),
      ],
      PatientRelatedResource.allergy => <Widget>[
        AppTextField(
          controller: _first,
          labelText: l10n.patientsAllergenLabel,
          enabled: !_isSaving,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppSelectField<String>(
          value: _choice,
          labelText: l10n.patientsSeverityLabel,
          enabled: !_isSaving,
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
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppDateField(
          value: _date,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          pickerButtonLabel: l10n.patientsDatePickerAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          labelText: l10n.patientsDiagnosisDateLabel,
          hintText: l10n.appDateFormatHint,
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
        AppSelectField<String>(
          value: _choice,
          labelText: l10n.patientsDocumentTypeLabel,
          enabled: !_isSaving,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onChanged: (String? value) => setState(() => _choice = value),
          options: <AppSelectOption<String>>[
            for (final String value
                in widget.referenceData.documentTypes.isEmpty
                    ? _documentTypes
                    : widget.referenceData.documentTypes)
              AppSelectOption<String>(value: value, label: _apiLabel(value)),
          ],
        ),
        AppTextField(
          controller: _first,
          labelText: l10n.patientsStorageKeyLabel,
          enabled: !_isSaving,
          validator: AppValidators.requiredText(l10n.validationRequired),
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
        AppSelectField<String>(
          value: _choice,
          labelText: l10n.patientsConsentTypeLabel,
          enabled: !_isSaving,
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onChanged: (String? value) => setState(() => _choice = value),
          options: <AppSelectOption<String>>[
            for (final String value
                in widget.referenceData.consentTypes.isEmpty
                    ? _consentTypes
                    : widget.referenceData.consentTypes)
              AppSelectOption<String>(value: value, label: _apiLabel(value)),
          ],
        ),
        AppSelectField<String>(
          value: _first.text.isEmpty ? null : _first.text,
          labelText: l10n.patientsConsentStatusLabel,
          enabled: !_isSaving,
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
        AppDateField(
          value: _date,
          firstDate: DateTime(1900),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          pickerButtonLabel: l10n.patientsDatePickerAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          labelText: l10n.patientsConsentDateLabel,
          hintText: l10n.appDateFormatHint,
          enabled: !_isSaving,
          onChanged: (DateTime? value) => _date = value,
        ),
      ],
    };
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

    final Map<String, Object?> payload = _payload();
    final String? recordId = _recordId(widget.item);
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

  Map<String, Object?> _payload() {
    final Patient patient = widget.detail.patient;
    final Map<String, Object?> createContext = <String, Object?>{
      'tenant_id': patient.tenantId,
      'patient_id': patient.id,
    };

    return switch (widget.resource) {
      PatientRelatedResource.identifier => <String, Object?>{
        ...createContext,
        'identifier_type': _first.text.trim(),
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
        'relationship': _second.text.trim(),
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

List<Patient> _patientsFromDuplicates(
  List<PatientDuplicateCandidate> duplicates,
) {
  final Map<String, Patient> patients = <String, Patient>{};
  for (final PatientDuplicateCandidate duplicate in duplicates) {
    for (final Patient? patient in <Patient?>[
      duplicate.primaryPatient,
      duplicate.secondaryPatient,
      duplicate.candidatePatient,
    ]) {
      if (patient != null && patient.id.isNotEmpty) {
        patients[patient.id] = patient;
      }
    }
  }

  return patients.values.toList(growable: false);
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

String _apiLabel(String value) {
  return value
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

List<String> _identifierTypeOptions(String currentValue) {
  final String normalized = currentValue.trim().toUpperCase();
  if (normalized.isEmpty || _identifierTypes.contains(normalized)) {
    return _identifierTypes;
  }

  return <String>[normalized, ..._identifierTypes];
}

String? _selectedIdentifierType(String currentValue) {
  final String normalized = currentValue.trim().toUpperCase();
  return normalized.isEmpty ? null : normalized;
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty && value != 'null')
      .join(' - ');
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
  'FAX',
  'OTHER',
];
const List<String> _severityOptions = <String>['MILD', 'MODERATE', 'SEVERE'];
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
const String _statusActive = 'active';
const String _statusInactive = 'inactive';

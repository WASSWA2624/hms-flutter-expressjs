import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/platform/app_print.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
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
  late final ValueNotifier<String> _tableSearchNotifier;
  Timer? _tableSearchDebounce;

  @override
  void initState() {
    super.initState();
    _tableSearchController = TextEditingController(
      text: widget.state.query.search,
    );
    _tableSearchNotifier = ValueNotifier<String>(widget.state.query.search);
    _tableSearchController.addListener(_handleTableSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _PatientRegistryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextSearch = widget.state.query.search;
    if (oldWidget.state.query.search != nextSearch &&
        _tableSearchController.text != nextSearch) {
      _tableSearchController.text = nextSearch;
      _tableSearchNotifier.value = nextSearch;
    }
  }

  @override
  void dispose() {
    _tableSearchDebounce?.cancel();
    _tableSearchController
      ..removeListener(_handleTableSearchChanged)
      ..dispose();
    _tableSearchNotifier.dispose();
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
      description: '',
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
        AppWorkspaceSummaryCard(
          label: l10n.patientsTotalSummaryLabel,
          value: AppFormatters.compactNumber(
            widget.state.overview.totalPatients,
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
            widget.state.overview.activePatients,
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
            widget.state.overview.waitingQueue,
            Localizations.localeOf(context),
          ),
          icon: Icons.queue_outlined,
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              ref,
              title: l10n.patientsQueueSummaryLabel,
              patients: widget.state.overview.waitingQueuePatients,
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.patientsDuplicateSummaryLabel,
          value: AppFormatters.compactNumber(
            widget.state.overview.duplicates.length,
            Localizations.localeOf(context),
          ),
          icon: Icons.content_copy_outlined,
          compact: true,
          onPressed: () {
            _openDuplicateReview(context, ref);
          },
        ),
      ],
      filters: _PatientFilters(
        query: widget.state.query,
        searchController: _tableSearchController,
      ),
      body: _PatientList(
        state: widget.state,
        searchListenable: _tableSearchNotifier,
      ),
      activity: _PatientActivityPanel(state: widget.state),
    );
  }

  void _handleTableSearchChanged() {
    final String query = _tableSearchController.text;
    if (_tableSearchNotifier.value == query) {
      return;
    }

    _tableSearchNotifier.value = query;
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

  Future<void> _openDuplicateReview(BuildContext context, WidgetRef ref) async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => PatientDuplicateReviewDialog(
        duplicates: widget.state.overview.duplicates,
      ),
    );
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
  const _PatientFilters({required this.query, required this.searchController});

  final PatientListQuery query;
  final TextEditingController searchController;

  @override
  ConsumerState<_PatientFilters> createState() => _PatientFiltersState();
}

class _PatientFiltersState extends ConsumerState<_PatientFilters> {
  late final TextEditingController _patientIdController;
  String? _gender;
  String? _status;
  String? _consentState;

  @override
  void initState() {
    super.initState();
    _patientIdController = TextEditingController(text: widget.query.patientId);
    _gender = widget.query.gender;
    _status = _statusValue(widget.query.isActive);
    _consentState = widget.query.consentState;
  }

  @override
  void didUpdateWidget(covariant _PatientFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _patientIdController.text = widget.query.patientId;
      _gender = widget.query.gender;
      _status = _statusValue(widget.query.isActive);
      _consentState = widget.query.consentState;
    }
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppWorkspaceFilterBar(
      semanticLabel: l10n.patientsFiltersLabel,
      expandSearch: true,
      search: _buildSearchField(context),
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
        if (_hasAdvancedFilters)
          AppIconButton(
            icon: Icons.filter_alt_off_outlined,
            semanticLabel: l10n.patientsClearFiltersAction,
            tooltip: l10n.patientsClearFiltersAction,
            onPressed: _clear,
          ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final l10n = context.l10n;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.searchController,
      builder: (BuildContext context, TextEditingValue value, _) {
        final bool canClear = value.text.isNotEmpty;

        return AppTextField(
          controller: widget.searchController,
          semanticLabel: l10n.patientsSearchLabel,
          hintText: l10n.patientsSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: canClear
              ? AppIconButton(
                  icon: Icons.close,
                  semanticLabel: l10n.patientsClearFiltersAction,
                  tooltip: l10n.patientsClearFiltersAction,
                  onPressed: widget.searchController.clear,
                )
              : null,
          textInputAction: TextInputAction.search,
        );
      },
    );
  }

  bool get _hasAdvancedFilters {
    return _patientIdController.text.trim().isNotEmpty ||
        _gender != null ||
        _status != null ||
        _consentState != null;
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
      search: widget.searchController.text.trim(),
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
    widget.searchController.clear();
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
  const _PatientList({required this.state, required this.searchListenable});

  final PatientRegistryState state;
  final ValueListenable<String> searchListenable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);

    return AppSearchablePaginatedDataList<Patient>(
      page: state.page,
      searchListenable: searchListenable,
      searchMatcher: (Patient patient, String query) {
        return _matchesPatientTableSearch(context, patient, query);
      },
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
        if (patient.requiresCompletion)
          Text(
            context.l10n.patientsRegistrationIncompleteValue,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.statusColors.warning,
              fontWeight: FontWeight.w700,
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
              if (patient.requiresCompletion)
                Text(
                  l10n.patientsRegistrationIncompleteValue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.statusColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
        if (patient.requiresCompletion)
          _InfoRow(
            label: l10n.patientsRegistrationStatusLabel,
            value: l10n.patientsRegistrationIncompleteValue,
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
            _QuickActionButton(
              label: l10n.patientsQuickOpdCheckInAction,
              icon: Icons.login_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.opdCheckIn,
              ),
              requirement: const AccessRequirement(
                anyPermissions: <AppPermission>[
                  AppPermissions.patientWrite,
                  AppPermissions.emergencyWrite,
                ],
              ),
            ),
            _QuickActionButton(
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
            _QuickActionButton(
              label: l10n.patientsQuickClinicalAction,
              icon: Icons.medical_services_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.clinicalVisit,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
              ),
            ),
            _QuickActionButton(
              label: l10n.patientsQuickBillingAction,
              icon: Icons.receipt_long_outlined,
              onPressed: () => _openQuickAction(
                context,
                ref,
                patient,
                _PatientQuickAction.billing,
              ),
              requirement: const AccessRequirement(
                allPermissions: <AppPermission>[AppPermissions.billingWrite],
              ),
            ),
            _QuickActionButton(
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
            _QuickActionButton(
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
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final AccessRequirement requirement;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppAccessActionGate(
      requirement: requirement,
      builder: (_, bool isAllowed) => AppButton.secondary(
        leadingIcon: icon,
        label: label,
        enabled: isAllowed,
        onPressed: isAllowed ? onPressed : null,
      ),
    );
  }
}

enum _PatientQuickAction {
  appointment,
  opdCheckIn,
  triage,
  clinicalVisit,
  billing,
  admission,
  report,
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

  final bool? changed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return switch (action) {
        _PatientQuickAction.appointment => _PatientAppointmentQuickDialog(
          patient: patient,
          referenceData: referenceData,
        ),
        _PatientQuickAction.report => _PatientReportDialog(
          detail: detail,
          patient: patient,
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

class _PatientAppointmentQuickDialog extends ConsumerStatefulWidget {
  const _PatientAppointmentQuickDialog({
    required this.patient,
    required this.referenceData,
  });

  final Patient patient;
  final PatientReferenceData referenceData;

  @override
  ConsumerState<_PatientAppointmentQuickDialog> createState() =>
      _PatientAppointmentQuickDialogState();
}

class _PatientAppointmentQuickDialogState
    extends ConsumerState<_PatientAppointmentQuickDialog> {
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
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            if (widget.referenceData.facilities.length > 1)
              _facilitySelect(context),
            _ResponsiveFieldPair(
              left: AppDateField(
                value: _date,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                pickerButtonLabel: l10n.patientsDatePickerAction,
                invalidDateMessage: l10n.appDateInvalidMessage,
                labelText: l10n.patientsAppointmentDateLabel,
                isRequired: true,
                enabled: !_isSaving,
                validator: AppValidators.requiredValue(l10n.validationRequired),
                onChanged: (DateTime? value) => _date = value,
              ),
              right: AppTextField(
                controller: _timeController,
                labelText: l10n.patientsAppointmentTimeLabel,
                hintText: l10n.patientsTimeHint,
                enabled: !_isSaving,
                isRequired: true,
                keyboardType: TextInputType.datetime,
                validator: _timeValidator(context),
              ),
            ),
            _ResponsiveFieldPair(
              left: AppTextField(
                controller: _durationController,
                labelText: l10n.patientsAppointmentDurationLabel,
                enabled: !_isSaving,
                isRequired: true,
                keyboardType: TextInputType.number,
                validator: _durationValidator(context),
              ),
              right: AppSelectField<String>.searchable(
                value: _status,
                labelText: l10n.patientsAppointmentStatusLabel,
                enabled: !_isSaving,
                onChanged: (String? value) =>
                    setState(() => _status = value ?? 'SCHEDULED'),
                options: _simpleStatusOptions(const <String>[
                  'SCHEDULED',
                  'CONFIRMED',
                ]),
              ),
            ),
            _providerSelect(context),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.patientsAppointmentReasonLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
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

  Widget _facilitySelect(BuildContext context) {
    return AppSelectField<String>.searchable(
      value: _facilityId,
      labelText: context.l10n.patientsFacilityLabel,
      enabled: !_isSaving,
      onChanged: (String? value) => setState(() => _facilityId = value),
      options: <AppSelectOption<String>>[
        for (final PatientReferenceOption option
            in widget.referenceData.facilities)
          AppSelectOption<String>(
            value: option.id,
            label: option.label,
            leadingIcon: const Icon(Icons.business_outlined),
          ),
      ],
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
    if (!(_formKey.currentState?.validate() ?? false)) {
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
  final TextEditingController _chiefComplaintController =
      TextEditingController();
  final TextEditingController _clinicalNoteController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _transactionRefController =
      TextEditingController();
  String? _facilityId;
  String? _providerId;
  String _arrivalMode = 'WALK_IN';
  String _emergencySeverity = 'HIGH';
  String? _triageLevel;
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
    if (widget.action == _PatientQuickAction.triage) {
      _arrivalMode = 'EMERGENCY';
    }
    unawaited(_loadProviders());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _chiefComplaintController.dispose();
    _clinicalNoteController.dispose();
    _diagnosisController.dispose();
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
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            if (widget.referenceData.facilities.length > 1)
              _facilitySelect(context),
            if (_usesProvider) _providerSelect(context),
            ..._modeFields(context),
            AppTextField(
              controller: _notesController,
              labelText: l10n.patientsNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
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
      _PatientQuickAction.opdCheckIn => Icons.login_outlined,
      _PatientQuickAction.triage => Icons.monitor_heart_outlined,
      _PatientQuickAction.clinicalVisit => Icons.medical_services_outlined,
      _PatientQuickAction.billing => Icons.receipt_long_outlined,
      _PatientQuickAction.admission => Icons.local_hospital_outlined,
      _ => Icons.play_arrow_outlined,
    };
  }

  String _dialogTitle(AppLocalizations l10n) {
    return switch (widget.action) {
      _PatientQuickAction.opdCheckIn => l10n.patientsOpdCheckInDialogTitle,
      _PatientQuickAction.triage => l10n.patientsTriageDialogTitle,
      _PatientQuickAction.clinicalVisit => l10n.patientsClinicalDialogTitle,
      _PatientQuickAction.billing => l10n.patientsBillingDialogTitle,
      _PatientQuickAction.admission => l10n.patientsAdmissionDialogTitle,
      _ => l10n.patientsQuickActionsTitle,
    };
  }

  String _primaryActionLabel(AppLocalizations l10n) {
    return switch (widget.action) {
      _PatientQuickAction.opdCheckIn => l10n.patientsQuickOpdCheckInAction,
      _PatientQuickAction.triage => l10n.patientsQuickTriageAction,
      _PatientQuickAction.clinicalVisit => l10n.patientsQuickClinicalAction,
      _PatientQuickAction.billing => l10n.patientsQuickBillingAction,
      _PatientQuickAction.admission => l10n.patientsQuickAdmissionAction,
      _ => l10n.patientsSaveAction,
    };
  }

  List<Widget> _modeFields(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.action) {
      _PatientQuickAction.opdCheckIn => <Widget>[
        AppSelectField<String>.searchable(
          value: _arrivalMode,
          labelText: l10n.patientsArrivalModeLabel,
          enabled: !_isSaving,
          onChanged: (String? value) =>
              setState(() => _arrivalMode = value ?? 'WALK_IN'),
          options: _simpleStatusOptions(const <String>['WALK_IN', 'EMERGENCY']),
        ),
        if (_arrivalMode == 'EMERGENCY') _emergencyFields(context),
        _consultationFeeField(context, required: false),
      ],
      _PatientQuickAction.triage => <Widget>[
        _emergencyFields(context),
        AppTextField(
          controller: _chiefComplaintController,
          labelText: l10n.patientsChiefComplaintLabel,
          enabled: !_isSaving,
          maxLines: 3,
        ),
      ],
      _PatientQuickAction.clinicalVisit => <Widget>[
        AppTextField(
          controller: _clinicalNoteController,
          labelText: l10n.patientsClinicalNoteLabel,
          enabled: !_isSaving,
          isRequired: true,
          maxLines: 4,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
        AppTextField(
          controller: _diagnosisController,
          labelText: l10n.patientsDiagnosisLabel,
          enabled: !_isSaving,
          maxLines: 2,
        ),
      ],
      _PatientQuickAction.billing => <Widget>[
        _consultationFeeField(context, required: true),
        AppCheckboxField(
          title: l10n.patientsMarkPaymentReceivedLabel,
          value: _markPaid,
          enabled: !_isSaving,
          onChanged: (bool value) => setState(() => _markPaid = value),
        ),
        if (_markPaid)
          _ResponsiveFieldPair(
            left: AppSelectField<String>.searchable(
              value: _paymentMethod,
              labelText: l10n.patientsPaymentMethodLabel,
              enabled: !_isSaving,
              onChanged: (String? value) =>
                  setState(() => _paymentMethod = value ?? 'CASH'),
              options: _simpleStatusOptions(_paymentMethods),
            ),
            right: AppTextField(
              controller: _transactionRefController,
              labelText: l10n.patientsTransactionReferenceLabel,
              enabled: !_isSaving,
            ),
          ),
      ],
      _PatientQuickAction.admission => <Widget>[
        AppTextField(
          controller: _clinicalNoteController,
          labelText: l10n.patientsAdmissionReasonLabel,
          enabled: !_isSaving,
          isRequired: true,
          maxLines: 4,
          validator: AppValidators.requiredText(l10n.validationRequired),
        ),
      ],
      _ => const <Widget>[],
    };
  }

  Widget _emergencyFields(BuildContext context) {
    final l10n = context.l10n;
    return _ResponsiveFieldPair(
      left: AppSelectField<String>.searchable(
        value: _emergencySeverity,
        labelText: l10n.patientsEmergencySeverityLabel,
        enabled: !_isSaving,
        onChanged: (String? value) =>
            setState(() => _emergencySeverity = value ?? 'HIGH'),
        options: _simpleStatusOptions(_emergencySeverityOptions),
      ),
      right: AppSelectField<String>.searchable(
        value: _triageLevel,
        labelText: l10n.patientsTriageLevelLabel,
        enabled: !_isSaving,
        onChanged: (String? value) => setState(() => _triageLevel = value),
        options: _simpleStatusOptions(_triageLevelOptions),
      ),
    );
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
    return AppSelectField<String>.searchable(
      value: _facilityId,
      labelText: context.l10n.patientsFacilityLabel,
      enabled: !_isSaving,
      onChanged: (String? value) => setState(() => _facilityId = value),
      options: <AppSelectOption<String>>[
        for (final PatientReferenceOption option
            in widget.referenceData.facilities)
          AppSelectOption<String>(
            value: option.id,
            label: option.label,
            leadingIcon: const Icon(Icons.business_outlined),
          ),
      ],
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final AppFailure? failure = await (switch (widget.action) {
      _PatientQuickAction.opdCheckIn => _submitOpdCheckIn(),
      _PatientQuickAction.triage => _submitTriage(),
      _PatientQuickAction.clinicalVisit => _submitClinicalVisit(),
      _PatientQuickAction.billing => _submitBilling(),
      _PatientQuickAction.admission => _submitAdmission(),
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

  Future<AppFailure?> _submitOpdCheckIn() {
    final String amount = normalizeCurrencyAmount(_feeController.text);
    return _startFlow(<String, Object?>{
      'arrival_mode': _arrivalMode,
      if (_arrivalMode == 'EMERGENCY') 'emergency': _emergencyPayload(),
      if (amount.isNotEmpty) 'consultation_fee': amount,
      if (amount.isNotEmpty) 'currency': _currency,
      if (amount.isNotEmpty) 'create_consultation_invoice': true,
      if (amount.isNotEmpty) 'require_consultation_payment': true,
    });
  }

  Future<AppFailure?> _submitTriage() {
    return _startFlow(<String, Object?>{
      'arrival_mode': 'EMERGENCY',
      'emergency': _emergencyPayload(),
      'initial_stage': 'WAITING_VITALS',
      'notes': _chiefComplaintController.text.trim(),
    });
  }

  Future<AppFailure?> _submitClinicalVisit() async {
    final Result<OpdFlowDetail> flowResult = await ref
        .read(opdRepositoryProvider)
        .startOpdFlow(
          _baseFlowPayload(<String, Object?>{
            'arrival_mode': 'WALK_IN',
            'initial_stage': 'WAITING_DOCTOR_REVIEW',
            'require_consultation_payment': false,
            'create_consultation_invoice': false,
          }),
        );
    final OpdFlowDetail? flow = _successOrNull(flowResult);
    if (flow == null) {
      return _failureOrNull(flowResult);
    }

    final Result<OpdFlowDetail> reviewResult = await ref
        .read(opdRepositoryProvider)
        .doctorReview(
          flow.summary.apiId,
          _withoutEmptyPayload(<String, Object?>{
            'note': _clinicalNoteController.text.trim(),
            if (_diagnosisController.text.trim().isNotEmpty)
              'diagnoses': <Map<String, Object?>>[
                <String, Object?>{
                  'diagnosis_type': 'PRIMARY',
                  'description': _diagnosisController.text.trim(),
                },
              ],
            'notes': _notesController.text.trim(),
          }),
        );
    return _failureOrNull(reviewResult);
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

  Future<AppFailure?> _submitAdmission() async {
    final Result<OpdFlowDetail> flowResult = await ref
        .read(opdRepositoryProvider)
        .startOpdFlow(
          _baseFlowPayload(<String, Object?>{
            'arrival_mode': 'WALK_IN',
            'initial_stage': 'WAITING_DOCTOR_REVIEW',
            'require_consultation_payment': false,
            'create_consultation_invoice': false,
          }),
        );
    final OpdFlowDetail? flow = _successOrNull(flowResult);
    if (flow == null) {
      return _failureOrNull(flowResult);
    }

    final Result<OpdFlowDetail> reviewResult = await ref
        .read(opdRepositoryProvider)
        .doctorReview(flow.summary.apiId, <String, Object?>{
          'note': _clinicalNoteController.text.trim(),
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
            'notes': _notesController.text.trim(),
          }),
        );
    return _failureOrNull(dispositionResult);
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

  Map<String, Object?> _emergencyPayload() {
    return _withoutEmptyPayload(<String, Object?>{
      'severity': _emergencySeverity,
      'triage_level': _triageLevel,
      'notes': _notesController.text.trim(),
    });
  }
}

class _PatientReportDialog extends StatelessWidget {
  const _PatientReportDialog({required this.patient, this.detail});

  final Patient patient;
  final PatientDetail? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final PatientWorkspaceSnapshot? workspace = detail?.workspace;

    return AppDialog(
      title: Text(l10n.patientsReportDialogTitle),
      icon: const Icon(Icons.summarize_outlined),
      scrollable: true,
      maxWidth: 760,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PatientDemographics(
            detail:
                detail ??
                PatientDetail(
                  patient: patient,
                  workspace: const PatientWorkspaceSnapshot(),
                ),
          ),
          SizedBox(height: theme.spacing.md),
          _ReportSummaryGrid(
            records: <_ReportSummaryItem>[
              _ReportSummaryItem(
                label: l10n.patientsAppointmentsSectionTitle,
                value: workspace?.appointments.length ?? 0,
                icon: Icons.event_available_outlined,
              ),
              _ReportSummaryItem(
                label: l10n.patientsEncountersSectionTitle,
                value: workspace?.encounters.length ?? 0,
                icon: Icons.medical_services_outlined,
              ),
              _ReportSummaryItem(
                label: l10n.patientsAdmissionsSectionTitle,
                value: workspace?.admissions.length ?? 0,
                icon: Icons.local_hospital_outlined,
              ),
              _ReportSummaryItem(
                label: l10n.patientsInvoicesSectionTitle,
                value: workspace?.invoices.length ?? 0,
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.patientsTimelineSectionTitle,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.xs),
          if ((detail?.timeline ?? const <PatientTimelineItem>[]).isEmpty)
            Text(l10n.patientsNoTimeline)
          else
            for (final PatientTimelineItem item in detail!.timeline.take(8))
              _InfoRow(
                label: _apiLabel(item.resource),
                value: _joinDisplay(<String?>[
                  item.title,
                  _formatOptionalDateTime(context, item.occurredAt),
                ]),
              ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
        AppButton.primary(
          label: l10n.patientsPrintReportAction,
          leadingIcon: Icons.print_outlined,
          onPressed: printCurrentWindow,
        ),
      ],
    );
  }
}

class _ReportSummaryItem {
  const _ReportSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

class _ReportSummaryGrid extends StatelessWidget {
  const _ReportSummaryGrid({required this.records});

  final List<_ReportSummaryItem> records;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth < 520 ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: constraints.maxWidth < 520 ? 2.2 : 1.9,
          crossAxisSpacing: theme.spacing.sm,
          mainAxisSpacing: theme.spacing.sm,
          children: <Widget>[
            for (final _ReportSummaryItem record in records)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(record.icon, color: theme.colorScheme.primary),
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        '${record.value}',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        record.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.statusColors.warningContainer,
        border: Border.all(color: theme.statusColors.warning),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.patientsMergePreviewTitle,
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: theme.spacing.sm),
            _DuplicatePatientPair(
              primary: preview.primaryPatient,
              secondary: preview.secondaryPatient,
            ),
            if (counts.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
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
            ],
            SizedBox(height: theme.spacing.md),
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
        ),
      ),
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: AppFormSection(
              density: AppFormSectionDensity.compact,
              children: <Widget>[
                if (_failure != null) AppFailureStateView(failure: _failure!),
                if (_duplicateCandidates.isNotEmpty)
                  PatientDuplicateWarningPanel(
                    duplicates: _duplicateCandidates,
                  ),
                _ResponsiveFieldPair(
                  left: AppTextField(
                    controller: _firstNameController,
                    labelText: l10n.patientsFirstNameLabel,
                    isRequired: true,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isSaving,
                    validator: AppValidators.requiredText(
                      l10n.validationRequired,
                    ),
                  ),
                  right: AppTextField(
                    controller: _lastNameController,
                    labelText: l10n.patientsLastNameLabel,
                    isRequired: true,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isSaving,
                    validator: AppValidators.requiredText(
                      l10n.validationRequired,
                    ),
                  ),
                ),
                _ResponsiveFieldPair(
                  left: AppDateField(
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
                          leadingIcon: const Icon(Icons.business_outlined),
                        ),
                    ],
                  ),
                AppPhoneField(
                  controller: _phoneController,
                  labelText: l10n.patientsPhoneLabel,
                  countryLabelText: l10n.appPhoneCountryLabel,
                  countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
                  countryNoResultsText: l10n.appPhoneCountryNoResults,
                  numberLabelText: l10n.appPhoneNumberLabel,
                  numberHintText: l10n.appPhoneNumberHint,
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
                    value: _selectedIdentifierType(
                      _identifierTypeController.text,
                    ),
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
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final Iterable<PatientDuplicateCandidate> visible = duplicates.take(3);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.statusColors.warningContainer,
        border: Border.all(color: theme.statusColors.warning),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.content_copy_outlined,
                  color: theme.statusColors.warning,
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(
                    l10n.patientsDuplicateWarningTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.xs),
            Text(l10n.patientsDuplicateWarningBody),
            SizedBox(height: theme.spacing.sm),
            for (final PatientDuplicateCandidate duplicate in visible)
              _DuplicateCandidateLine(duplicate: duplicate),
          ],
        ),
      ),
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
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            Text(l10n.patientsEmergencyRegisterBody),
            _ResponsiveFieldPair(
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
            AppPhoneField(
              controller: _phoneController,
              labelText: l10n.patientsPhoneLabel,
              countryLabelText: l10n.appPhoneCountryLabel,
              countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
              countryNoResultsText: l10n.appPhoneCountryNoResults,
              numberLabelText: l10n.appPhoneNumberLabel,
              numberHintText: l10n.appPhoneNumberHint,
              invalidPhoneMessage: l10n.appPhoneInvalidMessage,
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final DateTime registeredAt = DateTime.now().toUtc();
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'first_name': firstName.isEmpty ? 'Emergency' : firstName,
      'last_name': lastName.isEmpty
          ? 'Patient ${registeredAt.millisecondsSinceEpoch}'
          : lastName,
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
        AppPhoneField(
          controller: _third,
          labelText: l10n.patientsPhoneLabel,
          countryLabelText: l10n.appPhoneCountryLabel,
          countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
          countryNoResultsText: l10n.appPhoneCountryNoResults,
          numberLabelText: l10n.appPhoneNumberLabel,
          numberHintText: l10n.appPhoneNumberHint,
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
        _DocumentUploadField(
          files: _documentFiles,
          enabled:
              !_isSaving &&
              !_isPickingDocuments &&
              widget.onUploadDocuments != null,
          isLoading: _isPickingDocuments,
          onPick: _pickDocumentFiles,
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

  Widget _contactValueField(BuildContext context) {
    final l10n = context.l10n;
    final String type = (_choice ?? '').toUpperCase();
    if (<String>{'PHONE', 'WHATSAPP', 'FAX'}.contains(type)) {
      return AppPhoneField(
        controller: _first,
        labelText: l10n.patientsContactValueLabel,
        countryLabelText: l10n.appPhoneCountryLabel,
        countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
        countryNoResultsText: l10n.appPhoneCountryNoResults,
        numberLabelText: l10n.appPhoneNumberLabel,
        numberHintText: l10n.appPhoneNumberHint,
        invalidPhoneMessage: l10n.appPhoneInvalidMessage,
        requiredMessage: l10n.validationRequired,
        enabled: !_isSaving,
        isRequired: true,
      );
    }

    if (type == 'EMAIL') {
      return AppEmailField(
        controller: _first,
        labelText: l10n.patientsContactValueLabel,
        invalidEmailMessage: l10n.authEmailInvalidMessage,
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

class _DocumentUploadField extends StatelessWidget {
  const _DocumentUploadField({
    required this.files,
    required this.enabled,
    required this.isLoading,
    required this.onPick,
    required this.onClear,
  });

  final List<XFile> files;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final String fileSummary = files.isEmpty
        ? l10n.patientsDocumentUploadEmpty
        : files.map((XFile file) => file.name).join(', ');

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.upload_file_outlined,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.patientsDocumentUploadTitle,
                        style: theme.textTheme.titleSmall,
                      ),
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        fileSummary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                AppButton.secondary(
                  label: l10n.patientsChooseDocumentAction,
                  leadingIcon: Icons.attach_file_outlined,
                  isLoading: isLoading,
                  enabled: enabled,
                  onPressed: enabled ? onPick : null,
                ),
                if (files.isNotEmpty)
                  AppButton.tertiary(
                    label: l10n.patientsClearFiltersAction,
                    leadingIcon: Icons.close,
                    enabled: enabled,
                    onPressed: enabled ? onClear : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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

List<AppSelectOption<String>> _providerSelectOptions(
  List<OpdProviderOption> providers,
) {
  return <AppSelectOption<String>>[
    for (final OpdProviderOption provider in providers)
      AppSelectOption<String>(
        value: provider.id,
        label: provider.displayTitle,
        leadingIcon: const Icon(Icons.person_search_outlined),
        labelWidget: _ProviderOptionLabel(provider: provider),
      ),
  ];
}

class _ProviderOptionLabel extends StatelessWidget {
  const _ProviderOptionLabel({required this.provider});

  final OpdProviderOption provider;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(provider.displayTitle),
        if (_joinDisplay(<String?>[
          provider.positionTitle,
          provider.practitionerType,
        ]).isNotEmpty)
          Text(
            _joinDisplay(<String?>[
              provider.positionTitle,
              provider.practitionerType,
            ]),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
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
const String _statusActive = 'active';
const String _statusInactive = 'inactive';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class OpdWorkspacePage extends ConsumerWidget {
  const OpdWorkspacePage({super.key});

  static const AccessRequirement _readRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.patientRead,
      AppPermissions.clinicalRead,
      AppPermissions.billingRead,
      AppPermissions.operationsRead,
      AppPermissions.emergencyRead,
    ],
    activeModules: <String>['opd-flow'],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<Result<OpdWorkspaceState>> state = ref.watch(
      opdWorkspaceControllerProvider,
    );

    return AppAccessGate(
      requirement: _readRequirement,
      deniedBuilder: (_, _) => AppStateScaffold(
        variant: AppStateViewVariant.forbidden,
        title: l10n.routeForbiddenTitle,
        body: l10n.routeForbiddenBody,
      ),
      child: AsyncStateScaffold<OpdWorkspaceState>(
        value: state,
        loadingTitle: l10n.opdLoadingTitle,
        loadingBody: l10n.opdLoadingBody,
        maxWidth: PageMaxWidth.dataHeavy,
        centerVertically: false,
        onRetry: () {
          ref.read(opdWorkspaceControllerProvider.notifier).refresh();
        },
        dataBuilder: (BuildContext context, OpdWorkspaceState data) {
          return _OpdWorkspaceContent(state: data);
        },
      ),
    );
  }
}

class _OpdWorkspaceContent extends ConsumerStatefulWidget {
  const _OpdWorkspaceContent({required this.state});

  final OpdWorkspaceState state;

  @override
  ConsumerState<_OpdWorkspaceContent> createState() =>
      _OpdWorkspaceContentState();
}

class _OpdWorkspaceContentState extends ConsumerState<_OpdWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.patientWrite,
      AppPermissions.clinicalWrite,
      AppPermissions.billingWrite,
      AppPermissions.operationsWrite,
      AppPermissions.emergencyWrite,
    ],
    activeModules: <String>['opd-flow'],
  );

  final ValueNotifier<_OpdTableFilter> _filterNotifier =
      ValueNotifier<_OpdTableFilter>(const _OpdTableFilter());

  @override
  void dispose() {
    _filterNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final OpdWorkspaceState state = widget.state;
    final OpdWorkspaceController controller = ref.read(
      opdWorkspaceControllerProvider.notifier,
    );
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool iconOnly =
        breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;

    return AppWorkspace(
      title: l10n.opdTitle,
      description: '',
      compactSummaryCards: true,
      primaryAction: AppAccessActionGate(
        requirement: _writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          if (iconOnly) {
            return AppIconButton(
              icon: Icons.person_add_alt_1_outlined,
              semanticLabel: l10n.opdStartWalkInAction,
              tooltip: l10n.opdStartWalkInAction,
              enabled: isAllowed,
              onPressed: () {
                _openStartWalkInDialog(context, ref);
              },
            );
          }

          return AppButton.primary(
            label: l10n.opdStartWalkInAction,
            leadingIcon: Icons.person_add_alt_1_outlined,
            enabled: isAllowed,
            onPressed: () {
              _openStartWalkInDialog(context, ref);
            },
          );
        },
      ),
      secondaryActions: <Widget>[
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading:
              state.isRefreshingAppointments ||
              state.isRefreshingQueue ||
              state.isRefreshingFlows,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        AppWorkspaceSummaryCard(
          label: l10n.opdArrivalsSummaryLabel,
          value: AppFormatters.compactNumber(
            state.arrivalCount,
            Localizations.localeOf(context),
          ),
          icon: Icons.event_available_outlined,
          tone: _categoryTone(_opdCategoryArrival),
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              title: l10n.opdArrivalsSummaryLabel,
              emptyTitle: l10n.opdNoArrivalsTitle,
              emptyBody: l10n.opdNoArrivalsBody,
              patients: _summaryItemsFromAppointments(state.appointments.items),
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.opdQueueSummaryLabel,
          value: AppFormatters.compactNumber(
            state.queueCount,
            Localizations.localeOf(context),
          ),
          icon: Icons.queue_outlined,
          tone: _categoryTone(_opdCategoryQueue),
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              title: l10n.opdQueueSummaryLabel,
              emptyTitle: l10n.opdNoQueueTitle,
              emptyBody: l10n.opdNoQueueBody,
              patients: _summaryItemsFromQueue(state.queueEntries.items),
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.opdActiveFlowSummaryLabel,
          value: AppFormatters.compactNumber(
            state.activeFlowCount,
            Localizations.localeOf(context),
          ),
          icon: Icons.medical_services_outlined,
          tone: _categoryTone(_opdCategoryActiveFlow),
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              title: l10n.opdActiveFlowSummaryLabel,
              emptyTitle: l10n.opdNoFlowsTitle,
              emptyBody: l10n.opdNoFlowsBody,
              patients: _summaryItemsFromFlows(
                state.flows.items.where(
                  (OpdFlowSummary flow) => !flow.isTerminal,
                ),
              ),
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.opdCompletedFlowSummaryLabel,
          value: AppFormatters.compactNumber(
            state.completedFlowCount,
            Localizations.localeOf(context),
          ),
          icon: Icons.task_alt_outlined,
          tone: AppWorkspaceStatusTone.neutral,
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              title: l10n.opdCompletedFlowSummaryLabel,
              emptyTitle: l10n.opdNoSummaryPatientsTitle,
              emptyBody: l10n.opdNoSummaryPatientsBody,
              patients: _summaryItemsFromFlows(
                state.flows.items.where(
                  (OpdFlowSummary flow) => flow.isTerminal,
                ),
              ),
            );
          },
        ),
      ],
      filters: ValueListenableBuilder<_OpdTableFilter>(
        valueListenable: _filterNotifier,
        builder: (BuildContext context, _OpdTableFilter filter, _) {
          return _OpdFilters(
            state: state,
            filter: filter,
            onFilterChanged: _setFilter,
          );
        },
      ),
      body: ValueListenableBuilder<_OpdTableFilter>(
        valueListenable: _filterNotifier,
        builder: (BuildContext context, _OpdTableFilter filter, _) {
          return _OpdWorkspaceBody(state: state, filter: filter);
        },
      ),
    );
  }

  void _setFilter(_OpdTableFilter filter) {
    if (_filterNotifier.value == filter) {
      return;
    }
    _filterNotifier.value = filter;
  }

  Future<void> _openStartWalkInDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StartWalkInDialog(
        providerSchedules: widget.state.providerSchedules,
        appointments: widget.state.appointments.items,
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(opdWorkspaceControllerProvider.notifier)
              .startWalkIn(payload);
        },
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }

  Future<void> _openSummaryPatientList(
    BuildContext context, {
    required String title,
    required String emptyTitle,
    required String emptyBody,
    required List<_OpdPatientSummaryItem> patients,
  }) async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => _OpdSummaryPatientListDialog(
        title: title,
        emptyTitle: emptyTitle,
        emptyBody: emptyBody,
        patients: patients,
      ),
    );
  }
}

class _OpdFilters extends StatefulWidget {
  const _OpdFilters({
    required this.state,
    required this.filter,
    required this.onFilterChanged,
  });

  final OpdWorkspaceState state;
  final _OpdTableFilter filter;
  final ValueChanged<_OpdTableFilter> onFilterChanged;

  @override
  State<_OpdFilters> createState() => _OpdFiltersState();
}

@immutable
final class _OpdPatientSummaryItem {
  const _OpdPatientSummaryItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.status,
    this.provider,
    this.time,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? status;
  final String? provider;
  final DateTime? time;

  bool matches(String search) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return <String?>[id, title, subtitle, status, provider]
        .whereType<String>()
        .any((String value) => value.toLowerCase().contains(needle));
  }
}

List<_OpdPatientSummaryItem> _summaryItemsFromAppointments(
  Iterable<OpdAppointment> appointments,
) {
  return appointments
      .map(
        (OpdAppointment item) => _OpdPatientSummaryItem(
          id: item.id,
          title: item.displayTitle,
          subtitle: _joinDisplay(<String?>[
            item.patientIdentifier,
            item.patientPhone,
            item.reason,
          ]),
          status: item.status,
          provider: item.providerDisplayName,
          time: item.scheduledStart,
        ),
      )
      .toList(growable: false);
}

List<_OpdPatientSummaryItem> _summaryItemsFromQueue(
  Iterable<OpdQueueEntry> entries,
) {
  return entries
      .map(
        (OpdQueueEntry item) => _OpdPatientSummaryItem(
          id: item.id,
          title: item.displayTitle,
          subtitle: _joinDisplay(<String?>[
            item.patientIdentifier,
            item.patientPhone,
            item.appointmentReason,
          ]),
          status: item.status,
          provider: item.providerDisplayName,
          time: item.queuedAt,
        ),
      )
      .toList(growable: false);
}

List<_OpdPatientSummaryItem> _summaryItemsFromFlows(
  Iterable<OpdFlowSummary> flows,
) {
  return flows
      .map(
        (OpdFlowSummary item) => _OpdPatientSummaryItem(
          id: item.id,
          title: item.displayTitle,
          subtitle: _joinDisplay(<String?>[
            item.patientIdentifier,
            item.patientPhone,
            item.nextStep == null ? null : _apiLabel(item.nextStep!),
          ]),
          status: item.stage,
          provider: item.providerDisplayName,
          time: item.startedAt,
        ),
      )
      .toList(growable: false);
}

class _OpdSummaryPatientListDialog extends StatefulWidget {
  const _OpdSummaryPatientListDialog({
    required this.title,
    required this.emptyTitle,
    required this.emptyBody,
    required this.patients,
  });

  final String title;
  final String emptyTitle;
  final String emptyBody;
  final List<_OpdPatientSummaryItem> patients;

  @override
  State<_OpdSummaryPatientListDialog> createState() =>
      _OpdSummaryPatientListDialogState();
}

class _OpdSummaryPatientListDialogState
    extends State<_OpdSummaryPatientListDialog> {
  late final TextEditingController _searchController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<_OpdPatientSummaryItem> patients = widget.patients
        .where((_OpdPatientSummaryItem item) => item.matches(_search))
        .toList(growable: false);

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
            semanticLabel: l10n.opdSearchLabel,
            hintText: l10n.opdSearchHint,
            prefixIcon: const Icon(Icons.search),
            textInputAction: TextInputAction.search,
          ),
          SizedBox(height: theme.spacing.md),
          AppDataList<_OpdPatientSummaryItem>(
            items: patients,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            emptyBuilder: (_) =>
                _EmptyPanel(title: widget.emptyTitle, body: widget.emptyBody),
            columns: <AppDataColumn<_OpdPatientSummaryItem>>[
              AppDataColumn<_OpdPatientSummaryItem>(
                label: l10n.opdPatientColumnLabel,
                cellBuilder: (_, _OpdPatientSummaryItem item) =>
                    _PatientText(title: item.title, subtitle: item.subtitle),
              ),
              AppDataColumn<_OpdPatientSummaryItem>(
                label: l10n.opdStatusColumnLabel,
                cellBuilder: (_, _OpdPatientSummaryItem item) =>
                    _StatusBadge(value: item.status),
              ),
              AppDataColumn<_OpdPatientSummaryItem>(
                label: l10n.opdProviderColumnLabel,
                cellBuilder: (_, _OpdPatientSummaryItem item) =>
                    Text(item.provider ?? l10n.profileUnknownValue),
              ),
              AppDataColumn<_OpdPatientSummaryItem>(
                label: l10n.opdTimeColumnLabel,
                cellBuilder: (_, _OpdPatientSummaryItem item) =>
                    Text(_formatDateTime(context, item.time)),
              ),
            ],
            mobileItemBuilder: (_, _OpdPatientSummaryItem item) =>
                _SummaryPatientMobileRow(item: item),
            itemKeyBuilder: (_OpdPatientSummaryItem item) =>
                ValueKey<String>(item.id),
          ),
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
  }
}

class _SummaryPatientMobileRow extends StatelessWidget {
  const _SummaryPatientMobileRow({required this.item});

  final _OpdPatientSummaryItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title, style: theme.textTheme.titleSmall),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _joinDisplay(<String?>[
                    item.subtitle,
                    item.provider,
                    item.time == null
                        ? null
                        : AppFormatters.dateTime(item.time!, locale),
                  ]),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          _StatusBadge(value: item.status),
        ],
      ),
    );
  }
}

class _OpdFiltersState extends State<_OpdFilters> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filter.search);
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _OpdFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextSearch = widget.filter.search;
    if (nextSearch != _searchController.text) {
      _searchController.text = nextSearch;
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool useAdvancedModal = breakpoint.isMobile;
    final List<String> statuses = _tableStatuses(widget.state);
    final Widget searchField = AppTextField(
      controller: _searchController,
      semanticLabel: l10n.opdSearchLabel,
      hintText: l10n.opdSearchHint,
      prefixIcon: const Icon(Icons.search),
      textInputAction: TextInputAction.search,
      onFieldSubmitted: (_) => _applySearch(),
    );

    return AppWorkspaceFilterBar(
      semanticLabel: l10n.opdFiltersLabel,
      expandSearch: true,
      search: useAdvancedModal
          ? Row(
              children: <Widget>[
                Expanded(child: searchField),
                if (widget.filter.isActive) ...<Widget>[
                  const SizedBox(width: 4),
                  AppIconButton(
                    icon: Icons.clear,
                    semanticLabel: l10n.opdClearFiltersAction,
                    tooltip: l10n.opdClearFiltersAction,
                    onPressed: () {
                      widget.onFilterChanged(const _OpdTableFilter());
                    },
                  ),
                ],
                const SizedBox(width: 4),
                AppIconButton(
                  icon: widget.filter.hasAdvancedFilters
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                  semanticLabel: l10n.opdFilterAction,
                  tooltip: l10n.opdFilterAction,
                  onPressed: _openFilters,
                ),
              ],
            )
          : searchField,
      filters: useAdvancedModal
          ? const <Widget>[]
          : <Widget>[
              AppSelectField<String>.searchable(
                value: widget.filter.category ?? _opdFilterAll,
                labelText: l10n.opdCategoryFilterLabel,
                semanticLabel: l10n.opdCategoryFilterLabel,
                options: _categoryFilterOptions(context),
                onChanged: (String? value) {
                  final bool clearValue =
                      value == null || value == _opdFilterAll;
                  widget.onFilterChanged(
                    widget.filter.copyWith(
                      category: clearValue ? null : value,
                      clearCategory: clearValue,
                    ),
                  );
                },
              ),
              AppSelectField<String>.searchable(
                value: widget.filter.status ?? _opdFilterAll,
                labelText: l10n.opdStatusFilterLabel,
                semanticLabel: l10n.opdStatusFilterLabel,
                options: _statusFilterOptions(context, statuses),
                onChanged: (String? value) {
                  final bool clearValue =
                      value == null || value == _opdFilterAll;
                  widget.onFilterChanged(
                    widget.filter.copyWith(
                      status: clearValue ? null : value,
                      clearStatus: clearValue,
                    ),
                  );
                },
              ),
            ],
      actions: <Widget>[
        if (!useAdvancedModal && widget.filter.isActive)
          AppButton.tertiary(
            label: l10n.opdClearFiltersAction,
            leadingIcon: Icons.clear,
            onPressed: () {
              widget.onFilterChanged(const _OpdTableFilter());
            },
          ),
      ],
    );
  }

  Future<void> _openFilters() async {
    final _OpdTableFilter? value = await showAppDialog<_OpdTableFilter>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OpdFilterDialog(
        initialFilter: widget.filter,
        statuses: _tableStatuses(widget.state),
      ),
    );
    if (value != null) {
      widget.onFilterChanged(value);
    }
  }

  void _handleSearchChanged() {
    _applySearch();
  }

  void _applySearch() {
    final String value = _searchController.text.trim();
    if (value == widget.filter.search) {
      return;
    }
    widget.onFilterChanged(widget.filter.copyWith(search: value));
  }
}

class _OpdWorkspaceBody extends StatelessWidget {
  const _OpdWorkspaceBody({required this.state, required this.filter});

  final OpdWorkspaceState state;
  final _OpdTableFilter filter;

  @override
  Widget build(BuildContext context) {
    final List<_OpdTableItem> items = _tableItems(state)
        .where((_OpdTableItem item) => filter.matches(item))
        .toList(growable: false);

    return _OpdMainTable(
      items: items,
      isLoading:
          state.isRefreshingAppointments ||
          state.isRefreshingQueue ||
          state.isRefreshingFlows,
    );
  }
}

List<String> _tableStatuses(OpdWorkspaceState state) {
  return _tableItems(state)
      .map((_OpdTableItem item) => item.status)
      .whereType<String>()
      .where((String value) => value.trim().isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
}

List<AppSelectOption<String>> _categoryFilterOptions(BuildContext context) {
  final l10n = context.l10n;
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _opdFilterAll,
      label: l10n.opdAllCategoriesOption,
    ),
    AppSelectOption<String>(
      value: _opdCategoryArrival,
      label: l10n.opdArrivalsSummaryLabel,
    ),
    AppSelectOption<String>(
      value: _opdCategoryQueue,
      label: l10n.opdQueueSummaryLabel,
    ),
    AppSelectOption<String>(
      value: _opdCategoryActiveFlow,
      label: l10n.opdActiveFlowSummaryLabel,
    ),
  ];
}

List<AppSelectOption<String>> _statusFilterOptions(
  BuildContext context,
  List<String> statuses,
) {
  final l10n = context.l10n;
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _opdFilterAll,
      label: l10n.opdAllStatusesOption,
    ),
    for (final String status in statuses)
      AppSelectOption<String>(value: status, label: _apiLabel(status)),
  ];
}

@immutable
final class _OpdTableFilter {
  const _OpdTableFilter({this.search = '', this.category, this.status});

  final String search;
  final String? category;
  final String? status;

  bool get isActive =>
      search.trim().isNotEmpty || _isNonEmpty(category) || _isNonEmpty(status);

  bool get hasAdvancedFilters => _isNonEmpty(category) || _isNonEmpty(status);

  _OpdTableFilter copyWith({
    String? search,
    String? category,
    String? status,
    bool clearSearch = false,
    bool clearCategory = false,
    bool clearStatus = false,
  }) {
    return _OpdTableFilter(
      search: clearSearch ? '' : search ?? this.search,
      category: clearCategory ? null : category ?? this.category,
      status: clearStatus ? null : status ?? this.status,
    );
  }

  bool matches(_OpdTableItem item) {
    if (!item.matches(search)) {
      return false;
    }
    if (_isNonEmpty(category) && item.category != category) {
      return false;
    }
    if (_isNonEmpty(status) && item.status != status) {
      return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    return other is _OpdTableFilter &&
        other.search == search &&
        other.category == category &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(search, category, status);
}

@immutable
final class _OpdTableItem {
  const _OpdTableItem({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    this.subtitle,
    this.provider,
    this.nextStep,
    this.time,
    this.appointment,
    this.queueEntry,
    this.flow,
  });

  final String id;
  final String title;
  final String category;
  final String? status;
  final String? subtitle;
  final String? provider;
  final String? nextStep;
  final DateTime? time;
  final OpdAppointment? appointment;
  final OpdQueueEntry? queueEntry;
  final OpdFlowSummary? flow;

  String get categoryKey {
    final OpdFlowSummary? activeFlow = flow;
    final OpdQueueEntry? activeQueue = queueEntry;
    final OpdAppointment? activeAppointment = appointment;
    return activeFlow?.patientId ??
        activeQueue?.patientId ??
        activeAppointment?.patientId ??
        id;
  }

  bool matches(String search) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return <String?>[
      id,
      title,
      category,
      status,
      subtitle,
      provider,
      nextStep,
      appointment?.patientId,
      appointment?.patientIdentifier,
      appointment?.patientPhone,
      appointment?.reason,
      queueEntry?.patientId,
      queueEntry?.patientIdentifier,
      queueEntry?.patientPhone,
      queueEntry?.appointmentReason,
      flow?.patientId,
      flow?.patientIdentifier,
      flow?.patientPhone,
      flow?.stage,
      flow?.status,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }
}

List<_OpdTableItem> _tableItems(OpdWorkspaceState state) {
  final Set<String> usedPatientKeys = <String>{};
  final List<_OpdTableItem> items = <_OpdTableItem>[];

  for (final OpdFlowSummary flow in state.flows.items) {
    if (flow.isTerminal || _isCompletedStatus(flow.status ?? flow.stage)) {
      continue;
    }
    final _OpdTableItem item = _OpdTableItem(
      id: flow.id,
      title: flow.displayTitle,
      category: _opdCategoryActiveFlow,
      status: flow.stage,
      subtitle: _joinDisplay(<String?>[
        flow.patientIdentifier,
        flow.patientPhone,
      ]),
      provider: flow.providerDisplayName,
      nextStep: flow.nextStep,
      time: flow.startedAt,
      flow: flow,
    );
    usedPatientKeys.add(item.categoryKey);
    items.add(item);
  }

  for (final OpdQueueEntry entry in state.queueEntries.items) {
    if (_isCompletedStatus(entry.status)) {
      continue;
    }
    final _OpdTableItem item = _OpdTableItem(
      id: entry.id,
      title: entry.displayTitle,
      category: _opdCategoryQueue,
      status: entry.status,
      subtitle: _joinDisplay(<String?>[
        entry.patientIdentifier,
        entry.patientPhone,
        entry.appointmentReason,
      ]),
      provider: entry.providerDisplayName,
      time: entry.queuedAt,
      queueEntry: entry,
    );
    if (usedPatientKeys.add(item.categoryKey)) {
      items.add(item);
    }
  }

  for (final OpdAppointment appointment in state.appointments.items) {
    if (_isCompletedStatus(appointment.status)) {
      continue;
    }
    final _OpdTableItem item = _OpdTableItem(
      id: appointment.id,
      title: appointment.displayTitle,
      category: _opdCategoryArrival,
      status: appointment.status,
      subtitle: _joinDisplay(<String?>[
        appointment.patientIdentifier,
        appointment.patientPhone,
        appointment.reason,
      ]),
      provider: appointment.providerDisplayName,
      time: appointment.scheduledStart,
      appointment: appointment,
    );
    if (usedPatientKeys.add(item.categoryKey)) {
      items.add(item);
    }
  }

  items.sort((_OpdTableItem left, _OpdTableItem right) {
    final int categoryCompare = _categorySort(
      left.category,
    ).compareTo(_categorySort(right.category));
    if (categoryCompare != 0) {
      return categoryCompare;
    }
    return (left.time ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      right.time ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  });
  return items;
}

int _categorySort(String category) {
  return switch (category) {
    _opdCategoryActiveFlow => 0,
    _opdCategoryQueue => 1,
    _opdCategoryArrival => 2,
    _ => 3,
  };
}

bool _isCompletedStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'CLOSED' => true,
    _ => false,
  };
}

class _OpdMainTable extends ConsumerWidget {
  const _OpdMainTable({required this.items, required this.isLoading});

  final List<_OpdTableItem> items;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return AppDataList<_OpdTableItem>(
      items: items,
      isLoading: isLoading,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      emptyBuilder: (_) =>
          _EmptyPanel(title: l10n.opdNoFlowsTitle, body: l10n.opdNoFlowsBody),
      columns: <AppDataColumn<_OpdTableItem>>[
        AppDataColumn<_OpdTableItem>(
          label: l10n.opdPatientColumnLabel,
          cellBuilder: (_, _OpdTableItem item) =>
              _PatientText(title: item.title, subtitle: item.subtitle),
        ),
        AppDataColumn<_OpdTableItem>(
          label: l10n.opdNextStepColumnLabel,
          cellBuilder: (_, _OpdTableItem item) => Text(
            _nextStepLabel(context, item),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AppDataColumn<_OpdTableItem>(
          label: l10n.opdActionsColumnLabel,
          cellBuilder: (_, _OpdTableItem item) => AppIconButton(
            icon: Icons.more_horiz,
            semanticLabel: l10n.opdOpenActions,
            tooltip: l10n.opdOpenActions,
            onPressed: () => _openTableItemActions(context, item),
          ),
        ),
      ],
      mobileItemBuilder: (_, _OpdTableItem item) => _OpdTableMobileRow(
        item: item,
        onPressed: () => _openTableItemActions(context, item),
      ),
      itemKeyBuilder: (_OpdTableItem item) =>
          ValueKey<String>('${item.category}-${item.id}'),
      rowColorBuilder: _opdTableRowColor,
    );
  }

  Future<void> _openTableItemActions(
    BuildContext context,
    _OpdTableItem item,
  ) async {
    final OpdAppointment? appointment = item.appointment;
    final OpdQueueEntry? queueEntry = item.queueEntry;
    final OpdFlowSummary? flow = item.flow;

    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        if (appointment != null) {
          return AppointmentActionsDialog(appointment: appointment);
        }
        if (queueEntry != null) {
          return QueueActionsDialog(entry: queueEntry);
        }
        return FlowActionsDialog(flow: flow!);
      },
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }
}

class _OpdTableMobileRow extends StatelessWidget {
  const _OpdTableMobileRow({required this.item, required this.onPressed});

  final _OpdTableItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.title, style: theme.textTheme.titleSmall),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    _joinDisplay(<String?>[
                      item.subtitle,
                      _nextStepLabel(context, item),
                    ]),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _OpdFilterDialog extends StatefulWidget {
  const _OpdFilterDialog({required this.initialFilter, required this.statuses});

  final _OpdTableFilter initialFilter;
  final List<String> statuses;

  @override
  State<_OpdFilterDialog> createState() => _OpdFilterDialogState();
}

class _OpdFilterDialogState extends State<_OpdFilterDialog> {
  String? _category;
  String? _status;

  @override
  void initState() {
    super.initState();
    _category = widget.initialFilter.category;
    _status = widget.initialFilter.status;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.opdFilterDialogTitle),
      icon: const Icon(Icons.filter_alt_outlined),
      content: AppFormSection(
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _category ?? _opdFilterAll,
            labelText: l10n.opdCategoryFilterLabel,
            semanticLabel: l10n.opdCategoryFilterLabel,
            options: _categoryFilterOptions(context),
            onChanged: (String? value) {
              setState(() {
                _category = value == _opdFilterAll ? null : value;
              });
            },
          ),
          AppSelectField<String>.searchable(
            value: _status ?? _opdFilterAll,
            labelText: l10n.opdStatusFilterLabel,
            semanticLabel: l10n.opdStatusFilterLabel,
            options: _statusFilterOptions(context, widget.statuses),
            onChanged: (String? value) {
              setState(() {
                _status = value == _opdFilterAll ? null : value;
              });
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.opdClearFiltersAction,
          onPressed: () => Navigator.of(context).pop(const _OpdTableFilter()),
        ),
        AppButton.primary(
          label: l10n.opdApplyFiltersAction,
          leadingIcon: Icons.filter_alt_outlined,
          onPressed: () {
            Navigator.of(context).pop(
              widget.initialFilter.copyWith(
                category: _category,
                status: _status,
                clearCategory: _category == null,
                clearStatus: _status == null,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      variant: AppStateViewVariant.empty,
      title: title,
      body: body,
      crossAxisAlignment: CrossAxisAlignment.center,
      textAlign: TextAlign.center,
    );
  }
}

class _PatientText extends StatelessWidget {
  const _PatientText({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final String label = _apiLabel(value ?? '');
    final AppWorkspaceStatusTone tone = _stageTone(value);

    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(label: label, tone: tone),
    );
  }
}

String _nextStepLabel(BuildContext context, _OpdTableItem item) {
  final String label = _apiLabel(item.nextStep ?? item.status ?? '');
  return label.isEmpty ? context.l10n.profileUnknownValue : label;
}

Color _opdTableRowColor(BuildContext context, _OpdTableItem item) {
  final ThemeData theme = Theme.of(context);
  final AppStatusColors statusColors = theme.statusColors;
  final Color color = switch (item.category) {
    _opdCategoryArrival => statusColors.infoContainer,
    _opdCategoryQueue => statusColors.warningContainer,
    _opdCategoryActiveFlow => statusColors.successContainer,
    _ => theme.colorScheme.surfaceContainerHighest,
  };
  return color.withValues(alpha: 0.42);
}

String _categoryLabel(BuildContext context, String category) {
  final l10n = context.l10n;
  return switch (category) {
    _opdCategoryArrival => l10n.opdArrivalsSummaryLabel,
    _opdCategoryQueue => l10n.opdQueueSummaryLabel,
    _opdCategoryActiveFlow => l10n.opdActiveFlowSummaryLabel,
    _ => _apiLabel(category),
  };
}

AppWorkspaceStatusTone _categoryTone(String category) {
  return switch (category) {
    _opdCategoryArrival => AppWorkspaceStatusTone.info,
    _opdCategoryQueue => AppWorkspaceStatusTone.warning,
    _opdCategoryActiveFlow => AppWorkspaceStatusTone.success,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

class _ProviderSelectField extends StatelessWidget {
  const _ProviderSelectField({
    required this.value,
    required this.providers,
    required this.schedules,
    required this.labelText,
    required this.helperText,
    required this.emptyHelperText,
    required this.enabled,
    required this.isLoading,
    required this.onChanged,
  });

  final String? value;
  final List<OpdProviderOption> providers;
  final List<OpdProviderSchedule> schedules;
  final String labelText;
  final String helperText;
  final String emptyHelperText;
  final bool enabled;
  final bool isLoading;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<AppSelectOption<String>> options = _providerSelectOptions(
      providers: providers,
      schedules: schedules,
    );

    return AppSelectField<String>.searchable(
      value: value,
      options: options,
      labelText: labelText,
      helperText: options.isEmpty && !isLoading ? emptyHelperText : helperText,
      semanticLabel: labelText,
      enabled: enabled,
      isLoading: isLoading,
      onChanged: onChanged,
    );
  }
}

enum _WalkInPatientMode { existing, appointment, newPatient }

class _WalkInModeSelector extends StatelessWidget {
  const _WalkInModeSelector({
    required this.value,
    required this.enabled,
    required this.existingLabel,
    required this.appointmentLabel,
    required this.newPatientLabel,
    required this.onChanged,
  });

  final _WalkInPatientMode value;
  final bool enabled;
  final String existingLabel;
  final String appointmentLabel;
  final String newPatientLabel;
  final ValueChanged<_WalkInPatientMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SegmentedButton<_WalkInPatientMode>(
      expandedInsets: EdgeInsets.zero,
      segments: <ButtonSegment<_WalkInPatientMode>>[
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.existing,
          label: _WalkInTabLabel(existingLabel),
          icon: const Icon(Icons.badge_outlined),
        ),
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.appointment,
          label: _WalkInTabLabel(appointmentLabel),
          icon: const Icon(Icons.event_available_outlined),
        ),
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.newPatient,
          label: _WalkInTabLabel(newPatientLabel),
          icon: const Icon(Icons.person_add_alt_1_outlined),
        ),
      ],
      selected: <_WalkInPatientMode>{value},
      showSelectedIcon: false,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(theme.spacing.none, 44)),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(),
        ),
      ),
      onSelectionChanged: enabled
          ? (Set<_WalkInPatientMode> selected) => onChanged(selected.first)
          : null,
    );
  }
}

class _WalkInTabLabel extends StatelessWidget {
  const _WalkInTabLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _WalkInSection extends StatelessWidget {
  const _WalkInSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: AppFormSection(
          title: title,
          density: AppFormSectionDensity.compact,
          children: children,
        ),
      ),
    );
  }
}

class _WalkInFieldRow extends StatelessWidget {
  const _WalkInFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked =
            !constraints.hasBoundedWidth || constraints.maxWidth < 560;
        if (stacked) {
          return Column(
            children: <Widget>[
              for (var index = 0; index < children.length; index += 1) ...[
                children[index],
                if (index < children.length - 1)
                  SizedBox(height: theme.appTokens.formGapCompact),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < children.length; index += 1) ...[
              Expanded(child: children[index]),
              if (index < children.length - 1)
                SizedBox(width: theme.spacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _WalkInLowerSections extends StatelessWidget {
  const _WalkInLowerSections({
    required this.routingSection,
    required this.billingSection,
  });

  final Widget routingSection;
  final Widget billingSection;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked =
            !constraints.hasBoundedWidth || constraints.maxWidth < 760;
        if (stacked) {
          return AppFormSection(
            density: AppFormSectionDensity.compact,
            children: <Widget>[routingSection, billingSection],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: routingSection),
            SizedBox(width: theme.spacing.md),
            Expanded(child: billingSection),
          ],
        );
      },
    );
  }
}

typedef OpdPayloadSubmit =
    Future<AppFailure?> Function(Map<String, Object?> payload);

class StartWalkInDialog extends ConsumerStatefulWidget {
  const StartWalkInDialog({
    required this.providerSchedules,
    required this.appointments,
    required this.onSubmit,
    super.key,
  });

  final List<OpdProviderSchedule> providerSchedules;
  final List<OpdAppointment> appointments;
  final OpdPayloadSubmit onSubmit;

  @override
  ConsumerState<StartWalkInDialog> createState() => _StartWalkInDialogState();
}

class _StartWalkInDialogState extends ConsumerState<StartWalkInDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _feeController;
  late final TextEditingController _notesController;
  List<Patient> _patientOptions = const <Patient>[];
  List<OpdAppointment> _appointmentOptions = const <OpdAppointment>[];
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  _WalkInPatientMode _patientMode = _WalkInPatientMode.existing;
  bool _isLoadingPatients = false;
  bool _isLoadingAppointments = false;
  bool _isLoadingProviders = false;
  String? _patientId;
  String? _appointmentId;
  String? _providerId;
  String _currency = appDefaultCurrencyCode;
  String _arrivalMode = 'WALK_IN';
  String _emergencySeverity = 'HIGH';
  String? _triageLevel;
  String? _gender;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _feeController = TextEditingController();
    _notesController = TextEditingController();
    _appointmentOptions = _eligibleAppointmentOptions(widget.appointments);
    unawaited(_loadPatientOptions());
    unawaited(_loadAppointmentOptions());
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.opdWalkInDialogTitle),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      scrollable: true,
      maxWidth: 880,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            _WalkInSection(
              title: l10n.opdPatientSectionTitle,
              children: <Widget>[
                _WalkInModeSelector(
                  value: _patientMode,
                  enabled: !_isSaving,
                  existingLabel: l10n.opdExistingPatientModeLabel,
                  appointmentLabel: l10n.opdAppointmentPatientModeLabel,
                  newPatientLabel: l10n.opdNewPatientModeLabel,
                  onChanged: _setPatientMode,
                ),
                _patientModeContent(l10n),
              ],
            ),
            _WalkInLowerSections(
              routingSection: _routingSection(l10n),
              billingSection: _billingSection(l10n),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdStartWalkInAction,
          leadingIcon: Icons.play_arrow_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _routingSection(AppLocalizations l10n) {
    return _WalkInSection(
      title: l10n.opdRoutingSectionTitle,
      children: <Widget>[
        if (_patientMode != _WalkInPatientMode.appointment)
          AppSelectField<String>.searchable(
            value: _arrivalMode,
            labelText: l10n.opdArrivalModeLabel,
            semanticLabel: l10n.opdArrivalModeLabel,
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() {
                _arrivalMode = value ?? 'WALK_IN';
              });
            },
            options: _statusOptions(_arrivalModeOptions),
          ),
        if (_arrivalMode == 'EMERGENCY' &&
            _patientMode != _WalkInPatientMode.appointment)
          _WalkInFieldRow(
            children: <Widget>[
              AppSelectField<String>.searchable(
                value: _emergencySeverity,
                labelText: l10n.opdEmergencySeverityLabel,
                semanticLabel: l10n.opdEmergencySeverityLabel,
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _emergencySeverity = value ?? _emergencySeverity;
                  });
                },
                options: _statusOptions(_emergencySeverityOptions),
              ),
              AppSelectField<String>.searchable(
                value: _triageLevel,
                labelText: l10n.opdTriageLevelLabel,
                semanticLabel: l10n.opdTriageLevelLabel,
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _triageLevel = value;
                  });
                },
                options: _statusOptions(_triageLevelOptions),
              ),
            ],
          ),
        _ProviderSelectField(
          value: _providerId,
          providers: _providerOptionsForDialog(),
          schedules: widget.providerSchedules,
          labelText: l10n.opdSearchProviderLabel,
          helperText: l10n.opdSearchProviderHelper,
          emptyHelperText: l10n.opdNoProvidersHelper,
          enabled: !_isSaving,
          isLoading: _isLoadingProviders,
          onChanged: (String? value) {
            setState(() {
              _providerId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _billingSection(AppLocalizations l10n) {
    return _WalkInSection(
      title: l10n.opdBillingSectionTitle,
      children: <Widget>[
        AppCurrencyAmountField(
          amountController: _feeController,
          currency: _currency,
          amountLabelText: l10n.opdConsultationFeeLabel,
          currencyLabelText: l10n.opdCurrencyLabel,
          enabled: !_isSaving,
          onCurrencyChanged: (String? value) {
            setState(() {
              _currency = value ?? appDefaultCurrencyCode;
            });
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.opdNotesLabel,
          enabled: !_isSaving,
          maxLines: 3,
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

    final AppFailure? failure = await widget.onSubmit(_payload());
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

  void _setPatientMode(_WalkInPatientMode mode) {
    setState(() {
      _patientMode = mode;
      if (mode == _WalkInPatientMode.appointment) {
        _arrivalMode = 'ONLINE_APPOINTMENT';
      } else if (_arrivalMode == 'ONLINE_APPOINTMENT') {
        _arrivalMode = 'WALK_IN';
      }
    });
  }

  Widget _patientModeContent(AppLocalizations l10n) {
    return switch (_patientMode) {
      _WalkInPatientMode.existing => AppSelectField<String>.searchable(
        value: _patientId,
        options: _patientOptions
            .map(_patientSelectOption)
            .whereType<AppSelectOption<String>>()
            .toList(growable: false),
        labelText: l10n.opdSearchPatientLabel,
        semanticLabel: l10n.opdSearchPatientLabel,
        isLoading: _isLoadingPatients,
        enabled: !_isSaving,
        onChanged: (String? value) {
          setState(() {
            _patientId = value;
          });
        },
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.existing || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.appointment => AppSelectField<String>.searchable(
        value: _appointmentId,
        options: _appointmentOptions
            .map(_appointmentSelectOption)
            .whereType<AppSelectOption<String>>()
            .toList(growable: false),
        labelText: l10n.opdAppointmentPatientLabel,
        helperText: l10n.opdAppointmentPatientHelper,
        semanticLabel: l10n.opdAppointmentPatientLabel,
        isLoading: _isLoadingAppointments,
        enabled: !_isSaving,
        onChanged: (String? value) {
          setState(() {
            _appointmentId = value;
            final OpdAppointment? appointment = _appointmentByApiId(value);
            _providerId = appointment?.providerUserId ?? _providerId;
          });
        },
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.appointment || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.newPatient => AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          _WalkInFieldRow(
            children: <Widget>[
              AppTextField(
                controller: _firstNameController,
                labelText: l10n.opdFirstNameLabel,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                validator: (String? value) =>
                    _patientMode != _WalkInPatientMode.newPatient ||
                        _isNonEmpty(value)
                    ? null
                    : l10n.validationRequired,
              ),
              AppTextField(
                controller: _lastNameController,
                labelText: l10n.opdLastNameLabel,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                validator: (String? value) =>
                    _patientMode != _WalkInPatientMode.newPatient ||
                        _isNonEmpty(value)
                    ? null
                    : l10n.validationRequired,
              ),
            ],
          ),
          AppGenderField(
            value: _gender,
            labelText: l10n.opdGenderLabel,
            maleLabel: l10n.patientsGenderMale,
            femaleLabel: l10n.patientsGenderFemale,
            otherLabel: l10n.patientsGenderOther,
            unknownLabel: l10n.patientsGenderUnknown,
            enabled: !_isSaving,
            onChanged: (String? value) => setState(() => _gender = value),
          ),
        ],
      ),
    };
  }

  Future<void> _loadPatientOptions() async {
    setState(() {
      _isLoadingPatients = true;
    });
    final Result<AppPage<Patient>> result = await ref
        .read(patientRepositoryProvider)
        .listPatients(
          const PatientListQuery(
            isActive: true,
            pageRequest: AppPageRequest(pageSize: 50),
          ),
        );
    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<Patient> page) {
        setState(() {
          _patientOptions = page.items;
          _isLoadingPatients = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingPatients = false;
        });
      },
    );
  }

  Future<void> _loadAppointmentOptions() async {
    setState(() {
      _isLoadingAppointments = true;
    });
    final Result<AppPage<OpdAppointment>> result = await ref
        .read(opdRepositoryProvider)
        .listAppointments(
          const OpdAppointmentQuery(pageRequest: AppPageRequest(pageSize: 50)),
        );
    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<OpdAppointment> page) {
        setState(() {
          _appointmentOptions = _eligibleAppointmentOptions(page.items);
          _isLoadingAppointments = false;
        });
      },
      failure: (_) {
        setState(() {
          _isLoadingAppointments = false;
        });
      },
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = providers;
          _isLoadingProviders = false;
        });
      },
      failure: (_) {
        setState(() {
          _isLoadingProviders = false;
        });
      },
    );
  }

  List<OpdProviderOption> _providerOptionsForDialog() {
    final Map<String, OpdProviderOption> options = <String, OpdProviderOption>{
      for (final OpdProviderOption provider in _providerOptions)
        provider.id: provider,
    };

    for (final OpdAppointment appointment in _appointmentOptions) {
      final String? id = appointment.providerUserId;
      if (!_isNonEmpty(id) || options.containsKey(id)) {
        continue;
      }
      options[id!] = OpdProviderOption(
        id: id,
        displayName: appointment.providerDisplayName,
        facilityId: appointment.facilityId,
      );
    }

    return options.values.toList(growable: false);
  }

  Map<String, Object?> _payload() {
    final String notes = _notesController.text.trim();
    final String arrivalMode = _patientMode == _WalkInPatientMode.appointment
        ? 'ONLINE_APPOINTMENT'
        : _arrivalMode;

    return <String, Object?>{
      if (_patientMode == _WalkInPatientMode.newPatient)
        'patient_registration': <String, Object?>{
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'gender': _gender,
        }
      else if (_patientMode == _WalkInPatientMode.appointment)
        'appointment_id': _appointmentId
      else
        'patient_id': _patientId,
      'provider_user_id': _providerId,
      'arrival_mode': arrivalMode,
      if (arrivalMode == 'EMERGENCY')
        'emergency': <String, Object?>{
          'severity': _emergencySeverity,
          'triage_level': _triageLevel,
          'notes': notes,
        },
      'consultation_fee': normalizeCurrencyAmount(_feeController.text),
      'currency': _currency,
      'notes': notes,
    };
  }

  OpdAppointment? _appointmentByApiId(String? value) {
    if (!_isNonEmpty(value)) {
      return null;
    }

    for (final OpdAppointment appointment in _appointmentOptions) {
      if (appointment.publicId == value || appointment.id == value) {
        return appointment;
      }
    }
    return null;
  }
}

class AppointmentActionsDialog extends ConsumerStatefulWidget {
  const AppointmentActionsDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<AppointmentActionsDialog> createState() =>
      _AppointmentActionsDialogState();
}

class _AppointmentActionsDialogState
    extends ConsumerState<AppointmentActionsDialog> {
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(widget.appointment.displayTitle),
      icon: const Icon(Icons.event_available_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          Text(
            _joinDisplay(<String?>[
              widget.appointment.reason,
              _apiLabel(widget.appointment.status ?? ''),
              _formatDateTime(context, widget.appointment.scheduledStart),
            ]),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.secondary(
          label: l10n.opdQueueAction,
          leadingIcon: Icons.queue_outlined,
          isLoading: _isSaving,
          onPressed: () => _run(
            () => ref
                .read(opdWorkspaceControllerProvider.notifier)
                .assignAppointmentToQueue(widget.appointment),
          ),
        ),
        AppButton.secondary(
          label: l10n.opdRescheduleAction,
          leadingIcon: Icons.edit_calendar_outlined,
          enabled: !_isSaving,
          onPressed: _openReschedule,
        ),
        AppButton.secondary(
          label: l10n.opdCancelAction,
          leadingIcon: Icons.cancel_outlined,
          isLoading: _isSaving,
          onPressed: _openCancel,
        ),
        AppButton.primary(
          label: l10n.opdCheckInAction,
          leadingIcon: Icons.login_outlined,
          isLoading: _isSaving,
          onPressed: () => _run(
            () => ref
                .read(opdWorkspaceControllerProvider.notifier)
                .checkInAppointment(widget.appointment),
          ),
        ),
      ],
    );
  }

  Future<void> _openReschedule() async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          RescheduleAppointmentDialog(appointment: widget.appointment),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openCancel() async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CancelAppointmentDialog(appointment: widget.appointment),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _run(Future<AppFailure?> Function() action) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await action();
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

class RescheduleAppointmentDialog extends ConsumerStatefulWidget {
  const RescheduleAppointmentDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<RescheduleAppointmentDialog> createState() =>
      _RescheduleAppointmentDialogState();
}

class _RescheduleAppointmentDialogState
    extends ConsumerState<RescheduleAppointmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(
      text:
          widget.appointment.scheduledStart?.toLocal().toIso8601String() ?? '',
    );
    _endController = TextEditingController(
      text: widget.appointment.scheduledEnd?.toLocal().toIso8601String() ?? '',
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.opdRescheduleAction),
      icon: const Icon(Icons.edit_calendar_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _startController,
              labelText: l10n.opdAppointmentStartLabel,
              hintText: l10n.opdDateTimeHint,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _endController,
              labelText: l10n.opdAppointmentEndLabel,
              hintText: l10n.opdDateTimeHint,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdSaveAction,
          leadingIcon: Icons.save_outlined,
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
    final DateTime? start = DateTime.tryParse(_startController.text.trim());
    final DateTime? end = DateTime.tryParse(_endController.text.trim());
    if (start == null || end == null || !end.isAfter(start)) {
      setState(() {
        _failure = AppFailure.validation();
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .rescheduleAppointment(widget.appointment, start, end);
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

class CancelAppointmentDialog extends ConsumerStatefulWidget {
  const CancelAppointmentDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<CancelAppointmentDialog> createState() =>
      _CancelAppointmentDialogState();
}

class _CancelAppointmentDialogState
    extends ConsumerState<CancelAppointmentDialog> {
  late final TextEditingController _reasonController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.opdCancelAction),
      icon: const Icon(Icons.cancel_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.opdCancellationReasonLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdCancelAction,
          leadingIcon: Icons.cancel_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .cancelAppointment(widget.appointment, _reasonController.text.trim());
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

class QueueActionsDialog extends ConsumerStatefulWidget {
  const QueueActionsDialog({required this.entry, super.key});

  final OpdQueueEntry entry;

  @override
  ConsumerState<QueueActionsDialog> createState() => _QueueActionsDialogState();
}

class _QueueActionsDialogState extends ConsumerState<QueueActionsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _providerController;
  late final TextEditingController _reasonController;
  String? _status;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _providerController = TextEditingController(
      text: widget.entry.providerUserId ?? '',
    );
    _reasonController = TextEditingController();
    _status = widget.entry.status;
  }

  @override
  void dispose() {
    _providerController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(widget.entry.displayTitle),
      icon: const Icon(Icons.queue_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _status,
              labelText: l10n.opdQueueStatusLabel,
              enabled: !_isSaving,
              onChanged: (String? value) => setState(() => _status = value),
              options: _statusOptions(_queueStatuses),
            ),
            AppTextField(
              controller: _providerController,
              labelText: l10n.opdProviderIdLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.opdReasonLabel,
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
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.secondary(
          label: l10n.opdPrioritizeAction,
          leadingIcon: Icons.priority_high_outlined,
          isLoading: _isSaving,
          onPressed: () => _run(
            () => ref
                .read(opdWorkspaceControllerProvider.notifier)
                .prioritizeQueueEntry(
                  widget.entry,
                  _reasonController.text.trim(),
                ),
          ),
        ),
        AppButton.secondary(
          label: l10n.opdMoveQueueAction,
          leadingIcon: Icons.sync_alt_outlined,
          isLoading: _isSaving,
          onPressed: _submitMove,
        ),
        AppButton.primary(
          label: l10n.opdStartConsultationAction,
          leadingIcon: Icons.play_arrow_outlined,
          isLoading: _isSaving,
          onPressed: () => _run(
            () => ref
                .read(opdWorkspaceControllerProvider.notifier)
                .startOpdFromQueue(widget.entry),
          ),
        ),
      ],
    );
  }

  Future<void> _submitMove() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _run(
      () => ref.read(opdWorkspaceControllerProvider.notifier).moveQueueEntry(
        widget.entry,
        <String, Object?>{
          'status': _status,
          'provider_user_id': _providerController.text.trim(),
        },
      ),
    );
  }

  Future<void> _run(Future<AppFailure?> Function() action) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await action();
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

const AccessRequirement _opdReceptionRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientWrite,
    AppPermissions.operationsWrite,
    AppPermissions.clinicalWrite,
    AppPermissions.emergencyWrite,
  ],
  activeModules: <String>['opd-flow'],
);

const AccessRequirement _opdTriageRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.emergencyWrite,
  ],
  activeModules: <String>['opd-flow'],
);

const AccessRequirement _opdDoctorRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>['opd-flow'],
);

const AccessRequirement _opdBillingRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.billingWrite,
    AppPermissions.patientWrite,
  ],
  activeModules: <String>['opd-flow'],
);

class FlowActionsDialog extends ConsumerStatefulWidget {
  const FlowActionsDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<FlowActionsDialog> createState() => _FlowActionsDialogState();
}

class _FlowActionsDialogState extends ConsumerState<FlowActionsDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(opdWorkspaceControllerProvider.notifier)
            .selectFlow(widget.flow),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Result<OpdWorkspaceState>? workspaceResult = ref
        .watch(opdWorkspaceControllerProvider)
        .asData
        ?.value;
    final OpdFlowDetail? detail = workspaceResult?.when(
      success: (OpdWorkspaceState state) {
        final OpdFlowDetail? selected = state.selectedFlow;
        if (selected == null || !_isSameFlow(selected.summary, widget.flow)) {
          return null;
        }
        return selected;
      },
      failure: (_) => null,
    );
    final OpdFlowSummary flow = detail?.summary ?? widget.flow;
    final bool terminal = flow.isTerminal;

    return AppDialog(
      title: Text(flow.displayTitle),
      icon: const Icon(Icons.medical_services_outlined),
      maxWidth: 860,
      scrollable: true,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (detail == null) const LinearProgressIndicator(),
          _PatientText(
            title: _categoryLabel(context, _opdCategoryActiveFlow),
            subtitle: _joinDisplay(<String?>[
              _apiLabel(flow.stage ?? ''),
              flow.providerDisplayName,
              flow.patientPhone,
            ]),
          ),
          _OpdWorkflowStatusSummary(flow: flow, detail: detail),
          _OpdWorkflowRecordSummary(detail: detail),
          _OpdWorkflowSection(
            title: l10n.opdWorkflowReceptionTitle,
            children: <Widget>[
              _OpdWorkflowAction(
                requirement: _opdBillingRequirement,
                label: l10n.opdPayConsultationAction,
                icon: Icons.payments_outlined,
                enabled: !terminal,
                onPressed: () =>
                    _openNested(context, ConsultationPaymentDialog(flow: flow)),
              ),
              _OpdWorkflowAction(
                requirement: _opdReceptionRequirement,
                label: l10n.opdAssignDoctorAction,
                icon: Icons.assignment_ind_outlined,
                enabled: !terminal,
                onPressed: () =>
                    _openNested(context, AssignDoctorDialog(flow: flow)),
              ),
              _OpdWorkflowAction(
                requirement: _opdReceptionRequirement,
                label: l10n.opdSendToTriageAction,
                icon: Icons.monitor_heart_outlined,
                enabled: !terminal,
                onPressed: () => _openNested(
                  context,
                  StageRouteDialog(
                    flow: flow,
                    title: l10n.opdSendToTriageAction,
                    stage: 'WAITING_VITALS',
                  ),
                ),
              ),
              _OpdWorkflowAction(
                requirement: _opdReceptionRequirement,
                label: l10n.opdSendToDoctorAction,
                icon: Icons.medical_information_outlined,
                enabled: !terminal,
                onPressed: () => _openNested(
                  context,
                  StageRouteDialog(
                    flow: flow,
                    title: l10n.opdSendToDoctorAction,
                    stage: 'WAITING_DOCTOR_REVIEW',
                  ),
                ),
              ),
            ],
          ),
          _OpdWorkflowSection(
            title: l10n.opdWorkflowTriageTitle,
            children: <Widget>[
              _OpdWorkflowAction(
                requirement: _opdTriageRequirement,
                label: l10n.opdRecordVitalsAction,
                icon: Icons.monitor_heart_outlined,
                enabled: !terminal,
                onPressed: () =>
                    _openNested(context, RecordVitalsDialog(flow: flow)),
              ),
              _OpdWorkflowAction(
                requirement: _opdTriageRequirement,
                label: l10n.opdAssignDoctorAction,
                icon: Icons.assignment_ind_outlined,
                enabled: !terminal,
                onPressed: () =>
                    _openNested(context, AssignDoctorDialog(flow: flow)),
              ),
            ],
          ),
          _OpdWorkflowSection(
            title: l10n.opdWorkflowDoctorTitle,
            children: <Widget>[
              _OpdWorkflowAction(
                requirement: _opdDoctorRequirement,
                label: l10n.opdDoctorReviewAction,
                icon: Icons.edit_note_outlined,
                enabled: !terminal,
                onPressed: () =>
                    _openNested(context, DoctorReviewDialog(flow: flow)),
              ),
              _OpdWorkflowAction(
                requirement: _opdDoctorRequirement,
                label: l10n.opdReferAction,
                icon: Icons.alt_route_outlined,
                enabled: !terminal,
                onPressed: () =>
                    _openNested(context, ReferralDialog(flow: flow)),
              ),
              _OpdWorkflowAction(
                requirement: _opdDoctorRequirement,
                label: l10n.opdFollowUpAction,
                icon: Icons.event_repeat_outlined,
                enabled: !terminal,
                onPressed: () =>
                    _openNested(context, FollowUpDialog(flow: flow)),
              ),
              _OpdWorkflowAction(
                requirement: _opdDoctorRequirement,
                label: l10n.opdDispositionAction,
                icon: Icons.task_alt_outlined,
                enabled: !terminal,
                onPressed: () =>
                    _openNested(context, DispositionDialog(flow: flow)),
              ),
            ],
          ),
          _OpdWorkflowSection(
            title: l10n.opdWorkflowServicesTitle,
            children: <Widget>[
              _OpdWorkflowAction(
                requirement: _opdDoctorRequirement,
                label: l10n.opdRouteLabAction,
                icon: Icons.biotech_outlined,
                enabled: !terminal,
                onPressed: () => _openNested(
                  context,
                  StageRouteDialog(
                    flow: flow,
                    title: l10n.opdRouteLabAction,
                    stage: 'LAB_REQUESTED',
                  ),
                ),
              ),
              _OpdWorkflowAction(
                requirement: _opdDoctorRequirement,
                label: l10n.opdRouteRadiologyAction,
                icon: Icons.personal_injury_outlined,
                enabled: !terminal,
                onPressed: () => _openNested(
                  context,
                  StageRouteDialog(
                    flow: flow,
                    title: l10n.opdRouteRadiologyAction,
                    stage: 'RADIOLOGY_REQUESTED',
                  ),
                ),
              ),
              _OpdWorkflowAction(
                requirement: _opdDoctorRequirement,
                label: l10n.opdRoutePharmacyAction,
                icon: Icons.local_pharmacy_outlined,
                enabled: !terminal,
                onPressed: () => _openNested(
                  context,
                  StageRouteDialog(
                    flow: flow,
                    title: l10n.opdRoutePharmacyAction,
                    stage: 'PHARMACY_REQUESTED',
                  ),
                ),
              ),
              _OpdWorkflowAction(
                requirement: _opdDoctorRequirement,
                label: l10n.opdCorrectStageAction,
                icon: Icons.sync_alt_outlined,
                enabled: !terminal,
                onPressed: () =>
                    _openNested(context, CorrectStageDialog(flow: flow)),
              ),
            ],
          ),
          _OpdWorkflowSection(
            title: l10n.opdWorkflowPrintTitle,
            children: <Widget>[
              _OpdWorkflowAction(
                requirement: _opdTriageRequirement,
                label: l10n.opdPrintSummaryAction,
                icon: Icons.print_outlined,
                onPressed: () => _openNested(
                  context,
                  PrintOpdSummaryDialog(flow: flow, detail: detail),
                  closeParentOnChange: false,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  Future<void> _openNested(
    BuildContext context,
    Widget dialog, {
    bool closeParentOnChange = true,
  }) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    if (changed == true && closeParentOnChange && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _OpdWorkflowStatusSummary extends StatelessWidget {
  const _OpdWorkflowStatusSummary({required this.flow, required this.detail});

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<Widget> children = <Widget>[
      _OpdWorkflowInfoPill(
        label: l10n.opdStageLabel,
        value: _apiLabel(flow.stage ?? ''),
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdNextStepColumnLabel,
        value: _apiLabel(flow.nextStep ?? ''),
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdPaymentStatusLabel,
        value: detail == null
            ? l10n.profileUnknownValue
            : detail!.consultationPaid
            ? l10n.opdPaymentPaidLabel
            : detail!.consultationPaymentRequired
            ? l10n.opdPaymentRequiredLabel
            : l10n.opdPaymentNotRequiredLabel,
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdProviderColumnLabel,
        value: flow.providerDisplayName ?? l10n.profileUnknownValue,
      ),
    ];

    return _OpdWorkflowPanel(children: children);
  }
}

class _OpdWorkflowRecordSummary extends StatelessWidget {
  const _OpdWorkflowRecordSummary({required this.detail});

  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final OpdFlowDetail? value = detail;
    final List<Widget> children = <Widget>[
      _OpdWorkflowInfoPill(
        label: l10n.opdVitalsSummaryLabel,
        value: '${value?.vitalSigns.length ?? 0}',
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdServicesSummaryLabel,
        value:
            '${(value?.labOrders.length ?? 0) + (value?.radiologyOrders.length ?? 0) + (value?.pharmacyOrders.length ?? 0)}',
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdClinicalNotesSummaryLabel,
        value: '${value?.clinicalNotes.length ?? 0}',
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdProceduresSummaryLabel,
        value: '${value?.procedures.length ?? 0}',
      ),
    ];

    return _OpdWorkflowPanel(children: children);
  }
}

class _OpdWorkflowPanel extends StatelessWidget {
  const _OpdWorkflowPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.sm,
          children: children,
        ),
      ),
    );
  }
}

class _OpdWorkflowInfoPill extends StatelessWidget {
  const _OpdWorkflowInfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelMedium),
          SizedBox(height: theme.spacing.xs),
          Text(
            value.isEmpty ? context.l10n.profileUnknownValue : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpdWorkflowSection extends StatelessWidget {
  const _OpdWorkflowSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleSmall),
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpdWorkflowAction extends StatelessWidget {
  const _OpdWorkflowAction({
    required this.requirement,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final AccessRequirement requirement;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppAccessActionGate(
      requirement: requirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: 220,
          child: AppButton.secondary(
            label: label,
            leadingIcon: icon,
            fullWidth: true,
            enabled: enabled,
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}

bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
  return left.id == right.id ||
      (left.publicId != null && left.publicId == right.publicId);
}

class StageRouteDialog extends ConsumerStatefulWidget {
  const StageRouteDialog({
    required this.flow,
    required this.title,
    required this.stage,
    super.key,
  });

  final OpdFlowSummary flow;
  final String title;
  final String stage;

  @override
  ConsumerState<StageRouteDialog> createState() => _StageRouteDialogState();
}

class _StageRouteDialogState extends ConsumerState<StageRouteDialog> {
  late final TextEditingController _reasonController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.sync_alt_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          _StatusBadge(value: widget.stage),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.opdReasonLabel,
            enabled: !_isSaving,
            maxLines: 3,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdSaveAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_isNonEmpty(_reasonController.text)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .correctStage(widget.flow, widget.stage, _reasonController.text.trim());
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

class RecordVitalsDialog extends ConsumerStatefulWidget {
  const RecordVitalsDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<RecordVitalsDialog> createState() => _RecordVitalsDialogState();
}

class _RecordVitalsDialogState extends ConsumerState<RecordVitalsDialog> {
  late final TextEditingController _temperatureController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenSaturationController;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  String? _triageLevel;
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
    _oxygenSaturationController = TextEditingController();
    _weightController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdRecordVitalsAction),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppSelectField<String>.searchable(
            value: _triageLevel,
            labelText: l10n.opdTriageLevelLabel,
            semanticLabel: l10n.opdTriageLevelLabel,
            enabled: !_isSaving,
            onChanged: (String? value) => setState(() => _triageLevel = value),
            options: _statusOptions(_triageLevelOptions),
          ),
          AppTextField(
            controller: _temperatureController,
            labelText: l10n.opdTemperatureLabel,
            enabled: !_isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _decimalInputFormatters,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _systolicController,
                  labelText: l10n.opdSystolicLabel,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalInputFormatters,
                ),
              ),
              SizedBox(width: Theme.of(context).spacing.md),
              Expanded(
                child: AppTextField(
                  controller: _diastolicController,
                  labelText: l10n.opdDiastolicLabel,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalInputFormatters,
                ),
              ),
            ],
          ),
          AppTextField(
            controller: _heartRateController,
            labelText: l10n.opdHeartRateLabel,
            enabled: !_isSaving,
            keyboardType: TextInputType.number,
            inputFormatters: _integerInputFormatters,
          ),
          AppTextField(
            controller: _respiratoryRateController,
            labelText: l10n.opdRespiratoryRateLabel,
            enabled: !_isSaving,
            keyboardType: TextInputType.number,
            inputFormatters: _integerInputFormatters,
          ),
          AppTextField(
            controller: _oxygenSaturationController,
            labelText: l10n.opdOxygenSaturationLabel,
            enabled: !_isSaving,
            keyboardType: TextInputType.number,
            inputFormatters: _integerInputFormatters,
          ),
          AppTextField(
            controller: _weightController,
            labelText: l10n.opdWeightLabel,
            enabled: !_isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _decimalInputFormatters,
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.opdTriageNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdRecordVitalsAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final List<Map<String, Object?>> vitals = _vitalsPayload();
    if (vitals.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .recordVitals(widget.flow, <String, Object?>{
          'vitals': vitals,
          'triage_level': _triageLevel,
          'triage_notes': _notesController.text.trim(),
        });
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

  List<Map<String, Object?>> _vitalsPayload() {
    final List<Map<String, Object?>> vitals = <Map<String, Object?>>[];
    void addSimpleVital(
      TextEditingController controller,
      String type,
      String unit,
    ) {
      final String value = controller.text.trim();
      if (value.isEmpty) {
        return;
      }
      vitals.add(<String, Object?>{
        'vital_type': type,
        'value': value,
        'unit': unit,
      });
    }

    addSimpleVital(_temperatureController, 'TEMPERATURE', 'C');
    final String systolic = _systolicController.text.trim();
    final String diastolic = _diastolicController.text.trim();
    if (systolic.isNotEmpty && diastolic.isNotEmpty) {
      vitals.add(<String, Object?>{
        'vital_type': 'BLOOD_PRESSURE',
        'value': '$systolic/$diastolic',
        'unit': 'mmHg',
        'systolic_value': systolic,
        'diastolic_value': diastolic,
      });
    }
    addSimpleVital(_heartRateController, 'HEART_RATE', 'bpm');
    addSimpleVital(
      _respiratoryRateController,
      'RESPIRATORY_RATE',
      'breaths/min',
    );
    addSimpleVital(_oxygenSaturationController, 'OXYGEN_SATURATION', '%');
    addSimpleVital(_weightController, 'WEIGHT', 'kg');
    return vitals;
  }
}

class DoctorReviewDialog extends ConsumerStatefulWidget {
  const DoctorReviewDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<DoctorReviewDialog> createState() => _DoctorReviewDialogState();
}

class _DoctorReviewDialogState extends ConsumerState<DoctorReviewDialog> {
  late final TextEditingController _noteController;
  late final TextEditingController _diagnosisCodeController;
  late final TextEditingController _diagnosisController;
  late final TextEditingController _procedureCodeController;
  late final TextEditingController _procedureController;
  late final TextEditingController _labTestIdsController;
  late final TextEditingController _labPanelIdsController;
  late final TextEditingController _radiologyIdsController;
  late final TextEditingController _quantityController;
  late final TextEditingController _dosageController;
  late final TextEditingController _prescriptionNotesController;
  List<OpdDrugOption> _drugOptions = const <OpdDrugOption>[];
  bool _isLoadingDrugs = false;
  String _diagnosisType = 'PRIMARY';
  String? _drugId;
  String? _frequency;
  String? _route;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _diagnosisCodeController = TextEditingController();
    _diagnosisController = TextEditingController();
    _procedureCodeController = TextEditingController();
    _procedureController = TextEditingController();
    _labTestIdsController = TextEditingController();
    _labPanelIdsController = TextEditingController();
    _radiologyIdsController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _dosageController = TextEditingController();
    _prescriptionNotesController = TextEditingController();
    unawaited(_loadDrugs());
  }

  @override
  void dispose() {
    _noteController.dispose();
    _diagnosisCodeController.dispose();
    _diagnosisController.dispose();
    _procedureCodeController.dispose();
    _procedureController.dispose();
    _labTestIdsController.dispose();
    _labPanelIdsController.dispose();
    _radiologyIdsController.dispose();
    _quantityController.dispose();
    _dosageController.dispose();
    _prescriptionNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdDoctorReviewAction),
      icon: const Icon(Icons.edit_note_outlined),
      maxWidth: 760,
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTextField(
            controller: _noteController,
            labelText: l10n.opdClinicalNoteLabel,
            enabled: !_isSaving,
            maxLines: 4,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppSelectField<String>.searchable(
            value: _diagnosisType,
            labelText: l10n.opdDiagnosisTypeLabel,
            semanticLabel: l10n.opdDiagnosisTypeLabel,
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() => _diagnosisType = value ?? _diagnosisType);
            },
            options: _statusOptions(_diagnosisTypes),
          ),
          AppTextField(
            controller: _diagnosisController,
            labelText: l10n.opdDiagnosisLabel,
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppTextField(
            controller: _diagnosisCodeController,
            labelText: l10n.opdDiagnosisCodeLabel,
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _procedureController,
            labelText: l10n.opdProcedureLabel,
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppTextField(
            controller: _procedureCodeController,
            labelText: l10n.opdProcedureCodeLabel,
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _labTestIdsController,
            labelText: l10n.opdLabTestIdsLabel,
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppTextField(
            controller: _labPanelIdsController,
            labelText: l10n.opdLabPanelIdsLabel,
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppTextField(
            controller: _radiologyIdsController,
            labelText: l10n.opdRadiologyTestIdsLabel,
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppSelectField<String>.searchable(
            value: _drugId,
            labelText: l10n.opdDrugLabel,
            semanticLabel: l10n.opdDrugLabel,
            enabled: !_isSaving,
            isLoading: _isLoadingDrugs,
            onChanged: (String? value) => setState(() => _drugId = value),
            options: _drugOptions.map(_drugOption).toList(growable: false),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _quantityController,
                  labelText: l10n.opdDrugQuantityLabel,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerInputFormatters,
                ),
              ),
              SizedBox(width: Theme.of(context).spacing.md),
              Expanded(
                child: AppTextField(
                  controller: _dosageController,
                  labelText: l10n.opdDosageLabel,
                  enabled: !_isSaving,
                ),
              ),
            ],
          ),
          AppSelectField<String>.searchable(
            value: _frequency,
            labelText: l10n.opdFrequencyLabel,
            semanticLabel: l10n.opdFrequencyLabel,
            enabled: !_isSaving,
            onChanged: (String? value) => setState(() => _frequency = value),
            options: _statusOptions(_medicationFrequencies),
          ),
          AppSelectField<String>.searchable(
            value: _route,
            labelText: l10n.opdMedicationRouteLabel,
            semanticLabel: l10n.opdMedicationRouteLabel,
            enabled: !_isSaving,
            onChanged: (String? value) => setState(() => _route = value),
            options: _statusOptions(_medicationRoutes),
          ),
          AppTextField(
            controller: _prescriptionNotesController,
            labelText: l10n.opdPrescriptionNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdDoctorReviewAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _loadDrugs() async {
    setState(() => _isLoadingDrugs = true);
    final Result<List<OpdDrugOption>> result = await ref
        .read(opdRepositoryProvider)
        .listAvailableDrugs();
    if (!mounted) {
      return;
    }
    result.when(
      success: (List<OpdDrugOption> drugs) {
        setState(() {
          _drugOptions = drugs;
          _isLoadingDrugs = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingDrugs = false;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!_isNonEmpty(_noteController.text)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    final Map<String, Object?> payload = _payload();
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .doctorReview(widget.flow, payload);
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

  Map<String, Object?> _payload() {
    final List<Map<String, Object?>> labRequests = <Map<String, Object?>>[
      for (final String id in _splitTokens(_labTestIdsController.text))
        <String, Object?>{'lab_test_id': id, 'status': 'ORDERED'},
      for (final String id in _splitTokens(_labPanelIdsController.text))
        <String, Object?>{'lab_panel_id': id, 'status': 'ORDERED'},
    ];
    final List<Map<String, Object?>> radiologyRequests = <Map<String, Object?>>[
      for (final String id in _splitTokens(_radiologyIdsController.text))
        <String, Object?>{'radiology_test_id': id, 'status': 'ORDERED'},
    ];
    final String? drugId = _drugId;
    final int quantity = int.tryParse(_quantityController.text.trim()) ?? 1;

    return <String, Object?>{
      'note': _noteController.text.trim(),
      if (_isNonEmpty(_diagnosisController.text))
        'diagnoses': <Map<String, Object?>>[
          <String, Object?>{
            'diagnosis_type': _diagnosisType,
            'code': _diagnosisCodeController.text.trim(),
            'description': _diagnosisController.text.trim(),
          },
        ],
      if (_isNonEmpty(_procedureController.text))
        'procedures': <Map<String, Object?>>[
          <String, Object?>{
            'code': _procedureCodeController.text.trim(),
            'description': _procedureController.text.trim(),
            'performed_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      if (labRequests.isNotEmpty) 'lab_requests': labRequests,
      if (radiologyRequests.isNotEmpty) 'radiology_requests': radiologyRequests,
      if (_isNonEmpty(drugId))
        'medications': <Map<String, Object?>>[
          <String, Object?>{
            'drug_id': drugId,
            'quantity': quantity,
            'dosage': _dosageController.text.trim(),
            'frequency': _frequency,
            'route': _route,
            'status': 'ACTIVE',
          },
        ],
      'notes': _prescriptionNotesController.text.trim(),
    };
  }
}

class PrintOpdSummaryDialog extends StatelessWidget {
  const PrintOpdSummaryDialog({
    required this.flow,
    required this.detail,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String summary = _printSummary(context);
    return AppDialog(
      title: Text(l10n.opdPrintSummaryAction),
      icon: const Icon(Icons.print_outlined),
      maxWidth: 720,
      scrollable: true,
      content: SelectionArea(
        child: Text(summary, style: Theme.of(context).textTheme.bodyMedium),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.secondary(
          label: l10n.opdCopySummaryAction,
          leadingIcon: Icons.copy_outlined,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: summary));
            if (context.mounted) {
              Navigator.of(context).pop(false);
            }
          },
        ),
        AppButton.primary(
          label: l10n.opdPrintAction,
          leadingIcon: Icons.print_outlined,
          onPressed: () {
            printCurrentWindow();
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }

  String _printSummary(BuildContext context) {
    final l10n = context.l10n;
    final OpdFlowDetail? value = detail;
    final List<String> lines = <String>[
      flow.displayTitle,
      _joinDisplay(<String?>[
        flow.patientIdentifier,
        flow.patientPhone,
        flow.providerDisplayName,
      ]),
      '${l10n.opdStageLabel}: ${_apiLabel(flow.stage ?? '')}',
      '${l10n.opdNextStepColumnLabel}: ${_apiLabel(flow.nextStep ?? '')}',
      '${l10n.opdPaymentStatusLabel}: ${value == null
          ? l10n.profileUnknownValue
          : value.consultationPaid
          ? l10n.opdPaymentPaidLabel
          : value.consultationPaymentRequired
          ? l10n.opdPaymentRequiredLabel
          : l10n.opdPaymentNotRequiredLabel}',
      '${l10n.opdVitalsSummaryLabel}: ${value?.vitalSigns.length ?? 0}',
      '${l10n.opdClinicalNotesSummaryLabel}: ${value?.clinicalNotes.length ?? 0}',
      '${l10n.opdServicesSummaryLabel}: ${(value?.labOrders.length ?? 0) + (value?.radiologyOrders.length ?? 0) + (value?.pharmacyOrders.length ?? 0)}',
      if (value != null && value.vitalSigns.isNotEmpty) '',
      if (value != null && value.vitalSigns.isNotEmpty)
        l10n.opdVitalsSummaryLabel,
      if (value != null)
        for (final OpdRelatedRecord vital in value.vitalSigns)
          _joinDisplay(<String?>[vital.title, vital.subtitle]),
      if (value != null && value.timeline.isNotEmpty) '',
      if (value != null && value.timeline.isNotEmpty) l10n.opdTimelineTitle,
      if (value != null)
        for (final OpdTimelineItem item in value.timeline)
          _joinDisplay(<String?>[
            _apiLabel(item.action),
            _apiLabel(item.stage ?? ''),
            item.notes,
          ]),
    ];
    return lines.where((String line) => line.trim().isNotEmpty).join('\n');
  }
}

class AssignDoctorDialog extends ConsumerStatefulWidget {
  const AssignDoctorDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<AssignDoctorDialog> createState() => _AssignDoctorDialogState();
}

class _AssignDoctorDialogState extends ConsumerState<AssignDoctorDialog> {
  late final TextEditingController _providerController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _providerController = TextEditingController();
  }

  @override
  void dispose() {
    _providerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdAssignDoctorAction),
      icon: const Icon(Icons.assignment_ind_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTextField(
            controller: _providerController,
            labelText: l10n.opdProviderIdLabel,
            enabled: !_isSaving,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdAssignDoctorAction,
          leadingIcon: Icons.assignment_ind_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .assignDoctor(widget.flow, _providerController.text.trim());
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

class ConsultationPaymentDialog extends ConsumerStatefulWidget {
  const ConsultationPaymentDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<ConsultationPaymentDialog> createState() =>
      _ConsultationPaymentDialogState();
}

class _ConsultationPaymentDialogState
    extends ConsumerState<ConsultationPaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;
  String _currency = appDefaultCurrencyCode;
  String _method = 'CASH';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdPayConsultationAction),
      icon: const Icon(Icons.payments_outlined),
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppCurrencyAmountField(
            amountController: _amountController,
            currency: _currency,
            amountLabelText: l10n.opdAmountLabel,
            currencyLabelText: l10n.opdCurrencyLabel,
            enabled: !_isSaving,
            onCurrencyChanged: (String? value) {
              setState(() {
                _currency = value ?? appDefaultCurrencyCode;
              });
            },
          ),
          AppSelectField<String>(
            value: _method,
            labelText: l10n.opdPaymentMethodLabel,
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() => _method = value ?? _method);
            },
            options: _statusOptions(_paymentMethods),
          ),
          AppTextField(
            controller: _referenceController,
            labelText: l10n.opdTransactionReferenceLabel,
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.opdNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdPayConsultationAction,
          leadingIcon: Icons.payments_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .payConsultation(widget.flow, <String, Object?>{
          'amount': normalizeCurrencyAmount(_amountController.text),
          'currency': _currency,
          'method': _method,
          'status': 'COMPLETED',
          'transaction_ref': _referenceController.text.trim(),
          'notes': _notesController.text.trim(),
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        });
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

class CorrectStageDialog extends ConsumerStatefulWidget {
  const CorrectStageDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<CorrectStageDialog> createState() => _CorrectStageDialogState();
}

class _CorrectStageDialogState extends ConsumerState<CorrectStageDialog> {
  late final TextEditingController _reasonController;
  String _stage = _flowStages.first;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _stage = widget.flow.stage ?? _flowStages.first;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdCorrectStageAction),
      icon: const Icon(Icons.edit_note_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppSelectField<String>(
            value: _stage,
            labelText: l10n.opdStageLabel,
            enabled: !_isSaving,
            onChanged: (String? value) =>
                setState(() => _stage = value ?? _stage),
            options: _statusOptions(_flowStages),
          ),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.opdReasonLabel,
            enabled: !_isSaving,
            maxLines: 3,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdSaveAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .correctStage(widget.flow, _stage, _reasonController.text.trim());
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

class ReferralDialog extends ConsumerStatefulWidget {
  const ReferralDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<ReferralDialog> createState() => _ReferralDialogState();
}

class _ReferralDialogState extends ConsumerState<ReferralDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _facilityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _facilityController = TextEditingController();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _facilityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdReferAction),
      icon: const Icon(Icons.alt_route_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _facilityController,
              labelText: l10n.opdExternalFacilityLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.opdReasonLabel,
              enabled: !_isSaving,
              maxLines: 3,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.opdNotesLabel,
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
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdReferAction,
          leadingIcon: Icons.alt_route_outlined,
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
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .createReferral(
          flow: widget.flow,
          externalFacilityName: _facilityController.text.trim(),
          reason: _reasonController.text.trim(),
          notes: _notesController.text.trim(),
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
      _isSaving = false;
    });
  }
}

class FollowUpDialog extends ConsumerStatefulWidget {
  const FollowUpDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends ConsumerState<FollowUpDialog> {
  late final TextEditingController _dateController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdFollowUpAction),
      icon: const Icon(Icons.event_repeat_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTextField(
            controller: _dateController,
            labelText: l10n.opdFollowUpDateLabel,
            hintText: l10n.opdDateTimeHint,
            enabled: !_isSaving,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.opdNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdFollowUpAction,
          leadingIcon: Icons.event_repeat_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final DateTime? scheduledAt = DateTime.tryParse(
      _dateController.text.trim(),
    );
    if (scheduledAt == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .createFollowUp(
          flow: widget.flow,
          scheduledAt: scheduledAt,
          notes: _notesController.text.trim(),
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
      _isSaving = false;
    });
  }
}

class DispositionDialog extends ConsumerStatefulWidget {
  const DispositionDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<DispositionDialog> createState() => _DispositionDialogState();
}

class _DispositionDialogState extends ConsumerState<DispositionDialog> {
  late final TextEditingController _notesController;
  String _decision = 'DISCHARGE';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdDispositionAction),
      icon: const Icon(Icons.task_alt_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppSelectField<String>(
            value: _decision,
            labelText: l10n.opdDecisionLabel,
            enabled: !_isSaving,
            onChanged: (String? value) =>
                setState(() => _decision = value ?? _decision),
            options: _statusOptions(_dispositionOptions),
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.opdNotesLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdDispositionAction,
          leadingIcon: Icons.task_alt_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .disposeFlow(widget.flow, _decision, _notesController.text.trim());
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

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

AppSelectOption<String> _drugOption(OpdDrugOption drug) {
  return AppSelectOption<String>(
    value: drug.apiId,
    label: _joinDisplay(<String?>[
      drug.displayTitle,
      drug.form,
      drug.strength,
      drug.availableQuantity?.toString(),
    ]),
  );
}

AppSelectOption<String>? _patientSelectOption(Patient patient) {
  final String? value = patient.publicId;
  if (!_isNonEmpty(value)) {
    return null;
  }

  return AppSelectOption<String>(
    value: value!,
    label: _joinDisplay(<String?>[
      patient.effectiveDisplayName,
      patient.effectiveIdentifier,
      patient.primaryPhone,
    ]),
  );
}

AppSelectOption<String>? _appointmentSelectOption(OpdAppointment appointment) {
  final String value = appointment.publicId ?? appointment.id;
  if (!_isNonEmpty(value)) {
    return null;
  }

  return AppSelectOption<String>(
    value: value,
    label: _joinDisplay(<String?>[
      appointment.displayTitle,
      appointment.patientIdentifier,
      appointment.patientPhone,
      appointment.providerDisplayName,
      appointment.status,
    ]),
  );
}

List<OpdAppointment> _eligibleAppointmentOptions(
  Iterable<OpdAppointment> appointments,
) {
  final Map<String, OpdAppointment> options = <String, OpdAppointment>{};

  for (final OpdAppointment appointment in appointments) {
    final String value = appointment.publicId ?? appointment.id;
    if (!_isNonEmpty(value) ||
        _isTerminalAppointmentStatus(appointment.status)) {
      continue;
    }

    options[value] = appointment;
  }

  return options.values.toList(growable: false);
}

bool _isTerminalAppointmentStatus(String? status) {
  return switch (status?.toUpperCase()) {
    'CANCELLED' || 'NO_SHOW' || 'COMPLETED' => true,
    _ => false,
  };
}

List<AppSelectOption<String>> _providerSelectOptions({
  required List<OpdProviderOption> providers,
  required List<OpdProviderSchedule> schedules,
}) {
  final Map<String, AppSelectOption<String>> options =
      <String, AppSelectOption<String>>{};

  for (final OpdProviderOption provider in providers) {
    final String value = provider.id;
    if (!_isNonEmpty(value) || options.containsKey(value)) {
      continue;
    }
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[
        provider.displayTitle,
        provider.positionTitle,
        provider.practitionerType,
        provider.staffProfileId,
        value,
      ]),
    );
  }

  for (final OpdProviderSchedule schedule in schedules) {
    final String value = schedule.providerApiId;
    if (!_isNonEmpty(value) || options.containsKey(value)) {
      continue;
    }
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[
        schedule.providerDisplayName,
        value,
        schedule.facilityName,
      ]),
    );
  }

  return options.values.toList(growable: false);
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }

  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

List<String> _splitTokens(String value) {
  return value
      .split(RegExp(r'[,;\n]+'))
      .map((String token) => token.trim())
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

AppWorkspaceStatusTone _stageTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'COMPLETED' || 'DISCHARGED' || 'ADMITTED' => AppWorkspaceStatusTone.success,
    'CANCELLED' || 'NO_SHOW' => AppWorkspaceStatusTone.error,
    'WAITING_CONSULTATION_PAYMENT' ||
    'WAITING_VITALS' ||
    'WAITING_DOCTOR_ASSIGNMENT' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' ||
    'WAITING_DOCTOR_REVIEW' ||
    'WAITING_DISPOSITION' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

const String _opdCategoryArrival = 'ARRIVAL';
const String _opdCategoryQueue = 'QUEUE';
const String _opdCategoryActiveFlow = 'ACTIVE_FLOW';
const String _opdFilterAll = 'ALL';

const List<String> _queueStatuses = <String>[
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW',
];

const List<String> _arrivalModeOptions = <String>['WALK_IN', 'EMERGENCY'];

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

const List<String> _flowStages = <String>[
  'WAITING_CONSULTATION_PAYMENT',
  'WAITING_VITALS',
  'WAITING_DOCTOR_ASSIGNMENT',
  'WAITING_DOCTOR_REVIEW',
  'LAB_REQUESTED',
  'RADIOLOGY_REQUESTED',
  'LAB_AND_RADIOLOGY_REQUESTED',
  'PHARMACY_REQUESTED',
  'WAITING_DISPOSITION',
  'ADMITTED',
  'DISCHARGED',
];

const List<String> _paymentMethods = <String>[
  'CASH',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'CREDIT_CARD',
  'INSURANCE',
  'OTHER',
];

const List<String> _dispositionOptions = <String>[
  'DISCHARGE',
  'ADMIT',
  'SEND_TO_PHARMACY',
];

const List<String> _diagnosisTypes = <String>[
  'PRIMARY',
  'SECONDARY',
  'DIFFERENTIAL',
];

const List<String> _medicationFrequencies = <String>[
  'ONCE',
  'BID',
  'TID',
  'QID',
  'PRN',
  'STAT',
  'CUSTOM',
];

const List<String> _medicationRoutes = <String>[
  'ORAL',
  'IV',
  'IM',
  'TOPICAL',
  'INHALATION',
  'OTHER',
];

final List<TextInputFormatter> _decimalInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];

final List<TextInputFormatter> _integerInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

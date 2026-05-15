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
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
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

class _OpdWorkspaceContent extends ConsumerWidget {
  const _OpdWorkspaceContent({required this.state});

  final OpdWorkspaceState state;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
      filters: _OpdFilters(state: state),
      body: _OpdWorkspaceBody(state: state),
      detail: _FlowDetailPanel(state: state),
    );
  }

  Future<void> _openStartWalkInDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StartWalkInDialog(
        providerSchedules: state.providerSchedules,
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

class _OpdFilters extends ConsumerStatefulWidget {
  const _OpdFilters({required this.state});

  final OpdWorkspaceState state;

  @override
  ConsumerState<_OpdFilters> createState() => _OpdFiltersState();
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

class _OpdFiltersState extends ConsumerState<_OpdFilters> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _search = widget.state.flowQuery.search;
    _searchController = TextEditingController(text: _search);
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _OpdFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextSearch = widget.state.flowQuery.search;
    if (nextSearch != _search && nextSearch != _searchController.text) {
      _search = nextSearch;
      _searchController.text = nextSearch;
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

    return AppWorkspaceFilterBar(
      semanticLabel: l10n.opdFiltersLabel,
      expandSearch: true,
      search: AppTextField(
        controller: _searchController,
        semanticLabel: l10n.opdSearchLabel,
        hintText: l10n.opdSearchHint,
        prefixIcon: const Icon(Icons.search),
        textInputAction: TextInputAction.search,
        onFieldSubmitted: (_) => _applySearchImmediately(),
      ),
    );
  }

  void _handleSearchChanged() {
    final String value = _searchController.text.trim();
    if (value == _search) {
      return;
    }
    _search = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        unawaited(_applySearch());
      }
    });
  }

  void _applySearchImmediately() {
    _searchDebounce?.cancel();
    unawaited(_applySearch());
  }

  Future<void> _applySearch() async {
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .applySearch(_searchController.text);
    if (mounted) {
      _showFailureIfNeeded(context, failure);
    }
  }
}

class _OpdWorkspaceBody extends StatelessWidget {
  const _OpdWorkspaceBody({required this.state});

  final OpdWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ArrivalsPanel(state: state),
        SizedBox(height: theme.spacing.lg),
        _QueueBoardPanel(state: state),
        SizedBox(height: theme.spacing.lg),
        _FlowsPanel(state: state),
        SizedBox(height: theme.spacing.lg),
        _ProviderReadinessPanel(state: state),
      ],
    );
  }
}

class _ArrivalsPanel extends ConsumerWidget {
  const _ArrivalsPanel({required this.state});

  final OpdWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);

    return _SectionPanel(
      title: l10n.opdArrivalsTitle,
      icon: Icons.event_available_outlined,
      child: AppPaginatedDataList<OpdAppointment>(
        page: state.appointments,
        isLoading: state.isRefreshingAppointments,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        pageLabelBuilder: (AppPage<OpdAppointment> page) => l10n.opdPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.items.length,
        ),
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        onPageChanged: (AppPageRequest request) {
          ref
              .read(opdWorkspaceControllerProvider.notifier)
              .changeAppointmentPage(request);
        },
        emptyBuilder: (_) => _EmptyPanel(
          title: l10n.opdNoArrivalsTitle,
          body: l10n.opdNoArrivalsBody,
        ),
        columns: <AppDataColumn<OpdAppointment>>[
          AppDataColumn<OpdAppointment>(
            label: l10n.opdPatientColumnLabel,
            cellBuilder: (_, OpdAppointment item) => _PatientText(
              title: item.displayTitle,
              subtitle: item.patientPhone,
            ),
          ),
          AppDataColumn<OpdAppointment>(
            label: l10n.opdStatusColumnLabel,
            cellBuilder: (_, OpdAppointment item) =>
                _StatusBadge(value: item.status),
          ),
          AppDataColumn<OpdAppointment>(
            label: l10n.opdTimeColumnLabel,
            cellBuilder: (_, OpdAppointment item) =>
                Text(_formatDateTime(context, item.scheduledStart)),
          ),
          AppDataColumn<OpdAppointment>(
            label: l10n.opdProviderColumnLabel,
            cellBuilder: (_, OpdAppointment item) =>
                Text(item.providerDisplayName ?? l10n.profileUnknownValue),
          ),
          AppDataColumn<OpdAppointment>(
            label: l10n.opdActionsColumnLabel,
            cellBuilder: (_, OpdAppointment item) => AppIconButton(
              icon: Icons.more_horiz,
              semanticLabel: l10n.opdOpenActions,
              tooltip: l10n.opdOpenActions,
              onPressed: () {
                _openAppointmentActions(context, ref, item);
              },
            ),
          ),
        ],
        mobileItemBuilder: (_, OpdAppointment item) => _MobileRecordRow(
          title: item.displayTitle,
          subtitle: _joinDisplay(<String?>[
            item.reason,
            item.providerDisplayName,
            item.scheduledStart == null
                ? null
                : AppFormatters.dateTime(item.scheduledStart!, locale),
          ]),
          status: item.status,
          onPressed: () {
            _openAppointmentActions(context, ref, item);
          },
        ),
        itemKeyBuilder: (OpdAppointment item) => ValueKey<String>(item.id),
      ),
    );
  }

  Future<void> _openAppointmentActions(
    BuildContext context,
    WidgetRef ref,
    OpdAppointment appointment,
  ) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppointmentActionsDialog(appointment: appointment),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }
}

class _QueueBoardPanel extends ConsumerWidget {
  const _QueueBoardPanel({required this.state});

  final OpdWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Map<String, List<OpdQueueEntry>> grouped =
        <String, List<OpdQueueEntry>>{
          for (final String status in _queueStatuses)
            status: state.queueEntries.items
                .where((OpdQueueEntry entry) => entry.status == status)
                .toList(growable: false),
        };

    return _SectionPanel(
      title: l10n.opdQueueBoardTitle,
      icon: Icons.queue_outlined,
      trailing: state.isRefreshingQueue
          ? SizedBox.square(
              dimension: theme.appTokens.listIconSize,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: state.queueEntries.items.isEmpty && !state.isRefreshingQueue
          ? _EmptyPanel(title: l10n.opdNoQueueTitle, body: l10n.opdNoQueueBody)
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = constraints.maxWidth >= 980
                    ? 3
                    : constraints.maxWidth >= 640
                    ? 2
                    : 1;
                final double gap = theme.spacing.sm;
                final double itemWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final String status in _queueStatuses)
                      SizedBox(
                        width: itemWidth,
                        child: _QueueStatusColumn(
                          status: status,
                          entries: grouped[status] ?? const <OpdQueueEntry>[],
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _QueueStatusColumn extends ConsumerWidget {
  const _QueueStatusColumn({required this.status, required this.entries});

  final String status;
  final List<OpdQueueEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _apiLabel(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  AppFormatters.compactNumber(
                    entries.length,
                    Localizations.localeOf(context),
                  ),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            if (entries.isEmpty)
              Text(
                context.l10n.opdQueueEmptyColumnLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final OpdQueueEntry entry in entries.take(4)) ...<Widget>[
                _QueueCard(entry: entry),
                SizedBox(height: theme.spacing.xs),
              ],
          ],
        ),
      ),
    );
  }
}

class _QueueCard extends ConsumerWidget {
  const _QueueCard({required this.entry});

  final OpdQueueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          showAppDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => QueueActionsDialog(entry: entry),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                _joinDisplay(<String?>[
                  entry.providerDisplayName,
                  entry.appointmentReason,
                  entry.patientPhone,
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowsPanel extends ConsumerWidget {
  const _FlowsPanel({required this.state});

  final OpdWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);

    return _SectionPanel(
      title: l10n.opdFlowsTitle,
      icon: Icons.medical_services_outlined,
      child: AppPaginatedDataList<OpdFlowSummary>(
        page: state.flows,
        isLoading: state.isRefreshingFlows,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        pageLabelBuilder: (AppPage<OpdFlowSummary> page) => l10n.opdPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.items.length,
        ),
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        onPageChanged: (AppPageRequest request) {
          ref
              .read(opdWorkspaceControllerProvider.notifier)
              .changeFlowPage(request);
        },
        emptyBuilder: (_) =>
            _EmptyPanel(title: l10n.opdNoFlowsTitle, body: l10n.opdNoFlowsBody),
        onRowSelected: (OpdFlowSummary flow) async {
          final AppFailure? failure = await ref
              .read(opdWorkspaceControllerProvider.notifier)
              .selectFlow(flow);
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        columns: <AppDataColumn<OpdFlowSummary>>[
          AppDataColumn<OpdFlowSummary>(
            label: l10n.opdPatientColumnLabel,
            cellBuilder: (_, OpdFlowSummary flow) => _PatientText(
              title: flow.displayTitle,
              subtitle: flow.patientPhone,
            ),
          ),
          AppDataColumn<OpdFlowSummary>(
            label: l10n.opdStageColumnLabel,
            cellBuilder: (_, OpdFlowSummary flow) =>
                _StatusBadge(value: flow.stage),
          ),
          AppDataColumn<OpdFlowSummary>(
            label: l10n.opdNextStepColumnLabel,
            cellBuilder: (_, OpdFlowSummary flow) =>
                Text(_apiLabel(flow.nextStep ?? flow.status ?? '')),
          ),
          AppDataColumn<OpdFlowSummary>(
            label: l10n.opdProviderColumnLabel,
            cellBuilder: (_, OpdFlowSummary flow) =>
                Text(flow.providerDisplayName ?? l10n.profileUnknownValue),
          ),
          AppDataColumn<OpdFlowSummary>(
            label: l10n.opdTimeColumnLabel,
            cellBuilder: (_, OpdFlowSummary flow) =>
                Text(_formatDateTime(context, flow.startedAt)),
          ),
        ],
        mobileItemBuilder: (_, OpdFlowSummary flow) => _MobileRecordRow(
          title: flow.displayTitle,
          subtitle: _joinDisplay(<String?>[
            _apiLabel(flow.stage ?? ''),
            flow.providerDisplayName,
            flow.startedAt == null
                ? null
                : AppFormatters.dateTime(flow.startedAt!, locale),
          ]),
          status: flow.stage,
          onPressed: () async {
            final AppFailure? failure = await ref
                .read(opdWorkspaceControllerProvider.notifier)
                .selectFlow(flow);
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
        itemKeyBuilder: (OpdFlowSummary flow) => ValueKey<String>(flow.id),
      ),
    );
  }
}

class _ProviderReadinessPanel extends ConsumerWidget {
  const _ProviderReadinessPanel({required this.state});

  final OpdWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);

    return _SectionPanel(
      title: l10n.opdProviderReadinessTitle,
      icon: Icons.badge_outlined,
      child: state.providerSchedules.isEmpty
          ? _EmptyPanel(
              title: l10n.opdNoProvidersTitle,
              body: l10n.opdNoProvidersBody,
            )
          : Column(
              children: <Widget>[
                for (final OpdProviderSchedule schedule
                    in state.providerSchedules) ...<Widget>[
                  _ProviderReadinessRow(
                    schedule: schedule,
                    slotCount: state.availabilitySlots
                        .where(
                          (OpdAvailabilitySlot slot) =>
                              slot.scheduleId == schedule.apiId ||
                              slot.scheduleId == schedule.publicId,
                        )
                        .length,
                    canAssign:
                        state.selectedFlow != null &&
                        schedule.providerApiId.isNotEmpty &&
                        !(state.selectedFlow?.summary.isTerminal ?? true),
                    timeLabel: _timeRange(
                      schedule.startTime,
                      schedule.endTime,
                      locale,
                    ),
                    onAssign: () async {
                      final OpdFlowSummary? flow = state.selectedFlow?.summary;
                      if (flow == null || schedule.providerApiId.isEmpty) {
                        return;
                      }
                      final AppFailure? failure = await ref
                          .read(opdWorkspaceControllerProvider.notifier)
                          .assignDoctor(flow, schedule.providerApiId);
                      if (context.mounted) {
                        _showFailureIfNeeded(context, failure);
                      }
                    },
                  ),
                  if (schedule != state.providerSchedules.last)
                    SizedBox(height: theme.spacing.xs),
                ],
              ],
            ),
    );
  }
}

class _ProviderReadinessRow extends StatelessWidget {
  const _ProviderReadinessRow({
    required this.schedule,
    required this.slotCount,
    required this.canAssign,
    required this.timeLabel,
    required this.onAssign,
  });

  final OpdProviderSchedule schedule;
  final int slotCount;
  final bool canAssign;
  final String timeLabel;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Row(
          children: <Widget>[
            const Icon(Icons.medical_information_outlined),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    schedule.providerDisplayName ??
                        context.l10n.profileUnknownValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    _joinDisplay(<String?>[
                      schedule.facilityName,
                      timeLabel,
                      context.l10n.opdAvailableSlotsLabel(slotCount),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            AppIconButton(
              icon: Icons.assignment_ind_outlined,
              semanticLabel: context.l10n.opdAssignDoctorAction,
              tooltip: context.l10n.opdAssignDoctorAction,
              onPressed: canAssign ? onAssign : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowDetailPanel extends ConsumerWidget {
  const _FlowDetailPanel({required this.state});

  final OpdWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OpdFlowDetail? detail = state.selectedFlow;
    final l10n = context.l10n;

    if (detail == null) {
      return AppWorkspaceStatePanel(
        child: AppStateView(
          title: l10n.opdNoFlowSelectedTitle,
          body: l10n.opdNoFlowSelectedBody,
        ),
      );
    }

    final OpdFlowSummary flow = detail.summary;

    return AppWorkspaceDetailPanel(
      title: flow.displayTitle,
      description: _joinDisplay(<String?>[
        flow.publicId,
        _apiLabel(flow.stage ?? ''),
        flow.providerDisplayName,
      ]),
      actions: <Widget>[
        AppIconButton(
          icon: Icons.close,
          semanticLabel: l10n.commonCancelActionLabel,
          tooltip: l10n.commonCancelActionLabel,
          onPressed: () {
            ref.read(opdWorkspaceControllerProvider.notifier).clearSelection();
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _FlowActionGrid(detail: detail),
          SizedBox(height: Theme.of(context).spacing.md),
          _DetailFacts(detail: detail),
          SizedBox(height: Theme.of(context).spacing.md),
          _DetailRelatedList(
            title: l10n.opdReferralsTitle,
            items: detail.referrals,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _DetailRelatedList(
            title: l10n.opdFollowUpsTitle,
            items: detail.followUps,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _TimelineList(items: detail.timeline),
        ],
      ),
    );
  }
}

class _FlowActionGrid extends ConsumerWidget {
  const _FlowActionGrid({required this.detail});

  final OpdFlowDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bool terminal = detail.summary.isTerminal;

    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      children: <Widget>[
        AppButton.secondary(
          label: l10n.opdAssignDoctorAction,
          leadingIcon: Icons.assignment_ind_outlined,
          enabled: !terminal,
          onPressed: () => _openAssignDoctor(context),
        ),
        AppButton.secondary(
          label: l10n.opdPayConsultationAction,
          leadingIcon: Icons.payments_outlined,
          enabled: !terminal,
          onPressed: () => _openPayment(context),
        ),
        AppButton.secondary(
          label: l10n.opdCorrectStageAction,
          leadingIcon: Icons.edit_note_outlined,
          enabled: !terminal,
          onPressed: () => _openCorrectStage(context),
        ),
        AppButton.secondary(
          label: l10n.opdReferAction,
          leadingIcon: Icons.alt_route_outlined,
          enabled: !terminal,
          onPressed: () => _openReferral(context),
        ),
        AppButton.secondary(
          label: l10n.opdFollowUpAction,
          leadingIcon: Icons.event_repeat_outlined,
          enabled: !terminal,
          onPressed: () => _openFollowUp(context),
        ),
        AppButton.primary(
          label: l10n.opdDispositionAction,
          leadingIcon: Icons.task_alt_outlined,
          enabled: !terminal,
          onPressed: () => _openDisposition(context),
        ),
      ],
    );
  }

  Future<void> _openAssignDoctor(BuildContext context) async {
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignDoctorDialog(flow: detail.summary),
    );
  }

  Future<void> _openPayment(BuildContext context) async {
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConsultationPaymentDialog(flow: detail.summary),
    );
  }

  Future<void> _openCorrectStage(BuildContext context) async {
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CorrectStageDialog(flow: detail.summary),
    );
  }

  Future<void> _openReferral(BuildContext context) async {
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReferralDialog(flow: detail.summary),
    );
  }

  Future<void> _openFollowUp(BuildContext context) async {
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FollowUpDialog(flow: detail.summary),
    );
  }

  Future<void> _openDisposition(BuildContext context) async {
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DispositionDialog(flow: detail.summary),
    );
  }
}

class _DetailFacts extends StatelessWidget {
  const _DetailFacts({required this.detail});

  final OpdFlowDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final OpdFlowSummary flow = detail.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FactRow(label: l10n.opdStageLabel, value: _apiLabel(flow.stage ?? '')),
        _FactRow(
          label: l10n.opdNextStepColumnLabel,
          value: _apiLabel(flow.nextStep ?? ''),
        ),
        _FactRow(
          label: l10n.opdProviderColumnLabel,
          value: flow.providerDisplayName ?? l10n.profileUnknownValue,
        ),
        _FactRow(
          label: l10n.opdPaymentStatusLabel,
          value: detail.consultationPaid
              ? l10n.opdPaymentPaidLabel
              : detail.consultationPaymentRequired
              ? l10n.opdPaymentRequiredLabel
              : l10n.opdPaymentNotRequiredLabel,
        ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: theme.textTheme.labelLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _DetailRelatedList extends StatelessWidget {
  const _DetailRelatedList({required this.title, required this.items});

  final String title;
  final List<OpdRelatedRecord> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleSmall),
        SizedBox(height: theme.spacing.xs),
        if (items.isEmpty)
          Text(
            context.l10n.opdNoRelatedRecordsLabel,
            style: theme.textTheme.bodySmall,
          )
        else
          for (final OpdRelatedRecord item in items.take(3))
            _CompactRelatedRow(item: item),
      ],
    );
  }
}

class _CompactRelatedRow extends StatelessWidget {
  const _CompactRelatedRow({required this.item});

  final OpdRelatedRecord item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item.title ?? item.id, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _joinDisplay(<String?>[item.status, item.subtitle]),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.items});

  final List<OpdTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.l10n.opdTimelineTitle, style: theme.textTheme.titleSmall),
        SizedBox(height: theme.spacing.xs),
        if (items.isEmpty)
          Text(
            context.l10n.opdNoTimelineLabel,
            style: theme.textTheme.bodySmall,
          )
        else
          for (final OpdTimelineItem item in items.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_outlined),
              title: Text(_apiLabel(item.action)),
              subtitle: Text(
                _joinDisplay(<String?>[
                  item.stage == null ? null : _apiLabel(item.stage!),
                  item.occurredAt == null
                      ? null
                      : AppFormatters.dateTime(item.occurredAt!, locale),
                  item.notes,
                ]),
              ),
            ),
      ],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Row(
              children: <Widget>[
                Icon(icon, color: colorScheme.primary),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: EdgeInsets.all(theme.spacing.md), child: child),
        ],
      ),
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
        Text(title, overflow: TextOverflow.ellipsis),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
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

class _MobileRecordRow extends StatelessWidget {
  const _MobileRecordRow({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String? status;
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
                  Text(title, style: theme.textTheme.titleSmall),
                  SizedBox(height: theme.spacing.xs),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            _StatusBadge(value: status),
          ],
        ),
      ),
    );
  }
}

class _ProviderSelectField extends StatelessWidget {
  const _ProviderSelectField({
    required this.value,
    required this.schedules,
    required this.labelText,
    required this.enabled,
    required this.onChanged,
  });

  final String? value;
  final List<OpdProviderSchedule> schedules;
  final String labelText;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<String>.searchable(
      value: value,
      options: _providerSelectOptions(schedules),
      labelText: labelText,
      semanticLabel: labelText,
      enabled: enabled,
      onChanged: onChanged,
    );
  }
}

class _CurrencySelectField extends StatelessWidget {
  const _CurrencySelectField({
    required this.value,
    required this.labelText,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final String labelText;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<String>.searchable(
      value: value,
      options: _currencyOptions
          .map(
            (String currency) =>
                AppSelectOption<String>(value: currency, label: currency),
          )
          .toList(growable: false),
      labelText: labelText,
      semanticLabel: labelText,
      enabled: enabled,
      onChanged: onChanged,
    );
  }
}

typedef OpdPayloadSubmit =
    Future<AppFailure?> Function(Map<String, Object?> payload);

class StartWalkInDialog extends ConsumerStatefulWidget {
  const StartWalkInDialog({
    required this.providerSchedules,
    required this.onSubmit,
    super.key,
  });

  final List<OpdProviderSchedule> providerSchedules;
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
  bool _registerNewPatient = false;
  bool _isLoadingPatients = false;
  String? _patientId;
  String? _providerId;
  String _currency = _defaultCurrency;
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
    unawaited(_loadPatientOptions());
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
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppCheckboxField(
              title: l10n.opdRegisterNewPatientLabel,
              value: _registerNewPatient,
              enabled: !_isSaving,
              onChanged: (bool value) {
                setState(() => _registerNewPatient = value);
              },
            ),
            if (!_registerNewPatient)
              AppSelectField<String>.searchable(
                value: _patientId,
                options: _patientOptions
                    .map(_patientSelectOption)
                    .whereType<AppSelectOption<String>>()
                    .toList(growable: false),
                labelText: l10n.opdPatientIdLabel,
                semanticLabel: l10n.opdPatientIdLabel,
                isLoading: _isLoadingPatients,
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _patientId = value;
                  });
                },
                validator: (String? value) =>
                    _registerNewPatient || _isNonEmpty(value)
                    ? null
                    : l10n.validationRequired,
              )
            else ...<Widget>[
              AppTextField(
                controller: _firstNameController,
                labelText: l10n.opdFirstNameLabel,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
              AppTextField(
                controller: _lastNameController,
                labelText: l10n.opdLastNameLabel,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
              AppSelectField<String>.searchable(
                value: _gender,
                labelText: l10n.opdGenderLabel,
                semanticLabel: l10n.opdGenderLabel,
                enabled: !_isSaving,
                onChanged: (String? value) => setState(() => _gender = value),
                options: _statusOptions(_genderOptions),
              ),
            ],
            _ProviderSelectField(
              value: _providerId,
              schedules: widget.providerSchedules,
              labelText: l10n.opdProviderIdLabel,
              enabled: !_isSaving,
              onChanged: (String? value) {
                setState(() {
                  _providerId = value;
                });
              },
            ),
            AppTextField(
              controller: _feeController,
              labelText: l10n.opdConsultationFeeLabel,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            _CurrencySelectField(
              value: _currency,
              labelText: l10n.opdCurrencyLabel,
              enabled: !_isSaving,
              onChanged: (String? value) {
                setState(() {
                  _currency = value ?? _defaultCurrency;
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

  Map<String, Object?> _payload() {
    return <String, Object?>{
      if (_registerNewPatient)
        'patient_registration': <String, Object?>{
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'gender': _gender,
        }
      else
        'patient_id': _patientId,
      'provider_user_id': _providerId,
      'consultation_fee': _feeController.text.trim(),
      'currency': _currency,
      'notes': _notesController.text.trim(),
    };
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
  String _currency = _defaultCurrency;
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
          AppTextField(
            controller: _amountController,
            labelText: l10n.opdAmountLabel,
            enabled: !_isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          _CurrencySelectField(
            value: _currency,
            labelText: l10n.opdCurrencyLabel,
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() {
                _currency = value ?? _defaultCurrency;
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
          'amount': _amountController.text.trim(),
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

List<AppSelectOption<String>> _providerSelectOptions(
  List<OpdProviderSchedule> schedules,
) {
  final Map<String, AppSelectOption<String>> options =
      <String, AppSelectOption<String>>{};

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

String _timeRange(DateTime? start, DateTime? end, Locale locale) {
  if (start == null || end == null) {
    return '';
  }
  return '${AppFormatters.time(start, locale)}-${AppFormatters.time(end, locale)}';
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
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

const List<String> _queueStatuses = <String>[
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW',
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

const List<String> _genderOptions = <String>[
  'MALE',
  'FEMALE',
  'OTHER',
  'UNKNOWN',
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

const String _defaultCurrency = 'UGX';

const List<String> _currencyOptions = <String>[
  'UGX',
  'AED',
  'AFN',
  'ALL',
  'AMD',
  'ANG',
  'AOA',
  'ARS',
  'AUD',
  'AWG',
  'AZN',
  'BAM',
  'BBD',
  'BDT',
  'BGN',
  'BHD',
  'BIF',
  'BMD',
  'BND',
  'BOB',
  'BRL',
  'BSD',
  'BTN',
  'BWP',
  'BYN',
  'BZD',
  'CAD',
  'CDF',
  'CHF',
  'CLP',
  'CNY',
  'COP',
  'CRC',
  'CUP',
  'CVE',
  'CZK',
  'DJF',
  'DKK',
  'DOP',
  'DZD',
  'EGP',
  'ERN',
  'ETB',
  'EUR',
  'FJD',
  'FKP',
  'GBP',
  'GEL',
  'GHS',
  'GIP',
  'GMD',
  'GNF',
  'GTQ',
  'GYD',
  'HKD',
  'HNL',
  'HTG',
  'HUF',
  'IDR',
  'ILS',
  'INR',
  'IQD',
  'IRR',
  'ISK',
  'JMD',
  'JOD',
  'JPY',
  'KES',
  'KGS',
  'KHR',
  'KMF',
  'KRW',
  'KWD',
  'KYD',
  'KZT',
  'LAK',
  'LBP',
  'LKR',
  'LRD',
  'LSL',
  'LYD',
  'MAD',
  'MDL',
  'MGA',
  'MKD',
  'MMK',
  'MNT',
  'MOP',
  'MRU',
  'MUR',
  'MVR',
  'MWK',
  'MXN',
  'MYR',
  'MZN',
  'NAD',
  'NGN',
  'NIO',
  'NOK',
  'NPR',
  'NZD',
  'OMR',
  'PAB',
  'PEN',
  'PGK',
  'PHP',
  'PKR',
  'PLN',
  'PYG',
  'QAR',
  'RON',
  'RSD',
  'RUB',
  'RWF',
  'SAR',
  'SBD',
  'SCR',
  'SDG',
  'SEK',
  'SGD',
  'SHP',
  'SLE',
  'SOS',
  'SRD',
  'SSP',
  'STN',
  'SYP',
  'SZL',
  'THB',
  'TJS',
  'TMT',
  'TND',
  'TOP',
  'TRY',
  'TTD',
  'TWD',
  'TZS',
  'UAH',
  'USD',
  'UYU',
  'UZS',
  'VES',
  'VND',
  'VUV',
  'WST',
  'XAF',
  'XCD',
  'XOF',
  'XPF',
  'YER',
  'ZAR',
  'ZMW',
  'ZWL',
];

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_payment_gate_controller.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_appointment_actions_dialog.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_patient_actions.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_payment_gate_detail_dialog.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_queue_actions_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';

/// High-volume front-desk workspace composing Patient Registry + OPD.
///
/// Does not fork patient/billing engines. Triage capture stays in Triage/OPD.
class ReceptionWorkspacePage extends ConsumerWidget {
  const ReceptionWorkspacePage({this.initialQuery, super.key});

  final ReceptionWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<OpdWorkspaceState>> opdState = ref.watch(
      opdWorkspaceControllerProvider,
    );
    final bool canReadPaymentGate = receptionPaymentGateRequirement.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );
    final AsyncValue<Result<ReceptionPaymentGateState>>? paymentGateState =
        canReadPaymentGate
        ? ref.watch(receptionPaymentGateControllerProvider)
        : null;

    return AsyncStateScaffold<OpdWorkspaceState>(
      value: opdState,
      loadingTitle: l10n.receptionLoadingTitle,
      loadingBody: l10n.receptionLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      deferLoadingToShell: false,
      keepPreviousDataDuringRefresh: true,
      onRetry: () {
        ref.read(opdWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, OpdWorkspaceState data) {
        return _ReceptionWorkspaceContent(
          state: data,
          paymentGateState: paymentGateState,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _ReceptionWorkspaceContent extends ConsumerStatefulWidget {
  const _ReceptionWorkspaceContent({
    required this.state,
    required this.paymentGateState,
    this.initialQuery,
  });

  final OpdWorkspaceState state;
  final AsyncValue<Result<ReceptionPaymentGateState>>? paymentGateState;
  final ReceptionWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_ReceptionWorkspaceContent> createState() =>
      _ReceptionWorkspaceContentState();
}

class _ReceptionWorkspaceContentState
    extends ConsumerState<_ReceptionWorkspaceContent> {
  static const String _statusFilterKey = 'status';
  static const String _stageFilterKey = 'stage';
  static const String _serviceFilterKey = 'service';

  late final TextEditingController _searchController;
  late ReceptionDeskSection _section;
  String? _appliedRouteSignature;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  bool _refreshRequested = false;
  late final AppListTableColumnVisibilityController<_ReceptionDeskRow>
  _columnVisibilityController;

  @override
  void initState() {
    super.initState();
    _section = ReceptionDeskSection.appointments;
    _searchController = TextEditingController(
      text: widget.initialQuery?.search ?? '',
    );
    _columnVisibilityController =
        AppListTableColumnVisibilityController<_ReceptionDeskRow>();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _ReceptionWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  void _scheduleRouteQuery(ReceptionWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_applyDeepLink(query));
    });
  }

  Future<void> _applyDeepLink(ReceptionWorkspaceQuery query) async {
    if (_appliedRouteSignature == query.signature) {
      return;
    }
    _appliedRouteSignature = query.signature;

    final ReceptionDeskSection? section = receptionDeskSectionFromQuery(
      query.section,
    );
    if (section != null) {
      setState(() {
        _section = section;
        _filterValue = AppSearchBarFilterValue.empty;
      });
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
    }

    if (query.flowId.isNotEmpty) {
      final OpdFlowSummary? flow = _findFlow(query.flowId);
      if (flow != null && mounted) {
        await _openFlowActions(flow);
      }
    }
  }

  void _updateUrlForSection(ReceptionDeskSection section) {
    if (!mounted) {
      return;
    }
    final String tab = receptionDeskSectionToQueryValue(section);
    final String location = AppRoutes.reception.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    context.go(location);
  }

  OpdFlowSummary? _findFlow(String id) {
    final String needle = id.trim().toLowerCase();
    if (needle.isEmpty) {
      return null;
    }
    for (final OpdFlowSummary flow in widget.state.flows.items) {
      if (flow.id.toLowerCase() == needle ||
          flow.apiId.toLowerCase() == needle ||
          (flow.publicId ?? '').toLowerCase() == needle) {
        return flow;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final OpdWorkspaceState state = widget.state;
    final ReceptionPaymentGateState? paymentGate = _paymentGateState;
    final bool paymentGateLoading =
        _section == ReceptionDeskSection.paymentGate &&
        (widget.paymentGateState?.isLoading == true ||
            (paymentGate?.isRefreshing ?? false));
    final bool sectionRefreshing = switch (_section) {
      ReceptionDeskSection.appointments => state.isRefreshingAppointments,
      ReceptionDeskSection.queue => state.isRefreshingQueue,
      ReceptionDeskSection.activeVisits => state.isRefreshingFlows,
      ReceptionDeskSection.paymentGate => paymentGateLoading,
    };
    final bool isRefreshing = _refreshRequested || sectionRefreshing;
    final List<ReceptionDeskSection> visibleSections = _visibleSections();
    if (visibleSections.isEmpty) {
      return AppStateView(
        title: l10n.errorForbiddenTitle,
        body: l10n.errorForbiddenMessage,
        variant: AppStateViewVariant.error,
      );
    }
    if (!visibleSections.contains(_section)) {
      _section = visibleSections.first;
      _filterValue = AppSearchBarFilterValue.empty;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final String tab = receptionDeskSectionToQueryValue(_section);
        GoRouter.of(context).replace<void>(
          AppRoutes.reception.location(
            queryParameters: <String, String>{'section': tab},
          ),
        );
      });
    }

    final List<_ReceptionDeskRow> sectionRows = _buildSectionRows(
      state,
      paymentGate?.entries ?? const <ReceptionPaymentGateEntry>[],
    );
    final List<_ReceptionDeskRow> rows = _applyStatusFilter(sectionRows);
    final List<AppListTableColumn<_ReceptionDeskRow>> columns =
        _receptionDefaultColumns(l10n);
    final List<AppListTableColumn<_ReceptionDeskRow>> columnChoices =
        _receptionColumnChoices(l10n);

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final ReceptionDeskSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: _sectionCount(
                      state,
                      section,
                      paymentGate?.entries ??
                          const <ReceptionPaymentGateEntry>[],
                    ),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              onTabTapped: (String tabId) {
                for (final ReceptionDeskSection section
                    in ReceptionDeskSection.values) {
                  if (section.name == tabId) {
                    setState(() {
                      _section = section;
                      _filterValue = AppSearchBarFilterValue.empty;
                    });
                    _updateUrlForSection(section);
                    break;
                  }
                }
              },
              primaryAction: _buildPrimaryAction(l10n, isRefreshing),
              secondaryActions: _buildSecondaryActions(l10n, isRefreshing),
            ),
            SizedBox(height: theme.spacing.sm),
            if (_section == ReceptionDeskSection.paymentGate &&
                _paymentGateFailure != null &&
                paymentGate == null)
              AppStateView(
                title: l10n.errorUnexpectedTitle,
                body: l10n.errorUnexpectedMessage,
                variant: AppStateViewVariant.error,
                action: AppButton.secondary(
                  label: l10n.commonRetryActionLabel,
                  onPressed: () => ref
                      .read(receptionPaymentGateControllerProvider.notifier)
                      .refresh(),
                ),
              )
            else
              AppListTable<_ReceptionDeskRow>(
                items: rows,
                columns: columns,
                columnChoices: columnChoices,
                columnVisibilityController: _columnVisibilityController,
                columnVisibilityStorageKey: 'reception_${_section.name}',
                columnWidthStorageKey: 'reception_cw_${_section.name}',
                columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
                columnVisibilityTitle: l10n.commonTableSettingsTitle,
                isLoading: isRefreshing,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onRowSelected: (_ReceptionDeskRow row) =>
                    unawaited(_openRowDetail(row)),
                itemKeyBuilder: (_ReceptionDeskRow row) =>
                    ValueKey<String>(row.id),
                search: AppListTableSearch<_ReceptionDeskRow>(
                  controller: _searchController,
                  semanticLabel: _section == ReceptionDeskSection.paymentGate
                      ? l10n.receptionPaymentGateSearchHint
                      : l10n.receptionSearchHint,
                  hintText: _section == ReceptionDeskSection.paymentGate
                      ? l10n.receptionPaymentGateSearchHint
                      : l10n.receptionSearchHint,
                  clearLabel: l10n.receptionClearFiltersAction,
                  isLoading: isRefreshing,
                  matcher: (_ReceptionDeskRow row, String query) =>
                      row.matchesSearch(_section, query, context),
                  showAdvancedFilterButton: true,
                  advancedFilterButtonLabel: l10n.receptionFiltersLabel,
                  advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
                  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                  advancedFilterResetLabel: l10n.receptionClearFiltersAction,
                  enableDateFilter: false,
                  allFieldsLabel: l10n.opdAllFieldsFilterLabel,
                  filterGroups: _filterGroups(sectionRows, l10n),
                  filterValue: _filterValue,
                  hasActiveFilters: _filterValue.isActive,
                  onFilterChanged: (AppSearchBarFilterValue value) {
                    setState(() => _filterValue = value);
                  },
                ),
                emptyBuilder: (_) => AppStateView(
                  title: _section == ReceptionDeskSection.paymentGate
                      ? l10n.receptionPaymentGateEmptyTitle
                      : l10n.receptionEmptyTitle,
                  body: _section == ReceptionDeskSection.paymentGate
                      ? l10n.receptionPaymentGateEmptyBody
                      : l10n.receptionEmptyBody,
                  variant: AppStateViewVariant.empty,
                ),
                mobileItemBuilder: _mobileItemBuilder,
              ),
          ],
        ),
      ),
    );
  }

  ReceptionPaymentGateState? get _paymentGateState {
    return widget.paymentGateState?.asData?.value.when(
      success: (ReceptionPaymentGateState value) => value,
      failure: (_) => null,
    );
  }

  AppFailure? get _paymentGateFailure {
    return widget.paymentGateState?.asData?.value.when(
      success: (ReceptionPaymentGateState value) => value.lastFailure,
      failure: (AppFailure failure) => failure,
    );
  }

  String get _filterGroupKey {
    return switch (_section) {
      ReceptionDeskSection.appointments ||
      ReceptionDeskSection.queue => _statusFilterKey,
      ReceptionDeskSection.activeVisits => _stageFilterKey,
      ReceptionDeskSection.paymentGate => _statusFilterKey,
    };
  }

  String _filterGroupLabel(AppLocalizations l10n) {
    return switch (_section) {
      ReceptionDeskSection.appointments => l10n.receptionStatusLabel,
      ReceptionDeskSection.queue => l10n.receptionCurrentStepLabel,
      ReceptionDeskSection.activeVisits => l10n.receptionCurrentStepLabel,
      ReceptionDeskSection.paymentGate => l10n.billingStatusFilterLabel,
    };
  }

  List<AppSearchBarFilterGroup> _filterGroups(
    List<_ReceptionDeskRow> rows,
    AppLocalizations l10n,
  ) {
    final List<AppSearchBarFilterGroup> groups = <AppSearchBarFilterGroup>[
      AppSearchBarFilterGroup(
        key: _filterGroupKey,
        label: _filterGroupLabel(l10n),
        allLabel: l10n.opdAllFieldsFilterLabel,
        choices: _statusFilterChoices(rows, l10n),
      ),
    ];
    if (_section == ReceptionDeskSection.paymentGate) {
      final Set<String> sources = <String>{
        for (final _ReceptionDeskRow row in rows)
          ...?row.paymentGateEntry?.services,
      };
      groups.add(
        AppSearchBarFilterGroup(
          key: _serviceFilterKey,
          label: l10n.billingSourceFilterLabel,
          allLabel: l10n.billingAnySourceOption,
          choices: <AppSearchBarFilterChoice>[
            for (final String source in sources.toList()..sort())
              AppSearchBarFilterChoice(
                value: source,
                label: billingApiLabel(context, source),
              ),
          ],
        ),
      );
    }
    return groups;
  }

  Widget _buildPrimaryAction(AppLocalizations l10n, bool isRefreshing) {
    return AppAccessActionGate(
      requirement: receptionPatientWriteRequirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }
        return AppTabToolbarPrimary(
          label: l10n.receptionRegisterPatientAction,
          icon: Icons.person_add_alt_1_outlined,
          enabled: isAllowed && !isRefreshing,
          isLoading: isAllowed && isRefreshing,
          tooltip: isAllowed && isRefreshing
              ? l10n.receptionActionInProgressTooltip
              : null,
          onPressed: isAllowed && !isRefreshing
              ? () => unawaited(_openRegisterPatient())
              : null,
        );
      },
    );
  }

  List<Widget> _buildSecondaryActions(
    AppLocalizations l10n,
    bool isRefreshing,
  ) {
    final AppTabToolbarAction refreshAction = AppTabToolbarAction(
      label: l10n.commonRefreshActionLabel,
      icon: Icons.refresh,
      isLoading: isRefreshing,
      enabled: !isRefreshing,
      tooltip: isRefreshing
          ? l10n.receptionRefreshInProgressTooltip
          : l10n.commonRefreshActionLabel,
      onPressed: isRefreshing ? null : () => unawaited(_refreshWorkspace()),
    );

    final Widget scheduleAppointmentAction = AppAccessActionGate(
      requirement: receptionPatientWriteRequirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }
        return AppTabToolbarAction(
          label: l10n.receptionScheduleAppointmentAction,
          icon: Icons.calendar_month_outlined,
          enabled: isAllowed && !isRefreshing,
          isLoading: isAllowed && isRefreshing,
          tooltip: isAllowed && isRefreshing
              ? l10n.receptionActionInProgressTooltip
              : null,
          onPressed: isAllowed && !isRefreshing
              ? () => unawaited(_scheduleAppointment())
              : null,
        );
      },
    );

    return <Widget>[
      scheduleAppointmentAction,
      refreshAction,
      AppAccessActionGate(
        requirement: receptionPatientRegistryRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return AppTabToolbarAction(
            label: l10n.receptionOpenRegistryAction,
            icon: Icons.badge_outlined,
            onPressed: isAllowed
                ? () => context.go(AppRoutes.patients.location())
                : null,
          );
        },
      ),
      AppAccessActionGate(
        requirement: receptionOpdWorkspaceRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return AppTabToolbarAction(
            label: l10n.receptionOpenOpdAction,
            icon: Icons.local_hospital_outlined,
            onPressed: isAllowed
                ? () => context.go(AppRoutes.opd.location())
                : null,
          );
        },
      ),
    ];
  }

  List<ReceptionDeskSection> _visibleSections() {
    final policy = ref.watch(appAccessPolicyProvider);
    return <ReceptionDeskSection>[
      for (final ReceptionDeskSection section in ReceptionDeskSection.values)
        if (receptionDeskSectionRequirement(section).isAllowed(policy)) section,
    ];
  }

  List<AppListTableColumn<_ReceptionDeskRow>> _receptionDefaultColumns(
    AppLocalizations l10n,
  ) {
    final Locale locale = Localizations.localeOf(context);
    switch (_section) {
      case ReceptionDeskSection.appointments:
        return <AppListTableColumn<_ReceptionDeskRow>>[
          _receptionPatientColumn(l10n),
          _receptionScheduledTimeColumn(l10n, locale),
          _receptionStatusColumn(l10n),
          _receptionAppointmentNextActionColumn(l10n),
        ];
      case ReceptionDeskSection.queue:
        return <AppListTableColumn<_ReceptionDeskRow>>[
          _receptionPatientColumn(l10n),
          _receptionQueuedAtColumn(l10n, locale),
          _receptionQueueCurrentStepColumn(l10n),
          _receptionQueueNextActionColumn(l10n),
        ];
      case ReceptionDeskSection.activeVisits:
        return <AppListTableColumn<_ReceptionDeskRow>>[
          _receptionPatientColumn(l10n),
          _receptionStartedAtColumn(l10n, locale),
          _receptionFlowStageStatusColumn(l10n),
          _receptionFlowNextActionColumn(l10n),
        ];
      case ReceptionDeskSection.paymentGate:
        return <AppListTableColumn<_ReceptionDeskRow>>[
          _receptionPatientColumn(l10n),
          _receptionPaymentEncounterColumn(l10n),
          _receptionPaymentServicesColumn(l10n),
          _receptionPaymentOutstandingColumn(l10n),
          _receptionPaymentGateStatusColumn(l10n),
        ];
    }
  }

  List<AppListTableColumn<_ReceptionDeskRow>> _receptionColumnChoices(
    AppLocalizations l10n,
  ) {
    switch (_section) {
      case ReceptionDeskSection.appointments:
        return <AppListTableColumn<_ReceptionDeskRow>>[
          _receptionAppointmentIdColumn(l10n),
          _receptionProviderColumn(l10n, appointmentProvider: true),
          _receptionReasonColumn(l10n, appointmentReason: true),
        ];
      case ReceptionDeskSection.queue:
        return <AppListTableColumn<_ReceptionDeskRow>>[
          _receptionQueueIdColumn(l10n),
          _receptionQueuePaymentStatusColumn(l10n),
          _receptionProviderColumn(l10n, queueProvider: true),
          _receptionReasonColumn(l10n, queueReason: true),
        ];
      case ReceptionDeskSection.activeVisits:
        return <AppListTableColumn<_ReceptionDeskRow>>[
          _receptionPatientIdColumn(l10n),
          _receptionAssignedDoctorColumn(l10n),
        ];
      case ReceptionDeskSection.paymentGate:
        return <AppListTableColumn<_ReceptionDeskRow>>[
          _receptionPatientIdColumn(l10n),
          _receptionPaymentInvoicesColumn(l10n),
        ];
    }
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionPatientColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'patient',
      label: l10n.opdPatientNameLabel,
      alwaysVisible: true,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) =>
          AppListItemText(
            title: row.patientName(context),
            subtitle: row.patientIdentifier,
          ),
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          appListTableCompareText(
            a.patientName(context),
            b.patientName(context),
          ),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionScheduledTimeColumn(
    AppLocalizations l10n,
    Locale locale,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'scheduled_time',
      label: l10n.receptionScheduledTimeLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final DateTime? dt = row.appointment?.scheduledStart;
        return Text(dt != null ? AppFormatters.dateTime(dt, locale) : '');
      },
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          appListTableCompareDateTime(
            a.appointment?.scheduledStart,
            b.appointment?.scheduledStart,
          ),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionQueuedAtColumn(
    AppLocalizations l10n,
    Locale locale,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'queued_at',
      label: l10n.receptionQueuedAtLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final DateTime? dt = row.queueEntry?.queuedAt;
        return Text(dt != null ? AppFormatters.dateTime(dt, locale) : '');
      },
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          appListTableCompareDateTime(
            a.queueEntry?.queuedAt,
            b.queueEntry?.queuedAt,
          ),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionStartedAtColumn(
    AppLocalizations l10n,
    Locale locale,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'started_at',
      label: l10n.receptionStartedAtLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final DateTime? dt = row.flow?.startedAt;
        return Text(dt != null ? AppFormatters.dateTime(dt, locale) : '');
      },
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          appListTableCompareDateTime(a.flow?.startedAt, b.flow?.startedAt),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionStatusColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'status',
      label: l10n.receptionStatusLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final String? status =
            row.appointment?.status ?? row.queueEntry?.status;
        if (status == null || status.isEmpty) {
          return const SizedBox.shrink();
        }
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: opdStageDisplayLabel(context.l10n, status),
            tone: AppWorkspaceStatusTone.info,
          ),
        );
      },
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionQueueCurrentStepColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'status',
      label: l10n.receptionCurrentStepLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final String label = row.queueCurrentStepLabel(l10n);
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: label,
            tone: opdStageStatusTone(row.queueCurrentStepCode),
          ),
        );
      },
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) => a
          .queueCurrentStepLabel(l10n)
          .compareTo(b.queueCurrentStepLabel(l10n)),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionFlowStageStatusColumn(
    AppLocalizations l10n, {
    String id = 'status',
  }) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: id,
      label: l10n.receptionCurrentStepLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final String label = row.flowCurrentStepLabel(l10n);
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: label,
            tone: opdStageStatusTone(row.flowCurrentStepCode),
          ),
        );
      },
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          a.flowCurrentStepLabel(l10n).compareTo(b.flowCurrentStepLabel(l10n)),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionPaymentGateStatusColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'status',
      label: l10n.receptionPaymentStatusLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final ReceptionPaymentGateEntry? entry = row.paymentGateEntry;
        if (entry == null) {
          return const SizedBox.shrink();
        }
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: billingClearanceLabel(context, entry.clearanceState),
            tone: billingClearanceTone(entry.clearanceState),
          ),
        );
      },
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          (a.paymentGateEntry?.clearanceState.name ?? '').compareTo(
            b.paymentGateEntry?.clearanceState.name ?? '',
          ),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionPaymentEncounterColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'encounter',
      label: l10n.billingEncounterLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) =>
          Text(row.paymentGateEntry?.encounterIdentifier ?? ''),
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          (a.paymentGateEntry?.encounterIdentifier ?? '').compareTo(
            b.paymentGateEntry?.encounterIdentifier ?? '',
          ),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionPaymentServicesColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'services',
      label: l10n.billingSourceColumn,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) => Text(
        row.paymentGateEntry?.services
                .map((String source) => billingApiLabel(context, source))
                .join(', ') ??
            '',
      ),
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          (a.paymentGateEntry?.services.join(',') ?? '').compareTo(
            b.paymentGateEntry?.services.join(',') ?? '',
          ),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionPaymentOutstandingColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'outstanding',
      label: l10n.billingAmountDueColumn,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) =>
          Text(_paymentMoneySummary(context, row.paymentGateEntry)),
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          _paymentOutstandingTotal(
            a.paymentGateEntry,
          ).compareTo(_paymentOutstandingTotal(b.paymentGateEntry)),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionPaymentInvoicesColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'invoices',
      label: l10n.billingInvoiceColumn,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) => Text(
        row.paymentGateEntry?.invoices
                .map((BillingWorkItem invoice) => invoice.effectiveDisplayId)
                .join(', ') ??
            '',
      ),
    );
  }

  String _paymentMoneySummary(
    BuildContext context,
    ReceptionPaymentGateEntry? entry,
  ) {
    if (entry == null) {
      return '';
    }
    return entry.outstandingByCurrency.entries
        .map(
          (MapEntry<String, num> total) =>
              billingMoney(context, total.value, total.key),
        )
        .join(' · ');
  }

  num _paymentOutstandingTotal(ReceptionPaymentGateEntry? entry) {
    return entry?.outstandingByCurrency.values.fold<num>(
          0,
          (num total, num value) => total + value,
        ) ??
        0;
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionAppointmentIdColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'appointment_id',
      label: l10n.receptionAppointmentIdLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) =>
          Text(row.appointment?.publicId ?? row.appointment?.id ?? ''),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionQueueIdColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'queue_id',
      label: l10n.receptionQueueIdLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) =>
          Text(row.queueEntry?.publicId ?? row.queueEntry?.id ?? ''),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionPatientIdColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'patient_id',
      label: l10n.opdPatientIdLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) =>
          Text(row.flow?.patientIdentifier ?? row.flow?.patientId ?? ''),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionAssignedDoctorColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'assigned_doctor',
      label: l10n.receptionAssignedDoctorLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) =>
          Text(row.flow?.assignedStaffDisplayName ?? ''),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionProviderColumn(
    AppLocalizations l10n, {
    bool appointmentProvider = false,
    bool queueProvider = false,
  }) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'provider',
      label: l10n.opdProviderColumnLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final String? provider = appointmentProvider
            ? row.appointment?.providerDisplayName
            : queueProvider
            ? row.queueEntry?.providerDisplayName
            : null;
        return Text(provider ?? '');
      },
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionReasonColumn(
    AppLocalizations l10n, {
    bool appointmentReason = false,
    bool queueReason = false,
  }) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'reason',
      label: l10n.opdReasonLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final String? reason = appointmentReason
            ? row.appointment?.reason
            : queueReason
            ? row.queueEntry?.appointmentReason
            : null;
        return Text(reason ?? '');
      },
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionQueuePaymentStatusColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'payment_status',
      label: l10n.receptionPaymentStatusLabel,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final OpdQueueEntry? entry = row.queueEntry;
        if (entry == null) {
          return const SizedBox.shrink();
        }
        final OpdBillingDisplay billing = opdQueueBillingDisplay(
          context,
          entry,
        );
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: billing.statusLabel,
            tone: billing.tone,
          ),
        );
      },
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionAppointmentNextActionColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'next_action',
      label: l10n.opdActionsColumnLabel,
      alwaysVisible: true,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final OpdAppointment? appointment = row.appointment;
        if (appointment == null) {
          return const SizedBox.shrink();
        }
        final String? label = _receptionAppointmentNextActionLabel(
          l10n,
          appointment,
        );
        if (label == null) {
          return const SizedBox.shrink();
        }
        return AppButton.secondary(
          label: label,
          onPressed: () => unawaited(_openRowDetail(row)),
        );
      },
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionQueueNextActionColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'next_action',
      label: l10n.opdNextActionFilterLabel,
      alwaysVisible: true,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final String label = row.queueNextActionLabel(l10n);
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(label);
      },
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          a.queueNextActionLabel(l10n).compareTo(b.queueNextActionLabel(l10n)),
    );
  }

  AppListTableColumn<_ReceptionDeskRow> _receptionFlowNextActionColumn(
    AppLocalizations l10n,
  ) {
    return AppListTableColumn<_ReceptionDeskRow>(
      id: 'next_action',
      label: l10n.opdNextActionFilterLabel,
      alwaysVisible: true,
      cellBuilder: (BuildContext context, _ReceptionDeskRow row) {
        final String label = row.flowNextActionLabel(l10n);
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(label);
      },
      sortComparator: (_ReceptionDeskRow a, _ReceptionDeskRow b) =>
          a.flowNextActionLabel(l10n).compareTo(b.flowNextActionLabel(l10n)),
    );
  }

  String? _receptionAppointmentNextActionLabel(
    AppLocalizations l10n,
    OpdAppointment appointment,
  ) {
    final String status = (appointment.status ?? '').toUpperCase();
    if (isOpdAppointmentTerminalStatus(status)) {
      return null;
    }
    final bool canCheckIn = status != 'IN_PROGRESS' && status != 'COMPLETED';
    if (canCheckIn) {
      return l10n.opdCheckInAction;
    }
    if (status != 'IN_PROGRESS' && appointment.patientId != null) {
      return l10n.opdQueueAction;
    }
    return l10n.opdRescheduleAction;
  }

  Widget _mobileItemBuilder(BuildContext context, _ReceptionDeskRow row) {
    return _ReceptionDeskMobileRow(
      section: _section,
      row: row,
      onOpenDetail: () => unawaited(_openRowDetail(row)),
    );
  }

  List<_ReceptionDeskRow> _buildSectionRows(
    OpdWorkspaceState state,
    List<ReceptionPaymentGateEntry> paymentGateEntries,
  ) {
    switch (_section) {
      case ReceptionDeskSection.appointments:
        return <_ReceptionDeskRow>[
          for (final OpdAppointment appointment in state.appointments.items)
            if (!isOpdTerminalStatus(appointment.status))
              _ReceptionDeskRow.appointment(appointment),
        ];
      case ReceptionDeskSection.queue:
        return <_ReceptionDeskRow>[
          for (final OpdQueueEntry entry in state.queueEntries.items)
            if (!isOpdTerminalStatus(entry.status))
              _ReceptionDeskRow.queue(
                entry,
                flow: _findFlowForQueueEntry(entry, state.flows.items),
              ),
        ];
      case ReceptionDeskSection.activeVisits:
        return <_ReceptionDeskRow>[
          for (final OpdFlowSummary flow in state.flows.items)
            if (isReceptionActiveVisit(flow)) _ReceptionDeskRow.flow(flow),
        ];
      case ReceptionDeskSection.paymentGate:
        return <_ReceptionDeskRow>[
          for (final ReceptionPaymentGateEntry entry in paymentGateEntries)
            _ReceptionDeskRow.paymentGate(entry),
        ];
    }
  }

  List<_ReceptionDeskRow> _applyStatusFilter(List<_ReceptionDeskRow> rows) {
    final String? selected = _filterValue.option(_filterGroupKey);
    final String needle = (selected ?? '').toUpperCase();
    List<_ReceptionDeskRow> filtered = selected == null || selected.isEmpty
        ? rows
        : <_ReceptionDeskRow>[
            for (final _ReceptionDeskRow row in rows)
              if (_rowFilterCode(row).toUpperCase() == needle) row,
          ];
    if (_section == ReceptionDeskSection.paymentGate) {
      final String? service = _filterValue.option(_serviceFilterKey);
      if (service != null && service.isNotEmpty) {
        filtered = <_ReceptionDeskRow>[
          for (final _ReceptionDeskRow row in filtered)
            if (row.paymentGateEntry?.services.contains(service) ?? false) row,
        ];
      }
    }
    return filtered;
  }

  String _rowFilterCode(_ReceptionDeskRow row) {
    return switch (_section) {
      ReceptionDeskSection.activeVisits => row.flowCurrentStepCode,
      ReceptionDeskSection.paymentGate =>
        row.paymentGateEntry?.clearanceState.name ?? '',
      ReceptionDeskSection.appointments ||
      ReceptionDeskSection.queue => row.status ?? '',
    };
  }

  List<AppSearchBarFilterChoice> _statusFilterChoices(
    List<_ReceptionDeskRow> rows,
    AppLocalizations l10n,
  ) {
    final Set<String> seen = <String>{};
    final List<AppSearchBarFilterChoice> choices = <AppSearchBarFilterChoice>[];
    for (final _ReceptionDeskRow row in rows) {
      final String status = _rowFilterCode(row).trim();
      if (status.isEmpty) {
        continue;
      }
      final String key = status.toUpperCase();
      if (!seen.add(key)) {
        continue;
      }
      choices.add(
        AppSearchBarFilterChoice(
          value: key,
          label: switch (_section) {
            ReceptionDeskSection.activeVisits => row.flowCurrentStepLabel(l10n),
            ReceptionDeskSection.paymentGate => billingClearanceLabel(
              context,
              row.paymentGateEntry!.clearanceState,
            ),
            ReceptionDeskSection.appointments ||
            ReceptionDeskSection.queue => opdStageDisplayLabel(l10n, status),
          },
        ),
      );
    }
    choices.sort(
      (AppSearchBarFilterChoice a, AppSearchBarFilterChoice b) =>
          a.label.compareTo(b.label),
    );
    return choices;
  }

  int _sectionCount(
    OpdWorkspaceState state,
    ReceptionDeskSection section,
    List<ReceptionPaymentGateEntry> paymentGateEntries,
  ) {
    switch (section) {
      case ReceptionDeskSection.appointments:
        return state.appointments.items
            .where((OpdAppointment a) => !isOpdTerminalStatus(a.status))
            .length;
      case ReceptionDeskSection.queue:
        return state.queueEntries.items
            .where((OpdQueueEntry e) => !isOpdTerminalStatus(e.status))
            .length;
      case ReceptionDeskSection.activeVisits:
        return state.flows.items.where(isReceptionActiveVisit).length;
      case ReceptionDeskSection.paymentGate:
        return paymentGateEntries.length;
    }
  }

  static AppTabCountTone _sectionCountTone(ReceptionDeskSection section) {
    return switch (section) {
      ReceptionDeskSection.appointments ||
      ReceptionDeskSection.queue ||
      ReceptionDeskSection.activeVisits ||
      ReceptionDeskSection.paymentGate => AppTabCountTone.warning,
    };
  }

  OpdFlowSummary? _findFlowForQueueEntry(
    OpdQueueEntry entry,
    List<OpdFlowSummary> flows,
  ) {
    final List<OpdFlowSummary> activeFlows = flows
        .where((OpdFlowSummary flow) => !flow.isTerminal)
        .toList(growable: false);
    final Set<String> queueIds = <String>{
      entry.id.trim().toLowerCase(),
      entry.apiId.trim().toLowerCase(),
      (entry.publicId ?? '').trim().toLowerCase(),
    }..remove('');
    for (final OpdFlowSummary flow in activeFlows) {
      if (queueIds.contains((flow.visitQueueId ?? '').trim().toLowerCase())) {
        return flow;
      }
    }

    final String appointmentId = (entry.appointmentId ?? '')
        .trim()
        .toLowerCase();
    if (appointmentId.isNotEmpty) {
      for (final OpdFlowSummary flow in activeFlows) {
        if ((flow.appointmentId ?? '').trim().toLowerCase() == appointmentId) {
          return flow;
        }
      }
    }

    final String patientId = (entry.patientId ?? '').trim().toLowerCase();
    if (patientId.isEmpty) {
      return null;
    }
    final List<OpdFlowSummary> patientFlows = activeFlows
        .where(
          (OpdFlowSummary flow) =>
              (flow.patientId ?? '').trim().toLowerCase() == patientId,
        )
        .toList(growable: false);
    return patientFlows.length == 1 ? patientFlows.single : null;
  }

  String _sectionLabel(AppLocalizations l10n, ReceptionDeskSection section) {
    return switch (section) {
      ReceptionDeskSection.appointments => l10n.receptionSectionAppointments,
      ReceptionDeskSection.queue => l10n.receptionSectionQueue,
      ReceptionDeskSection.activeVisits => l10n.receptionSectionActiveVisits,
      ReceptionDeskSection.paymentGate => l10n.receptionSectionPaymentGate,
    };
  }

  static IconData _sectionIcon(ReceptionDeskSection section) {
    return switch (section) {
      ReceptionDeskSection.appointments => Icons.event_available_outlined,
      ReceptionDeskSection.queue => Icons.queue_outlined,
      ReceptionDeskSection.activeVisits => Icons.pending_actions_outlined,
      ReceptionDeskSection.paymentGate => Icons.payments_outlined,
    };
  }

  Future<void> _refreshWorkspace() async {
    if (_refreshRequested) {
      return;
    }
    setState(() => _refreshRequested = true);
    try {
      final List<Future<AppFailure?>> refreshes = <Future<AppFailure?>>[
        ref.read(opdWorkspaceControllerProvider.notifier).refresh(),
        if (widget.paymentGateState != null)
          ref.read(receptionPaymentGateControllerProvider.notifier).refresh(),
      ];
      final List<AppFailure?> failures = await Future.wait(refreshes);
      if (!mounted) {
        return;
      }
      for (final AppFailure? failure in failures) {
        _showFailureIfNeeded(context, failure);
      }
    } finally {
      if (mounted) {
        setState(() => _refreshRequested = false);
      }
    }
  }

  Future<void> _scheduleAppointment() async {
    final bool scheduled = await openReceptionScheduleAppointment(
      context: context,
      ref: ref,
    );
    if (!scheduled || !mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
  }

  Future<void> _openRowDetail(_ReceptionDeskRow row) async {
    if (row.paymentGateEntry != null) {
      await showReceptionPaymentGateDetailDialog(
        context: context,
        entry: row.paymentGateEntry!,
      );
      return;
    }
    if (row.appointment != null) {
      final bool? changed = await showReceptionAppointmentActionsDialog(
        context: context,
        appointment: row.appointment!,
        workspaceState: widget.state,
      );
      if (changed == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
      }
      return;
    }
    if (row.queueEntry != null) {
      final OpdAppointment? linkedAppointment = _findAppointmentForQueueEntry(
        row.queueEntry!,
      );
      if (linkedAppointment != null) {
        final bool? changed = await showReceptionAppointmentActionsDialog(
          context: context,
          appointment: linkedAppointment,
          workspaceState: widget.state,
        );
        if (changed == true && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
        }
        return;
      }
      final bool? changed = await showReceptionQueueActionsDialog(
        context: context,
        entry: row.queueEntry!,
      );
      if (changed == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
      }
      return;
    }
    if (row.flow != null) {
      await _openFlowActions(row.flow!);
    }
  }

  OpdAppointment? _findAppointmentForQueueEntry(OpdQueueEntry entry) {
    final String? appointmentId = entry.appointmentId?.trim();
    if (appointmentId == null || appointmentId.isEmpty) {
      return null;
    }
    final String needle = appointmentId.toLowerCase();
    for (final OpdAppointment appointment in widget.state.appointments.items) {
      if (appointment.id.toLowerCase() == needle ||
          appointment.apiId.toLowerCase() == needle ||
          (appointment.publicId ?? '').toLowerCase() == needle) {
        return appointment;
      }
    }
    return null;
  }

  Future<void> _openRegisterPatient() async {
    final AsyncValue<Result<PatientRegistryState>> registryAsync = ref.read(
      patientRegistryControllerProvider,
    );
    final PatientRegistryState? registry = registryAsync.asData?.value.when(
      success: (PatientRegistryState state) => state,
      failure: (_) => null,
    );
    if (registry == null) {
      final AppFailure? failure = await ref
          .read(patientRegistryControllerProvider.notifier)
          .refresh();
      if (!mounted) {
        return;
      }
      if (failure != null) {
        _showFailureIfNeeded(context, failure);
        return;
      }
    }

    final PatientRegistryState? loaded = ref
        .read(patientRegistryControllerProvider)
        .asData
        ?.value
        .when(
          success: (PatientRegistryState state) => state,
          failure: (_) => null,
        );
    if (loaded == null || !mounted) {
      return;
    }

    final PatientRegistrationResult? registration =
        await showRegisterNewPatientDialog(
          context: context,
          referenceData: loaded.referenceData,
          registrationScope: PatientRegistrationScope.resolve(
            referenceData: loaded.referenceData,
            accessPolicy: ref.read(appAccessPolicyProvider),
          ),
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
        );

    if (registration == null || !mounted) {
      return;
    }
    if (registration.wasCreated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientsSavedMessage)),
      );
    }
    await openReceptionPatientEditor(context, ref, registration.patient.id);
  }

  Future<void> _openFlowActions(OpdFlowSummary flow) async {
    final bool? changed = await showFlowActionsDialog(
      context: context,
      flow: flow,
      allowBillingActions: false,
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }

  void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
    showAppFailureSnackBar(context, failure);
  }
}

@immutable
final class _ReceptionDeskRow {
  const _ReceptionDeskRow._({
    this.appointment,
    this.queueEntry,
    this.flow,
    this.paymentGateEntry,
  });

  factory _ReceptionDeskRow.appointment(OpdAppointment appointment) {
    return _ReceptionDeskRow._(appointment: appointment);
  }

  factory _ReceptionDeskRow.queue(OpdQueueEntry entry, {OpdFlowSummary? flow}) {
    return _ReceptionDeskRow._(queueEntry: entry, flow: flow);
  }

  factory _ReceptionDeskRow.flow(OpdFlowSummary flow) {
    return _ReceptionDeskRow._(flow: flow);
  }

  factory _ReceptionDeskRow.paymentGate(ReceptionPaymentGateEntry entry) {
    return _ReceptionDeskRow._(paymentGateEntry: entry);
  }

  final OpdAppointment? appointment;
  final OpdQueueEntry? queueEntry;
  final OpdFlowSummary? flow;
  final ReceptionPaymentGateEntry? paymentGateEntry;

  String get id =>
      appointment?.id ??
      queueEntry?.id ??
      flow?.id ??
      paymentGateEntry?.id ??
      '';

  String patientName(BuildContext context) {
    return appointment?.patientDisplayName ??
        queueEntry?.patientDisplayName ??
        flow?.patientDisplayName ??
        paymentGateEntry?.patientName ??
        context.l10n.profileUnknownValue;
  }

  String? get patientId =>
      appointment?.patientId ??
      queueEntry?.patientId ??
      flow?.patientId ??
      paymentGateEntry?.patientId;

  String? get patientIdentifier =>
      appointment?.patientIdentifier ??
      queueEntry?.patientIdentifier ??
      flow?.patientIdentifier ??
      paymentGateEntry?.patientIdentifier;

  String? get displayId =>
      appointment?.publicId ??
      queueEntry?.publicId ??
      flow?.publicId ??
      paymentGateEntry?.encounterIdentifier ??
      appointment?.id ??
      queueEntry?.id ??
      flow?.id;

  String? get status {
    if (appointment != null) {
      return appointment?.status;
    }
    if (queueEntry != null) {
      return queueCurrentStepCode;
    }
    return flow?.stage;
  }

  String get queueCurrentStepCode =>
      flow?.displayCode ?? flow?.stage ?? queueEntry?.status ?? '';

  String queueCurrentStepLabel(AppLocalizations l10n) {
    final OpdFlowSummary? linkedFlow = flow;
    if (linkedFlow != null) {
      return opdStatusDisplayLabel(l10n, linkedFlow);
    }
    return opdStageDisplayLabel(l10n, queueEntry?.status);
  }

  String queueNextActionLabel(AppLocalizations l10n) {
    final OpdFlowSummary? linkedFlow = flow;
    if (linkedFlow != null) {
      return opdNextStepDisplayLabel(
        l10n,
        linkedFlow.displayNextStep ?? linkedFlow.nextStep,
      );
    }
    if (queueEntry != null && !isOpdTerminalStatus(queueEntry?.status)) {
      return l10n.opdStartConsultationAction;
    }
    return '';
  }

  String get flowCurrentStepCode =>
      flow?.displayCode ?? flow?.stage ?? flow?.status ?? '';

  String flowCurrentStepLabel(AppLocalizations l10n) {
    final OpdFlowSummary? currentFlow = flow;
    return currentFlow == null ? '' : opdStatusDisplayLabel(l10n, currentFlow);
  }

  String flowNextActionLabel(AppLocalizations l10n) {
    final OpdFlowSummary? currentFlow = flow;
    if (currentFlow == null) {
      return '';
    }
    return opdNextStepDisplayLabel(
      l10n,
      currentFlow.displayNextStep ?? currentFlow.nextStep,
    );
  }

  DateTime? get time =>
      appointment?.scheduledStart ?? queueEntry?.queuedAt ?? flow?.startedAt;

  bool matchesSearch(
    ReceptionDeskSection section,
    String query,
    BuildContext context,
  ) {
    if (query.trim().isEmpty) {
      return true;
    }
    final String needle = query.trim().toLowerCase();
    final Locale locale = Localizations.localeOf(context);
    final AppLocalizations l10n = context.l10n;

    return searchValues(
      section,
      context,
      locale,
      l10n,
    ).any((String value) => value.toLowerCase().contains(needle));
  }

  List<String> searchValues(
    ReceptionDeskSection section,
    BuildContext context,
    Locale locale,
    AppLocalizations l10n,
  ) {
    final List<String?> values = <String?>[
      patientName(context),
      patientId,
      patientIdentifier,
      displayId,
    ];

    switch (section) {
      case ReceptionDeskSection.appointments:
        final OpdAppointment? appt = appointment;
        if (appt != null) {
          values.addAll(<String?>[
            appt.publicId,
            appt.id,
            appt.status,
            appt.providerDisplayName,
            appt.reason,
            appt.scheduledStart == null
                ? null
                : AppFormatters.dateTime(appt.scheduledStart!, locale),
            opdStageDisplayLabel(l10n, appt.status ?? ''),
            _receptionAppointmentNextActionLabelStatic(l10n, appt),
          ]);
        }
      case ReceptionDeskSection.queue:
        final OpdQueueEntry? entry = queueEntry;
        if (entry != null) {
          final OpdBillingDisplay billing = opdQueueBillingDisplay(
            context,
            entry,
          );
          values.addAll(<String?>[
            entry.publicId,
            entry.id,
            entry.status,
            entry.providerDisplayName,
            entry.appointmentReason,
            entry.paymentStatus,
            entry.queuedAt == null
                ? null
                : AppFormatters.dateTime(entry.queuedAt!, locale),
            flow?.displayCode,
            flow?.displayStatus,
            flow?.stage,
            flow?.nextStep,
            flow?.displayNextStep,
            queueCurrentStepLabel(l10n),
            queueNextActionLabel(l10n),
            billing.statusLabel,
            billing.label,
          ]);
        }
      case ReceptionDeskSection.activeVisits:
        final OpdFlowSummary? flowSummary = flow;
        if (flowSummary != null) {
          final OpdBillingDisplay billing = opdFlowBillingDisplay(
            context,
            flowSummary,
          );
          values.addAll(<String?>[
            flowSummary.patientIdentifier,
            flowSummary.patientId,
            flowSummary.publicId,
            flowSummary.id,
            flowSummary.stage,
            flowSummary.assignedStaffDisplayName,
            flowSummary.nextStep,
            flowSummary.displayNextStep,
            flowSummary.startedAt == null
                ? null
                : AppFormatters.dateTime(flowSummary.startedAt!, locale),
            opdStageDisplayLabel(l10n, flowSummary.stage ?? ''),
            billing.statusLabel,
            billing.label,
            flowSummary.consultationFee?.toString(),
            flowSummary.consultationCurrency,
            flowSummary.consultationFee == null
                ? null
                : '${flowSummary.consultationCurrency ?? ''} ${flowSummary.consultationFee!.toStringAsFixed(0)}'
                      .trim(),
            opdNextStepDisplayLabel(
              l10n,
              flowSummary.displayNextStep ?? flowSummary.nextStep,
            ),
          ]);
        }
      case ReceptionDeskSection.paymentGate:
        final ReceptionPaymentGateEntry? entry = paymentGateEntry;
        if (entry != null) {
          values.addAll(<String?>[
            entry.encounterId,
            entry.encounterIdentifier,
            entry.clearanceState.name,
            for (final String service in entry.services) service,
            for (final MapEntry<String, num> total
                in entry.outstandingByCurrency.entries) ...<String>[
              total.key,
              total.value.toString(),
            ],
            for (final BillingWorkItem invoice in entry.invoices) ...<String?>[
              invoice.id,
              invoice.effectiveDisplayId,
              invoice.billingStatus,
              invoice.status,
              for (final BillingInvoiceItem item in invoice.items)
                item.description,
            ],
          ]);
        }
    }

    return values
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static String? _receptionAppointmentNextActionLabelStatic(
    AppLocalizations l10n,
    OpdAppointment appointment,
  ) {
    final String status = (appointment.status ?? '').toUpperCase();
    if (isOpdAppointmentTerminalStatus(status)) {
      return null;
    }
    final bool canCheckIn = status != 'IN_PROGRESS' && status != 'COMPLETED';
    if (canCheckIn) {
      return l10n.opdCheckInAction;
    }
    if (status != 'IN_PROGRESS' && appointment.patientId != null) {
      return l10n.opdQueueAction;
    }
    return l10n.opdRescheduleAction;
  }
}

class _ReceptionDeskMobileRow extends StatelessWidget {
  const _ReceptionDeskMobileRow({
    required this.section,
    required this.row,
    required this.onOpenDetail,
  });

  final ReceptionDeskSection section;
  final _ReceptionDeskRow row;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onOpenDetail,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppListItemText(
              title: row.patientName(context),
              subtitle: row.patientIdentifier,
            ),
            if (row.time != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                AppFormatters.dateTime(row.time!, locale),
                style: theme.textTheme.bodySmall,
              ),
            ],
            SizedBox(height: theme.spacing.xs),
            _ReceptionDeskMobileStatus(section: section, row: row),
            SizedBox(height: theme.spacing.sm),
            _ReceptionDeskMobileNextAction(
              section: section,
              row: row,
              onOpenDetail: onOpenDetail,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceptionDeskMobileStatus extends StatelessWidget {
  const _ReceptionDeskMobileStatus({required this.section, required this.row});

  final ReceptionDeskSection section;
  final _ReceptionDeskRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    switch (section) {
      case ReceptionDeskSection.appointments:
        final String? status = row.appointment?.status;
        if (status == null || status.isEmpty) {
          return const SizedBox.shrink();
        }
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: opdStageDisplayLabel(l10n, status),
            tone: AppWorkspaceStatusTone.info,
          ),
        );
      case ReceptionDeskSection.queue:
        final String label = row.queueCurrentStepLabel(l10n);
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: label,
            tone: opdStageStatusTone(row.queueCurrentStepCode),
          ),
        );
      case ReceptionDeskSection.activeVisits:
        final String label = row.flowCurrentStepLabel(l10n);
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: label,
            tone: opdStageStatusTone(row.flowCurrentStepCode),
          ),
        );
      case ReceptionDeskSection.paymentGate:
        final ReceptionPaymentGateEntry? entry = row.paymentGateEntry;
        if (entry == null) {
          return const SizedBox.shrink();
        }
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: billingClearanceLabel(context, entry.clearanceState),
            tone: billingClearanceTone(entry.clearanceState),
          ),
        );
    }
  }
}

class _ReceptionDeskMobileNextAction extends StatelessWidget {
  const _ReceptionDeskMobileNextAction({
    required this.section,
    required this.row,
    required this.onOpenDetail,
  });

  final ReceptionDeskSection section;
  final _ReceptionDeskRow row;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    switch (section) {
      case ReceptionDeskSection.appointments:
        final OpdAppointment? appointment = row.appointment;
        if (appointment == null) {
          return const SizedBox.shrink();
        }
        final String? label =
            _ReceptionDeskRow._receptionAppointmentNextActionLabelStatic(
              l10n,
              appointment,
            );
        if (label == null) {
          return const SizedBox.shrink();
        }
        return AppButton.secondary(label: label, onPressed: onOpenDetail);
      case ReceptionDeskSection.queue:
        final String label = row.queueNextActionLabel(l10n);
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(label);
      case ReceptionDeskSection.activeVisits:
        final String label = row.flowNextActionLabel(l10n);
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(label);
      case ReceptionDeskSection.paymentGate:
        final ReceptionPaymentGateEntry? entry = row.paymentGateEntry;
        if (entry == null) {
          return const SizedBox.shrink();
        }
        return Text(
          <String>[
            entry.services
                .map((String source) => billingApiLabel(context, source))
                .join(', '),
            entry.outstandingByCurrency.entries
                .map(
                  (MapEntry<String, num> total) =>
                      billingMoney(context, total.value, total.key),
                )
                .join(' · '),
          ].where((String value) => value.isNotEmpty).join(' · '),
        );
    }
  }
}

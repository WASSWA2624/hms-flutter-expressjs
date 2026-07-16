import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/claims/presentation/widgets/insurance_authorization_panel.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_bed_board_panel.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_clinical_order_actions.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_start_admission_dialog.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_transfer_request_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/ipd_actions/ipd_actions.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';

const List<AppRole> _ipdAdminActionRoles = <AppRole>[
  AppRole.superAdmin,
  AppRole.tenantAdmin,
  AppRole.facilityAdmin,
];

const AccessRequirement _ipdOperationalWriteRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    ..._ipdAdminActionRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.operations,
    AppRole.icuManager,
  ],
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.operationsWrite,
  ],
  activeModules: <String>['inpatient-bed-management'],
);

const AccessRequirement _ipdBedManageRequirement = AccessRequirement(
  anyRoles: _ipdAdminActionRoles,
  anyPermissions: <AppPermission>[
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ],
  activeModules: <String>['inpatient-bed-management'],
);

const AccessRequirement _ipdClinicalWriteRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    ..._ipdAdminActionRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.icuManager,
  ],
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>['inpatient-bed-management'],
);

class IpdWorkspacePage extends ConsumerStatefulWidget {
  const IpdWorkspacePage({this.initialQuery, super.key});

  final IpdAdmissionQuery? initialQuery;

  @override
  ConsumerState<IpdWorkspacePage> createState() => _IpdWorkspacePageState();
}

class _IpdWorkspacePageState extends ConsumerState<IpdWorkspacePage> {
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant IpdWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_querySignature(oldWidget.initialQuery) !=
        _querySignature(widget.initialQuery)) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  void _scheduleRouteQuery(IpdAdmissionQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    final String? signature = _querySignature(query);
    if (signature == null || _appliedRouteSignature == signature) {
      return;
    }
    _appliedRouteSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(IpdAdmissionQuery query) async {
    final IpdWorkspaceController controller = ref.read(
      ipdWorkspaceControllerProvider.notifier,
    );
    await controller.applyRouteQuery(query);
    if (!mounted) {
      return;
    }
    if (query.section.isBedBoard) {
      await controller.loadBedBoard();
    }
    if (!mounted || query.focusAdmissionId == null) {
      return;
    }
    await _openIpdDetailDialogById(context, ref, query.focusAdmissionId!);
  }

  String? _querySignature(IpdAdmissionQuery? query) {
    if (query == null) {
      return null;
    }
    return '${query.search}|${query.wardId}|${query.scope.name}'
        '|${query.section.name}|${query.focusAdmissionId}'
        '|${query.focusPanel?.name}';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<IpdWorkspaceState>> state = ref.watch(
      ipdWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<IpdWorkspaceState>(
      value: state,
      loadingTitle: l10n.ipdLoadingTitle,
      loadingBody: l10n.ipdLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(ipdWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, IpdWorkspaceState data) {
        return _IpdWorkspaceContent(
          state: data,
          initialQuery: widget.initialQuery,
        );
      },
    );
  }
}

class _IpdWorkspaceContent extends ConsumerStatefulWidget {
  const _IpdWorkspaceContent({required this.state, this.initialQuery});

  final IpdWorkspaceState state;
  final IpdAdmissionQuery? initialQuery;

  @override
  ConsumerState<_IpdWorkspaceContent> createState() =>
      _IpdWorkspaceContentState();
}

class _IpdWorkspaceContentState extends ConsumerState<_IpdWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<IpdAdmissionSummary>
  _tableColumnController;
  late IpdWorkspaceSection _section;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<IpdAdmissionSummary>();
    _section = widget.initialQuery?.section ?? widget.state.query.section;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _applySectionFilter(_section);
    });
  }

  void _applySectionFilter(IpdWorkspaceSection section) {
    final IpdWorkspaceController controller = ref.read(
      ipdWorkspaceControllerProvider.notifier,
    );
    final IpdQueueScope? scope = section.queueScope;
    if (scope != null) {
      if (scope != widget.state.query.scope) {
        unawaited(controller.applyScope(scope));
      }
    } else if (section.isBedBoard) {
      unawaited(controller.loadBedBoard());
    }
  }

  void _selectSection(IpdWorkspaceSection section) {
    if (_section == section) return;
    setState(() => _section = section);
    _applySectionFilter(section);
    _updateUrlForSection(section);
  }

  void _updateUrlForSection(IpdWorkspaceSection section) {
    if (!mounted) return;
    final String sectionValue = _sectionToQueryValue(section);
    final String location = AppRoutes.ipd.location(
      queryParameters: <String, String>{
        if (sectionValue.isNotEmpty) 'section': sectionValue,
      },
    );
    GoRouter.of(context).replace<void>(location);
  }

  static String _sectionToQueryValue(IpdWorkspaceSection section) {
    return switch (section) {
      IpdWorkspaceSection.admissionQueue => 'admission-queue',
      IpdWorkspaceSection.activePatients => 'active',
      IpdWorkspaceSection.transferPending => 'transfers',
      IpdWorkspaceSection.dischargePlanned => 'discharge',
      IpdWorkspaceSection.bedBoard => 'bed-board',
    };
  }

  @override
  void didUpdateWidget(covariant _IpdWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final IpdWorkspaceState state = widget.state;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canManageBeds = _ipdBedManageRequirement.isAllowed(policy);

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                AppTabItem(
                  id: IpdWorkspaceSection.admissionQueue.name,
                  icon: Icons.bed_outlined,
                  label: l10n.ipdAdmissionQueueTabLabel,
                  count: _tabCount(state.admissionQueueCount),
                  countTone: AppTabCountTone.warning,
                ),
                AppTabItem(
                  id: IpdWorkspaceSection.activePatients.name,
                  icon: Icons.local_hospital_outlined,
                  label: l10n.ipdActivePatientsTabLabel,
                  count: _tabCount(state.activePatientCount),
                ),
                AppTabItem(
                  id: IpdWorkspaceSection.transferPending.name,
                  icon: Icons.swap_horiz,
                  label: l10n.ipdTransfersTabLabel,
                  count: _tabCount(state.transferPendingCount),
                  countTone: AppTabCountTone.warning,
                ),
                AppTabItem(
                  id: IpdWorkspaceSection.dischargePlanned.name,
                  icon: Icons.fact_check_outlined,
                  label: l10n.ipdDischargeTabLabel,
                  count: _tabCount(state.dischargePlannedCount),
                  countTone: AppTabCountTone.warning,
                ),
                AppTabItem(
                  id: IpdWorkspaceSection.bedBoard.name,
                  icon: Icons.grid_view_outlined,
                  label: l10n.ipdBedBoardTab,
                ),
              ],
              selectedId: _section.name,
              onTabTapped: (String id) {
                final IpdWorkspaceSection section = IpdWorkspaceSection.values
                    .firstWhere(
                      (IpdWorkspaceSection s) => s.name == id,
                      orElse: () => IpdWorkspaceSection.admissionQueue,
                    );
                _selectSection(section);
              },
              primaryAction: _buildPrimaryAction(l10n, state, canManageBeds),
              secondaryActions: _buildSecondaryActions(
                l10n,
                state,
                canManageBeds,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            if (_section.isBedBoard)
              IpdBedBoardPanel(
                state: state,
                canManageBeds: canManageBeds,
                onOpenAdmission: (IpdBedBoardEntry bed) {
                  final String? admissionId =
                      bed.occupantAdmissionId ?? bed.occupantAdmissionDisplayId;
                  if (admissionId != null) {
                    unawaited(
                      _openIpdDetailDialogById(context, ref, admissionId),
                    );
                  }
                },
              )
            else
              _IpdBoardPanel(
                state: state,
                section: _section,
                searchController: _searchController,
                columnVisibilityController: _tableColumnController,
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildPrimaryAction(
    AppLocalizations l10n,
    IpdWorkspaceState state,
    bool canManageBeds,
  ) {
    if (_section.isBedBoard && canManageBeds) {
      return AppTabToolbarPrimary(
        label: l10n.ipdBedBoardManageBedsAction,
        icon: Icons.open_in_new,
        tooltip: l10n.ipdBedBoardManageBedsAction,
        semanticLabel: l10n.ipdBedBoardManageBedsAction,
        onPressed: () => context.go(AppRoutes.roomsBeds.path),
      );
    }
    return AppAccessActionGate(
      requirement: _ipdOperationalWriteRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppTabToolbarPrimary(
          label: l10n.ipdStartAdmissionAction,
          icon: Icons.person_add_alt_1_outlined,
          tooltip: l10n.ipdStartAdmissionAction,
          semanticLabel: l10n.ipdStartAdmissionAction,
          enabled: isAllowed && !state.isSaving,
          onPressed: isAllowed
              ? () => unawaited(_openStartAdmissionDialog(context))
              : null,
        );
      },
    );
  }

  List<Widget> _buildSecondaryActions(
    AppLocalizations l10n,
    IpdWorkspaceState state,
    bool canManageBeds,
  ) {
    return <Widget>[
      AppTabToolbarAction(
        label: l10n.commonRefreshActionLabel,
        icon: Icons.refresh,
        tooltip: l10n.commonRefreshActionLabel,
        semanticLabel: l10n.commonRefreshActionLabel,
        onPressed: () {
          unawaited(
            ref.read(ipdWorkspaceControllerProvider.notifier).refresh(),
          );
        },
      ),
      if (_section.isBedBoard && canManageBeds)
        AppAccessActionGate(
          requirement: _ipdOperationalWriteRequirement,
          builder: (BuildContext context, bool isAllowed) {
            return AppTabToolbarAction(
              label: l10n.ipdStartAdmissionAction,
              icon: Icons.person_add_alt_1_outlined,
              tooltip: l10n.ipdStartAdmissionAction,
              semanticLabel: l10n.ipdStartAdmissionAction,
              enabled: isAllowed && !state.isSaving,
              onPressed: isAllowed
                  ? () => unawaited(_openStartAdmissionDialog(context))
                  : null,
            );
          },
        ),
    ];
  }

  static int? _tabCount(int count) => count > 0 ? count : null;

  Future<void> _openStartAdmissionDialog(BuildContext context) async {
    final IpdWorkspaceState state = widget.state;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          IpdStartAdmissionDialog(referenceData: state.referenceData),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }
}

class _IpdBoardPanel extends ConsumerWidget {
  const _IpdBoardPanel({
    required this.state,
    required this.section,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final IpdWorkspaceState state;
  final IpdWorkspaceSection section;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<IpdAdmissionSummary>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IpdWorkspaceController controller = ref.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final List<AppListTableColumn<IpdAdmissionSummary>> defaultColumns =
        _ipdAdmissionDefaultColumns(context);
    final List<AppListTableColumn<IpdAdmissionSummary>> optionalColumns =
        _ipdAdmissionOptionalColumns(context);

    return AppListTable<IpdAdmissionSummary>(
      page: state.admissions,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'ipd_${section.name}',
      columnWidthStorageKey: 'ipd_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columns: defaultColumns,
      columnChoices: optionalColumns,
      search: AppListTableSearch<IpdAdmissionSummary>(
        controller: searchController,
        semanticLabel: l10n.ipdSearchLabel,
        hintText: l10n.ipdSearchHint,
        matcher: (IpdAdmissionSummary admission, String query) =>
            _ipdAdmissionMatchesSearch(context, admission, query),
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.ipdFiltersLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        allFieldsLabel: l10n.ipdAllWardsOption,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _ipdWardFilterKey,
            label: l10n.ipdWardFilterLabel,
            allLabel: l10n.ipdAllWardsOption,
            choices: _ipdWardFilterChoices(state.referenceData.wards),
          ),
        ],
        filterValue: AppSearchBarFilterValue(
          options: <String, String>{
            if (state.query.wardId != null)
              _ipdWardFilterKey: state.query.wardId!,
          },
        ),
        hasActiveFilters: state.query.wardId != null,
        onFilterChanged: (AppSearchBarFilterValue value) async {
          final String? nextWardId = value.option(_ipdWardFilterKey);
          if (nextWardId != state.query.wardId) {
            final AppFailure? failure = await controller.applyWard(nextWardId);
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          }
        },
      ),
      previousPageLabel: l10n.opdPreviousPageLabel,
      nextPageLabel: l10n.opdNextPageLabel,
      pageLabelBuilder: (AppPage<IpdAdmissionSummary> page) {
        return _pageLabel(context, page);
      },
      onPageChanged: controller.changePage,
      onRowSelected: (IpdAdmissionSummary admission) {
        unawaited(_openIpdDetailDialog(context, ref, state, admission));
      },
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.ipdNoAdmissionsTitle,
        body: l10n.ipdNoAdmissionsBody,
        icon: Icons.bed_outlined,
      ),
      mobileItemBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return _IpdMobileAdmissionRow(admission: item);
      },
    );
  }
}

List<AppListTableColumn<IpdAdmissionSummary>> _ipdAdmissionDefaultColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<IpdAdmissionSummary>>[
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'patient',
      label: l10n.opdPatientColumnLabel,
      alwaysVisible: true,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(left.displayTitle, right.displayTitle),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return _IpdPatientCell(admission: item);
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'location',
      label: l10n.ipdLocationColumnLabel,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(left.location, right.location),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return Text(item.location ?? context.l10n.profileUnknownValue);
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'admitted_at',
      label: l10n.ipdAdmittedAtColumnLabel,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareDateTime(left.admittedAt, right.admittedAt),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return Text(_dateTimeLabel(context, item.admittedAt));
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'status',
      label: l10n.opdStatusColumnLabel,
      alwaysVisible: true,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(left.stage, right.stage),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return AppWorkspaceStatusBadge(
          status: _stageStatus(context, item.stage),
        );
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'next_action',
      label: l10n.ipdNextActionColumnLabel,
      alwaysVisible: true,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(left.nextStep, right.nextStep),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return _IpdAdmissionNextActionCell(admission: item);
      },
    ),
  ];
}

List<AppListTableColumn<IpdAdmissionSummary>> _ipdAdmissionOptionalColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<IpdAdmissionSummary>>[
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'owner_role',
      label: l10n.settingsWorkspaceModuleRole,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(
            _ipdOwnerRoleLabel(context, left.stage),
            _ipdOwnerRoleLabel(context, right.stage),
          ),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return Text(_ipdOwnerRoleLabel(context, item.stage));
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'length_of_stay',
      label: l10n.ipdLengthOfStayColumnLabel,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareDateTime(left.admittedAt, right.admittedAt),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return Text(_lengthOfStayLabel(context, item));
      },
    ),
  ];
}

bool _ipdAdmissionMatchesSearch(
  BuildContext context,
  IpdAdmissionSummary admission,
  String query,
) {
  if (admission.matchesSearch(query)) {
    return true;
  }
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  return <String>[
    _ipdOwnerRoleLabel(context, admission.stage),
    _dateTimeLabel(context, admission.admittedAt),
    _lengthOfStayLabel(context, admission),
    _stageLabel(context, admission.stage),
    _nextStepLabel(context, admission.nextStep),
  ].any((String value) => value.toLowerCase().contains(needle));
}

class _IpdAdmissionNextActionCell extends StatelessWidget {
  const _IpdAdmissionNextActionCell({required this.admission});

  final IpdAdmissionSummary admission;

  @override
  Widget build(BuildContext context) {
    final String encounterId = admission.encounterId ?? admission.id;
    if (encounterId.trim().isEmpty) {
      return Text(_nextStepLabel(context, admission.nextStep));
    }
    return WorkflowActionButton(
      encounterId: encounterId,
      patientId: admission.patientId,
      admissionId: admission.id,
      nextStep: admission.nextStep,
      stage: admission.stage,
      sourceModule: 'ipd',
      compact: true,
    );
  }
}

class _IpdPatientCell extends StatelessWidget {
  const _IpdPatientCell({required this.admission});

  final IpdAdmissionSummary admission;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          admission.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          admission.displayId ?? context.l10n.profileUnknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _IpdMobileAdmissionRow extends StatelessWidget {
  const _IpdMobileAdmissionRow({required this.admission});

  final IpdAdmissionSummary admission;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _IpdPatientCell(admission: admission)),
              SizedBox(width: theme.spacing.sm),
              AppWorkspaceStatusBadge(
                status: _stageStatus(context, admission.stage),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            admission.location ?? context.l10n.profileUnknownValue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: theme.spacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: _IpdAdmissionNextActionCell(admission: admission),
          ),
        ],
      ),
    );
  }
}

class _IpdDetailPanel extends ConsumerWidget {
  const _IpdDetailPanel({required this.state});

  final IpdWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IpdAdmissionDetail? admission = state.selectedAdmission;

    if (admission == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.ipdAdmissionDetailTitle,
        description: l10n.ipdAdmissionDetailDescription,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.ipdNoSelectionTitle,
          body: l10n.ipdNoSelectionBody,
          icon: Icons.manage_search_outlined,
        ),
      );
    }

    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canOperate = _ipdOperationalWriteRequirement.isAllowed(policy);
    final bool canClinical = _ipdClinicalWriteRequirement.isAllowed(policy);
    final bool actionsEnabled = !state.isSaving;

    return AppWorkspaceDetailPanel(
      title: l10n.ipdAdmissionDetailTitle,
      description: admission.summary.displayId ?? '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.isRefreshingDetail)
            const LinearProgressIndicator(minHeight: 2),
          AppPatientDetails(
            semanticLabel: l10n.ipdPatientContextLabel,
            patientName: admission.patientDisplayName,
            patientNumber: (admission.summary.patientId ?? '').trim(),
            patientNumberLabel: l10n.opdPatientIdLabel,
            ageLabel: admission.patientDateOfBirth == null
                ? null
                : AppFormatters.mediumDate(
                    admission.patientDateOfBirth!,
                    Localizations.localeOf(context),
                  ),
            genderLabel: admission.patientGender == null
                ? null
                : _apiLabel(admission.patientGender!),
            showAvatar: false,
            status: _stageStatus(context, admission.summary.stage),
            alerts: <AppWorkspaceStatus>[
              if (admission.summary.hasCriticalAlert)
                AppWorkspaceStatus(
                  label: _criticalAlertLabel(context, admission.summary),
                  tone: AppWorkspaceStatusTone.error,
                  icon: Icons.notification_important_outlined,
                ),
            ],
            expandedFields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.ipdAdmissionIdLabel,
                value: admission.summary.displayId ?? '',
                icon: Icons.confirmation_number_outlined,
                copyable: true,
                copyTooltip: l10n.copyAdmissionIdAction,
                copiedMessage: l10n.admissionIdCopiedMessage,
              ),
              AppWorkspacePatientContextField(
                label: l10n.ipdEncounterIdLabel,
                value: admission.summary.encounterId ?? '',
                icon: Icons.assignment_outlined,
                copyable: (admission.summary.encounterId ?? '').isNotEmpty,
                copyTooltip: l10n.opdCopyEncounterIdAction,
                copiedMessage: l10n.opdEncounterIdCopiedMessage,
              ),
              AppWorkspacePatientContextField(
                label: l10n.ipdWardBedLabel,
                value: admission.summary.location ?? l10n.profileUnknownValue,
                icon: Icons.bed_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.ipdFacilityLabel,
                value: admission.facilityName ?? l10n.profileUnknownValue,
                icon: Icons.apartment_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.ipdIcuStatusLabel,
                value: _icuStatusLabel(context, admission.icu.status),
                icon: Icons.monitor_heart_outlined,
                tone: admission.icu.hasCriticalAlert
                    ? AppWorkspaceStatusTone.error
                    : AppWorkspaceStatusTone.neutral,
              ),
            ],
            actions: <Widget>[
              _IpdDetailActions(
                admission: admission,
                state: state,
                canOperate: canOperate,
                canClinical: canClinical,
                actionsEnabled: actionsEnabled,
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          if (admission.sourceContext != null)
            _IpdSourceContextSection(admission: admission),
          if (admission.theatre.handoverSummary != null)
            _IpdTheatreHandoverSection(admission: admission),
          _IpdBedSection(admission: admission),
          InsuranceAuthorizationPanel(
            patientId: admission.summary.patientId,
            admissionId: admission.summary.id,
            encounterId: admission.summary.encounterId,
            canManage: canOperate,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _IpdRecordSection(
            title: l10n.ipdTransfersSectionTitle,
            icon: Icons.swap_horiz,
            records: <IpdClinicalRecord>[
              for (final IpdTransferRequest request
                  in admission.transferRequests)
                IpdClinicalRecord(
                  id: request.id,
                  kind: _ipdTransferKind,
                  status: request.status,
                  title: _joinDisplay(<String?>[
                    request.fromWard?.displayTitle,
                    request.toWard?.displayTitle,
                  ]),
                  occurredAt: request.requestedAt,
                ),
            ],
            emptyTitle: l10n.ipdNoTransfersTitle,
            emptyBody: l10n.ipdNoTransfersBody,
          ),
          _IpdRecordSection(
            title: l10n.ipdRoundsSectionTitle,
            icon: Icons.fact_check_outlined,
            records: admission.wardRounds,
            emptyTitle: l10n.ipdNoRoundsTitle,
            emptyBody: l10n.ipdNoRoundsBody,
          ),
          _IpdRecordSection(
            title: l10n.ipdNursingSectionTitle,
            icon: Icons.note_alt_outlined,
            records: admission.nursingNotes,
            emptyTitle: l10n.ipdNoNursingNotesTitle,
            emptyBody: l10n.ipdNoNursingNotesBody,
          ),
          _IpdRecordSection(
            title: l10n.ipdMedicationSectionTitle,
            icon: Icons.medication_outlined,
            records: <IpdClinicalRecord>[
              ...admission.medicationAdministrations,
              ...admission.medicationReminders,
            ],
            emptyTitle: l10n.ipdNoMedicationTitle,
            emptyBody: l10n.ipdNoMedicationBody,
          ),
          _IpdDischargeSection(admission: admission),
          _IpdTimelineSection(admission: admission),
        ],
      ),
    );
  }
}

Future<void> _openIpdDetailDialog(
  BuildContext context,
  WidgetRef ref,
  IpdWorkspaceState fallbackState,
  IpdAdmissionSummary admission,
) async {
  final IpdWorkspaceController controller = ref.read(
    ipdWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectAdmission(admission);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final IpdWorkspaceState state = _readIpdState(ref) ?? fallbackState;
  if (state.selectedAdmission == null) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.ipdAdmissionDetailTitle),
      icon: const Icon(Icons.bed_outlined),
      scrollable: true,
      maxWidth: 980,
      content: _IpdDetailPanel(state: state),
    ),
  );
}

Future<void> _openIpdDetailDialogById(
  BuildContext context,
  WidgetRef ref,
  String admissionId,
) async {
  final IpdWorkspaceController controller = ref.read(
    ipdWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectAdmissionById(admissionId);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }
  final IpdWorkspaceState? state = _readIpdState(ref);
  if (state == null || state.selectedAdmission == null) {
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.ipdAdmissionDetailTitle),
      icon: const Icon(Icons.bed_outlined),
      scrollable: true,
      maxWidth: 980,
      content: _IpdDetailPanel(state: state),
    ),
  );
}

IpdWorkspaceState? _readIpdState(WidgetRef ref) {
  return ref
      .read(ipdWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (IpdWorkspaceState state) => state, failure: (_) => null);
}

class _IpdDetailActions extends ConsumerWidget {
  const _IpdDetailActions({
    required this.admission,
    required this.state,
    required this.canOperate,
    required this.canClinical,
    required this.actionsEnabled,
  });

  final IpdAdmissionDetail admission;
  final IpdWorkspaceState state;
  final bool canOperate;
  final bool canClinical;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IpdAdmissionSummary summary = admission.summary;
    final bool terminal = summary.isTerminal;
    final bool activeBed = summary.hasActiveBed;
    final bool dischargePlanned = summary.stage == _stageDischargePlanned;
    final bool admissionRequested = summary.stage == _stageAdmissionRequested;
    final bool hasOpenTransfer = admission.openTransferRequest != null;
    final String icuStatus = (admission.icu.status ?? '').toUpperCase();
    final bool icuActive = icuStatus == 'ACTIVE';
    final bool icuEligible = activeBed && !terminal && !icuActive;

    return AppActionList(
      actions: <AppActionItem>[
        if (icuActive || admission.icu.hasCriticalAlert)
          AppActionItem(
            label: l10n.ipdOpenIcuAction,
            leadingIcon: Icons.monitor_heart_outlined,
            onPressed: () => _openIcuWorkspace(context, summary),
          ),
        if (summary.hasActiveTheatreCase)
          AppActionItem(
            label: l10n.ipdOpenTheaterAction,
            leadingIcon: Icons.event_seat_outlined,
            onPressed: () => _openTheaterWorkspace(context, summary),
          ),
        if (canClinical && icuEligible)
          AppActionItem(
            label: l10n.ipdStartIcuStayAction,
            leadingIcon: Icons.play_circle_outline,
            enabled: canClinical && actionsEnabled,
            onPressed: () => _confirmStartIcuStay(context, ref, summary),
          ),
        if (canOperate && admissionRequested && !terminal)
          AppActionItem(
            label: l10n.ipdApproveAdmissionAction,
            leadingIcon: Icons.check_circle_outline,
            enabled: canOperate && actionsEnabled,
            variant: AppActionVariant.primary,
            onPressed: () => _confirmApproveAdmission(context, ref, summary),
          ),
        if (canOperate && !activeBed && !terminal && !admissionRequested)
          AppActionItem(
            label: l10n.ipdAssignBedAction,
            leadingIcon: Icons.bed_outlined,
            enabled: canOperate && actionsEnabled,
            onPressed: () => _openAssignBedDialog(context, ref),
          ),
        if (canOperate && activeBed && dischargePlanned && !terminal)
          AppActionItem(
            label: l10n.ipdReleaseBedAction,
            leadingIcon: AppActionIcons.cleaning,
            enabled: canOperate && actionsEnabled,
            onPressed: () => _openReleaseBedDialog(context, ref),
          ),
        if (canOperate &&
            activeBed &&
            !hasOpenTransfer &&
            !dischargePlanned &&
            !terminal)
          AppActionItem(
            label: l10n.ipdRequestTransferAction,
            leadingIcon: AppActionIcons.transfer,
            enabled: canOperate && actionsEnabled,
            onPressed: () => _openTransferRequestDialog(context, ref),
          ),
        if (canOperate && hasOpenTransfer && !terminal)
          AppActionItem(
            label: l10n.ipdManageTransferAction,
            leadingIcon: Icons.move_down_outlined,
            enabled: canOperate && actionsEnabled,
            onPressed: () => _openTransferUpdateDialog(context, ref),
          ),
        if (canClinical && activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdOrderLabAction,
            leadingIcon: Icons.biotech_outlined,
            enabled: canClinical && actionsEnabled,
            onPressed: () =>
                _openClinicalOrder(context, openIpdLabOrderDialog(context)),
          ),
        if (canClinical && activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdOrderRadiologyAction,
            leadingIcon: Icons.medical_services_outlined,
            enabled: canClinical && actionsEnabled,
            onPressed: () => _openClinicalOrder(
              context,
              openIpdRadiologyOrderDialog(context),
            ),
          ),
        if (canClinical && activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdRequestTherapyAction,
            leadingIcon: Icons.accessibility_new_outlined,
            enabled: canClinical && actionsEnabled,
            onPressed: () => _openRequestTherapyDialog(context, ref),
          ),
        if (canClinical && activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdOpenPhysiotherapyAction,
            leadingIcon: Icons.open_in_new_outlined,
            enabled: canClinical && actionsEnabled,
            onPressed: () {
              final String? encounterId = admission.summary.encounterId;
              if (encounterId == null || encounterId.isEmpty) {
                return;
              }
              context.go(
                AppRoutes.physiotherapy.location(
                  queryParameters: <String, String>{'encounterId': encounterId},
                ),
              );
            },
          ),
        if (canClinical && activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdOrderPrescriptionAction,
            leadingIcon: Icons.medication_outlined,
            enabled: canClinical && actionsEnabled,
            onPressed: () =>
                _openClinicalOrder(context, openIpdPrescriptionDialog(context)),
          ),
        if (canClinical && activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdOpenNursingAction,
            leadingIcon: Icons.local_hospital_outlined,
            onPressed: () => _openNursingWorkspace(context, summary),
          ),
        if (canClinical && activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdAddWardRoundAction,
            leadingIcon: Icons.fact_check_outlined,
            enabled: canClinical && actionsEnabled,
            onPressed: () => _openWardRoundDialog(context, ref, summary),
          ),
        if (canClinical && activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdAddNursingNoteAction,
            leadingIcon: Icons.note_add_outlined,
            enabled: canClinical && actionsEnabled,
            onPressed: () => _openTextActionDialog(
              context,
              ref,
              title: l10n.ipdAddNursingNoteAction,
              icon: Icons.note_add_outlined,
              fieldLabel: l10n.ipdNotesFieldLabel,
              submitLabel: l10n.ipdAddNursingNoteAction,
              onSubmit: (String value) => ref
                  .read(ipdWorkspaceControllerProvider.notifier)
                  .addNursingNote(summary, value),
            ),
          ),
        if (canClinical && activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdRecordMedicationAction,
            leadingIcon: Icons.medication_outlined,
            enabled: canClinical && actionsEnabled,
            onPressed: () => _openMedicationDialog(context, ref),
          ),
        if (canClinical && activeBed && !dischargePlanned && !terminal)
          AppActionItem(
            label: l10n.ipdPlanDischargeAction,
            leadingIcon: Icons.fact_check_outlined,
            enabled: canClinical && actionsEnabled,
            onPressed: () => _openDischargeClearanceDialog(context, ref),
          ),
        if (canClinical && dischargePlanned && !terminal)
          AppActionItem(
            label: l10n.ipdManageDischargeTitle,
            leadingIcon: Icons.logout_outlined,
            enabled: canClinical && actionsEnabled,
            variant: AppActionVariant.primary,
            onPressed: () => _openDischargeClearanceDialog(context, ref),
          ),
        if (canOperate && !activeBed && !terminal)
          AppActionItem(
            label: l10n.ipdRejectAdmissionAction,
            leadingIcon: Icons.cancel_outlined,
            enabled: canOperate && actionsEnabled,
            variant: AppActionVariant.tertiary,
            onPressed: () => _openTextActionDialog(
              context,
              ref,
              title: l10n.ipdRejectAdmissionAction,
              icon: Icons.cancel_outlined,
              fieldLabel: l10n.ipdReasonFieldLabel,
              submitLabel: l10n.ipdRejectAdmissionAction,
              onSubmit: (String value) => ref
                  .read(ipdWorkspaceControllerProvider.notifier)
                  .rejectAdmission(summary, value),
            ),
          ),
      ],
    );
  }

  void _openIcuWorkspace(BuildContext context, IpdAdmissionSummary summary) {
    final String? displayId = summary.displayId?.trim();
    final String location = displayId == null || displayId.isEmpty
        ? AppRoutes.icu.path
        : AppRoutes.icu.location(
            queryParameters: <String, String>{'id': displayId},
          );
    context.go(location);
  }

  void _openTheaterWorkspace(
    BuildContext context,
    IpdAdmissionSummary summary,
  ) {
    final String? caseId = summary.activeTheatreCaseId?.trim();
    final String location = caseId == null || caseId.isEmpty
        ? AppRoutes.theater.path
        : AppRoutes.theater.location(
            queryParameters: <String, String>{'id': caseId},
          );
    context.go(location);
  }

  void _openNursingWorkspace(
    BuildContext context,
    IpdAdmissionSummary summary,
  ) {
    final String? displayId = summary.displayId?.trim();
    final String location = displayId == null || displayId.isEmpty
        ? AppRoutes.nursing.path
        : AppRoutes.nursing.location(
            queryParameters: <String, String>{
              'id': displayId,
              'panel': 'nursing',
            },
          );
    context.go(location);
  }

  Future<void> _openClinicalOrder(
    BuildContext context,
    Future<bool?> dialogFuture,
  ) async {
    final bool? saved = await dialogFuture;
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openDischargeClearanceDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final IpdWorkspaceState? state = _readIpdState(ref);
    final IpdAdmissionDetail? admission = state?.selectedAdmission;
    if (admission == null) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool dischargePlanned =
        (admission.latestDischargeSummary?.status ?? '').toUpperCase() ==
        'PLANNED';
    final bool? saved = await showDischargePlanningDialog(
      context: context,
      ref: ref,
      admissionId: admission.summary.apiId,
      title: Text(
        dischargePlanned
            ? l10n.ipdManageDischargeTitle
            : l10n.ipdPlanDischargeAction,
      ),
      onFailure: (AppFailure failure) => _showFailureIfNeeded(context, failure),
    );
    if (saved == true && context.mounted) {
      await ref.read(ipdWorkspaceControllerProvider.notifier).refresh();
      if (context.mounted) {
        _showSaved(context);
      }
    }
  }

  Future<void> _confirmApproveAdmission(
    BuildContext context,
    WidgetRef ref,
    IpdAdmissionSummary summary,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.ipdApproveAdmissionAction,
        body: l10n.ipdApproveAdmissionBody,
        submitLabel: l10n.ipdApproveAdmissionAction,
        icon: const Icon(Icons.check_circle_outline),
        onConfirm: () => ref
            .read(ipdWorkspaceControllerProvider.notifier)
            .approveAdmission(summary),
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _confirmStartIcuStay(
    BuildContext context,
    WidgetRef ref,
    IpdAdmissionSummary summary,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.ipdStartIcuStayAction,
        body: l10n.ipdStartIcuStayBody,
        submitLabel: l10n.ipdStartIcuStayAction,
        icon: const Icon(Icons.play_circle_outline),
        onConfirm: () => ref
            .read(ipdWorkspaceControllerProvider.notifier)
            .startIcuStay(summary),
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openAssignBedDialog(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalAdmissionActionDialog(
        title: l10n.ipdAssignBedAction,
        submitLabel: l10n.ipdAssignBedAction,
        referenceData: _ipdAdmissionReferenceData(context, state.referenceData),
        onSubmit: (ClinicalActionAdmissionInput input) {
          final ClinicalActionCatalogOption? bed = input.bed;
          if (bed == null) {
            return Future<AppFailure?>.value(AppFailure.validation());
          }
          return ref
              .read(ipdWorkspaceControllerProvider.notifier)
              .assignBed(admission.summary, bed.apiId);
        },
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openReleaseBedDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final IpdAdmissionSummary summary = admission.summary;
    final bool? saved = await showIpdReleaseBedDialog(
      context: context,
      onConfirm: () => ref
          .read(ipdWorkspaceControllerProvider.notifier)
          .releaseBed(summary),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openTransferRequestDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferRequestDialog(
        admission: admission,
        wards: state.referenceData.wards,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (saved == true) {
      _showSaved(context);
    }
  }

  Future<void> _openRequestTherapyDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RequestTherapyDialog(admission: admission.summary),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openTransferUpdateDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferUpdateDialog(
        admission: admission,
        beds: state.referenceData.availableBeds,
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openMedicationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicationAdministrationDialog(admission: admission),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openTextActionDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required IconData icon,
    required String fieldLabel,
    required String submitLabel,
    required Future<AppFailure?> Function(String value) onSubmit,
    String? initialValue,
  }) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: title,
        icon: Icon(icon),
        label: fieldLabel,
        submitLabel: submitLabel,
        initialValue: initialValue,
        minLines: 3,
        maxLines: 8,
        onSubmit: onSubmit,
      ),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }

  Future<void> _openWardRoundDialog(
    BuildContext context,
    WidgetRef ref,
    IpdAdmissionSummary summary,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WardRoundActionDialog(summary: summary),
    );
    if (saved == true && context.mounted) {
      _showSaved(context);
    }
  }
}

class _WardRoundActionDialog extends ConsumerStatefulWidget {
  const _WardRoundActionDialog({required this.summary});

  final IpdAdmissionSummary summary;

  @override
  ConsumerState<_WardRoundActionDialog> createState() =>
      _WardRoundActionDialogState();
}

class _WardRoundActionDialogState
    extends ConsumerState<_WardRoundActionDialog> {
  final TextEditingController _notesController = TextEditingController();
  ClinicalRequestBillingSubmit? _billing;
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);
    final ClinicalRequestBillingSubmit? billing = _billing;
    final bool charge =
        billing != null &&
        billing.paymentStatus != ClinicalRequestPaymentStatus.notBilled &&
        billing.totalAmount > 0;
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .addWardRound(
          widget.summary,
          _notesController.text.trim(),
          billing: charge ? billing.toPayloadMap() : null,
        );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      _showFailureIfNeeded(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRequestBillingLineItem> lineItems =
        <ClinicalRequestBillingLineItem>[
          ClinicalRequestBillingLineItem(
            id: 'WARD_ROUND_FEE',
            label: l10n.ipdWardRoundFeeLabel,
          ),
        ];

    return AppDialog(
      title: Text(l10n.ipdAddWardRoundAction),
      icon: const Icon(Icons.fact_check_outlined),
      maxWidth: 560,
      scrollable: true,
      closeEnabled: !_submitting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _notesController,
            labelText: l10n.ipdNotesFieldLabel,
            minLines: 3,
            maxLines: 8,
            enabled: !_submitting,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          ClinicalRequestBillingPanel(
            lineItems: lineItems,
            enabled: !_submitting,
            onChanged: (ClinicalRequestBillingSubmit value) {
              _billing = value;
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_submitting,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.ipdAddWardRoundAction,
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _IpdBedSection extends StatelessWidget {
  const _IpdBedSection({required this.admission});

  final IpdAdmissionDetail admission;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IpdBedAssignment? assignment = admission.activeBedAssignment;
    final IpdBedOption? bed = assignment?.bed;
    return _IpdSection(
      title: l10n.ipdBedSectionTitle,
      icon: Icons.bed_outlined,
      child: _IpdKeyValueGrid(
        values: <_IpdKeyValue>[
          _IpdKeyValue(l10n.ipdBedFieldLabel, bed?.displayTitle),
          _IpdKeyValue(l10n.ipdWardBedLabel, admission.summary.location),
          _IpdKeyValue(
            l10n.opdStatusColumnLabel,
            bed?.status == null ? null : _bedStatusLabel(context, bed!.status),
          ),
          _IpdKeyValue(
            l10n.ipdAdmittedAtColumnLabel,
            _dateTimeLabel(context, admission.summary.admittedAt),
          ),
        ],
      ),
    );
  }
}

class _IpdDischargeSection extends StatelessWidget {
  const _IpdDischargeSection({required this.admission});

  final IpdAdmissionDetail admission;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IpdDischargeSummary? discharge = admission.latestDischargeSummary;
    final IpdPharmacyClearance pharmacy = admission.pharmacyClearance;
    return _IpdSection(
      title: l10n.ipdDischargeSectionTitle,
      icon: Icons.logout_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _IpdKeyValueGrid(
            values: <_IpdKeyValue>[
              _IpdKeyValue(
                l10n.opdStatusColumnLabel,
                discharge?.status == null
                    ? null
                    : _dischargeStatusLabel(context, discharge!.status),
              ),
              _IpdKeyValue(
                l10n.ipdDischargedAtLabel,
                _dateTimeLabel(context, discharge?.dischargedAt),
              ),
              _IpdKeyValue(
                l10n.ipdDischargeClearancePhaseLabel,
                discharge?.clearancePhase == null
                    ? null
                    : _clearancePhaseLabel(context, discharge!.clearancePhase),
              ),
              _IpdKeyValue(
                l10n.ipdPharmacyClearanceLabel,
                pharmacy.hasClearance
                    ? l10n.ipdPharmacyClearanceCleared
                    : l10n.ipdPharmacyClearancePending(pharmacy.openOrderCount),
              ),
            ],
          ),
          if (!pharmacy.hasClearance && pharmacy.orders.isNotEmpty) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.sm),
            ...pharmacy.orders.map(
              (IpdPharmacyOrderSummary order) => Padding(
                padding: EdgeInsets.only(bottom: Theme.of(context).spacing.xs),
                child: Text(
                  _joinDisplay(<String?>[
                        order.id,
                        order.status == null
                            ? null
                            : _statusLikeLabel(context, order.status),
                        _dateTimeLabel(context, order.orderedAt),
                      ]) ??
                      '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
          if ((discharge?.summary ?? '').trim().isNotEmpty) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.sm),
            Text(discharge!.summary!),
          ],
        ],
      ),
    );
  }
}

class _IpdSourceContextSection extends StatelessWidget {
  const _IpdSourceContextSection({required this.admission});

  final IpdAdmissionDetail admission;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IpdSourceContext? source = admission.sourceContext;
    if (source == null) {
      return const SizedBox.shrink();
    }
    return _IpdSection(
      title: l10n.ipdSourceContextTitle,
      icon: Icons.input_outlined,
      child: _IpdKeyValueGrid(
        values: <_IpdKeyValue>[
          _IpdKeyValue(
            l10n.ipdSourceKindLabel,
            _sourceKindLabel(context, source.kind),
          ),
          _IpdKeyValue(
            l10n.ipdEncounterTypeLabel,
            source.encounterType == null
                ? null
                : _apiLabel(source.encounterType!),
          ),
          _IpdKeyValue(
            l10n.opdStatusColumnLabel,
            source.encounterStatus == null
                ? null
                : _apiLabel(source.encounterStatus!),
          ),
          _IpdKeyValue(
            l10n.ipdAdmittedAtColumnLabel,
            _dateTimeLabel(context, source.startedAt),
          ),
        ],
      ),
    );
  }
}

class _IpdTheatreHandoverSection extends StatelessWidget {
  const _IpdTheatreHandoverSection({required this.admission});

  final IpdAdmissionDetail admission;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IpdTheatreHandoverSummary? handover =
        admission.theatre.handoverSummary;
    if (handover == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: Theme.of(context).spacing.md),
      child: _IpdSection(
        title: l10n.ipdTheatreHandoverTitle,
        icon: Icons.event_seat_outlined,
        child: _IpdKeyValueGrid(
          values: <_IpdKeyValue>[
            _IpdKeyValue(l10n.theaterCaseIdColumnLabel, handover.caseDisplayId),
            _IpdKeyValue(
              l10n.theaterStageLabel,
              handover.workflowStage == null
                  ? null
                  : _apiLabel(handover.workflowStage!),
            ),
            _IpdKeyValue(
              l10n.theaterHandoverDestinationLabel,
              handover.handoverDestination == null
                  ? null
                  : _apiLabel(handover.handoverDestination!),
            ),
            _IpdKeyValue(l10n.theaterPostOpNoteLabel, handover.postOpNote),
            _IpdKeyValue(l10n.theaterStageNotesLabel, handover.stageNotes),
          ],
        ),
      ),
    );
  }
}

class _IpdTimelineSection extends StatelessWidget {
  const _IpdTimelineSection({required this.admission});

  final IpdAdmissionDetail admission;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> items = admission.timeline
        .map(
          (IpdTimelineItem item) => AppWorkspaceActivityItem(
            title: _timelineTypeLabel(context, item.type),
            subtitle: _dateTimeLabel(context, item.occurredAt),
            description: item.label,
            icon: Icons.timeline_outlined,
          ),
        )
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(top: Theme.of(context).spacing.md),
      child: AppWorkspaceActivityList(
        title: l10n.ipdTimelineSectionTitle,
        items: items,
        emptyTitle: l10n.ipdNoTimelineTitle,
        emptyBody: l10n.ipdNoTimelineBody,
      ),
    );
  }
}

class _IpdRecordSection extends StatelessWidget {
  const _IpdRecordSection({
    required this.title,
    required this.icon,
    required this.records,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final String title;
  final IconData icon;
  final List<IpdClinicalRecord> records;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    return _IpdSection(
      title: title,
      icon: icon,
      child: records.isEmpty
          ? AppStateView(
              variant: AppStateViewVariant.empty,
              title: emptyTitle,
              body: emptyBody,
              crossAxisAlignment: CrossAxisAlignment.center,
              textAlign: TextAlign.center,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  var index = 0;
                  index < records.length;
                  index += 1
                ) ...<Widget>[
                  _IpdRecordRow(record: records[index]),
                  if (index < records.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _IpdRecordRow extends StatelessWidget {
  const _IpdRecordRow({required this.record});

  final IpdClinicalRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            _recordIcon(record.kind),
            size: theme.appTokens.listIconSize,
            color: colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  record.title ?? record.id,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _joinDisplay(<String?>[
                        record.subtitle,
                        record.status == null
                            ? null
                            : _statusLikeLabel(context, record.status),
                        _dateTimeLabel(context, record.occurredAt),
                      ]) ??
                      context.l10n.profileUnknownValue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IpdSection extends StatelessWidget {
  const _IpdSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: theme.appTokens.listIconSize),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

final class _IpdKeyValue {
  const _IpdKeyValue(this.label, this.value);

  final String label;
  final String? value;
}

class _IpdKeyValueGrid extends StatelessWidget {
  const _IpdKeyValueGrid({required this.values});

  final List<_IpdKeyValue> values;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 420 ? 2 : 1;
        final double gap = theme.spacing.sm;
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final _IpdKeyValue value in values)
              SizedBox(
                width: width,
                child: _IpdKeyValueTile(item: value),
              ),
          ],
        );
      },
    );
  }
}

class _IpdKeyValueTile extends StatelessWidget {
  const _IpdKeyValueTile({required this.item});

  final _IpdKeyValue item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          item.value ?? context.l10n.profileUnknownValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class RequestTherapyDialog extends ConsumerStatefulWidget {
  const RequestTherapyDialog({required this.admission, super.key});

  final IpdAdmissionSummary admission;

  @override
  ConsumerState<RequestTherapyDialog> createState() =>
      _RequestTherapyDialogState();
}

class _RequestTherapyDialogState extends ConsumerState<RequestTherapyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _indicationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _indicationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.ipdRequestTherapyAction),
      icon: const Icon(Icons.accessibility_new_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppTextField(
              controller: _indicationController,
              labelText: l10n.physiotherapyReasonFieldLabel,
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
          label: l10n.ipdRequestTherapyAction,
          leadingIcon: Icons.accessibility_new_outlined,
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
        .read(ipdWorkspaceControllerProvider.notifier)
        .requestTherapy(
          admission: widget.admission,
          clinicalIndication: _indicationController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _isSaving = false;
        _failure = failure;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }
}

class TransferUpdateDialog extends ConsumerStatefulWidget {
  const TransferUpdateDialog({
    required this.admission,
    required this.beds,
    super.key,
  });

  final IpdAdmissionDetail admission;
  final List<IpdBedOption> beds;

  @override
  ConsumerState<TransferUpdateDialog> createState() =>
      _TransferUpdateDialogState();
}

class _TransferUpdateDialogState extends ConsumerState<TransferUpdateDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _action = _transferApprove;
  String? _bedId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final String status =
        widget.admission.openTransferRequest?.status?.toUpperCase() ?? '';
    if (status == _transferApproved) {
      _action = _transferStart;
    }
    if (status == _transferInProgress) {
      _action = _transferComplete;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.ipdManageTransferAction),
      icon: const Icon(Icons.move_down_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppSelectField<String>(
            value: _action,
            labelText: l10n.ipdTransferActionFieldLabel,
            enabled: !_isSaving,
            options: <AppSelectOption<String>>[
              AppSelectOption<String>(
                value: _transferApprove,
                label: l10n.ipdTransferApproveAction,
              ),
              AppSelectOption<String>(
                value: _transferStart,
                label: l10n.ipdTransferStartAction,
              ),
              AppSelectOption<String>(
                value: _transferComplete,
                label: l10n.ipdTransferCompleteAction,
              ),
              AppSelectOption<String>(
                value: _transferCancel,
                label: l10n.ipdTransferCancelAction,
              ),
            ],
            onChanged: _isSaving
                ? null
                : (String? value) {
                    if (value != null) {
                      setState(() => _action = value);
                    }
                  },
          ),
          if (_action == _transferComplete)
            AppSelectField<String>.searchable(
              value: _bedId,
              labelText: l10n.ipdDestinationBedFieldLabel,
              hintText: l10n.ipdSelectBedHint,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredValue<String>(
                l10n.validationRequired,
              ),
              options: <AppSelectOption<String>>[
                for (final IpdBedOption bed in widget.beds)
                  AppSelectOption<String>(
                    value: bed.id,
                    label:
                        _joinDisplay(<String?>[
                          bed.displayTitle,
                          bed.displaySubtitle,
                        ]) ??
                        bed.id,
                  ),
              ],
              onChanged: _isSaving
                  ? null
                  : (String? value) => setState(() => _bedId = value),
            ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.ipdManageTransferAction,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: Icons.move_down_outlined,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    if (_action == _transferComplete && _bedId == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .updateTransfer(
          admission: widget.admission.summary,
          action: _action,
          transferRequestId: widget.admission.openTransferRequest?.id,
          toBedId: _bedId,
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

class MedicationAdministrationDialog extends ConsumerStatefulWidget {
  const MedicationAdministrationDialog({required this.admission, super.key});

  final IpdAdmissionDetail admission;

  @override
  ConsumerState<MedicationAdministrationDialog> createState() =>
      _MedicationAdministrationDialogState();
}

class _MedicationAdministrationDialogState
    extends ConsumerState<MedicationAdministrationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _medicationController;
  late final TextEditingController _doseController;
  late final TextEditingController _unitController;
  late final TextEditingController _noteController;
  String? _prescriptionId;
  String _route = _medRouteOral;
  String _frequency = _medFrequencyOnce;
  String _status = _medStatusGiven;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _medicationController = TextEditingController();
    _doseController = TextEditingController();
    _unitController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _doseController.dispose();
    _unitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.ipdRecordMedicationAction),
      icon: const Icon(Icons.medication_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppSelectField<String>.searchable(
              value: _prescriptionId,
              labelText: l10n.ipdMedicationOrderFieldLabel,
              hintText: l10n.ipdMedicationOrderHint,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                for (final IpdMedicationSuggestion suggestion
                    in widget.admission.medicationSuggestions)
                  AppSelectOption<String>(
                    value: suggestion.id,
                    label:
                        _joinDisplay(<String?>[
                          suggestion.displayTitle,
                          suggestion.displaySubtitle,
                        ]) ??
                        suggestion.id,
                  ),
              ],
              onChanged: _selectSuggestion,
            ),
            AppTextField(
              controller: _medicationController,
              labelText: l10n.ipdMedicationFieldLabel,
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _doseController,
              labelText: l10n.ipdDoseFieldLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _unitController,
              labelText: l10n.ipdUnitFieldLabel,
              enabled: !_isSaving,
            ),
            AppSelectField<String>(
              value: _route,
              labelText: l10n.ipdRouteFieldLabel,
              enabled: !_isSaving,
              options: _routeOptions(l10n),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _route = value);
                }
              },
            ),
            AppSelectField<String>(
              value: _frequency,
              labelText: l10n.ipdFrequencyFieldLabel,
              enabled: !_isSaving,
              options: _frequencyOptions(l10n),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _frequency = value);
                }
              },
            ),
            AppSelectField<String>(
              value: _status,
              labelText: l10n.ipdMedicationStatusFieldLabel,
              enabled: !_isSaving,
              options: _medicationStatusOptions(l10n),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            AppTextField(
              controller: _noteController,
              labelText: l10n.ipdNotesFieldLabel,
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
          label: l10n.ipdRecordMedicationAction,
          leadingIcon: Icons.medication_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _selectSuggestion(String? value) {
    final IpdMedicationSuggestion? suggestion = _firstMedicationSuggestion(
      widget.admission.medicationSuggestions,
      value,
    );
    setState(() {
      _prescriptionId = value;
      if (suggestion != null) {
        _medicationController.text = suggestion.medicationLabel ?? '';
        _doseController.text = suggestion.dose ?? '';
        _unitController.text = suggestion.unit ?? '';
        _route = suggestion.route ?? _route;
        _frequency = suggestion.frequency ?? _frequency;
      }
    });
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
        .read(ipdWorkspaceControllerProvider.notifier)
        .addMedicationAdministration(
          widget.admission.summary,
          <String, Object?>{
            'prescription_id': _prescriptionId,
            'medication_label': _medicationController.text.trim(),
            'dose': _doseController.text.trim(),
            'unit': _unitController.text.trim(),
            'route': _route,
            'frequency': _frequency,
            'status': _status,
            'administration_note': _noteController.text.trim(),
            'administered_at': DateTime.now().toUtc().toIso8601String(),
          },
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

const String _ipdWardFilterKey = 'ward';

List<AppSearchBarFilterChoice> _ipdWardFilterChoices(
  List<IpdWardOption> wards,
) {
  return <AppSearchBarFilterChoice>[
    for (final IpdWardOption ward in wards)
      AppSearchBarFilterChoice(
        value: ward.id,
        label: ward.displayTitle,
        icon: Icons.local_hospital_outlined,
      ),
  ];
}

List<AppSelectOption<String>> _routeOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(value: _medRouteOral, label: l10n.ipdRouteOral),
    AppSelectOption<String>(value: _medRouteIv, label: l10n.ipdRouteIv),
    AppSelectOption<String>(value: _medRouteIm, label: l10n.ipdRouteIm),
    AppSelectOption<String>(
      value: _medRouteTopical,
      label: l10n.ipdRouteTopical,
    ),
    AppSelectOption<String>(
      value: _medRouteInhalation,
      label: l10n.ipdRouteInhalation,
    ),
    AppSelectOption<String>(value: _medRouteOther, label: l10n.ipdRouteOther),
  ];
}

List<AppSelectOption<String>> _frequencyOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _medFrequencyOnce,
      label: l10n.ipdFrequencyOnce,
    ),
    AppSelectOption<String>(
      value: _medFrequencyBid,
      label: l10n.ipdFrequencyBid,
    ),
    AppSelectOption<String>(
      value: _medFrequencyTid,
      label: l10n.ipdFrequencyTid,
    ),
    AppSelectOption<String>(
      value: _medFrequencyQid,
      label: l10n.ipdFrequencyQid,
    ),
    AppSelectOption<String>(
      value: _medFrequencyPrn,
      label: l10n.ipdFrequencyPrn,
    ),
    AppSelectOption<String>(
      value: _medFrequencyStat,
      label: l10n.ipdFrequencyStat,
    ),
    AppSelectOption<String>(
      value: _medFrequencyCustom,
      label: l10n.ipdFrequencyCustom,
    ),
  ];
}

List<AppSelectOption<String>> _medicationStatusOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _medStatusGiven,
      label: l10n.ipdMedicationGiven,
    ),
    AppSelectOption<String>(
      value: _medStatusMissed,
      label: l10n.ipdMedicationMissed,
    ),
    AppSelectOption<String>(
      value: _medStatusDelayed,
      label: l10n.ipdMedicationDelayed,
    ),
    AppSelectOption<String>(
      value: _medStatusRefused,
      label: l10n.ipdMedicationRefused,
    ),
  ];
}

String _ipdOwnerRoleLabel(BuildContext context, String? stage) {
  final AppLocalizations l10n = context.l10n;
  return switch ((stage ?? '').toUpperCase()) {
    _stageAdmittedPendingBed =>
      '${l10n.navigationOperationsLabel} / ${l10n.navigationNursingLabel}',
    _stageAdmittedInBed =>
      '${l10n.navigationNursingLabel} / ${l10n.opdWorkflowDoctorTitle}',
    _stageInProcedureOt => l10n.navigationTheaterLabel,
    _stageTransferRequested || _stageTransferInProgress =>
      '${l10n.navigationOperationsLabel} / ${l10n.navigationNursingLabel}',
    _stageDischargePlanned => _joinDisplay(<String>[
      l10n.opdWorkflowDoctorTitle,
      l10n.navigationNursingLabel,
      l10n.navigationBillingLabel,
      l10n.navigationPharmacyLabel,
    ])!,
    _stageDischarged => l10n.navigationDischargeLabel,
    _stageCancelled => l10n.navigationSetupLabel,
    _ => l10n.profileUnknownValue,
  };
}

AppWorkspaceStatus _stageStatus(BuildContext context, String? stage) {
  final AppWorkspaceStatusTone tone = switch ((stage ?? '').toUpperCase()) {
    _stageAdmittedInBed => AppWorkspaceStatusTone.info,
    _stageInProcedureOt => AppWorkspaceStatusTone.warning,
    _stageAdmittedPendingBed => AppWorkspaceStatusTone.warning,
    _stageAdmissionRequested => AppWorkspaceStatusTone.warning,
    _stageTransferRequested ||
    _stageTransferInProgress => AppWorkspaceStatusTone.warning,
    _stageDischargePlanned => AppWorkspaceStatusTone.success,
    _stageDischarged => AppWorkspaceStatusTone.neutral,
    _stageCancelled => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
  return AppWorkspaceStatus(label: _stageLabel(context, stage), tone: tone);
}

String _stageLabel(BuildContext context, String? stage) {
  final AppLocalizations l10n = context.l10n;
  return switch ((stage ?? '').toUpperCase()) {
    _stageAdmissionRequested => l10n.ipdStatusAdmissionRequested,
    _stageAdmittedPendingBed => l10n.ipdStatusAdmittedPendingBed,
    _stageAdmittedInBed => l10n.ipdStatusAdmittedInBed,
    _stageInProcedureOt => l10n.ipdStatusInProcedureOt,
    _stageTransferRequested => l10n.ipdStatusTransferRequested,
    _stageTransferInProgress => l10n.ipdStatusTransferInProgress,
    _stageDischargePlanned => l10n.ipdStatusDischargePlanned,
    _stageDischarged => l10n.ipdStatusDischarged,
    _stageCancelled => l10n.ipdStatusCancelled,
    _ => context.l10n.profileUnknownValue,
  };
}

String _nextStepLabel(BuildContext context, String? nextStep) {
  final AppLocalizations l10n = context.l10n;
  return switch ((nextStep ?? '').toUpperCase()) {
    'ASSIGN_BED' => l10n.ipdNextAssignBed,
    'RECORD_NURSING_NOTE' => l10n.ipdNextRecordNursingNote,
    'APPROVE_TRANSFER' => l10n.ipdNextApproveTransfer,
    'START_TRANSFER' => l10n.ipdNextStartTransfer,
    'COMPLETE_TRANSFER' => l10n.ipdNextCompleteTransfer,
    'COMPLETE_THEATRE_HANDOVER' => l10n.ipdNextCompleteTheatreHandover,
    'FINALIZE_DISCHARGE' => l10n.ipdNextFinalizeDischarge,
    _ => l10n.ipdNextContinueCare,
  };
}

String _bedStatusLabel(BuildContext context, String? status) {
  final AppLocalizations l10n = context.l10n;
  return switch ((status ?? '').toUpperCase()) {
    'AVAILABLE' => l10n.ipdBedStatusAvailable,
    'OCCUPIED' => l10n.ipdBedStatusOccupied,
    'RESERVED' => l10n.ipdBedStatusReserved,
    'OUT_OF_SERVICE' => l10n.ipdBedStatusOutOfService,
    _ => context.l10n.profileUnknownValue,
  };
}

String _dischargeStatusLabel(BuildContext context, String? status) {
  final AppLocalizations l10n = context.l10n;
  return switch ((status ?? '').toUpperCase()) {
    'PLANNED' => l10n.ipdDischargeStatusPlanned,
    'COMPLETED' => l10n.ipdDischargeStatusCompleted,
    _ => context.l10n.profileUnknownValue,
  };
}

String _clearancePhaseLabel(BuildContext context, String? phase) {
  final AppLocalizations l10n = context.l10n;
  return switch ((phase ?? '').toUpperCase()) {
    'SUMMARY_PENDING' => l10n.ipdClearancePhaseSummaryPending,
    'PENDING_ORDERS_REVIEW' => l10n.ipdClearancePhasePendingOrders,
    'MEDICATION_PENDING' => l10n.ipdClearancePhaseMedication,
    'BILLING_PENDING' => l10n.ipdClearancePhaseBilling,
    'NURSING_CLEARANCE_PENDING' => l10n.ipdClearancePhaseNursing,
    'DOCUMENTS_PENDING' => l10n.ipdClearancePhaseDocuments,
    'PATIENT_EXIT_PENDING' => l10n.ipdClearancePhasePatientExit,
    'READY_FOR_EXIT' => l10n.ipdClearancePhaseReadyForExit,
    'COMPLETED' => l10n.ipdDischargeStatusCompleted,
    _ => context.l10n.profileUnknownValue,
  };
}

String _sourceKindLabel(BuildContext context, String? kind) {
  final AppLocalizations l10n = context.l10n;
  return switch ((kind ?? '').toUpperCase()) {
    'OPD' => l10n.ipdSourceKindOpd,
    'EMERGENCY' => l10n.ipdSourceKindEmergency,
    'REFERRAL' => l10n.ipdSourceKindReferral,
    'DIRECT' => l10n.ipdSourceKindDirect,
    _ => context.l10n.profileUnknownValue,
  };
}

String _icuStatusLabel(BuildContext context, String? status) {
  final AppLocalizations l10n = context.l10n;
  return switch ((status ?? '').toUpperCase()) {
    'ACTIVE' => l10n.ipdIcuStatusActive,
    'ENDED' => l10n.ipdIcuStatusEnded,
    'NONE' => l10n.ipdIcuStatusNone,
    _ => l10n.ipdIcuStatusNone,
  };
}

String _statusLikeLabel(BuildContext context, String? status) {
  if (status == null || status.trim().isEmpty) {
    return context.l10n.profileUnknownValue;
  }
  return _apiLabel(status);
}

String _timelineTypeLabel(BuildContext context, String type) {
  final AppLocalizations l10n = context.l10n;
  return switch (type.toUpperCase()) {
    'WARD_ROUND' => l10n.ipdTimelineWardRound,
    'NURSING_NOTE' => l10n.ipdTimelineNursingNote,
    'MEDICATION_ADMINISTRATION' => l10n.ipdTimelineMedication,
    'MEDICATION_REMINDER' => l10n.ipdTimelineMedicationReminder,
    'TRANSFER' => l10n.ipdTimelineTransfer,
    'ICU_OBSERVATION' => l10n.ipdTimelineIcuObservation,
    'CRITICAL_ALERT' => l10n.ipdTimelineCriticalAlert,
    _ => l10n.ipdTimelineCareEvent,
  };
}

String _criticalAlertLabel(BuildContext context, IpdAdmissionSummary summary) {
  final String? severity = summary.criticalSeverity;
  if (severity == null || severity.trim().isEmpty) {
    return context.l10n.ipdCriticalAlertLabel;
  }
  return context.l10n.ipdCriticalSeverityLabel(_apiLabel(severity));
}

IconData _recordIcon(String kind) {
  return switch (kind) {
    _ipdTransferKind => Icons.swap_horiz,
    'ward_round' => Icons.fact_check_outlined,
    'nursing_note' => Icons.note_alt_outlined,
    'medication_administration' ||
    'medication_reminder' => Icons.medication_outlined,
    'critical_alert' => Icons.notification_important_outlined,
    'icu_observation' => Icons.monitor_heart_outlined,
    _ => Icons.circle_outlined,
  };
}

String _pageLabel<T>(BuildContext context, AppPage<T> page) {
  final int total = page.totalItemCount ?? page.lastItemNumber;
  return context.l10n.opdPageLabel(
    page.firstItemNumber,
    page.lastItemNumber,
    total,
  );
}

IpdMedicationSuggestion? _firstMedicationSuggestion(
  Iterable<IpdMedicationSuggestion> suggestions,
  String? id,
) {
  for (final IpdMedicationSuggestion suggestion in suggestions) {
    if (suggestion.id == id) {
      return suggestion;
    }
  }
  return null;
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _lengthOfStayLabel(BuildContext context, IpdAdmissionSummary item) {
  final DateTime? admittedAt = item.admittedAt;
  if (admittedAt == null) {
    return context.l10n.profileUnknownValue;
  }
  final DateTime end = item.dischargedAt ?? DateTime.now();
  final Duration stay = end.difference(admittedAt);
  if (stay.isNegative) {
    return context.l10n.profileUnknownValue;
  }
  if (stay.inHours < 24) {
    return context.l10n.ipdLengthOfStayHours(stay.inHours);
  }
  return context.l10n.ipdLengthOfStayDays(stay.inDays);
}

ClinicalActionReferenceData _ipdAdmissionReferenceData(
  BuildContext context,
  IpdReferenceData referenceData,
) {
  final AppLocalizations l10n = context.l10n;
  final Map<String, ClinicalActionCatalogOption> wards =
      <String, ClinicalActionCatalogOption>{
        for (final IpdWardOption ward in referenceData.wards)
          ward.id: ClinicalActionCatalogOption(
            id: ward.id,
            name: ward.displayTitle,
            category: ward.wardType,
            status: ward.isActive ? 'ACTIVE' : 'INACTIVE',
          ),
      };
  final Map<String, ClinicalActionCatalogOption> rooms =
      <String, ClinicalActionCatalogOption>{};
  final List<ClinicalActionCatalogOption> beds =
      <ClinicalActionCatalogOption>[];

  for (final IpdBedOption bed in referenceData.availableBeds) {
    final String wardId = _ipdBedWardId(bed);
    final String roomId = _ipdBedRoomId(bed, wardId);
    wards.putIfAbsent(
      wardId,
      () => ClinicalActionCatalogOption(
        id: wardId,
        name: _firstDisplayValue(<String?>[
          bed.wardName,
          bed.wardId,
          l10n.profileUnknownValue,
        ]),
      ),
    );
    rooms.putIfAbsent(
      roomId,
      () => ClinicalActionCatalogOption(
        id: roomId,
        name: _firstDisplayValue(<String?>[
          bed.roomName,
          bed.roomId,
          l10n.profileUnknownValue,
        ]),
        secondaryText: bed.roomFloor,
        parentId: wardId,
      ),
    );
    beds.add(
      ClinicalActionCatalogOption(
        id: bed.id,
        name: bed.displayTitle,
        status: bed.status,
        parentId: wardId,
        secondaryId: roomId,
        secondaryText: bed.displaySubtitle,
      ),
    );
  }

  return ClinicalActionReferenceData(
    wards: wards.values.toList(growable: false),
    rooms: rooms.values.toList(growable: false),
    availableBeds: beds,
  );
}

String _ipdBedWardId(IpdBedOption bed) {
  return _trimmedValue(bed.wardId) ?? _ipdUnknownWardId;
}

String _ipdBedRoomId(IpdBedOption bed, String wardId) {
  return _trimmedValue(bed.roomId) ??
      '$_ipdUnknownRoomIdPrefix$wardId:${_trimmedValue(bed.roomName) ?? 'room'}';
}

String _firstDisplayValue(Iterable<String?> values) {
  for (final String? value in values) {
    final String? normalized = _trimmedValue(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return '';
}

String? _trimmedValue(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
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

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.ipdSavedMessage)));
}

const String _stageAdmissionRequested = 'ADMISSION_REQUESTED';
const String _stageAdmittedPendingBed = 'ADMITTED_PENDING_BED';
const String _stageAdmittedInBed = 'ADMITTED_IN_BED';
const String _stageInProcedureOt = 'IN_PROCEDURE_OT';
const String _stageTransferRequested = 'TRANSFER_REQUESTED';
const String _stageTransferInProgress = 'TRANSFER_IN_PROGRESS';
const String _stageDischargePlanned = 'DISCHARGE_PLANNED';
const String _stageDischarged = 'DISCHARGED';
const String _stageCancelled = 'CANCELLED';
const String _ipdUnknownWardId = '__ipd_unknown_ward__';
const String _ipdUnknownRoomIdPrefix = '__ipd_unknown_room__:';
const String _transferApprove = 'APPROVE';
const String _transferStart = 'START';
const String _transferComplete = 'COMPLETE';
const String _transferCancel = 'CANCEL';
const String _transferApproved = 'APPROVED';
const String _transferInProgress = 'IN_PROGRESS';
const String _ipdTransferKind = 'transfer';
const String _medRouteOral = 'ORAL';
const String _medRouteIv = 'IV';
const String _medRouteIm = 'IM';
const String _medRouteTopical = 'TOPICAL';
const String _medRouteInhalation = 'INHALATION';
const String _medRouteOther = 'OTHER';
const String _medFrequencyOnce = 'ONCE';
const String _medFrequencyBid = 'BID';
const String _medFrequencyTid = 'TID';
const String _medFrequencyQid = 'QID';
const String _medFrequencyPrn = 'PRN';
const String _medFrequencyStat = 'STAT';
const String _medFrequencyCustom = 'CUSTOM';
const String _medStatusGiven = 'GIVEN';
const String _medStatusMissed = 'MISSED';
const String _medStatusDelayed = 'DELAYED';
const String _medStatusRefused = 'REFUSED';

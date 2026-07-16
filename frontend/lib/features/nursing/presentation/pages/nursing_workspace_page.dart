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
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_handover_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_medication_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_note_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_scope_navigation.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_shift_context_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_transfer_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_vitals_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_filters.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class NursingWorkspacePage extends ConsumerWidget {
  const NursingWorkspacePage({this.initialQuery, super.key});

  final NursingWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<NursingWorkspaceState>> state = ref.watch(
      nursingWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<NursingWorkspaceState>(
      value: state,
      loadingTitle: l10n.nursingLoadingTitle,
      loadingBody: l10n.nursingLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(nursingWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, NursingWorkspaceState data) {
        return _NursingWorkspaceContent(
          state: data,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _NursingWorkspaceContent extends ConsumerStatefulWidget {
  const _NursingWorkspaceContent({required this.state, this.initialQuery});

  final NursingWorkspaceState state;
  final NursingWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_NursingWorkspaceContent> createState() =>
      _NursingWorkspaceContentState();
}

class _NursingWorkspaceContentState
    extends ConsumerState<_NursingWorkspaceContent> {
  static const AccessRequirement writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.patientWrite,
      AppPermissions.lastOfficeWrite,
    ],
    anyRoles: <AppRole>[
      AppRole.nurse,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.facilityAdmin,
      AppRole.tenantAdmin,
      AppRole.superAdmin,
    ],
    activeModules: <String>['inpatient-bed-management'],
  );

  late final TextEditingController _searchController;
  late AppSearchBarFilterValue _filterValue;
  NursingQueueScope _scope = NursingQueueScope.all;
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialQuery?.search.isNotEmpty == true
          ? widget.initialQuery!.search
          : widget.state.query.search,
    );
    _filterValue = nursingFilterValueFromQuery(widget.state.query);
    _scope =
        nursingScopeFromQueryValue(widget.initialQuery?.scope) ??
        widget.state.query.scope;
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _NursingWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (oldWidget.state.query != widget.state.query) {
      _filterValue = nursingFilterValueFromQuery(widget.state.query);
    }
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleRouteQuery(NursingWorkspaceQuery? query) {
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

  Future<void> _applyDeepLink(NursingWorkspaceQuery query) async {
    if (_appliedRouteSignature == query.signature) {
      return;
    }
    _appliedRouteSignature = query.signature;

    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );
    final NursingQueueScope? scope = nursingScopeFromQueryValue(query.scope);
    if (scope != null) {
      // Local tab state may already match (set in initState); still sync the
      // controller so the worklist reflects the deep-linked scope.
      if (scope != _scope) {
        setState(() => _scope = scope);
      }
      if (scope != widget.state.query.scope) {
        await controller.applyScope(scope);
        if (!mounted) {
          return;
        }
      }
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
    }

    final String id = query.admissionId.trim();
    if (id.isEmpty) {
      return;
    }
    final NursingPatientSummary? summary = await controller
        .selectPatientByDisplayId(id);
    if (!mounted || summary == null) {
      return;
    }
    unawaited(
      showAppDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) =>
            const NursingPatientDetailDialog(),
      ),
    );
    final NursingDetailPanel? panel = NursingDetailPanel.fromValue(query.panel);
    if (panel == null || panel == NursingDetailPanel.checklist) {
      return;
    }
    final NursingPatientDetail? detail = nursingSelectedDetailFromState(
      ref.read(nursingWorkspaceControllerProvider),
    );
    if (detail == null || !mounted) {
      return;
    }
    switch (panel) {
      case NursingDetailPanel.vitals:
        await _openVitalsDialog();
      case NursingDetailPanel.medication:
        await _openMedicationDialog(detail);
      case NursingDetailPanel.handover:
        await _openHandoverDialog();
      case NursingDetailPanel.discharge:
        await _openDischargeClearanceDialog(detail);
      case NursingDetailPanel.checklist:
        break;
    }
  }

  void _updateUrlForScope(NursingQueueScope scope) {
    if (!mounted) {
      return;
    }
    final String tab = nursingScopeToQueryValue(scope);
    final String location = AppRoutes.nursing.location(
      queryParameters: <String, String>{
        if (tab.isNotEmpty && tab != 'all') 'scope': tab,
      },
    );
    GoRouter.of(context).replace<void>(location);
  }

  void _onTabTapped(String tabId) {
    final NursingQueueScope? scope = nursingScopeFromQueryValue(tabId);
    if (scope == null || scope == _scope) {
      return;
    }
    setState(() => _scope = scope);
    _updateUrlForScope(scope);
    ref.read(nursingWorkspaceControllerProvider.notifier).applyScope(scope);
  }

  void _executePrimaryAction() {
    switch (_scope) {
      case NursingQueueScope.medicationDue:
        final NursingPatientDetail? detail = nursingSelectedDetailFromState(
          ref.read(nursingWorkspaceControllerProvider),
        );
        if (detail != null) {
          _openMedicationDialog(detail);
        }
      case NursingQueueScope.handoverPending:
        _openHandoverDialog();
      case NursingQueueScope.transferPending:
        final NursingPatientDetail? detail = nursingSelectedDetailFromState(
          ref.read(nursingWorkspaceControllerProvider),
        );
        if (detail != null) {
          nursingShowActionResult(
            context,
            showAppDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => NursingTransferDialog(detail: detail),
            ),
          );
        }
      case NursingQueueScope.dischargePending:
        final NursingPatientDetail? detail = nursingSelectedDetailFromState(
          ref.read(nursingWorkspaceControllerProvider),
        );
        if (detail != null) {
          _openDischargeClearanceDialog(detail);
        }
      case NursingQueueScope.all:
      case NursingQueueScope.assignedWard:
      case NursingQueueScope.urgent:
        _openVitalsDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final NursingWorkspaceState state = widget.state;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );
    final bool isRefreshing = state.isRefreshing || state.isRefreshingDetail;

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: nursingTabItems(l10n, state),
              selectedId: nursingScopeToQueryValue(_scope),
              onTabTapped: _onTabTapped,
              primaryAction: AppAccessActionGate(
                requirement: writeRequirement,
                builder: (BuildContext context, bool isAllowed) {
                  return AppTabToolbarPrimary(
                    label: nursingPrimaryActionLabel(l10n, _scope),
                    icon: nursingPrimaryActionIcon(_scope),
                    enabled: isAllowed && !state.isSaving,
                    onPressed: isAllowed ? _executePrimaryAction : null,
                  );
                },
              ),
              secondaryActions: <Widget>[
                AppTabToolbarAction(
                  label: l10n.nursingShiftContextTitle,
                  icon: Icons.assignment_ind_outlined,
                  tooltip: l10n.nursingShiftContextTitle,
                  semanticLabel: l10n.nursingShiftContextTitle,
                  onPressed: _openShiftContextDialog,
                ),
                AppAccessActionGate(
                  requirement: writeRequirement,
                  builder: (BuildContext context, bool isAllowed) {
                    return AppTabToolbarAction(
                      label: l10n.nursingActionAddNote,
                      icon: Icons.note_add_outlined,
                      tooltip: l10n.nursingActionAddNote,
                      semanticLabel: l10n.nursingActionAddNote,
                      enabled: isAllowed && !state.isSaving,
                      onPressed: isAllowed ? _openNoteDialog : null,
                    );
                  },
                ),
                AppTabToolbarAction(
                  label: l10n.commonRefreshActionLabel,
                  icon: Icons.refresh,
                  tooltip: l10n.commonRefreshActionLabel,
                  semanticLabel: l10n.commonRefreshActionLabel,
                  enabled: !isRefreshing,
                  isLoading: isRefreshing,
                  onPressed: isRefreshing
                      ? null
                      : () async {
                          final AppFailure? failure = await controller
                              .refresh();
                          if (context.mounted) {
                            nursingShowFailureIfNeeded(context, failure);
                          }
                        },
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: NursingWorklistPanel(
                state: state,
                scope: _scope,
                searchController: _searchController,
                filterValue: _filterValue,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() {
                    _filterValue = value;
                  });
                  controller
                      .applyAdvancedFilters(
                        searchField: value.field,
                        scope: nursingScopeFromFilterValue(
                          value.option('scope'),
                        ),
                        patient: value.text('patient'),
                        admission: value.text('admission'),
                        encounter: value.text('encounter'),
                        ward: value.text('ward'),
                        room: value.text('room'),
                        bed: value.text('bed'),
                        observation: value.text('observation'),
                        taskType: value.text('task_type'),
                        status: value.option('status'),
                        priority: value.option('priority'),
                        assignedNurse: value.text('assigned_nurse'),
                        shift: value.text('shift'),
                        transferStatus: value.option('transfer_status'),
                        handoverStatus: value.option('handover_status'),
                        dischargeStatus: value.option('discharge_status'),
                        dateFrom: value.dateFrom,
                        dateTo: value.dateTo,
                      )
                      .then((AppFailure? failure) {
                        if (context.mounted) {
                          nursingShowFailureIfNeeded(context, failure);
                        }
                      });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openShiftContextDialog() {
    showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) =>
          const NursingShiftContextDialog(),
    );
  }

  Future<void> _openVitalsDialog() async {
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const NursingVitalsDialog(),
      ),
    );
  }

  Future<void> _openNoteDialog() async {
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const NursingNoteDialog(),
      ),
    );
  }

  Future<void> _openMedicationDialog(NursingPatientDetail detail) async {
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => NursingMedicationDialog(detail: detail),
      ),
    );
  }

  Future<void> _openHandoverDialog() async {
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const NursingHandoverDialog(),
      ),
    );
  }

  Future<void> _openDischargeClearanceDialog(
    NursingPatientDetail detail,
  ) async {
    await nursingShowActionResult(
      context,
      showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => NursingDischargeClearanceDialog(detail: detail),
      ),
    );
  }
}

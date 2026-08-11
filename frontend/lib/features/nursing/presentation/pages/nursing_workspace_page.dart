import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_scope_navigation.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_actions.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_filters.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/routing/workspace_location_sync.dart';

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
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<NursingWorkItem>
  _columnVisibilityController;
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
    _columnVisibilityController =
        AppListTableColumnVisibilityController<NursingWorkItem>();
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
    _columnVisibilityController.dispose();
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

    final NursingDetailPanel? panel = NursingDetailPanel.fromValue(query.panel);
    // Panel-focused deep links open the mutation dialog directly (no empty
    // detail shell). Bare admission links open detail with the stage
    // next-action omitted so it is not duplicated inside Quick Actions.
    // Unauthorized write panels fall back to detail (restricted deep link).
    if (panel != null && panel != NursingDetailPanel.checklist) {
      final AccessRequirement? panelRequirement =
          nursingFocusedPanelRequirement(panel);
      final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
      if (panelRequirement != null && panelRequirement.isAllowed(policy)) {
        await openNursingFocusedAction(context, ref, summary, panel);
        return;
      }
    }

    await openNursingPatientDetailDialog(
      context,
      ref,
      summary,
      omitNextActionKind: nursingResolveNextActionKind(summary, _scope),
    );
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
    syncWorkspaceLocation(context, location);
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final NursingWorkspaceState state = widget.state;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final List<NursingQueueScope> visibleScopes = nursingAllowedScopes(policy);
    if (visibleScopes.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!visibleScopes.contains(_scope)) {
      final NursingQueueScope fallback =
          nursingFallbackScope(policy) ?? visibleScopes.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleScopes.contains(_scope)) {
          return;
        }
        setState(() => _scope = fallback);
        _updateUrlForScope(fallback);
        controller.applyScope(fallback);
      });
    }
    return ResponsivePage(
      padding: ResponsiveSpacing.workspacePagePaddingFor(
        spacing: Theme.of(context).spacing,
      ),
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: nursingTabItems(l10n, state, policy: policy),
              selectedId: nursingScopeToQueryValue(_scope),
              onTabTapped: _onTabTapped,
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: NursingWorklistPanel(
                state: state,
                scope: _scope,
                searchController: _searchController,
                filterValue: _filterValue,
                columnVisibilityController: _columnVisibilityController,
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
                      .then((failure) {
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
}

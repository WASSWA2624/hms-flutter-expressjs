import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/controllers/subscriptions_realtime_delta_applier.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final subscriptionsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      SubscriptionsWorkspaceController,
      Result<SubscriptionsWorkspaceState>
    >(SubscriptionsWorkspaceController.new);

final class SubscriptionsWorkspaceController
    extends AsyncNotifier<Result<SubscriptionsWorkspaceState>> {
  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();

  SubscriptionsRepository get _repository {
    return ref.read(subscriptionsRepositoryProvider);
  }

  @override
  Future<Result<SubscriptionsWorkspaceState>> build() {
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.subscriptions,
      includeCrudMutations: true,
      shouldDefer: () => _currentState?.isSaving ?? false,
      onRefresh: _syncFromRealtime,
    );
    return runWorkspaceInitialLoad(ref, _loadInitialState);
  }

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    if (message.event == RealtimeEvents.moduleEntitlementUpdated) {
      await _refreshSession();
    }

    await handleWorkspaceListRealtimeSync<SubscriptionsWorkspaceState>(
      message: message,
      profile: WorkspaceRefreshProfile.subscriptions,
      currentState: _currentState,
      isDeferred: _currentState?.isSaving ?? false,
      pendingRefresh: _pendingRefresh,
      applyDelta: SubscriptionsRealtimeDeltaApplier.apply,
      emit: _emit,
      syncHttp: ({required WorkspaceRefreshPlan plan}) async {
        await _refreshWorkspace(
          preferredSelectedId: _currentState?.selectedItem?.id,
        );
      },
    );
  }

  Future<AppFailure?> applyRouteQuery(SubscriptionsWorkspaceQuery query) async {
    final SubscriptionsWorkspaceQuery resolved = await _resolveRouteQuery(
      query,
    );
    return _loadQuery(
      resolved.copyWith(pageRequest: resolved.pageRequest.first()),
      preserveSelectedId: resolved.recordId,
    );
  }

  Future<AppFailure?> refresh() async {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      state = const AsyncLoading<Result<SubscriptionsWorkspaceState>>();
      final Result<SubscriptionsWorkspaceState> result =
          await _loadInitialState();
      state = AsyncData<Result<SubscriptionsWorkspaceState>>(result);
      return _failureOrNull(result);
    }
    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    return _refreshWorkspace(preferredSelectedId: current.selectedItem?.id);
  }

  Future<AppFailure?> applySearch(String value) {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _loadQuery(
      current.query.copyWith(
        search: value.trim(),
        pageRequest: current.query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> applyPanel(SubscriptionPanel panel) {
    return applyResource(_defaultResourceForPanel(panel));
  }

  Future<AppFailure?> applyResource(SubscriptionResource resource) {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _loadQuery(
      current.query
          .copyWith(
            panel: resource.defaultPanel,
            resource: resource,
            pageRequest: current.query.pageRequest.first(),
          )
          .resetFilters()
          .copyWith(panel: resource.defaultPanel, resource: resource),
      clearSelectedItem: true,
    );
  }

  Future<AppFailure?> applyQueue(SubscriptionQueueSummary queue) {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _loadQuery(
      current.query.copyWith(
        panel: queue.panel,
        resource: queue.resource,
        queue: queue.queue,
        pageRequest: current.query.pageRequest.first(),
      ),
      clearSelectedItem: true,
    );
  }

  Future<AppFailure?> applyFilters({
    String? status,
    String? tierCode,
    String? billingCycle,
    String? planId,
    String? moduleId,
    String? fitStatus,
    String? invoiceStatus,
    String? licenseType,
    String? eligibilityState,
    SubscriptionDatePreset? datePreset,
  }) {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _loadQuery(
      current.query.copyWith(
        status: status,
        tierCode: tierCode,
        billingCycle: billingCycle,
        planId: planId,
        moduleId: moduleId,
        fitStatus: fitStatus,
        invoiceStatus: invoiceStatus,
        licenseType: licenseType,
        eligibilityState: eligibilityState,
        datePreset: datePreset,
        pageRequest: current.query.pageRequest.first(),
      ),
      clearSelectedItem: true,
    );
  }

  Future<AppFailure?> resetFilters() {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _loadQuery(current.query.resetFilters(), clearSelectedItem: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _loadQuery(current.query.copyWith(pageRequest: request));
  }

  void selectItem(SubscriptionItem item) {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        selectedItem: item,
        clearPlanDetail: true,
        clearLastFailure: true,
      ),
    );
  }

  Future<void> loadPlanDetail(String planId) async {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null || planId.trim().isEmpty) {
      return;
    }
    _emit(current.copyWith(isLoadingPlanDetail: true, clearLastFailure: true));
    final Result<SubscriptionPlanDetail> result = await _repository
        .getPlanDetail(planId);
    final SubscriptionsWorkspaceState? latest = _currentState;
    if (latest == null) {
      return;
    }
    result.when(
      success: (SubscriptionPlanDetail detail) {
        final bool sameSelection =
            latest.selectedItem?.id == detail.plan.id ||
            latest.selectedItem?.effectiveDisplayId ==
                detail.plan.effectiveDisplayId;
        _emit(
          latest.copyWith(
            planDetail: detail,
            isLoadingPlanDetail: false,
            selectedItem: sameSelection ? detail.plan : latest.selectedItem,
          ),
        );
      },
      failure: (AppFailure failure) {
        _emit(
          latest.copyWith(
            isLoadingPlanDetail: false,
            lastFailure: failure,
            clearPlanDetail: true,
          ),
        );
      },
    );
  }

  Future<AppFailure?> createPlan(SubscriptionPlanDraft draft) {
    return _submitAction(() => _repository.createPlan(draft));
  }

  Future<AppFailure?> updateSelectedPlan(SubscriptionPlanDraft draft) {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.subscriptionPlans,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.updatePlan(selected.id, draft)).then(
      (AppFailure? failure) async {
        if (failure == null) {
          await loadPlanDetail(selected.id);
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> createSubscription(SubscriptionDraft draft) {
    return _submitAction(
      () => _repository.createSubscription(draft),
      refreshSession: true,
    );
  }

  Future<AppFailure?> updateSubscription(
    String subscriptionId,
    SubscriptionDraft draft,
  ) {
    return _submitAction(
      () => _repository.updateSubscription(subscriptionId, draft),
      refreshSession: true,
    );
  }

  Future<AppFailure?> updateSelectedSubscription(SubscriptionDraft draft) {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.subscriptions,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return updateSubscription(selected.id, draft);
  }

  Future<AppFailure?> activateSelectedSubscription() {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.subscriptions,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () => _repository.activateSubscription(selected.id),
      refreshSession: true,
    );
  }

  Future<AppFailure?> cancelSelectedSubscription() {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.subscriptions,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () => _repository.cancelSubscription(selected.id),
      refreshSession: true,
    );
  }

  Future<AppFailure?> renewSelectedSubscription(
    SubscriptionRenewalDraft draft,
  ) {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.subscriptions,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () => _repository.renewSubscription(selected.id, draft),
      refreshSession: true,
    );
  }

  Future<AppFailure?> changeSelectedSubscriptionPlan(
    SubscriptionPlanChangeDraft draft,
  ) {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.subscriptions,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () => _repository.changeSubscriptionPlan(selected.id, draft),
      refreshSession: true,
    );
  }

  Future<AppFailure?> createModuleSubscription(ModuleSubscriptionDraft draft) {
    return _submitAction(
      () => _repository.createModuleSubscription(draft),
      refreshSession: true,
    );
  }

  Future<AppFailure?> toggleSelectedModule({String? reason}) {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.moduleSubscriptions,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () => _repository.setModuleSubscriptionActive(
        selected.id,
        isActive: selected.isActive != true,
        reason: reason,
      ),
      refreshSession: true,
    );
  }

  Future<AppFailure?> createLicense(LicenseDraft draft) {
    return _submitAction(
      () => _repository.createLicense(draft),
      refreshSession: true,
    );
  }

  Future<AppFailure?> updateSelectedLicense(LicenseDraft draft) {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.licenses,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () => _repository.updateLicense(selected.id, draft),
      refreshSession: true,
    );
  }

  Future<AppFailure?> collectSelectedInvoice(SubscriptionActionDraft draft) {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.subscriptionInvoices,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.collectInvoice(selected.id, draft));
  }

  Future<AppFailure?> retrySelectedInvoice(SubscriptionActionDraft draft) {
    final SubscriptionItem? selected = _requireSelected(
      SubscriptionResource.subscriptionInvoices,
    );
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.retryInvoice(selected.id, draft));
  }

  Future<Result<SubscriptionsWorkspaceState>> _loadInitialState() async {
    const SubscriptionsWorkspaceQuery query = SubscriptionsWorkspaceQuery();
    final Result<SubscriptionsWorkspaceData> dataResult = await _repository
        .getWorkspace(query);
    if (dataResult case ResultFailure<SubscriptionsWorkspaceData>(
      failure: final AppFailure failure,
    )) {
      return Result<SubscriptionsWorkspaceState>.failure(failure);
    }
    final SubscriptionsWorkspaceData data =
        (dataResult as ResultSuccess<SubscriptionsWorkspaceData>).value;
    final SubscriptionsWorkspaceData enriched = await _enrichWorkspaceData(
      data,
    );
    return Result<SubscriptionsWorkspaceState>.success(
      SubscriptionsWorkspaceState(
        data: enriched,
        selectedItem:
            enriched.overview.currentSubscription ??
            enriched.items.items.firstOrNull,
      ),
    );
  }

  Future<AppFailure?> _loadQuery(
    SubscriptionsWorkspaceQuery query, {
    bool clearSelectedItem = false,
    String? preserveSelectedId,
  }) async {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        isRefreshing: true,
        clearLastFailure: true,
        clearSelectedItem: clearSelectedItem,
      ),
    );
    final Result<SubscriptionsWorkspaceData> result = await _repository
        .getWorkspace(query);
    if (result case ResultFailure<SubscriptionsWorkspaceData>(
      failure: final AppFailure failure,
    )) {
      _emit(
        _currentState!.copyWith(
          isRefreshing: false,
          isSaving: false,
          lastFailure: failure,
        ),
      );
      return failure;
    }
    final SubscriptionsWorkspaceData data =
        (result as ResultSuccess<SubscriptionsWorkspaceData>).value;
    final SubscriptionsWorkspaceData enriched = await _enrichWorkspaceData(
      data,
    );
    _emit(
      _currentState!.copyWith(
        data: enriched,
        selectedItem: clearSelectedItem
            ? null
            : _selectAfterRefresh(
                enriched.items.items,
                preserveSelectedId ?? _currentState?.selectedItem?.id,
                recordId: query.recordId,
              ),
        isRefreshing: false,
        isSaving: false,
        clearLastFailure: true,
      ),
    );
    return null;
  }

  Future<AppFailure?> _submitAction(
    Future<Result<void>> Function() submit, {
    bool refreshSession = false,
  }) async {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      return _missingSelectionFailure();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await submit();
    return result.when<Future<AppFailure?>>(
      success: (_) async {
        if (refreshSession) {
          await _refreshSession();
        }
        final AppFailure? failure = await _refreshWorkspace(
          preferredSelectedId: current.selectedItem?.id,
        );
        await _flushPendingRefresh();
        return failure;
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<void> _flushPendingRefresh() async {
    if (!_pendingRefresh.refreshPending) {
      return;
    }
    final WorkspaceRefreshPlan plan = _pendingRefresh.takePending();
    if (plan.isEmpty) {
      return;
    }
    await _refreshWorkspace(
      preferredSelectedId: _currentState?.selectedItem?.id,
    );
  }

  Future<AppFailure?> _refreshWorkspace({String? preferredSelectedId}) async {
    final SubscriptionsWorkspaceState current = _currentState!;
    final Result<SubscriptionsWorkspaceData> result = await _repository
        .getWorkspace(current.query);
    if (result case ResultFailure<SubscriptionsWorkspaceData>(
      failure: final AppFailure failure,
    )) {
      _emit(
        _currentState!.copyWith(
          isRefreshing: false,
          isSaving: false,
          lastFailure: failure,
        ),
      );
      return failure;
    }
    final SubscriptionsWorkspaceData data =
        (result as ResultSuccess<SubscriptionsWorkspaceData>).value;
    final SubscriptionsWorkspaceData enriched = await _enrichWorkspaceData(
      data,
    );
    _emit(
      _currentState!.copyWith(
        data: enriched,
        selectedItem: _selectAfterRefresh(
          enriched.items.items,
          preferredSelectedId,
          recordId: current.query.recordId,
        ),
        isRefreshing: false,
        isSaving: false,
        clearLastFailure: true,
      ),
    );
    return null;
  }

  Future<void> _refreshSession() async {
    final session = ref.read(sessionStateProvider).session;
    if (session == null || !session.tokens.hasRefreshToken) {
      return;
    }
    final result = await ref
        .read(authRepositoryProvider)
        .refreshSession(session.tokens);
    await result.when<Future<void>>(
      success: (session) {
        return ref.read(sessionStateProvider.notifier).persistSession(session);
      },
      failure: (_) async {},
    );
  }

  SubscriptionItem? _selectAfterRefresh(
    List<SubscriptionItem> items,
    String? preferredSelectedId, {
    String? recordId,
  }) {
    final String? targetId = recordId ?? preferredSelectedId;
    if (targetId != null) {
      for (final SubscriptionItem item in items) {
        if (item.id == targetId || item.effectiveDisplayId == targetId) {
          return item;
        }
      }
    }
    if (preferredSelectedId != null) {
      for (final SubscriptionItem item in items) {
        if (item.id == preferredSelectedId) {
          return item;
        }
      }
    }
    return items.firstOrNull;
  }

  Future<SubscriptionsWorkspaceQuery> _resolveRouteQuery(
    SubscriptionsWorkspaceQuery query,
  ) async {
    final String? recordId = query.recordId;
    if (recordId == null || recordId.isEmpty) {
      return query;
    }

    final Result<SubscriptionLegacyRouteResolution> result = await _repository
        .resolveLegacyRoute(query.resource, recordId);
    return result.when(
      success: (SubscriptionLegacyRouteResolution resolution) {
        return query.copyWith(
          panel: resolution.panel,
          resource: resolution.resource,
          recordId: resolution.id ?? recordId,
          action: resolution.action ?? query.action,
          tenantId: resolution.tenantId ?? query.tenantId,
        );
      },
      failure: (_) => query,
    );
  }

  Future<SubscriptionsWorkspaceData> _enrichWorkspaceData(
    SubscriptionsWorkspaceData data,
  ) async {
    final SubscriptionLookups lookups = data.lookups;
    if (_lookupsAreComplete(lookups)) {
      return data;
    }

    final Result<SubscriptionLookups> referenceResult = await _repository
        .getReferenceData(tenantId: data.query.tenantId);
    return referenceResult.when(
      success: (SubscriptionLookups reference) {
        return SubscriptionsWorkspaceData(
          query: data.query,
          summary: data.summary,
          queueSummaries: data.queueSummaries,
          panelSummaries: data.panelSummaries,
          lookups: _mergeLookups(lookups, reference),
          items: data.items,
          overview: data.overview,
          timeline: data.timeline,
        );
      },
      failure: (_) => data,
    );
  }

  bool _lookupsAreComplete(SubscriptionLookups lookups) {
    return lookups.tenants.isNotEmpty &&
        lookups.plans.isNotEmpty &&
        lookups.modules.isNotEmpty;
  }

  SubscriptionLookups _mergeLookups(
    SubscriptionLookups primary,
    SubscriptionLookups fallback,
  ) {
    return SubscriptionLookups(
      tenants: primary.tenants.isNotEmpty ? primary.tenants : fallback.tenants,
      plans: primary.plans.isNotEmpty ? primary.plans : fallback.plans,
      modules: primary.modules.isNotEmpty ? primary.modules : fallback.modules,
      statuses: primary.statuses.isNotEmpty
          ? primary.statuses
          : fallback.statuses,
      changeStatuses: primary.changeStatuses.isNotEmpty
          ? primary.changeStatuses
          : fallback.changeStatuses,
      fitStatuses: primary.fitStatuses.isNotEmpty
          ? primary.fitStatuses
          : fallback.fitStatuses,
      billingCycles: primary.billingCycles.isNotEmpty
          ? primary.billingCycles
          : fallback.billingCycles,
      tiers: primary.tiers.isNotEmpty ? primary.tiers : fallback.tiers,
      licenseTypes: primary.licenseTypes.isNotEmpty
          ? primary.licenseTypes
          : fallback.licenseTypes,
      invoiceStatuses: primary.invoiceStatuses.isNotEmpty
          ? primary.invoiceStatuses
          : fallback.invoiceStatuses,
      eligibilityStates: primary.eligibilityStates.isNotEmpty
          ? primary.eligibilityStates
          : fallback.eligibilityStates,
    );
  }

  SubscriptionItem? _requireSelected(SubscriptionResource resource) {
    final SubscriptionItem? selected = _currentState?.selectedItem;
    if (selected == null || selected.resource != resource) {
      return null;
    }
    return selected;
  }

  SubscriptionsWorkspaceState? get _currentState {
    final Result<SubscriptionsWorkspaceState>? currentResult =
        state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<SubscriptionsWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(SubscriptionsWorkspaceState nextState) {
    state = AsyncData<Result<SubscriptionsWorkspaceState>>(
      Result<SubscriptionsWorkspaceState>.success(nextState),
    );
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  AppFailure _missingSelectionFailure() {
    return AppFailure.validation(validationFields: <String>{'subscription_id'});
  }
}

SubscriptionResource _defaultResourceForPanel(SubscriptionPanel panel) {
  return switch (panel) {
    SubscriptionPanel.overview => SubscriptionResource.subscriptions,
    SubscriptionPanel.catalog => SubscriptionResource.subscriptionPlans,
    SubscriptionPanel.operations => SubscriptionResource.subscriptions,
    SubscriptionPanel.billing => SubscriptionResource.subscriptionInvoices,
    SubscriptionPanel.governance => SubscriptionResource.licenses,
  };
}

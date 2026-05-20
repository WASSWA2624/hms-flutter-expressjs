import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final subscriptionsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      SubscriptionsWorkspaceController,
      Result<SubscriptionsWorkspaceState>
    >(SubscriptionsWorkspaceController.new);

final class SubscriptionsWorkspaceController
    extends AsyncNotifier<Result<SubscriptionsWorkspaceState>> {
  SubscriptionsRepository get _repository {
    return ref.read(subscriptionsRepositoryProvider);
  }

  @override
  Future<Result<SubscriptionsWorkspaceState>> build() async {
    const SubscriptionsWorkspaceQuery query = SubscriptionsWorkspaceQuery();
    final Result<SubscriptionsWorkspaceData> dataResult = await _repository
        .getWorkspace(query);
    return dataResult.map(
      (SubscriptionsWorkspaceData data) => SubscriptionsWorkspaceState(
        data: data,
        selectedItem: data.overview.currentSubscription ?? data.items.items.firstOrNull,
      ),
    );
  }

  Future<AppFailure?> refresh() async {
    final SubscriptionsWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
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
    _emit(current.copyWith(selectedItem: item, clearLastFailure: true));
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
    return _submitAction(() => _repository.updatePlan(selected.id, draft));
  }

  Future<AppFailure?> createSubscription(SubscriptionDraft draft) {
    return _submitAction(
      () => _repository.createSubscription(draft),
      refreshSession: true,
    );
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

  Future<AppFailure?> createModuleSubscription(
    ModuleSubscriptionDraft draft,
  ) {
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

  Future<AppFailure?> _loadQuery(
    SubscriptionsWorkspaceQuery query, {
    bool clearSelectedItem = false,
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
    return result.when(
      success: (SubscriptionsWorkspaceData data) {
        _emit(
          _currentState!.copyWith(
            data: data,
            selectedItem: _selectAfterRefresh(data.items.items, null),
            isRefreshing: false,
            isSaving: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshing: false,
            isSaving: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
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
        return _refreshWorkspace(preferredSelectedId: current.selectedItem?.id);
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshWorkspace({String? preferredSelectedId}) async {
    final SubscriptionsWorkspaceState current = _currentState!;
    final Result<SubscriptionsWorkspaceData> result = await _repository
        .getWorkspace(current.query);
    return result.when(
      success: (SubscriptionsWorkspaceData data) {
        _emit(
          _currentState!.copyWith(
            data: data,
            selectedItem: _selectAfterRefresh(
              data.items.items,
              preferredSelectedId,
            ),
            isRefreshing: false,
            isSaving: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshing: false,
            isSaving: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
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
    String? preferredSelectedId,
  ) {
    if (preferredSelectedId != null) {
      for (final SubscriptionItem item in items) {
        if (item.id == preferredSelectedId) {
          return item;
        }
      }
    }
    return items.firstOrNull;
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

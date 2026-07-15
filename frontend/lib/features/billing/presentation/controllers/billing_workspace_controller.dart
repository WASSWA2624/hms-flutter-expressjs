import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final billingWorkspaceControllerProvider =
    AsyncNotifierProvider<
      BillingWorkspaceController,
      Result<BillingWorkspaceState>
    >(BillingWorkspaceController.new);

final class BillingWorkspaceController
    extends AsyncNotifier<Result<BillingWorkspaceState>> {
  BillingRepository get _repository => ref.read(billingRepositoryProvider);

  bool _isSyncing = false;
  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();

  @override
  Future<Result<BillingWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.billingWorkspace,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isSaving ?? false),
      onRefresh: _syncFromRealtime,
    );
    return runWorkspaceInitialLoad(ref, () async {
      const BillingWorkspaceQuery query = BillingWorkspaceQuery();
      final Result<BillingWorkspaceOverview> overviewResult = await _repository
          .getWorkspace(query);

      return overviewResult.when(
        success: (BillingWorkspaceOverview overview) async {
          final Result<AppPage<BillingWorkItem>> itemsResult = await _repository
              .listWorkItems(query);
          return itemsResult.when(
            success: (AppPage<BillingWorkItem> workItems) {
              return Result<BillingWorkspaceState>.success(
                BillingWorkspaceState(
                  query: query,
                  overview: overview,
                  workItems: workItems,
                  selectedItem: workItems.items.firstOrNull,
                ),
              );
            },
            failure: (AppFailure failure) {
              return Result<BillingWorkspaceState>.failure(failure);
            },
          );
        },
        failure: (AppFailure failure) async {
          return Result<BillingWorkspaceState>.failure(failure);
        },
      );
    });
  }

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    await handleWorkspaceListRealtimeSync<BillingWorkspaceState>(
      message: message,
      profile: WorkspaceRefreshProfile.fullOnMatch,
      currentState: _currentState,
      isDeferred: _isSyncing || (_currentState?.isSaving ?? false),
      pendingRefresh: _pendingRefresh,
      emit: _emit,
      syncHttp: ({required WorkspaceRefreshPlan plan}) => refresh(),
    );
  }

  Future<AppFailure?> refresh() async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }
    if (_isSyncing || current.isSaving) {
      _pendingRefresh.refreshPending = true;
      return null;
    }
    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    return _refreshWorkspace(preferredSelectedId: current.selectedItem?.id);
  }

  Future<AppFailure?> applySearch(String value) async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: value.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace();
  }

  Future<AppFailure?> applyQueue(BillingQueueType queue) async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          queue: queue,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace();
  }

  Future<AppFailure?> applyFilters(BillingWorkspaceQuery filters) async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          queue: filters.queue,
          patientId: filters.patientId,
          invoiceNumber: filters.invoiceNumber,
          encounterId: filters.encounterId,
          sourceModule: filters.sourceModule,
          billingStatus: filters.billingStatus,
          from: filters.from,
          to: filters.to,
          clearFrom: filters.from == null,
          clearTo: filters.to == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace();
  }

  Future<AppFailure?> clearFilters() async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: BillingWorkspaceQuery(
          search: current.query.search,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace();
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(pageRequest: request),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace();
  }

  void selectItem(BillingWorkItem item) {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(current.copyWith(selectedItem: item, clearLastFailure: true));
  }

  Future<AppFailure?> issueSelectedInvoice({String? notes}) {
    final BillingWorkItem? selected = _selectedInvoice;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () => _repository.issueInvoice(selected.id, notes: notes),
    );
  }

  Future<AppFailure?> sendSelectedInvoice({String? recipientEmail}) {
    final BillingWorkItem? selected = _selectedInvoice;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () =>
          _repository.sendInvoice(selected.id, recipientEmail: recipientEmail),
    );
  }

  Future<AppFailure?> receivePayment(BillingPaymentDraft draft) {
    final BillingWorkItem? selected = _selectedInvoice;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitOnlineOnlyAction(
      () => _repository.receivePayment(selected, draft),
    );
  }

  Future<AppFailure?> requestRefund(BillingRefundDraft draft) {
    return _submitOnlineOnlyAction(() => _repository.requestRefund(draft));
  }

  Future<AppFailure?> requestAdjustment(BillingAdjustmentDraft draft) {
    final BillingWorkItem? selected = _selectedInvoice;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.requestAdjustment(selected, draft));
  }

  Future<AppFailure?> requestInvoiceVoid({
    required String reason,
    String? notes,
  }) {
    final BillingWorkItem? selected = _selectedInvoice;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () => _repository.requestInvoiceVoid(
        selected,
        reason: reason,
        notes: notes,
      ),
    );
  }

  Future<AppFailure?> closeShift(BillingCloseDraft draft) {
    return _submitOnlineOnlyMaintenanceAction(
      () => _repository.closeShift(draft),
    );
  }

  Future<AppFailure?> closeDay(BillingCloseDraft draft) {
    return _submitOnlineOnlyMaintenanceAction(
      () => _repository.closeDay(draft),
    );
  }

  Future<Result<BillingPatientLedger>> fetchPatientLedger(
    String patientIdentifier, {
    BillingLedgerQuery query = const BillingLedgerQuery(),
  }) {
    return _repository.getPatientLedger(patientIdentifier, query);
  }

  Future<Result<BillingInvoiceDocument>> downloadInvoiceDocument(
    String invoiceId,
  ) {
    return _repository.getInvoiceDocument(invoiceId);
  }

  Future<AppFailure?> approveSelectedApproval(
    BillingApprovalDecisionDraft draft,
  ) {
    final BillingWorkItem? selected = _selectedApproval;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.approveApproval(selected.id, draft));
  }

  Future<AppFailure?> rejectSelectedApproval(
    BillingApprovalDecisionDraft draft,
  ) {
    final BillingWorkItem? selected = _selectedApproval;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.rejectApproval(selected.id, draft));
  }

  Future<AppFailure?> submitSelectedClaim(BillingClaimActionDraft draft) {
    final BillingWorkItem? selected = _selectedClaim;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.submitClaim(selected.id, draft));
  }

  Future<AppFailure?> reconcileSelectedClaim(BillingClaimActionDraft draft) {
    final BillingWorkItem? selected = _selectedClaim;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.reconcileClaim(selected.id, draft));
  }

  Future<AppFailure?> updateSelectedPreAuthorization(
    Map<String, Object?> payload,
  ) {
    final BillingWorkItem? selected = _selectedPreAuthorization;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(
      () => _repository.updatePreAuthorization(selected.id, payload),
    );
  }

  Future<AppFailure?> _submitAction(
    Future<Result<BillingMutationResult>> Function() submit,
  ) async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return _missingSelectionFailure();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<BillingMutationResult> result = await submit();
    return result.when<Future<AppFailure?>>(
      success: (BillingMutationResult mutation) async {
        _applyMutationResult(mutation);
        final BillingWorkspaceState? patched = _currentState;
        if (patched != null) {
          _emit(patched.copyWith(isSaving: false, isRefreshing: true));
        }
        final String? preferredSelectedId =
            mutation.invoice?.id ??
            mutation.approval?.id ??
            mutation.claim?.id ??
            current.selectedItem?.id;
        final AppFailure? failure = await _refreshWorkspace(
          preferredSelectedId: preferredSelectedId,
        );
        await _flushPendingRefresh(preferredSelectedId: preferredSelectedId);
        if (patched != null) {
          _emit(
            _currentState!.copyWith(
              lastActionPendingApproval: mutation.approvalRequired,
            ),
          );
        }
        return failure;
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        await _flushPendingRefresh(
          preferredSelectedId: current.selectedItem?.id,
        );
        return failure;
      },
    );
  }

  /// Payments, refunds, and closeout must never queue offline.
  Future<AppFailure?> _submitOnlineOnlyAction(
    Future<Result<BillingMutationResult>> Function() submit,
  ) async {
    final AppFailure? offline = _rejectIfOffline();
    if (offline != null) {
      return offline;
    }
    return _submitAction(submit);
  }

  Future<AppFailure?> _submitMaintenanceAction(
    Future<Result<void>> Function() submit,
  ) async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return _missingSelectionFailure();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await submit();
    return result.when<Future<AppFailure?>>(
      success: (_) async {
        _emit(_currentState!.copyWith(isSaving: false, isRefreshing: true));
        final AppFailure? failure = await _refreshWorkspace(
          preferredSelectedId: current.selectedItem?.id,
        );
        await _flushPendingRefresh(
          preferredSelectedId: current.selectedItem?.id,
        );
        return failure;
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        await _flushPendingRefresh(
          preferredSelectedId: current.selectedItem?.id,
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> _submitOnlineOnlyMaintenanceAction(
    Future<Result<void>> Function() submit,
  ) async {
    final AppFailure? offline = _rejectIfOffline();
    if (offline != null) {
      return offline;
    }
    return _submitMaintenanceAction(submit);
  }

  AppFailure? _rejectIfOffline() {
    final AsyncValue<AppConnectivityStatus> status = ref.read(
      appConnectivityStatusProvider,
    );
    final bool isOffline = status.maybeWhen(
      data: (AppConnectivityStatus value) =>
          value == AppConnectivityStatus.offline,
      orElse: () => false,
    );
    if (!isOffline) {
      return null;
    }
    final BillingWorkspaceState? current = _currentState;
    const AppFailure offline = AppFailure.offline();
    if (current != null) {
      _emit(current.copyWith(lastFailure: offline));
    }
    return offline;
  }

  Future<AppFailure?> _refreshWorkspace({String? preferredSelectedId}) async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }
    if (_isSyncing || current.isSaving) {
      _pendingRefresh.refreshPending = true;
      return null;
    }

    _isSyncing = true;
    final Result<BillingWorkspaceOverview> overviewResult = await _repository
        .getWorkspace(current.query);
    try {
      return await overviewResult.when<Future<AppFailure?>>(
        success: (BillingWorkspaceOverview overview) async {
          final Result<AppPage<BillingWorkItem>> itemsResult = await _repository
              .listWorkItems(current.query);
          return itemsResult.when(
            success: (AppPage<BillingWorkItem> workItems) {
              final BillingWorkItem? selected = _selectAfterRefresh(
                workItems.items,
                preferredSelectedId,
              );
              _emit(
                _currentState!.copyWith(
                  overview: overview,
                  workItems: workItems,
                  selectedItem: selected,
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
        },
        failure: (AppFailure failure) async {
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
    } finally {
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _flushPendingRefresh({
    String? preferredSelectedId,
  }) async {
    if (!_pendingRefresh.refreshPending ||
        _isSyncing ||
        (_currentState?.isSaving ?? false)) {
      return null;
    }
    _pendingRefresh.refreshPending = false;
    return _refreshWorkspace(preferredSelectedId: preferredSelectedId);
  }

  void _applyMutationResult(BillingMutationResult mutation) {
    if (!mutation.hasImmediatePatch) {
      return;
    }

    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }

    final BillingWorkItem? patchItem =
        mutation.invoice ?? mutation.approval ?? mutation.claim;
    if (patchItem == null) {
      return;
    }

    final AppPage<BillingWorkItem> workItems = _upsertWorkItem(
      current.workItems,
      patchItem,
    );
    final BillingWorkItem selected = current.selectedItem?.id == patchItem.id
        ? patchItem
        : current.selectedItem ?? patchItem;
    _emit(
      current.copyWith(
        workItems: workItems,
        selectedItem: selected,
        clearLastFailure: true,
      ),
    );
  }

  AppPage<BillingWorkItem> _upsertWorkItem(
    AppPage<BillingWorkItem> page,
    BillingWorkItem item,
  ) {
    final List<BillingWorkItem> items = page.items
        .where((BillingWorkItem existing) => existing.id != item.id)
        .toList(growable: true);
    final bool inserted = items.length == page.items.length;
    items.insert(0, item);
    final int maxItems = page.request.pageSize;
    final List<BillingWorkItem> visible = items.length > maxItems
        ? items.take(maxItems).toList(growable: false)
        : items.toList(growable: false);

    return AppPage<BillingWorkItem>(
      items: visible,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : page.totalItemCount! + (inserted ? 1 : 0),
    );
  }

  BillingWorkItem? _selectAfterRefresh(
    List<BillingWorkItem> items,
    String? preferredSelectedId,
  ) {
    if (preferredSelectedId != null) {
      for (final BillingWorkItem item in items) {
        if (item.id == preferredSelectedId) {
          return item;
        }
      }
    }
    return items.firstOrNull;
  }

  BillingWorkItem? get _selectedInvoice {
    final BillingWorkItem? selected = _currentState?.selectedItem;
    return selected != null && selected.isInvoice ? selected : null;
  }

  BillingWorkItem? get _selectedApproval {
    final BillingWorkItem? selected = _currentState?.selectedItem;
    return selected != null && selected.isApproval ? selected : null;
  }

  BillingWorkItem? get _selectedClaim {
    final BillingWorkItem? selected = _currentState?.selectedItem;
    return selected != null && selected.isClaim ? selected : null;
  }

  BillingWorkItem? get _selectedPreAuthorization {
    final BillingWorkItem? selected = _currentState?.selectedItem;
    return selected != null && selected.isPreAuthorization ? selected : null;
  }

  BillingWorkspaceState? get _currentState {
    final Result<BillingWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<BillingWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(BillingWorkspaceState nextState) {
    state = AsyncData<Result<BillingWorkspaceState>>(
      Result<BillingWorkspaceState>.success(nextState),
    );
  }

  AppFailure _missingSelectionFailure() {
    return AppFailure.validation(validationFields: <String>{'invoice_id'});
  }
}

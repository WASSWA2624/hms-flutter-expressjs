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
import 'package:hosspi_hms/core/network/idempotency.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_realtime_delta_applier.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_mutation_applier.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_payment_gate_controller.dart';
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
      applyDelta: BillingRealtimeDeltaApplier.apply,
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
          queue: current.query.queue,
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
    final String idempotencyKey = createIdempotencyKey();
    return _submitReceivePayment(
      () => _repository.receivePayment(
        selected,
        draft,
        idempotencyKey: idempotencyKey,
      ),
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

  /// Receive payment patches Billing (and linked workspaces) immediately;
  /// success must not wait on a blanket workspace GET.
  Future<AppFailure?> _submitReceivePayment(
    Future<Result<BillingMutationResult>> Function() submit,
  ) async {
    final AppFailure? offline = _rejectIfOffline();
    if (offline != null) {
      return offline;
    }

    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return _missingSelectionFailure();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<BillingMutationResult> result = await submit();
    return result.when<Future<AppFailure?>>(
      success: (BillingMutationResult mutation) async {
        final BillingWorkspaceState? latest = _currentState;
        if (latest == null) {
          return null;
        }
        final BillingWorkspaceState patched =
            BillingWorkspaceMutationApplier.apply(latest, mutation);
        _emit(patched);
        _syncLinkedWorkspacesAfterPayment(mutation.invoice);
        // Reconcile publishes several billing realtime events while isSaving.
        // Those arm refreshPending; a full work-items GET would drop the paid
        // invoice from queue-scoped lists and clobber the authoritative patch
        // (detail dialog would fall back to the unpaid snapshot).
        _pendingRefresh.refreshPending = false;
        return null;
      },
      failure: (AppFailure failure) async {
        final BillingWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        await _flushPendingRefresh(
          preferredSelectedId: current.selectedItem?.id,
        );
        return failure;
      },
    );
  }

  void _syncLinkedWorkspacesAfterPayment(BillingWorkItem? invoice) {
    if (invoice == null) {
      return;
    }
    if (ref.exists(receptionPaymentGateControllerProvider)) {
      ref
          .read(receptionPaymentGateControllerProvider.notifier)
          .applyInvoiceUpdate(invoice);
    }
    if (ref.exists(opdWorkspaceControllerProvider)) {
      ref
          .read(opdWorkspaceControllerProvider.notifier)
          .applyConsultationInvoicePaidIfLoaded(invoice);
    }
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
                previousSelected: _currentState?.selectedItem,
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
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(BillingWorkspaceMutationApplier.apply(current, mutation));
  }

  BillingWorkItem? _selectAfterRefresh(
    List<BillingWorkItem> items,
    String? preferredSelectedId, {
    BillingWorkItem? previousSelected,
  }) {
    if (preferredSelectedId != null) {
      for (final BillingWorkItem item in items) {
        if (item.id == preferredSelectedId) {
          return _preferFresherSelection(item, previousSelected);
        }
      }
      // Paid invoices leave pending-payment / merged-all queues; keep the
      // locally patched selection so open detail dialogs stay live.
      if (previousSelected?.id == preferredSelectedId) {
        return previousSelected;
      }
    }
    return items.firstOrNull;
  }

  /// Prefer the selection that already reflects a completed payment / lower due.
  BillingWorkItem _preferFresherSelection(
    BillingWorkItem fromList,
    BillingWorkItem? previousSelected,
  ) {
    if (previousSelected == null || previousSelected.id != fromList.id) {
      return fromList;
    }
    final bool previousLooksPaid =
        previousSelected.balanceDue <= 0.009 &&
        previousSelected.paidAmount >= fromList.paidAmount;
    final bool listLooksUnpaid =
        fromList.balanceDue > 0.009 &&
        (fromList.billingStatus ?? '').toUpperCase() != 'PAID';
    if (previousLooksPaid && listLooksUnpaid) {
      return previousSelected;
    }
    return fromList;
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

  /// Clears a page-level failure banner (e.g. after an inline dialog handles it).
  void clearLastFailure() {
    final BillingWorkspaceState? current = _currentState;
    if (current == null || current.lastFailure == null) {
      return;
    }
    _emit(current.copyWith(clearLastFailure: true));
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
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

  @override
  Future<Result<BillingWorkspaceState>> build() async {
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
  }

  Future<AppFailure?> refresh() async {
    final BillingWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
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
    return _submitAction(() => _repository.receivePayment(selected, draft));
  }

  Future<AppFailure?> requestRefund(BillingRefundDraft draft) {
    return _submitAction(() => _repository.requestRefund(draft));
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
    return _submitAction(() => _repository.closeShift(draft));
  }

  Future<AppFailure?> closeDay(BillingCloseDraft draft) {
    return _submitAction(() => _repository.closeDay(draft));
  }

  Future<AppFailure?> _submitAction(
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
        return _refreshWorkspace(preferredSelectedId: current.selectedItem?.id);
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshWorkspace({String? preferredSelectedId}) async {
    final BillingWorkspaceState current = _currentState!;
    final Result<BillingWorkspaceOverview> overviewResult = await _repository
        .getWorkspace(current.query);
    return overviewResult.when<Future<AppFailure?>>(
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

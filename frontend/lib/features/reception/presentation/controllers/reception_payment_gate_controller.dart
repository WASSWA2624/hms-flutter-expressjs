import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final receptionPaymentGateControllerProvider =
    AsyncNotifierProvider<
      ReceptionPaymentGateController,
      Result<ReceptionPaymentGateState>
    >(ReceptionPaymentGateController.new);

@immutable
final class ReceptionPaymentGateState {
  const ReceptionPaymentGateState({
    this.entries = const <ReceptionPaymentGateEntry>[],
    this.totalCount = 0,
    this.isRefreshing = false,
    this.lastFailure,
  });

  final List<ReceptionPaymentGateEntry> entries;

  /// Authoritative Payment-gate total (loaded aggregate length; all pages).
  final int totalCount;
  final bool isRefreshing;
  final AppFailure? lastFailure;

  ReceptionPaymentGateState copyWith({
    List<ReceptionPaymentGateEntry>? entries,
    int? totalCount,
    bool? isRefreshing,
    AppFailure? lastFailure,
    bool clearLastFailure = false,
  }) {
    return ReceptionPaymentGateState(
      entries: entries ?? this.entries,
      totalCount: totalCount ?? this.totalCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
    );
  }
}

final class ReceptionPaymentGateController
    extends AsyncNotifier<Result<ReceptionPaymentGateState>> {
  BillingRepository get _repository => ref.read(billingRepositoryProvider);

  bool _isSyncing = false;
  Future<AppFailure?>? _refreshInFlight;

  @override
  Future<Result<ReceptionPaymentGateState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.billingWorkspace,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing,
      onRefresh: _refreshFromRealtime,
    );
    return _load();
  }

  Future<AppFailure?> refresh() {
    final Future<AppFailure?>? active = _refreshInFlight;
    if (active != null) {
      return active;
    }
    late final Future<AppFailure?> operation;
    operation = _runRefresh().whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = operation;
    return operation;
  }

  Future<AppFailure?> _runRefresh() async {
    final ReceptionPaymentGateState? current = _currentState;
    if (current != null) {
      _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    }
    final Result<ReceptionPaymentGateState> result = await _load();
    AppFailure? failure;
    result.when(
      success: _emit,
      failure: (AppFailure value) {
        failure = value;
        final ReceptionPaymentGateState? previous = _currentState;
        if (previous != null) {
          _emit(previous.copyWith(isRefreshing: false, lastFailure: value));
        } else {
          state = AsyncData<Result<ReceptionPaymentGateState>>(result);
        }
      },
    );
    return failure;
  }

  Future<void> _refreshFromRealtime(RealtimeMessage _) async {
    await refresh();
  }

  /// Instantly upserts or drops a billed invoice on the Payment gate.
  void applyInvoiceUpdate(BillingWorkItem invoice) {
    final ReceptionPaymentGateState? current = _currentState;
    if (current == null || current.isRefreshing) {
      return;
    }

    final List<BillingWorkItem> invoices = <BillingWorkItem>[];
    for (final ReceptionPaymentGateEntry entry in current.entries) {
      for (final BillingWorkItem existing in entry.invoices) {
        if (existing.id == invoice.id) {
          continue;
        }
        invoices.add(existing);
      }
    }
    if (isReceptionOutstandingOpdInvoice(invoice)) {
      invoices.add(invoice);
    }

    final List<ReceptionPaymentGateEntry> entries =
        aggregateReceptionPaymentGateEntries(invoices);
    _emit(
      current.copyWith(
        entries: entries,
        totalCount: entries.length,
        isRefreshing: false,
        clearLastFailure: true,
      ),
    );
  }

  Future<Result<ReceptionPaymentGateState>> _load() async {
    _isSyncing = true;
    try {
      final List<BillingWorkItem> invoices = <BillingWorkItem>[];
      var request = const AppPageRequest(pageSize: AppPageRequest.maxPageSize);
      while (true) {
        final BillingWorkspaceQuery query = BillingWorkspaceQuery(
          queue: BillingQueueType.pendingPayment,
          pageRequest: request,
        );
        final Result<AppPage<BillingWorkItem>> result = await _repository
            .listWorkItems(query);
        AppFailure? failure;
        AppPage<BillingWorkItem>? page;
        result.when(
          success: (AppPage<BillingWorkItem> value) => page = value,
          failure: (AppFailure value) => failure = value,
        );
        if (failure != null) {
          return Result<ReceptionPaymentGateState>.failure(failure!);
        }
        final AppPage<BillingWorkItem> loaded = page!;
        invoices.addAll(loaded.items);
        if (!loaded.hasNextPage) {
          break;
        }
        request = request.next();
      }
      final List<ReceptionPaymentGateEntry> entries =
          aggregateReceptionPaymentGateEntries(invoices);
      return Result<ReceptionPaymentGateState>.success(
        ReceptionPaymentGateState(
          entries: entries,
          totalCount: entries.length,
        ),
      );
    } finally {
      _isSyncing = false;
    }
  }

  ReceptionPaymentGateState? get _currentState {
    final Result<ReceptionPaymentGateState>? result = state.asData?.value;
    return switch (result) {
      ResultSuccess<ReceptionPaymentGateState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(ReceptionPaymentGateState next) {
    state = AsyncData<Result<ReceptionPaymentGateState>>(
      Result<ReceptionPaymentGateState>.success(next),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';

final receptionFollowUpControllerProvider =
    AsyncNotifierProvider<
      ReceptionFollowUpController,
      Result<ReceptionFollowUpState>
    >(ReceptionFollowUpController.new);

@immutable
final class ReceptionFollowUpState {
  const ReceptionFollowUpState({
    this.entries = const <ReceptionFollowUpEntry>[],
    this.totalCount = 0,
    this.isRefreshing = false,
    this.lastFailure,
  });

  final List<ReceptionFollowUpEntry> entries;

  /// Authoritative SCHEDULED follow-up total from list pagination (may exceed
  /// the loaded page size).
  final int totalCount;
  final bool isRefreshing;
  final AppFailure? lastFailure;

  ReceptionFollowUpState copyWith({
    List<ReceptionFollowUpEntry>? entries,
    int? totalCount,
    bool? isRefreshing,
    AppFailure? lastFailure,
    bool clearLastFailure = false,
  }) {
    return ReceptionFollowUpState(
      entries: entries ?? this.entries,
      totalCount: totalCount ?? this.totalCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
    );
  }
}

final class ReceptionFollowUpController
    extends AsyncNotifier<Result<ReceptionFollowUpState>> {
  ReceptionFollowUpRepository get _repository =>
      ref.read(receptionFollowUpRepositoryProvider);

  bool _isSyncing = false;
  Future<AppFailure?>? _refreshInFlight;

  @override
  Future<Result<ReceptionFollowUpState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.clinical,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing,
      onRefresh: (_) async {
        await refresh();
      },
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

  Future<AppFailure?> completeFollowUp(
    ReceptionFollowUpEntry entry, {
    String? notes,
  }) async {
    final Result<void> result = await _repository.completeFollowUp(
      entry.id,
      notes: notes,
    );
    final AppFailure? failure = result.when(
      success: (_) => null,
      failure: (AppFailure value) => value,
    );
    if (failure != null) {
      return failure;
    }
    await refresh();
    return null;
  }

  Future<AppFailure?> createFollowUp({
    required String encounterId,
    required DateTime scheduledAt,
    required String notes,
  }) async {
    final Result<void> result = await _repository.createFollowUp(
      <String, Object?>{
        'encounter_id': encounterId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': 'SCHEDULED',
        'notes': notes,
      },
    );
    final AppFailure? failure = result.when(
      success: (_) => null,
      failure: (AppFailure value) => value,
    );
    if (failure != null) {
      return failure;
    }
    await refresh();
    return null;
  }

  Future<AppFailure?> _runRefresh() async {
    if (!ref.mounted) {
      return null;
    }
    final ReceptionFollowUpState? current = _currentState;
    if (current != null) {
      _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    }
    final Result<ReceptionFollowUpState> result = await _load();
    if (!ref.mounted) {
      return null;
    }
    AppFailure? failure;
    result.when(
      success: _emit,
      failure: (AppFailure value) {
        failure = value;
        final ReceptionFollowUpState? previous = _currentState;
        if (previous != null) {
          _emit(previous.copyWith(isRefreshing: false, lastFailure: value));
        } else {
          state = AsyncData<Result<ReceptionFollowUpState>>(result);
        }
      },
    );
    return failure;
  }

  Future<Result<ReceptionFollowUpState>> _load() async {
    _isSyncing = true;
    try {
      final Result<({List<ReceptionFollowUpEntry> entries, int total})> result =
          await _repository.listScheduledFollowUpsPage();
      return result.when(
        success: (({List<ReceptionFollowUpEntry> entries, int total}) page) {
          final List<ReceptionFollowUpEntry> sorted =
              List<ReceptionFollowUpEntry>.of(page.entries)
                ..sort(
                  (ReceptionFollowUpEntry a, ReceptionFollowUpEntry b) =>
                      a.scheduledAt.compareTo(b.scheduledAt),
                );
          return Result<ReceptionFollowUpState>.success(
            ReceptionFollowUpState(
              entries: List.unmodifiable(sorted),
              totalCount: page.total < sorted.length ? sorted.length : page.total,
            ),
          );
        },
        failure: Result<ReceptionFollowUpState>.failure,
      );
    } finally {
      _isSyncing = false;
    }
  }

  ReceptionFollowUpState? get _currentState {
    return state.asData?.value.when(
      success: (ReceptionFollowUpState value) => value,
      failure: (_) => null,
    );
  }

  void _emit(ReceptionFollowUpState value) {
    state = AsyncData<Result<ReceptionFollowUpState>>(
      Result<ReceptionFollowUpState>.success(value),
    );
  }
}

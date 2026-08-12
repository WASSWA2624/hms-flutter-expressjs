import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

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
    this.pageRequest = const AppPageRequest(
      pageSize: AppPageRequest.maxPageSize,
    ),
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.lastFailure,
  });

  final List<ReceptionFollowUpEntry> entries;

  /// Authoritative SCHEDULED follow-up total from list pagination (may exceed
  /// the loaded [entries] length while more pages remain).
  final int totalCount;

  /// Last successfully loaded page request (0-based).
  final AppPageRequest pageRequest;
  final bool isRefreshing;
  final bool isLoadingMore;
  final AppFailure? lastFailure;

  bool get hasMore => entries.length < totalCount;

  ReceptionFollowUpState copyWith({
    List<ReceptionFollowUpEntry>? entries,
    int? totalCount,
    AppPageRequest? pageRequest,
    bool? isRefreshing,
    bool? isLoadingMore,
    AppFailure? lastFailure,
    bool clearLastFailure = false,
  }) {
    return ReceptionFollowUpState(
      entries: entries ?? this.entries,
      totalCount: totalCount ?? this.totalCount,
      pageRequest: pageRequest ?? this.pageRequest,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
    );
  }
}

final class ReceptionFollowUpController
    extends AsyncNotifier<Result<ReceptionFollowUpState>> {
  ReceptionFollowUpRepository get _repository =>
      ref.read(receptionFollowUpRepositoryProvider);

  static const AppPageRequest _firstPageRequest = AppPageRequest(
    pageSize: AppPageRequest.maxPageSize,
  );

  bool _isSyncing = false;
  Future<AppFailure?>? _refreshInFlight;
  Future<AppFailure?>? _loadMoreInFlight;

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
    return _loadFirstPage();
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

  /// Loads the next API page and appends it to [ReceptionFollowUpState.entries].
  Future<AppFailure?> loadMore() {
    final Future<AppFailure?>? active = _loadMoreInFlight;
    if (active != null) {
      return active;
    }
    late final Future<AppFailure?> operation;
    operation = _runLoadMore().whenComplete(() {
      if (identical(_loadMoreInFlight, operation)) {
        _loadMoreInFlight = null;
      }
    });
    _loadMoreInFlight = operation;
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
      _emit(
        current.copyWith(
          isRefreshing: true,
          isLoadingMore: false,
          clearLastFailure: true,
        ),
      );
    }
    final Result<ReceptionFollowUpState> result = await _loadFirstPage();
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
          _emit(
            previous.copyWith(
              isRefreshing: false,
              isLoadingMore: false,
              lastFailure: value,
            ),
          );
        } else {
          state = AsyncData<Result<ReceptionFollowUpState>>(result);
        }
      },
    );
    return failure;
  }

  Future<AppFailure?> _runLoadMore() async {
    if (!ref.mounted) {
      return null;
    }
    final ReceptionFollowUpState? current = _currentState;
    if (current == null ||
        current.isRefreshing ||
        current.isLoadingMore ||
        !current.hasMore) {
      return null;
    }

    final AppPageRequest nextRequest = current.pageRequest
        .next()
        .copyWith(pageSize: AppPageRequest.maxPageSize);
    _emit(current.copyWith(isLoadingMore: true, clearLastFailure: true));
    _isSyncing = true;
    try {
      final Result<({List<ReceptionFollowUpEntry> entries, int total})> result =
          await _repository.listScheduledFollowUpsPage(
            pageRequest: nextRequest,
          );
      if (!ref.mounted) {
        return null;
      }
      return result.when(
        success: (({List<ReceptionFollowUpEntry> entries, int total}) page) {
          final ReceptionFollowUpState latest = _currentState ?? current;
          final List<ReceptionFollowUpEntry> merged = _mergeEntries(
            latest.entries,
            page.entries,
          );
          final int totalCount = page.total < merged.length
              ? merged.length
              : page.total;
          _emit(
            latest.copyWith(
              entries: List.unmodifiable(merged),
              totalCount: totalCount,
              pageRequest: nextRequest,
              isLoadingMore: false,
              isRefreshing: false,
              clearLastFailure: true,
            ),
          );
          return null;
        },
        failure: (AppFailure failure) {
          final ReceptionFollowUpState latest = _currentState ?? current;
          _emit(
            latest.copyWith(isLoadingMore: false, lastFailure: failure),
          );
          return failure;
        },
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<Result<ReceptionFollowUpState>> _loadFirstPage() async {
    _isSyncing = true;
    try {
      final Result<({List<ReceptionFollowUpEntry> entries, int total})> result =
          await _repository.listScheduledFollowUpsPage(
            pageRequest: _firstPageRequest,
          );
      return result.when(
        success: (({List<ReceptionFollowUpEntry> entries, int total}) page) {
          final List<ReceptionFollowUpEntry> sorted =
              _sortedEntries(page.entries);
          return Result<ReceptionFollowUpState>.success(
            ReceptionFollowUpState(
              entries: List.unmodifiable(sorted),
              totalCount: page.total < sorted.length
                  ? sorted.length
                  : page.total,
              pageRequest: _firstPageRequest,
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

  static List<ReceptionFollowUpEntry> _sortedEntries(
    Iterable<ReceptionFollowUpEntry> entries,
  ) {
    return List<ReceptionFollowUpEntry>.of(entries)
      ..sort(
        (ReceptionFollowUpEntry a, ReceptionFollowUpEntry b) =>
            a.scheduledAt.compareTo(b.scheduledAt),
      );
  }

  static List<ReceptionFollowUpEntry> _mergeEntries(
    List<ReceptionFollowUpEntry> existing,
    List<ReceptionFollowUpEntry> incoming,
  ) {
    if (incoming.isEmpty) {
      return existing;
    }
    final Set<String> seen = <String>{
      for (final ReceptionFollowUpEntry entry in existing) entry.id,
    };
    final List<ReceptionFollowUpEntry> merged =
        List<ReceptionFollowUpEntry>.of(existing);
    for (final ReceptionFollowUpEntry entry in incoming) {
      if (seen.add(entry.id)) {
        merged.add(entry);
      }
    }
    return _sortedEntries(merged);
  }
}

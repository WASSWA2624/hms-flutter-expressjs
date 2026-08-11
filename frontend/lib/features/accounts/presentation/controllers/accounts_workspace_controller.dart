import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_adaptive_polling.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_mutation_applier.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final accountsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      AccountsWorkspaceController,
      Result<AccountsWorkspaceState>
    >(AccountsWorkspaceController.new);

/// Live count of GL accounts with activity (panel may override while filtered).
final accountsGlActivityCountProvider = StateProvider<int?>((Ref ref) => null);

/// Live count of open fiscal periods (Close books strip).
final accountsOpenPeriodsCountProvider = StateProvider<int?>((Ref ref) => null);

final class AccountsWorkspaceController
    extends AsyncNotifier<Result<AccountsWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 20);

  AccountsRepository get _repository => ref.read(accountsRepositoryProvider);

  bool _isSyncing = false;
  final WorkspaceAdaptivePolling _adaptivePolling = WorkspaceAdaptivePolling();

  AccountsWorkspaceState? get _currentState {
    final Result<AccountsWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<AccountsWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(AccountsWorkspaceState next) {
    state = AsyncData<Result<AccountsWorkspaceState>>(
      Result<AccountsWorkspaceState>.success(next),
    );
  }

  @override
  Future<Result<AccountsWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    ref.onDispose(_adaptivePolling.dispose);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.accountsWorkspace,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isSaving ?? false),
      onRefresh: (RealtimeMessage _) async {
        await refresh();
      },
    );
    final Result<AccountsWorkspaceState> result = await runWorkspaceInitialLoad(
      ref,
      () => _load(const AccountsWorkspaceQuery()),
    );
    _startAdaptivePolling();
    return result;
  }

  void _startAdaptivePolling() {
    installWorkspaceAdaptivePolling(
      ref: ref,
      polling: _adaptivePolling,
      intervalWhenDisconnected: _syncInterval,
      disconnectProfile: WorkspaceRefreshProfile.fullOnMatch,
      syncOnDisconnect: (WorkspaceRefreshPlan plan) async {
        if (plan.isEmpty) {
          return;
        }
        await refresh();
      },
    );
  }

  Future<Result<AccountsWorkspaceState>> _load(
    AccountsWorkspaceQuery query,
  ) async {
    final Result<AccountsWorkspaceOverview> overviewResult = await _repository
        .getWorkspace(query);
    return overviewResult.when(
      success: (AccountsWorkspaceOverview overview) async {
        ref.read(accountsGlActivityCountProvider.notifier).state =
            overview.summary.glWithActivityCount;
        final Result<AppPage<AccountsWorkItem>> itemsResult = await _repository
            .listWorkItems(query);
        return itemsResult.when(
          success: (AppPage<AccountsWorkItem> workItems) {
            return Result<AccountsWorkspaceState>.success(
              AccountsWorkspaceState(
                query: query,
                overview: overview,
                workItems: workItems,
                selectedItem: workItems.items.firstOrNull,
              ),
            );
          },
          failure: (AppFailure failure) {
            return Result<AccountsWorkspaceState>.success(
              AccountsWorkspaceState(
                query: query,
                overview: overview,
                workItems: AppPage<AccountsWorkItem>(
                  items: const <AccountsWorkItem>[],
                  request: query.pageRequest,
                  totalItemCount: 0,
                ),
                lastFailure: failure,
              ),
            );
          },
        );
      },
      failure: (AppFailure failure) async {
        return Result<AccountsWorkspaceState>.failure(failure);
      },
    );
  }

  Future<AppFailure?> refresh() async {
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }
    if (_isSyncing || current.isSaving) {
      return null;
    }
    _isSyncing = true;
    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    try {
      final Result<AccountsWorkspaceState> result = await _load(current.query);
      return result.when(
        success: (AccountsWorkspaceState next) {
          _emit(next.copyWith(isRefreshing: false));
          return null;
        },
        failure: (AppFailure failure) {
          _emit(current.copyWith(isRefreshing: false, lastFailure: failure));
          return failure;
        },
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<AppFailure?> applySection(AccountsDeskSection section) async {
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }
    final AccountsWorkspaceQuery nextQuery = current.query.copyWith(
      section: section,
      pageRequest: current.query.pageRequest.first(),
    );
    _emit(
      current.copyWith(
        query: nextQuery,
        isRefreshing: true,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
    final Result<AccountsWorkspaceState> result = await _load(nextQuery);
    return result.when(
      success: (AccountsWorkspaceState next) {
        _emit(next.copyWith(isRefreshing: false));
        return null;
      },
      failure: (AppFailure failure) {
        _emit(current.copyWith(isRefreshing: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> applySearch(String value) async {
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }
    final AccountsWorkspaceQuery nextQuery = current.query.copyWith(
      search: value.trim(),
      pageRequest: current.query.pageRequest.first(),
    );
    _emit(
      current.copyWith(
        query: nextQuery,
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    final Result<AccountsWorkspaceState> result = await _load(nextQuery);
    return result.when(
      success: (AccountsWorkspaceState next) {
        _emit(next.copyWith(isRefreshing: false));
        return null;
      },
      failure: (AppFailure failure) {
        _emit(current.copyWith(isRefreshing: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> applyQuery(AccountsWorkspaceQuery query) async {
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }
    _emit(
      current.copyWith(
        query: query,
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    final Result<AccountsWorkspaceState> result = await _load(query);
    return result.when(
      success: (AccountsWorkspaceState next) {
        _emit(next.copyWith(isRefreshing: false));
        return null;
      },
      failure: (AppFailure failure) {
        _emit(current.copyWith(isRefreshing: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<Result<AccountsGlLedger>> fetchAccountLedger(String accountId) {
    return _repository.getAccountLedger(accountId);
  }

  void selectItem(AccountsWorkItem item) {
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(current.copyWith(selectedItem: item, clearLastFailure: true));
  }

  void clearLastFailure() {
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(current.copyWith(clearLastFailure: true));
  }

  Future<AppFailure?> clearFilters() {
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      return Future<AppFailure?>.value();
    }
    return applyQuery(
      AccountsWorkspaceQuery(section: current.query.section),
    );
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }
    return applyQuery(current.query.copyWith(pageRequest: request));
  }

  Future<AppFailure?> createJournal(AccountsJournalDraft draft) {
    return _submitMutation(() => _repository.createJournal(draft));
  }

  Future<AppFailure?> postSelectedJournal({String? notes}) {
    final AccountsWorkItem? selected = _currentState?.selectedItem;
    if (selected == null || !selected.canPost) {
      return Future<AppFailure?>.value(
        AppFailure.validation(validationFields: <String>{'journal_id'}),
      );
    }
    return _submitMutation(
      () => _repository.postJournal(selected.id, notes: notes),
    );
  }

  /// Bulk-post draft journals (To post → Post all). Stops on first failure.
  Future<AppFailure?> postJournals(
    List<String> journalIds, {
    String? notes,
  }) async {
    final List<String> ids = journalIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      return AppFailure.validation(validationFields: <String>{'journal_id'});
    }
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      return const AppFailure.unexpected();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    AppFailure? failure;
    for (final String journalId in ids) {
      final Result<AccountsMutationResult> result = await _repository
          .postJournal(journalId, notes: notes);
      final bool stop = result.when(
        success: (AccountsMutationResult mutation) {
          final AccountsWorkspaceState? after = _currentState;
          if (after != null) {
            _emit(
              AccountsWorkspaceMutationApplier.apply(after, mutation).copyWith(
                lastActionPendingApproval: mutation.approvalRequired,
              ),
            );
          }
          return false;
        },
        failure: (AppFailure error) {
          failure = error;
          return true;
        },
      );
      if (stop) {
        break;
      }
    }

    final AccountsWorkspaceState? after = _currentState;
    if (after != null) {
      _emit(
        after.copyWith(
          isSaving: false,
          isRefreshing: failure == null,
          lastFailure: failure,
          clearLastFailure: failure == null,
        ),
      );
    }
    if (failure == null) {
      await refresh();
    }
    return failure;
  }

  Future<AppFailure?> reverseSelectedJournal({
    required String reason,
    String? notes,
  }) {
    final AccountsWorkItem? selected = _currentState?.selectedItem;
    if (selected == null) {
      return Future<AppFailure?>.value(
        AppFailure.validation(validationFields: <String>{'journal_id'}),
      );
    }
    return _submitMutation(
      () => _repository.reverseJournal(
        selected.id,
        reason: reason,
        notes: notes,
      ),
    );
  }

  Future<AppFailure?> voidSelectedJournal({
    required String reason,
    String? notes,
  }) {
    final AccountsWorkItem? selected = _currentState?.selectedItem;
    if (selected == null) {
      return Future<AppFailure?>.value(
        AppFailure.validation(validationFields: <String>{'journal_id'}),
      );
    }
    return _submitMutation(
      () => _repository.voidJournal(
        selected.id,
        reason: reason,
        notes: notes,
      ),
    );
  }

  Future<AppFailure?> closeSelectedPeriod({String? notes}) {
    final AccountsWorkItem? selected = _currentState?.selectedItem;
    if (selected == null) {
      return Future<AppFailure?>.value(
        AppFailure.validation(validationFields: <String>{'period_id'}),
      );
    }
    return _submitMutation(
      () => _repository.closePeriod(selected.id, notes: notes),
    );
  }

  Future<AppFailure?> approveSelectedApproval(
    AccountsApprovalDecisionDraft draft,
  ) {
    final AccountsWorkItem? selected = _selectedApproval;
    if (selected == null) {
      return Future<AppFailure?>.value(
        AppFailure.validation(validationFields: <String>{'approval_id'}),
      );
    }
    return _submitMutation(
      () => _repository.approveRequest(selected.id, notes: draft.notes),
    );
  }

  Future<AppFailure?> rejectSelectedApproval(
    AccountsApprovalDecisionDraft draft,
  ) {
    final AccountsWorkItem? selected = _selectedApproval;
    if (selected == null) {
      return Future<AppFailure?>.value(
        AppFailure.validation(validationFields: <String>{'approval_id'}),
      );
    }
    final String reason = (draft.reason ?? '').trim();
    if (reason.isEmpty) {
      return Future<AppFailure?>.value(
        AppFailure.validation(validationFields: <String>{'reason'}),
      );
    }
    return _submitMutation(
      () => _repository.rejectRequest(
        selected.id,
        reason: reason,
        notes: draft.notes,
      ),
    );
  }

  AccountsWorkItem? get _selectedApproval {
    final AccountsWorkItem? selected = _currentState?.selectedItem;
    if (selected == null || !selected.canApproveOrReject) {
      return null;
    }
    return selected;
  }

  Future<AppFailure?> _submitMutation(
    Future<Result<AccountsMutationResult>> Function() submit,
  ) async {
    final AccountsWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation(validationFields: <String>{'item_id'});
    }
    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<AccountsMutationResult> result = await submit();
    return result.when(
      success: (AccountsMutationResult mutation) async {
        final AccountsWorkspaceState latest = _currentState ?? current;
        final AccountsWorkspaceState patched =
            AccountsWorkspaceMutationApplier.apply(latest, mutation);
        _emit(
          patched.copyWith(
            isSaving: false,
            isRefreshing: true,
            lastActionPendingApproval: mutation.approvalRequired,
          ),
        );
        await refresh();
        return null;
      },
      failure: (AppFailure failure) async {
        final AccountsWorkspaceState latest = _currentState ?? current;
        _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }
}

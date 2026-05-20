import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/features/communications/data/repositories/communications_repository_impl.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/domain/repositories/communications_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final communicationsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      CommunicationsWorkspaceController,
      Result<CommunicationsWorkspaceState>
    >(CommunicationsWorkspaceController.new);

final class CommunicationsWorkspaceController
    extends AsyncNotifier<Result<CommunicationsWorkspaceState>> {
  CommunicationsRepository get _repository =>
      ref.read(communicationsRepositoryProvider);

  @override
  Future<Result<CommunicationsWorkspaceState>> build() async {
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.communications,
      onRefresh: (_) => _syncFromRealtime(),
    );
    return _repository.getWorkspace(const CommunicationsWorkspaceQuery());
  }

  Future<void> _syncFromRealtime() async {
    await refresh();
  }

  Future<AppFailure?> refresh() async {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }
    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    return _refreshWorkspace();
  }

  Future<AppFailure?> applyRouteQuery(CommunicationsWorkspaceQuery query) {
    return _applyQuery(query.copyWith(pageRequest: query.pageRequest.first()));
  }

  Future<AppFailure?> applySearch(String value) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _applyQuery(
      current.query.copyWith(
        search: value.trim(),
        pageRequest: current.query.pageRequest.first(),
      ),
    );
  }

  Future<AppFailure?> applyPanel(CommunicationsPanel panel) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _applyQuery(
      current.query.copyWith(
        panel: panel,
        pageRequest: current.query.pageRequest.first(),
        clearConversationId: true,
        clearMessageId: true,
        clearNotificationId: true,
        clearTemplateId: true,
        clearAction: true,
      ),
    );
  }

  Future<AppFailure?> applyFilter({
    String? filter,
    bool unreadOnly = false,
    bool sensitive = false,
  }) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _applyQuery(
      current.query.copyWith(
        filter: filter,
        unreadOnly: unreadOnly,
        sensitive: sensitive,
        pageRequest: current.query.pageRequest.first(),
        clearFilter: filter == null,
      ),
    );
  }

  Future<AppFailure?> changePage(AppPageRequest request) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _applyQuery(current.query.copyWith(pageRequest: request));
  }

  void selectConversation(CommunicationsConversation conversation) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        selectedConversation: conversation,
        clearSelectedNotification: true,
        clearSelectedDelivery: true,
        clearSelectedTemplate: true,
        clearLastFailure: true,
      ),
    );
  }

  void selectNotification(NotificationItem notification) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        selectedNotification: notification,
        clearSelectedConversation: true,
        clearSelectedDelivery: true,
        clearSelectedTemplate: true,
        clearLastFailure: true,
      ),
    );
  }

  void selectDelivery(NotificationDelivery delivery) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        selectedDelivery: delivery,
        clearSelectedConversation: true,
        clearSelectedNotification: true,
        clearSelectedTemplate: true,
        clearLastFailure: true,
      ),
    );
  }

  void selectTemplate(CommunicationTemplate template) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        selectedTemplate: template,
        clearSelectedConversation: true,
        clearSelectedNotification: true,
        clearSelectedDelivery: true,
        clearLastFailure: true,
      ),
    );
  }

  Future<AppFailure?> markSelectedNotificationRead() {
    final NotificationItem? selected = _currentState?.selectedNotification;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitNotificationMutation(
      () => _repository.markNotificationRead(selected.id),
    );
  }

  Future<AppFailure?> markSelectedNotificationUnread() {
    final NotificationItem? selected = _currentState?.selectedNotification;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitNotificationMutation(
      () => _repository.markNotificationUnread(selected.id),
    );
  }

  Future<AppFailure?> archiveSelectedNotification() {
    final NotificationItem? selected = _currentState?.selectedNotification;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitAction(() => _repository.archiveNotification(selected.id), (
      CommunicationsWorkspaceState current,
    ) async {
      final List<NotificationItem> nextItems = current.notifications.items
          .where((NotificationItem item) => item.id != selected.id)
          .toList(growable: false);
      final NotificationItem? nextSelected = nextItems.firstOrNull;
      final Result<NotificationMetrics> metricsResult = await _repository
          .getNotificationMetrics();
      return metricsResult.when(
        success: (NotificationMetrics metrics) {
          _emit(
            current.copyWith(
              metrics: metrics,
              summary: current.summary.copyWith(
                notifications: current.summary.notifications > 0
                    ? current.summary.notifications - 1
                    : 0,
              ),
              notifications: _pageWithItems(current.notifications, nextItems),
              selectedNotification: nextSelected,
              isSaving: false,
              clearSelectedNotification: nextSelected == null,
            ),
          );
          return null;
        },
        failure: (AppFailure failure) {
          _emit(current.copyWith(isSaving: false, lastFailure: failure));
          return failure;
        },
      );
    });
  }

  Future<AppFailure?> markSelectedConversationRead() {
    final CommunicationsConversation? selected =
        _currentState?.selectedConversation;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitConversationMutation(
      () => _repository.markConversationRead(selected.id),
    );
  }

  Future<AppFailure?> archiveSelectedConversation() {
    final CommunicationsConversation? selected =
        _currentState?.selectedConversation;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitConversationMutation(
      () => _repository.archiveConversation(selected.id),
      removeWhenNotArchivedFilter: true,
    );
  }

  Future<AppFailure?> unarchiveSelectedConversation() {
    final CommunicationsConversation? selected =
        _currentState?.selectedConversation;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitConversationMutation(
      () => _repository.unarchiveConversation(selected.id),
      removeWhenArchivedFilter: true,
    );
  }

  Future<AppFailure?> sendMessage(String content) {
    final CommunicationsConversation? selected =
        _currentState?.selectedConversation;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitConversationMutation(
      () => _repository.sendMessage(
        selected.id,
        CommunicationMessageDraft(content: content),
      ),
    );
  }

  Future<AppFailure?> createConversation(CommunicationConversationDraft draft) {
    return _submitAction(() => _repository.createConversation(draft), (
      CommunicationsWorkspaceState current,
    ) async {
      final Result<CommunicationsConversation> result = await _repository
          .createConversation(draft);
      return result.when(
        success: (CommunicationsConversation conversation) {
          final List<CommunicationsConversation> nextItems =
              <CommunicationsConversation>[
                conversation,
                ...current.conversations.items.where(
                  (CommunicationsConversation item) =>
                      item.id != conversation.id,
                ),
              ];
          _emit(
            current.copyWith(
              query: current.query.copyWith(
                panel: CommunicationsPanel.inbox,
                conversationId: conversation.id,
                pageRequest: current.query.pageRequest.first(),
              ),
              conversations: _pageWithItems(current.conversations, nextItems),
              selectedConversation: conversation,
              isSaving: false,
              clearSelectedNotification: true,
              clearSelectedDelivery: true,
              clearSelectedTemplate: true,
            ),
          );
          return null;
        },
        failure: (AppFailure failure) {
          _emit(current.copyWith(isSaving: false, lastFailure: failure));
          return failure;
        },
      );
    }, alreadySubmittedByHandler: true);
  }

  Future<AppFailure?> _applyQuery(CommunicationsWorkspaceQuery query) async {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }
    _emit(
      current.copyWith(
        query: query,
        isRefreshing: true,
        clearLastFailure: true,
        clearSelectedConversation: true,
        clearSelectedNotification: true,
        clearSelectedDelivery: true,
        clearSelectedTemplate: true,
      ),
    );
    return _refreshWorkspace();
  }

  Future<AppFailure?> _refreshWorkspace() async {
    final CommunicationsWorkspaceState current = _currentState!;
    final Result<CommunicationsWorkspaceState> result = await _repository
        .getWorkspace(current.query);
    return result.when(
      success: (CommunicationsWorkspaceState nextState) {
        _emit(nextState.copyWith(isRefreshing: false, isSaving: false));
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          current.copyWith(
            isRefreshing: false,
            isSaving: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> _submitNotificationMutation(
    Future<Result<NotificationItem>> Function() submit,
  ) {
    return _submitAction(submit, (CommunicationsWorkspaceState current) async {
      final Result<NotificationItem> result = await submit();
      return result.when(
        success: (NotificationItem notification) async {
          final Result<NotificationMetrics> metricsResult = await _repository
              .getNotificationMetrics();
          return metricsResult.when(
            success: (NotificationMetrics metrics) {
              final List<NotificationItem> nextItems = _replaceItem(
                current.notifications.items,
                notification,
                (NotificationItem item) => item.id,
              );
              _emit(
                current.copyWith(
                  metrics: metrics,
                  notifications: _pageWithItems(
                    current.notifications,
                    nextItems,
                  ),
                  selectedNotification: notification,
                  isSaving: false,
                ),
              );
              return null;
            },
            failure: (AppFailure failure) {
              _emit(current.copyWith(isSaving: false, lastFailure: failure));
              return failure;
            },
          );
        },
        failure: (AppFailure failure) {
          _emit(current.copyWith(isSaving: false, lastFailure: failure));
          return failure;
        },
      );
    }, alreadySubmittedByHandler: true);
  }

  Future<AppFailure?> _submitConversationMutation(
    Future<Result<CommunicationsConversation>> Function() submit, {
    bool removeWhenNotArchivedFilter = false,
    bool removeWhenArchivedFilter = false,
  }) {
    return _submitAction(submit, (CommunicationsWorkspaceState current) async {
      final Result<CommunicationsConversation> result = await submit();
      return result.when(
        success: (CommunicationsConversation conversation) {
          final bool archivedFilter =
              (current.query.filter ?? '').trim().toUpperCase() == 'ARCHIVED';
          final bool shouldRemove =
              removeWhenNotArchivedFilter && !archivedFilter ||
              removeWhenArchivedFilter && archivedFilter;
          final List<CommunicationsConversation> nextItems = shouldRemove
              ? current.conversations.items
                    .where(
                      (CommunicationsConversation item) =>
                          item.id != conversation.id,
                    )
                    .toList(growable: false)
              : _replaceItem(
                  current.conversations.items,
                  conversation,
                  (CommunicationsConversation item) => item.id,
                );
          final int unreadDelta = _unreadDelta(
            current.conversations.items,
            conversation,
          );
          _emit(
            current.copyWith(
              summary: current.summary.copyWith(
                unreadThreads: current.summary.unreadThreads + unreadDelta < 0
                    ? 0
                    : current.summary.unreadThreads + unreadDelta,
                archivedThreads: _archivedCountAfter(
                  current.summary.archivedThreads,
                  current.conversations.items,
                  conversation,
                ),
              ),
              conversations: _pageWithItems(current.conversations, nextItems),
              selectedConversation: shouldRemove
                  ? nextItems.firstOrNull
                  : conversation,
              isSaving: false,
              clearSelectedConversation: shouldRemove && nextItems.isEmpty,
            ),
          );
          return null;
        },
        failure: (AppFailure failure) {
          _emit(current.copyWith(isSaving: false, lastFailure: failure));
          return failure;
        },
      );
    }, alreadySubmittedByHandler: true);
  }

  Future<AppFailure?> _submitAction<T>(
    Future<Result<T>> Function() submit,
    Future<AppFailure?> Function(CommunicationsWorkspaceState current)
    onSuccess, {
    bool alreadySubmittedByHandler = false,
  }) async {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return _missingSelectionFailure();
    }
    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    if (alreadySubmittedByHandler) {
      return onSuccess(current);
    }

    final Result<T> result = await submit();
    return result.when<Future<AppFailure?>>(
      success: (_) => onSuccess(current),
      failure: (AppFailure failure) async {
        _emit(current.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  CommunicationsWorkspaceState? get _currentState {
    final Result<CommunicationsWorkspaceState>? currentResult =
        state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<CommunicationsWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(CommunicationsWorkspaceState nextState) {
    state = AsyncData<Result<CommunicationsWorkspaceState>>(
      Result<CommunicationsWorkspaceState>.success(nextState),
    );
  }

  AppFailure _missingSelectionFailure() {
    return AppFailure.validation(validationFields: <String>{'selection'});
  }
}

List<T> _replaceItem<T>(
  List<T> items,
  T replacement,
  String Function(T item) idOf,
) {
  bool replaced = false;
  final List<T> nextItems = <T>[
    for (final T item in items)
      if (idOf(item) == idOf(replacement)) ...<T>[replacement] else item,
  ];
  replaced = items.any((T item) => idOf(item) == idOf(replacement));
  if (!replaced) {
    nextItems.insert(0, replacement);
  }
  return nextItems;
}

AppPage<T> _pageWithItems<T>(AppPage<T> page, List<T> items) {
  return AppPage<T>(
    items: items,
    request: page.request,
    totalItemCount: page.totalItemCount,
  );
}

int _unreadDelta(
  List<CommunicationsConversation> items,
  CommunicationsConversation replacement,
) {
  final CommunicationsConversation? previous = items
      .where((CommunicationsConversation item) => item.id == replacement.id)
      .firstOrNull;
  if (previous == null) {
    return replacement.unread ? 1 : 0;
  }
  if (previous.unread == replacement.unread) {
    return 0;
  }
  return replacement.unread ? 1 : -1;
}

int _archivedCountAfter(
  int current,
  List<CommunicationsConversation> items,
  CommunicationsConversation replacement,
) {
  final CommunicationsConversation? previous = items
      .where((CommunicationsConversation item) => item.id == replacement.id)
      .firstOrNull;
  if (previous == null || previous.archived == replacement.archived) {
    return current;
  }
  final int next = current + (replacement.archived ? 1 : -1);
  return next < 0 ? 0 : next;
}

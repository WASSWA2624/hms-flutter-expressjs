import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/communications/data/repositories/communications_repository_impl.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/domain/repositories/communications_repository.dart';
import 'package:hosspi_hms/features/communications/presentation/config/communications_message_filters.dart';
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

  final Map<CommunicationsPanel, CommunicationsWorkspaceState> _panelSnapshots =
      <CommunicationsPanel, CommunicationsWorkspaceState>{};

  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();
  bool _isSyncing = false;

  @override
  Future<Result<CommunicationsWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.communications,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isSaving ?? false),
      onRefresh: _syncFromRealtime,
    );
    return runWorkspaceInitialLoad(
      ref,
      () => _repository.getWorkspace(const CommunicationsWorkspaceQuery()),
    );
  }

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    if (_isSyncing || (_currentState?.isSaving ?? false)) {
      _pendingRefresh.defer(
        WorkspaceEventRefreshPlan.forMessage(
          message,
          profile: WorkspaceRefreshProfile.fullOnMatch,
        ),
      );
      return;
    }
    final WorkspaceRefreshPlan plan = WorkspaceEventRefreshPlan.forMessage(
      message,
      profile: WorkspaceRefreshProfile.fullOnMatch,
    );
    if (plan.isEmpty) {
      return;
    }
    await _syncVisibleData(plan: plan);
  }

  Future<AppFailure?> _syncVisibleData({
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.full,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      _pendingRefresh.defer(plan);
      return null;
    }

    if (!workspacePlanRefreshesPrimaryList(plan) && !plan.selectedDetail) {
      return null;
    }

    _isSyncing = true;
    try {
      return await _refreshWorkspace(
        preserveSelection: true,
        preserveConversation: true,
      );
    } finally {
      _isSyncing = false;
      if (_pendingRefresh.refreshPending &&
          !(_currentState?.isSaving ?? false)) {
        final WorkspaceRefreshPlan pendingPlan = _pendingRefresh.takePending();
        if (!pendingPlan.isEmpty) {
          unawaited(_syncVisibleData(plan: pendingPlan));
        }
      }
    }
  }

  Future<AppFailure?> refresh() async {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }
    _emit(
      current.copyWith(
        isRefreshing: true,
        isRefreshingConversations: true,
        isRefreshingNotifications: true,
        isRefreshingDeliveries: true,
        isRefreshingTemplates: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace(
      preserveSelection: true,
      preserveConversation: true,
    );
  }

  Future<AppFailure?> applyRouteQuery(CommunicationsWorkspaceQuery query) {
    return _applyQuery(
      query.copyWith(pageRequest: query.pageRequest.first()),
      preservePanelSelections: true,
    );
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
      preservePanelSelections: current.query.panel == CommunicationsPanel.inbox,
    );
  }

  Future<AppFailure?> applyPanel(CommunicationsPanel panel) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    if (current.query.panel == panel) {
      return Future<AppFailure?>.value();
    }

    _snapshotPanel(current);

    final CommunicationsWorkspaceState? cached = _panelSnapshots[panel];
    if (cached != null) {
      _emit(
        cached.copyWith(
          query: cached.query.copyWith(
            panel: panel,
            search: current.query.search,
            pageRequest: current.query.pageRequest.first(),
          ),
          isRefreshing: false,
          clearLastFailure: true,
        ),
      );
    }

    return _applyQuery(
      current.query.copyWith(
        panel: panel,
        pageRequest: current.query.pageRequest.first(),
        clearConversationId: panel != CommunicationsPanel.inbox,
        clearMessageId: panel != CommunicationsPanel.inbox,
        clearNotificationId: panel != CommunicationsPanel.notifications,
        clearTemplateId: panel != CommunicationsPanel.templates,
        clearAction: true,
      ),
      preservePanelSelections: true,
      backgroundRefresh: cached != null,
    );
  }

  Future<AppFailure?> applyMessageFilter(String filterId) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    final CommunicationsMessageFilter filter = communicationsMessageFilterById(
      filterId,
    );
    return _applyQuery(
      communicationsQueryForMessageFilter(current.query, filter),
      activeMessageFilter: filter,
      preservePanelSelections: true,
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
        clearFilter: filter == null && !unreadOnly,
      ),
    );
  }

  Future<AppFailure?> changePage(AppPageRequest request) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    return _applyQuery(
      current.query.copyWith(pageRequest: request),
      preservePanelSelections: current.query.panel == CommunicationsPanel.inbox,
    );
  }

  Future<AppFailure?> selectConversation(
    CommunicationsConversation conversation,
  ) async {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }
    _emit(
      current.copyWith(
        selectedConversation: conversation,
        query: current.query.copyWith(conversationId: conversation.id),
        isRefreshingThread: true,
        composeAutofocus: false,
        clearSelectedNotification: true,
        clearSelectedDelivery: true,
        clearSelectedTemplate: true,
        clearLastFailure: true,
      ),
    );
    return _loadConversation(conversation.id, markRead: true);
  }

  Future<AppFailure?> loadConversation(
    String conversationId, {
    bool markRead = false,
    bool composeAutofocus = false,
  }) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return Future<AppFailure?>.value();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(conversationId: conversationId),
        isRefreshingThread: true,
        composeAutofocus: composeAutofocus,
        clearLastFailure: true,
      ),
    );
    return _loadConversation(conversationId, markRead: markRead);
  }

  void selectNotification(NotificationItem notification) {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        selectedNotification: notification,
        query: current.query.copyWith(notificationId: notification.id),
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
        query: current.query.copyWith(templateId: template.id),
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

  Future<AppFailure?> sendMessage(CommunicationMessageDraft draft) {
    final CommunicationsConversation? selected =
        _currentState?.selectedConversation;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    final String content = draft.content.trim();
    if (content.isEmpty && draft.attachments.isEmpty) {
      return Future<AppFailure?>.value(
        AppFailure.validation(validationFields: <String>{'content'}),
      );
    }
    return _submitConversationMutation(
      () => _repository.sendMessage(selected.id, draft),
    );
  }

  Future<AppFailure?> toggleSelectedConversationFavorite() {
    final CommunicationsConversation? selected =
        _currentState?.selectedConversation;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitConversationMutation(
      () => _repository.toggleConversationFavorite(selected.id),
    );
  }

  Future<AppFailure?> toggleSelectedConversationFlag() {
    final CommunicationsConversation? selected =
        _currentState?.selectedConversation;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitConversationMutation(
      () => _repository.toggleConversationFlag(selected.id),
    );
  }

  Future<AppFailure?> addParticipantToSelected(String userId) {
    final CommunicationsConversation? selected =
        _currentState?.selectedConversation;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitConversationMutation(
      () => _repository.addParticipant(selected.id, userId),
    );
  }

  Future<AppFailure?> removeParticipantFromSelected(String participantId) {
    final CommunicationsConversation? selected =
        _currentState?.selectedConversation;
    if (selected == null) {
      return Future<AppFailure?>.value(_missingSelectionFailure());
    }
    return _submitConversationMutation(
      () => _repository.removeParticipant(selected.id, participantId),
    );
  }

  void clearSelectedConversation() {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        clearSelectedConversation: true,
        query: current.query.copyWith(clearConversationId: true),
        composeAutofocus: false,
        clearLastFailure: true,
      ),
    );
  }

  void clearComposeAutofocus() {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null || !current.composeAutofocus) {
      return;
    }
    _emit(current.copyWith(composeAutofocus: false));
  }

  Future<List<CommunicationStaffOption>> searchStaff(String query) async {
    final Result<List<CommunicationStaffOption>> result = await _repository
        .getReferenceStaff(search: query);
    return result.when(
      success: (List<CommunicationStaffOption> value) => value,
      failure: (_) => const <CommunicationStaffOption>[],
    );
  }

  Future<AppFailure?> createConversation(CommunicationConversationDraft draft) {
    return _submitAction(() => _repository.createConversation(draft), (
      CommunicationsWorkspaceState current,
    ) async {
      final Result<CommunicationsConversation> result = await _repository
          .createConversation(draft);
      return result.when(
        success: (CommunicationsConversation conversation) async {
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
              composeAutofocus: true,
              clearSelectedNotification: true,
              clearSelectedDelivery: true,
              clearSelectedTemplate: true,
            ),
          );
          return _loadConversation(conversation.id);
        },
        failure: (AppFailure failure) {
          _emit(current.copyWith(isSaving: false, lastFailure: failure));
          return failure;
        },
      );
    }, alreadySubmittedByHandler: true);
  }

  Future<AppFailure?> _applyQuery(
    CommunicationsWorkspaceQuery query, {
    CommunicationsMessageFilter? activeMessageFilter,
    bool preservePanelSelections = false,
    bool backgroundRefresh = false,
  }) async {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }

    final CommunicationsPanel panel = query.panel;
    _emit(
      current.copyWith(
        query: query,
        isRefreshing: !backgroundRefresh,
        isRefreshingConversations: panel == CommunicationsPanel.inbox,
        isRefreshingNotifications: panel == CommunicationsPanel.notifications,
        isRefreshingDeliveries: panel == CommunicationsPanel.deliveries,
        isRefreshingTemplates: panel == CommunicationsPanel.templates,
        clearLastFailure: true,
        clearSelectedConversation:
            !preservePanelSelections || panel != CommunicationsPanel.inbox,
        clearSelectedNotification:
            !preservePanelSelections ||
            panel != CommunicationsPanel.notifications,
        clearSelectedDelivery:
            !preservePanelSelections || panel != CommunicationsPanel.deliveries,
        clearSelectedTemplate:
            !preservePanelSelections || panel != CommunicationsPanel.templates,
      ),
    );

    return _refreshWorkspace(
      activeMessageFilter: activeMessageFilter,
      preserveSelection: preservePanelSelections,
      preserveConversation:
          preservePanelSelections && query.conversationId != null,
    );
  }

  Future<AppFailure?> _loadConversation(
    String conversationId, {
    bool markRead = false,
    bool composeAutofocus = false,
  }) async {
    final CommunicationsWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<CommunicationsConversation> result = await _repository
        .getConversation(conversationId);
    return result.when(
      success: (CommunicationsConversation conversation) async {
        final List<CommunicationsConversation> nextItems = _replaceItem(
          current.conversations.items,
          conversation,
          (CommunicationsConversation item) => item.id,
        );
        _emit(
          current.copyWith(
            conversations: _pageWithItems(current.conversations, nextItems),
            selectedConversation: conversation,
            isRefreshingThread: false,
            composeAutofocus: composeAutofocus,
          ),
        );
        if (markRead && conversation.unread) {
          return markSelectedConversationRead();
        }
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          current.copyWith(isRefreshingThread: false, lastFailure: failure),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshWorkspace({
    CommunicationsMessageFilter? activeMessageFilter,
    bool preserveSelection = false,
    bool preserveConversation = false,
  }) async {
    final CommunicationsWorkspaceState current = _currentState!;
    final Result<CommunicationsWorkspaceState> result = await _repository
        .getWorkspace(current.query);

    return result.when(
      success: (CommunicationsWorkspaceState nextState) {
        final CommunicationsMessageFilter filter =
            activeMessageFilter ??
            communicationsMessageFilterById(
              communicationsMessageFilterIdForQuery(current.query),
            );
        final bool usesClientFilter =
            communicationsMessageFilterUsesClientFallback(filter);
        final String? currentUserId = ref
            .read(sessionStateProvider)
            .session
            ?.user
            ?.id;
        final List<CommunicationsConversation> filteredConversations =
            applyCommunicationsMessageFilter(
              nextState.conversations.items,
              filter,
              currentUserId,
              useClientFallback: usesClientFilter,
            );

        CommunicationsConversation? selectedConversation = preserveConversation
            ? current.selectedConversation
            : null;
        selectedConversation ??= nextState.selectedConversation;
        if (selectedConversation == null &&
            current.query.conversationId != null) {
          selectedConversation = filteredConversations
              .where(
                (CommunicationsConversation item) =>
                    item.id == current.query.conversationId,
              )
              .firstOrNull;
        }
        if (!preserveSelection) {
          selectedConversation = nextState.selectedConversation;
        }

        final NotificationItem? selectedNotification = preserveSelection
            ? current.selectedNotification ?? nextState.selectedNotification
            : nextState.selectedNotification;
        final NotificationDelivery? selectedDelivery = preserveSelection
            ? current.selectedDelivery ?? nextState.selectedDelivery
            : nextState.selectedDelivery;
        final CommunicationTemplate? selectedTemplate = preserveSelection
            ? current.selectedTemplate ?? nextState.selectedTemplate
            : nextState.selectedTemplate;

        final CommunicationsWorkspaceState merged = nextState.copyWith(
          conversations: _pageWithItems(
            nextState.conversations,
            filteredConversations,
          ),
          selectedConversation: selectedConversation,
          selectedNotification: selectedNotification,
          selectedDelivery: selectedDelivery,
          selectedTemplate: selectedTemplate,
          usesClientMessageFilter:
              usesClientFilter && filter.id != kCommunicationsMessageFilterAll,
          isRefreshing: false,
          isRefreshingConversations: false,
          isRefreshingNotifications: false,
          isRefreshingDeliveries: false,
          isRefreshingTemplates: false,
          isSaving: false,
        );
        _emit(merged);
        _snapshotPanel(merged);

        final String? conversationId = merged.query.conversationId;
        if (conversationId != null &&
            (merged.selectedConversation == null ||
                merged.selectedConversation!.messages.isEmpty)) {
          return _loadConversation(
            conversationId,
            markRead: true,
            composeAutofocus: merged.composeAutofocus,
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          current.copyWith(
            isRefreshing: false,
            isRefreshingConversations: false,
            isRefreshingNotifications: false,
            isRefreshingDeliveries: false,
            isRefreshingTemplates: false,
            isSaving: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  void _snapshotPanel(CommunicationsWorkspaceState state) {
    _panelSnapshots[state.query.panel] = state;
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
      final AppFailure? failure = await onSuccess(current);
      await _flushPendingRealtimeRefresh();
      return failure;
    }

    final Result<T> result = await submit();
    return result.when<Future<AppFailure?>>(
      success: (_) async {
        final AppFailure? failure = await onSuccess(current);
        await _flushPendingRealtimeRefresh();
        return failure;
      },
      failure: (AppFailure failure) async {
        _emit(current.copyWith(isSaving: false, lastFailure: failure));
        await _flushPendingRealtimeRefresh();
        return failure;
      },
    );
  }

  Future<void> _flushPendingRealtimeRefresh() async {
    if (!_pendingRefresh.refreshPending ||
        _isSyncing ||
        (_currentState?.isSaving ?? false)) {
      return;
    }
    final WorkspaceRefreshPlan pendingPlan = _pendingRefresh.takePending();
    if (!pendingPlan.isEmpty) {
      await _syncVisibleData(plan: pendingPlan);
    }
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

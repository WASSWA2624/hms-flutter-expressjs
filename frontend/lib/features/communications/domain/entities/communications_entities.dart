import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum CommunicationsPanel {
  inbox('inbox'),
  notifications('notifications'),
  deliveries('deliveries'),
  templates('templates');

  const CommunicationsPanel(this.serverValue);

  final String serverValue;

  static CommunicationsPanel fromServer(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    for (final CommunicationsPanel panel in values) {
      if (panel.serverValue == normalized) {
        return panel;
      }
    }
    return CommunicationsPanel.inbox;
  }
}

@immutable
final class CommunicationsWorkspaceQuery {
  const CommunicationsWorkspaceQuery({
    this.panel = CommunicationsPanel.inbox,
    this.search = '',
    this.filter,
    this.conversationId,
    this.messageId,
    this.notificationId,
    this.templateId,
    this.action,
    this.unreadOnly = false,
    this.sensitive = false,
    this.pageRequest = const AppPageRequest(pageSize: 30),
  });

  factory CommunicationsWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    return CommunicationsWorkspaceQuery(
      panel: CommunicationsPanel.fromServer(params['panel']),
      search: params['search'] ?? '',
      filter: _nonEmpty(params['filter']),
      conversationId: _nonEmpty(params['conversationId']),
      messageId: _nonEmpty(params['messageId']),
      notificationId: _nonEmpty(params['notificationId']),
      templateId: _nonEmpty(params['templateId']),
      action: _nonEmpty(params['action']),
      unreadOnly: _boolParam(params['unreadOnly']),
      sensitive: _boolParam(params['sensitive']),
    );
  }

  final CommunicationsPanel panel;
  final String search;
  final String? filter;
  final String? conversationId;
  final String? messageId;
  final String? notificationId;
  final String? templateId;
  final String? action;
  final bool unreadOnly;
  final bool sensitive;
  final AppPageRequest pageRequest;

  bool get hasActiveFilters {
    return search.trim().isNotEmpty ||
        filter != null ||
        conversationId != null ||
        notificationId != null ||
        templateId != null ||
        unreadOnly ||
        sensitive;
  }

  CommunicationsWorkspaceQuery copyWith({
    CommunicationsPanel? panel,
    String? search,
    String? filter,
    String? conversationId,
    String? messageId,
    String? notificationId,
    String? templateId,
    String? action,
    bool? unreadOnly,
    bool? sensitive,
    AppPageRequest? pageRequest,
    bool clearFilter = false,
    bool clearConversationId = false,
    bool clearMessageId = false,
    bool clearNotificationId = false,
    bool clearTemplateId = false,
    bool clearAction = false,
  }) {
    return CommunicationsWorkspaceQuery(
      panel: panel ?? this.panel,
      search: search ?? this.search,
      filter: clearFilter ? null : filter ?? this.filter,
      conversationId: clearConversationId
          ? null
          : conversationId ?? this.conversationId,
      messageId: clearMessageId ? null : messageId ?? this.messageId,
      notificationId: clearNotificationId
          ? null
          : notificationId ?? this.notificationId,
      templateId: clearTemplateId ? null : templateId ?? this.templateId,
      action: clearAction ? null : action ?? this.action,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      sensitive: sensitive ?? this.sensitive,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class CommunicationsSummary {
  const CommunicationsSummary({
    this.unreadThreads = 0,
    this.archivedThreads = 0,
    this.notifications = 0,
    this.failedDeliveries = 0,
    this.templates = 0,
  });

  final int unreadThreads;
  final int archivedThreads;
  final int notifications;
  final int failedDeliveries;
  final int templates;

  int get workloadCount => unreadThreads + failedDeliveries;

  CommunicationsSummary copyWith({
    int? unreadThreads,
    int? archivedThreads,
    int? notifications,
    int? failedDeliveries,
    int? templates,
  }) {
    return CommunicationsSummary(
      unreadThreads: unreadThreads ?? this.unreadThreads,
      archivedThreads: archivedThreads ?? this.archivedThreads,
      notifications: notifications ?? this.notifications,
      failedDeliveries: failedDeliveries ?? this.failedDeliveries,
      templates: templates ?? this.templates,
    );
  }
}

@immutable
final class NotificationMetrics {
  const NotificationMetrics({
    this.total = 0,
    this.unread = 0,
    this.read = 0,
    this.attentionRequired = 0,
    this.failedDeliveries = 0,
    this.retryableDeliveries = 0,
    this.lastReceivedAt,
  });

  final int total;
  final int unread;
  final int read;
  final int attentionRequired;
  final int failedDeliveries;
  final int retryableDeliveries;
  final DateTime? lastReceivedAt;
}

@immutable
final class CommunicationsPanelSummary {
  const CommunicationsPanelSummary({
    required this.panel,
    required this.count,
    this.id,
    this.labelKey,
  });

  final CommunicationsPanel panel;
  final int count;
  final String? id;
  final String? labelKey;
}

@immutable
final class CommunicationsQueueSummary {
  const CommunicationsQueueSummary({
    required this.id,
    required this.label,
    required this.count,
    required this.panel,
    this.filter,
  });

  final String id;
  final String label;
  final int count;
  final CommunicationsPanel panel;
  final String? filter;
}

@immutable
final class CommunicationUser {
  const CommunicationUser({
    required this.id,
    this.name,
    this.email,
    this.positionTitle,
    this.initials,
    this.roles = const <String>[],
  });

  final String id;
  final String? name;
  final String? email;
  final String? positionTitle;
  final String? initials;
  final List<String> roles;

  String get displayName => _nonEmpty(name) ?? _nonEmpty(email) ?? id;
}

@immutable
final class CommunicationAttachment {
  const CommunicationAttachment({
    required this.id,
    required this.fileName,
    this.contentType,
    this.sizeBytes = 0,
    this.attachmentKind,
    this.publicUrl,
    this.createdAt,
  });

  final String id;
  final String fileName;
  final String? contentType;
  final int sizeBytes;
  final String? attachmentKind;
  final String? publicUrl;
  final DateTime? createdAt;
}

@immutable
final class CommunicationMessage {
  const CommunicationMessage({
    required this.id,
    this.conversationId,
    this.senderUserId,
    this.sender,
    this.content,
    this.messageType,
    this.sentAt,
    this.editedAt,
    this.replyToMessageId,
    this.replyToMessage,
    this.attachments = const <CommunicationAttachment>[],
  });

  final String id;
  final String? conversationId;
  final String? senderUserId;
  final CommunicationUser? sender;
  final String? content;
  final String? messageType;
  final DateTime? sentAt;
  final DateTime? editedAt;
  final String? replyToMessageId;
  final CommunicationMessage? replyToMessage;
  final List<CommunicationAttachment> attachments;

  String get preview {
    final String? text = _nonEmpty(content);
    if (text != null) {
      return text;
    }
    return attachments.isEmpty ? '' : attachments.first.fileName;
  }
}

@immutable
final class CommunicationsParticipant {
  const CommunicationsParticipant({
    required this.id,
    required this.userId,
    this.user,
    this.roleSnapshot,
    this.joinedAt,
    this.archivedAt,
    this.lastReadAt,
  });

  final String id;
  final String userId;
  final CommunicationUser? user;
  final String? roleSnapshot;
  final DateTime? joinedAt;
  final DateTime? archivedAt;
  final DateTime? lastReadAt;
}

@immutable
final class CommunicationsConversation {
  const CommunicationsConversation({
    required this.id,
    required this.title,
    this.subject,
    this.conversationType,
    this.status,
    this.isSensitive = false,
    this.archived = false,
    this.unread = false,
    this.lastMessageAt,
    this.createdAt,
    this.targetPath,
    this.participants = const <CommunicationsParticipant>[],
    this.lastMessage,
    this.messages = const <CommunicationMessage>[],
    this.attachmentCount = 0,
  });

  final String id;
  final String title;
  final String? subject;
  final String? conversationType;
  final String? status;
  final bool isSensitive;
  final bool archived;
  final bool unread;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final String? targetPath;
  final List<CommunicationsParticipant> participants;
  final CommunicationMessage? lastMessage;
  final List<CommunicationMessage> messages;
  final int attachmentCount;

  String get preview => lastMessage?.preview ?? '';
}

@immutable
final class NotificationDelivery {
  const NotificationDelivery({
    required this.id,
    this.notificationId,
    this.channel,
    this.status,
    this.recipientTarget,
    this.providerName,
    this.attemptCount = 0,
    this.sentAt,
    this.deliveredAt,
    this.failedAt,
    this.retryable = false,
    this.errorMessage,
    this.targetPath,
    this.notificationTitle,
    this.recipient,
  });

  final String id;
  final String? notificationId;
  final String? channel;
  final String? status;
  final String? recipientTarget;
  final String? providerName;
  final int attemptCount;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? failedAt;
  final bool retryable;
  final String? errorMessage;
  final String? targetPath;
  final String? notificationTitle;
  final CommunicationUser? recipient;
}

@immutable
final class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    this.notificationType,
    this.priority,
    this.message,
    this.targetPath,
    this.contextType,
    this.contextPublicId,
    this.readAt,
    this.createdAt,
    this.updatedAt,
    this.deliveryStatus,
    this.deliveries = const <NotificationDelivery>[],
  });

  final String id;
  final String title;
  final String? notificationType;
  final String? priority;
  final String? message;
  final String? targetPath;
  final String? contextType;
  final String? contextPublicId;
  final DateTime? readAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? deliveryStatus;
  final List<NotificationDelivery> deliveries;

  bool get isRead => readAt != null;

  bool get isUrgent {
    final String normalized = (priority ?? '').trim().toUpperCase();
    return normalized == 'HIGH' || normalized == 'URGENT';
  }

  String? get effectiveDeliveryStatus {
    if (_nonEmpty(deliveryStatus) != null) {
      return deliveryStatus;
    }
    if (deliveries.isEmpty) {
      return null;
    }
    return deliveries.first.status;
  }

  NotificationItem copyWith({DateTime? readAt, bool clearReadAt = false}) {
    return NotificationItem(
      id: id,
      title: title,
      notificationType: notificationType,
      priority: priority,
      message: message,
      targetPath: targetPath,
      contextType: contextType,
      contextPublicId: contextPublicId,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deliveryStatus: deliveryStatus,
      deliveries: deliveries,
    );
  }
}

@immutable
final class CommunicationTemplate {
  const CommunicationTemplate({
    required this.id,
    required this.name,
    this.channel,
    this.subject,
    this.description,
    this.body,
    this.isActive = true,
    this.variableCount = 0,
    this.previewSubject,
    this.previewBody,
  });

  final String id;
  final String name;
  final String? channel;
  final String? subject;
  final String? description;
  final String? body;
  final bool isActive;
  final int variableCount;
  final String? previewSubject;
  final String? previewBody;
}

@immutable
final class CommunicationsWorkspaceState {
  const CommunicationsWorkspaceState({
    required this.query,
    required this.summary,
    required this.metrics,
    required this.conversations,
    required this.notifications,
    required this.deliveries,
    required this.templates,
    this.panels = const <CommunicationsPanelSummary>[],
    this.queueSummaries = const <CommunicationsQueueSummary>[],
    this.selectedConversation,
    this.selectedNotification,
    this.selectedDelivery,
    this.selectedTemplate,
    this.lastFailure,
    this.isRefreshing = false,
    this.isSaving = false,
  });

  final CommunicationsWorkspaceQuery query;
  final CommunicationsSummary summary;
  final NotificationMetrics metrics;
  final List<CommunicationsPanelSummary> panels;
  final List<CommunicationsQueueSummary> queueSummaries;
  final AppPage<CommunicationsConversation> conversations;
  final AppPage<NotificationItem> notifications;
  final AppPage<NotificationDelivery> deliveries;
  final AppPage<CommunicationTemplate> templates;
  final CommunicationsConversation? selectedConversation;
  final NotificationItem? selectedNotification;
  final NotificationDelivery? selectedDelivery;
  final CommunicationTemplate? selectedTemplate;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isSaving;

  int get unreadBadgeCount => summary.unreadThreads + metrics.unread;

  int get workloadCount {
    return summary.unreadThreads +
        metrics.attentionRequired +
        metrics.failedDeliveries;
  }

  CommunicationsWorkspaceState copyWith({
    CommunicationsWorkspaceQuery? query,
    CommunicationsSummary? summary,
    NotificationMetrics? metrics,
    List<CommunicationsPanelSummary>? panels,
    List<CommunicationsQueueSummary>? queueSummaries,
    AppPage<CommunicationsConversation>? conversations,
    AppPage<NotificationItem>? notifications,
    AppPage<NotificationDelivery>? deliveries,
    AppPage<CommunicationTemplate>? templates,
    CommunicationsConversation? selectedConversation,
    NotificationItem? selectedNotification,
    NotificationDelivery? selectedDelivery,
    CommunicationTemplate? selectedTemplate,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isSaving,
    bool clearSelectedConversation = false,
    bool clearSelectedNotification = false,
    bool clearSelectedDelivery = false,
    bool clearSelectedTemplate = false,
    bool clearLastFailure = false,
  }) {
    return CommunicationsWorkspaceState(
      query: query ?? this.query,
      summary: summary ?? this.summary,
      metrics: metrics ?? this.metrics,
      panels: panels ?? this.panels,
      queueSummaries: queueSummaries ?? this.queueSummaries,
      conversations: conversations ?? this.conversations,
      notifications: notifications ?? this.notifications,
      deliveries: deliveries ?? this.deliveries,
      templates: templates ?? this.templates,
      selectedConversation: clearSelectedConversation
          ? null
          : selectedConversation ?? this.selectedConversation,
      selectedNotification: clearSelectedNotification
          ? null
          : selectedNotification ?? this.selectedNotification,
      selectedDelivery: clearSelectedDelivery
          ? null
          : selectedDelivery ?? this.selectedDelivery,
      selectedTemplate: clearSelectedTemplate
          ? null
          : selectedTemplate ?? this.selectedTemplate,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

@immutable
final class CommunicationMessageDraft {
  const CommunicationMessageDraft({
    required this.content,
    this.replyToMessageId,
  });

  final String content;
  final String? replyToMessageId;
}

@immutable
final class CommunicationConversationDraft {
  const CommunicationConversationDraft({
    required this.participantIds,
    this.subject,
    this.isSensitive = false,
    this.conversationType,
  });

  final List<String> participantIds;
  final String? subject;
  final bool isSensitive;
  final String? conversationType;
}

bool _boolParam(String? value) {
  final String normalized = (value ?? '').trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

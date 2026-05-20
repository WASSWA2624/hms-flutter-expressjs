import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef CommunicationsJsonMap = Map<String, Object?>;

final class CommunicationsWorkspaceDto {
  const CommunicationsWorkspaceDto({required this.state});

  final CommunicationsWorkspaceState state;

  factory CommunicationsWorkspaceDto.fromResponse(
    Object? responseData,
    CommunicationsWorkspaceQuery query,
    NotificationMetrics metrics,
  ) {
    final CommunicationsJsonMap data = _dataMap(responseData);
    final CommunicationsJsonMap pagination = _map(data['pagination']);
    final CommunicationsJsonMap totals = _map(pagination['totals']);
    final AppPageRequest request = query.pageRequest;
    final List<CommunicationsConversation> conversations = _list(
      data['conversations'],
    )
        .map(CommunicationsConversationDto.new)
        .map((CommunicationsConversationDto dto) => dto.toEntity())
        .where((CommunicationsConversation item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<NotificationItem> notifications = _list(data['notifications'])
        .map(NotificationItemDto.new)
        .map((NotificationItemDto dto) => dto.toEntity())
        .where((NotificationItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<NotificationDelivery> deliveries = _list(data['deliveries'])
        .map(NotificationDeliveryDto.new)
        .map((NotificationDeliveryDto dto) => dto.toEntity())
        .where((NotificationDelivery item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<CommunicationTemplate> templates = _list(data['templates'])
        .map(CommunicationTemplateDto.new)
        .map((CommunicationTemplateDto dto) => dto.toEntity())
        .where((CommunicationTemplate item) => item.id.isNotEmpty)
        .toList(growable: false);
    final CommunicationsConversation? activeConversation =
        _map(data['active_conversation']).isEmpty
        ? null
        : CommunicationsConversationDto(
            _map(data['active_conversation']),
          ).toEntity();

    return CommunicationsWorkspaceDto(
      state: CommunicationsWorkspaceState(
        query: query,
        summary: CommunicationsSummaryDto(_list(data['summary'])).toEntity(),
        metrics: metrics,
        panels: _list(data['panels'])
            .map(CommunicationsPanelSummaryDto.new)
            .map((CommunicationsPanelSummaryDto dto) => dto.toEntity())
            .toList(growable: false),
        queueSummaries: _list(data['queue_summaries'])
            .map(CommunicationsQueueSummaryDto.new)
            .map((CommunicationsQueueSummaryDto dto) => dto.toEntity())
            .toList(growable: false),
        conversations: AppPage<CommunicationsConversation>(
          items: conversations,
          request: request,
          totalItemCount: _int(totals['conversations']) ?? conversations.length,
        ),
        notifications: AppPage<NotificationItem>(
          items: notifications,
          request: request,
          totalItemCount: _int(totals['notifications']) ?? notifications.length,
        ),
        deliveries: AppPage<NotificationDelivery>(
          items: deliveries,
          request: request,
          totalItemCount: _int(totals['deliveries']) ?? deliveries.length,
        ),
        templates: AppPage<CommunicationTemplate>(
          items: templates,
          request: request,
          totalItemCount: _int(totals['templates']) ?? templates.length,
        ),
        selectedConversation:
            activeConversation ??
            _selectConversation(conversations, query.conversationId),
        selectedNotification: _selectNotification(
          notifications,
          query.notificationId,
        ),
        selectedDelivery: deliveries.firstOrNull,
        selectedTemplate: _selectTemplate(templates, query.templateId),
      ),
    );
  }
}

final class CommunicationsSummaryDto {
  const CommunicationsSummaryDto(this.rows);

  final List<CommunicationsJsonMap> rows;

  CommunicationsSummary toEntity() {
    int valueFor(String id) {
      for (final CommunicationsJsonMap row in rows) {
        if ((_string(row['id']) ?? '').trim().toLowerCase() == id) {
          return _int(row['value']) ?? 0;
        }
      }
      return 0;
    }

    return CommunicationsSummary(
      unreadThreads: valueFor('unread'),
      archivedThreads: valueFor('archived'),
      notifications: valueFor('notifications'),
      failedDeliveries: valueFor('failed_deliveries'),
      templates: valueFor('templates'),
    );
  }
}

final class NotificationMetricsDto {
  const NotificationMetricsDto(this.json);

  final CommunicationsJsonMap json;

  factory NotificationMetricsDto.fromResponse(Object? responseData) {
    return NotificationMetricsDto(_dataMap(responseData));
  }

  NotificationMetrics toEntity() {
    return NotificationMetrics(
      total: _int(json['total']) ?? 0,
      unread: _int(json['unread']) ?? 0,
      read: _int(json['read']) ?? 0,
      attentionRequired: _int(json['attention_required']) ?? 0,
      failedDeliveries: _int(json['failed_deliveries']) ?? 0,
      retryableDeliveries: _int(json['retryable_deliveries']) ?? 0,
      lastReceivedAt: _date(json['last_received_at']),
    );
  }
}

final class CommunicationsPanelSummaryDto {
  const CommunicationsPanelSummaryDto(this.json);

  final CommunicationsJsonMap json;

  CommunicationsPanelSummary toEntity() {
    return CommunicationsPanelSummary(
      id: _string(json['id']),
      labelKey: _string(json['label_key']),
      panel: CommunicationsPanel.fromServer(_string(json['id'])),
      count: _int(json['count']) ?? 0,
    );
  }
}

final class CommunicationsQueueSummaryDto {
  const CommunicationsQueueSummaryDto(this.json);

  final CommunicationsJsonMap json;

  CommunicationsQueueSummary toEntity() {
    return CommunicationsQueueSummary(
      id: _string(json['id']) ?? '',
      label: _string(json['label']) ?? '',
      count: _int(json['count']) ?? 0,
      panel: CommunicationsPanel.fromServer(_string(json['panel'])),
      filter: _string(json['filter']),
    );
  }
}

final class CommunicationUserDto {
  const CommunicationUserDto(this.json);

  final CommunicationsJsonMap json;

  CommunicationUser toEntity() {
    return CommunicationUser(
      id: _firstString(<Object?>[json['id'], json['user_id']]),
      name: _string(json['name']) ?? _string(json['label']),
      email: _string(json['email']),
      positionTitle: _string(json['position_title']),
      initials: _string(json['initials']),
      roles: _stringList(json['roles']),
    );
  }
}

final class CommunicationAttachmentDto {
  const CommunicationAttachmentDto(this.json);

  final CommunicationsJsonMap json;

  CommunicationAttachment toEntity() {
    return CommunicationAttachment(
      id: _firstString(<Object?>[json['id'], json['display_id']]),
      fileName: _string(json['file_name']) ?? '',
      contentType: _string(json['content_type']),
      sizeBytes: _int(json['size_bytes']) ?? 0,
      attachmentKind: _string(json['attachment_kind']),
      publicUrl: _string(json['public_url']),
      createdAt: _date(json['created_at']),
    );
  }
}

final class CommunicationMessageDto {
  const CommunicationMessageDto(this.json);

  final CommunicationsJsonMap json;

  CommunicationMessage toEntity() {
    final CommunicationsJsonMap reply = _map(json['reply_to_message']);
    return CommunicationMessage(
      id: _firstString(<Object?>[json['id'], json['display_id']]),
      conversationId: _string(json['conversation_id']),
      senderUserId: _string(json['sender_user_id']),
      sender: _map(json['sender']).isEmpty
          ? null
          : CommunicationUserDto(_map(json['sender'])).toEntity(),
      content: _string(json['content']),
      messageType: _string(json['message_type']),
      sentAt: _date(json['sent_at']),
      editedAt: _date(json['edited_at']),
      replyToMessageId: _string(json['reply_to_message_id']),
      replyToMessage: reply.isEmpty
          ? null
          : CommunicationMessageDto(reply).toEntity(),
      attachments: _list(json['attachments'])
          .map(CommunicationAttachmentDto.new)
          .map((CommunicationAttachmentDto dto) => dto.toEntity())
          .where((CommunicationAttachment item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class CommunicationsParticipantDto {
  const CommunicationsParticipantDto(this.json);

  final CommunicationsJsonMap json;

  CommunicationsParticipant toEntity() {
    return CommunicationsParticipant(
      id: _firstString(<Object?>[json['id'], json['display_id']]),
      userId: _string(json['user_id']) ?? '',
      roleSnapshot: _string(json['role_snapshot']),
      joinedAt: _date(json['joined_at']),
      archivedAt: _date(json['archived_at']),
      lastReadAt: _date(json['last_read_at']),
      user: _map(json['user']).isEmpty
          ? null
          : CommunicationUserDto(_map(json['user'])).toEntity(),
    );
  }
}

final class CommunicationsConversationDto {
  const CommunicationsConversationDto(this.json);

  final CommunicationsJsonMap json;

  factory CommunicationsConversationDto.fromResponse(Object? responseData) {
    return CommunicationsConversationDto(_dataMap(responseData));
  }

  CommunicationsConversation toEntity() {
    return CommunicationsConversation(
      id: _firstString(<Object?>[json['id'], json['display_id']]),
      title:
          _string(json['title']) ??
          _string(json['subject']) ??
          _string(json['id']) ??
          '',
      subject: _string(json['subject']),
      conversationType: _string(json['conversation_type']),
      status: _string(json['status']),
      isSensitive: _bool(json['is_sensitive']),
      archived: _bool(json['archived']),
      unread: _bool(json['unread']),
      lastMessageAt: _date(json['last_message_at']),
      createdAt: _date(json['created_at']),
      targetPath: _string(json['target_path']),
      participants: _list(json['participants'])
          .map(CommunicationsParticipantDto.new)
          .map((CommunicationsParticipantDto dto) => dto.toEntity())
          .where((CommunicationsParticipant item) => item.id.isNotEmpty)
          .toList(growable: false),
      lastMessage: _map(json['last_message']).isEmpty
          ? null
          : CommunicationMessageDto(_map(json['last_message'])).toEntity(),
      messages: _list(json['messages'])
          .map(CommunicationMessageDto.new)
          .map((CommunicationMessageDto dto) => dto.toEntity())
          .where((CommunicationMessage item) => item.id.isNotEmpty)
          .toList(growable: false),
      attachmentCount: _int(json['attachment_count']) ?? 0,
    );
  }
}

final class NotificationDeliveryDto {
  const NotificationDeliveryDto(this.json);

  final CommunicationsJsonMap json;

  NotificationDelivery toEntity() {
    return NotificationDelivery(
      id: _firstString(<Object?>[json['id'], json['display_id']]),
      notificationId: _string(json['notification_id']),
      channel: _string(json['channel']),
      status: _string(json['status']),
      recipientTarget: _string(json['recipient_target']),
      providerName: _string(json['provider_name']),
      attemptCount: _int(json['attempt_count']) ?? 0,
      sentAt: _date(json['sent_at']),
      deliveredAt: _date(json['delivered_at']),
      failedAt: _date(json['failed_at']),
      retryable: _bool(json['retryable']),
      errorMessage: _string(json['error_message']),
      targetPath: _string(json['target_path']),
      notificationTitle: _string(json['notification_title']),
      recipient: _map(json['recipient']).isEmpty
          ? null
          : CommunicationUserDto(_map(json['recipient'])).toEntity(),
    );
  }
}

final class NotificationItemDto {
  const NotificationItemDto(this.json);

  final CommunicationsJsonMap json;

  factory NotificationItemDto.fromResponse(Object? responseData) {
    return NotificationItemDto(_dataMap(responseData));
  }

  NotificationItem toEntity() {
    final CommunicationsJsonMap deliverySummary = _map(
      json['delivery_summary'],
    );
    return NotificationItem(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
      ]),
      title: _string(json['title']) ?? '',
      notificationType: _string(json['notification_type']),
      priority: _string(json['priority']),
      message: _string(json['message']),
      targetPath: _string(json['target_path']),
      contextType: _string(json['context_type']),
      contextPublicId: _string(json['context_public_id']),
      readAt: _date(json['read_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      deliveryStatus: _string(deliverySummary['last_status']),
      deliveries: _list(json['deliveries'])
          .map(NotificationDeliveryDto.new)
          .map((NotificationDeliveryDto dto) => dto.toEntity())
          .where((NotificationDelivery item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class CommunicationTemplateDto {
  const CommunicationTemplateDto(this.json);

  final CommunicationsJsonMap json;

  CommunicationTemplate toEntity() {
    final CommunicationsJsonMap preview = _map(json['preview']);
    return CommunicationTemplate(
      id: _firstString(<Object?>[json['id'], json['display_id']]),
      name: _string(json['name']) ?? '',
      channel: _string(json['channel']),
      subject: _string(json['subject']),
      description: _string(json['description']),
      body: _string(json['body']),
      isActive: _bool(json['is_active'], fallback: true),
      variableCount: _int(json['variable_count']) ?? 0,
      previewSubject: _string(preview['subject']),
      previewBody: _string(preview['body']),
    );
  }
}

CommunicationsConversation? _selectConversation(
  List<CommunicationsConversation> conversations,
  String? id,
) {
  if (id != null) {
    for (final CommunicationsConversation item in conversations) {
      if (item.id == id) {
        return item;
      }
    }
  }
  return conversations.firstOrNull;
}

NotificationItem? _selectNotification(
  List<NotificationItem> notifications,
  String? id,
) {
  if (id != null) {
    for (final NotificationItem item in notifications) {
      if (item.id == id) {
        return item;
      }
    }
  }
  return notifications.firstOrNull;
}

CommunicationTemplate? _selectTemplate(
  List<CommunicationTemplate> templates,
  String? id,
) {
  if (id != null) {
    for (final CommunicationTemplate item in templates) {
      if (item.id == id) {
        return item;
      }
    }
  }
  return templates.firstOrNull;
}

CommunicationsJsonMap _dataMap(Object? responseData) {
  final CommunicationsJsonMap response = _map(responseData);
  final CommunicationsJsonMap data = _map(response['data']);
  return data.isNotEmpty ? data : response;
}

CommunicationsJsonMap _map(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>((Object? key, Object? value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }
  return <String, Object?>{};
}

List<CommunicationsJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <CommunicationsJsonMap>[];
  }
  return value
      .map(_map)
      .where((CommunicationsJsonMap item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! Iterable<Object?>) {
    return const <String>[];
  }
  return value
      .map(_string)
      .whereType<String>()
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

String _firstString(Iterable<Object?> values) {
  for (final Object? value in values) {
    final String? normalized = _string(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return '';
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (<String>['true', '1', 'yes', 'on'].contains(normalized)) {
      return true;
    }
    if (<String>['false', '0', 'no', 'off'].contains(normalized)) {
      return false;
    }
  }
  return fallback;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}

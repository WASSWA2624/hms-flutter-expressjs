import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/communications/data/dtos/communications_dtos.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/domain/repositories/communications_repository.dart';

final communicationsRepositoryProvider = Provider<CommunicationsRepository>((
  ref,
) {
  return CommunicationsRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class CommunicationsRepositoryImpl implements CommunicationsRepository {
  const CommunicationsRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<CommunicationsWorkspaceState>> getWorkspace(
    CommunicationsWorkspaceQuery query,
  ) async {
    final Result<NotificationMetrics> metricsResult =
        await getNotificationMetrics();
    return metricsResult.when<Future<Result<CommunicationsWorkspaceState>>>(
      success: (NotificationMetrics metrics) {
        return _apiClient.get<CommunicationsWorkspaceState>(
          ApiEndpoints.nested(
            HmsApiResource.communicationsWorkspace,
            'workspace',
            const <String>[],
          ),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': query.pageRequest.pageIndex + 1,
            'limit': query.pageRequest.pageSize,
            'panel': query.panel.serverValue,
            'search': query.search,
            'filter': query.filter,
            'conversationId': query.conversationId,
            'messageId': query.messageId,
            'notificationId': query.notificationId,
            'templateId': query.templateId,
            'action': query.action,
            'unreadOnly': query.unreadOnly ? 'true' : null,
            'sensitive': query.sensitive ? 'true' : null,
          }),
          decoder: (Object? data) {
            return CommunicationsWorkspaceDto.fromResponse(
              data,
              query,
              metrics,
            ).state;
          },
        );
      },
      failure: (failure) async => Result<CommunicationsWorkspaceState>.failure(
        failure,
      ),
    );
  }

  @override
  Future<Result<NotificationMetrics>> getNotificationMetrics() {
    return _apiClient.get<NotificationMetrics>(
      ApiEndpoints.nested(
        HmsApiResource.notifications,
        'metrics',
        const <String>[],
      ),
      decoder: (Object? data) {
        return NotificationMetricsDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<NotificationItem>> markNotificationRead(String id) {
    return _apiClient.post<NotificationItem>(
      ApiEndpoints.nested(HmsApiResource.notifications, id, const <String>[
        'read',
      ]),
      decoder: (Object? data) => NotificationItemDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<NotificationItem>> markNotificationUnread(String id) {
    return _apiClient.post<NotificationItem>(
      ApiEndpoints.nested(HmsApiResource.notifications, id, const <String>[
        'unread',
      ]),
      decoder: (Object? data) => NotificationItemDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<void>> archiveNotification(String id) {
    return _apiClient.post<void>(
      ApiEndpoints.apiV1(<String>['notifications', 'bulk', 'archive']),
      data: <String, Object?>{
        'ids': <String>[id],
      },
      decoder: (_) {},
    );
  }

  @override
  Future<Result<CommunicationsConversation>> getConversation(String id) {
    return _apiClient.get<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[id],
      ),
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> markConversationRead(String id) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[id, 'read'],
      ),
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> archiveConversation(String id) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[id, 'archive'],
      ),
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> unarchiveConversation(String id) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[id, 'unarchive'],
      ),
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> sendMessage(
    String conversationId,
    CommunicationMessageDraft draft,
  ) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[conversationId, 'messages'],
      ),
      data: _withoutEmpty(<String, Object?>{
        'content': draft.content,
        'reply_to_message_id': draft.replyToMessageId,
      }),
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> createConversation(
    CommunicationConversationDraft draft,
  ) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        const <String>[],
      ),
      data: _withoutEmpty(<String, Object?>{
        'participant_ids': draft.participantIds,
        'subject': draft.subject,
        'is_sensitive': draft.isSensitive,
        'conversation_type': draft.conversationType,
      }),
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }
}

Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPayloadValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPayloadValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable) {
    return value.isEmpty;
  }
  if (value is Map) {
    return value.isEmpty;
  }
  return false;
}

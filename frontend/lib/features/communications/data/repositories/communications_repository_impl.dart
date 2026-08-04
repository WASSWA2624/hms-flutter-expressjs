import 'package:dio/dio.dart';
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
      failure: (failure) async =>
          Result<CommunicationsWorkspaceState>.failure(failure),
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
      decoder: (Object? data) =>
          NotificationItemDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<NotificationItem>> markNotificationUnread(String id) {
    return _apiClient.post<NotificationItem>(
      ApiEndpoints.nested(HmsApiResource.notifications, id, const <String>[
        'unread',
      ]),
      decoder: (Object? data) =>
          NotificationItemDto.fromResponse(data).toEntity(),
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
    final bool hasAttachments = draft.attachments.isNotEmpty;
    final Object payload = hasAttachments
        ? _messageFormData(draft)
        : _withoutEmpty(<String, Object?>{
            'content': draft.content,
            'reply_to_message_id': draft.replyToMessageId,
            'mentioned_user_ids': draft.mentionedUserIds.isEmpty
                ? null
                : draft.mentionedUserIds,
          });

    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[conversationId, 'messages'],
      ),
      data: payload,
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  FormData _messageFormData(CommunicationMessageDraft draft) {
    final FormData formData = FormData();
    final String content = draft.content.trim();
    if (content.isNotEmpty) {
      formData.fields.add(MapEntry<String, String>('content', content));
    }
    if (draft.replyToMessageId != null &&
        draft.replyToMessageId!.trim().isNotEmpty) {
      formData.fields.add(
        MapEntry<String, String>(
          'reply_to_message_id',
          draft.replyToMessageId!.trim(),
        ),
      );
    }
    for (final String userId in draft.mentionedUserIds) {
      formData.fields.add(
        MapEntry<String, String>('mentioned_user_ids', userId),
      );
    }
    for (final CommunicationAttachmentUpload attachment in draft.attachments) {
      formData.files.add(
        MapEntry<String, MultipartFile>(
          'attachments',
          MultipartFile.fromBytes(
            attachment.bytes,
            filename: attachment.fileName,
            contentType: attachment.contentType == null
                ? null
                : DioMediaType.parse(attachment.contentType!),
          ),
        ),
      );
    }
    return formData;
  }

  @override
  Future<Result<List<CommunicationStaffOption>>> getReferenceStaff({
    String search = '',
  }) {
    return _apiClient.get<List<CommunicationStaffOption>>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'reference-data',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{'search': search}),
      decoder: (Object? data) {
        final CommunicationsJsonMap map = _responseMap(data);
        return _list(map['users'])
            .map((Object? item) => CommunicationStaffOptionDto(item).toEntity())
            .where((CommunicationStaffOption item) => item.id.isNotEmpty)
            .toList(growable: false);
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> addParticipant(
    String conversationId,
    String userId,
  ) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[conversationId, 'participants'],
      ),
      data: <String, Object?>{'user_id': userId},
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> removeParticipant(
    String conversationId,
    String participantId,
  ) {
    return _apiClient.delete<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[conversationId, 'participants', participantId],
      ),
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> toggleConversationFavorite(
    String id,
  ) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[id, 'favorite'],
      ),
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> toggleConversationFlag(String id) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[id, 'flag'],
      ),
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
        'visibility_roles': draft.visibilityRoles.isEmpty
            ? null
            : draft.visibilityRoles,
        'initial_message': draft.initialMessage,
      }),
      decoder: (Object? data) {
        return CommunicationsConversationDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<List<CommunicationRoleOption>>> getReferenceRoles() {
    return _apiClient.get<List<CommunicationRoleOption>>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'reference-data',
        const <String>[],
      ),
      decoder: (Object? data) {
        final CommunicationsJsonMap map = _responseMap(data);
        return _list(map['roles'])
            .map((Object? item) {
              if (item is! Map) {
                return const CommunicationRoleOption(
                  id: '',
                  label: '',
                  code: '',
                );
              }
              final Map<String, Object?> roleMap = item.map(
                (Object? key, Object? value) =>
                    MapEntry<String, Object?>(key.toString(), value),
              );
              final String code =
                  (roleMap['code'] ?? roleMap['id'] ?? '').toString().trim();
              final String label =
                  (roleMap['label'] ?? code).toString().trim();
              return CommunicationRoleOption(
                id: code,
                label: label,
                code: code,
              );
            })
            .where((CommunicationRoleOption item) => item.code.isNotEmpty)
            .toList(growable: false);
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> startCall(
    String conversationId, {
    required String kind,
  }) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[conversationId, 'calls'],
      ),
      data: <String, Object?>{'kind': kind},
      decoder: (Object? data) {
        final CommunicationsJsonMap map = _responseMap(data);
        final Object? conversation = map['conversation'] ?? data;
        return CommunicationsConversationDto.fromResponse(
          conversation,
        ).toEntity();
      },
    );
  }

  @override
  Future<Result<CommunicationsConversation>> updateCall(
    String conversationId, {
    required String callId,
    required String action,
  }) {
    return _apiClient.post<CommunicationsConversation>(
      ApiEndpoints.nested(
        HmsApiResource.communicationsWorkspace,
        'conversations',
        <String>[conversationId, 'calls', 'update'],
      ),
      data: <String, Object?>{'call_id': callId, 'action': action},
      decoder: (Object? data) {
        final CommunicationsJsonMap map = _responseMap(data);
        final Object? conversation = map['conversation'] ?? data;
        return CommunicationsConversationDto.fromResponse(
          conversation,
        ).toEntity();
      },
    );
  }
}

CommunicationsJsonMap _responseMap(Object? responseData) {
  if (responseData is Map) {
    final Map<String, Object?> map = responseData.map<String, Object?>(
      (Object? key, Object? value) =>
          MapEntry<String, Object?>(key.toString(), value),
    );
    final Object? data = map['data'];
    if (data is Map) {
      return data.map<String, Object?>(
        (Object? key, Object? value) =>
            MapEntry<String, Object?>(key.toString(), value),
      );
    }
    return map;
  }
  return <String, Object?>{};
}

List<Object?> _list(Object? value) {
  if (value is List) {
    return value;
  }
  return const <Object?>[];
}

final class CommunicationStaffOptionDto {
  const CommunicationStaffOptionDto(this.json);

  final Object? json;

  CommunicationStaffOption toEntity() {
    if (json is! Map) {
      return const CommunicationStaffOption(id: '', label: '');
    }
    final Map<Object?, Object?> rawMap = json! as Map<Object?, Object?>;
    final CommunicationsJsonMap map = rawMap.map<String, Object?>(
      (Object? key, Object? value) =>
          MapEntry<String, Object?>(key.toString(), value),
    );
    return CommunicationStaffOption(
      id: _string(map['id']) ?? '',
      label: _string(map['label']) ?? _string(map['id']) ?? '',
      email: _string(map['email']),
      positionTitle: _string(map['position_title']),
      roles: _list(map['roles'])
          .map((Object? item) => item?.toString() ?? '')
          .where((String item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }

  String? _string(Object? value) {
    final String? normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
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

import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';

abstract interface class CommunicationsRepository {
  Future<Result<CommunicationsWorkspaceState>> getWorkspace(
    CommunicationsWorkspaceQuery query,
  );

  Future<Result<NotificationMetrics>> getNotificationMetrics();

  Future<Result<NotificationItem>> markNotificationRead(String id);

  Future<Result<NotificationItem>> markNotificationUnread(String id);

  Future<Result<void>> archiveNotification(String id);

  Future<Result<CommunicationsConversation>> getConversation(String id);

  Future<Result<CommunicationsConversation>> markConversationRead(String id);

  Future<Result<CommunicationsConversation>> archiveConversation(String id);

  Future<Result<CommunicationsConversation>> unarchiveConversation(String id);

  Future<Result<CommunicationsConversation>> sendMessage(
    String conversationId,
    CommunicationMessageDraft draft,
  );

  Future<Result<CommunicationsConversation>> createConversation(
    CommunicationConversationDraft draft,
  );
}

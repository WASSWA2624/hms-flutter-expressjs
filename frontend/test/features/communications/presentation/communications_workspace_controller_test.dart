import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/communications/data/repositories/communications_repository_impl.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/domain/repositories/communications_repository.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockCommunicationsRepository extends Mock
    implements CommunicationsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const CommunicationsWorkspaceQuery());
    registerFallbackValue(const CommunicationMessageDraft(content: 'Message'));
    registerFallbackValue(
      const CommunicationConversationDraft(participantIds: <String>['user-1']),
    );
  });

  group('CommunicationsWorkspaceController', () {
    test('loads workspace and exposes unread badge count', () async {
      final _MockCommunicationsRepository repository =
          _MockCommunicationsRepository();
      _stubWorkspace(repository);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          communicationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final Result<CommunicationsWorkspaceState> result = await container.read(
        communicationsWorkspaceControllerProvider.future,
      );

      final CommunicationsWorkspaceState state = result.when(
        success: (CommunicationsWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );
      expect(state.notifications.items.single.id, 'notification-1');
      expect(state.selectedNotification?.id, 'notification-1');
      expect(state.unreadBadgeCount, 3);
      verify(() => repository.getWorkspace(any())).called(1);
    });

    test('marks notification read without reloading the workspace', () async {
      final _MockCommunicationsRepository repository =
          _MockCommunicationsRepository();
      final DateTime readAt = DateTime.utc(2026, 5, 20, 9);
      _stubWorkspace(repository);
      when(() => repository.markNotificationRead('notification-1')).thenAnswer(
        (_) async =>
            Result<NotificationItem>.success(_notification(readAt: readAt)),
      );
      when(() => repository.getNotificationMetrics()).thenAnswer(
        (_) async => const Result<NotificationMetrics>.success(
          NotificationMetrics(read: 1),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          communicationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(communicationsWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(communicationsWorkspaceControllerProvider.notifier)
          .markSelectedNotificationRead();

      final CommunicationsWorkspaceState state = container
          .read(communicationsWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (CommunicationsWorkspaceState value) => value,
            failure: (AppFailure failure) => fail(failure.code),
          );
      expect(failure, isNull);
      expect(state.selectedNotification?.isRead, isTrue);
      expect(state.notifications.items.single.isRead, isTrue);
      expect(state.metrics.unread, 0);
      verify(() => repository.markNotificationRead('notification-1')).called(1);
      verify(() => repository.getNotificationMetrics()).called(1);
      verify(() => repository.getWorkspace(any())).called(1);
    });
  });
}

void _stubWorkspace(_MockCommunicationsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
    final CommunicationsWorkspaceQuery query =
        invocation.positionalArguments.single as CommunicationsWorkspaceQuery;
    final NotificationItem notification = _notification();
    return Result<CommunicationsWorkspaceState>.success(
      CommunicationsWorkspaceState(
        query: query,
        summary: const CommunicationsSummary(
          unreadThreads: 2,
          notifications: 1,
          failedDeliveries: 1,
        ),
        metrics: const NotificationMetrics(
          total: 1,
          unread: 1,
          attentionRequired: 1,
          failedDeliveries: 1,
        ),
        conversations: AppPage<CommunicationsConversation>(
          items: const <CommunicationsConversation>[
            CommunicationsConversation(
              id: 'conversation-1',
              title: 'Critical lab follow-up',
              unread: true,
            ),
          ],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
        notifications: AppPage<NotificationItem>(
          items: <NotificationItem>[notification],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
        deliveries: AppPage<NotificationDelivery>(
          items: const <NotificationDelivery>[
            NotificationDelivery(
              id: 'delivery-1',
              status: 'FAILED',
              notificationTitle: 'Critical lab result',
            ),
          ],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
        templates: AppPage<CommunicationTemplate>(
          items: const <CommunicationTemplate>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        selectedNotification: notification,
      ),
    );
  });
}

NotificationItem _notification({DateTime? readAt}) {
  return NotificationItem(
    id: 'notification-1',
    title: 'Critical lab result',
    priority: 'HIGH',
    readAt: readAt,
    deliveryStatus: 'FAILED',
  );
}

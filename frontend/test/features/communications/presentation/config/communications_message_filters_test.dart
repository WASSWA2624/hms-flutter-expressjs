import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/config/communications_message_filters.dart';

void main() {
  test('sent filter keeps threads last sent by current user', () {
    final List<CommunicationsConversation> conversations =
        <CommunicationsConversation>[
          const CommunicationsConversation(
            id: '1',
            title: 'Mine',
            lastMessage: CommunicationMessage(
              id: 'm1',
              senderUserId: 'user-1',
              content: 'Hi',
            ),
          ),
          const CommunicationsConversation(
            id: '2',
            title: 'Theirs',
            lastMessage: CommunicationMessage(
              id: 'm2',
              senderUserId: 'user-2',
              content: 'Hello',
            ),
          ),
        ];

    final List<CommunicationsConversation> filtered =
        applyCommunicationsMessageFilter(
          conversations,
          communicationsMessageFilterById(kCommunicationsMessageFilterSent),
          'user-1',
          useClientFallback: true,
        );

    expect(filtered.map((CommunicationsConversation item) => item.id), <String>[
      '1',
    ]);
  });
}

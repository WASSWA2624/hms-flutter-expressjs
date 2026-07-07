import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';

void main() {
  group('listenForRealtimeRefresh', () {
    test('flushes matching realtime events on the next microtask', () async {
      final events = StreamController<RealtimeMessage>.broadcast(sync: true);
      var refreshCount = 0;

      final listenerProvider = Provider<void>((ref) {
        listenForRealtimeRefresh(
          ref: ref,
          events: const <String>{RealtimeEvents.patientUpdated},
          onRefresh: (_) async {
            refreshCount += 1;
          },
        );
      });

      final container = ProviderContainer(
        overrides: [
          realtimeMessagesProvider.overrideWith((ref) => events.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await events.close();
      });

      container.read(listenerProvider);
      final subscription = container.listen<AsyncValue<RealtimeMessage>>(
        realtimeMessagesProvider,
        (_, _) {},
      );
      await Future<void>.microtask(() {});

      events.add(const RealtimeMessage(event: RealtimeEvents.patientUpdated));

      expect(refreshCount, 0);
      await Future<void>.microtask(() {});
      expect(refreshCount, 1);
      subscription.close();
    });
  });
}

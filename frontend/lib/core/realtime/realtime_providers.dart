import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_service.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final RealtimeService service = RealtimeService(
    config: ref.watch(appConfigProvider),
  );
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final realtimeMessagesProvider = StreamProvider<RealtimeMessage>((ref) {
  final String? accessToken = ref.watch(
    sessionStateProvider.select((SessionState state) {
      if (!state.isAuthenticated) {
        return null;
      }
      return state.session?.tokens.accessToken;
    }),
  );

  final RealtimeService service = ref.watch(realtimeServiceProvider);
  if (accessToken == null || accessToken.trim().isEmpty) {
    unawaited(service.disconnect());
    return const Stream<RealtimeMessage>.empty();
  }

  unawaited(service.connect(accessToken));
  ref.onDispose(() {
    unawaited(service.disconnect());
  });
  return service.messages;
});

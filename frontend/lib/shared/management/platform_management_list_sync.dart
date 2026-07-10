import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_providers.dart';

typedef PlatformManagementReload =
    Future<void> Function({bool silent, RealtimeMessage? message});

/// Keeps a platform management list dialog aligned with websocket mutations.
final class PlatformManagementListSync {
  PlatformManagementListSync({
    required this.ref,
    required this.reload,
    required this.onMutated,
    required this.events,
    this.debounce = const Duration(milliseconds: 200),
  });

  final WidgetRef ref;
  final PlatformManagementReload reload;
  final VoidCallback onMutated;
  final Set<String> events;
  final Duration debounce;

  ProviderSubscription<AsyncValue<RealtimeMessage>>? _subscription;
  Timer? _debounceTimer;

  void attach() {
    _subscription = ref.listenManual<AsyncValue<RealtimeMessage>>(
      realtimeMessagesProvider,
      _onMessage,
    );
  }

  void dispose() {
    _debounceTimer?.cancel();
    _subscription?.close();
  }

  void _onMessage(
    AsyncValue<RealtimeMessage>? previous,
    AsyncValue<RealtimeMessage> next,
  ) {
    if (next case AsyncData<RealtimeMessage>(value: final message)) {
      if (!events.contains(message.event)) {
        return;
      }

      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, () {
        onMutated();
        unawaited(reload(silent: true, message: message));
      });
    }
  }
}

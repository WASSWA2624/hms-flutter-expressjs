import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_providers.dart';

typedef RealtimeRefreshPredicate = bool Function(RealtimeMessage message);
typedef RealtimeRefreshCallback =
    Future<void> Function(RealtimeMessage message);

/// Debounced listener for workspace refreshes triggered by websocket events.
///
/// Controllers keep their own business-specific refresh methods; this helper
/// centralizes websocket subscription, debouncing, and in-flight refresh
/// protection so modules stay responsive during bursts of updates.
void listenForRealtimeRefresh({
  required Ref ref,
  required Iterable<String> events,
  required RealtimeRefreshCallback onRefresh,
  RealtimeRefreshPredicate? shouldRefresh,
  Duration debounce = const Duration(milliseconds: 250),
}) {
  final Set<String> eventSet = Set<String>.unmodifiable(events);
  Timer? debounceTimer;
  RealtimeMessage? pendingMessage;
  bool isRefreshing = false;

  Future<void> runRefresh(RealtimeMessage message) async {
    try {
      await onRefresh(message);
    } catch (_) {
      // Workspace refresh failures are reflected by each controller's state.
      // The listener must not throw into Riverpod's stream subscription.
    }
  }

  void flush() {
    debounceTimer?.cancel();
    debounceTimer = null;

    final RealtimeMessage? message = pendingMessage;
    pendingMessage = null;
    if (message == null) {
      return;
    }

    if (isRefreshing) {
      pendingMessage = message;
      debounceTimer = Timer(debounce, flush);
      return;
    }

    isRefreshing = true;
    unawaited(
      runRefresh(message).whenComplete(() {
        isRefreshing = false;
        if (pendingMessage != null) {
          debounceTimer?.cancel();
          debounceTimer = Timer(debounce, flush);
        }
      }),
    );
  }

  ref.onDispose(() => debounceTimer?.cancel());
  ref.listen<AsyncValue<RealtimeMessage>>(realtimeMessagesProvider, (
    AsyncValue<RealtimeMessage>? previous,
    AsyncValue<RealtimeMessage> next,
  ) {
    if (next case AsyncData<RealtimeMessage>(value: final message)) {
      if (!eventSet.contains(message.event)) {
        return;
      }
      if (shouldRefresh != null && !shouldRefresh(message)) {
        return;
      }
      pendingMessage = message;
      debounceTimer?.cancel();
      debounceTimer = Timer(debounce, flush);
    }
  });
}

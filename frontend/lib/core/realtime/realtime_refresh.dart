import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/realtime/realtime_crud_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_providers.dart';

typedef RealtimeRefreshPredicate = bool Function(RealtimeMessage message);
typedef RealtimeRefreshCallback =
    Future<void> Function(RealtimeMessage message);
typedef RealtimeRefreshDefer = bool Function();

const Duration _deferredRetryDelay = Duration(milliseconds: 50);

/// Realtime listener for workspace refreshes triggered by websocket events.
///
/// Controllers keep their own business-specific refresh methods; this helper
/// centralizes websocket subscription, burst coalescing, and in-flight refresh
/// protection so the first update is reflected immediately while follow-up
/// events during the same refresh are collapsed into one trailing reload.
void listenForRealtimeRefresh({
  required Ref ref,
  required Iterable<String> events,
  required RealtimeRefreshCallback onRefresh,
  RealtimeRefreshPredicate? shouldRefresh,
  RealtimeRefreshDefer? shouldDefer,
  Duration debounce = Duration.zero,
  bool refreshOnReconnect = true,
  bool includeCrudMutations = false,
}) {
  final Set<String> eventSet = Set<String>.unmodifiable(<String>{
    ...events,
    if (refreshOnReconnect) RealtimeEvents.authenticated,
  });
  Timer? trailingTimer;
  RealtimeMessage? pendingMessage;
  bool isRefreshing = false;
  bool disposed = false;
  bool flushScheduled = false;

  Future<void> runRefresh(RealtimeMessage message) async {
    try {
      await onRefresh(message);
    } catch (_) {
      // Workspace refresh failures are reflected by each controller's state.
      // The listener must not throw into Riverpod's stream subscription.
    }
  }

  late void Function({bool deferred}) scheduleFlush;

  void flush() {
    if (disposed) {
      return;
    }

    trailingTimer?.cancel();
    trailingTimer = null;
    flushScheduled = false;

    final RealtimeMessage? message = pendingMessage;
    pendingMessage = null;
    if (message == null) {
      return;
    }

    if (isRefreshing || (shouldDefer?.call() ?? false)) {
      pendingMessage = message;
      scheduleFlush(deferred: true);
      return;
    }

    isRefreshing = true;
    unawaited(
      runRefresh(message).whenComplete(() {
        isRefreshing = false;
        if (!disposed && pendingMessage != null) {
          scheduleFlush();
        }
      }),
    );
  }

  scheduleFlush = ({bool deferred = false}) {
    if (disposed || flushScheduled) {
      return;
    }
    flushScheduled = true;
    final Duration delay = deferred && debounce <= Duration.zero
        ? _deferredRetryDelay
        : debounce;
    if (delay <= Duration.zero) {
      scheduleMicrotask(flush);
      return;
    }
    trailingTimer = Timer(delay, flush);
  };

  ref.onDispose(() {
    disposed = true;
    trailingTimer?.cancel();
  });
  ref.listen<AsyncValue<RealtimeMessage>>(realtimeMessagesProvider, (
    AsyncValue<RealtimeMessage>? previous,
    AsyncValue<RealtimeMessage> next,
  ) {
    if (next case AsyncData<RealtimeMessage>(value: final message)) {
      final bool matchesNamedEvent = eventSet.contains(message.event);
      final bool matchesCrudEvent =
          includeCrudMutations && RealtimeCrudEvents.matches(message.event);
      if (!matchesNamedEvent && !matchesCrudEvent) {
        return;
      }
      if (message.event != RealtimeEvents.authenticated &&
          shouldRefresh != null &&
          !shouldRefresh(message)) {
        return;
      }
      pendingMessage = message;
      scheduleFlush();
    }
  });
}

import 'dart:async';

/// Starts periodic sync only while realtime transport is unavailable.
///
/// When WebSocket is connected, polling is stopped so refreshes are driven by
/// targeted realtime handlers instead of redundant full sync timers.
final class WorkspaceAdaptivePolling {
  Timer? _timer;
  void Function({required bool immediate})? _schedule;

  void start({
    required Duration intervalWhenDisconnected,
    required bool Function() isRealtimeConnected,
    required void Function() onTick,
  }) {
    _timer?.cancel();
    _timer = null;

    void schedule({required bool immediate}) {
      _timer?.cancel();
      if (isRealtimeConnected()) {
        return;
      }

      if (immediate) {
        onTick();
      }
      _timer = Timer.periodic(intervalWhenDisconnected, (_) => onTick());
    }

    _schedule = schedule;
    schedule(immediate: false);
  }

  void onConnectionStateChanged() {
    _schedule?.call(immediate: true);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _schedule = null;
  }
}

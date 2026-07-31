import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the shell should show the global navigation loading bar.
final shellNavigationLoadingProvider =
    NotifierProvider<ShellNavigationLoadingController, bool>(
      ShellNavigationLoadingController.new,
    );

class ShellNavigationLoadingController extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool loading) {
    if (state != loading) {
      state = loading;
    }
  }

  void clearLoadingIfMounted() {
    if (!ref.mounted) {
      return;
    }
    // Deferred so it is safe to call from a widget's dispose(), which runs
    // during tree finalization where synchronous provider mutation is illegal.
    Future<void>.microtask(() {
      if (!ref.mounted) {
        return;
      }
      setLoading(false);
    });
  }
}

/// Enables [AsyncStateScaffold] to defer full-page loading UI to the shell bar.
class ShellNavigationScope extends InheritedWidget {
  const ShellNavigationScope({
    required this.deferLoadingToShell,
    required super.child,
    super.key,
  });

  final bool deferLoadingToShell;

  static bool deferLoadingToShellOf(BuildContext context) {
    return context
            .getInheritedWidgetOfExactType<ShellNavigationScope>()
            ?.deferLoadingToShell ??
        false;
  }

  @override
  bool updateShouldNotify(ShellNavigationScope oldWidget) {
    return deferLoadingToShell != oldWidget.deferLoadingToShell;
  }
}

/// Thin indeterminate bar pinned below [AppMenuBar] during shell navigation.
class AppShellLoadingBar extends StatelessWidget {
  const AppShellLoadingBar({required this.visible, super.key});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: SizedBox(
        height: 2,
        width: double.infinity,
        child: disableAnimations
            ? ColoredBox(color: colorScheme.primary)
            : LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
              ),
      ),
    );
  }
}

/// Keeps the previous route visible while the destination workspace loads.
///
/// On route change the previous child stays painted while the destination
/// mounts offstage (so it can fetch and report loading). The pending route is
/// committed when shell loading finishes, or after a short settle delay when
/// the destination never reports shell loading—never on the same frame as the
/// route swap, which previously flashed a blank deferred-loading child.
class ShellRouteChildRetention extends StatefulWidget {
  const ShellRouteChildRetention({
    required this.routeKey,
    required this.isLoading,
    required this.child,
    super.key,
  });

  final String routeKey;
  final bool isLoading;
  final Widget child;

  @override
  State<ShellRouteChildRetention> createState() =>
      _ShellRouteChildRetentionState();
}

class _ShellRouteChildRetentionState extends State<ShellRouteChildRetention> {
  String? _visibleRouteKey;
  Widget? _visibleChild;
  String? _pendingRouteKey;
  bool _sawLoadingForPending = false;
  int _pendingGeneration = 0;
  Timer? _neverLoadedCommitTimer;

  @override
  void initState() {
    super.initState();
    _visibleRouteKey = widget.routeKey;
    _visibleChild = widget.child;
  }

  @override
  void dispose() {
    _neverLoadedCommitTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ShellRouteChildRetention oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.routeKey != oldWidget.routeKey) {
      _pendingRouteKey = widget.routeKey;
      _sawLoadingForPending = widget.isLoading;
      _pendingGeneration += 1;
      final int generation = _pendingGeneration;
      if (_sawLoadingForPending) {
        _cancelNeverLoadedCommit();
      } else {
        _scheduleCommitIfNeverLoaded(generation);
      }
      return;
    }

    if (_pendingRouteKey == null) {
      if (widget.routeKey == _visibleRouteKey) {
        _visibleChild = widget.child;
      }
      return;
    }

    if (widget.isLoading) {
      _sawLoadingForPending = true;
      _cancelNeverLoadedCommit();
      return;
    }

    if (_sawLoadingForPending) {
      _commitPending();
    }
  }

  void _cancelNeverLoadedCommit() {
    _neverLoadedCommitTimer?.cancel();
    _neverLoadedCommitTimer = null;
  }

  void _scheduleCommitIfNeverLoaded(int generation) {
    _cancelNeverLoadedCommit();
    // Two zero-delay ticks so [ShellLoadingReporter] can mark loading after
    // the destination mounts. Destinations that never report then commit.
    _neverLoadedCommitTimer = Timer(Duration.zero, () {
      _neverLoadedCommitTimer = Timer(Duration.zero, () {
        _neverLoadedCommitTimer = null;
        if (!mounted || generation != _pendingGeneration) {
          return;
        }
        _commitIfPendingNeverLoaded();
      });
    });
  }

  void _commitIfPendingNeverLoaded() {
    if (_pendingRouteKey == null || _sawLoadingForPending) {
      return;
    }
    if (widget.routeKey != _pendingRouteKey || widget.isLoading) {
      return;
    }
    _commitPending();
  }

  void _commitPending() {
    _cancelNeverLoadedCommit();
    setState(() {
      _visibleRouteKey = widget.routeKey;
      _visibleChild = widget.child;
      _pendingRouteKey = null;
      _sawLoadingForPending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool retainPrevious =
        _pendingRouteKey != null && _visibleChild != null;

    if (!retainPrevious) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _visibleChild!,
        Offstage(
          child: TickerMode(enabled: true, child: widget.child),
        ),
      ],
    );
  }
}

/// Reports workspace initial-load state to [shellNavigationLoadingProvider].
class ShellLoadingReporter extends ConsumerStatefulWidget {
  const ShellLoadingReporter({
    required this.isLoading,
    required this.child,
    super.key,
  });

  final bool isLoading;
  final Widget child;

  @override
  ConsumerState<ShellLoadingReporter> createState() =>
      _ShellLoadingReporterState();
}

class _ShellLoadingReporterState extends ConsumerState<ShellLoadingReporter> {
  ShellNavigationLoadingController? _loadingController;

  @override
  void initState() {
    super.initState();
    _loadingController = ref.read(shellNavigationLoadingProvider.notifier);
    _syncLoading();
  }

  @override
  void didUpdateWidget(ShellLoadingReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      _syncLoading();
    }
  }

  @override
  void dispose() {
    _loadingController?.clearLoadingIfMounted();
    super.dispose();
  }

  void _syncLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadingController?.setLoading(widget.isLoading);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

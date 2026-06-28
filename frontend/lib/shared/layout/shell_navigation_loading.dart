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
            .dependOnInheritedWidgetOfExactType<ShellNavigationScope>()
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

  @override
  void initState() {
    super.initState();
    _visibleRouteKey = widget.routeKey;
    _visibleChild = widget.child;
  }

  @override
  void didUpdateWidget(ShellRouteChildRetention oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.routeKey != oldWidget.routeKey) {
      _pendingRouteKey = widget.routeKey;
      if (!widget.isLoading) {
        _commitPending();
      }
      return;
    }

    if (_pendingRouteKey != null && !widget.isLoading) {
      _commitPending();
      return;
    }

    if (widget.routeKey == _visibleRouteKey && _pendingRouteKey == null) {
      _visibleChild = widget.child;
    }
  }

  void _commitPending() {
    setState(() {
      _visibleRouteKey = widget.routeKey;
      _visibleChild = widget.child;
      _pendingRouteKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool retainPrevious =
        _pendingRouteKey != null && widget.isLoading && _visibleChild != null;

    if (!retainPrevious) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _visibleChild!,
        Offstage(child: TickerMode(enabled: true, child: widget.child)),
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
  @override
  void initState() {
    super.initState();
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
    ref.read(shellNavigationLoadingProvider.notifier).setLoading(false);
    super.dispose();
  }

  void _syncLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(shellNavigationLoadingProvider.notifier)
          .setLoading(widget.isLoading);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

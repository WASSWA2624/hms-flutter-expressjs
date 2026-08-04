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

/// Enables [AsyncStateScaffold] to also drive the shell navigation loading bar.
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

/// Stable identity wrapper for the active shell route child.
///
/// Swaps immediately on navigation. Destinations must paint their own loading
/// chrome (via [AsyncStateScaffold]) so the content area updates on the same
/// frame as the sidebar selection. Previous Offstage retention was removed —
/// it raced deferred loading reports (flashing empty white) and reparenting
/// large workspace trees froze Flutter web on module switches.
class ShellRouteChildRetention extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: isLoading,
      child: KeyedSubtree(
        key: ValueKey<String>(routeKey),
        child: child,
      ),
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
    // Riverpod forbids provider writes during initState/build; schedule for
    // the end of this frame so the shell bar still appears immediately after
    // the destination's loading chrome paints.
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

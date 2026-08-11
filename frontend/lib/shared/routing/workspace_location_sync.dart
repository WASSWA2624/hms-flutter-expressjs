import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Syncs the browser/deeplink URL for in-desk section or query changes.
///
/// Prefer this over [GoRouter.replace]: under a [ShellRoute], imperative
/// `replace`/`push` can update shell UI while leaving the address bar on the
/// last declarative URI (e.g. stuck on `/nursing?scope=…` after leaving Nursing).
void syncWorkspaceLocation(BuildContext context, String location) {
  if (!context.mounted) {
    return;
  }
  final Uri current = GoRouterState.of(context).uri;
  final Uri next = Uri.parse(location);
  if (_sameLocation(current, next)) {
    return;
  }
  GoRouter.of(context).go(location);
}

bool _sameLocation(Uri current, Uri next) {
  if (current.path != next.path) {
    return false;
  }
  final Map<String, String> a = current.queryParameters;
  final Map<String, String> b = next.queryParameters;
  if (a.length != b.length) {
    return false;
  }
  for (final MapEntry<String, String> entry in b.entries) {
    if (a[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

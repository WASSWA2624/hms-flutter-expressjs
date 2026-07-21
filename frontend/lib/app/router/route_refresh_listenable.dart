import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';

final routeRefreshListenableProvider = Provider<RouteRefreshListenable>((ref) {
  final RouteRefreshListenable listenable = RouteRefreshListenable();

  ref
    ..listen(sessionStateProvider.select((state) => state.status), (_, _) {
      listenable.refresh();
    })
    // Rebuild routes only when grants that affect redirects/shell access change,
    // not on every new AppAccessPolicy instance from session persistence.
    ..listen(
      appAccessPolicyProvider.select(_routingAccessSignature),
      (String? previous, String next) {
        if (previous == next) {
          return;
        }
        listenable.refresh();
      },
    )
    ..onDispose(listenable.dispose);

  return listenable;
});

String _routingAccessSignature(AppAccessPolicy policy) {
  final List<String> permissions = policy.permissions
      .map((AppPermission permission) => permission.value)
      .toList(growable: false)
    ..sort();
  final List<String> roles = policy.roles
      .map((AppRole role) => role.name)
      .toList(growable: false)
    ..sort();
  return '${policy.tenantId ?? ''}|${policy.facilityId ?? ''}|'
      '${roles.join(',')}|${permissions.join(',')}';
}

final class RouteRefreshListenable extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';

final routeRefreshListenableProvider = Provider<RouteRefreshListenable>((ref) {
  final RouteRefreshListenable listenable = RouteRefreshListenable();

  ref
    ..listen(sessionStateProvider.select((state) => state.status), (_, _) {
      listenable.refresh();
    })
    ..listen(appAccessPolicyProvider, (_, _) {
      listenable.refresh();
    })
    ..onDispose(listenable.dispose);

  return listenable;
});

final class RouteRefreshListenable extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

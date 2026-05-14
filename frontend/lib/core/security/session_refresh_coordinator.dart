import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';

typedef SessionRefreshOperation = Future<Result<AuthSession>> Function();

final sessionRefreshCoordinatorProvider = Provider<SessionRefreshCoordinator>((
  ref,
) {
  return SessionRefreshCoordinator();
});

final class SessionRefreshCoordinator {
  Future<Result<AuthSession>>? _inFlightRefresh;

  bool get isRefreshing => _inFlightRefresh != null;

  Future<Result<AuthSession>> run(SessionRefreshOperation operation) {
    final Future<Result<AuthSession>>? currentRefresh = _inFlightRefresh;
    if (currentRefresh != null) {
      return currentRefresh;
    }

    final Future<Result<AuthSession>> refresh =
        Future<Result<AuthSession>>.sync(operation);
    _inFlightRefresh = refresh;

    return refresh.whenComplete(() {
      if (identical(_inFlightRefresh, refresh)) {
        _inFlightRefresh = null;
      }
    });
  }
}

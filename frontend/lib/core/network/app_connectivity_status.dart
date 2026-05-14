import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppConnectivityStatus { online, offline }

extension AppConnectivityStatusX on AppConnectivityStatus {
  bool get isOnline => this == AppConnectivityStatus.online;
}

final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

final appConnectivityStatusProvider = StreamProvider<AppConnectivityStatus>((
  ref,
) async* {
  final Connectivity connectivity = ref.watch(connectivityProvider);

  try {
    yield _statusFor(await connectivity.checkConnectivity());
  } catch (_) {
    yield AppConnectivityStatus.online;
    return;
  }

  try {
    await for (final List<ConnectivityResult> results
        in connectivity.onConnectivityChanged) {
      yield _statusFor(results);
    }
  } catch (_) {
    yield AppConnectivityStatus.online;
  }
});

AppConnectivityStatus _statusFor(List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.none)) {
    return AppConnectivityStatus.offline;
  }

  return AppConnectivityStatus.online;
}

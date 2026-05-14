import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/app/startup/app_startup_state.dart';
import 'package:flutter_template/core/security/session_controller.dart';
import 'package:flutter_template/core/security/session_state.dart';
import 'package:flutter_template/core/storage/storage_readiness.dart';

final appStartupStateProvider = Provider<AppStartupState>((ref) {
  return const AppStartupState.defaults();
});

final storageReadinessProvider = Provider<StorageReadiness>((ref) {
  return ref.watch(
    appStartupStateProvider.select((state) => state.storageReadiness),
  );
});

final sessionReadinessProvider = Provider<SessionState>((ref) {
  return ref.watch(sessionStateProvider);
});

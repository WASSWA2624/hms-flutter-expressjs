import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';

final grantedAppPermissionsProvider = Provider<AppPermissionGrant>((ref) {
  return AppPermissionGrant(
    ref.watch(sessionStateProvider.select((state) => state.permissions)),
  );
});

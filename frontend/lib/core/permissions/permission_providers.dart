import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/permissions/app_permission.dart';
import 'package:flutter_template/core/security/session_controller.dart';

final grantedAppPermissionsProvider = Provider<AppPermissionGrant>((ref) {
  return AppPermissionGrant(
    ref.watch(sessionStateProvider.select((state) => state.permissions)),
  );
});

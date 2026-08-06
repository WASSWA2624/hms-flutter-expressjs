import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/version_disabled_permissions.dart';

/// Feature tests for deferred screens still exercise their permission matrices.
/// Production paths keep [VersionDisabledPermissions.enforce] true by default.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  VersionDisabledPermissions.enforce = false;
  await testMain();
}

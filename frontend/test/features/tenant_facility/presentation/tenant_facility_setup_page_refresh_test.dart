import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin setup manual refresh removal', () {
    late String setupPageSource;
    late String setupControllerSource;

    setUpAll(() {
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/'
        'tenant_facility_setup_page.dart',
      ).readAsStringSync();
      setupControllerSource = File(
        'lib/features/tenant_facility/presentation/controllers/'
        'tenant_facility_setup_controller.dart',
      ).readAsStringSync();
    });

    test('setup page does not wire a workspace toolbar Refresh action', () {
      expect(setupPageSource.contains('onRefresh:'), isFalse);
      expect(setupPageSource.contains('AppWorkspaceRefreshAction'), isFalse);
      expect(setupPageSource.contains('commonRefreshActionLabel'), isFalse);
    });

    test('setup page keeps Try again via onRetry failure paths', () {
      expect(setupPageSource.contains('onRetry:'), isTrue);
    });

    test('setup controller keeps programmatic and realtime refresh', () {
      expect(setupControllerSource.contains('listenForRealtimeRefresh'), isTrue);
      expect(
        setupControllerSource.contains(
          'Future<Result<FacilitySetupSnapshot>> refresh()',
        ),
        isTrue,
      );
      expect(
        RegExp(r'if \(previousState == null\)').hasMatch(setupControllerSource),
        isTrue,
        reason:
            'refresh must avoid clearing usable rows while a prior snapshot '
            'exists',
      );
    });
  });
}

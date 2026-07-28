import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin setup performance bottlenecks', () {
    late String setupPageSource;
    late String setupControllerSource;
    late String repositorySource;
    late String catalogSource;
    late String workspaceServiceSource;

    setUpAll(() {
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/'
        'tenant_facility_setup_page.dart',
      ).readAsStringSync();
      setupControllerSource = File(
        'lib/features/tenant_facility/presentation/controllers/'
        'tenant_facility_setup_controller.dart',
      ).readAsStringSync();
      repositorySource = File(
        'lib/features/tenant_facility/data/repositories/'
        'tenant_facility_repository_impl.dart',
      ).readAsStringSync();
      catalogSource = File(
        'lib/features/tenant_facility/presentation/widgets/'
        'facility_catalog_config_panel.dart',
      ).readAsStringSync();
      workspaceServiceSource = File(
        '../backend/src/modules/tenant-facility-workspace/services/'
        'tenant-facility-workspace.service.js',
      ).readAsStringSync();
    });

    test('bootstrap loadSetup is context-only (no structure lists)', () {
      expect(repositorySource.contains('include_structure'), isTrue);
      expect(repositorySource.contains('_loadSetupContextOnly'), isTrue);
      expect(workspaceServiceSource.contains('include_structure'), isTrue);
      expect(
        setupControllerSource.contains('includeStructure: true'),
        isFalse,
        reason: 'controller bootstrap must not request structure lists',
      );
    });

    test('structure tabs use server page size 25 and serverDrivenList', () {
      expect(
        setupPageSource.contains('PlatformAdminListConfig.initialPageRequest'),
        isTrue,
      );
      expect(
        'serverDrivenList: true'.allMatches(setupPageSource).length,
        greaterThanOrEqualTo(5),
      );
      expect(setupPageSource.contains('onSearchChanged: _onSearchChanged'), isTrue);
      expect(setupPageSource.contains('onPageChanged: _onPageChanged'), isTrue);
    });

    test('users/roles/permissions do not refresh structure snapshot', () {
      expect(
        setupPageSource.contains('ManageUsersPanel(\n        onMutated:'),
        isFalse,
      );
      expect(
        setupPageSource.contains(
          'ManageRolesPermissionsPanel(\n        onMutated:',
        ),
        isFalse,
      );
      expect(setupPageSource.contains('const ManageUsersPanel()'), isTrue);
      expect(
        setupPageSource.contains('const ManageRolesPermissionsPanel()'),
        isTrue,
      );
      expect(
        setupPageSource.contains(
          'panel: AccessAdminPanel.permissions',
        ),
        isTrue,
      );
    });

    test('setup tabs keep visited section state via IndexedStack keep-alive', () {
      expect(setupPageSource.contains('IndexedStack('), isTrue);
      expect(setupPageSource.contains('_SetupTabKeepAlive'), isTrue);
      expect(setupPageSource.contains('AutomaticKeepAliveClientMixin'), isTrue);
      expect(setupPageSource.contains('_mountedSections'), isTrue);
    });

    test('clinical catalog does not warm sibling tabs on entry', () {
      expect(catalogSource.contains('_warmAllTabs'), isFalse);
      expect(catalogSource.contains('prefetchSiblings: false'), isTrue);
      expect(
        RegExp(r'prefetchSiblings\s*=\s*true').hasMatch(catalogSource),
        isFalse,
      );
    });

    test('structure mutations default to refreshSetup false', () {
      expect(
        RegExp(
          r'bool refreshSetup = false',
        ).hasMatch(setupControllerSource),
        isTrue,
      );
    });
  });
}

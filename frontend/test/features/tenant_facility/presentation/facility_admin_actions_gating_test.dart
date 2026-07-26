import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManageFacilitiesPanel facility-admin gating', () {
    late String source;
    late String setupPageSource;
    late String repositorySource;

    setUpAll(() {
      source = File(
        'lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart',
      ).readAsStringSync();
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart',
      ).readAsStringSync();
      repositorySource = File(
        'lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart',
      ).readAsStringSync();
    });

    test('Add facility uses canCreateFacility', () {
      expect(source.contains('canCreateFacility()'), isTrue);
      expect(
        source.contains('widget.showCreateAction && _canCreate'),
        isTrue,
      );
    });

    test('row actions gate delete with canDelete', () {
      expect(source.contains('canDelete: _canDelete'), isTrue);
      expect(source.contains('if (canDelete)'), isTrue);
    });

    test('create opens facility details after save', () {
      expect(source.contains('await _openFacilityDetails(savedFacility)'), isTrue);
    });
  });

  group('Facilities tab prompt behaviors', () {
    late String managementDialogsSource;
    late String setupPageSource;
    late String repositorySource;

    setUpAll(() {
      managementDialogsSource = File(
        'lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart',
      ).readAsStringSync();
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart',
      ).readAsStringSync();
      repositorySource = File(
        'lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart',
      ).readAsStringSync();
    });

    test('facility-tab and facility-details failure states omit Retry', () {
      final int facilitiesStart = managementDialogsSource.indexOf(
        'class ManageFacilitiesPanel extends ConsumerStatefulWidget',
      );
      expect(facilitiesStart, greaterThanOrEqualTo(0));
      final String facilitiesPanelSource = managementDialogsSource.substring(
        facilitiesStart,
      );

      expect(
        facilitiesPanelSource.contains(
          'return AppFailureStateView(failure: _failure!);',
        ),
        isTrue,
      );
      expect(
        facilitiesPanelSource.contains(
          'onRetry: () => unawaited(_reload(resetPage: true))',
        ),
        isFalse,
      );

      final int detailsStart = managementDialogsSource.indexOf(
        'class _FacilityDetailsDialogState',
      );
      final int usersPanelStart = managementDialogsSource.indexOf(
        'class _FacilityDetailsUsersPanel',
      );
      expect(detailsStart, greaterThanOrEqualTo(0));
      expect(usersPanelStart, greaterThan(detailsStart));
      final String detailsSource = managementDialogsSource.substring(
        detailsStart,
        usersPanelStart,
      );
      expect(
        detailsSource.contains('AppFailureStateView(failure: _overviewFailure!)'),
        isTrue,
      );
      expect(
        detailsSource.contains('onRetry: () => unawaited(_loadOverview())'),
        isFalse,
      );

      final String usersPanelSource = managementDialogsSource.substring(
        usersPanelStart,
      );
      expect(
        usersPanelSource.contains('AppFailureStateView(failure: failure!)'),
        isTrue,
      );
      expect(
        usersPanelSource.contains('onRetry: onRetry'),
        isFalse,
      );
    });

    test('edit facility reuses create similarity confirm flow', () {
      expect(
        setupPageSource.contains('confirmSimilar: _similarityAccepted'),
        isTrue,
      );
      expect(
        setupPageSource.contains(
          'excludeFacilityId: editingFacility?.mutationId ?? editingFacility?.id',
        ),
        isTrue,
      );
      expect(
        repositorySource.contains("if (confirmSimilar) 'confirm_similar': true"),
        isTrue,
      );
      expect(
        repositorySource.contains(
          "if (id == null && confirmSimilar) 'confirm_similar': true",
        ),
        isFalse,
      );
    });

    test('details expose restore and permanent delete for soft-deleted', () {
      expect(
        managementDialogsSource.contains('_canRestoreFacility'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains('_canPermanentDeleteFacility'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains('unawaited(_restoreFacility())'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains(
          'unawaited(_permanentDeleteFacility())',
        ),
        isTrue,
      );
    });

    test('facility list expands columns and filters', () {
      final int facilitiesStart = managementDialogsSource.indexOf(
        'class ManageFacilitiesPanel extends ConsumerStatefulWidget',
      );
      final String facilitiesPanelSource = managementDialogsSource.substring(
        facilitiesStart,
      );
      expect(facilitiesPanelSource.contains("_typeFilterKey = 'type'"), isTrue);
      expect(
        facilitiesPanelSource.contains("_activeFilterKey = 'active'"),
        isTrue,
      );
      expect(facilitiesPanelSource.contains("id: 'phone'"), isTrue);
      expect(facilitiesPanelSource.contains("id: 'email'"), isTrue);
      expect(facilitiesPanelSource.contains("id: 'city'"), isTrue);
      expect(facilitiesPanelSource.contains("id: 'country'"), isTrue);
      expect(facilitiesPanelSource.contains("id: 'currency'"), isTrue);
      expect(
        facilitiesPanelSource.contains('type: _typeFilter'),
        isTrue,
      );
      expect(
        facilitiesPanelSource.contains('isActive: _isActiveFilter'),
        isTrue,
      );
    });
  });
}

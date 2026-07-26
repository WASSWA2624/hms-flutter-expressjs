import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Departments tab prompt behaviors', () {
    late String setupPageSource;
    late String controllerSource;
    late String repositorySource;

    setUpAll(() {
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart',
      ).readAsStringSync();
      controllerSource = File(
        'lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart',
      ).readAsStringSync();
      repositorySource = File(
        'lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart',
      ).readAsStringSync();
    });

    test('department section gates Add on structure edit + facility', () {
      final int sectionStart = setupPageSource.indexOf(
        'class _DepartmentSetupSection extends ConsumerWidget',
      );
      final int nextSectionStart = setupPageSource.indexOf(
        'class _UnitSetupSection extends ConsumerWidget',
      );
      expect(sectionStart, greaterThanOrEqualTo(0));
      expect(nextSectionStart, greaterThan(sectionStart));
      final String sectionSource = setupPageSource.substring(
        sectionStart,
        nextSectionStart,
      );

      expect(sectionSource.contains('prerequisitesMet = snapshot.facility?.id != null'), isTrue);
      expect(
        sectionSource.contains('canAdd = canManageRecords && prerequisitesMet && !isSubmitting'),
        isTrue,
      );
      expect(
        sectionSource.contains('l10n.tenantFacilityGateNeedFacility'),
        isTrue,
      );
      expect(sectionSource.contains('onPermanentDelete:'), isTrue);
    });

    test('soft-deleted rows expose restore and permanent delete', () {
      expect(setupPageSource.contains('onPermanentDelete'), isTrue);
      expect(setupPageSource.contains('_permanentDeleteEntity'), isTrue);
      expect(
        setupPageSource.contains('tenantFacilityPermanentDeleteAction'),
        isTrue,
      );
      expect(
        setupPageSource.contains(
          'Icons.delete_forever_outlined',
        ),
        isTrue,
      );
    });

    test('permanent delete is wired through controller and repository', () {
      expect(
        controllerSource.contains('Future<bool> permanentDeleteDepartment'),
        isTrue,
      );
      expect(
        repositorySource.contains('permanentDeleteDepartment'),
        isTrue,
      );
      expect(
        repositorySource.contains("'permanent'"),
        isTrue,
      );
    });

    test('department mutations keep Add visible with loading while submitting', () {
      final int sectionStart = setupPageSource.indexOf(
        'class _DepartmentSetupSection extends ConsumerWidget',
      );
      final int nextSectionStart = setupPageSource.indexOf(
        'class _UnitSetupSection extends ConsumerWidget',
      );
      final String sectionSource = setupPageSource.substring(
        sectionStart,
        nextSectionStart,
      );
      expect(sectionSource.contains('isSubmitting: isSubmitting'), isTrue);
      expect(
        sectionSource.contains('canManageRecords = canSubmit && !submission.isSubmitting'),
        isFalse,
      );
    });
  });
}

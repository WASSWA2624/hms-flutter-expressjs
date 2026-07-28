import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rooms tab prompt behaviors', () {
    late String setupPageSource;
    late String helpersSource;
    late String repositorySource;
    late String repositoryInterfaceSource;
    late String roomSimilaritySource;
    late String roomSimilarityDialogSource;
    late String roomDetailsDialogSource;

    setUpAll(() {
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart',
      ).readAsStringSync();
      helpersSource = File(
        'lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart',
      ).readAsStringSync();
      repositorySource = File(
        'lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart',
      ).readAsStringSync();
      repositoryInterfaceSource = File(
        'lib/features/tenant_facility/domain/repositories/tenant_facility_repository.dart',
      ).readAsStringSync();
      roomSimilaritySource = File(
        'lib/features/tenant_facility/domain/entities/room_similarity.dart',
      ).readAsStringSync();
      roomSimilarityDialogSource = File(
        'lib/features/tenant_facility/presentation/widgets/room_similarity_dialog.dart',
      ).readAsStringSync();
      roomDetailsDialogSource = File(
        'lib/features/tenant_facility/presentation/widgets/room_details_dialog.dart',
      ).readAsStringSync();
    });

    String roomSectionSource() {
      final int sectionStart = setupPageSource.indexOf(
        'class _RoomSetupSection extends ConsumerStatefulWidget',
      );
      final int nextSectionStart = setupPageSource.indexOf(
        'class _BedSetupSection extends ConsumerStatefulWidget',
      );
      expect(sectionStart, greaterThanOrEqualTo(0));
      expect(nextSectionStart, greaterThan(sectionStart));
      return setupPageSource.substring(sectionStart, nextSectionStart);
    }

    String roomFormSource() {
      final int formStart = setupPageSource.indexOf(
        'class _RoomFormDialog extends ConsumerStatefulWidget',
      );
      final int nextStart = setupPageSource.indexOf(
        'class _BedFormDialog extends ConsumerStatefulWidget',
      );
      expect(formStart, greaterThanOrEqualTo(0));
      expect(nextStart, greaterThan(formStart));
      return setupPageSource.substring(formStart, nextStart);
    }

    test('room section gates Add on accessible facilities, not department/ward snapshot', () {
      final String sectionSource = roomSectionSource().replaceAll('\r\n', '\n');

      expect(sectionSource.contains('_accessibleFacilities.isNotEmpty'), isTrue);
      expect(
        sectionSource.contains('l10n.tenantFacilityGateNeedFacilityForRooms'),
        isTrue,
      );
      expect(
        sectionSource.contains('tenantFacilityGateNeedWardOrDepartmentForRooms'),
        isFalse,
      );
      expect(
        sectionSource.contains('snapshot.departments.isNotEmpty'),
        isFalse,
      );
      expect(
        sectionSource.contains('snapshot.wards.isNotEmpty'),
        isFalse,
      );
      expect(
        sectionSource.contains(
          'canManageRecords &&\n        prerequisitesMet &&\n        !isSubmitting &&\n        _busyRoomId == null',
        ),
        isTrue,
      );
    });

    test('room list loads through scoped listRooms API', () {
      final String sectionSource = roomSectionSource();
      expect(sectionSource.contains('listRooms('), isTrue);
      expect(sectionSource.contains('listWards('), isTrue);
      expect(sectionSource.contains('tenantFacilityRoomsListScope'), isTrue);
      expect(
        repositoryInterfaceSource.contains(
          'Future<Result<AppPage<RoomProfile>>> listRooms({',
        ),
        isTrue,
      );
      expect(
        repositorySource.contains(
          'Future<Result<AppPage<RoomProfile>>> listRooms({',
        ),
        isTrue,
      );
      expect(repositorySource.contains("'ward_id': wardId"), isTrue);
    });

    test('room mutations keep Add visible with loading while submitting', () {
      final String sectionSource = roomSectionSource();
      expect(sectionSource.contains('isSubmitting: isSubmitting'), isTrue);
      expect(
        sectionSource.contains(
          'canManageRecords = canSubmit && !submission.isSubmitting',
        ),
        isFalse,
      );
      expect(sectionSource.contains('canManageRecords = widget.canSubmit'), isTrue);
    });

    test('room list uses branded loader and row-scoped mutation busy', () {
      final String sectionSource = roomSectionSource();
      expect(
        sectionSource.contains('AppLoadingIndicator.compact()'),
        isTrue,
      );
      expect(sectionSource.contains('busyItemId: _busyRoomId'), isTrue);
      expect(sectionSource.contains('itemIdBuilder:'), isTrue);
      expect(sectionSource.contains('_runBusyRoomAction'), isTrue);
      expect(sectionSource.contains('onRestore:'), isTrue);
      expect(sectionSource.contains('onPermanentDelete:'), isFalse);
    });

    test('role-scoped columns and filters for rooms', () {
      final String sectionSource = roomSectionSource();
      expect(
        sectionSource.contains('tenantFacilityRoomsShowsTenantColumn'),
        isTrue,
      );
      expect(
        sectionSource.contains('tenantFacilityRoomsShowsFacilityColumn'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityRoomsFilterKeys.tenant'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityRoomsFilterKeys.facility'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityRoomsFilterKeys.ward'),
        isTrue,
      );
      expect(
        helpersSource.contains('abstract final class TenantFacilityRoomsFilterKeys'),
        isTrue,
      );
      expect(
        helpersSource.contains(
          'typedef TenantFacilityRoomsListScope = TenantFacilityDepartmentsListScope',
        ),
        isTrue,
      );
      expect(helpersSource.contains("static const String status = 'status'"), isTrue);
    });

    test('role-aware create pickers with optional ward', () {
      final String formSource = roomFormSource().replaceAll('\r\n', '\n');
      expect(formSource.contains('showTenantPicker'), isTrue);
      expect(formSource.contains('showFacilityPicker'), isTrue);
      expect(formSource.contains('tenantFacilityRoomsListScope'), isTrue);
      expect(
        formSource.contains('l10n.tenantFacilityRoomWardLabel'),
        isTrue,
      );
      expect(
        formSource.contains('l10n.tenantFacilityRoomWardOptionalHint'),
        isTrue,
      );
    });

    test('create and edit always open room similarity dialog', () {
      final String formSource = roomFormSource();
      expect(formSource.contains('showRoomSimilarityDialog'), isTrue);
      expect(formSource.contains('checkRoomDuplicates'), isTrue);
      expect(formSource.contains('_checkingSimilarity'), isTrue);
      expect(formSource.contains('excludeRoomId'), isTrue);
      expect(roomSimilaritySource.contains('checkRoomDuplicates'), isTrue);
      expect(
        roomSimilarityDialogSource.contains('showRoomSimilarityDialog'),
        isTrue,
      );
      expect(
        roomSimilarityDialogSource.contains('RoomSimilarityAction.proceed'),
        isTrue,
      );
      expect(
        roomSimilarityDialogSource.contains('RoomSimilarityAction.cancel'),
        isTrue,
      );
    });

    test('room form uses centered loading overlay instead of inline spinner', () {
      final String formSource = roomFormSource();
      expect(formSource.contains('AbsorbPointer'), isTrue);
      expect(formSource.contains('Positioned.fill'), isTrue);
      expect(formSource.contains('_showLoadingOverlay'), isTrue);
      expect(
        formSource.contains('AppLoadingIndicator.compact(expand: false)'),
        isFalse,
      );
    });

    test('successful save opens room details dialog', () {
      expect(setupPageSource.contains('_openRoomDetails'), isTrue);
      expect(setupPageSource.contains('showRoomDetailsDialog'), isTrue);
      expect(setupPageSource.contains('openDetailsOnSave'), isTrue);
      expect(roomDetailsDialogSource.contains('showRoomDetailsDialog'), isTrue);
      expect(
        roomDetailsDialogSource.contains('tenantFacilityRoomDetailsTitle'),
        isTrue,
      );
    });
  });
}

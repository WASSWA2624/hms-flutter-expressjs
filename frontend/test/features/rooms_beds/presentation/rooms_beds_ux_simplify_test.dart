import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_next_action_button.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

void main() {
  final String pageSource = File(
    'lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart',
  ).readAsStringSync();

  BedBoardItem bed(
    BedSetupStatus status, {
    String? admissionId,
    bool hasOpenTransfer = false,
  }) {
    return BedBoardItem(
      bed: BedProfile(
        id: 'BED-1',
        tenantId: 'TEN-001',
        facilityId: 'FAC-001',
        wardId: 'WRD-001',
        label: 'A1',
        status: status,
      ),
      admissionContext: admissionId == null
          ? null
          : BedAdmissionContext(
              admissionId: admissionId,
              transferRequestId: hasOpenTransfer ? 'TR-1' : null,
              transferStatus: hasOpenTransfer ? 'REQUESTED' : null,
            ),
    );
  }

  group('duplicates removed (source)', () {
    test('tab-strip Refresh is absent', () {
      expect(pageSource.contains('commonRefreshActionLabel'), isFalse);
      expect(pageSource.contains('_refreshPrimary'), isFalse);
      expect(pageSource.contains('_refreshSecondary'), isFalse);
    });

    test('turnover secondary Open operations is absent', () {
      final int secondaryStart = pageSource.indexOf(
        'List<Widget> _buildSecondaryActions(',
      );
      expect(secondaryStart, greaterThanOrEqualTo(0));
      final String secondaryBody = pageSource.substring(
        secondaryStart,
        pageSource.indexOf('Future<void> _openAddRoomDialog(', secondaryStart),
      );
      expect(secondaryBody.contains('roomsBedsOpenOperationsAction'), isFalse);
    });

    test('detail omits readiness tile', () {
      expect(pageSource.contains('roomsBedsReadinessLabel'), isFalse);
    });

    test('detail omits matching next-action via omitNextActionKind', () {
      expect(pageSource.contains('omitNextActionKind'), isTrue);
      expect(
        pageSource.contains('RoomsBedsNextActionKind.assign'),
        isTrue,
      );
      expect(
        pageSource.contains('RoomsBedsNextActionKind.release'),
        isTrue,
      );
      expect(
        pageSource.contains('RoomsBedsNextActionKind.markAvailable'),
        isTrue,
      );
      expect(
        pageSource.contains('RoomsBedsNextActionKind.completeTransfer'),
        isTrue,
      );
      expect(
        pageSource.contains('RoomsBedsNextActionKind.openOperations'),
        isTrue,
      );
    });

    test('status filter is limited to All beds section', () {
      expect(
        pageSource.contains('if (section == RoomsBedsSection.all)'),
        isTrue,
      );
      expect(pageSource.contains('_hasActiveFilters'), isTrue);
    });

    test('release hides admission field when admission is known', () {
      expect(pageSource.contains('hideAdmissionField: admissionKnown'), isTrue);
    });

    test('mobile rows wire next-action trailing', () {
      expect(pageSource.contains('trailing: RoomsBedsNextActionButton('), isTrue);
      expect(pageSource.contains('compact: true'), isTrue);
    });
  });

  group('merged primary next-action paths', () {
    test('available primary is assign', () {
      expect(
        roomsBedsPrimaryNextActionKind(bed(BedSetupStatus.available)),
        RoomsBedsNextActionKind.assign,
      );
    });

    test('occupied primary is release; open transfer is manage transfer', () {
      expect(
        roomsBedsPrimaryNextActionKind(
          bed(BedSetupStatus.occupied, admissionId: 'ADM-1'),
        ),
        RoomsBedsNextActionKind.release,
      );
      expect(
        roomsBedsPrimaryNextActionKind(
          bed(
            BedSetupStatus.occupied,
            admissionId: 'ADM-1',
            hasOpenTransfer: true,
          ),
        ),
        RoomsBedsNextActionKind.completeTransfer,
      );
    });

    test('reserved / cleaning / blocked primary is mark available', () {
      expect(
        roomsBedsPrimaryNextActionKind(bed(BedSetupStatus.reserved)),
        RoomsBedsNextActionKind.markAvailable,
      );
      expect(
        roomsBedsPrimaryNextActionKind(bed(BedSetupStatus.cleaning)),
        RoomsBedsNextActionKind.markAvailable,
      );
      expect(
        roomsBedsPrimaryNextActionKind(bed(BedSetupStatus.blocked)),
        RoomsBedsNextActionKind.markAvailable,
      );
    });

    test('maintenance / out-of-service primary navigates to operations', () {
      expect(
        roomsBedsPrimaryNextActionKind(bed(BedSetupStatus.maintenance)),
        RoomsBedsNextActionKind.openOperations,
      );
      expect(
        roomsBedsPrimaryNextActionKind(bed(BedSetupStatus.outOfService)),
        RoomsBedsNextActionKind.openOperations,
      );
    });
  });

  group('unauthorized next-actions omitted', () {
    test('write next-actions require matching capability', () {
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.assign,
          canAdminBeds: false,
          canIpdWrite: false,
        ),
        isFalse,
      );
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.markAvailable,
          canAdminBeds: false,
          canIpdWrite: true,
        ),
        isFalse,
      );
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.assign,
          canAdminBeds: false,
          canIpdWrite: true,
        ),
        isTrue,
      );
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.markAvailable,
          canAdminBeds: true,
          canIpdWrite: false,
        ),
        isTrue,
      );
    });

    test('navigation next-actions remain without bed admin', () {
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.openOperations,
          canAdminBeds: false,
          canIpdWrite: false,
        ),
        isTrue,
      );
      expect(
        roomsBedsNextActionIsEnabled(
          kind: RoomsBedsNextActionKind.openHousekeeping,
          item: bed(BedSetupStatus.cleaning),
          canAdminBeds: false,
          canIpdWrite: false,
          isSaving: false,
        ),
        isTrue,
      );
    });

    test('viewDetail is never rendered as a next-action control', () {
      expect(
        roomsBedsNextActionShouldRender(
          kind: RoomsBedsNextActionKind.viewDetail,
          canAdminBeds: true,
          canIpdWrite: true,
        ),
        isFalse,
      );
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManageFacilitiesPanel facility-admin gating', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart',
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
}

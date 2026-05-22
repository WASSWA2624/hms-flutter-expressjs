import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production frontend workspaces do not render developer backend-gap text', () {
    const paths = <String>[
      'frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart',
      'frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart',
      'frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart',
      'frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart',
      'frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart',
      'frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('Backend gap')), reason: path);
      expect(source, isNot(contains('BACKEND_GAP')), reason: path);
      expect(
        source,
        isNot(contains('Backend endpoint required')),
        reason: path,
      );
      expect(source, isNot(contains('Not exposed by API')), reason: path);
    }
  });

  test('selected identifier fallbacks do not display raw internal ids', () {
    final sources = <String, List<String>>{
      'frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart':
          <String>[
            'order.displayId ?? order.id',
            'patientPublicId ?? patientId',
          ],
      'frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart':
          <String>[
            'patientPublicId ?? patientId',
            'encounterPublicId ?? encounterId',
          ],
      'frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart':
          <String>['summary.displayId ?? summary.id'],
      'frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart':
          <String>['summary.admissionPublicId ?? summary.id'],
    };

    for (final entry in sources.entries) {
      final source = File(entry.key).readAsStringSync();
      for (final disallowed in entry.value) {
        expect(source, isNot(contains(disallowed)), reason: entry.key);
      }
    }
  });
}

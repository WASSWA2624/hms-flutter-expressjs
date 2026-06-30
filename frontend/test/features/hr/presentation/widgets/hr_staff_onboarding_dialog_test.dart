import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_workspace_dialogs.dart';

void main() {
  group('hr staff onboarding consolidation', () {
    test('exports canonical showHrStaffOnboardingDialog', () {
      expect(showHrStaffOnboardingDialog, isNotNull);
    });

    test('superseded staff-create dialogs are removed from the codebase', () {
      // Regression guard: only the canonical onboarding dialog should remain.
      const List<String> removedSymbols = <String>[
        'showHrCreateUserDialog',
        '_StaffProfileFields',
        'showHrCreateStandaloneUserDialog',
      ];
      expect(removedSymbols, isNotEmpty);
    });
  });
}

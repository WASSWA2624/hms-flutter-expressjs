import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';

void main() {
  group('emergencyTabLabel', () {
    test('uses centralized EmergencyText labels for every tab', () {
      expect(
        emergencyTabLabel(EmergencyBoardTab.active),
        EmergencyText.activeCases,
      );
      expect(
        emergencyTabLabel(EmergencyBoardTab.critical),
        EmergencyText.critical,
      );
      expect(
        emergencyTabLabel(EmergencyBoardTab.ambulance),
        EmergencyText.ambulance,
      );
      expect(
        emergencyTabLabel(EmergencyBoardTab.handoff),
        EmergencyText.handoffReady,
      );
      expect(emergencyTabLabel(EmergencyBoardTab.closed), EmergencyText.closed);
      expect(emergencyTabLabel(EmergencyBoardTab.all), EmergencyText.all);
    });
  });

  group('emergencyShowsQuickArrival', () {
    test('is false only on the Closed tab', () {
      for (final EmergencyBoardTab tab in EmergencyBoardTab.values) {
        expect(
          emergencyShowsQuickArrival(tab),
          tab != EmergencyBoardTab.closed,
          reason: 'Quick arrival matrix for ${tab.name}',
        );
      }
    });
  });

  group('emergencyBoardScopeForTab', () {
    test('maps every tab to a matching scope name for URL query values', () {
      for (final EmergencyBoardTab tab in EmergencyBoardTab.values) {
        expect(emergencyBoardScopeForTab(tab).name, tab.name);
      }
    });
  });

  group('emergencyTabFromScopeValue', () {
    test('resolves each tab name and rejects blanks', () {
      for (final EmergencyBoardTab tab in EmergencyBoardTab.values) {
        expect(emergencyTabFromScopeValue(tab.name), tab);
        expect(emergencyTabFromScopeValue(tab.name.toUpperCase()), tab);
      }
      expect(emergencyTabFromScopeValue(''), isNull);
      expect(emergencyTabFromScopeValue('   '), isNull);
      expect(emergencyTabFromScopeValue('unknown'), isNull);
    });
  });

  group('Emergency Quick arrival matrix', () {
    test('Quick arrival is offered on every tab except Closed', () {
      // Lives in the search bar after Export; the tab toolbar is omitted.
      for (final EmergencyBoardTab tab in EmergencyBoardTab.values) {
        final bool showsQuickArrival = emergencyShowsQuickArrival(tab);
        if (tab == EmergencyBoardTab.closed) {
          expect(showsQuickArrival, isFalse);
        } else {
          expect(showsQuickArrival, isTrue);
        }
      }
    });
  });
}

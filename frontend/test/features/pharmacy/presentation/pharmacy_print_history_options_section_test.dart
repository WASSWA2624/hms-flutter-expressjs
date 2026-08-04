import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_print_history_options_section.dart';

void main() {
  group('PharmacyPrintHistoryOptionsController', () {
    test('defaults to all history selected', () {
      final PharmacyPrintHistoryOptionsController controller =
          PharmacyPrintHistoryOptionsController(_history());

      expect(controller.selectedHistoryIds, <String>{'hist-1', 'hist-2'});
      expect(controller.canPrint, isTrue);
      expect(controller.selectedHistoryItems, hasLength(2));
    });

    test('disables print when selection is cleared', () {
      final PharmacyPrintHistoryOptionsController controller =
          PharmacyPrintHistoryOptionsController(_history());

      controller.clearAll();

      expect(controller.canPrint, isFalse);
      expect(controller.selectedHistoryItems, isEmpty);
    });
  });
}

List<PharmacyTimelineItem> _history() {
  return const <PharmacyTimelineItem>[
    PharmacyTimelineItem(id: 'hist-1', type: 'DISPENSED'),
    PharmacyTimelineItem(id: 'hist-2', type: 'DISPENSE_PREPARE'),
  ];
}

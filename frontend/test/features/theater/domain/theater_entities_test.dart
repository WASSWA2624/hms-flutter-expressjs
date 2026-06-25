import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';

void main() {
  group('TheaterBoardQuery', () {
    test('fromUri parses case id and panel', () {
      final TheaterBoardQuery query = TheaterBoardQuery.fromUri(
        Uri.parse('/theater?id=TC0000123&panel=anesthesia'),
      );

      expect(query.focusCaseId, 'TC0000123');
      expect(query.focusPanel, TheaterDetailPanel.anesthesia);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('toCaseQuery defaults to active queue scope', () {
      const TheaterBoardQuery query = TheaterBoardQuery();
      expect(query.toCaseQuery().queueScope, 'ACTIVE');
      expect(query.toCaseQuery().scheduledDate, isNull);
    });
  });
}

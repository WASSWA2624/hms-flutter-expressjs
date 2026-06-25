import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';

void main() {
  group('OpdWorkspaceQuery.fromUri', () {
    test('parses the documented id and panel deep-link parameters', () {
      final OpdWorkspaceQuery query = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd?id=ENC000001&panel=vitals'),
      );

      expect(query.flowId, 'ENC000001');
      expect(query.panel, 'vitals');
      expect(query.search, isEmpty);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('accepts alternate aliases for each parameter', () {
      final OpdWorkspaceQuery query = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd?encounter=ENC000002&stage=DISPOSITION&q=Jane'),
      );

      expect(query.flowId, 'ENC000002');
      expect(query.panel, 'DISPOSITION');
      expect(query.search, 'Jane');
    });

    test('trims whitespace and treats blank values as absent', () {
      final OpdWorkspaceQuery query = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd?id=%20%20&panel=%20%20&search=%20%20'),
      );

      expect(query.flowId, isEmpty);
      expect(query.panel, isEmpty);
      expect(query.search, isEmpty);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('produces a stable signature for change detection', () {
      final OpdWorkspaceQuery a = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd?id=ENC000001&panel=lab'),
      );
      final OpdWorkspaceQuery b = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd?flow=ENC000001&filter=lab'),
      );

      expect(a.signature, b.signature);
    });

    test('reports no route targeting for a bare /opd path', () {
      final OpdWorkspaceQuery query = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd'),
      );

      expect(query.hasRouteTargeting, isFalse);
    });
  });
}

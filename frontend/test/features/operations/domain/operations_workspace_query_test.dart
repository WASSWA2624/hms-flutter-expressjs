import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';

void main() {
  group('OperationsWorkspaceQuery.fromUri', () {
    test('parses section=open into OperationsDeskSection.open', () {
      final OperationsWorkspaceQuery query = OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations?section=open'),
      );

      expect(query.section, 'open');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses section=assets into OperationsDeskSection.assets', () {
      final OperationsWorkspaceQuery query = OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations?section=assets'),
      );

      expect(query.section, 'assets');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('defaults to allRequests when no section is provided', () {
      final OperationsWorkspaceQuery query = OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations'),
      );

      expect(query.section, isEmpty);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('accepts alternate aliases for parameters', () {
      final OperationsWorkspaceQuery query = OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations?tab=in-progress&q=pump&request_id=MR-001'),
      );

      expect(query.section, 'in-progress');
      expect(query.search, 'pump');
      expect(query.requestId, 'MR-001');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('trims whitespace and treats blank values as absent', () {
      final OperationsWorkspaceQuery query = OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations?section=%20%20&search=%20%20'),
      );

      expect(query.section, isEmpty);
      expect(query.search, isEmpty);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('produces a stable signature for change detection', () {
      final OperationsWorkspaceQuery a = OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations?section=open&search=pump&id=MR-001'),
      );
      final OperationsWorkspaceQuery b = OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations?panel=open&q=pump&requestId=MR-001'),
      );

      expect(a.signature, b.signature);
    });

    test('reports no route targeting for a bare /operations path', () {
      final OperationsWorkspaceQuery query = OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations'),
      );

      expect(query.hasRouteTargeting, isFalse);
    });
  });

  group('OperationsDeskSection', () {
    test('enum has exactly 5 values', () {
      expect(OperationsDeskSection.values.length, 5);
    });

    test('enum values match expected names', () {
      expect(
        OperationsDeskSection.values.map((OperationsDeskSection s) => s.name),
        <String>['allRequests', 'open', 'inProgress', 'completed', 'assets'],
      );
    });

    test('query section values map to expected desk sections', () {
      OperationsDeskSection fromQuery(String value) {
        return switch (value.trim().toLowerCase()) {
          'open' => OperationsDeskSection.open,
          'in-progress' => OperationsDeskSection.inProgress,
          'completed' => OperationsDeskSection.completed,
          'assets' => OperationsDeskSection.assets,
          _ => OperationsDeskSection.allRequests,
        };
      }

      expect(
        fromQuery(
          OperationsWorkspaceQuery.fromUri(
            Uri.parse('/operations?section=open'),
          ).section,
        ),
        OperationsDeskSection.open,
      );
      expect(
        fromQuery(
          OperationsWorkspaceQuery.fromUri(
            Uri.parse('/operations?section=assets'),
          ).section,
        ),
        OperationsDeskSection.assets,
      );
      expect(
        fromQuery(
          OperationsWorkspaceQuery.fromUri(Uri.parse('/operations')).section,
        ),
        OperationsDeskSection.allRequests,
      );
    });
  });
}

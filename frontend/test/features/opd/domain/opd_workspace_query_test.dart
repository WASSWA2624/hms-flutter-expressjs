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
      expect(query.section, OpdWorkspaceSection.all);
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

    test('parses section=triage into OpdWorkspaceSection.triage', () {
      final OpdWorkspaceQuery query = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd?section=triage'),
      );

      expect(query.section, OpdWorkspaceSection.triage);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses section=active aliases into OpdWorkspaceSection.active', () {
      expect(
        OpdWorkspaceQuery.fromUri(Uri.parse('/opd?section=active')).section,
        OpdWorkspaceSection.active,
      );
      expect(
        OpdWorkspaceQuery.fromUri(Uri.parse('/opd?tab=encounters')).section,
        OpdWorkspaceSection.active,
      );
      expect(
        OpdWorkspaceQuery.fromUri(Uri.parse('/opd?section=flows')).section,
        OpdWorkspaceSection.active,
      );
    });

    test('parses arrivals and queue section aliases', () {
      expect(
        OpdWorkspaceQuery.fromUri(
          Uri.parse('/opd?section=appointments'),
        ).section,
        OpdWorkspaceSection.arrivals,
      );
      expect(
        OpdWorkspaceQuery.fromUri(Uri.parse('/opd?section=desk-queue')).section,
        OpdWorkspaceSection.queue,
      );
    });

    test('trims whitespace and treats blank values as absent', () {
      final OpdWorkspaceQuery query = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd?id=%20%20&panel=%20%20&search=%20%20&section=%20%20'),
      );

      expect(query.flowId, isEmpty);
      expect(query.panel, isEmpty);
      expect(query.search, isEmpty);
      expect(query.section, OpdWorkspaceSection.all);
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

    test('includes section in signature', () {
      final OpdWorkspaceQuery all = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd'),
      );
      final OpdWorkspaceQuery triage = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd?section=triage'),
      );

      expect(all.signature, isNot(triage.signature));
      expect(triage.signature, startsWith('triage|'));
    });

    test('reports no route targeting for a bare /opd path', () {
      final OpdWorkspaceQuery query = OpdWorkspaceQuery.fromUri(
        Uri.parse('/opd'),
      );

      expect(query.hasRouteTargeting, isFalse);
      expect(query.section, OpdWorkspaceSection.all);
    });
  });
}

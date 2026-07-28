import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';

void main() {
  group('IntegrationWorkspaceQuery.fromUri', () {
    test(
      'parses section=webhooks into IntegrationWorkspaceFilter.webhooks',
      () {
        final IntegrationWorkspaceQuery query =
            IntegrationWorkspaceQuery.fromUri(
              Uri.parse('/integrations?section=webhooks'),
            );

        expect(query.filter, IntegrationWorkspaceFilter.webhooks);
        expect(query.hasRouteTargeting, isTrue);
      },
    );

    test('parses section=api-keys into IntegrationWorkspaceFilter.apiKeys', () {
      final IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?section=api-keys'),
      );

      expect(query.filter, IntegrationWorkspaceFilter.apiKeys);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses section=logs into IntegrationWorkspaceFilter.logs', () {
      final IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?section=logs'),
      );

      expect(query.filter, IntegrationWorkspaceFilter.logs);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses section=interop into IntegrationWorkspaceFilter.interop', () {
      final IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?section=interop'),
      );

      expect(query.filter, IntegrationWorkspaceFilter.interop);
      expect(query.hasRouteTargeting, isTrue);
    });

    test(
      'parses section=integrations into IntegrationWorkspaceFilter.integrations',
      () {
        final IntegrationWorkspaceQuery query =
            IntegrationWorkspaceQuery.fromUri(
              Uri.parse('/integrations?section=integrations'),
            );

        expect(query.filter, IntegrationWorkspaceFilter.integrations);
        expect(query.hasRouteTargeting, isTrue);
      },
    );

    test('defaults to filter.all when no section is provided', () {
      final IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations'),
      );

      expect(query.filter, IntegrationWorkspaceFilter.all);
      expect(query.search, isEmpty);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('accepts alternate aliases for section parameter', () {
      final IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?kind=api-keys'),
      );

      expect(query.filter, IntegrationWorkspaceFilter.apiKeys);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses search from q alias', () {
      final IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?section=webhooks&q=payment'),
      );

      expect(query.filter, IntegrationWorkspaceFilter.webhooks);
      expect(query.search, 'payment');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('trims whitespace and treats blank values as absent', () {
      final IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?section=%20%20&search=%20%20'),
      );

      expect(query.filter, IntegrationWorkspaceFilter.all);
      expect(query.search, isEmpty);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('accepts section value aliases for apikeys', () {
      for (final String alias in <String>[
        'api-keys',
        'apikeys',
        'api_keys',
        'keys',
      ]) {
        final IntegrationWorkspaceQuery query =
            IntegrationWorkspaceQuery.fromUri(
              Uri.parse('/integrations?section=$alias'),
            );

        expect(
          query.filter,
          IntegrationWorkspaceFilter.apiKeys,
          reason: 'alias "$alias" should resolve to apiKeys',
        );
      }
    });

    test('accepts section value aliases for webhooks', () {
      for (final String alias in <String>['webhooks', 'webhook', 'hooks']) {
        final IntegrationWorkspaceQuery query =
            IntegrationWorkspaceQuery.fromUri(
              Uri.parse('/integrations?section=$alias'),
            );

        expect(
          query.filter,
          IntegrationWorkspaceFilter.webhooks,
          reason: 'alias "$alias" should resolve to webhooks',
        );
      }
    });

    test('accepts section value aliases for interop', () {
      for (final String alias in <String>[
        'interop',
        'interoperability',
        'fhir',
        'hl7',
      ]) {
        final IntegrationWorkspaceQuery query =
            IntegrationWorkspaceQuery.fromUri(
              Uri.parse('/integrations?section=$alias'),
            );

        expect(
          query.filter,
          IntegrationWorkspaceFilter.interop,
          reason: 'alias "$alias" should resolve to interop',
        );
      }
    });
  });

  group('IntegrationWorkspaceQuery.signature', () {
    test('produces deterministic signature', () {
      const IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery(
        filter: IntegrationWorkspaceFilter.logs,
      );

      expect(query.signature, 'logs||');
    });

    test('signature changes with filter', () {
      const IntegrationWorkspaceQuery a = IntegrationWorkspaceQuery(
        filter: IntegrationWorkspaceFilter.logs,
      );
      const IntegrationWorkspaceQuery b = IntegrationWorkspaceQuery(
        filter: IntegrationWorkspaceFilter.apiKeys,
      );

      expect(a.signature, isNot(b.signature));
    });

    test('signature changes with search', () {
      const IntegrationWorkspaceQuery a = IntegrationWorkspaceQuery(
        search: 'abc',
      );
      const IntegrationWorkspaceQuery b = IntegrationWorkspaceQuery(
        search: 'xyz',
      );

      expect(a.signature, isNot(b.signature));
    });

    test('signature changes with statusFilter', () {
      const IntegrationWorkspaceQuery a = IntegrationWorkspaceQuery(
        filter: IntegrationWorkspaceFilter.integrations,
        statusFilter: IntegrationWorkspaceFilter.active,
      );
      const IntegrationWorkspaceQuery b = IntegrationWorkspaceQuery(
        filter: IntegrationWorkspaceFilter.integrations,
        statusFilter: IntegrationWorkspaceFilter.failed,
      );

      expect(a.signature, isNot(b.signature));
    });

    test('same parameters produce same signature', () {
      final IntegrationWorkspaceQuery a = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?section=webhooks&search=test'),
      );
      final IntegrationWorkspaceQuery b = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?filter=webhooks&q=test'),
      );

      expect(a.signature, b.signature);
    });
  });

  group('IntegrationWorkspaceQuery.statusFilter', () {
    test('parses status from URI without changing section', () {
      final IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?section=integrations&status=active'),
      );

      expect(query.filter, IntegrationWorkspaceFilter.integrations);
      expect(query.statusFilter, IntegrationWorkspaceFilter.active);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('section and status filters combine in workItems', () {
      const IntegrationWorkspaceState state = IntegrationWorkspaceState(
        query: IntegrationWorkspaceQuery(
          filter: IntegrationWorkspaceFilter.integrations,
          statusFilter: IntegrationWorkspaceFilter.active,
        ),
        integrations: <IntegrationRecord>[
          IntegrationRecord(
            id: 'active-1',
            name: 'Active Feed',
            status: 'ACTIVE',
          ),
          IntegrationRecord(
            id: 'inactive-1',
            name: 'Inactive Feed',
            status: 'INACTIVE',
          ),
        ],
        apiKeys: <ApiKeyRecord>[
          ApiKeyRecord(
            id: 'key-1',
            name: 'Active Key',
            userId: 'user-1',
            isActive: true,
          ),
        ],
      );

      expect(state.workItems.map((IntegrationWorkItem i) => i.id), <String>[
        'active-1',
      ]);
    });
  });

  group('IntegrationWorkspaceQuery.hasRouteTargeting', () {
    test('returns false for default query', () {
      const IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery();

      expect(query.hasRouteTargeting, isFalse);
    });

    test('returns true when search is provided', () {
      const IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery(
        search: 'test',
      );

      expect(query.hasRouteTargeting, isTrue);
    });

    test('returns true when filter is not all', () {
      const IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery(
        filter: IntegrationWorkspaceFilter.apiKeys,
      );

      expect(query.hasRouteTargeting, isTrue);
    });

    test('returns true when statusFilter is set', () {
      const IntegrationWorkspaceQuery query = IntegrationWorkspaceQuery(
        statusFilter: IntegrationWorkspaceFilter.warning,
      );

      expect(query.hasRouteTargeting, isTrue);
    });
  });

  group('IntegrationDeskSection', () {
    test('enum has exactly 5 values', () {
      expect(IntegrationDeskSection.values.length, 5);
    });

    test('enum values match expected names', () {
      expect(
        IntegrationDeskSection.values.map((IntegrationDeskSection s) => s.name),
        <String>['integrations', 'apiKeys', 'webhooks', 'logs', 'interop'],
      );
    });
  });
}

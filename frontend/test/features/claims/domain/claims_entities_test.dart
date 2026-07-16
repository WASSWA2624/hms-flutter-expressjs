import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';

void main() {
  group('ClaimsWorkspaceQuery', () {
    test('parses section and search deep links', () {
      final ClaimsWorkspaceQuery query = ClaimsWorkspaceQuery.fromUri(
        Uri.parse('/claims?section=active-claims&search=Ada&q=ignored'),
      );

      expect(query.section, 'active-claims');
      expect(query.search, 'Ada');
      expect(query.hasRouteTargeting, isTrue);
      expect(query.signature, contains('active-claims'));
    });

    test('accepts section aliases panel, filter, and tab', () {
      expect(
        ClaimsWorkspaceQuery.fromUri(
          Uri.parse('/claims?panel=settled'),
        ).section,
        'settled',
      );
      expect(
        ClaimsWorkspaceQuery.fromUri(
          Uri.parse('/claims?filter=insurance-setup'),
        ).section,
        'insurance-setup',
      );
      expect(
        ClaimsWorkspaceQuery.fromUri(
          Uri.parse('/claims?tab=authorizations'),
        ).section,
        'authorizations',
      );
    });

    test('empty uri has no route targeting', () {
      final ClaimsWorkspaceQuery query = ClaimsWorkspaceQuery.fromUri(
        Uri.parse('/claims'),
      );

      expect(query.section, isEmpty);
      expect(query.hasRouteTargeting, isFalse);
    });
  });

  group('ClaimsDeskSection helpers', () {
    test('maps query values to desk sections', () {
      expect(
        claimsDeskSectionFromQuery('authorizations'),
        ClaimsDeskSection.authorizations,
      );
      expect(
        claimsDeskSectionFromQuery('active-claims'),
        ClaimsDeskSection.activeClaims,
      );
      expect(claimsDeskSectionFromQuery('settled'), ClaimsDeskSection.settled);
      expect(
        claimsDeskSectionFromQuery('insurance-setup'),
        ClaimsDeskSection.insuranceSetup,
      );
      expect(
        claimsDeskSectionFromQuery('unknown'),
        ClaimsDeskSection.authorizations,
      );
    });

    test('maps desk sections back to query values', () {
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.authorizations),
        'authorizations',
      );
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.activeClaims),
        'active-claims',
      );
      expect(claimsDeskSectionToQuery(ClaimsDeskSection.settled), 'settled');
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.insuranceSetup),
        'insurance-setup',
      );
    });
  });
}

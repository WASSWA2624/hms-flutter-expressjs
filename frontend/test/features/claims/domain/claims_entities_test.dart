import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';

void main() {
  group('ClaimsWorkspaceQuery', () {
    test('parses section and search deep links', () {
      final ClaimsWorkspaceQuery query = ClaimsWorkspaceQuery.fromUri(
        Uri.parse('/claims?section=submitted&search=Ada&q=ignored'),
      );

      expect(query.section, 'submitted');
      expect(query.search, 'Ada');
      expect(query.hasRouteTargeting, isTrue);
      expect(query.signature, contains('submitted'));
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
    test('maps leaf and legacy query values to desk sections', () {
      expect(
        claimsDeskSectionFromQuery('authorizations'),
        ClaimsDeskSection.authPending,
      );
      expect(
        claimsDeskSectionFromQuery('auth-pending'),
        ClaimsDeskSection.authPending,
      );
      expect(
        claimsDeskSectionFromQuery('auth-approved'),
        ClaimsDeskSection.authApproved,
      );
      expect(
        claimsDeskSectionFromQuery('auth-denied'),
        ClaimsDeskSection.authDenied,
      );
      expect(
        claimsDeskSectionFromQuery('auth-expired'),
        ClaimsDeskSection.authExpired,
      );
      expect(
        claimsDeskSectionFromQuery('active-claims'),
        ClaimsDeskSection.submitted,
      );
      expect(
        claimsDeskSectionFromQuery('active_claims'),
        ClaimsDeskSection.submitted,
      );
      expect(
        claimsDeskSectionFromQuery('submitted'),
        ClaimsDeskSection.submitted,
      );
      expect(
        claimsDeskSectionFromQuery('approved'),
        ClaimsDeskSection.approved,
      );
      expect(
        claimsDeskSectionFromQuery('partial-claims'),
        ClaimsDeskSection.partialClaims,
      );
      expect(
        claimsDeskSectionFromQuery('claim-rejected'),
        ClaimsDeskSection.claimRejected,
      );
      expect(claimsDeskSectionFromQuery('settled'), ClaimsDeskSection.settled);
      expect(
        claimsDeskSectionFromQuery('insurance-setup'),
        ClaimsDeskSection.insuranceSetup,
      );
      expect(
        claimsDeskSectionFromQuery('insurance_setup'),
        ClaimsDeskSection.insuranceSetup,
      );
      expect(
        claimsDeskSectionFromQuery('ACTIVE-CLAIMS'),
        ClaimsDeskSection.submitted,
      );
      expect(
        claimsDeskSectionFromQuery('unknown'),
        ClaimsDeskSection.authPending,
      );
    });

    test('maps desk sections back to leaf query values', () {
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.authPending),
        'auth-pending',
      );
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.authApproved),
        'auth-approved',
      );
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.authDenied),
        'auth-denied',
      );
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.authExpired),
        'auth-expired',
      );
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.submitted),
        'submitted',
      );
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.approved),
        'approved',
      );
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.partialClaims),
        'partial-claims',
      );
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.claimRejected),
        'claim-rejected',
      );
      expect(claimsDeskSectionToQuery(ClaimsDeskSection.settled), 'settled');
      expect(
        claimsDeskSectionToQuery(ClaimsDeskSection.insuranceSetup),
        'insurance-setup',
      );
    });

    test('classifies authorization vs claim scoped leaves', () {
      expect(
        claimsDeskSectionIsAuthorizationScoped(ClaimsDeskSection.authPending),
        isTrue,
      );
      expect(
        claimsDeskSectionIsAuthorizationScoped(ClaimsDeskSection.submitted),
        isFalse,
      );
      expect(
        claimsDeskSectionIsClaimScoped(ClaimsDeskSection.claimRejected),
        isTrue,
      );
      expect(
        claimsDeskSectionIsClaimScoped(ClaimsDeskSection.authDenied),
        isFalse,
      );
    });
  });
}

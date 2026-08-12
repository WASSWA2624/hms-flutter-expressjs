import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/widgets/claims_scope_navigation.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  const ClaimsWorkspaceSummary summary = ClaimsWorkspaceSummary(
    authorizationPendingCount: 3,
    authorizationApprovedCount: 2,
    submittedClaimsCount: 4,
    approvedClaimsCount: 1,
    partialClaimsCount: 1,
    rejectedResubmissionCount: 1,
    paidClosedCount: 7,
  );

  ClaimsWorkspaceState stateFor({
    ClaimsQueueFilter filter = ClaimsQueueFilter.authorizationPending,
    String search = '',
    int? totalItemCount,
    int itemCount = 0,
  }) {
    return ClaimsWorkspaceState(
      query: ClaimsQueueQuery(filter: filter, search: search),
      summary: summary,
      queue: AppPage<ClaimsQueueItem>(
        items: List<ClaimsQueueItem>.generate(
          itemCount,
          (int index) => ClaimsQueueItem.authorization(
            PreAuthorizationRecord(
              id: 'auth-$index',
              displayId: 'AUTH-$index',
              coveragePlanId: 'plan',
              coveragePlanDisplayId: 'PLAN',
              status: 'PENDING',
            ),
          ),
        ),
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: totalItemCount,
      ),
    );
  }

  test('sibling badges use dedicated per-leaf summary totals', () {
    final ClaimsWorkspaceState state = stateFor();

    expect(
      claimsSectionTabCount(state, ClaimsDeskSection.authPending),
      3,
    );
    expect(
      claimsSectionTabCount(state, ClaimsDeskSection.authApproved),
      2,
    );
    expect(claimsSectionTabCount(state, ClaimsDeskSection.authDenied), 0);
    expect(claimsSectionTabCount(state, ClaimsDeskSection.authExpired), 0);
    expect(claimsSectionTabCount(state, ClaimsDeskSection.submitted), 4);
    expect(claimsSectionTabCount(state, ClaimsDeskSection.approved), 1);
    expect(claimsSectionTabCount(state, ClaimsDeskSection.partialClaims), 1);
    expect(claimsSectionTabCount(state, ClaimsDeskSection.claimRejected), 1);
    expect(claimsSectionTabCount(state, ClaimsDeskSection.settled), 7);
    expect(
      claimsSectionTabCount(state, ClaimsDeskSection.insuranceSetup),
      isNull,
    );
  });

  test('active tab uses filtered total when search or filter narrows', () {
    final ClaimsWorkspaceState narrowed = stateFor(
      search: 'AUTH',
      totalItemCount: 1,
      itemCount: 1,
    );
    expect(
      claimsSectionTabCount(
        narrowed,
        ClaimsDeskSection.authPending,
        activeSection: ClaimsDeskSection.authPending,
      ),
      1,
    );

    final ClaimsWorkspaceState filterNarrowed = stateFor(
      filter: ClaimsQueueFilter.authorizationApproved,
      totalItemCount: 2,
      itemCount: 2,
    );
    expect(
      claimsSectionTabCount(
        filterNarrowed,
        ClaimsDeskSection.authPending,
        activeSection: ClaimsDeskSection.authPending,
      ),
      2,
    );
    // Sibling leaf keeps unfiltered summary total.
    expect(
      claimsSectionTabCount(
        filterNarrowed,
        ClaimsDeskSection.authApproved,
        activeSection: ClaimsDeskSection.authPending,
      ),
      2,
    );
  });

  test('active tab keeps scope total when filter matches section default', () {
    final ClaimsWorkspaceState state = stateFor(
      filter: ClaimsQueueFilter.authorizationPending,
      totalItemCount: 99,
      itemCount: 12,
    );
    expect(
      claimsSectionTabCount(
        state,
        ClaimsDeskSection.authPending,
        activeSection: ClaimsDeskSection.authPending,
      ),
      3,
    );
  });

  test('default filters and count tones match leaf scopes', () {
    expect(
      claimsDefaultFilterForSection(ClaimsDeskSection.authPending),
      ClaimsQueueFilter.authorizationPending,
    );
    expect(
      claimsDefaultFilterForSection(ClaimsDeskSection.submitted),
      ClaimsQueueFilter.claimSubmitted,
    );
    expect(
      claimsDefaultFilterForSection(ClaimsDeskSection.authDenied),
      ClaimsQueueFilter.authorizationDenied,
    );
    expect(
      claimsSectionCountTone(ClaimsDeskSection.authPending),
      AppTabCountTone.warning,
    );
    expect(
      claimsSectionCountTone(ClaimsDeskSection.submitted),
      AppTabCountTone.warning,
    );
    expect(
      claimsSectionCountTone(ClaimsDeskSection.settled),
      AppTabCountTone.info,
    );
  });
}

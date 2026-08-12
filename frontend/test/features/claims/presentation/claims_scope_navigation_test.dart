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

  test('sibling badges use dedicated summary scope totals', () {
    final ClaimsWorkspaceState state = stateFor();

    expect(
      claimsSectionTabCount(state, ClaimsDeskSection.authorizations),
      5,
    );
    expect(
      claimsSectionTabCount(state, ClaimsDeskSection.activeClaims),
      7,
    );
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
        ClaimsDeskSection.authorizations,
        activeSection: ClaimsDeskSection.authorizations,
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
        ClaimsDeskSection.authorizations,
        activeSection: ClaimsDeskSection.authorizations,
      ),
      2,
    );
  });

  test('active tab keeps scope total on default filter without search', () {
    final ClaimsWorkspaceState state = stateFor(totalItemCount: 1, itemCount: 1);
    expect(
      claimsSectionTabCount(
        state,
        ClaimsDeskSection.authorizations,
        activeSection: ClaimsDeskSection.authorizations,
      ),
      5,
    );
  });

  test('active tab falls back to scope total when filtered total is null', () {
    final ClaimsWorkspaceState narrowed = stateFor(
      search: 'AUTH',
      totalItemCount: null,
      itemCount: 1,
    );
    expect(
      claimsSectionTabCount(
        narrowed,
        ClaimsDeskSection.authorizations,
        activeSection: ClaimsDeskSection.authorizations,
      ),
      5,
    );
  });

  test('count tones follow urgency policy', () {
    expect(
      claimsSectionCountTone(ClaimsDeskSection.authorizations),
      AppTabCountTone.warning,
    );
    expect(
      claimsSectionCountTone(ClaimsDeskSection.activeClaims),
      AppTabCountTone.warning,
    );
    expect(
      claimsSectionCountTone(ClaimsDeskSection.settled),
      AppTabCountTone.info,
    );
    expect(
      claimsSectionCountTone(ClaimsDeskSection.insuranceSetup),
      AppTabCountTone.info,
    );
  });
}

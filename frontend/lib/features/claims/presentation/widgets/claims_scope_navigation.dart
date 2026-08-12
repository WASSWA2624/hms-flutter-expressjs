import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Default queue filter applied when entering a desk section.
ClaimsQueueFilter claimsDefaultFilterForSection(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.authorizations => ClaimsQueueFilter.authorizationPending,
    ClaimsDeskSection.activeClaims => ClaimsQueueFilter.claimSubmitted,
    ClaimsDeskSection.settled => ClaimsQueueFilter.claimPaid,
    ClaimsDeskSection.insuranceSetup => ClaimsQueueFilter.all,
  };
}

/// Dedicated unfiltered scope total from workspace summary (sibling model).
int claimsSectionScopeTotal(
  ClaimsWorkspaceState state,
  ClaimsDeskSection section,
) {
  return switch (section) {
    ClaimsDeskSection.authorizations =>
      state.authorizationPendingCount + state.authorizationApprovedCount,
    ClaimsDeskSection.activeClaims =>
      state.submittedClaimsCount +
          state.approvedClaimsCount +
          state.partialClaimsCount +
          state.rejectedResubmissionCount,
    ClaimsDeskSection.settled => state.paidClosedCount,
    // Insurance Setup is a catalog hub — callers omit the badge (`count: null`).
    ClaimsDeskSection.insuranceSetup => 0,
  };
}

bool claimsQueueQueryNarrowed(
  ClaimsQueueQuery query,
  ClaimsDeskSection section,
) {
  if (query.search.trim().isNotEmpty) {
    return true;
  }
  return query.filter != claimsDefaultFilterForSection(section);
}

/// Sibling-count model: dedicated unfiltered summary scope totals.
/// Active queue tab with search / advanced filters uses the filtered
/// [ClaimsWorkspaceState.queue] `totalItemCount`.
///
/// Returns `null` for Insurance Setup so the strip omits count chrome.
int? claimsSectionTabCount(
  ClaimsWorkspaceState state,
  ClaimsDeskSection section, {
  ClaimsDeskSection? activeSection,
}) {
  if (section == ClaimsDeskSection.insuranceSetup) {
    return null;
  }
  final int scopeTotal = claimsSectionScopeTotal(state, section);
  if (activeSection == null || section != activeSection) {
    return scopeTotal;
  }
  if (!claimsQueueQueryNarrowed(state.query, section)) {
    return scopeTotal;
  }
  return state.queue.totalItemCount ?? state.queue.items.length;
}

AppTabCountTone claimsSectionCountTone(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.authorizations ||
    ClaimsDeskSection.activeClaims => AppTabCountTone.warning,
    ClaimsDeskSection.settled ||
    ClaimsDeskSection.insuranceSetup => AppTabCountTone.info,
  };
}

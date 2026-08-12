import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

@immutable
final class ClaimsWorkspaceQuery {
  const ClaimsWorkspaceQuery({
    this.encounterId = '',
    this.patientId = '',
    this.action = '',
    this.search = '',
    this.section = '',
  });

  factory ClaimsWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return ClaimsWorkspaceQuery(
      encounterId: pick(<String>['encounterId', 'encounter_id', 'encounter']),
      patientId: pick(<String>['patientId', 'patient_id', 'patient']),
      action: pick(<String>['action']),
      search: pick(<String>['search', 'q']),
      section: pick(<String>['section', 'panel', 'filter', 'tab']),
    );
  }

  final String encounterId;
  final String patientId;
  final String action;
  final String search;
  final String section;

  bool get hasRouteTargeting =>
      encounterId.isNotEmpty ||
      patientId.isNotEmpty ||
      action.isNotEmpty ||
      search.isNotEmpty ||
      section.isNotEmpty;

  String get signature => '$encounterId|$patientId|$action|$search|$section';
}

/// Desk sections for the Claims workspace tab strip (independent leaf queues).
enum ClaimsDeskSection {
  authPending,
  authApproved,
  authDenied,
  authExpired,
  submitted,
  approved,
  partialClaims,
  claimRejected,
  settled,
  insuranceSetup,
}

/// Authorization queue leaves (pre-auth pending / approved / denied / expired).
bool claimsDeskSectionIsAuthorizationScoped(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.authPending ||
    ClaimsDeskSection.authApproved ||
    ClaimsDeskSection.authDenied ||
    ClaimsDeskSection.authExpired => true,
    _ => false,
  };
}

/// Active-claim queue leaves (submitted / approved / partial / rejected).
bool claimsDeskSectionIsClaimScoped(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.submitted ||
    ClaimsDeskSection.approved ||
    ClaimsDeskSection.partialClaims ||
    ClaimsDeskSection.claimRejected => true,
    _ => false,
  };
}

ClaimsDeskSection claimsDeskSectionFromQuery(String value) {
  switch (value.trim().toLowerCase()) {
    // Legacy parent deep links → first leaf of that family.
    case 'authorizations':
    case 'auth-pending':
    case 'auth_pending':
      return ClaimsDeskSection.authPending;
    case 'auth-approved':
    case 'auth_approved':
      return ClaimsDeskSection.authApproved;
    case 'auth-denied':
    case 'auth_denied':
      return ClaimsDeskSection.authDenied;
    case 'auth-expired':
    case 'auth_expired':
      return ClaimsDeskSection.authExpired;
    case 'active-claims':
    case 'active_claims':
    case 'submitted':
      return ClaimsDeskSection.submitted;
    case 'approved':
    case 'claim-approved':
    case 'claim_approved':
      return ClaimsDeskSection.approved;
    case 'partial-claims':
    case 'partial_claims':
    case 'partial':
      return ClaimsDeskSection.partialClaims;
    case 'claim-rejected':
    case 'claim_rejected':
    case 'rejected':
      return ClaimsDeskSection.claimRejected;
    case 'settled':
      return ClaimsDeskSection.settled;
    case 'insurance-setup':
    case 'insurance_setup':
      return ClaimsDeskSection.insuranceSetup;
    default:
      return ClaimsDeskSection.authPending;
  }
}

String claimsDeskSectionToQuery(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.authPending => 'auth-pending',
    ClaimsDeskSection.authApproved => 'auth-approved',
    ClaimsDeskSection.authDenied => 'auth-denied',
    ClaimsDeskSection.authExpired => 'auth-expired',
    ClaimsDeskSection.submitted => 'submitted',
    ClaimsDeskSection.approved => 'approved',
    ClaimsDeskSection.partialClaims => 'partial-claims',
    ClaimsDeskSection.claimRejected => 'claim-rejected',
    ClaimsDeskSection.settled => 'settled',
    ClaimsDeskSection.insuranceSetup => 'insurance-setup',
  };
}

enum ClaimsQueueKind { authorization, claim }

enum ClaimsQueueFilter {
  all,
  authorizationPending,
  authorizationApproved,
  authorizationDenied,
  authorizationExpired,
  claimSubmitted,
  claimApproved,
  claimPartial,
  claimRejected,
  claimPaid,
  claimCancelled,
}

@immutable
final class ClaimsQueueQuery {
  const ClaimsQueueQuery({
    this.search = '',
    this.filter = ClaimsQueueFilter.all,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final String search;
  final ClaimsQueueFilter filter;
  final AppPageRequest pageRequest;

  ClaimsQueueQuery copyWith({
    String? search,
    ClaimsQueueFilter? filter,
    AppPageRequest? pageRequest,
  }) {
    return ClaimsQueueQuery(
      search: search ?? this.search,
      filter: filter ?? this.filter,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class InsuranceCompanyOption {
  const InsuranceCompanyOption({
    required this.id,
    required this.displayId,
    this.name,
    this.code,
    this.isActive = true,
    this.schemeCount,
  });

  final String id;
  final String displayId;
  final String? name;
  final String? code;
  final bool isActive;
  final int? schemeCount;

  String get apiId => _firstNonEmpty(<String?>[displayId, id]) ?? id;

  String get title =>
      _firstNonEmpty(<String?>[name, code, displayId, id]) ?? id;
}

@immutable
final class CoveragePlanOption {
  const CoveragePlanOption({
    required this.id,
    required this.displayId,
    this.name,
    this.code,
    this.providerName,
    this.coveragePercentage,
    this.defaultCopayType,
    this.defaultCopayValue,
    this.status,
    this.insuranceCompanyId,
    this.insuranceCompanyName,
    this.insuranceCompanyCode,
    this.tenantDisplayId,
  });

  final String id;
  final String displayId;
  final String? name;
  final String? code;
  final String? providerName;
  final int? coveragePercentage;
  final String? defaultCopayType;
  final num? defaultCopayValue;
  final String? status;
  final String? insuranceCompanyId;
  final String? insuranceCompanyName;
  final String? insuranceCompanyCode;
  final String? tenantDisplayId;

  String get apiId => _firstNonEmpty(<String?>[displayId, id]) ?? id;

  String get title => _firstNonEmpty(<String?>[name, displayId, id]) ?? id;

  String? get subtitle {
    return _joinDisplay(<String?>[
      insuranceCompanyName ?? providerName,
      code,
      coveragePercentage == null ? null : '$coveragePercentage%',
      tenantDisplayId,
    ]);
  }
}

@immutable
final class ClaimInvoiceOption {
  const ClaimInvoiceOption({
    required this.id,
    required this.displayId,
    this.patientDisplayId,
    this.status,
    this.billingStatus,
    this.totalAmount,
    this.balanceDue,
    this.netPaidTotal,
    this.currency,
    this.issuedAt,
  });

  final String id;
  final String displayId;
  final String? patientDisplayId;
  final String? status;
  final String? billingStatus;
  final num? totalAmount;

  /// Outstanding balance from Billing financials (ledger SoR).
  final num? balanceDue;

  /// Net paid total from Billing financials after remittance / payments.
  final num? netPaidTotal;
  final String? currency;
  final DateTime? issuedAt;

  String get apiId => _firstNonEmpty(<String?>[displayId, id]) ?? id;

  String get title => _firstNonEmpty(<String?>[displayId, id]) ?? id;

  String? get subtitle {
    return _joinDisplay(<String?>[patientDisplayId, billingStatus ?? status]);
  }

  /// True when Billing reports a collectible patient residual.
  bool get hasCollectibleBalance {
    final num? due = balanceDue;
    return due != null && due > 0.009;
  }
}

@immutable
final class PreAuthorizationRecord {
  const PreAuthorizationRecord({
    required this.id,
    required this.displayId,
    required this.coveragePlanId,
    required this.coveragePlanDisplayId,
    required this.status,
    this.patientId,
    this.patientDisplayId,
    this.encounterId,
    this.encounterDisplayId,
    this.admissionId,
    this.admissionDisplayId,
    this.reason,
    this.approvedAmount,
    this.consumedAmount,
    this.notes,
    this.requestedAt,
    this.approvedAt,
    this.timelineAt,
  });

  final String id;
  final String displayId;
  final String coveragePlanId;
  final String coveragePlanDisplayId;
  final String status;
  final String? patientId;
  final String? patientDisplayId;
  final String? encounterId;
  final String? encounterDisplayId;
  final String? admissionId;
  final String? admissionDisplayId;
  final String? reason;
  final num? approvedAmount;
  final num? consumedAmount;
  final String? notes;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final DateTime? timelineAt;

  String get apiId => _firstNonEmpty(<String?>[displayId, id]) ?? id;

  num? get remainingAmount {
    if (approvedAmount == null) {
      return null;
    }
    return approvedAmount! - (consumedAmount ?? 0);
  }

  bool get isAuthorizationSufficient {
    final num? remaining = remainingAmount;
    if (remaining == null) {
      return status.toUpperCase() == 'APPROVED';
    }
    return status.toUpperCase() == 'APPROVED' && remaining > 0;
  }
}

@immutable
final class InsuranceClaimRecord {
  const InsuranceClaimRecord({
    required this.id,
    required this.displayId,
    required this.coveragePlanId,
    required this.coveragePlanDisplayId,
    required this.invoiceId,
    required this.invoiceDisplayId,
    required this.status,
    this.patientDisplayId,
    this.claimAmount,
    this.settlementAmount,
    this.payerReference,
    this.notes,
    this.submittedAt,
    this.resubmittedAt,
    this.timelineAt,
  });

  final String id;
  final String displayId;
  final String coveragePlanId;
  final String coveragePlanDisplayId;
  final String invoiceId;
  final String invoiceDisplayId;
  final String status;
  final String? patientDisplayId;
  final num? claimAmount;
  final num? settlementAmount;
  final String? payerReference;
  final String? notes;
  final DateTime? submittedAt;
  final DateTime? resubmittedAt;
  final DateTime? timelineAt;

  String get apiId => _firstNonEmpty(<String?>[displayId, id]) ?? id;
}

@immutable
final class ClaimsQueueItem {
  const ClaimsQueueItem.authorization(this.authorization) : claim = null;

  const ClaimsQueueItem.claim(this.claim) : authorization = null;

  final PreAuthorizationRecord? authorization;
  final InsuranceClaimRecord? claim;

  ClaimsQueueKind get kind {
    return authorization != null
        ? ClaimsQueueKind.authorization
        : ClaimsQueueKind.claim;
  }

  bool get isAuthorization => kind == ClaimsQueueKind.authorization;

  bool get isClaim => kind == ClaimsQueueKind.claim;

  String get id => authorization?.id ?? claim?.id ?? '';

  String get apiId => authorization?.apiId ?? claim?.apiId ?? id;

  String get displayId => authorization?.displayId ?? claim?.displayId ?? id;

  String get status => authorization?.status ?? claim?.status ?? '';

  String get coveragePlanDisplayId {
    return authorization?.coveragePlanDisplayId ??
        claim?.coveragePlanDisplayId ??
        '';
  }

  String? get invoiceDisplayId => claim?.invoiceDisplayId;

  String? get patientDisplayId =>
      authorization?.patientDisplayId ?? claim?.patientDisplayId;

  DateTime? get timelineAt {
    return authorization?.timelineAt ??
        authorization?.approvedAt ??
        authorization?.requestedAt ??
        claim?.timelineAt ??
        claim?.submittedAt;
  }

  String get queueKey => '${kind.name}:$apiId';
}

@immutable
final class ClaimsQueueDetail {
  const ClaimsQueueDetail({
    required this.item,
    this.authorization,
    this.claim,
    this.coveragePlan,
    this.invoice,
    this.coverageUnavailable = false,
    this.invoiceUnavailable = false,
  });

  final ClaimsQueueItem item;
  final PreAuthorizationRecord? authorization;
  final InsuranceClaimRecord? claim;
  final CoveragePlanOption? coveragePlan;
  final ClaimInvoiceOption? invoice;
  final bool coverageUnavailable;
  final bool invoiceUnavailable;

  bool get isAuthorization => item.isAuthorization;

  bool get isClaim => item.isClaim;
}

@immutable
final class ClaimsReferenceData {
  const ClaimsReferenceData({
    this.insuranceCompanies = const <InsuranceCompanyOption>[],
    this.coveragePlans = const <CoveragePlanOption>[],
    this.invoices = const <ClaimInvoiceOption>[],
    this.coverageUnavailable = false,
    this.invoicesUnavailable = false,
  });

  final List<InsuranceCompanyOption> insuranceCompanies;
  final List<CoveragePlanOption> coveragePlans;
  final List<ClaimInvoiceOption> invoices;
  final bool coverageUnavailable;
  final bool invoicesUnavailable;
}

@immutable
final class ClaimsWorkspaceSummary {
  const ClaimsWorkspaceSummary({
    this.authorizationPendingCount = 0,
    this.authorizationApprovedCount = 0,
    this.submittedClaimsCount = 0,
    this.approvedClaimsCount = 0,
    this.partialClaimsCount = 0,
    this.rejectedResubmissionCount = 0,
    this.paidClosedCount = 0,
    this.eligibilityPendingCount = 0,
    this.claimsToSubmitCount = 0,
    this.readyToSettleCount = 0,
    this.settledCount = 0,
    this.workloadCount = 0,
  });

  final int authorizationPendingCount;
  final int authorizationApprovedCount;
  final int submittedClaimsCount;
  final int approvedClaimsCount;
  final int partialClaimsCount;
  final int rejectedResubmissionCount;
  final int paidClosedCount;
  final int eligibilityPendingCount;
  final int claimsToSubmitCount;
  final int readyToSettleCount;
  final int settledCount;
  final int workloadCount;
}

@immutable
final class ClaimsWorkspaceState {
  const ClaimsWorkspaceState({
    required this.query,
    required this.queue,
    this.referenceData = const ClaimsReferenceData(),
    this.summary,
    this.selectedDetail,
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final ClaimsQueueQuery query;
  final AppPage<ClaimsQueueItem> queue;
  final ClaimsReferenceData referenceData;

  /// Authoritative counts from the backend `claims-workspace` aggregator.
  /// When present these are used in preference to the queue-page heuristics so
  /// summary cards reflect the full tenant/facility scope, not just the loaded
  /// page.
  final ClaimsWorkspaceSummary? summary;
  final ClaimsQueueDetail? selectedDetail;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get authorizationPendingCount {
    return summary?.authorizationPendingCount ??
        _count(
          kind: ClaimsQueueKind.authorization,
          statuses: const <String>{'PENDING'},
        );
  }

  int get authorizationApprovedCount {
    return summary?.authorizationApprovedCount ??
        _count(
          kind: ClaimsQueueKind.authorization,
          statuses: const <String>{'APPROVED'},
        );
  }

  int get submittedClaimsCount {
    return summary?.submittedClaimsCount ??
        _count(
          kind: ClaimsQueueKind.claim,
          statuses: const <String>{'SUBMITTED'},
        );
  }

  int get approvedClaimsCount {
    return summary?.approvedClaimsCount ??
        _count(
          kind: ClaimsQueueKind.claim,
          statuses: const <String>{'APPROVED'},
        );
  }

  int get partialClaimsCount {
    return summary?.partialClaimsCount ??
        _count(
          kind: ClaimsQueueKind.claim,
          statuses: const <String>{'PARTIAL'},
        );
  }

  int get eligibilityPendingCount {
    return summary?.eligibilityPendingCount ?? 0;
  }

  int get claimsToSubmitCount {
    return summary?.claimsToSubmitCount ?? 0;
  }

  int get readyToSettleCount {
    return summary?.readyToSettleCount ?? 0;
  }

  int get rejectedResubmissionCount {
    return summary?.rejectedResubmissionCount ??
        queue.items.where((ClaimsQueueItem item) {
          return (item.isAuthorization &&
                  item.status.toUpperCase() == 'DENIED') ||
              (item.isClaim && item.status.toUpperCase() == 'REJECTED');
        }).length;
  }

  int get paidClosedCount {
    return summary?.paidClosedCount ??
        _count(
          kind: ClaimsQueueKind.claim,
          statuses: const <String>{'PAID', 'CANCELLED'},
        );
  }

  int get workloadCount {
    return summary?.workloadCount ??
        queue.items.where((ClaimsQueueItem item) {
          final String status = item.status.toUpperCase();
          return switch (item.kind) {
            ClaimsQueueKind.authorization =>
              status == 'PENDING' || status == 'DENIED',
            ClaimsQueueKind.claim =>
              status == 'SUBMITTED' ||
                  status == 'APPROVED' ||
                  status == 'REJECTED',
          };
        }).length;
  }

  ClaimsWorkspaceState copyWith({
    ClaimsQueueQuery? query,
    AppPage<ClaimsQueueItem>? queue,
    ClaimsReferenceData? referenceData,
    ClaimsWorkspaceSummary? summary,
    ClaimsQueueDetail? selectedDetail,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedDetail = false,
    bool clearLastFailure = false,
  }) {
    return ClaimsWorkspaceState(
      query: query ?? this.query,
      queue: queue ?? this.queue,
      referenceData: referenceData ?? this.referenceData,
      summary: summary ?? this.summary,
      selectedDetail: clearSelectedDetail
          ? null
          : selectedDetail ?? this.selectedDetail,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  int _count({required ClaimsQueueKind kind, required Set<String> statuses}) {
    return queue.items.where((ClaimsQueueItem item) {
      return item.kind == kind && statuses.contains(item.status.toUpperCase());
    }).length;
  }
}

String? preAuthorizationStatusForFilter(ClaimsQueueFilter filter) {
  return switch (filter) {
    ClaimsQueueFilter.authorizationPending => 'PENDING',
    ClaimsQueueFilter.authorizationApproved => 'APPROVED',
    ClaimsQueueFilter.authorizationDenied => 'DENIED',
    ClaimsQueueFilter.authorizationExpired => 'EXPIRED',
    _ => null,
  };
}

String? insuranceClaimStatusForFilter(ClaimsQueueFilter filter) {
  return switch (filter) {
    ClaimsQueueFilter.claimSubmitted => 'SUBMITTED',
    ClaimsQueueFilter.claimApproved => 'APPROVED',
    ClaimsQueueFilter.claimPartial => 'PARTIAL',
    ClaimsQueueFilter.claimRejected => 'REJECTED',
    ClaimsQueueFilter.claimPaid => 'PAID',
    ClaimsQueueFilter.claimCancelled => 'CANCELLED',
    _ => null,
  };
}

/// Maps a queue filter to the backend aggregator `kind` parameter.
/// Returns `AUTHORIZATION`, `CLAIM`, or `null` (both kinds) for the work-items
/// endpoint exposed by the `claims-workspace` module.
String? claimsFilterKind(ClaimsQueueFilter filter) {
  if (filter == ClaimsQueueFilter.all) {
    return null;
  }
  if (preAuthorizationStatusForFilter(filter) != null) {
    return 'AUTHORIZATION';
  }
  if (insuranceClaimStatusForFilter(filter) != null) {
    return 'CLAIM';
  }
  return null;
}

/// Maps a queue filter to the backend aggregator `status` parameter.
String? claimsFilterStatus(ClaimsQueueFilter filter) {
  return preAuthorizationStatusForFilter(filter) ??
      insuranceClaimStatusForFilter(filter);
}

bool filterIncludesAuthorizations(ClaimsQueueFilter filter) {
  return filter == ClaimsQueueFilter.all ||
      preAuthorizationStatusForFilter(filter) != null;
}

bool filterIncludesClaims(ClaimsQueueFilter filter) {
  return filter == ClaimsQueueFilter.all ||
      insuranceClaimStatusForFilter(filter) != null;
}

bool matchesClaimsSearch(ClaimsQueueItem item, String query) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  final List<String> values = <String>[
    item.displayId,
    item.status,
    item.coveragePlanDisplayId,
    ?item.invoiceDisplayId,
    ?item.patientDisplayId,
  ];

  return values.any((String value) => value.toLowerCase().contains(normalized));
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return null;
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

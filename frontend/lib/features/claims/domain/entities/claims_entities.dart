import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum ClaimsQueueKind { authorization, claim }

enum ClaimsQueueFilter {
  all,
  authorizationPending,
  authorizationApproved,
  authorizationDenied,
  authorizationExpired,
  claimSubmitted,
  claimApproved,
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
final class CoveragePlanOption {
  const CoveragePlanOption({
    required this.id,
    required this.displayId,
    this.name,
    this.providerName,
    this.coveragePercentage,
    this.tenantDisplayId,
  });

  final String id;
  final String displayId;
  final String? name;
  final String? providerName;
  final int? coveragePercentage;
  final String? tenantDisplayId;

  String get apiId => _firstNonEmpty(<String?>[displayId, id]) ?? id;

  String get title => _firstNonEmpty(<String?>[name, displayId, id]) ?? id;

  String? get subtitle {
    return _joinDisplay(<String?>[
      providerName,
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
    this.currency,
    this.issuedAt,
  });

  final String id;
  final String displayId;
  final String? patientDisplayId;
  final String? status;
  final String? billingStatus;
  final num? totalAmount;
  final String? currency;
  final DateTime? issuedAt;

  String get apiId => _firstNonEmpty(<String?>[displayId, id]) ?? id;

  String get title => _firstNonEmpty(<String?>[displayId, id]) ?? id;

  String? get subtitle {
    return _joinDisplay(<String?>[patientDisplayId, billingStatus ?? status]);
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
    this.requestedAt,
    this.approvedAt,
    this.timelineAt,
  });

  final String id;
  final String displayId;
  final String coveragePlanId;
  final String coveragePlanDisplayId;
  final String status;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final DateTime? timelineAt;

  String get apiId => _firstNonEmpty(<String?>[displayId, id]) ?? id;
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
    this.submittedAt,
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
  final DateTime? submittedAt;
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

  String? get patientDisplayId => claim?.patientDisplayId;

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
    this.coveragePlans = const <CoveragePlanOption>[],
    this.invoices = const <ClaimInvoiceOption>[],
    this.coverageUnavailable = false,
    this.invoicesUnavailable = false,
  });

  final List<CoveragePlanOption> coveragePlans;
  final List<ClaimInvoiceOption> invoices;
  final bool coverageUnavailable;
  final bool invoicesUnavailable;
}

@immutable
final class ClaimsWorkspaceState {
  const ClaimsWorkspaceState({
    required this.query,
    required this.queue,
    this.referenceData = const ClaimsReferenceData(),
    this.selectedDetail,
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final ClaimsQueueQuery query;
  final AppPage<ClaimsQueueItem> queue;
  final ClaimsReferenceData referenceData;
  final ClaimsQueueDetail? selectedDetail;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get authorizationPendingCount {
    return _count(
      kind: ClaimsQueueKind.authorization,
      statuses: const <String>{'PENDING'},
    );
  }

  int get authorizationApprovedCount {
    return _count(
      kind: ClaimsQueueKind.authorization,
      statuses: const <String>{'APPROVED'},
    );
  }

  int get submittedClaimsCount {
    return _count(
      kind: ClaimsQueueKind.claim,
      statuses: const <String>{'SUBMITTED'},
    );
  }

  int get approvedClaimsCount {
    return _count(
      kind: ClaimsQueueKind.claim,
      statuses: const <String>{'APPROVED'},
    );
  }

  int get rejectedResubmissionCount {
    return queue.items.where((ClaimsQueueItem item) {
      return (item.isAuthorization && item.status.toUpperCase() == 'DENIED') ||
          (item.isClaim && item.status.toUpperCase() == 'REJECTED');
    }).length;
  }

  int get paidClosedCount {
    return _count(
      kind: ClaimsQueueKind.claim,
      statuses: const <String>{'PAID', 'CANCELLED'},
    );
  }

  int get workloadCount {
    return queue.items.where((ClaimsQueueItem item) {
      final String status = item.status.toUpperCase();
      return switch (item.kind) {
        ClaimsQueueKind.authorization =>
          status == 'PENDING' || status == 'DENIED',
        ClaimsQueueKind.claim =>
          status == 'SUBMITTED' || status == 'APPROVED' || status == 'REJECTED',
      };
    }).length;
  }

  ClaimsWorkspaceState copyWith({
    ClaimsQueueQuery? query,
    AppPage<ClaimsQueueItem>? queue,
    ClaimsReferenceData? referenceData,
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
    ClaimsQueueFilter.claimRejected => 'REJECTED',
    ClaimsQueueFilter.claimPaid => 'PAID',
    ClaimsQueueFilter.claimCancelled => 'CANCELLED',
    _ => null,
  };
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

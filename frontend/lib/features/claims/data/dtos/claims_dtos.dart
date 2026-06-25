import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef ClaimsJsonMap = Map<String, Object?>;

final class PreAuthorizationPageDto {
  const PreAuthorizationPageDto({required this.page});

  final AppPage<PreAuthorizationRecord> page;

  factory PreAuthorizationPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final ClaimsJsonMap response = _expectMap(responseData);
    final List<PreAuthorizationRecord> items = _list(response['data'])
        .map(PreAuthorizationDto.new)
        .map((PreAuthorizationDto dto) => dto.toEntity())
        .where((PreAuthorizationRecord item) => item.id.isNotEmpty)
        .toList(growable: false);

    return PreAuthorizationPageDto(
      page: AppPage<PreAuthorizationRecord>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class PreAuthorizationDto {
  const PreAuthorizationDto(this.json);

  final ClaimsJsonMap json;

  factory PreAuthorizationDto.fromResponse(Object? responseData) {
    final ClaimsJsonMap response = _expectMap(responseData);
    return PreAuthorizationDto(_map(response['data']));
  }

  PreAuthorizationRecord toEntity() {
    final String displayId =
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        _string(json['id']) ??
        '';
    final String id = _string(json['id']) ?? displayId;
    final String coveragePlanDisplayId =
        _string(json['coverage_plan_display_id']) ??
        _string(json['coverage_plan_id']) ??
        _string(_map(json['coverage_plan'])['human_friendly_id']) ??
        '';

    return PreAuthorizationRecord(
      id: id,
      displayId: displayId,
      coveragePlanId:
          _string(json['coverage_plan_id']) ?? coveragePlanDisplayId,
      coveragePlanDisplayId: coveragePlanDisplayId,
      status: _string(json['status']) ?? 'PENDING',
      patientId: _string(json['patient_id']),
      patientDisplayId: _string(json['patient_display_id']),
      encounterId: _string(json['encounter_id']),
      encounterDisplayId: _string(json['encounter_display_id']),
      admissionId: _string(json['admission_id']),
      admissionDisplayId: _string(json['admission_display_id']),
      reason: _string(json['reason']),
      approvedAmount: _number(json['approved_amount']),
      consumedAmount: _number(json['consumed_amount']),
      notes: _string(json['notes']),
      requestedAt: _date(json['requested_at']),
      approvedAt: _date(json['approved_at']),
      timelineAt: _date(json['timeline_at']),
    );
  }
}

final class InsuranceClaimPageDto {
  const InsuranceClaimPageDto({required this.page});

  final AppPage<InsuranceClaimRecord> page;

  factory InsuranceClaimPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final ClaimsJsonMap response = _expectMap(responseData);
    final List<InsuranceClaimRecord> items = _list(response['data'])
        .map(InsuranceClaimDto.new)
        .map((InsuranceClaimDto dto) => dto.toEntity())
        .where((InsuranceClaimRecord item) => item.id.isNotEmpty)
        .toList(growable: false);

    return InsuranceClaimPageDto(
      page: AppPage<InsuranceClaimRecord>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class InsuranceClaimDto {
  const InsuranceClaimDto(this.json);

  final ClaimsJsonMap json;

  factory InsuranceClaimDto.fromResponse(Object? responseData) {
    final ClaimsJsonMap response = _expectMap(responseData);
    return InsuranceClaimDto(_map(response['data']));
  }

  InsuranceClaimRecord toEntity() {
    final String displayId =
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        _string(json['id']) ??
        '';
    final String id = _string(json['id']) ?? displayId;
    final String coveragePlanDisplayId =
        _string(json['coverage_plan_display_id']) ??
        _string(json['coverage_plan_id']) ??
        _string(_map(json['coverage_plan'])['human_friendly_id']) ??
        '';
    final String invoiceDisplayId =
        _string(json['invoice_display_id']) ??
        _string(json['invoice_id']) ??
        _string(_map(json['invoice'])['human_friendly_id']) ??
        '';

    return InsuranceClaimRecord(
      id: id,
      displayId: displayId,
      coveragePlanId:
          _string(json['coverage_plan_id']) ?? coveragePlanDisplayId,
      coveragePlanDisplayId: coveragePlanDisplayId,
      invoiceId: _string(json['invoice_id']) ?? invoiceDisplayId,
      invoiceDisplayId: invoiceDisplayId,
      patientDisplayId: _string(json['patient_display_id']),
      status: _string(json['status']) ?? 'SUBMITTED',
      settlementAmount: _number(json['settlement_amount']),
      payerReference: _string(json['payer_reference']),
      notes: _string(json['notes']),
      submittedAt: _date(json['submitted_at']),
      resubmittedAt: _date(json['resubmitted_at']),
      timelineAt: _date(json['timeline_at']),
    );
  }
}

final class ClaimsWorkItemsPageDto {
  const ClaimsWorkItemsPageDto({required this.page});

  final AppPage<ClaimsQueueItem> page;

  factory ClaimsWorkItemsPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final ClaimsJsonMap response = _expectMap(responseData);
    final List<ClaimsQueueItem> items = _list(
      response['data'],
    ).map(_itemFromJson).whereType<ClaimsQueueItem>().toList(growable: false);

    return ClaimsWorkItemsPageDto(
      page: AppPage<ClaimsQueueItem>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }

  static ClaimsQueueItem? _itemFromJson(ClaimsJsonMap json) {
    final String type = (_string(json['type']) ?? '').toUpperCase();
    if (type == 'CLAIM') {
      final InsuranceClaimRecord claim = InsuranceClaimDto(json).toEntity();
      return claim.id.isEmpty ? null : ClaimsQueueItem.claim(claim);
    }

    final PreAuthorizationRecord authorization = PreAuthorizationDto(
      json,
    ).toEntity();
    return authorization.id.isEmpty
        ? null
        : ClaimsQueueItem.authorization(authorization);
  }
}

final class ClaimsWorkspaceSummaryDto {
  const ClaimsWorkspaceSummaryDto({required this.summary});

  final ClaimsWorkspaceSummary summary;

  factory ClaimsWorkspaceSummaryDto.fromResponse(Object? responseData) {
    final ClaimsJsonMap response = _expectMap(responseData);
    final ClaimsJsonMap data = _map(response['data']);
    final ClaimsJsonMap summary = _map(data['summary']);

    return ClaimsWorkspaceSummaryDto(
      summary: ClaimsWorkspaceSummary(
        authorizationPendingCount: _int(summary['authorization_pending']) ?? 0,
        authorizationApprovedCount:
            _int(summary['authorization_approved']) ?? 0,
        submittedClaimsCount: _int(summary['claims_submitted']) ?? 0,
        approvedClaimsCount: _int(summary['claims_approved']) ?? 0,
        rejectedResubmissionCount: _int(summary['denied_resubmission']) ?? 0,
        paidClosedCount: _int(summary['paid_closed']) ?? 0,
        workloadCount: _int(summary['workload']) ?? 0,
      ),
    );
  }
}

final class CoveragePlanPageDto {
  const CoveragePlanPageDto({required this.page});

  final AppPage<CoveragePlanOption> page;

  factory CoveragePlanPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final ClaimsJsonMap response = _expectMap(responseData);
    final List<CoveragePlanOption> items = _list(response['data'])
        .map(CoveragePlanDto.new)
        .map((CoveragePlanDto dto) => dto.toEntity())
        .where((CoveragePlanOption item) => item.id.isNotEmpty)
        .toList(growable: false);

    return CoveragePlanPageDto(
      page: AppPage<CoveragePlanOption>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class CoveragePlanDto {
  const CoveragePlanDto(this.json);

  final ClaimsJsonMap json;

  factory CoveragePlanDto.fromResponse(Object? responseData) {
    final ClaimsJsonMap response = _expectMap(responseData);
    return CoveragePlanDto(_map(response['data']));
  }

  CoveragePlanOption toEntity() {
    final String displayId =
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        _string(json['id']) ??
        '';
    return CoveragePlanOption(
      id: _string(json['id']) ?? displayId,
      displayId: displayId,
      name: _string(json['name']),
      providerName: _string(json['provider_name']),
      coveragePercentage: _int(json['coverage_percentage']),
      tenantDisplayId:
          _string(json['tenant_display_id']) ??
          _string(_map(json['tenant'])['human_friendly_id']) ??
          _string(json['tenant_id']),
    );
  }
}

final class ClaimInvoicePageDto {
  const ClaimInvoicePageDto({required this.page});

  final AppPage<ClaimInvoiceOption> page;

  factory ClaimInvoicePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final ClaimsJsonMap response = _expectMap(responseData);
    final List<ClaimInvoiceOption> items = _list(response['data'])
        .map(ClaimInvoiceDto.new)
        .map((ClaimInvoiceDto dto) => dto.toEntity())
        .where((ClaimInvoiceOption item) => item.id.isNotEmpty)
        .toList(growable: false);

    return ClaimInvoicePageDto(
      page: AppPage<ClaimInvoiceOption>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class ClaimInvoiceDto {
  const ClaimInvoiceDto(this.json);

  final ClaimsJsonMap json;

  factory ClaimInvoiceDto.fromResponse(Object? responseData) {
    final ClaimsJsonMap response = _expectMap(responseData);
    return ClaimInvoiceDto(_map(response['data']));
  }

  ClaimInvoiceOption toEntity() {
    final String displayId =
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        _string(json['id']) ??
        '';
    return ClaimInvoiceOption(
      id: _string(json['id']) ?? displayId,
      displayId: displayId,
      patientDisplayId:
          _string(json['patient_display_id']) ??
          _string(_map(json['patient'])['human_friendly_id']) ??
          _string(json['patient_id']),
      status: _string(json['status']),
      billingStatus: _string(json['billing_status']),
      totalAmount: _number(json['total_amount']),
      currency: _string(json['currency']),
      issuedAt: _date(json['issued_at']) ?? _date(json['created_at']),
    );
  }
}

final class ClaimsLookupsDto {
  const ClaimsLookupsDto({required this.referenceData});

  final ClaimsReferenceData referenceData;

  factory ClaimsLookupsDto.fromResponse(Object? responseData) {
    final ClaimsJsonMap response = _expectMap(responseData);
    final ClaimsJsonMap data = _map(response['data']);

    final List<CoveragePlanOption> coveragePlans = _list(data['coverage_plans'])
        .map(CoveragePlanDto.new)
        .map((CoveragePlanDto dto) => dto.toEntity())
        .where((CoveragePlanOption item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<ClaimInvoiceOption> invoices = _list(data['invoices'])
        .map(ClaimInvoiceDto.new)
        .map((ClaimInvoiceDto dto) => dto.toEntity())
        .where((ClaimInvoiceOption item) => item.id.isNotEmpty)
        .toList(growable: false);

    return ClaimsLookupsDto(
      referenceData: ClaimsReferenceData(
        coveragePlans: coveragePlans,
        invoices: invoices,
      ),
    );
  }
}

ClaimsJsonMap _expectMap(Object? value) {
  if (value is ClaimsJsonMap) {
    return value;
  }

  throw const FormatException('Expected claims response object.');
}

ClaimsJsonMap _map(Object? value) {
  return value is ClaimsJsonMap ? value : <String, Object?>{};
}

List<ClaimsJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <ClaimsJsonMap>[];
  }

  return value.whereType<ClaimsJsonMap>().toList(growable: false);
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }

  return DateTime.tryParse(normalized);
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

num? _number(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}

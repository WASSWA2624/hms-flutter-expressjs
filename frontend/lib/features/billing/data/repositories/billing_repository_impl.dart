import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/billing/data/dtos/billing_dtos.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

/// Last-office create mutations require a conditional header per offline policy.
const Map<String, String> _initialConditionalMutationHeaders = <String, String>{
  'If-Match': 'W/"1"',
};

final class BillingRepositoryImpl implements BillingRepository {
  const BillingRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<BillingWorkspaceOverview>> getWorkspace(
    BillingWorkspaceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<BillingWorkspaceOverview>(
      ApiEndpoints.nested(
        HmsApiResource.billing,
        'workspace',
        const <String>[],
      ),
      queryParameters: _workspaceQueryParameters(query, request),
      decoder: (Object? data) {
        return BillingWorkspaceOverviewDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<AppPage<BillingWorkItem>>> listWorkItems(
    BillingWorkspaceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<BillingWorkItem>>(
      ApiEndpoints.nested(
        HmsApiResource.billing,
        'work-items',
        const <String>[],
      ),
      queryParameters: _workItemsQueryParameters(query, request),
      decoder: (Object? data) {
        return BillingWorkItemPageDto.fromResponse(data, request).page;
      },
    );
  }

  @override
  Future<Result<BillingMutationResult>> issueInvoice(
    String invoiceId, {
    String? notes,
  }) {
    return _apiClient.post<BillingMutationResult>(
      ApiEndpoints.apiV1(<String>['billing', 'invoices', invoiceId, 'issue']),
      data: _withoutEmpty(<String, Object?>{
        'issued_at': DateTime.now().toUtc().toIso8601String(),
        'notes': notes,
      }),
      decoder: (Object? data) =>
          BillingMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<BillingMutationResult>> sendInvoice(
    String invoiceId, {
    String? recipientEmail,
  }) {
    return _apiClient.post<BillingMutationResult>(
      ApiEndpoints.apiV1(<String>['billing', 'invoices', invoiceId, 'send']),
      data: _withoutEmpty(<String, Object?>{'recipient_email': recipientEmail}),
      decoder: (Object? data) =>
          BillingMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<BillingMutationResult>> receivePayment(
    BillingWorkItem invoice,
    BillingPaymentDraft draft,
  ) async {
    final String? tenantId = _nonEmpty(invoice.tenantId);
    if (tenantId == null || invoice.id.isEmpty) {
      return Result<BillingMutationResult>.failure(
        AppFailure.validation(validationFields: <String>{'invoice_id'}),
      );
    }

    final Result<String> createdPayment = await _apiClient.post<String>(
      ApiEndpoints.collection(HmsApiResource.payments),
      data: _withoutEmpty(<String, Object?>{
        'tenant_id': tenantId,
        'facility_id': invoice.facilityId,
        'patient_id': invoice.patientId,
        'invoice_id': invoice.id,
        'status': 'PENDING',
        'method': draft.method,
        'amount': _decimalString(draft.amount),
        'paid_at': DateTime.now().toUtc().toIso8601String(),
        'transaction_ref': draft.reference,
      }),
      decoder: decodeBillingRecordId,
    );

    return createdPayment.when<Future<Result<BillingMutationResult>>>(
      success: (String paymentId) {
        if (paymentId.isEmpty) {
          return Future<Result<BillingMutationResult>>.value(
            Result<BillingMutationResult>.failure(
              AppFailure.validation(validationFields: <String>{'payment_id'}),
            ),
          );
        }
        return _apiClient.post<BillingMutationResult>(
          ApiEndpoints.apiV1(<String>[
            'billing',
            'payments',
            paymentId,
            'reconcile',
          ]),
          data: const <String, Object?>{'status': 'COMPLETED'},
          decoder: (Object? data) =>
              BillingMutationResultDto.fromResponse(data).toEntity(),
        );
      },
      failure: (AppFailure failure) async =>
          Result<BillingMutationResult>.failure(failure),
    );
  }

  @override
  Future<Result<BillingMutationResult>> requestRefund(
    BillingRefundDraft draft,
  ) {
    return _apiClient.post<BillingMutationResult>(
      ApiEndpoints.apiV1(<String>[
        'billing',
        'payments',
        draft.paymentId,
        'refund-request',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'amount': _decimalString(draft.amount),
        'reason': draft.reason,
        'notes': draft.notes,
      }),
      decoder: (Object? data) =>
          BillingMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<BillingMutationResult>> requestAdjustment(
    BillingWorkItem invoice,
    BillingAdjustmentDraft draft,
  ) {
    return _apiClient.post<BillingMutationResult>(
      ApiEndpoints.apiV1(<String>['billing', 'adjustments', 'request']),
      data: _withoutEmpty(<String, Object?>{
        'invoice_id': invoice.id,
        'amount': _signedDecimalString(draft.amount),
        'reason': draft.reason,
        'status': draft.status,
        'adjusted_at': DateTime.now().toUtc().toIso8601String(),
        'notes': draft.notes,
      }),
      decoder: (Object? data) =>
          BillingMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<BillingMutationResult>> requestInvoiceVoid(
    BillingWorkItem invoice, {
    required String reason,
    String? notes,
  }) {
    return _apiClient.post<BillingMutationResult>(
      ApiEndpoints.apiV1(<String>[
        'billing',
        'invoices',
        invoice.id,
        'void-request',
      ]),
      data: _withoutEmpty(<String, Object?>{'reason': reason, 'notes': notes}),
      decoder: (Object? data) =>
          BillingMutationResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<void>> closeShift(BillingCloseDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.shiftCloses),
      data: _withoutEmpty(<String, Object?>{
        'expected_amount': _nullableDecimalString(draft.expectedAmount),
        'actual_amount': _nullableDecimalString(draft.actualAmount),
        'notes': draft.notes,
        'submit': draft.submit,
      }),
      options: Options(headers: _initialConditionalMutationHeaders),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> closeDay(BillingCloseDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.dayCloses),
      data: _withoutEmpty(<String, Object?>{
        'notes': draft.notes,
        'submit': draft.submit,
      }),
      options: Options(headers: _initialConditionalMutationHeaders),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<BillingPatientLedger>> getPatientLedger(
    String patientIdentifier,
    BillingLedgerQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<BillingPatientLedger>(
      ApiEndpoints.nested(HmsApiResource.billing, 'patients', <String>[
        patientIdentifier,
        'ledger',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'from': query.from?.toUtc().toIso8601String(),
        'to': query.to?.toUtc().toIso8601String(),
      }),
      decoder: (Object? data) {
        return BillingPatientLedgerDto.fromResponse(data, request).toEntity();
      },
    );
  }

  @override
  Future<Result<BillingMutationResult>> approveApproval(
    String approvalId,
    BillingApprovalDecisionDraft draft,
  ) {
    return _apiClient.post<BillingMutationResult>(
      ApiEndpoints.apiV1(<String>[
        'billing',
        'approvals',
        approvalId,
        'approve',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'decision_notes': draft.decisionNotes,
      }),
      decoder: (Object? data) => BillingMutationResultDto.fromResponse(
        data,
        fallbackQueue: BillingQueueType.approvalRequired,
      ).toEntity(),
    );
  }

  @override
  Future<Result<BillingMutationResult>> rejectApproval(
    String approvalId,
    BillingApprovalDecisionDraft draft,
  ) {
    return _apiClient.post<BillingMutationResult>(
      ApiEndpoints.apiV1(<String>[
        'billing',
        'approvals',
        approvalId,
        'reject',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'reason': draft.reason,
        'decision_notes': draft.decisionNotes,
      }),
      decoder: (Object? data) => BillingMutationResultDto.fromResponse(
        data,
        fallbackQueue: BillingQueueType.approvalRequired,
      ).toEntity(),
    );
  }

  @override
  Future<Result<BillingInvoiceDocument>> getInvoiceDocument(String invoiceId) {
    return _apiClient.get<BillingInvoiceDocument>(
      ApiEndpoints.apiV1(<String>[
        'billing',
        'invoices',
        invoiceId,
        'document',
      ]),
      options: Options(responseType: ResponseType.bytes),
      decoder: (Object? data) {
        final List<int> bytes = _decodeBytes(data);
        return BillingInvoiceDocument(
          bytes: bytes,
          fileName: 'invoice-$invoiceId.pdf',
        );
      },
    );
  }

  @override
  Future<Result<BillingMutationResult>> submitClaim(
    String claimId,
    BillingClaimActionDraft draft,
  ) {
    return _apiClient.post<BillingMutationResult>(
      ApiEndpoints.nested(HmsApiResource.insuranceClaims, claimId, <String>[
        'submit',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'notes': draft.notes,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      }),
      decoder: (Object? data) => BillingMutationResultDto.fromResponse(
        data,
        fallbackQueue: BillingQueueType.claimsPending,
      ).toEntity(),
    );
  }

  @override
  Future<Result<BillingMutationResult>> reconcileClaim(
    String claimId,
    BillingClaimActionDraft draft,
  ) {
    return _apiClient.post<BillingMutationResult>(
      ApiEndpoints.nested(HmsApiResource.insuranceClaims, claimId, <String>[
        'reconcile',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'status': draft.status,
        'notes': draft.notes,
      }),
      decoder: (Object? data) => BillingMutationResultDto.fromResponse(
        data,
        fallbackQueue: BillingQueueType.claimsPending,
      ).toEntity(),
    );
  }

  @override
  Future<Result<BillingMutationResult>> updatePreAuthorization(
    String preAuthorizationId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<BillingMutationResult>(
      ApiEndpoints.byId(HmsApiResource.preAuthorizations, preAuthorizationId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          BillingMutationResultDto.fromResponse(data).toEntity(),
    );
  }
}

Map<String, Object?> _workspaceQueryParameters(
  BillingWorkspaceQuery query,
  AppPageRequest request,
) {
  return _withoutEmpty(<String, Object?>{
    'page': request.pageIndex + 1,
    'limit': request.pageSize,
    ..._billingFilterQueryParameters(query),
  });
}

Map<String, Object?> _workItemsQueryParameters(
  BillingWorkspaceQuery query,
  AppPageRequest request,
) {
  return _withoutEmpty(<String, Object?>{
    'page': request.pageIndex + 1,
    'limit': request.pageSize,
    'queue': query.queue == BillingQueueType.all
        ? null
        : query.queue.serverValue,
    ..._billingFilterQueryParameters(query),
  });
}

Map<String, Object?> _billingFilterQueryParameters(
  BillingWorkspaceQuery query,
) {
  return <String, Object?>{
    'search': query.search,
    'patient_id': query.patientId,
    'invoice_number': query.invoiceNumber,
    'encounter_id': query.encounterId,
    'source_module': query.sourceModule,
    'billing_status': query.billingStatus,
    'from': query.from?.toUtc().toIso8601String(),
    'to': query.to?.toUtc().toIso8601String(),
  };
}

Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPayloadValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPayloadValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable) {
    return value.isEmpty;
  }
  if (value is Map) {
    return value.isEmpty;
  }
  return false;
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _decimalString(String value) {
  final num parsed = num.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  return parsed.toStringAsFixed(2);
}

String _signedDecimalString(String value) {
  final num parsed = num.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  return parsed.toStringAsFixed(2);
}

String? _nullableDecimalString(String? value) {
  final String? normalized = _nonEmpty(value);
  return normalized == null ? null : _decimalString(normalized);
}

List<int> _decodeBytes(Object? data) {
  if (data is List<int>) {
    return data;
  }
  if (data is List) {
    return data.whereType<int>().toList(growable: false);
  }
  return const <int>[];
}

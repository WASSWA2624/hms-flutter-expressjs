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
      ApiEndpoints.nested(HmsApiResource.billing, 'workspace', const <String>[]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
      }),
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
      ApiEndpoints.nested(HmsApiResource.billing, 'work-items', const <String>[]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'queue': query.queue.serverValue,
        'search': query.search,
      }),
      decoder: (Object? data) {
        return BillingWorkItemPageDto.fromResponse(data, request).page;
      },
    );
  }

  @override
  Future<Result<void>> issueInvoice(String invoiceId, {String? notes}) {
    return _apiClient.post<void>(
      ApiEndpoints.apiV1(<String>['billing', 'invoices', invoiceId, 'issue']),
      data: _withoutEmpty(<String, Object?>{
        'issued_at': DateTime.now().toUtc().toIso8601String(),
        'notes': notes,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> sendInvoice(String invoiceId, {String? recipientEmail}) {
    return _apiClient.post<void>(
      ApiEndpoints.apiV1(<String>['billing', 'invoices', invoiceId, 'send']),
      data: _withoutEmpty(<String, Object?>{
        'recipient_email': recipientEmail,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> receivePayment(
    BillingWorkItem invoice,
    BillingPaymentDraft draft,
  ) async {
    final String? tenantId = _nonEmpty(invoice.tenantId);
    if (tenantId == null || invoice.id.isEmpty) {
      return Result<void>.failure(
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

    return createdPayment.when<Future<Result<void>>>(
      success: (String paymentId) {
        if (paymentId.isEmpty) {
          return Future<Result<void>>.value(
            Result<void>.failure(
              AppFailure.validation(validationFields: <String>{'payment_id'}),
            ),
          );
        }
        return _apiClient.post<void>(
          ApiEndpoints.apiV1(<String>[
            'billing',
            'payments',
            paymentId,
            'reconcile',
          ]),
          data: const <String, Object?>{'status': 'COMPLETED'},
          decoder: (_) {},
        );
      },
      failure: (AppFailure failure) async => Result<void>.failure(failure),
    );
  }

  @override
  Future<Result<void>> requestRefund(BillingRefundDraft draft) {
    return _apiClient.post<void>(
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
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> requestAdjustment(
    BillingWorkItem invoice,
    BillingAdjustmentDraft draft,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.apiV1(<String>['billing', 'adjustments', 'request']),
      data: _withoutEmpty(<String, Object?>{
        'invoice_id': invoice.id,
        'amount': _signedDecimalString(draft.amount),
        'reason': draft.reason,
        'status': draft.status,
        'adjusted_at': DateTime.now().toUtc().toIso8601String(),
        'notes': draft.notes,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> requestInvoiceVoid(
    BillingWorkItem invoice, {
    required String reason,
    String? notes,
  }) {
    return _apiClient.post<void>(
      ApiEndpoints.apiV1(<String>[
        'billing',
        'invoices',
        invoice.id,
        'void-request',
      ]),
      data: _withoutEmpty(<String, Object?>{'reason': reason, 'notes': notes}),
      decoder: (_) {},
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
      decoder: (_) {},
    );
  }
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';

final priceBookResolveRepositoryProvider =
    Provider<PriceBookResolveRepository>((Ref ref) {
      return PriceBookResolveRepository(
        apiClient: ref.watch(apiClientProvider),
      );
    });

/// Client for POST /price-book-entries/resolve
final class PriceBookResolveRepository {
  const PriceBookResolveRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Result<List<ClinicalRequestBillingLineItem>>> resolveLineItems({
    required String tenantId,
    String? facilityId,
    required List<ClinicalRequestBillingLineItem> items,
    ClinicalRequestPayerContext? payerContext,
    String? billingEntity,
    String? currency,
  }) {
    final ClinicalRequestPayerContext payer =
        payerContext ?? const ClinicalRequestPayerContext();
    final String paymentMode = payer.insured
        ? 'INSURANCE'
        : (payer.paymentMode.isNotEmpty ? payer.paymentMode : 'SELF_PAY');

    return _apiClient.post<List<ClinicalRequestBillingLineItem>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.priceBookEntries.path,
        'resolve',
      ]),
      body: <String, Object?>{
        'tenant_id': tenantId,
        if (facilityId != null && facilityId.isNotEmpty)
          'facility_id': facilityId,
        'payment_mode': paymentMode,
        if (payer.coveragePlanId != null && payer.coveragePlanId!.isNotEmpty)
          'coverage_plan_id': payer.coveragePlanId,
        if (payer.insuranceCompanyId != null &&
            payer.insuranceCompanyId!.isNotEmpty)
          'insurance_company_id': payer.insuranceCompanyId,
        if (payer.insurerKey != null && payer.insurerKey!.isNotEmpty)
          'insurer_key': payer.insurerKey,
        if (billingEntity != null && billingEntity.isNotEmpty)
          'billing_entity': billingEntity,
        if (currency != null && currency.isNotEmpty) 'currency': currency,
        'items': <Map<String, Object?>>[
          for (final ClinicalRequestBillingLineItem item in items)
            <String, Object?>{
              'id': item.id,
              if (item.catalogType != null) 'catalog_type': item.catalogType,
              'catalog_item_id': item.id,
              'quantity': item.quantity,
              if (item.priceSource != null) 'price_source': item.priceSource,
            },
        ],
      },
      decoder: (Object? data) {
        final Object? payload = data is Map ? data['data'] ?? data : data;
        final Object? list = payload is Map
            ? payload['items'] ?? payload
            : payload;
        if (list is! List) {
          return items;
        }
        return <ClinicalRequestBillingLineItem>[
          for (int i = 0; i < items.length; i++)
            () {
              final ClinicalRequestBillingLineItem base = items[i];
              final Object? raw = i < list.length ? list[i] : null;
              if (raw is! Map) {
                return base;
              }
              final Map<String, Object?> json = Map<String, Object?>.from(raw);
              final num? unitPrice = _num(json['unit_price']);
              return base.copyWith(
                unitPrice: unitPrice ?? base.unitPrice,
                currency: _string(json['currency']) ?? base.currency,
                priceSource:
                    _string(json['price_source']) ?? base.priceSource,
                billingEntity:
                    _string(json['billing_entity']) ?? base.billingEntity,
                paymentMode: _string(json['payment_mode']) ?? base.paymentMode,
                catalogType: _string(json['catalog_type']) ?? base.catalogType,
                priceBookEntryId:
                    _string(json['price_book_entry_id']) ??
                    base.priceBookEntryId,
                coveragePlanId:
                    _string(json['coverage_plan_id']) ?? base.coveragePlanId,
                patientShare: _num(json['patient_share']) ?? base.patientShare,
                insurerShare: _num(json['insurer_share']) ?? base.insurerShare,
                copayAmount: _num(json['copay_amount']) ?? base.copayAmount,
              );
            }(),
        ];
      },
    );
  }
}

ClinicalRequestPayerContext clinicalRequestPayerContextFromCoverage({
  required bool verified,
  String? insuranceCompanyId,
  String? insuranceCompanyName,
  String? coveragePlanId,
  String? coveragePlanName,
  int? coveragePercentage,
  String? copayType,
  num? copayValue,
  String? memberId,
  String? insurerKey,
}) {
  return ClinicalRequestPayerContext(
    insured: verified && (coveragePlanId ?? '').trim().isNotEmpty,
    insuranceCompanyId: insuranceCompanyId,
    insuranceCompanyName: insuranceCompanyName,
    coveragePlanId: coveragePlanId,
    coveragePlanName: coveragePlanName,
    coveragePercentage: coveragePercentage,
    copayType: copayType,
    copayValue: copayValue,
    memberId: memberId,
    insurerKey: insurerKey,
  );
}

Future<List<ClinicalRequestBillingLineItem>> resolveClinicalRequestBillingLineItems({
  required BuildContext context,
  required List<ClinicalRequestBillingLineItem> catalogFallbackItems,
  ClinicalRequestPayerContext? payerContext,
  String? billingEntity,
  String? currency,
}) async {
  if (catalogFallbackItems.isEmpty) {
    return catalogFallbackItems;
  }

  final ProviderContainer container = ProviderScope.containerOf(context);
  final String? tenantId = container
      .read(sessionStateProvider)
      .session
      ?.user
      ?.tenantId;
  if (tenantId == null || tenantId.trim().isEmpty) {
    return catalogFallbackItems;
  }

  final String? facilityId = container
      .read(sessionStateProvider)
      .session
      ?.user
      ?.facilityId;

  final Result<List<ClinicalRequestBillingLineItem>> result = await container
      .read(priceBookResolveRepositoryProvider)
      .resolveLineItems(
        tenantId: tenantId,
        facilityId: facilityId,
        items: catalogFallbackItems,
        payerContext: payerContext,
        billingEntity: billingEntity,
        currency: currency,
      );

  return result.when(
    success: (List<ClinicalRequestBillingLineItem> items) => items,
    failure: (_) => catalogFallbackItems,
  );
}

/// Resolve prices via the engine, then open the shared billing dialog.
Future<ClinicalRequestBillingSubmit?> showResolvedClinicalRequestBillingDialog({
  required BuildContext context,
  required List<ClinicalActionCatalogOption> options,
  Map<String, num>? quantities,
  ClinicalRequestBillingSubmit? initialBilling,
  ClinicalRequestPayerContext? payerContext,
  String? billingEntity,
  String? catalogType,
  bool enabled = true,
}) async {
  final List<ClinicalRequestBillingLineItem> fallback =
      clinicalRequestBillingLineItems(
        options: options,
        quantities: quantities,
        catalogType: catalogType,
        billingEntity: billingEntity,
      );
  final List<ClinicalRequestBillingLineItem> resolved =
      await resolveClinicalRequestBillingLineItems(
        context: context,
        catalogFallbackItems: fallback,
        payerContext: payerContext,
        billingEntity: billingEntity,
      );
  if (!context.mounted) {
    return null;
  }
  return showClinicalRequestBillingDialog(
    context: context,
    lineItems: resolved,
    initialBilling: initialBilling,
    payerContext: payerContext,
    billingEntity: billingEntity,
    enabled: enabled,
  );
}

String? _string(Object? value) {
  if (value == null) return null;
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

num? _num(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

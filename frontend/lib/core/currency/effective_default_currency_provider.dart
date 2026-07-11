import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:hosspi_hms/shared/components/app_currency.dart';

/// App-wide default currency: facility → tenant → [appDefaultCurrencyCode].
///
/// Watches the tenant/facility setup snapshot so amount fields and dialogs
/// stay aligned with configured org defaults.
final effectiveDefaultCurrencyProvider = Provider<String>((Ref ref) {
  final AsyncValue<Result<FacilitySetupSnapshot>> setupAsync = ref.watch(
    tenantFacilitySetupControllerProvider,
  );
  final Result<FacilitySetupSnapshot>? result = setupAsync.asData?.value;
  if (result == null) {
    return appDefaultCurrencyCode;
  }

  return result.when(
    success: (FacilitySetupSnapshot snapshot) {
      return resolveDefaultCurrency(
        facilityCurrency: snapshot.facility?.currency,
        tenantCurrency: snapshot.tenant?.currency,
      );
    },
    failure: (_) => appDefaultCurrencyCode,
  );
});

/// Resolves currency from an explicit setup snapshot (dialogs, non-ref paths).
String effectiveDefaultCurrencyFromSnapshot(FacilitySetupSnapshot? snapshot) {
  return resolveDefaultCurrency(
    facilityCurrency: snapshot?.facility?.currency,
    tenantCurrency: snapshot?.tenant?.currency,
  );
}

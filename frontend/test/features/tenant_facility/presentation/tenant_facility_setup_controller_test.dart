import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockTenantFacilityRepository extends Mock
    implements TenantFacilityRepository {}

void main() {
  group('TenantFacilitySetupController', () {
    test('refresh keeps selected facility and returns workspace snapshot', () async {
      final _MockTenantFacilityRepository repository =
          _MockTenantFacilityRepository();
      const FacilitySetupSnapshot snapshot = FacilitySetupSnapshot(
        tenant: TenantProfile(id: 'TEN0001', name: 'Acme Hospital'),
        facility: FacilityProfile(
          id: 'FAC0001',
          tenantId: 'TEN0001',
          name: 'Main Campus',
          type: FacilitySetupType.hospital,
        ),
        facilities: <FacilityProfile>[
          FacilityProfile(
            id: 'FAC0001',
            tenantId: 'TEN0001',
            name: 'Main Campus',
            type: FacilitySetupType.hospital,
          ),
        ],
      );

      when(
        () => repository.loadSetup(facilityId: any(named: 'facilityId')),
      ).thenAnswer(
        (_) async => const Result<FacilitySetupSnapshot>.success(snapshot),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          tenantFacilityRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tenantFacilitySetupControllerProvider.future);
      await container
          .read(tenantFacilitySetupControllerProvider.notifier)
          .selectFacility('FAC0001');

      verify(
        () => repository.loadSetup(facilityId: any(named: 'facilityId')),
      ).called(greaterThanOrEqualTo(2));
      final Result<FacilitySetupSnapshot>? result =
          container.read(tenantFacilitySetupControllerProvider).value;
      expect(result?.when(success: (value) => value.facility?.id, failure: (_) => null),
          'FAC0001');
    });
  });
}

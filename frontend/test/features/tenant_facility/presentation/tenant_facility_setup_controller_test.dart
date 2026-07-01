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
  setUpAll(() {
    registerFallbackValue(FacilitySetupType.hospital);
  });

  group('TenantFacilitySetupController', () {
    test(
      'refresh keeps selected facility and returns workspace snapshot',
      () async {
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
        final Result<FacilitySetupSnapshot>? result = container
            .read(tenantFacilitySetupControllerProvider)
            .value;
        expect(
          result?.when(
            success: (value) => value.facility?.id,
            failure: (_) => null,
          ),
          'FAC0001',
        );
      },
    );
    test(
      'saveFacility uploads logo bytes before persisting facility profile',
      () async {
        final _MockTenantFacilityRepository repository =
            _MockTenantFacilityRepository();
        const FacilityProfile facility = FacilityProfile(
          id: 'FAC0001',
          tenantId: 'TEN0001',
          name: 'Main Campus',
          type: FacilitySetupType.hospital,
        );
        const FacilitySetupSnapshot snapshot = FacilitySetupSnapshot(
          tenant: TenantProfile(id: 'TEN0001', name: 'Acme Hospital'),
          facility: facility,
        );

        when(
          () => repository.loadSetup(facilityId: any(named: 'facilityId')),
        ).thenAnswer(
          (_) async => const Result<FacilitySetupSnapshot>.success(snapshot),
        );
        when(
          () => repository.saveFacility(
            id: any(named: 'id'),
            tenantId: any(named: 'tenantId'),
            name: any(named: 'name'),
            type: any(named: 'type'),
            isActive: any(named: 'isActive'),
            logoUrl: any(named: 'logoUrl'),
          ),
        ).thenAnswer(
          (_) async => const Result<FacilityProfile>.success(facility),
        );
        when(
          () => repository.uploadFacilityLogo(
            facilityId: any(named: 'facilityId'),
            bytes: any(named: 'bytes'),
            fileName: any(named: 'fileName'),
            mimeType: any(named: 'mimeType'),
          ),
        ).thenAnswer(
          (_) async =>
              const Result<String>.success('https://example.com/logo.png'),
        );
        when(
          () => repository.saveFacilityContactAddress(
            tenantId: any(named: 'tenantId'),
            facilityId: any(named: 'facilityId'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
            addressLine1: any(named: 'addressLine1'),
            city: any(named: 'city'),
            country: any(named: 'country'),
          ),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final ProviderContainer container = ProviderContainer(
          overrides: [
            tenantFacilityRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(tenantFacilitySetupControllerProvider.future);

        final bool saved = await container
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .saveFacility(
              id: facility.id,
              tenantId: 'TEN0001',
              name: facility.name,
              type: facility.type,
              isActive: true,
              logoBytes: <int>[1, 2, 3],
              logoFileName: 'logo.png',
              logoMimeType: 'image/png',
              phone: '+256700000000',
            );

        expect(saved, isTrue);
        verify(
          () => repository.uploadFacilityLogo(
            facilityId: facility.id,
            bytes: <int>[1, 2, 3],
            fileName: 'logo.png',
            mimeType: 'image/png',
          ),
        ).called(1);
        verify(
          () => repository.saveFacility(
            id: facility.id,
            tenantId: 'TEN0001',
            name: facility.name,
            type: facility.type,
            isActive: true,
            logoUrl: 'https://example.com/logo.png',
          ),
        ).called(1);
      },
    );
  });
}

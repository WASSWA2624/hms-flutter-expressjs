import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';

final tenantFacilitySetupControllerProvider =
    AsyncNotifierProvider<
      TenantFacilitySetupController,
      Result<FacilitySetupSnapshot>
    >(TenantFacilitySetupController.new);

final tenantFacilitySetupSubmissionProvider =
    NotifierProvider<
      TenantFacilitySetupSubmissionController,
      TenantFacilitySetupSubmissionState
    >(TenantFacilitySetupSubmissionController.new);

final class TenantFacilitySetupController
    extends AsyncNotifier<Result<FacilitySetupSnapshot>> {
  @override
  Future<Result<FacilitySetupSnapshot>> build() {
    return ref.read(tenantFacilityRepositoryProvider).loadSetup();
  }

  Future<void> refresh() async {
    state = const AsyncValue<Result<FacilitySetupSnapshot>>.loading();
    state = await AsyncValue.guard(
      () => ref.read(tenantFacilityRepositoryProvider).loadSetup(),
    );
  }
}

final class TenantFacilitySetupSubmissionState {
  const TenantFacilitySetupSubmissionState({
    this.isSubmitting = false,
    this.failure,
  });

  final bool isSubmitting;
  final AppFailure? failure;

  TenantFacilitySetupSubmissionState copyWith({
    bool? isSubmitting,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return TenantFacilitySetupSubmissionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

final class TenantFacilitySetupSubmissionController
    extends Notifier<TenantFacilitySetupSubmissionState> {
  @override
  TenantFacilitySetupSubmissionState build() {
    return const TenantFacilitySetupSubmissionState();
  }

  Future<bool> saveTenant({
    String? id,
    required String name,
    String? slug,
    required bool isActive,
  }) {
    return _submit(
      () => _repository.saveTenant(
        id: id,
        name: name,
        slug: slug,
        isActive: isActive,
      ),
    );
  }

  Future<bool> saveFacility({
    String? id,
    required String tenantId,
    required String name,
    required FacilitySetupType type,
    required bool isActive,
    String? logoUrl,
    String? phone,
    String? email,
    String? addressLine1,
    String? city,
    String? country,
  }) {
    return _submit(() async {
      final facilityResult = await _repository.saveFacility(
        id: id,
        tenantId: tenantId,
        name: name,
        type: type,
        isActive: isActive,
        logoUrl: logoUrl,
      );

      return facilityResult.when(
        success: (FacilityProfile facility) {
          return _repository.saveFacilityContactAddress(
            tenantId: tenantId,
            facilityId: facility.id,
            phone: phone,
            email: email,
            addressLine1: addressLine1,
            city: city,
            country: country,
          );
        },
        failure: (AppFailure failure) async => Result<void>.failure(failure),
      );
    });
  }

  Future<bool> createBranch({
    required String tenantId,
    required String facilityId,
    required String name,
    required bool isActive,
  }) {
    return _submit(
      () => _repository.createBranch(
        tenantId: tenantId,
        facilityId: facilityId,
        name: name,
        isActive: isActive,
      ),
    );
  }

  Future<bool> createDepartment({
    required String tenantId,
    required String facilityId,
    required String name,
    String? shortName,
    required DepartmentSetupType type,
    required bool isActive,
  }) {
    return _submit(
      () => _repository.createDepartment(
        tenantId: tenantId,
        facilityId: facilityId,
        name: name,
        shortName: shortName,
        type: type,
        isActive: isActive,
      ),
    );
  }

  Future<bool> createUnit({
    required String tenantId,
    required String facilityId,
    required String name,
    String? departmentId,
    required bool isActive,
  }) {
    return _submit(
      () => _repository.createUnit(
        tenantId: tenantId,
        facilityId: facilityId,
        name: name,
        departmentId: departmentId,
        isActive: isActive,
      ),
    );
  }

  TenantFacilityRepository get _repository {
    return ref.read(tenantFacilityRepositoryProvider);
  }

  Future<bool> _submit<T>(Future<Result<T>> Function() action) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final result = await action();

    return result.when(
      success: (_) async {
        state = state.copyWith(isSubmitting: false, clearFailure: true);
        await ref
            .read(tenantFacilitySetupControllerProvider.notifier)
            .refresh();
        return true;
      },
      failure: (AppFailure failure) {
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
      },
    );
  }
}

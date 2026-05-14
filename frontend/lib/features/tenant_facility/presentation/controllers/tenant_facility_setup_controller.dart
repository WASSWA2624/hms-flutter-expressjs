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
  String? _selectedFacilityId;

  @override
  Future<Result<FacilitySetupSnapshot>> build() {
    return ref
        .read(tenantFacilityRepositoryProvider)
        .loadSetup(facilityId: _selectedFacilityId);
  }

  Future<void> refresh() async {
    state = const AsyncValue<Result<FacilitySetupSnapshot>>.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(tenantFacilityRepositoryProvider)
          .loadSetup(facilityId: _selectedFacilityId),
    );
  }

  Future<void> selectFacility(String facilityId) async {
    _selectedFacilityId = facilityId;
    await refresh();
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

  Future<bool> saveBranch({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    required bool isActive,
  }) {
    return _submit(
      () => _repository.saveBranch(
        id: id,
        tenantId: tenantId,
        facilityId: facilityId,
        name: name,
        isActive: isActive,
      ),
    );
  }

  Future<bool> deleteBranch(String id) {
    return _submit(() => _repository.deleteBranch(id));
  }

  Future<bool> saveDepartment({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? shortName,
    String? branchId,
    required DepartmentSetupType type,
    required bool isActive,
  }) {
    return _submit(
      () => _repository.saveDepartment(
        id: id,
        tenantId: tenantId,
        facilityId: facilityId,
        name: name,
        shortName: shortName,
        branchId: branchId,
        type: type,
        isActive: isActive,
      ),
    );
  }

  Future<bool> deleteDepartment(String id) {
    return _submit(() => _repository.deleteDepartment(id));
  }

  Future<bool> saveUnit({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? departmentId,
    required bool isActive,
  }) {
    return _submit(
      () => _repository.saveUnit(
        id: id,
        tenantId: tenantId,
        facilityId: facilityId,
        name: name,
        departmentId: departmentId,
        isActive: isActive,
      ),
    );
  }

  Future<bool> deleteUnit(String id) {
    return _submit(() => _repository.deleteUnit(id));
  }

  Future<bool> saveWard({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    required WardSetupType type,
    String? departmentId,
    required bool isActive,
  }) {
    return _submit(
      () => _repository.saveWard(
        id: id,
        tenantId: tenantId,
        facilityId: facilityId,
        name: name,
        type: type,
        departmentId: departmentId,
        isActive: isActive,
      ),
    );
  }

  Future<bool> deleteWard(String id) {
    return _submit(() => _repository.deleteWard(id));
  }

  Future<bool> saveRoom({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? wardId,
    String? floor,
  }) {
    return _submit(
      () => _repository.saveRoom(
        id: id,
        tenantId: tenantId,
        facilityId: facilityId,
        name: name,
        wardId: wardId,
        floor: floor,
      ),
    );
  }

  Future<bool> deleteRoom(String id) {
    return _submit(() => _repository.deleteRoom(id));
  }

  Future<bool> saveBed({
    String? id,
    required String tenantId,
    required String facilityId,
    required String wardId,
    required String label,
    required BedSetupStatus status,
    String? roomId,
  }) {
    return _submit(
      () => _repository.saveBed(
        id: id,
        tenantId: tenantId,
        facilityId: facilityId,
        wardId: wardId,
        label: label,
        status: status,
        roomId: roomId,
      ),
    );
  }

  Future<bool> deleteBed(String id) {
    return _submit(() => _repository.deleteBed(id));
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

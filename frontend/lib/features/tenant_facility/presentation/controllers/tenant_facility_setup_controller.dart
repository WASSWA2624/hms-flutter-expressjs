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

final tenantFacilitySetupRefreshProvider =
    NotifierProvider<TenantFacilitySetupRefreshController, bool>(
      TenantFacilitySetupRefreshController.new,
    );

typedef _SnapshotUpdate<T> =
    FacilitySetupSnapshot Function(FacilitySetupSnapshot snapshot, T value);

final class TenantFacilitySetupRefreshController extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void start() {
    state = true;
  }

  void stop() {
    state = false;
  }
}

final class TenantFacilitySetupController
    extends AsyncNotifier<Result<FacilitySetupSnapshot>> {
  String? _selectedFacilityId;

  @override
  Future<Result<FacilitySetupSnapshot>> build() {
    return ref
        .read(tenantFacilityRepositoryProvider)
        .loadSetup(facilityId: _selectedFacilityId);
  }

  Future<Result<FacilitySetupSnapshot>> refresh() async {
    final previousState = state.value;
    final refreshState = ref.read(tenantFacilitySetupRefreshProvider.notifier);
    if (previousState == null) {
      state = const AsyncValue<Result<FacilitySetupSnapshot>>.loading();
    }

    refreshState.start();
    try {
      final result = await ref
          .read(tenantFacilityRepositoryProvider)
          .loadSetup(facilityId: _selectedFacilityId);
      state = AsyncValue<Result<FacilitySetupSnapshot>>.data(result);
      return result;
    } catch (error, stackTrace) {
      if (previousState == null) {
        state = AsyncValue<Result<FacilitySetupSnapshot>>.error(
          error,
          stackTrace,
        );
      }

      return const Result<FacilitySetupSnapshot>.failure(
        AppFailure.unexpected(),
      );
    } finally {
      refreshState.stop();
    }
  }

  Future<void> selectFacility(String facilityId) async {
    _selectedFacilityId = facilityId;
    await refresh();
  }

  void updateSnapshot(
    FacilitySetupSnapshot Function(FacilitySetupSnapshot snapshot) update,
  ) {
    final result = state.value;
    final snapshot = result?.when<FacilitySetupSnapshot?>(
      success: (FacilitySetupSnapshot snapshot) => snapshot,
      failure: (_) => null,
    );
    if (snapshot == null) {
      return;
    }

    state = AsyncValue<Result<FacilitySetupSnapshot>>.data(
      Result<FacilitySetupSnapshot>.success(update(snapshot)),
    );
  }
}

final class TenantFacilitySetupSubmissionState {
  const TenantFacilitySetupSubmissionState({
    this.isSubmitting = false,
    this.failure,
    this.successVersion = 0,
  });

  final bool isSubmitting;
  final AppFailure? failure;
  final int successVersion;

  TenantFacilitySetupSubmissionState copyWith({
    bool? isSubmitting,
    AppFailure? failure,
    int? successVersion,
    bool clearFailure = false,
  }) {
    return TenantFacilitySetupSubmissionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
      successVersion: successVersion ?? this.successVersion,
    );
  }
}

final class TenantFacilitySetupSubmissionController
    extends Notifier<TenantFacilitySetupSubmissionState> {
  static const Duration _postMutationRefreshDelay = Duration(milliseconds: 300);

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
      updateSnapshot: (FacilitySetupSnapshot snapshot, TenantProfile tenant) {
        return snapshot.copyWith(tenant: tenant);
      },
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
    return _submit(
      () async {
        final facilityResult = await _repository.saveFacility(
          id: id,
          tenantId: tenantId,
          name: name,
          type: type,
          isActive: isActive,
          logoUrl: logoUrl,
        );

        return facilityResult.when(
          success: (FacilityProfile facility) async {
            final contactResult = await _repository.saveFacilityContactAddress(
              tenantId: tenantId,
              facilityId: facility.id,
              phone: phone,
              email: email,
              addressLine1: addressLine1,
              city: city,
              country: country,
            );

            return contactResult.when(
              success: (_) => Result<FacilityProfile>.success(facility),
              failure: (AppFailure failure) =>
                  Result<FacilityProfile>.failure(failure),
            );
          },
          failure: (AppFailure failure) async =>
              Result<FacilityProfile>.failure(failure),
        );
      },
      updateSnapshot:
          (FacilitySetupSnapshot snapshot, FacilityProfile facility) {
            return snapshot.copyWith(
              facility: facility,
              facilities: _upsertById<FacilityProfile>(
                snapshot.facilities,
                facility,
                (FacilityProfile item) => item.id,
              ),
              contactAddress: FacilityContactAddress(
                phone: phone,
                email: email,
                addressLine1: addressLine1,
                city: city,
                country: country,
              ),
            );
          },
    );
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
      updateSnapshot: (FacilitySetupSnapshot snapshot, BranchProfile branch) {
        return snapshot.copyWith(
          branches: _upsertById<BranchProfile>(
            snapshot.branches,
            branch,
            (BranchProfile item) => item.id,
          ),
        );
      },
    );
  }

  Future<bool> deleteBranch(String id) {
    return _submit(
      () => _repository.deleteBranch(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, _) {
        return snapshot.copyWith(
          branches: _removeById<BranchProfile>(
            snapshot.branches,
            id,
            (BranchProfile item) => item.id,
          ),
        );
      },
    );
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
      updateSnapshot:
          (FacilitySetupSnapshot snapshot, DepartmentProfile department) {
            return snapshot.copyWith(
              departments: _upsertById<DepartmentProfile>(
                snapshot.departments,
                department,
                (DepartmentProfile item) => item.id,
              ),
            );
          },
    );
  }

  Future<bool> deleteDepartment(String id) {
    return _submit(
      () => _repository.deleteDepartment(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, _) {
        return snapshot.copyWith(
          departments: _removeById<DepartmentProfile>(
            snapshot.departments,
            id,
            (DepartmentProfile item) => item.id,
          ),
        );
      },
    );
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
      updateSnapshot: (FacilitySetupSnapshot snapshot, UnitProfile unit) {
        return snapshot.copyWith(
          units: _upsertById<UnitProfile>(
            snapshot.units,
            unit,
            (UnitProfile item) => item.id,
          ),
        );
      },
    );
  }

  Future<bool> deleteUnit(String id) {
    return _submit(
      () => _repository.deleteUnit(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, _) {
        return snapshot.copyWith(
          units: _removeById<UnitProfile>(
            snapshot.units,
            id,
            (UnitProfile item) => item.id,
          ),
        );
      },
    );
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
      updateSnapshot: (FacilitySetupSnapshot snapshot, WardProfile ward) {
        return snapshot.copyWith(
          wards: _upsertById<WardProfile>(
            snapshot.wards,
            ward,
            (WardProfile item) => item.id,
          ),
        );
      },
    );
  }

  Future<bool> deleteWard(String id) {
    return _submit(
      () => _repository.deleteWard(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, _) {
        return snapshot.copyWith(
          wards: _removeById<WardProfile>(
            snapshot.wards,
            id,
            (WardProfile item) => item.id,
          ),
        );
      },
    );
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
      updateSnapshot: (FacilitySetupSnapshot snapshot, RoomProfile room) {
        return snapshot.copyWith(
          rooms: _upsertById<RoomProfile>(
            snapshot.rooms,
            room,
            (RoomProfile item) => item.id,
          ),
        );
      },
    );
  }

  Future<bool> deleteRoom(String id) {
    return _submit(
      () => _repository.deleteRoom(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, _) {
        return snapshot.copyWith(
          rooms: _removeById<RoomProfile>(
            snapshot.rooms,
            id,
            (RoomProfile item) => item.id,
          ),
        );
      },
    );
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
      updateSnapshot: (FacilitySetupSnapshot snapshot, BedProfile bed) {
        return snapshot.copyWith(
          beds: _upsertById<BedProfile>(
            snapshot.beds,
            bed,
            (BedProfile item) => item.id,
          ),
        );
      },
    );
  }

  Future<bool> deleteBed(String id) {
    return _submit(
      () => _repository.deleteBed(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, _) {
        return snapshot.copyWith(
          beds: _removeById<BedProfile>(
            snapshot.beds,
            id,
            (BedProfile item) => item.id,
          ),
        );
      },
    );
  }

  TenantFacilityRepository get _repository {
    return ref.read(tenantFacilityRepositoryProvider);
  }

  Future<bool> _submit<T>(
    Future<Result<T>> Function() action, {
    _SnapshotUpdate<T>? updateSnapshot,
  }) async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final Result<T> result;
    try {
      result = await action();
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        failure: const AppFailure.unexpected(),
      );
      return false;
    }

    return result.when(
      success: (T value) async {
        final setupController = ref.read(
          tenantFacilitySetupControllerProvider.notifier,
        );
        if (updateSnapshot != null) {
          setupController.updateSnapshot(
            (FacilitySetupSnapshot snapshot) => updateSnapshot(snapshot, value),
          );
        }

        await Future<void>.delayed(_postMutationRefreshDelay);
        final refreshResult = await setupController.refresh();
        if (updateSnapshot != null) {
          refreshResult.when(
            success: (_) {
              setupController.updateSnapshot(
                (FacilitySetupSnapshot snapshot) =>
                    updateSnapshot(snapshot, value),
              );
            },
            failure: (_) {},
          );
        }

        state = state.copyWith(
          isSubmitting: false,
          clearFailure: true,
          successVersion: state.successVersion + 1,
        );
        return true;
      },
      failure: (AppFailure failure) {
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
      },
    );
  }
}

List<T> _upsertById<T>(List<T> items, T value, String Function(T item) idOf) {
  final id = idOf(value);
  final index = items.indexWhere((T item) => idOf(item) == id);
  if (index == -1) {
    return <T>[...items, value];
  }

  final next = List<T>.of(items);
  next[index] = value;
  return next;
}

List<T> _removeById<T>(List<T> items, String id, String Function(T item) idOf) {
  return <T>[
    for (final item in items)
      if (idOf(item) != id) item,
  ];
}

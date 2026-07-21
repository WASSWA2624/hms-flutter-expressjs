import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/realtime/realtime_scope.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
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
    watchSessionEpoch(ref);
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
  String? _selectedTenantId;

  @override
  Future<Result<FacilitySetupSnapshot>> build() {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.tenantFacility,
      includeCrudMutations: true,
      shouldRefresh: (RealtimeMessage message) {
        return RealtimeScope.matchesMessage(
          message: message,
          facilityId: _selectedFacilityId,
        );
      },
      onRefresh: (_) async {
        await refresh();
      },
    );
    return ref
        .read(tenantFacilityRepositoryProvider)
        .loadSetup(
          facilityId: _selectedFacilityId,
          tenantId: _selectedTenantId,
          includeDeleted: true,
        )
        .then((Result<FacilitySetupSnapshot> result) {
          if (result case ResultSuccess<FacilitySetupSnapshot>(:final value)) {
            _selectedFacilityId ??= value.facility?.id;
            _selectedTenantId ??= value.tenant?.id;
          }
          return result;
        });
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
          .loadSetup(
            facilityId: _selectedFacilityId,
            tenantId: _selectedTenantId,
            includeDeleted: true,
          );
      if (result case ResultSuccess<FacilitySetupSnapshot>(:final value)) {
        _selectedFacilityId ??= value.facility?.id;
        _selectedTenantId ??= value.tenant?.id;
      }
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

  Future<void> selectTenant(String tenantId) async {
    _selectedTenantId = tenantId;
    _selectedFacilityId = null;
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
  @override
  TenantFacilitySetupSubmissionState build() {
    watchSessionEpoch(ref);
    return const TenantFacilitySetupSubmissionState();
  }

  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  Future<bool> saveTenant({
    String? id,
    required String name,
    String? slug,
    required bool isActive,
    String? currency,
    String? standardConsultationFee,
    bool clearStandardConsultationFee = false,
    bool refreshSetup = true,
  }) {
    return _submit(
      () => _repository.saveTenant(
        id: id,
        name: name,
        slug: slug,
        isActive: isActive,
        currency: currency,
        standardConsultationFee: standardConsultationFee,
        clearStandardConsultationFee: clearStandardConsultationFee,
      ),
      updateSnapshot: (FacilitySetupSnapshot snapshot, TenantProfile tenant) {
        return snapshot.copyWith(tenant: tenant);
      },
      refreshSetup: refreshSetup,
    );
  }

  Future<bool> saveTenantConfiguration({
    required String id,
    required String name,
    required bool isActive,
    String? slug,
    String? currency,
    String? standardConsultationFee,
    bool clearCurrency = false,
    bool clearStandardConsultationFee = false,
  }) {
    return _submit(
      () => _repository.saveTenant(
        id: id,
        name: name,
        slug: slug,
        isActive: isActive,
        currency: clearCurrency ? null : currency,
        standardConsultationFee: standardConsultationFee,
        clearStandardConsultationFee: clearStandardConsultationFee,
      ),
      updateSnapshot: (FacilitySetupSnapshot snapshot, TenantProfile tenant) {
        return snapshot.copyWith(tenant: tenant);
      },
    );
  }

  Future<bool> saveFacilityConfiguration({
    required String id,
    required String tenantId,
    required String name,
    required FacilitySetupType type,
    required bool isActive,
    String? currency,
    String? standardConsultationFee,
    bool clearCurrency = false,
    bool clearStandardConsultationFee = false,
  }) {
    return _submit(
      () => _repository.saveFacility(
        id: id,
        tenantId: tenantId,
        name: name,
        type: type,
        isActive: isActive,
        currency: clearCurrency ? null : currency,
        standardConsultationFee: standardConsultationFee,
        clearStandardConsultationFee: clearStandardConsultationFee,
      ),
      updateSnapshot:
          (FacilitySetupSnapshot snapshot, FacilityProfile facility) {
            return snapshot.copyWith(
              facility: facility,
              facilities: _upsertById<FacilityProfile>(
                snapshot.facilities,
                facility,
                (FacilityProfile item) => item.id,
              ),
            );
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
    bool removeLogo = false,
    String? currency,
    List<int>? logoBytes,
    String? logoFileName,
    String? logoMimeType,
    String? phone,
    String? email,
    String? addressLine1,
    String? city,
    String? country,
    bool refreshSetup = true,
  }) {
    return _submit(
      () async {
        String? resolvedLogoUrl = logoUrl?.trim();
        if (resolvedLogoUrl != null && resolvedLogoUrl.isEmpty) {
          resolvedLogoUrl = null;
        }
        final String? resolvedCurrency = currency?.trim().isNotEmpty == true
            ? currency!.trim().toUpperCase()
            : null;

        var facilityResult = await _repository.saveFacility(
          id: id,
          tenantId: tenantId,
          name: name,
          type: type,
          isActive: isActive,
          logoUrl: resolvedLogoUrl,
          removeLogo: removeLogo,
          currency: resolvedCurrency,
        );

        if (facilityResult case ResultFailure<FacilityProfile>(
          :final failure,
        )) {
          return Result<FacilityProfile>.failure(failure);
        }

        var facility = (facilityResult as ResultSuccess<FacilityProfile>).value;

        if (logoBytes != null &&
            logoFileName != null &&
            logoFileName.trim().isNotEmpty) {
          final uploadResult = await _repository.uploadFacilityLogo(
            facilityId: facility.mutationId,
            bytes: logoBytes,
            fileName: logoFileName,
            mimeType: logoMimeType,
          );

          final String? uploadedLogoUrl = uploadResult.when(
            success: (String value) => value,
            failure: (_) => null,
          );
          if (uploadedLogoUrl == null) {
            return uploadResult.when(
              success: (_) => Result<FacilityProfile>.success(facility),
              failure: (AppFailure failure) =>
                  Result<FacilityProfile>.failure(failure),
            );
          }

          facilityResult = await _repository.saveFacility(
            id: facility.mutationId,
            tenantId: tenantId,
            name: name,
            type: type,
            isActive: isActive,
            logoUrl: uploadedLogoUrl,
            currency: resolvedCurrency ?? facility.currency,
          );
          if (facilityResult case ResultFailure<FacilityProfile>(
            :final failure,
          )) {
            return Result<FacilityProfile>.failure(failure);
          }
          facility = (facilityResult as ResultSuccess<FacilityProfile>).value;
          resolvedLogoUrl = uploadedLogoUrl;
        }

        final contactResult = await _repository.saveFacilityContactAddress(
          tenantId: tenantId,
          facilityId: facility.mutationId,
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
      refreshSetup: refreshSetup,
    );
  }

    String? id,
    required String tenantId,
    String? facilityId,
    required String name,
    required bool isActive,
  }) {
    return _submit(
        id: id,
        tenantId: tenantId,
        facilityId: facilityId,
        name: name,
        isActive: isActive,
      ),
        return snapshot.copyWith(
            snapshot.branches,
            branch,
          ),
        );
      },
    );
  }

    return _submit(
      updateSnapshot: (FacilitySetupSnapshot snapshot, _) {
        final DateTime deletedAt = DateTime.now().toUtc();
        final List<DepartmentProfile> departments = <DepartmentProfile>[
          for (final DepartmentProfile department in snapshot.departments)
                ? department.copyWith(deletedAt: deletedAt)
                : department,
        ];
        final Set<String> deletedDepartmentIds = <String>{
          for (final DepartmentProfile department in departments)
        };
        return snapshot.copyWith(
              branch.id == id ? branch.copyWith(deletedAt: deletedAt) : branch,
          ],
          departments: departments,
          units: <UnitProfile>[
            for (final UnitProfile unit in snapshot.units)
              unit.departmentId != null &&
                      deletedDepartmentIds.contains(unit.departmentId)
                  ? unit.copyWith(deletedAt: deletedAt)
                  : unit,
          ],
        );
      },
    );
  }

    return _submit(
        return snapshot.copyWith(
            snapshot.branches,
            branch.copyWith(clearDeletedAt: true),
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
        final DateTime deletedAt = DateTime.now().toUtc();
        return snapshot.copyWith(
          departments: <DepartmentProfile>[
            for (final DepartmentProfile department in snapshot.departments)
              department.id == id
                  ? department.copyWith(deletedAt: deletedAt)
                  : department,
          ],
          units: <UnitProfile>[
            for (final UnitProfile unit in snapshot.units)
              unit.departmentId == id
                  ? unit.copyWith(deletedAt: deletedAt)
                  : unit,
          ],
        );
      },
    );
  }

  Future<bool> restoreDepartment(String id) {
    return _submit(
      () => _repository.restoreDepartment(id),
      updateSnapshot:
          (FacilitySetupSnapshot snapshot, DepartmentProfile department) {
            return snapshot.copyWith(
              departments: _upsertById<DepartmentProfile>(
                snapshot.departments,
                department.copyWith(clearDeletedAt: true),
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
        final DateTime deletedAt = DateTime.now().toUtc();
        return snapshot.copyWith(
          units: <UnitProfile>[
            for (final UnitProfile unit in snapshot.units)
              unit.id == id ? unit.copyWith(deletedAt: deletedAt) : unit,
          ],
        );
      },
    );
  }

  Future<bool> restoreUnit(String id) {
    return _submit(
      () => _repository.restoreUnit(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, UnitProfile unit) {
        return snapshot.copyWith(
          units: _upsertById<UnitProfile>(
            snapshot.units,
            unit.copyWith(clearDeletedAt: true),
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
        final DateTime deletedAt = DateTime.now().toUtc();
        final List<RoomProfile> rooms = <RoomProfile>[
          for (final RoomProfile room in snapshot.rooms)
            room.wardId == id ? room.copyWith(deletedAt: deletedAt) : room,
        ];
        final Set<String> deletedRoomIds = <String>{
          for (final RoomProfile room in rooms)
            if (room.wardId == id) room.id,
        };
        return snapshot.copyWith(
          wards: <WardProfile>[
            for (final WardProfile ward in snapshot.wards)
              ward.id == id ? ward.copyWith(deletedAt: deletedAt) : ward,
          ],
          rooms: rooms,
          beds: <BedProfile>[
            for (final BedProfile bed in snapshot.beds)
              bed.wardId == id ||
                      (bed.roomId != null &&
                          deletedRoomIds.contains(bed.roomId))
                  ? bed.copyWith(deletedAt: deletedAt)
                  : bed,
          ],
        );
      },
    );
  }

  Future<bool> restoreWard(String id) {
    return _submit(
      () => _repository.restoreWard(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, WardProfile ward) {
        return snapshot.copyWith(
          wards: _upsertById<WardProfile>(
            snapshot.wards,
            ward.copyWith(clearDeletedAt: true),
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
        final DateTime deletedAt = DateTime.now().toUtc();
        return snapshot.copyWith(
          rooms: <RoomProfile>[
            for (final RoomProfile room in snapshot.rooms)
              room.id == id ? room.copyWith(deletedAt: deletedAt) : room,
          ],
          beds: <BedProfile>[
            for (final BedProfile bed in snapshot.beds)
              bed.roomId == id ? bed.copyWith(deletedAt: deletedAt) : bed,
          ],
        );
      },
    );
  }

  Future<bool> restoreRoom(String id) {
    return _submit(
      () => _repository.restoreRoom(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, RoomProfile room) {
        return snapshot.copyWith(
          rooms: _upsertById<RoomProfile>(
            snapshot.rooms,
            room.copyWith(clearDeletedAt: true),
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
        final DateTime deletedAt = DateTime.now().toUtc();
        return snapshot.copyWith(
          beds: <BedProfile>[
            for (final BedProfile bed in snapshot.beds)
              bed.id == id ? bed.copyWith(deletedAt: deletedAt) : bed,
          ],
        );
      },
    );
  }

  Future<bool> restoreBed(String id) {
    return _submit(
      () => _repository.restoreBed(id),
      updateSnapshot: (FacilitySetupSnapshot snapshot, BedProfile bed) {
        return snapshot.copyWith(
          beds: _upsertById<BedProfile>(
            snapshot.beds,
            bed.copyWith(clearDeletedAt: true),
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
    bool refreshSetup = true,
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

        state = state.copyWith(
          isSubmitting: false,
          clearFailure: true,
          successVersion: state.successVersion + 1,
        );

        if (refreshSetup) {
          unawaited(() async {
            final Result<FacilitySetupSnapshot> refreshResult =
                await setupController.refresh();
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
          }());
        }

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

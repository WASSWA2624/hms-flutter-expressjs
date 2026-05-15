import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final patientRegistryControllerProvider =
    AsyncNotifierProvider<
      PatientRegistryController,
      Result<PatientRegistryState>
    >(PatientRegistryController.new);

final class PatientRegistryController
    extends AsyncNotifier<Result<PatientRegistryState>> {
  PatientRepository get _repository => ref.read(patientRepositoryProvider);

  @override
  Future<Result<PatientRegistryState>> build() async {
    return _loadInitialState();
  }

  Future<AppFailure?> refresh() async {
    final Result<PatientRegistryState> result = await _loadInitialState();
    state = AsyncData<Result<PatientRegistryState>>(result);
    return _failureOrNull(result);
  }

  Future<AppFailure?> applyQuery(PatientListQuery query) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: query,
        isRefreshingList: true,
        clearLastFailure: true,
      ),
    );

    final Result<AppPage<Patient>> result = await _repository.listPatients(
      query,
    );
    return result.when(
      success: (AppPage<Patient> page) {
        final PatientDetail? selectedDetail = _selectedDetailAfterListRefresh(
          page,
          current.selectedDetail,
        );
        _emit(
          _currentState!.copyWith(
            page: page,
            selectedDetail: selectedDetail,
            isRefreshingList: false,
            clearSelectedDetail: selectedDetail == null,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            lastFailure: failure,
            isRefreshingList: false,
          ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> selectPatient(String patientId) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));

    final Result<PatientDetail> result = await _repository.loadPatientDetail(
      patientId,
    );
    return result.when(
      success: (PatientDetail detail) {
        final PatientRegistryState next = _currentState!.copyWith(
          selectedDetail: detail,
          page: _replacePatientInPage(_currentState!.page, detail.patient),
          isRefreshingDetail: false,
        );
        _emit(next);
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            lastFailure: failure,
            isRefreshingDetail: false,
          ),
        );
        return failure;
      },
    );
  }

  void clearSelection() {
    final PatientRegistryState? current = _currentState;
    if (current != null) {
      _emit(current.copyWith(clearSelectedDetail: true));
    }
  }

  Future<AppFailure?> createPatient(Map<String, Object?> payload) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<Patient> result = await _repository.createPatient(payload);
    return result.when(
      success: (Patient patient) async {
        await _refreshOverviewOnly();
        await applyQuery(_currentState!.query.copyWith());
        final AppFailure? detailFailure = await selectPatient(patient.id);
        _emit(_currentState!.copyWith(isSaving: false));
        return detailFailure;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> updatePatient(
    String patientId,
    Map<String, Object?> payload,
  ) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<Patient> result = await _repository.updatePatient(
      patientId,
      payload,
    );
    return result.when(
      success: (Patient patient) async {
        _emit(
          _currentState!.copyWith(
            page: _replacePatientInPage(_currentState!.page, patient),
          ),
        );
        final AppFailure? detailFailure = await selectPatient(patient.id);
        _emit(_currentState!.copyWith(isSaving: false));
        return detailFailure;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> deletePatient(String patientId) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<PatientMutationResult> result = await _repository
        .deletePatient(patientId);
    return result.when(
      success: (_) async {
        final AppPage<Patient> page = _removePatientFromPage(
          _currentState!.page,
          patientId,
        );
        _emit(
          _currentState!.copyWith(
            page: page,
            isSaving: false,
            clearSelectedDetail: true,
          ),
        );
        await _refreshOverviewOnly();
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> createRelatedRecord(
    PatientRelatedResource resource,
    Map<String, Object?> payload,
  ) async {
    return _mutateRelated(
      () => _repository.createRelatedRecord(resource, payload),
    );
  }

  Future<AppFailure?> updateRelatedRecord(
    PatientRelatedResource resource,
    String recordId,
    Map<String, Object?> payload,
  ) async {
    return _mutateRelated(
      () => _repository.updateRelatedRecord(resource, recordId, payload),
    );
  }

  Future<AppFailure?> deleteRelatedRecord(
    PatientRelatedResource resource,
    String recordId,
  ) async {
    return _mutateRelated(
      () => _repository.deleteRelatedRecord(resource, recordId),
    );
  }

  Future<AppFailure?> _mutateRelated(
    Future<Result<void>> Function() action,
  ) async {
    final PatientRegistryState? current = _currentState;
    final PatientDetail? selectedDetail = current?.selectedDetail;
    if (current == null || selectedDetail == null) {
      return null;
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await action();
    return result.when(
      success: (_) async {
        final AppFailure? detailFailure = await selectPatient(
          selectedDetail.patient.id,
        );
        await _refreshOverviewOnly();
        _emit(_currentState!.copyWith(isSaving: false));
        return detailFailure;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<Result<PatientRegistryState>> _loadInitialState() async {
    final Result<PatientRegistryOverview> overviewResult = await _repository
        .loadOverview();
    final PatientRegistryOverview? overview = _successOrNull(overviewResult);
    if (overview == null) {
      return Result<PatientRegistryState>.failure(
        _failureOrNull(overviewResult)!,
      );
    }

    final Result<PatientReferenceData> referenceResult = await _repository
        .loadReferenceData();
    final PatientReferenceData? referenceData = _successOrNull(referenceResult);
    if (referenceData == null) {
      return Result<PatientRegistryState>.failure(
        _failureOrNull(referenceResult)!,
      );
    }

    const PatientListQuery query = PatientListQuery();
    final Result<AppPage<Patient>> pageResult = await _repository.listPatients(
      query,
    );
    final AppPage<Patient>? page = _successOrNull(pageResult);
    if (page == null) {
      return Result<PatientRegistryState>.failure(_failureOrNull(pageResult)!);
    }

    return Result<PatientRegistryState>.success(
      PatientRegistryState(
        query: query,
        page: page,
        overview: overview,
        referenceData: referenceData,
      ),
    );
  }

  Future<void> _refreshOverviewOnly() async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return;
    }

    final Result<PatientRegistryOverview> result = await _repository
        .loadOverview();
    result.when(
      success: (PatientRegistryOverview overview) {
        final PatientRegistryState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(overview: overview));
        }
      },
      failure: (_) {},
    );
  }

  PatientDetail? _selectedDetailAfterListRefresh(
    AppPage<Patient> page,
    PatientDetail? selectedDetail,
  ) {
    if (selectedDetail == null) {
      return null;
    }
    final Iterable<Patient> matching = page.items.where(
      (Patient patient) => patient.id == selectedDetail.patient.id,
    );
    if (matching.isEmpty) {
      return selectedDetail;
    }

    return selectedDetail.copyWith(patient: matching.first);
  }

  AppPage<Patient> _replacePatientInPage(
    AppPage<Patient> page,
    Patient patient,
  ) {
    return AppPage<Patient>(
      items: <Patient>[
        for (final Patient item in page.items)
          if (item.id == patient.id) patient else item,
      ],
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  AppPage<Patient> _removePatientFromPage(
    AppPage<Patient> page,
    String patientId,
  ) {
    final List<Patient> items = page.items
        .where((Patient item) => item.id != patientId)
        .toList(growable: false);
    final int? total = page.totalItemCount == null
        ? null
        : (page.totalItemCount! - (page.items.length - items.length)).clamp(
            0,
            page.totalItemCount!,
          );

    return AppPage<Patient>(
      items: items,
      request: page.request,
      totalItemCount: total,
    );
  }

  PatientRegistryState? get _currentState {
    final Result<PatientRegistryState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<PatientRegistryState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(PatientRegistryState nextState) {
    state = AsyncData<Result<PatientRegistryState>>(
      Result<PatientRegistryState>.success(nextState),
    );
  }

  T? _successOrNull<T>(Result<T> result) {
    return result.when(success: (T value) => value, failure: (_) => null);
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }
}

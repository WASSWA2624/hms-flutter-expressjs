import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/hr/data/dtos/hr_dtos.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  return HrRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class HrRepositoryImpl implements HrRepository {
  const HrRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<HrWorkspaceOverview>> loadOverview() {
    return _apiClient.get<HrWorkspaceOverview>(
      _hrEndpoint(<String>['workspace']),
      queryParameters: const <String, Object?>{
        'panel': 'staffing',
        'resource': 'staff-profiles',
        'limit': 20,
      },
      decoder: (Object? data) =>
          HrWorkspaceOverviewDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<HrReferenceData>> loadReferenceData({
    String? facilityId,
    String? departmentId,
  }) {
    return _apiClient.get<HrReferenceData>(
      _hrEndpoint(<String>['reference-data']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'facility_id': facilityId,
        'department_id': departmentId,
      }),
      decoder: (Object? data) =>
          HrReferenceDataDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AppPage<HrStaffProfile>>> listStaffProfiles(
    HrStaffQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<HrStaffProfile>>(
      ApiEndpoints.collection(HmsApiResource.staffProfiles),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'department_id': query.departmentId,
        'position': query.position,
        'practitioner_type': query.practitionerType,
        'sort_by': 'created_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          HrStaffProfilePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<HrStaffDetail>> loadStaffDetail(HrStaffProfile profile) async {
    final Result<HrStaffProfile> profileResult = await _apiClient
        .get<HrStaffProfile>(
          ApiEndpoints.byId(HmsApiResource.staffProfiles, profile.effectiveId),
          decoder: (Object? data) =>
              HrStaffProfileDto.fromResponse(data).toEntity(),
        );

    return profileResult.when(
      success: (HrStaffProfile detail) async {
        final List<HrStaffAssignment> assignments = await _loadStaffAssignments(
          detail.effectiveId,
        );
        final List<HrStaffLeave> leaves = await _loadStaffLeaves(
          detail.effectiveId,
        );
        final List<HrStaffAvailability> availabilities =
            await _loadStaffAvailabilities(detail.effectiveId);
        final List<HrShiftAssignment> shiftAssignments =
            await _loadShiftAssignments(detail.effectiveId);
        final HrStaffAccessSummary? accessSummary =
            await _loadStaffAccessSummaryOrEmpty(detail.effectiveId);

        return Result<HrStaffDetail>.success(
          HrStaffDetail(
            profile: detail,
            assignments: assignments,
            leaves: leaves,
            availabilities: availabilities,
            compensations: detail.compensations,
            shiftAssignments: shiftAssignments,
            accessSummary: accessSummary,
          ),
        );
      },
      failure: (failure) => Result<HrStaffDetail>.failure(failure),
    );
  }

  @override
  Future<Result<AppPage<HrWorkItem>>> listWorkItems(HrWorkItemsQuery query) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<HrWorkItem>>(
      _hrEndpoint(<String>['work-items']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'queue': query.queue.value,
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'status': query.status,
        'department_id': query.departmentId,
        'facility_id': query.facilityId,
      }),
      decoder: (Object? data) =>
          HrWorkItemPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<HrStaffProfile>> createStaffProfile(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<HrStaffProfile>(
      ApiEndpoints.collection(HmsApiResource.staffProfiles),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          HrStaffProfileDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<HrStaffProfile>> updateStaffProfile(
    String staffProfileId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<HrStaffProfile>(
      ApiEndpoints.byId(HmsApiResource.staffProfiles, staffProfileId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          HrStaffProfileDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<Object?>> createStaffAssignment(Map<String, Object?> payload) {
    return _postCollection(HmsApiResource.staffAssignments, payload);
  }

  @override
  Future<Result<Object?>> createStaffAvailability(
    Map<String, Object?> payload,
  ) {
    return _postCollection(HmsApiResource.staffAvailabilities, payload);
  }

  @override
  Future<Result<Object?>> createStaffLeave(Map<String, Object?> payload) {
    return _postCollection(HmsApiResource.staffLeaves, payload);
  }

  @override
  Future<Result<Object?>> createShiftAssignment(Map<String, Object?> payload) {
    return _postCollection(HmsApiResource.shiftAssignments, payload);
  }

  @override
  Future<Result<Object?>> createShiftSwapRequest(Map<String, Object?> payload) {
    return _postCollection(HmsApiResource.shiftSwapRequests, payload);
  }

  @override
  Future<Result<Object?>> createPayrollRun(Map<String, Object?> payload) {
    return _postCollection(HmsApiResource.payrollRuns, payload);
  }

  @override
  Future<Result<Object?>> approveLeave(String leaveId, {String? reason}) {
    return _postHrAction(
      <String>['leaves', leaveId, 'approve'],
      <String, Object?>{'reason': reason},
    );
  }

  @override
  Future<Result<Object?>> rejectLeave(
    String leaveId, {
    required String reason,
  }) {
    return _postHrAction(
      <String>['leaves', leaveId, 'reject'],
      <String, Object?>{'reason': reason},
    );
  }

  @override
  Future<Result<Object?>> approveSwap(String swapId, {String? reason}) {
    return _postHrAction(
      <String>['swaps', swapId, 'approve'],
      <String, Object?>{'reason': reason},
    );
  }

  @override
  Future<Result<Object?>> rejectSwap(String swapId, {required String reason}) {
    return _postHrAction(
      <String>['swaps', swapId, 'reject'],
      <String, Object?>{'reason': reason},
    );
  }

  @override
  Future<Result<Object?>> publishRoster(
    String rosterId, {
    bool notifyStaff = true,
    bool allowPartialPublish = false,
    String? publishNote,
  }) {
    return _postHrAction(
      <String>['rosters', rosterId, 'publish'],
      <String, Object?>{
        'notify_staff': notifyStaff,
        'allow_partial_publish': allowPartialPublish,
        'publish_note': publishNote,
      },
    );
  }

  @override
  Future<Result<Object?>> generateRoster(
    String rosterId, {
    bool replaceExistingAssignments = true,
    bool dryRun = false,
  }) {
    return _postHrAction(
      <String>['rosters', rosterId, 'generate'],
      <String, Object?>{
        'replace_existing_assignments': replaceExistingAssignments,
        'dry_run': dryRun,
      },
    );
  }

  @override
  Future<Result<Object?>> overrideShift(
    String shiftId, {
    required String staffProfileId,
    required String reason,
  }) {
    return _postHrAction(
      <String>['shifts', shiftId, 'override'],
      <String, Object?>{'staff_profile_id': staffProfileId, 'reason': reason},
    );
  }

  @override
  Future<Result<Object?>> processPayrollRun(
    String payrollRunId, {
    bool replaceExistingItems = false,
    String? notes,
  }) {
    return _postHrAction(
      <String>['payroll-runs', payrollRunId, 'process'],
      <String, Object?>{
        'replace_existing_items': replaceExistingItems,
        'notes': notes,
      },
    );
  }

  @override
  Future<Result<HrStaffAccessSummary>> loadStaffAccessSummary(
    String staffProfileId,
  ) {
    return _apiClient.get<HrStaffAccessSummary>(
      _hrEndpoint(<String>['staff', staffProfileId, 'access-summary']),
      decoder: (Object? data) =>
          HrStaffAccessSummaryDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<void>> assignUserRole({
    required String userId,
    required String roleId,
    required String tenantId,
    String? facilityId,
  }) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.userRoles),
      data: _withoutEmpty(<String, Object?>{
        'user_id': userId,
        'role_id': roleId,
        'tenant_id': tenantId,
        'facility_id': facilityId,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> revokeUserRole(String userRoleId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.userRoles, userRoleId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<Object?>> createUserAccount(Map<String, Object?> payload) {
    return _apiClient.post<Object?>(
      ApiEndpoints.collection(HmsApiResource.users),
      data: _withoutEmpty(payload),
      decoder: passthroughResponseData,
    );
  }

  @override
  Future<Result<Object?>> updateStaffAssignment(
    String assignmentId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<Object?>(
      ApiEndpoints.byId(HmsApiResource.staffAssignments, assignmentId),
      data: _withoutEmpty(payload),
      decoder: passthroughResponseData,
    );
  }

  @override
  Future<Result<Object?>> createShiftTemplate(Map<String, Object?> payload) {
    return _postCollection(HmsApiResource.shiftTemplates, payload);
  }

  @override
  Future<Result<Object?>> updateShiftTemplate(
    String templateId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<Object?>(
      ApiEndpoints.byId(HmsApiResource.shiftTemplates, templateId),
      data: _withoutEmpty(payload),
      decoder: passthroughResponseData,
    );
  }

  @override
  Future<Result<Object?>> deleteShiftTemplate(String templateId) {
    return _apiClient.delete<Object?>(
      ApiEndpoints.byId(HmsApiResource.shiftTemplates, templateId),
      decoder: (_) => null,
    );
  }

  @override
  Future<Result<HrPayrollPreview>> previewPayrollRun(String payrollRunId) {
    return _apiClient.get<HrPayrollPreview>(
      _hrEndpoint(<String>['payroll-runs', payrollRunId, 'preview']),
      decoder: (Object? data) =>
          HrPayrollPreviewDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<HrRosterGenerateResult>> generateRosterPreview(
    String rosterId, {
    bool replaceExistingAssignments = true,
  }) {
    return _apiClient.post<HrRosterGenerateResult>(
      _hrEndpoint(<String>['rosters', rosterId, 'generate']),
      data: <String, Object?>{
        'replace_existing_assignments': replaceExistingAssignments,
        'dry_run': true,
      },
      decoder: (Object? data) =>
          HrRosterGenerateResultDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AppPage<HrAccessUser>>> listAccessUsers(HrAccessQuery query) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<HrAccessUser>>(
      ApiEndpoints.collection(HmsApiResource.users),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'tenant_id': query.tenantId,
        'sort_by': 'created_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          HrAccessUserPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AppPage<HrAccessRole>>> listAccessRoles(HrAccessQuery query) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<HrAccessRole>>(
      ApiEndpoints.collection(HmsApiResource.roles),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'tenant_id': query.tenantId,
        'sort_by': 'created_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          HrAccessRolePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AppPage<HrAccessPermission>>> listAccessPermissions(
    HrAccessQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<HrAccessPermission>>(
      ApiEndpoints.collection(HmsApiResource.permissions),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'tenant_id': query.tenantId,
        'sort_by': 'created_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          HrAccessPermissionPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<Object?>> updateUserAccount(
    String userId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<Object?>(
      ApiEndpoints.byId(HmsApiResource.users, userId),
      data: _withoutEmpty(payload),
      decoder: passthroughResponseData,
    );
  }

  @override
  Future<Result<Object?>> createRole(Map<String, Object?> payload) {
    return _postCollection(HmsApiResource.roles, payload);
  }

  @override
  Future<Result<Object?>> updateRole(
    String roleId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<Object?>(
      ApiEndpoints.byId(HmsApiResource.roles, roleId),
      data: _withoutEmpty(payload),
      decoder: passthroughResponseData,
    );
  }

  @override
  Future<Result<void>> deleteRole(String roleId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.roles, roleId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<Object?>> createPermission(Map<String, Object?> payload) {
    return _postCollection(HmsApiResource.permissions, payload);
  }

  @override
  Future<Result<Object?>> updatePermission(
    String permissionId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<Object?>(
      ApiEndpoints.byId(HmsApiResource.permissions, permissionId),
      data: _withoutEmpty(payload),
      decoder: passthroughResponseData,
    );
  }

  @override
  Future<Result<void>> deletePermission(String permissionId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.permissions, permissionId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> assignRolePermission({
    required String roleId,
    required String permissionId,
  }) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.rolePermissions),
      data: <String, Object?>{'role_id': roleId, 'permission_id': permissionId},
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> revokeRolePermission(String rolePermissionId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.rolePermissions, rolePermissionId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<AppPage<HrOption>>> listRolePermissions(String roleId) {
    const AppPageRequest request = AppPageRequest(pageSize: 200);
    return _apiClient.get<AppPage<HrOption>>(
      ApiEndpoints.collection(HmsApiResource.rolePermissions),
      queryParameters: <String, Object?>{
        'role_id': roleId,
        'page': 1,
        'limit': request.pageSize,
      },
      decoder: (Object? data) {
        final Map<String, Object?> response = data is Map<String, Object?>
            ? data
            : <String, Object?>{};
        final List<Object?> rows = response['data'] is List<Object?>
            ? response['data']! as List<Object?>
            : const <Object?>[];
        final List<HrOption> items = rows
            .whereType<Map<String, Object?>>()
            .map((Map<String, Object?> entry) {
              final Map<String, Object?> permission =
                  entry['permission'] is Map<String, Object?>
                  ? entry['permission']! as Map<String, Object?>
                  : <String, Object?>{};
              final String permissionId =
                  permission['human_friendly_id']?.toString() ??
                  permission['id']?.toString() ??
                  entry['permission_id']?.toString() ??
                  '';
              final String permissionName =
                  permission['name']?.toString() ?? permissionId;
              final String assignmentId =
                  entry['human_friendly_id']?.toString() ??
                  entry['id']?.toString() ??
                  '';
              return HrOption(
                value: permissionId,
                label: permissionName,
                displayId: assignmentId,
              );
            })
            .where((HrOption item) => item.value.isNotEmpty)
            .toList(growable: false);
        return AppPage<HrOption>(
          items: items,
          request: request,
          totalItemCount: items.length,
        );
      },
    );
  }

  Future<HrStaffAccessSummary?> _loadStaffAccessSummaryOrEmpty(
    String staffProfileId,
  ) async {
    final Result<HrStaffAccessSummary> result = await loadStaffAccessSummary(
      staffProfileId,
    );
    return result.when(
      success: (HrStaffAccessSummary value) => value,
      failure: (_) => null,
    );
  }

  Future<List<HrStaffAssignment>> _loadStaffAssignments(
    String staffProfileId,
  ) async {
    final Result<List<HrStaffAssignment>> result = await _apiClient
        .get<List<HrStaffAssignment>>(
          ApiEndpoints.collection(HmsApiResource.staffAssignments),
          queryParameters: <String, Object?>{
            'staff_profile_id': staffProfileId,
            'limit': 20,
          },
          decoder: (Object? data) =>
              HrStaffAssignmentPageDto.fromResponse(data).items,
        );
    return result.when(success: (items) => items, failure: (_) => const []);
  }

  Future<List<HrStaffLeave>> _loadStaffLeaves(String staffProfileId) async {
    final Result<List<HrStaffLeave>> result = await _apiClient
        .get<List<HrStaffLeave>>(
          ApiEndpoints.collection(HmsApiResource.staffLeaves),
          queryParameters: <String, Object?>{
            'staff_profile_id': staffProfileId,
            'limit': 20,
          },
          decoder: (Object? data) =>
              HrStaffLeavePageDto.fromResponse(data).items,
        );
    return result.when(success: (items) => items, failure: (_) => const []);
  }

  Future<List<HrStaffAvailability>> _loadStaffAvailabilities(
    String staffProfileId,
  ) async {
    final Result<List<HrStaffAvailability>> result = await _apiClient
        .get<List<HrStaffAvailability>>(
          ApiEndpoints.collection(HmsApiResource.staffAvailabilities),
          queryParameters: <String, Object?>{
            'staff_profile_id': staffProfileId,
            'limit': 20,
          },
          decoder: (Object? data) =>
              HrStaffAvailabilityPageDto.fromResponse(data).items,
        );
    return result.when(success: (items) => items, failure: (_) => const []);
  }

  Future<List<HrShiftAssignment>> _loadShiftAssignments(
    String staffProfileId,
  ) async {
    final Result<List<HrShiftAssignment>> result = await _apiClient
        .get<List<HrShiftAssignment>>(
          ApiEndpoints.collection(HmsApiResource.shiftAssignments),
          queryParameters: <String, Object?>{
            'staff_profile_id': staffProfileId,
            'limit': 20,
          },
          decoder: (Object? data) =>
              HrShiftAssignmentPageDto.fromResponse(data).items,
        );
    return result.when(success: (items) => items, failure: (_) => const []);
  }

  Future<Result<Object?>> _postCollection(
    HmsApiResource resource,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<Object?>(
      ApiEndpoints.collection(resource),
      data: _withoutEmpty(payload),
      decoder: passthroughResponseData,
    );
  }

  Future<Result<Object?>> _postHrAction(
    List<String> pathSegments,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<Object?>(
      _hrEndpoint(pathSegments),
      data: _withoutEmpty(payload),
      decoder: passthroughResponseData,
    );
  }

  Uri _hrEndpoint(List<String> pathSegments) {
    return ApiEndpoints.apiV1(<String>[
      HmsApiResource.hr.path,
      ...pathSegments,
    ]);
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

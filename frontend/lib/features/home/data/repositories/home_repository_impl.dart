import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/home/data/dtos/home_dashboard_dtos.dart';
import 'package:hosspi_hms/features/home/data/dtos/home_dashboard_lookups_dtos.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(
    apiClient: () => ref.read(apiClientProvider),
    accessPolicy: ref.watch(appAccessPolicyProvider),
    session: ref.watch(sessionStateProvider.select((state) => state.session)),
  );
});

final class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl({
    required ApiClient Function() apiClient,
    required AppAccessPolicy accessPolicy,
    required AuthSession? session,
  }) : _apiClient = apiClient,
       _accessPolicy = accessPolicy,
       _session = session;

  final ApiClient Function() _apiClient;
  final AppAccessPolicy _accessPolicy;
  final AuthSession? _session;

  @override
  Future<Result<HomeDashboard>> loadDashboard(
    HomeDashboardRequest request,
  ) async {
    final HomeDashboardRequest effectiveRequest = _effectiveRequest(request);
    final HomeDashboardProfile localProfile = homeProfileForRoles(
      _accessPolicy.roles,
    );

    if (_shouldUseLocalDashboard(localProfile, effectiveRequest)) {
      return Result<HomeDashboard>.success(
        _localDashboard(localProfile, usesFallbackData: true),
      );
    }

    final result = await _apiClient().get<HomeDashboard>(
      ApiEndpoints.nested(
        HmsApiResource.dashboardWorkspace,
        'workspace',
        const <String>[],
      ),
      queryParameters: effectiveRequest.toQueryParameters(),
      decoder: (Object? data) {
        return HomeDashboardDto.fromResponse(data).toEntity();
      },
    );

    return result.when(
      success: (HomeDashboard dashboard) {
        return Result<HomeDashboard>.success(
          _mergeDashboard(localProfile, dashboard),
        );
      },
      failure: (AppFailure failure) {
        if (_shouldFallbackToLocalDashboard(failure)) {
          return Result<HomeDashboard>.success(
            _localDashboard(localProfile, usesFallbackData: true),
          );
        }
        return Result<HomeDashboard>.failure(failure);
      },
    );
  }

  @override
  Future<Result<HomeDashboardLookups>> loadLookups(
    HomeDashboardRequest request,
  ) async {
    final HomeDashboardProfile localProfile = homeProfileForRoles(
      _accessPolicy.roles,
    );
    if (_session == null || localProfile.role == AppRole.other) {
      return const Result<HomeDashboardLookups>.success(HomeDashboardLookups());
    }

    final HomeDashboardRequest effectiveRequest = _effectiveRequest(request);
    final result = await _apiClient().get<HomeDashboardLookups>(
      ApiEndpoints.nested(
        HmsApiResource.dashboardWorkspace,
        'lookups',
        const <String>[],
      ),
      queryParameters: effectiveRequest.toQueryParameters(),
      decoder: (Object? data) {
        return HomeDashboardLookupsDto.fromResponse(data).toEntity();
      },
    );

    return result.when(
      success: (HomeDashboardLookups lookups) {
        return Result<HomeDashboardLookups>.success(lookups);
      },
      failure: (AppFailure failure) {
        if (_shouldFallbackToLocalDashboard(failure)) {
          return const Result<HomeDashboardLookups>.success(
            HomeDashboardLookups(),
          );
        }
        return Result<HomeDashboardLookups>.failure(failure);
      },
    );
  }

  HomeDashboard _mergeDashboard(
    HomeDashboardProfile localProfile,
    HomeDashboard dashboard,
  ) {
    final HomeDashboardProfile profile = dashboard.profile.role == AppRole.other
        ? localProfile
        : dashboard.profile;
    final List<String> quickActionIds = localProfile.suppressHomeQuickActions
        ? const <String>[]
        : dashboard.quickActionIds.isEmpty
        ? localProfile.quickActionIds
        : dashboard.quickActionIds;
    final List<String> shortcutIds = localProfile.suppressHomeShortcuts
        ? const <String>[]
        : dashboard.shortcutIds.isEmpty
        ? localProfile.shortcutIds
        : dashboard.shortcutIds;

    return dashboard.copyWith(
      profile: profile,
      quickActionIds: quickActionIds,
      shortcutIds: shortcutIds,
    );
  }

  HomeDashboardRequest _effectiveRequest(HomeDashboardRequest request) {
    return HomeDashboardRequest(
      tenantId: request.tenantId ?? _accessPolicy.tenantId,
      facilityId: request.facilityId ?? _accessPolicy.facilityId,
      branchId: request.branchId ?? _accessPolicy.branchId,
    );
  }

  bool _shouldUseLocalDashboard(
    HomeDashboardProfile profile,
    HomeDashboardRequest request,
  ) {
    if (profile.role == AppRole.other) {
      return true;
    }
    if (_session == null) {
      return true;
    }
    if (profile.role == AppRole.superAdmin) {
      return false;
    }

    return !_accessPolicy.hasTenantContext && !request.hasTenantContext;
  }

  bool _shouldFallbackToLocalDashboard(AppFailure failure) {
    return failure.category == AppFailureCategory.notFound ||
        failure.category == AppFailureCategory.forbidden;
  }

  HomeDashboard _localDashboard(
    HomeDashboardProfile profile, {
    required bool usesFallbackData,
  }) {
    final AuthUserProfile? user = _session?.user;

    return HomeDashboard(
      state: HomeDashboardLoadState.ready,
      profile: profile,
      context: HomeDashboardContext(
        roleValue: profile.role.value,
        tenantId: _accessPolicy.tenantId,
        facilityId: _accessPolicy.facilityId,
        facilityName: user?.facilityName,
        facilityType: user?.facilityType,
        branchId: _accessPolicy.branchId,
      ),
      statusCards: profile.fallbackStatusCards(),
      trend: HomeDashboardTrend.empty,
      distribution: HomeDashboardDistribution.empty,
      quickActionIds: profile.suppressHomeQuickActions
        ? const <String>[]
        : profile.quickActionIds,
      shortcutIds: profile.suppressHomeShortcuts
        ? const <String>[]
        : profile.shortcutIds,
      queuePreview: const <HomeQueueItem>[],
      alerts: const <HomeAlertItem>[],
      activity: const <HomeActivityItem>[],
      tenantOptions: const <HomeTenantOption>[],
      generatedAt: DateTime.now().toUtc(),
      usesFallbackData: usesFallbackData,
    );
  }
}

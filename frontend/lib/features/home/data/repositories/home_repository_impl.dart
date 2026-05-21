import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/home/data/dtos/home_dashboard_dtos.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
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
    final HomeDashboardProfile localProfile = homeProfileForRoles(
      _accessPolicy.roles,
    );

    if (_shouldUseLocalDashboard(localProfile, request)) {
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
      queryParameters: request.toQueryParameters(),
      decoder: (Object? data) {
        return HomeDashboardDto.fromResponse(data).toEntity();
      },
    );

    return result.map((HomeDashboard dashboard) {
      final HomeDashboardProfile profile =
          dashboard.profile.role == AppRole.other
          ? localProfile
          : dashboard.profile;
      final List<String> quickActionIds = _mergeIds(<Iterable<String>>[
        dashboard.quickActionIds,
        mergedHomeQuickActions(_accessPolicy.roles),
      ]);
      final List<String> shortcutIds = _mergeIds(<Iterable<String>>[
        dashboard.shortcutIds,
        mergedHomeShortcuts(_accessPolicy.roles),
      ]);

      return dashboard.copyWith(
        profile: profile,
        quickActionIds: quickActionIds,
        shortcutIds: shortcutIds,
      );
    });
  }

  bool _shouldUseLocalDashboard(
    HomeDashboardProfile profile,
    HomeDashboardRequest request,
  ) {
    if (profile.role == AppRole.patient || profile.role == AppRole.other) {
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

  HomeDashboard _localDashboard(
    HomeDashboardProfile profile, {
    required bool usesFallbackData,
  }) {
    final AuthUserProfile? user = _session?.user;
    final Set<AppRole> roles = _accessPolicy.roles.isEmpty
        ? <AppRole>{profile.role}
        : _accessPolicy.roles;
    final List<String> quickActions = _mergeIds(<Iterable<String>>[
      profile.quickActionIds,
      mergedHomeQuickActions(roles),
    ]);
    final List<String> shortcuts = _mergeIds(<Iterable<String>>[
      profile.shortcutIds,
      mergedHomeShortcuts(roles),
    ]);

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
      quickActionIds: quickActions,
      shortcutIds: shortcuts,
      queuePreview: const <HomeQueueItem>[],
      alerts: const <HomeAlertItem>[],
      activity: const <HomeActivityItem>[],
      tenantOptions: const <HomeTenantOption>[],
      generatedAt: DateTime.now().toUtc(),
      usesFallbackData: usesFallbackData,
    );
  }

  List<String> _mergeIds(Iterable<Iterable<String>> groups) {
    final ids = <String>{};
    for (final Iterable<String> group in groups) {
      ids.addAll(group.where((String id) => id.trim().isNotEmpty));
    }
    return ids.toList(growable: false);
  }
}

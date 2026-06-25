import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/api_response.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';
import 'package:hosspi_hms/features/profile/data/dtos/user_profile_dtos.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';
import 'package:hosspi_hms/features/profile/domain/repositories/user_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

final class UserProfileRepositoryImpl implements UserProfileRepository {
  const UserProfileRepositoryImpl({
    required ApiClient apiClient,
    required AuthRepository authRepository,
  }) : _apiClient = apiClient,
       _authRepository = authRepository;

  final ApiClient _apiClient;
  final AuthRepository _authRepository;

  @override
  Future<Result<UserProfileView>> loadCurrentProfile(
    AuthSession session,
  ) async {
    final Result<AuthSession> refreshed = await _authRepository
        .fetchCurrentUser(session);

    if (refreshed case ResultFailure<AuthSession>(failure: final failure)) {
      return Result<UserProfileView>.failure(failure);
    }

    final AuthSession enrichedSession =
        (refreshed as ResultSuccess<AuthSession>).value;
    final String? userId = enrichedSession.user?.id;
    if (userId == null || userId.trim().isEmpty) {
      return Result<UserProfileView>.success(
        UserProfileView(session: enrichedSession),
      );
    }

    final Result<UserProfileRecord?> recordResult = await _findProfileForUser(
      userId,
    );
    return recordResult.when(
      success: (UserProfileRecord? record) {
        return Result<UserProfileView>.success(
          UserProfileView(session: enrichedSession, record: record),
        );
      },
      failure: (_) {
        return Result<UserProfileView>.success(
          UserProfileView(session: enrichedSession),
        );
      },
    );
  }

  @override
  Future<Result<UserProfileRecord>> updateProfile(
    String profileId,
    UserProfileDraft draft,
  ) {
    return _apiClient.put<UserProfileRecord>(
      ApiEndpoints.byId(HmsApiResource.userProfiles, profileId),
      data: UserProfileRecordDto.toUpdatePayload(draft),
      decoder: (Object? data) {
        return UserProfileRecordDto.fromJson(
          ApiResponseEnvelope.decodeData<UserProfileJsonMap>(
            data,
            decoder: (Object? payload) => payload as UserProfileJsonMap,
          ),
        ).record;
      },
    );
  }

  Future<Result<UserProfileRecord?>> _findProfileForUser(String userId) {
    return _apiClient.get<UserProfileRecord?>(
      ApiEndpoints.collection(HmsApiResource.userProfiles),
      queryParameters: <String, Object?>{
        'user_id': userId,
        'limit': 1,
        'page': 1,
      },
      decoder: (Object? data) {
        final List<UserProfileRecord> records = UserProfileListDto.fromResponse(
          data,
        ).records;
        return records.isEmpty ? null : records.first;
      },
    );
  }
}

typedef UserProfileJsonMap = Map<String, Object?>;

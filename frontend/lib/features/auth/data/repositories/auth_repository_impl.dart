import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/api_response.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';
import 'package:hosspi_hms/core/security/session_refresh_coordinator.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/data/dtos/auth_session_dto.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    sessionManager: ref.watch(sessionManagerProvider),
    refreshCoordinator: ref.watch(sessionRefreshCoordinatorProvider),
    failureMapper: ref.watch(networkFailureMapperProvider),
  );
});

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required ApiClient apiClient,
    required SessionManager sessionManager,
    required SessionRefreshCoordinator refreshCoordinator,
    NetworkFailureMapper failureMapper = const NetworkFailureMapper(),
  }) : _apiClient = apiClient,
       _sessionManager = sessionManager,
       _refreshCoordinator = refreshCoordinator,
       _failureMapper = failureMapper;

  final ApiClient _apiClient;
  final SessionManager _sessionManager;
  final SessionRefreshCoordinator _refreshCoordinator;
  final NetworkFailureMapper _failureMapper;

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    try {
      final state = await _sessionManager.restore();
      final session = state.session;
      if (session == null) {
        return const Result<AuthSession?>.success(null);
      }

      if (!session.tokens.isAccessTokenExpired(DateTime.now().toUtc())) {
        return Result<AuthSession?>.success(session);
      }

      final refreshResult = await refreshSession(session.tokens);
      return refreshResult.map<AuthSession?>((session) => session);
    } catch (error, stackTrace) {
      return Result<AuthSession?>.failure(
        _failureMapper.map(error, stackTrace),
      );
    }
  }

  @override
  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  }) async {
    final normalizedIdentifier = identifier.trim();
    if (normalizedIdentifier.isEmpty || password.isEmpty) {
      return Result<AuthSession>.failure(
        AppFailure.validation(
          code: 'auth.login.invalid_input',
          validationFields: const <String>{'identifier', 'password'},
        ),
      );
    }

    final payload = <String, Object?>{
      if (_looksLikeEmail(normalizedIdentifier))
        'email': normalizedIdentifier.toLowerCase()
      else
        'phone': normalizedIdentifier.replaceAll(RegExp(r'\D'), ''),
      'password': password,
      if (_normalizedOptional(tenantId) != null)
        'tenant_id': _normalizedOptional(tenantId),
      if (_normalizedOptional(facilityId) != null)
        'facility_id': _normalizedOptional(facilityId),
    };

    final result = await _apiClient.post<AuthSession>(
      ApiEndpoints.auth(AuthEndpoint.login),
      data: payload,
      decoder: (data) => ApiResponseEnvelope.decodeData<AuthSession>(
        data,
        decoder: (payload) => AuthSessionDto.fromResponseData(
          _requireCompletedLoginPayload(payload),
        ).toEntity(),
      ),
    );

    return result;
  }

  @override
  Future<Result<void>> register({
    required String email,
    required String password,
    required String facilityName,
    required String adminName,
    required String facilityType,
    String? phone,
    String? location,
    String? interests,
  }) {
    return _apiClient.post<void>(
      ApiEndpoints.auth(AuthEndpoint.register),
      data: <String, Object?>{
        'email': email.trim().toLowerCase(),
        'password': password,
        'facility_name': facilityName.trim(),
        'admin_name': adminName.trim(),
        'facility_type': facilityType,
        if (_normalizedOptional(phone) != null)
          'phone': _normalizedOptional(phone),
        if (_normalizedOptional(location) != null)
          'location': _normalizedOptional(location),
        if (_normalizedOptional(interests) != null)
          'interests': _normalizedOptional(interests),
      },
      decoder: (data) =>
          ApiResponseEnvelope.decodeData<void>(data, decoder: (_) {}),
    );
  }

  @override
  Future<Result<void>> verifyEmail({required String token, String? email}) {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return Future.value(
        Result<void>.failure(
          AppFailure.validation(
            code: 'auth.verify_email.invalid_token',
            validationFields: const <String>{'token'},
          ),
        ),
      );
    }

    return _apiClient.post<void>(
      ApiEndpoints.auth(AuthEndpoint.verifyEmail),
      data: <String, Object?>{
        'token': normalizedToken,
        if (_normalizedOptional(email) != null)
          'email': _normalizedOptional(email)?.toLowerCase(),
      },
      decoder: (data) =>
          ApiResponseEnvelope.decodeData<void>(data, decoder: (_) {}),
    );
  }

  @override
  Future<Result<AuthSession>> refreshSession(SessionTokens tokens) {
    final refreshToken = tokens.refreshToken;
    if (refreshToken == null) {
      return Future.value(
        const Result<AuthSession>.failure(AppFailure.unauthorized()),
      );
    }

    return _refreshCoordinator.run(() {
      return _apiClient.post<AuthSession>(
        ApiEndpoints.auth(AuthEndpoint.refresh),
        data: <String, Object?>{'refresh_token': refreshToken},
        decoder: (data) => ApiResponseEnvelope.decodeData<AuthSession>(
          data,
          decoder: (payload) =>
              AuthSessionDto.fromResponseData(payload).toEntity(),
        ),
      );
    });
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _apiClient.post<void>(
      ApiEndpoints.auth(AuthEndpoint.changePassword),
      data: <String, Object?>{
        'old_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
      decoder: (data) =>
          ApiResponseEnvelope.decodeData<void>(data, decoder: (_) {}),
    );
  }

  @override
  Future<Result<void>> logout() async {
    final tokens = await _sessionManager.readTokens();
    final result = await _apiClient.post<void>(
      ApiEndpoints.auth(AuthEndpoint.logout),
      data: <String, Object?>{
        if (tokens?.refreshToken case final String refreshToken)
          'refresh_token': refreshToken,
      },
      decoder: (data) =>
          ApiResponseEnvelope.decodeData<void>(data, decoder: (_) {}),
    );

    await _sessionManager.clearSession();
    return result.when(
      success: (_) => const Result<void>.success(null),
      failure: (failure) => Result<void>.failure(failure),
    );
  }

  static bool _looksLikeEmail(String value) {
    return value.contains('@');
  }

  static String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static Object? _requireCompletedLoginPayload(Object? payload) {
    if (payload is Map<String, Object?> &&
        payload['requires_facility_selection'] == true) {
      throw const FormatException('Facility selection is required.');
    }

    return payload;
  }
}

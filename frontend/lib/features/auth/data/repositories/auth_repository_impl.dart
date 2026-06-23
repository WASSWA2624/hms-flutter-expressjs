import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/api_response.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';
import 'package:hosspi_hms/core/security/session_refresh_service.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/data/dtos/auth_session_dto.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    publicApiClient: ref.watch(publicApiClientProvider),
    sessionRefreshService: ref.watch(sessionRefreshServiceProvider),
    sessionManager: ref.watch(sessionManagerProvider),
  );
});

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required ApiClient apiClient,
    required ApiClient publicApiClient,
    required SessionRefreshService sessionRefreshService,
    required SessionManager sessionManager,
  }) : _apiClient = apiClient,
       _publicApiClient = publicApiClient,
       _sessionRefreshService = sessionRefreshService,
       _sessionManager = sessionManager;

  final ApiClient _apiClient;
  final ApiClient _publicApiClient;
  final SessionRefreshService _sessionRefreshService;
  final SessionManager _sessionManager;

  @override
  Future<Result<AuthSession?>> restoreSession() {
    return _sessionRefreshService.restoreSession();
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

    final result = await _publicApiClient.post<AuthSession>(
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
    return _publicApiClient.post<void>(
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

    return _publicApiClient.post<void>(
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
  Future<Result<void>> resendEmailVerification({required String email}) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return Future.value(
        Result<void>.failure(
          AppFailure.validation(
            code: 'auth.resend_verification.invalid_email',
            validationFields: const <String>{'email'},
          ),
        ),
      );
    }

    return _publicApiClient.post<void>(
      ApiEndpoints.auth(AuthEndpoint.resendVerification),
      data: <String, Object?>{'email': normalizedEmail, 'type': 'email'},
      decoder: (data) =>
          ApiResponseEnvelope.decodeData<void>(data, decoder: (_) {}),
    );
  }

  @override
  Future<Result<AuthSession>> refreshSession(SessionTokens tokens) {
    return _sessionRefreshService.refreshSession(tokens);
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

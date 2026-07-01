import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';

abstract interface class AuthRepository {
  Future<Result<AuthSession?>> restoreSession();

  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  });

  Future<Result<void>> register({
    required String email,
    required String password,
    required String tenantName,
    required String facilityName,
    required String adminName,
    required String facilityType,
    required String phone,
    String? location,
    String? interests,
  });

  Future<Result<void>> verifyEmail({required String token, String? email});

  Future<Result<void>> resendEmailVerification({required String email});

  Future<Result<AuthIdentifyResult>> identify({required String identifier});

  Future<Result<void>> forgotPassword({
    required String email,
    required String tenantId,
  });

  Future<Result<void>> resetPassword({
    String? token,
    String? email,
    String? code,
    required String newPassword,
    required String confirmPassword,
  });

  Future<Result<AuthSession>> refreshSession(SessionTokens tokens);

  Future<Result<AuthSession>> fetchCurrentUser(AuthSession session);

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  });

  Future<Result<void>> logout();
}

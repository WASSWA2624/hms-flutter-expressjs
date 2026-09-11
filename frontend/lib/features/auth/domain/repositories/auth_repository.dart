import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/password_reset_request_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/registration_result.dart';

abstract interface class AuthRepository {
  Future<Result<AuthSession?>> restoreSession();

  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  });

  /// Submits a registration.
  ///
  /// [idempotencyKey] identifies the logical submission: retries of the same
  /// submission must reuse it so the backend replays the original outcome
  /// instead of bootstrapping a second workspace.
  Future<Result<RegistrationResult>> register({
    required String email,
    required String password,
    required String facilityName,
    required String adminName,
    required String facilityType,
    required String phone,
    required String idempotencyKey,
    String? tenantName,
    String? location,
    String? interests,
  });

  /// Asks the backend what actually happened to a registration submission.
  ///
  /// Used after a timeout or connection error so the UI can report the truth
  /// rather than assuming the registration failed.
  Future<Result<RegistrationResult>> registrationStatus({
    required String idempotencyKey,
  });

  Future<Result<EmailVerificationResult>> verifyEmail({
    required String token,
    String? email,
  });

  Future<Result<void>> resendEmailVerification({required String email});

  Future<Result<AuthIdentifyResult>> identify({required String identifier});

  Future<Result<PasswordResetRequestResult>> forgotPassword({
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

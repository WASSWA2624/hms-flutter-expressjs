import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

abstract interface class AuthRepository {
  Future<Result<AuthSession?>> restoreSession();

  Future<Result<AuthSession>> refreshSession(SessionTokens tokens);

  Future<Result<void>> logout();
}

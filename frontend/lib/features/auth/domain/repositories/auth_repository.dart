import 'package:flutter_template/core/errors/result.dart';
import 'package:flutter_template/core/security/auth_session.dart';
import 'package:flutter_template/core/security/session_tokens.dart';

abstract interface class AuthRepository {
  Future<Result<AuthSession?>> restoreSession();

  Future<Result<AuthSession>> refreshSession(SessionTokens tokens);

  Future<Result<void>> logout();
}

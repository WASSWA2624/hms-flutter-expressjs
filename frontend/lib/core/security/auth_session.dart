import 'package:flutter_template/core/permissions/app_permission.dart';
import 'package:flutter_template/core/security/session_tokens.dart';

final class AuthSession {
  AuthSession({
    required this.tokens,
    String? subject,
    Iterable<AppPermission> permissions = const <AppPermission>[],
  }) : subject = _normalizedSubject(subject),
       permissions = Set<AppPermission>.unmodifiable(permissions);

  final SessionTokens tokens;
  final String? subject;
  final Set<AppPermission> permissions;

  bool hasPermission(AppPermission permission) {
    return permissions.grants(permission);
  }

  bool hasAllPermissions(Iterable<AppPermission> requiredPermissions) {
    return permissions.grantsAll(requiredPermissions);
  }

  @override
  String toString() {
    return 'AuthSession('
        'subject: ${subject ?? 'none'}, '
        'tokens: $tokens, '
        'permissions: $permissions'
        ')';
  }

  static String? _normalizedSubject(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
  }
}

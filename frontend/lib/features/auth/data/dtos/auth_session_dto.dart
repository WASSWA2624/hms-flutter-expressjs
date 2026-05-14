import 'dart:convert';

import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

final class AuthSessionDto {
  const AuthSessionDto({
    required this.accessToken,
    this.refreshToken,
    this.subject,
    this.permissions = const <AppPermission>[],
  });

  factory AuthSessionDto.fromResponseData(Object? data) {
    if (data is! Map<String, Object?>) {
      throw const FormatException('Invalid auth session payload.');
    }

    return AuthSessionDto.fromJson(data);
  }

  factory AuthSessionDto.fromJson(Map<String, Object?> json) {
    final user = json['user'];
    return AuthSessionDto(
      accessToken: _requiredString(json, 'access_token'),
      refreshToken: _optionalString(json, 'refresh_token'),
      subject: user is Map<String, Object?>
          ? _userSubject(user)
          : _subjectFromToken(_requiredString(json, 'access_token')),
      permissions: user is Map<String, Object?>
          ? _permissionsFromUser(user)
          : _permissionsFromToken(_requiredString(json, 'access_token')),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final String? subject;
  final List<AppPermission> permissions;

  AuthSession toEntity() {
    return AuthSession(
      tokens: SessionTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: _expiresAtFromToken(accessToken),
      ),
      subject: subject,
      permissions: permissions,
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid auth session payload.');
    }

    return value.trim();
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }

  static String? _userSubject(Map<String, Object?> user) {
    for (final key in <String>['email', 'name', 'id']) {
      final value = user[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  static List<AppPermission> _permissionsFromUser(Map<String, Object?> user) {
    final permissions = <AppPermission>[];
    for (final key in <String>['permissions', 'permission_names']) {
      final values = user[key];
      if (values is Iterable<Object?>) {
        permissions.addAll(_permissionsFromValues(values));
      }
    }

    return List<AppPermission>.unmodifiable(permissions.toSet());
  }

  static List<AppPermission> _permissionsFromToken(String token) {
    final payload = _tokenPayload(token);
    final permissions = payload?['permissions'];
    if (permissions is! Iterable<Object?>) {
      return const <AppPermission>[];
    }

    return List<AppPermission>.unmodifiable(
      _permissionsFromValues(permissions).toSet(),
    );
  }

  static List<AppPermission> _permissionsFromValues(Iterable<Object?> values) {
    return values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map(AppPermission.new)
        .toList(growable: false);
  }

  static String? _subjectFromToken(String token) {
    final payload = _tokenPayload(token);
    for (final key in <String>['email', 'sub', 'userId']) {
      final value = payload?[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  static DateTime? _expiresAtFromToken(String token) {
    final payload = _tokenPayload(token);
    final exp = payload?['exp'];
    if (exp is! num) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  }

  static Map<String, Object?>? _tokenPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      return payload is Map<String, Object?> ? payload : null;
    } catch (_) {
      return null;
    }
  }
}

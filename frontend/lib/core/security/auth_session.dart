import 'dart:convert';

import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

final class AuthSession {
  AuthSession({
    required this.tokens,
    String? subject,
    this.user,
    Iterable<AppPermission> permissions = const <AppPermission>[],
    Iterable<AppModuleEntitlement> moduleEntitlements =
        const <AppModuleEntitlement>[],
  }) : subject =
           _normalizedSubject(subject) ??
           _normalizedSubject(user?.email) ??
           _normalizedSubject(user?.id),
       permissions = Set<AppPermission>.unmodifiable(permissions),
       moduleEntitlements = Map<String, AppModuleEntitlement>.unmodifiable({
         for (final entitlement in moduleEntitlements)
           entitlement.normalizedCode: entitlement,
       });

  factory AuthSession.fromTokens(SessionTokens tokens) {
    final Map<String, Object?>? payload = _tokenPayload(tokens.accessToken);
    final profile = payload == null ? null : AuthUserProfile.fromToken(payload);

    return AuthSession(
      tokens: tokens,
      subject:
          profile?.email ??
          _firstString(payload, const <String>['email', 'sub', 'userId']),
      user: profile,
      permissions: _permissionsFromPayload(payload),
      moduleEntitlements: _moduleEntitlementsFromPayload(payload),
    );
  }

  final SessionTokens tokens;
  final String? subject;
  final AuthUserProfile? user;
  final Set<AppPermission> permissions;
  final Map<String, AppModuleEntitlement> moduleEntitlements;

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
        'permissions: $permissions, '
        'moduleEntitlements: ${moduleEntitlements.keys}, '
        'hasUser: ${user != null}'
        ')';
  }

  static String? _normalizedSubject(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
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

  static String? _firstString(
    Map<String, Object?>? payload,
    Iterable<String> keys,
  ) {
    if (payload == null) {
      return null;
    }

    for (final key in keys) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  static List<AppPermission> _permissionsFromPayload(
    Map<String, Object?>? payload,
  ) {
    final permissions = payload?['permissions'];
    if (permissions is! Iterable<Object?>) {
      return const <AppPermission>[];
    }

    return permissions
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map(AppPermission.new)
        .toSet()
        .toList(growable: false);
  }

  static List<AppModuleEntitlement> _moduleEntitlementsFromPayload(
    Map<String, Object?>? payload,
  ) {
    if (payload == null) {
      return const <AppModuleEntitlement>[];
    }

    final Object? source =
        payload['module_entitlements'] ??
        payload['moduleEntitlements'] ??
        payload['modules'] ??
        payload['active_modules'] ??
        payload['activeModules'];
    if (source is! Iterable<Object?>) {
      return const <AppModuleEntitlement>[];
    }

    return source
        .map(AppModuleEntitlement.tryFromPayload)
        .whereType<AppModuleEntitlement>()
        .toSet()
        .toList(growable: false);
  }
}

final class AppModuleEntitlement {
  const AppModuleEntitlement({
    required this.code,
    this.isActive = true,
    this.licenseStatus,
  });

  static AppModuleEntitlement? tryFromPayload(Object? payload) {
    if (payload is String) {
      final code = payload.trim();
      if (code.isEmpty) {
        return null;
      }

      return AppModuleEntitlement(code: code);
    }

    if (payload is! Map<Object?, Object?>) {
      return null;
    }

    final code = _firstPresentString(payload, const <String>[
      'code',
      'name',
      'module',
      'module_code',
      'moduleCode',
      'module_id',
      'moduleId',
    ]);
    if (code == null) {
      return null;
    }

    return AppModuleEntitlement(
      code: code,
      isActive: _boolValue(
        payload['is_active'] ?? payload['isActive'] ?? payload['active'],
      ),
      licenseStatus: _stringValue(
        payload['license_status'] ??
            payload['licenseStatus'] ??
            payload['subscription_status'] ??
            payload['subscriptionStatus'],
      )?.toUpperCase(),
    );
  }

  final String code;
  final bool isActive;
  final String? licenseStatus;

  String get normalizedCode => normalizeModuleCode(code);

  bool get isAvailable {
    final status = licenseStatus;
    return isActive &&
        (status == null ||
            status == 'ACTIVE' ||
            status == 'TRIAL' ||
            status == 'HEALTHY');
  }

  @override
  bool operator ==(Object other) {
    return other is AppModuleEntitlement &&
        normalizedCode == other.normalizedCode &&
        isActive == other.isActive &&
        licenseStatus == other.licenseStatus;
  }

  @override
  int get hashCode => Object.hash(normalizedCode, isActive, licenseStatus);

  static String normalizeModuleCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  static String? _firstPresentString(
    Map<Object?, Object?> payload,
    Iterable<String> keys,
  ) {
    for (final key in keys) {
      final value = _stringValue(payload[key]);
      if (value != null) {
        return value;
      }
    }

    return null;
  }

  static String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    return switch (value?.toString().trim().toUpperCase()) {
      'FALSE' || '0' || 'NO' || 'INACTIVE' || 'DISABLED' => false,
      _ => true,
    };
  }
}

final class AuthUserProfile {
  const AuthUserProfile({
    this.id,
    this.displayId,
    this.email,
    this.phone,
    this.status,
    this.positionTitle,
    this.firstName,
    this.middleName,
    this.lastName,
    this.gender,
    this.tenantId,
    this.tenantName,
    this.facilityId,
    this.facilityName,
    this.facilityType,
    this.branchId,
    this.staffNumber,
    this.staffPosition,
    this.practitionerType,
    this.roles = const <String>[],
  });

  factory AuthUserProfile.fromToken(Map<String, Object?> payload) {
    final roles = _strings(payload['roles']);

    return AuthUserProfile(
      id: _string(payload['userId']) ?? _string(payload['sub']),
      email: _string(payload['email']),
      tenantId: _string(payload['tenant_id']) ?? _string(payload['tenantId']),
      facilityId:
          _string(payload['facility_id']) ?? _string(payload['facilityId']),
      branchId: _string(payload['branch_id']) ?? _string(payload['branchId']),
      roles: roles,
    );
  }

  final String? id;
  final String? displayId;
  final String? email;
  final String? phone;
  final String? status;
  final String? positionTitle;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? gender;
  final String? tenantId;
  final String? tenantName;
  final String? facilityId;
  final String? facilityName;
  final String? facilityType;
  final String? branchId;
  final String? staffNumber;
  final String? staffPosition;
  final String? practitionerType;
  final List<String> roles;

  String? get fullName {
    final parts = <String>[
      if (_hasText(firstName)) firstName!.trim(),
      if (_hasText(middleName)) middleName!.trim(),
      if (_hasText(lastName)) lastName!.trim(),
    ];

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' ');
  }

  String? get displayName {
    return fullName ??
        _string(email) ??
        _formattedToken(positionTitle) ??
        _string(displayId) ??
        _string(id);
  }

  String? get effectiveTitle {
    return _formattedToken(staffPosition) ?? _formattedToken(positionTitle);
  }

  String? get overallRole {
    if (roles.isEmpty) {
      return null;
    }

    return _formattedToken(roles.first);
  }

  String? get userType {
    final practitioner = _formattedToken(practitionerType);
    if (practitioner != null) {
      return practitioner;
    }

    final normalizedValues = <String>[
      ...roles,
      if (_hasText(positionTitle)) positionTitle!,
      if (_hasText(staffPosition)) staffPosition!,
    ].map((value) => value.toUpperCase()).join(' ');

    if (normalizedValues.contains('DOCTOR') ||
        normalizedValues.contains('PHYSICIAN')) {
      return 'Doctor';
    }
    if (normalizedValues.contains('NURSE')) {
      return 'Nurse';
    }
    if (normalizedValues.contains('ADMIN') ||
        normalizedValues.contains('OWNER')) {
      return 'Administrator';
    }
    if (normalizedValues.contains('PHARM')) {
      return 'Pharmacy';
    }
    if (normalizedValues.contains('LAB')) {
      return 'Laboratory';
    }

    return overallRole ?? effectiveTitle;
  }

  String get initials {
    final source = displayName ?? email ?? id ?? '';
    final words = source
        .replaceAll(RegExp(r'[@._-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.isEmpty) {
      return '?';
    }

    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }

    return <String>[
      words.first.substring(0, 1),
      words.last.substring(0, 1),
    ].join().toUpperCase();
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  static String? _string(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }

  static List<String> _strings(Object? value) {
    if (value is! Iterable<Object?>) {
      return const <String>[];
    }

    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String? _formattedToken(String? value) {
    final normalized = _string(value);
    if (normalized == null) {
      return null;
    }

    final words = normalized
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');

    return words.isEmpty ? null : words;
  }
}

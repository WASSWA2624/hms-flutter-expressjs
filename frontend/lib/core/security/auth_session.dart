import 'dart:convert';

import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';

final class AuthSession {
  AuthSession({
    required this.tokens,
    String? subject,
    this.user,
    Iterable<AppPermission> permissions = const <AppPermission>[],
    Iterable<AppModuleEntitlement> moduleEntitlements =
        const <AppModuleEntitlement>[],
    this.subscriptionSummary,
    this.platformAdminContact,
    this.isAuthorizationHydrated = false,
    this.isModuleCatalogHydrated = false,
    Iterable<OrgAdminContact> tenantAdminContacts = const <OrgAdminContact>[],
    Iterable<OrgAdminContact> facilityAdminContacts = const <OrgAdminContact>[],
  }) : subject =
           _normalizedSubject(subject) ??
           _normalizedSubject(user?.email) ??
           _normalizedSubject(user?.id),
       permissions = Set<AppPermission>.unmodifiable(permissions),
       moduleEntitlements = Map<String, AppModuleEntitlement>.unmodifiable({
         for (final entitlement in moduleEntitlements)
           entitlement.normalizedCode: entitlement,
       }),
       tenantAdminContacts = List<OrgAdminContact>.unmodifiable(
         tenantAdminContacts,
       ),
       facilityAdminContacts = List<OrgAdminContact>.unmodifiable(
         facilityAdminContacts,
       );

  factory AuthSession.fromTokens(SessionTokens tokens) {
    final Map<String, Object?>? payload = _tokenPayload(tokens.accessToken);
    final profile = payload == null ? null : AuthUserProfile.fromToken(payload);
    final List<AppModuleEntitlement> entitlements =
        _moduleEntitlementsFromPayload(payload);

    return AuthSession(
      tokens: tokens,
      subject:
          profile?.email ??
          _firstString(payload, const <String>['email', 'sub', 'userId']),
      user: profile,
      permissions: _permissionsFromPayload(payload),
      moduleEntitlements: entitlements,
      isAuthorizationHydrated: payload?.containsKey('permissions') == true,
      // JWTs rarely embed plan modules; /auth/me owns the catalog.
      isModuleCatalogHydrated: entitlements.isNotEmpty,
    );
  }

  final SessionTokens tokens;
  final String? subject;
  final AuthUserProfile? user;
  final Set<AppPermission> permissions;
  final Map<String, AppModuleEntitlement> moduleEntitlements;
  final TenantSubscriptionSummary? subscriptionSummary;
  final PlatformAdminContact? platformAdminContact;
  final bool isAuthorizationHydrated;

  /// True after `/auth/me` (or an equivalent profile enrich) has applied plan
  /// modules — even when the resulting catalog is empty.
  final bool isModuleCatalogHydrated;
  final List<OrgAdminContact> tenantAdminContacts;
  final List<OrgAdminContact> facilityAdminContacts;

  /// Tenant JWT restore before `/auth/me`: hold routing instead of forbidden.
  bool get needsMeEnrichment {
    final String? tenantId = user?.tenantId?.trim();
    if (tenantId == null || tenantId.isEmpty) {
      return false;
    }
    if (isModuleCatalogHydrated || moduleEntitlements.isNotEmpty) {
      return false;
    }
    return true;
  }

  bool hasPermission(AppPermission permission) {
    return permissions.grants(permission);
  }

  bool hasAllPermissions(Iterable<AppPermission> requiredPermissions) {
    return permissions.grantsAll(requiredPermissions);
  }

  AuthSession copyWith({
    SessionTokens? tokens,
    String? subject,
    AuthUserProfile? user,
    Iterable<AppPermission>? permissions,
    Iterable<AppModuleEntitlement>? moduleEntitlements,
    TenantSubscriptionSummary? subscriptionSummary,
    PlatformAdminContact? platformAdminContact,
    bool? isAuthorizationHydrated,
    bool? isModuleCatalogHydrated,
    Iterable<OrgAdminContact>? tenantAdminContacts,
    Iterable<OrgAdminContact>? facilityAdminContacts,
  }) {
    return AuthSession(
      tokens: tokens ?? this.tokens,
      subject: subject ?? this.subject,
      user: user ?? this.user,
      permissions: permissions ?? this.permissions,
      moduleEntitlements: moduleEntitlements ?? this.moduleEntitlements.values,
      subscriptionSummary: subscriptionSummary ?? this.subscriptionSummary,
      platformAdminContact: platformAdminContact ?? this.platformAdminContact,
      isAuthorizationHydrated:
          isAuthorizationHydrated ?? this.isAuthorizationHydrated,
      isModuleCatalogHydrated:
          isModuleCatalogHydrated ?? this.isModuleCatalogHydrated,
      tenantAdminContacts: tenantAdminContacts ?? this.tenantAdminContacts,
      facilityAdminContacts:
          facilityAdminContacts ?? this.facilityAdminContacts,
    );
  }

  AuthSession enrichFromUserProfile(AuthUserProfile profile) {
    return copyWith(
      subject: profile.email ?? profile.id ?? subject,
      user: profile,
    );
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
    this.planTierCode,
    this.allowedPermissions = const <String>[],
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
      'slug',
      'name',
      'module',
      'module_code',
      'moduleCode',
      'module_id',
      'moduleId',
      'module_slug',
      'moduleSlug',
      'module_label',
      'moduleLabel',
    ]);
    if (code == null) {
      return null;
    }

    final bool entitlementDenied = _boolValue(
      payload['entitlement_denied'] ?? payload['entitlementDenied'],
      defaultValue: false,
    );

    return AppModuleEntitlement(
      code: code,
      isActive:
          _boolValue(
            payload['is_active'] ?? payload['isActive'] ?? payload['active'],
          ) &&
          !entitlementDenied,
      licenseStatus: _stringValue(
        payload['license_status'] ??
            payload['licenseStatus'] ??
            payload['subscription_status'] ??
            payload['subscriptionStatus'] ??
            payload['status'] ??
            payload['evaluated_plan_fit_status'] ??
            payload['evaluatedPlanFitStatus'],
      )?.toUpperCase(),
      planTierCode: _stringValue(
        payload['plan_tier_code'] ?? payload['planTierCode'],
      )?.toUpperCase(),
      allowedPermissions: _stringList(
        payload['allowed_permissions'] ?? payload['allowedPermissions'],
      ),
    );
  }

  final String code;
  final bool isActive;
  final String? licenseStatus;
  final String? planTierCode;
  final List<String> allowedPermissions;

  String get normalizedCode => normalizeModuleCode(code);

  bool get isAvailable {
    final status = licenseStatus;
    return isActive &&
        (status == null ||
            status == 'ACTIVE' ||
            status == 'TRIAL' ||
            status == 'HEALTHY' ||
            status == 'FIT');
  }

  @override
  bool operator ==(Object other) {
    return other is AppModuleEntitlement &&
        normalizedCode == other.normalizedCode &&
        isActive == other.isActive &&
        licenseStatus == other.licenseStatus &&
        planTierCode == other.planTierCode;
  }

  @override
  int get hashCode =>
      Object.hash(normalizedCode, isActive, licenseStatus, planTierCode);

  static String normalizeModuleCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  static String resolveModuleCode(String value) {
    final normalized = normalizeModuleCode(value);
    return switch (normalized) {
      'PHARMACY' => 'PHARMACY_DISPENSING',
      'REPORTS' => 'REPORTING_ANALYTICS',
      'LAB' => 'LAB_WORKFLOWS',
      'RADIOLOGY' => 'RADIOLOGY_WORKFLOWS',
      'PATIENTS' => 'PATIENT_REGISTRY',
      'SCHEDULING' => 'SCHEDULING_QUEUE',
      'CLINICAL' => 'ENCOUNTERS_VITALS',
      'NURSING' => 'INPATIENT_BED_MANAGEMENT',
      'ROOMS_BEDS' => 'INPATIENT_BED_MANAGEMENT',
      'BILLING' => 'BILLING_PAYMENTS',
      'BILLING_INSURANCE' => 'BILLING_PAYMENTS',
      'INSURANCE' => 'INSURANCE_CLAIMS',
      'CLAIMS' => 'INSURANCE_CLAIMS',
      'INVENTORY' => 'INVENTORY_PROCUREMENT_LITE',
      'INVENTORY_PROCUREMENT' => 'INVENTORY_PROCUREMENT_LITE',
      'HR' => 'HR_ROSTERS',
      'OPERATIONS' => 'FACILITIES_MAINTENANCE',
      'BIOMEDICAL' => 'BIOMEDICAL_ENGINEERING_SUITE',
      'COMMUNICATIONS' => 'NOTIFICATIONS_COMMUNICATIONS',
      'INTEGRATIONS' => 'INTEGRATIONS_CORE',
      'MORTUARY' => 'MORTUARY',
      'THEATER' => 'THEATRE_ANESTHESIA',
      'PHYSIOTHERAPY' => 'PHYSIOTHERAPY',
      'EMERGENCY' => 'SCHEDULING_QUEUE',
      'CLINICAL_CARE' => 'ENCOUNTERS_VITALS',
      'HOUSEKEEPING' => 'FACILITIES_MAINTENANCE',
      _ => normalized,
    };
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

  static bool _boolValue(Object? value, {bool defaultValue = true}) {
    if (value == null) {
      return defaultValue;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    return switch (value.toString().trim().toUpperCase()) {
      'FALSE' || '0' || 'NO' || 'INACTIVE' || 'DISABLED' => false,
      _ => true,
    };
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }
    return value
        .map((Object? entry) => _stringValue(entry))
        .whereType<String>()
        .toList(growable: false);
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

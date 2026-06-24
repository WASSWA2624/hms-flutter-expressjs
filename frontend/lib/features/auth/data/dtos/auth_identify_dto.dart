import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';

final class AuthIdentifyDto {
  const AuthIdentifyDto({this.tenants = const <AuthTenantOption>[]});

  factory AuthIdentifyDto.fromResponseData(Object? data) {
    if (data is! Map<String, Object?>) {
      return const AuthIdentifyDto();
    }

    final users = data['users'];
    if (users is! Iterable<Object?>) {
      return const AuthIdentifyDto();
    }

    final tenants = users
        .whereType<Map<String, Object?>>()
        .map(_tenantFromJson)
        .whereType<AuthTenantOption>()
        .toList(growable: false);

    return AuthIdentifyDto(tenants: tenants);
  }

  final List<AuthTenantOption> tenants;

  AuthIdentifyResult toEntity() {
    return AuthIdentifyResult(tenants: tenants);
  }

  static AuthTenantOption? _tenantFromJson(Map<String, Object?> json) {
    final tenantId = _string(json['tenant_id']) ?? _string(json['tenantId']);
    if (tenantId == null) {
      return null;
    }

    return AuthTenantOption(
      tenantId: tenantId,
      tenantName: _string(json['tenant_name']) ?? _string(json['tenantName']) ?? '',
      tenantSlug: _string(json['tenant_slug']) ?? _string(json['tenantSlug']),
      status: _string(json['status']) ?? 'INACTIVE',
    );
  }

  static String? _string(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }
}

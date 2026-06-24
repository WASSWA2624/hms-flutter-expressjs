final class AuthTenantOption {
  const AuthTenantOption({
    required this.tenantId,
    required this.tenantName,
    this.tenantSlug,
    this.status = 'INACTIVE',
  });

  final String tenantId;
  final String tenantName;
  final String? tenantSlug;
  final String status;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}

final class AuthIdentifyResult {
  const AuthIdentifyResult({this.tenants = const <AuthTenantOption>[]});

  final List<AuthTenantOption> tenants;

  bool get hasTenants => tenants.isNotEmpty;
}

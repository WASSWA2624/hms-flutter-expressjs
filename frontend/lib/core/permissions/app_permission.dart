final class AppPermission {
  const AppPermission(this.value);

  final String value;

  @override
  bool operator ==(Object other) {
    return other is AppPermission && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class AppPermissionGrant {
  AppPermissionGrant(Iterable<AppPermission> permissions)
    : permissions = Set<AppPermission>.unmodifiable(permissions);

  const AppPermissionGrant.empty() : permissions = const <AppPermission>{};

  final Set<AppPermission> permissions;

  bool grants(AppPermission permission) {
    return permissions.contains(permission);
  }

  bool grantsAll(Iterable<AppPermission> requiredPermissions) {
    return requiredPermissions.every(grants);
  }

  bool grantsAny(Iterable<AppPermission> requiredPermissions) {
    return requiredPermissions.any(grants);
  }

  AppPermissionGrant merge(AppPermissionGrant other) {
    return AppPermissionGrant(<AppPermission>{
      ...permissions,
      ...other.permissions,
    });
  }

  @override
  bool operator ==(Object other) {
    return other is AppPermissionGrant &&
        permissions.length == other.permissions.length &&
        permissions.containsAll(other.permissions);
  }

  @override
  int get hashCode => Object.hashAllUnordered(permissions);
}

extension AppPermissionIterableX on Iterable<AppPermission> {
  bool grants(AppPermission permission) {
    return contains(permission);
  }

  bool grantsAll(Iterable<AppPermission> requiredPermissions) {
    return requiredPermissions.every(grants);
  }

  bool grantsAny(Iterable<AppPermission> requiredPermissions) {
    return requiredPermissions.any(grants);
  }
}

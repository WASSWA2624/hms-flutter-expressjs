import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';

typedef AccessGateDeniedBuilder =
    Widget Function(BuildContext context, AppAccessPolicy policy);
typedef AccessGateChildBuilder =
    Widget Function(BuildContext context, bool isAllowed);

final class AccessRequirement {
  const AccessRequirement({
    this.allPermissions = const <AppPermission>[],
    this.anyPermissions = const <AppPermission>[],
    this.anyRoles = const <AppRole>[],
    this.activeModules = const <String>[],
    this.requiresTenantContext = false,
    this.requiresFacilityContext = false,
  });

  final Iterable<AppPermission> allPermissions;
  final Iterable<AppPermission> anyPermissions;
  final Iterable<AppRole> anyRoles;
  final Iterable<String> activeModules;
  final bool requiresTenantContext;
  final bool requiresFacilityContext;

  bool isAllowed(AppAccessPolicy policy) {
    if (!policy.hasAnyRole(anyRoles)) {
      return false;
    }
    if (!policy.grantsAll(allPermissions)) {
      return false;
    }
    if (anyPermissions.isNotEmpty && !policy.grantsAny(anyPermissions)) {
      return false;
    }
    if (requiresTenantContext &&
        !policy.hasTenantContext &&
        !policy.isElevated) {
      return false;
    }
    if (requiresFacilityContext &&
        !policy.hasFacilityContext &&
        !policy.isElevated) {
      return false;
    }

    return policy.hasAllActiveModules(activeModules);
  }
}

class AppAccessGate extends ConsumerWidget {
  const AppAccessGate({
    required this.requirement,
    required this.child,
    this.deniedBuilder,
    super.key,
  });

  final AccessRequirement requirement;
  final Widget child;
  final AccessGateDeniedBuilder? deniedBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(appAccessPolicyProvider);
    if (requirement.isAllowed(policy)) {
      return child;
    }

    return deniedBuilder?.call(context, policy) ?? const SizedBox.shrink();
  }
}

class AppAccessActionGate extends ConsumerWidget {
  const AppAccessActionGate({
    required this.requirement,
    required this.builder,
    super.key,
  });

  final AccessRequirement requirement;
  final AccessGateChildBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(appAccessPolicyProvider);
    return builder(context, requirement.isAllowed(policy));
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';

typedef AccessGateDeniedBuilder =
    Widget Function(BuildContext context, AppAccessPolicy policy);
typedef AccessGateChildBuilder =
    Widget Function(BuildContext context, bool isAllowed);

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

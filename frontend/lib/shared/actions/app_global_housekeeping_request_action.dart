import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/shared/actions/app_global_housekeeping_request_dialog.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

const _housekeepingRequestRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.operationsWrite,
    AppPermissions.operationsRead,
  ],
  activeModules: <String>['housekeeping-maintenance'],
);

/// Global toolbar action to request housekeeping/maintenance from any workspace.
class AppGlobalHousekeepingRequestAction extends ConsumerWidget {
  const AppGlobalHousekeepingRequestAction({
    required this.label,
    this.onCompleted,
    super.key,
  });

  final String label;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppAccessActionGate(
      requirement: _housekeepingRequestRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppButton(iconOnly: true, 
          leadingIcon: Icons.cleaning_services_outlined,
          label: label,

          semanticLabel: label,
          tooltip: label,
          enabled: isAllowed,
          onPressed: isAllowed
              ? () {
                  showAppGlobalHousekeepingRequestDialog(
                    context: context,
                    ref: ref,
                    onCompleted: onCompleted,
                  );
                }
              : null,
        );
      },
    );
  }
}

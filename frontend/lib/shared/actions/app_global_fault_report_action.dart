import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/shared/actions/app_global_fault_report_dialog.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';

const _faultReportRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.biomedWrite,
    AppPermissions.operationsWrite,
  ],
  activeModules: <String>['biomedical-engineering-suite'],
);

/// Global toolbar action to report equipment faults from any workspace.
class AppGlobalFaultReportAction extends ConsumerWidget {
  const AppGlobalFaultReportAction({
    required this.label,
    this.onCompleted,
    super.key,
  });

  final String label;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppAccessActionGate(
      requirement: _faultReportRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppIconButton(
          icon: Icons.report_problem_outlined,
          semanticLabel: label,
          tooltip: label,
          enabled: isAllowed,
          onPressed: isAllowed
              ? () {
                  showAppGlobalFaultReportDialog(
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

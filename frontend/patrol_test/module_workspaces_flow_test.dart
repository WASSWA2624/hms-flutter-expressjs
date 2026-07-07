import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  for (final PatrolWorkspaceTarget target in patrolWorkspaceTargets) {
    patrolTestWithDiagnostics(
      'workspace shell loads for ${target.route.name}',
      ($) async {
        await pumpPatrolAuthenticatedApp(
          $,
          initialLocation: target.route.path,
        );

        await expectAnyVisible($, target.labels);
      },
      targetFile: 'patrol_test/module_workspaces_flow_test.dart',
      platform: 'chrome',
    );
  }
}

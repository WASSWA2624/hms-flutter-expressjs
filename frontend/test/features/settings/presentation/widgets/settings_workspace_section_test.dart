import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/settings/data/repositories/settings_workspace_repository_impl.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';
import 'package:hosspi_hms/features/settings/domain/repositories/settings_workspace_repository.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_workspace_section.dart';

import '../../../../shared/components/component_test_app.dart';

void main() {
  testWidgets('renders backend-backed settings workspace content', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      ProviderScope(
        overrides: [
          settingsWorkspaceRepositoryProvider.overrideWithValue(
            _FakeSettingsWorkspaceRepository(
              workspace: _workspace(SettingsWorkspaceStatus.ready),
              referenceData: _referenceData(),
            ),
          ),
        ],
        child: const SettingsWorkspaceSection(),
      ),
      size: const Size(1280, 1200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administrative setup workspace'), findsOneWidget);
    expect(find.text('Acme Health'), findsWidgets);
    expect(find.text('Central Hospital'), findsWidgets);
    expect(find.text('Organization'), findsWidgets);
    expect(find.text('Tenant'), findsWidgets);
    expect(find.text('Open'), findsWidgets);
  });

  testWidgets('renders tenant selector when backend requires tenant context', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      ProviderScope(
        overrides: [
          settingsWorkspaceRepositoryProvider.overrideWithValue(
            _FakeSettingsWorkspaceRepository(
              workspace: _workspace(
                SettingsWorkspaceStatus.tenantContextRequired,
              ),
              referenceData: _referenceData(),
            ),
          ),
        ],
        child: const SettingsWorkspaceSection(),
      ),
      size: const Size(900, 700),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tenant context required'), findsOneWidget);
    expect(find.text('Tenant'), findsWidgets);
    expect(find.text('Tenant context'), findsWidgets);
  });
}

final class _FakeSettingsWorkspaceRepository
    implements SettingsWorkspaceRepository {
  const _FakeSettingsWorkspaceRepository({
    required this.workspace,
    required this.referenceData,
  });

  final SettingsWorkspace workspace;
  final SettingsReferenceData referenceData;

  @override
  Future<Result<SettingsWorkspace>> getWorkspace(
    SettingsWorkspaceQuery query,
  ) async {
    return Result<SettingsWorkspace>.success(workspace);
  }

  @override
  Future<Result<SettingsReferenceData>> getReferenceData(
    SettingsWorkspaceQuery query,
  ) async {
    return Result<SettingsReferenceData>.success(referenceData);
  }
}

SettingsReferenceData _referenceData() {
  return const SettingsReferenceData(
    tenants: <SettingsReferenceOption>[
      SettingsReferenceOption(id: 'TEN-1', label: 'Acme Health'),
    ],
    facilities: <SettingsReferenceOption>[
      SettingsReferenceOption(id: 'FAC-1', label: 'Central Hospital'),
    ],
  );
}

SettingsWorkspace _workspace(SettingsWorkspaceStatus status) {
  final bool ready = status == SettingsWorkspaceStatus.ready;
  return SettingsWorkspace(
    status: status,
    generatedAt: DateTime.utc(2026, 5, 22, 9),
    context: SettingsWorkspaceContext(
      state: status,
      tenantName: ready ? 'Acme Health' : null,
      facilityName: ready ? 'Central Hospital' : null,
      roleKeys: const <String>['TENANT_ADMIN'],
    ),
    summaryCards: ready
        ? const <SettingsSummaryCard>[
            SettingsSummaryCard(
              id: 'organization',
              labelKey: 'settings.workspace.summary.organization',
              totalModules: 1,
              configuredModules: 1,
              attentionModules: 0,
              totalRecords: 1,
              state: 'configured',
            ),
          ]
        : const <SettingsSummaryCard>[],
    checklist: ready
        ? const SettingsChecklist(
            completedCount: 1,
            totalCount: 1,
            items: <SettingsChecklistItem>[
              SettingsChecklistItem(
                id: 'tenant',
                labelKey: 'settings.workspace.checklist.tenant',
                completed: true,
                priority: 1,
                route: '/settings/tenants',
              ),
            ],
          )
        : const SettingsChecklist(
            completedCount: 0,
            totalCount: 0,
            items: <SettingsChecklistItem>[],
          ),
    quickActions: ready
        ? const <SettingsQuickAction>[
            SettingsQuickAction(
              id: 'tenant:create',
              moduleId: 'tenant',
              moduleLabelKey: 'settings.tabs.tenant',
              labelKey: 'settings.workspace.quickActions.createModule',
              canExecute: true,
              route: '/settings/tenants/create',
            ),
          ]
        : const <SettingsQuickAction>[],
    moduleGroups: ready
        ? const <SettingsModuleGroup>[
            SettingsModuleGroup(
              id: 'organization',
              labelKey: 'settings.sidebar.groups.organization',
              modules: <SettingsModuleItem>[
                SettingsModuleItem(
                  moduleId: 'tenant',
                  labelKey: 'settings.tabs.tenant',
                  groupId: 'organization',
                  count: 1,
                  state: SettingsModuleState.configured,
                  canRead: true,
                  canWrite: true,
                  canCreate: true,
                  dependencies: <SettingsModuleDependency>[],
                  route: '/settings/tenants',
                  createRoute: '/settings/tenants/create',
                ),
              ],
            ),
          ]
        : const <SettingsModuleGroup>[],
    referenceData: _referenceData(),
    stats: const SettingsWorkspaceStats(
      totalModules: 1,
      configuredModules: 1,
      attentionModules: 0,
      totalRecords: 1,
    ),
    permissions: const SettingsWorkspacePermissions(canWrite: true),
  );
}

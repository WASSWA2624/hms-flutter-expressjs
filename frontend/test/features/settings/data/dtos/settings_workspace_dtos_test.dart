import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/settings/data/dtos/settings_workspace_dtos.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';

void main() {
  test(
    'parses settings workspace payload without exposing backend label keys',
    () {
      final dto = SettingsWorkspaceDto.fromResponse(<String, Object?>{
        'data': _workspacePayload(),
      });

      final workspace = dto.workspace;

      expect(workspace.status, SettingsWorkspaceStatus.ready);
      expect(workspace.context.tenantName, 'Acme Health');
      expect(workspace.summaryCards.single.totalModules, 3);
      expect(
        workspace.checklist.items.single.createRoute,
        '/settings/tenants/create',
      );
      expect(workspace.quickActions.single.moduleId, 'tenant');
      expect(
        workspace.moduleGroups.single.modules.single.state,
        SettingsModuleState.configured,
      );
      expect(workspace.referenceData.tenants.single.label, 'Acme Health');
      expect(workspace.permissions.canWrite, isTrue);
    },
  );

  test('parses tenant-context-required reference data', () {
    final dto = SettingsReferenceDataDto.fromResponse(<String, Object?>{
      'data': <String, Object?>{
        'state': 'tenant_context_required',
        'tenants': <Map<String, Object?>>[
          <String, Object?>{'id': 'TEN-1', 'label': 'Acme Health'},
        ],
      },
    });

    expect(
      dto.referenceData.state,
      SettingsWorkspaceStatus.tenantContextRequired,
    );
    expect(dto.referenceData.tenants.single.id, 'TEN-1');
  });
}

Map<String, Object?> _workspacePayload() {
  return <String, Object?>{
    'state': 'ready',
    'generated_at': '2026-05-22T09:00:00.000Z',
    'context': <String, Object?>{
      'state': 'ready',
      'tenant_id': 'TEN-1',
      'tenant_name': 'Acme Health',
      'facility_id': 'FAC-1',
      'facility_name': 'Central Hospital',
      'facility_type': 'HOSPITAL',
      'role_keys': <String>['TENANT_ADMIN'],
    },
    'summary_cards': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'organization',
        'label_key': 'settings.workspace.summary.organization',
        'total_modules': 3,
        'configured_modules': 2,
        'attention_modules': 1,
        'total_records': 8,
        'state': 'attention',
      },
    ],
    'checklist': <String, Object?>{
      'completed_count': 1,
      'total_count': 2,
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'tenant',
          'label_key': 'settings.workspace.checklist.tenant',
          'completed': true,
          'priority': 1,
          'route': '/settings/tenants',
          'create_route': '/settings/tenants/create',
        },
      ],
    },
    'quick_actions': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'tenant:create',
        'module_id': 'tenant',
        'module_label_key': 'settings.tabs.tenant',
        'label_key': 'settings.workspace.quickActions.createModule',
        'can_execute': true,
        'icon': 'business-outline',
        'route': '/settings/tenants/create',
      },
    ],
    'module_groups': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'organization',
        'label_key': 'settings.sidebar.groups.organization',
        'modules': <Map<String, Object?>>[
          <String, Object?>{
            'module_id': 'tenant',
            'label_key': 'settings.tabs.tenant',
            'group_id': 'organization',
            'count': 1,
            'state': 'configured',
            'can_read': true,
            'can_write': true,
            'can_create': true,
            'route': '/settings/tenants',
            'create_route': '/settings/tenants/create',
          },
        ],
      },
    ],
    'tenants': <Map<String, Object?>>[
      <String, Object?>{'id': 'TEN-1', 'label': 'Acme Health'},
    ],
    'facilities': <Map<String, Object?>>[
      <String, Object?>{'id': 'FAC-1', 'label': 'Central Hospital'},
    ],
    'stats': <String, Object?>{
      'total_modules': 1,
      'configured_modules': 1,
      'attention_modules': 0,
      'total_records': 8,
    },
    'permissions': <String, Object?>{'can_write': true},
  };
}

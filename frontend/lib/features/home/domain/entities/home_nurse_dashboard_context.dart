import 'dart:collection';

import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

/// Nursing attachment inferred from HR assignment or staff profile signals.
enum NurseDepartmentKind {
  general,
  opd,
  theatre,
  radiology,
  icu,
  ward,
}

const Map<String, NurseDepartmentKind> _nurseContextByValue =
    <String, NurseDepartmentKind>{
      'general': NurseDepartmentKind.general,
      'opd': NurseDepartmentKind.opd,
      'theatre': NurseDepartmentKind.theatre,
      'theater': NurseDepartmentKind.theatre,
      'radiology': NurseDepartmentKind.radiology,
      'icu': NurseDepartmentKind.icu,
      'ward': NurseDepartmentKind.ward,
    };

NurseDepartmentKind nurseDepartmentKindFromValue(String? value) {
  final String normalized = (value ?? '').trim().toLowerCase();
  return _nurseContextByValue[normalized] ?? NurseDepartmentKind.general;
}

NurseDepartmentKind inferNurseDepartmentKind({
  String? nurseContextValue,
  String? departmentName,
  String? staffPosition,
  String? practitionerType,
}) {
  if (nurseContextValue != null && nurseContextValue.trim().isNotEmpty) {
    final NurseDepartmentKind fromApi = nurseDepartmentKindFromValue(
      nurseContextValue,
    );
    if (fromApi != NurseDepartmentKind.general ||
        nurseContextValue.trim().toLowerCase() == 'general') {
      return fromApi;
    }
  }

  final String combined = <String?>[
    departmentName,
    staffPosition,
    practitionerType,
  ].whereType<String>().join(' ').toLowerCase();

  if (_matchesAny(combined, <String>['theatre', 'theater', 'surgery', 'surgical'])) {
    return NurseDepartmentKind.theatre;
  }
  if (_matchesAny(combined, <String>['radiology', 'imaging', 'x-ray', 'xray'])) {
    return NurseDepartmentKind.radiology;
  }
  if (_matchesAny(combined, <String>['opd', 'outpatient', 'out-patient', 'clinic'])) {
    return NurseDepartmentKind.opd;
  }
  if (_matchesAny(combined, <String>['icu', 'intensive care', 'critical care'])) {
    return NurseDepartmentKind.icu;
  }
  if (_matchesAny(combined, <String>['ward', 'inpatient', 'ipd'])) {
    return NurseDepartmentKind.ward;
  }

  return NurseDepartmentKind.general;
}

bool _matchesAny(String value, List<String> needles) {
  return needles.any(value.contains);
}

const List<String> _nurseCoreMetricIds = <String>[
  'inpatient_flow',
  'med_admin_today',
  'transfer_queue',
  'critical_labs',
  'discharge_pressure',
];

const Map<NurseDepartmentKind, List<String>> _nurseMetricPriorityByKind =
    <NurseDepartmentKind, List<String>>{
      NurseDepartmentKind.general: <String>[
        'inpatient_flow',
        'med_admin_today',
        'transfer_queue',
        'critical_labs',
        'discharge_pressure',
        'opd_notifications_attention',
        'appointments_today',
        'emergency_cases_today',
      ],
      NurseDepartmentKind.opd: <String>[
        'appointments_today',
        'opd_notifications_attention',
        'med_admin_today',
        'inpatient_flow',
        'critical_labs',
        'emergency_cases_today',
      ],
      NurseDepartmentKind.theatre: <String>[
        'theatre_cases_today',
        'inpatient_flow',
        'med_admin_today',
        'transfer_queue',
        'critical_labs',
        'discharge_pressure',
      ],
      NurseDepartmentKind.radiology: <String>[
        'radiology_pending',
        'critical_labs',
        'inpatient_flow',
        'med_admin_today',
        'appointments_today',
      ],
      NurseDepartmentKind.icu: <String>[
        'inpatient_flow',
        'med_admin_today',
        'critical_labs',
        'transfer_queue',
        'emergency_cases_today',
      ],
      NurseDepartmentKind.ward: <String>[
        'inpatient_flow',
        'med_admin_today',
        'transfer_queue',
        'discharge_pressure',
        'critical_labs',
        'opd_notifications_attention',
      ],
    };

const List<String> _nurseCoreQuickActionIds = <String>[
  'record_vitals',
  'mark_med_administered',
  'create_handover',
  'write_clinical_note',
  'route_patient',
  'check_in_patient',
];

const Map<NurseDepartmentKind, List<String>> _nurseQuickActionPriorityByKind =
    <NurseDepartmentKind, List<String>>{
      NurseDepartmentKind.general: _nurseCoreQuickActionIds,
      NurseDepartmentKind.opd: <String>[
        'route_patient',
        'check_in_patient',
        'record_vitals',
        'mark_med_administered',
        'write_clinical_note',
        'create_handover',
      ],
      NurseDepartmentKind.theatre: <String>[
        'record_vitals',
        'mark_med_administered',
        'create_handover',
        'write_clinical_note',
        'route_patient',
      ],
      NurseDepartmentKind.radiology: <String>[
        'record_vitals',
        'write_clinical_note',
        'route_patient',
        'mark_med_administered',
        'create_handover',
      ],
      NurseDepartmentKind.icu: <String>[
        'record_vitals',
        'mark_med_administered',
        'create_handover',
        'write_clinical_note',
        'route_patient',
      ],
      NurseDepartmentKind.ward: <String>[
        'record_vitals',
        'mark_med_administered',
        'create_handover',
        'write_clinical_note',
        'route_patient',
        'check_in_patient',
      ],
    };

const List<String> _nurseCoreShortcutIds = <String>[
  'nursing',
  'ipd',
  'lab',
  'opd',
  'emergency',
  'radiology',
  'theater',
  'icu',
  'clinical',
];

const Map<NurseDepartmentKind, List<String>> _nurseShortcutPriorityByKind =
    <NurseDepartmentKind, List<String>>{
      NurseDepartmentKind.general: _nurseCoreShortcutIds,
      NurseDepartmentKind.opd: <String>[
        'opd',
        'nursing',
        'emergency',
        'clinical',
        'patients',
        'lab',
      ],
      NurseDepartmentKind.theatre: <String>[
        'theater',
        'nursing',
        'ipd',
        'clinical',
        'emergency',
        'lab',
      ],
      NurseDepartmentKind.radiology: <String>[
        'radiology',
        'nursing',
        'lab',
        'clinical',
        'opd',
        'ipd',
      ],
      NurseDepartmentKind.icu: <String>[
        'icu',
        'nursing',
        'ipd',
        'lab',
        'clinical',
        'emergency',
      ],
      NurseDepartmentKind.ward: <String>[
        'nursing',
        'ipd',
        'rooms_beds',
        'lab',
        'emergency',
        'clinical',
      ],
    };

const Map<String, List<String>> _nurseMetricRequiredModules =
    <String, List<String>>{
      'opd_notifications_attention': <String>['scheduling'],
      'appointments_today': <String>['scheduling'],
      'emergency_cases_today': <String>['emergency'],
      'theatre_cases_today': <String>['theatre'],
      'radiology_pending': <String>['radiology'],
    };

/// Reorders nurse dashboard templates for the nurse's department attachment.
HomeDashboardProfile tailorNurseDashboardProfile({
  required HomeDashboardProfile base,
  required NurseDepartmentKind departmentKind,
  required AppAccessPolicy policy,
  AuthUserProfile? user,
}) {
  if (base.role != AppRole.nurse) {
    return base;
  }

  final NurseDepartmentKind kind = departmentKind == NurseDepartmentKind.general
      ? inferNurseDepartmentKind(
          departmentName: user?.staffPosition,
          staffPosition: user?.positionTitle,
          practitionerType: user?.practitionerType,
        )
      : departmentKind;

  final Map<String, HomeStatusCardTemplate> templatesById =
      <String, HomeStatusCardTemplate>{
        for (final HomeStatusCardTemplate template in base.statusCards)
          template.id: template,
      };

  final List<String> metricOrder =
      _nurseMetricPriorityByKind[kind] ?? _nurseCoreMetricIds;
  final List<HomeStatusCardTemplate> statusCards = metricOrder
      .map((String id) => templatesById[id])
      .whereType<HomeStatusCardTemplate>()
      .where(
        (HomeStatusCardTemplate template) =>
            _nurseMetricAllowed(template.id, policy),
      )
      .toList(growable: false);

  final List<String> quickActionIds = _orderedUnique(
    _nurseQuickActionPriorityByKind[kind] ?? _nurseCoreQuickActionIds,
    fallback: base.quickActionIds,
  );
  final List<String> shortcutIds = _orderedUnique(
    _nurseShortcutPriorityByKind[kind] ?? _nurseCoreShortcutIds,
    fallback: base.shortcutIds,
  );

  return HomeDashboardProfile(
    id: base.id,
    role: base.role,
    roleLabel: base.roleLabel,
    homeTitle: _nurseHomeTitle(kind),
    emptyMessage: base.emptyMessage,
    statusCards: statusCards,
    quickActionIds: quickActionIds,
    shortcutIds: shortcutIds,
    emptyActionIds: base.emptyActionIds,
    metricRouteTargets: base.metricRouteTargets,
    metricActionTargets: base.metricActionTargets,
    toolbarActionIds: base.toolbarActionIds,
    maxStatusCards: base.maxStatusCards,
    showEmptyWorkspaceLink: base.showEmptyWorkspaceLink,
    suppressHomeQuickActions: base.suppressHomeQuickActions,
    suppressHomeShortcuts: base.suppressHomeShortcuts,
  );
}

HomeDashboardProfile tailorNurseDashboardProfileIfNeeded({
  required HomeDashboardProfile profile,
  required AppAccessPolicy policy,
  HomeDashboardContext? context,
  AuthUserProfile? user,
}) {
  if (profile.role != AppRole.nurse) {
    return profile;
  }

  return tailorNurseDashboardProfile(
    base: profile,
    departmentKind: context?.nurseContext == null
        ? inferNurseDepartmentKind(
            departmentName: context?.departmentName,
            staffPosition: user?.positionTitle,
            practitionerType: user?.practitionerType,
          )
        : nurseDepartmentKindFromValue(context?.nurseContext),
    policy: policy,
    user: user,
  );
}

bool _nurseMetricAllowed(String metricId, AppAccessPolicy policy) {
  final List<String>? modules = _nurseMetricRequiredModules[metricId];
  if (modules == null || modules.isEmpty) {
    return true;
  }
  return policy.hasAllActiveModules(modules);
}

List<String> _orderedUnique(
  List<String> preferred, {
  required List<String> fallback,
}) {
  final LinkedHashSet<String> ids = LinkedHashSet<String>();
  ids.addAll(preferred);
  ids.addAll(fallback);
  return ids.toList(growable: false);
}

String _nurseHomeTitle(NurseDepartmentKind kind) {
  return switch (kind) {
    NurseDepartmentKind.opd => 'OPD nursing',
    NurseDepartmentKind.theatre => 'Theatre nursing',
    NurseDepartmentKind.radiology => 'Radiology nursing',
    NurseDepartmentKind.icu => 'ICU nursing',
    NurseDepartmentKind.ward => 'Ward nursing',
    NurseDepartmentKind.general => 'Nursing',
  };
}

String nurseDistributionTitleForKind(NurseDepartmentKind kind) {
  return switch (kind) {
    NurseDepartmentKind.opd => 'OPD queue mix',
    NurseDepartmentKind.theatre => 'Theatre case mix',
    NurseDepartmentKind.radiology => 'Imaging workload mix',
    NurseDepartmentKind.icu => 'ICU workload mix',
    NurseDepartmentKind.ward || NurseDepartmentKind.general => 'Ward distribution',
  };
}

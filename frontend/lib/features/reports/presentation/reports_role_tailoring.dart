import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';

/// Domain packs derived from effective permissions (union for multi-role).
enum ReportsDomainPack {
  admin,
  finance,
  pharmacy,
  reception,
  clinical,
  lab,
  radiology,
  hr,
  biomedical,
  operations,
  communications,
  general,
}

/// Preferred infra panels when a domain pack applies (excluding compliance).
const Map<ReportsDomainPack, List<ReportsWorkspacePanel>>
_reportsDomainCatalogPanels =
    <ReportsDomainPack, List<ReportsWorkspacePanel>>{
      ReportsDomainPack.admin: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
        ReportsWorkspacePanel.dashboards,
        ReportsWorkspacePanel.monitor,
        ReportsWorkspacePanel.activity,
      ],
      ReportsDomainPack.finance: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
        ReportsWorkspacePanel.dashboards,
      ],
      ReportsDomainPack.pharmacy: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
      ],
      ReportsDomainPack.reception: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
      ],
      ReportsDomainPack.clinical: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
      ],
      ReportsDomainPack.lab: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
      ],
      ReportsDomainPack.radiology: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
      ],
      ReportsDomainPack.hr: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
      ],
      ReportsDomainPack.biomedical: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
      ],
      ReportsDomainPack.operations: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
        ReportsWorkspacePanel.activity,
      ],
      ReportsDomainPack.communications: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
      ],
      ReportsDomainPack.general: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
        ReportsWorkspacePanel.dashboards,
        ReportsWorkspacePanel.monitor,
        ReportsWorkspacePanel.activity,
      ],
    };

/// Dataset category → any-of permission gates (plus reports:read at call site).
const Map<String, List<AppPermission>> reportsDatasetCategoryPermissions =
    <String, List<AppPermission>>{
      'patients': <AppPermission>[
        AppPermissions.patientRead,
        AppPermissions.patientsRead,
        AppPermissions.receptionRead,
      ],
      'appointments': <AppPermission>[
        AppPermissions.patientRead,
        AppPermissions.patientsRead,
        AppPermissions.receptionRead,
        AppPermissions.opdRead,
        AppPermissions.operationsRead,
      ],
      'billing': <AppPermission>[AppPermissions.billingRead],
      'pharmacy': <AppPermission>[AppPermissions.pharmacyRead],
      'inventory': <AppPermission>[
        AppPermissions.pharmacyRead,
        AppPermissions.operationsRead,
      ],
      'hr': <AppPermission>[AppPermissions.hrRead],
      'biomedical': <AppPermission>[AppPermissions.biomedRead],
      'communications': <AppPermission>[AppPermissions.communicationsRead],
    };

/// Primary dataset keys surfaced as Overview shortcuts per domain pack.
const Map<ReportsDomainPack, List<String>> reportsDomainPrimaryDatasets =
    <ReportsDomainPack, List<String>>{
      ReportsDomainPack.finance: <String>[
        'billing_collections_open_balances',
        'insurance_claims_aging',
      ],
      ReportsDomainPack.pharmacy: <String>[
        'pharmacy_drug_consumption',
        'pharmacy_dispense_throughput',
        'inventory_stock_risk',
      ],
      ReportsDomainPack.reception: <String>[
        'patient_registrations',
        'appointment_throughput_no_shows',
      ],
      ReportsDomainPack.clinical: <String>[
        'patient_registrations',
        'appointment_throughput_no_shows',
      ],
      ReportsDomainPack.lab: <String>[
        'patient_registrations',
      ],
      ReportsDomainPack.radiology: <String>[
        'patient_registrations',
      ],
      ReportsDomainPack.hr: <String>[
        'hr_staffing_leave_coverage',
      ],
      ReportsDomainPack.biomedical: <String>[
        'biomedical_incidents_downtime',
      ],
      ReportsDomainPack.operations: <String>[
        'appointment_throughput_no_shows',
        'inventory_stock_risk',
      ],
      ReportsDomainPack.communications: <String>[
        'communications_delivery_performance',
      ],
      ReportsDomainPack.admin: <String>[
        'billing_collections_open_balances',
        'pharmacy_drug_consumption',
        'patient_registrations',
        'appointment_throughput_no_shows',
      ],
      ReportsDomainPack.general: <String>[
        'patient_registrations',
        'billing_collections_open_balances',
        'pharmacy_drug_consumption',
      ],
    };

bool reportsIsAdminOverlay(AppAccessPolicy policy) {
  return policy.grantsAny(const <AppPermission>[
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ]);
}

/// Domain packs from effective permissions (union). Admins get [admin] only.
Set<ReportsDomainPack> reportsDomainPacks(AppAccessPolicy policy) {
  if (reportsIsAdminOverlay(policy)) {
    return <ReportsDomainPack>{ReportsDomainPack.admin};
  }

  final Set<ReportsDomainPack> packs = <ReportsDomainPack>{};
  if (policy.grants(AppPermissions.billingRead)) {
    packs.add(ReportsDomainPack.finance);
  }
  if (policy.grants(AppPermissions.pharmacyRead)) {
    packs.add(ReportsDomainPack.pharmacy);
  }
  if (policy.grantsAny(const <AppPermission>[
    AppPermissions.receptionRead,
  ])) {
    packs.add(ReportsDomainPack.reception);
  }
  if (policy.grantsAny(const <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.nursingRead,
    AppPermissions.opdRead,
    AppPermissions.ipdRead,
    AppPermissions.icuRead,
    AppPermissions.theaterRead,
    AppPermissions.emergencyRead,
  ])) {
    packs.add(ReportsDomainPack.clinical);
  }
  if (policy.grants(AppPermissions.labRead)) {
    packs.add(ReportsDomainPack.lab);
  }
  if (policy.grants(AppPermissions.radiologyRead)) {
    packs.add(ReportsDomainPack.radiology);
  }
  if (policy.grants(AppPermissions.hrRead)) {
    packs.add(ReportsDomainPack.hr);
  }
  if (policy.grants(AppPermissions.biomedRead)) {
    packs.add(ReportsDomainPack.biomedical);
  }
  if (policy.grants(AppPermissions.operationsRead)) {
    packs.add(ReportsDomainPack.operations);
  }
  if (policy.grants(AppPermissions.communicationsRead)) {
    packs.add(ReportsDomainPack.communications);
  }

  if (packs.isEmpty) {
    packs.add(ReportsDomainPack.general);
  }
  return packs;
}

/// Catalog (non-compliance) panels curated for the user's domain packs.
List<ReportsWorkspacePanel> reportsTailoredCatalogPanels(AppAccessPolicy policy) {
  final Set<ReportsDomainPack> packs = reportsDomainPacks(policy);
  final Set<ReportsWorkspacePanel> panels = <ReportsWorkspacePanel>{};
  for (final ReportsDomainPack pack in packs) {
    panels.addAll(
      _reportsDomainCatalogPanels[pack] ?? const <ReportsWorkspacePanel>[],
    );
  }

  // Stable product order.
  return ReportsWorkspacePanel.values
      .where(
        (ReportsWorkspacePanel panel) =>
            !panel.isCompliance && panels.contains(panel),
      )
      .toList(growable: false);
}

bool canAccessReportsDatasetCategory(
  AppAccessPolicy policy,
  String? category,
) {
  if (reportsIsAdminOverlay(policy)) {
    return true;
  }
  final String normalized = (category ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  final List<AppPermission>? required =
      reportsDatasetCategoryPermissions[normalized];
  if (required == null) {
    // Unknown categories stay visible for reporting specialists.
    return true;
  }
  final Set<ReportsDomainPack> packs = reportsDomainPacks(policy);
  if (packs.contains(ReportsDomainPack.general) && packs.length == 1) {
    // reports:read without domain grants — show full catalog.
    return true;
  }
  return policy.grantsAny(required);
}

bool canAccessReportsDataset(
  AppAccessPolicy policy,
  ReportsLookupOption dataset,
) {
  final Object? category = dataset.meta['category'];
  return canAccessReportsDatasetCategory(
    policy,
    category is String ? category : null,
  );
}

/// Datasets the user may see in filters / Overview shortcuts.
List<ReportsLookupOption> reportsTailoredDatasets(
  AppAccessPolicy policy,
  List<ReportsLookupOption> datasets,
) {
  return datasets
      .where((ReportsLookupOption item) => canAccessReportsDataset(policy, item))
      .toList(growable: false);
}

/// Primary dataset keys for Overview shortcuts (union across packs).
List<String> reportsPrimaryDatasetKeys(AppAccessPolicy policy) {
  final Set<String> keys = <String>{};
  for (final ReportsDomainPack pack in reportsDomainPacks(policy)) {
    keys.addAll(
      reportsDomainPrimaryDatasets[pack] ?? const <String>[],
    );
  }
  return keys.toList(growable: false);
}

/// Domain datasets for Overview chips, limited and ordered.
List<ReportsLookupOption> reportsOverviewDatasetShortcuts(
  AppAccessPolicy policy,
  List<ReportsLookupOption> datasets,
) {
  final List<ReportsLookupOption> allowed = reportsTailoredDatasets(
    policy,
    datasets,
  );
  final List<String> preferred = reportsPrimaryDatasetKeys(policy);
  if (preferred.isEmpty) {
    return allowed.take(4).toList(growable: false);
  }

  final Map<String, ReportsLookupOption> byId = <String, ReportsLookupOption>{
    for (final ReportsLookupOption item in allowed) item.id: item,
  };
  final List<ReportsLookupOption> ordered = <ReportsLookupOption>[
    for (final String key in preferred)
      if (byId.containsKey(key)) byId[key]!,
  ];
  if (ordered.length >= 4) {
    return ordered.take(4).toList(growable: false);
  }
  for (final ReportsLookupOption item in allowed) {
    if (ordered.any((ReportsLookupOption existing) => existing.id == item.id)) {
      continue;
    }
    ordered.add(item);
    if (ordered.length >= 4) {
      break;
    }
  }
  return ordered;
}

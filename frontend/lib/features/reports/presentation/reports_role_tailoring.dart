import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';

/// Domain packs derived from **owned** job scope (not embed-only module reads).
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
  emergency,
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
      ReportsDomainPack.emergency: <ReportsWorkspacePanel>[
        ReportsWorkspacePanel.overview,
        ReportsWorkspacePanel.catalog,
        ReportsWorkspacePanel.delivery,
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
        AppPermissions.emergencyRead,
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
      ReportsDomainPack.emergency: <String>[
        'appointment_throughput_no_shows',
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
      ],
    };

bool reportsIsAdminOverlay(AppAccessPolicy policy) {
  return policy.grantsAny(const <AppPermission>[
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ]);
}

bool _hasAnyRole(AppAccessPolicy policy, Set<AppRole> roles) {
  return roles.any(policy.hasRole);
}

/// Owned domain packs for Reporting chrome (job scope, not embed-only reads).
///
/// Focused shells and primary roles drive packs. Embed grants such as a
/// doctor's `pharmacy:read` do **not** mount pharmacy Reporting.
Set<ReportsDomainPack> reportsDomainPacks(AppAccessPolicy policy) {
  if (reportsIsAdminOverlay(policy)) {
    return <ReportsDomainPack>{ReportsDomainPack.admin};
  }

  // Patient portal is not a staff reporting actor.
  if (policy.hasRole(AppRole.patient) &&
      !policy.hasAnyRole(const <AppRole>[
        AppRole.doctor,
        AppRole.nurse,
        AppRole.labTech,
        AppRole.radiologyTech,
        AppRole.pharmacist,
        AppRole.receptionist,
        AppRole.billing,
        AppRole.operations,
        AppRole.hr,
        AppRole.biomed,
        AppRole.houseKeeper,
        AppRole.ambulanceOperator,
        AppRole.unitManager,
        AppRole.wardManager,
        AppRole.icuManager,
        AppRole.theatreManager,
        AppRole.housekeepingManager,
        AppRole.biomedManager,
        AppRole.mortuaryStaff,
        AppRole.mortuaryManager,
        AppRole.tenantAdmin,
        AppRole.facilityAdmin,
        AppRole.superAdmin,
        AppRole.integrationAdmin,
      ])) {
    return <ReportsDomainPack>{};
  }

  final Set<ReportsDomainPack> packs = <ReportsDomainPack>{};

  if (policy.isPharmacistFocusedShellUser ||
      policy.hasRole(AppRole.pharmacist)) {
    packs.add(ReportsDomainPack.pharmacy);
  }
  if (policy.isBillingFocusedShellUser || policy.hasRole(AppRole.billing)) {
    packs.add(ReportsDomainPack.finance);
  }
  if (policy.isReceptionistFocusedShellUser ||
      policy.hasRole(AppRole.receptionist)) {
    packs.add(ReportsDomainPack.reception);
  }
  if (policy.isLabFocusedShellUser || policy.hasRole(AppRole.labTech)) {
    packs.add(ReportsDomainPack.lab);
  }
  if (policy.hasRole(AppRole.radiologyTech)) {
    packs.add(ReportsDomainPack.radiology);
  }
  if (_hasAnyRole(policy, const <AppRole>{
    AppRole.doctor,
    AppRole.nurse,
    AppRole.wardManager,
    AppRole.icuManager,
    AppRole.theatreManager,
  })) {
    packs.add(ReportsDomainPack.clinical);
  }
  if (_hasAnyRole(policy, const <AppRole>{
    AppRole.hr,
    AppRole.unitManager,
  })) {
    packs.add(ReportsDomainPack.hr);
  }
  if (_hasAnyRole(policy, const <AppRole>{
    AppRole.biomed,
    AppRole.biomedManager,
  })) {
    packs.add(ReportsDomainPack.biomedical);
  }
  if (_hasAnyRole(policy, const <AppRole>{
    AppRole.operations,
    AppRole.houseKeeper,
    AppRole.housekeepingManager,
  })) {
    packs.add(ReportsDomainPack.operations);
  }
  if (policy.hasRole(AppRole.ambulanceOperator)) {
    packs.add(ReportsDomainPack.emergency);
  }

  // True multi-role / custom staff: union additional owned grants without
  // treating clinical pharmacy embeds as pharmacy ownership.
  if (!policy.isPharmacistFocusedShellUser &&
      !policy.hasRole(AppRole.pharmacist) &&
      policy.grants(AppPermissions.billingRead) &&
      !packs.contains(ReportsDomainPack.finance)) {
    // Only add finance from grant when no clinical-primary role holds embeds.
    if (!_hasAnyRole(policy, const <AppRole>{
      AppRole.doctor,
      AppRole.nurse,
      AppRole.labTech,
      AppRole.radiologyTech,
      AppRole.receptionist,
      AppRole.pharmacist,
    })) {
      packs.add(ReportsDomainPack.finance);
    }
  }
  if (policy.grants(AppPermissions.communicationsRead) &&
      packs.isEmpty) {
    packs.add(ReportsDomainPack.communications);
  }

  if (packs.isEmpty) {
    packs.add(ReportsDomainPack.general);
  }
  return packs;
}

/// Whether Overview should mount domain Reporting chrome for [pack].
bool reportsOwnsDomainReporting(AppAccessPolicy policy, ReportsDomainPack pack) {
  return reportsDomainPacks(policy).contains(pack);
}

/// Non-pharmacy packs that should mount shared domain Reporting chrome.
List<ReportsDomainPack> reportsNonPharmacyOwnedPacks(AppAccessPolicy policy) {
  return reportsDomainPacks(policy)
      .where(
        (ReportsDomainPack pack) =>
            pack != ReportsDomainPack.pharmacy &&
            pack != ReportsDomainPack.general,
      )
      .toList(growable: false);
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
  // Pharmacy dataset category still requires pharmacy:read (embed OK for
  // infra catalog filters) but Overview chrome uses owned packs separately.
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

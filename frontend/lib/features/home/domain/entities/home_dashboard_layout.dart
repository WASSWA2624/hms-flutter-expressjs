import 'dart:math' as math;

import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

/// Visual density and section order for role-specific home dashboards.
enum HomeDashboardLayoutTier {
  platform,
  organization,
  facilityCommand,
  clinicalQueue,
  departmentQueue,
  taskFirst,
  workforce,
  patient,
  general,
}

HomeDashboardLayoutTier homeLayoutTierForRole(AppRole role) {
  return switch (role) {
    AppRole.superAdmin => HomeDashboardLayoutTier.platform,
    AppRole.tenantAdmin => HomeDashboardLayoutTier.organization,
    AppRole.facilityAdmin ||
    AppRole.operations => HomeDashboardLayoutTier.facilityCommand,
    AppRole.doctor ||
    AppRole.nurse ||
    AppRole.wardManager ||
    AppRole.icuManager ||
    AppRole.unitManager ||
    AppRole.theatreManager => HomeDashboardLayoutTier.clinicalQueue,
    AppRole.labTech ||
    AppRole.radiologyTech ||
    AppRole.pharmacist ||
    AppRole.receptionist ||
    AppRole.billing ||
    AppRole.biomed ||
    AppRole.biomedManager ||
    AppRole.ambulanceOperator => HomeDashboardLayoutTier.departmentQueue,
    AppRole.houseKeeper ||
    AppRole.housekeepingManager ||
    AppRole.mortuaryStaff ||
    AppRole.mortuaryManager => HomeDashboardLayoutTier.taskFirst,
    AppRole.hr => HomeDashboardLayoutTier.workforce,
    AppRole.patient => HomeDashboardLayoutTier.patient,
    _ => HomeDashboardLayoutTier.general,
  };
}

extension HomeDashboardProfileLayout on HomeDashboardProfile {
  HomeDashboardLayoutTier get layoutTier => homeLayoutTierForRole(role);

  bool get isDoctorClinicalDashboard => id == 'doctor';

  bool get isNurseClinicalDashboard => id == 'nurse';

  bool get isLabDepartmentDashboard => id == 'lab_tech';

  bool get isPharmacistDepartmentDashboard => id == 'pharmacist';

  bool get isReceptionistFrontDeskDashboard => id == 'receptionist';

  bool get isBillingDepartmentDashboard => id == 'billing';

  int get effectiveMaxStatusCards {
    // Dashboard.md recommends 4–6 KPIs. Role profiles set [maxStatusCards];
    // [expandHomeProfileForPermissions] may raise it to 6 so cross-domain
    // grants (e.g. doctor + billing:read) can surface without a new role.
    const int kpiCap = 6;
    return math.min(maxStatusCards, kpiCap);
  }

  int get maxQuickActions {
    if (suppressHomeQuickActions) {
      return 0;
    }
    if (isDoctorClinicalDashboard) {
      return 5;
    }
    if (isNurseClinicalDashboard) {
      return 8;
    }
    if (isPharmacistDepartmentDashboard ||
        isReceptionistFrontDeskDashboard ||
        isBillingDepartmentDashboard) {
      return 4;
    }
    if (isLabDepartmentDashboard) {
      return 3;
    }
    return switch (layoutTier) {
      HomeDashboardLayoutTier.workforce => 0,
      HomeDashboardLayoutTier.platform => 8,
      HomeDashboardLayoutTier.organization => 8,
      HomeDashboardLayoutTier.facilityCommand => 3,
      _ => 2,
    };
  }

  int get maxQueueItems =>
      isDoctorClinicalDashboard ||
          isNurseClinicalDashboard ||
          isPharmacistDepartmentDashboard ||
          isReceptionistFrontDeskDashboard ||
          isBillingDepartmentDashboard
      ? 5
      : 3;

  int get maxResultsItems => isDoctorClinicalDashboard ? 3 : 0;

  int get maxFollowUpItems =>
      isDoctorClinicalDashboard || isReceptionistFrontDeskDashboard ? 3 : 0;

  int get maxShortcutTiles {
    if (suppressHomeShortcuts || shortcutIds.isEmpty) {
      return 0;
    }
    if (isDoctorClinicalDashboard || isNurseClinicalDashboard) {
      return 6;
    }
    if (isReceptionistFrontDeskDashboard || isBillingDepartmentDashboard) {
      return 5;
    }
    // Floor of 4 authorized tiles when the catalog can supply them; prefer 5
    // for admin / facility-command surfaces with denser destinations.
    return switch (layoutTier) {
      HomeDashboardLayoutTier.platform ||
      HomeDashboardLayoutTier.organization ||
      HomeDashboardLayoutTier.facilityCommand ||
      HomeDashboardLayoutTier.workforce => 5,
      HomeDashboardLayoutTier.patient => 0,
      _ => 4,
    };
  }

  bool get compactMetrics {
    return layoutTier != HomeDashboardLayoutTier.workforce &&
        layoutTier != HomeDashboardLayoutTier.platform &&
        layoutTier != HomeDashboardLayoutTier.organization &&
        layoutTier != HomeDashboardLayoutTier.facilityCommand;
  }

  bool get showCharts => true;

  bool get queueBeforeMetrics => false;

  bool get alertsBeforeMetrics => isDoctorClinicalDashboard;

  bool get showAlertsInPriorityPanel => !alertsBeforeMetrics;

  bool showChartsWhenData({
    required HomeDashboardTrend trend,
    required HomeDashboardDistribution distribution,
  }) {
    // Collapse empty chart strips for every persona (permission filter may
    // clear trend/distribution when reports:read is missing).
    if (!trend.hasData && !distribution.hasData) {
      return false;
    }
    return showCharts;
  }

  bool showActivityPanel({required bool hasQueueItems}) => false;

  bool showAlertsPanel(List<HomeAlertItem> alerts) => showQueuePanel;

  bool showShortcutsSection({required int quickActionCount}) {
    if (suppressHomeShortcuts || shortcutIds.isEmpty || maxShortcutTiles == 0) {
      return false;
    }
    return true;
  }

  bool get showMetricsSection => true;

  bool get showQueuePanel {
    return layoutTier != HomeDashboardLayoutTier.workforce;
  }

  bool showQueuePanelFor(List<HomeQueueItem> items) => showQueuePanel;

  bool get showQueuePanelTitle => true;
}

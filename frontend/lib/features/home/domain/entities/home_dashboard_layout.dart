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
    AppRole.facilityAdmin || AppRole.operations =>
      HomeDashboardLayoutTier.facilityCommand,
    AppRole.doctor ||
    AppRole.nurse ||
    AppRole.wardManager ||
    AppRole.icuManager ||
    AppRole.unitManager ||
    AppRole.theatreManager =>
      HomeDashboardLayoutTier.clinicalQueue,
    AppRole.labTech ||
    AppRole.radiologyTech ||
    AppRole.pharmacist ||
    AppRole.receptionist ||
    AppRole.billing ||
    AppRole.biomed ||
    AppRole.biomedManager ||
    AppRole.ambulanceOperator =>
      HomeDashboardLayoutTier.departmentQueue,
    AppRole.houseKeeper ||
    AppRole.housekeepingManager ||
    AppRole.mortuaryStaff ||
    AppRole.mortuaryManager =>
      HomeDashboardLayoutTier.taskFirst,
    AppRole.hr => HomeDashboardLayoutTier.workforce,
    AppRole.patient => HomeDashboardLayoutTier.patient,
    _ => HomeDashboardLayoutTier.general,
  };
}

extension HomeDashboardProfileLayout on HomeDashboardProfile {
  HomeDashboardLayoutTier get layoutTier => homeLayoutTierForRole(role);

  bool get showCharts {
    return switch (layoutTier) {
      HomeDashboardLayoutTier.platform ||
      HomeDashboardLayoutTier.clinicalQueue ||
      HomeDashboardLayoutTier.departmentQueue ||
      HomeDashboardLayoutTier.taskFirst ||
      HomeDashboardLayoutTier.workforce ||
      HomeDashboardLayoutTier.patient =>
        false,
      _ => true,
    };
  }

  bool get queueBeforeMetrics {
    return switch (layoutTier) {
      HomeDashboardLayoutTier.clinicalQueue ||
      HomeDashboardLayoutTier.departmentQueue ||
      HomeDashboardLayoutTier.taskFirst =>
        true,
      _ => false,
    };
  }

  bool showActivityPanel({required bool hasQueueItems}) {
    if (suppressHomeShortcuts && layoutTier == HomeDashboardLayoutTier.workforce) {
      return false;
    }
    return switch (layoutTier) {
      HomeDashboardLayoutTier.departmentQueue ||
      HomeDashboardLayoutTier.taskFirst ||
      HomeDashboardLayoutTier.patient =>
        false,
      HomeDashboardLayoutTier.clinicalQueue => !hasQueueItems,
      _ => true,
    };
  }

  bool showShortcutsSection({required int quickActionCount}) {
    if (suppressHomeShortcuts || shortcutIds.isEmpty) {
      return false;
    }
    return switch (layoutTier) {
      HomeDashboardLayoutTier.departmentQueue ||
      HomeDashboardLayoutTier.taskFirst ||
      HomeDashboardLayoutTier.workforce ||
      HomeDashboardLayoutTier.patient =>
        false,
      HomeDashboardLayoutTier.clinicalQueue => quickActionCount > 3,
      _ => true,
    };
  }

  bool get showMetricsSection => true;

  bool get showQueuePanel {
    return layoutTier != HomeDashboardLayoutTier.workforce;
  }
}

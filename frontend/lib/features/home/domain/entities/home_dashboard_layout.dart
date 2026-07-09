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

  int get effectiveMaxStatusCards {
    final int tierCap = switch (layoutTier) {
      HomeDashboardLayoutTier.platform ||
      HomeDashboardLayoutTier.organization ||
      HomeDashboardLayoutTier.facilityCommand ||
      HomeDashboardLayoutTier.workforce => 4,
      _ => 3,
    };
    return math.min(maxStatusCards, tierCap);
  }

  int get maxQuickActions {
    if (suppressHomeQuickActions) {
      return 0;
    }
    return switch (layoutTier) {
      HomeDashboardLayoutTier.workforce => 0,
      HomeDashboardLayoutTier.platform ||
      HomeDashboardLayoutTier.organization ||
      HomeDashboardLayoutTier.facilityCommand => 3,
      _ => 2,
    };
  }

  int get maxQueueItems => 3;

  int get maxShortcutTiles => switch (layoutTier) {
    HomeDashboardLayoutTier.platform ||
    HomeDashboardLayoutTier.organization => 3,
    HomeDashboardLayoutTier.facilityCommand => 2,
    _ => 3,
  };

  bool get compactMetrics {
    return layoutTier != HomeDashboardLayoutTier.workforce &&
        layoutTier != HomeDashboardLayoutTier.platform &&
        layoutTier != HomeDashboardLayoutTier.organization &&
        layoutTier != HomeDashboardLayoutTier.facilityCommand;
  }

  bool get showCharts => true;

  bool showChartsWhenData({
    required HomeDashboardTrend trend,
    required HomeDashboardDistribution distribution,
  }) {
    return showCharts;
  }

  bool get queueBeforeMetrics => false;

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

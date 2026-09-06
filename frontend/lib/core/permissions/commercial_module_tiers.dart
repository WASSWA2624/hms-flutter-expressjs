/// Commercial module minimum tiers — mirrors backend `plan-module-matrix.js`.
///
/// Used to fail closed in the shell when a tenant still has a stale
/// `module_subscription` row for a higher-tier package.
abstract final class CommercialModuleTiers {
  static const Map<String, int> tierRank = <String, int>{
    'FREE': 0,
    'BASIC': 1,
    'ADVANCED': 2,
    'PRO': 3,
    'CUSTOM': 4,
    'DEVELOPER': 5,
  };

  /// Minimum plan tier for commercial modules.
  /// Unlisted modules are not tier-gated here (FREE / platform / unknown).
  static const Map<String, String> minimumTierBySlug = <String, String>{
    'scheduling-queue': 'BASIC',
    'encounters-vitals': 'BASIC',
    'pharmacy-dispensing': 'BASIC',
    'billing-payments': 'BASIC',
    'facility-accounts': 'BASIC',
    'inpatient-bed-management': 'BASIC',
    'notifications-communications': 'BASIC',
    'subscription-controls': 'BASIC',
    'lab-workflows': 'ADVANCED',
    'radiology-workflows': 'ADVANCED',
    'insurance-claims': 'ADVANCED',
    'physiotherapy': 'ADVANCED',
    'extra-storage': 'ADVANCED',
    'inventory-procurement': 'ADVANCED',
    'theatre-anesthesia': 'PRO',
    'facilities-maintenance': 'PRO',
    'icu-critical-care': 'PRO',
    'hr-rosters': 'PRO',
    'biomedical-engineering-suite': 'PRO',
    'mortuary': 'PRO',
    'integrations-core': 'PRO',
    'inventory-procurement-lite': 'PRO',
    'compliance-audit-core': 'CUSTOM',
    'advanced-analytics': 'CUSTOM',
    'sms-credits': 'CUSTOM',
    'developer-tools': 'DEVELOPER',
  };

  static int rankOf(String? tierCode) {
    final String normalized = (tierCode ?? '').trim().toUpperCase();
    return tierRank[normalized] ?? -1;
  }

  static String? minimumTierForModule(String moduleCode) {
    final String slug = moduleCode.trim().toLowerCase().replaceAll('_', '-');
    return minimumTierBySlug[slug];
  }

  static bool planMeetsModuleMinimum({
    required String? planTierCode,
    required String moduleCode,
  }) {
    final String? minimum = minimumTierForModule(moduleCode);
    if (minimum == null) {
      return true;
    }
    final int planRank = rankOf(planTierCode);
    if (planRank < 0) {
      // Unknown tier: do not block on this layer (permission caps still apply).
      return true;
    }
    return planRank >= rankOf(minimum);
  }
}

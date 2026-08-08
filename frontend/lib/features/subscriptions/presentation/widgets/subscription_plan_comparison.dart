import 'package:hosspi_hms/core/permissions/commercial_module_tiers.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';

/// Compact comparison rows for upgrade plan columns.
///
/// Mirrors commercial packaging (`CommercialModuleTiers` / plan-module-matrix).
final class SubscriptionPlanComparisonFeature {
  const SubscriptionPlanComparisonFeature({
    required this.id,
    required this.label,
    this.moduleSlug,
    this.limitKey,
  });

  final String id;
  final String label;

  /// When set, inclusion is derived from plan tier vs module minimum.
  final String? moduleSlug;

  /// When set, value comes from plan limit fields (`users`, `facilities`,
  /// `storage`).
  final String? limitKey;
}

abstract final class SubscriptionPlanComparisonCatalog {
  static const List<SubscriptionPlanComparisonFeature> features =
      <SubscriptionPlanComparisonFeature>[
        SubscriptionPlanComparisonFeature(
          id: 'limit_users',
          label: 'Users',
          limitKey: 'users',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'limit_facilities',
          label: 'Facilities',
          limitKey: 'facilities',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'limit_storage',
          label: 'Storage',
          limitKey: 'storage',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'patient_registry',
          label: 'Patient registry',
          moduleSlug: 'patient-registry',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'scheduling_queue',
          label: 'OPD / queue',
          moduleSlug: 'scheduling-queue',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'encounters_vitals',
          label: 'Encounters & vitals',
          moduleSlug: 'encounters-vitals',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'pharmacy_dispensing',
          label: 'Pharmacy',
          moduleSlug: 'pharmacy-dispensing',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'billing_payments',
          label: 'Billing',
          moduleSlug: 'billing-payments',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'notifications',
          label: 'Communications',
          moduleSlug: 'notifications-communications',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'lab_workflows',
          label: 'Lab',
          moduleSlug: 'lab-workflows',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'radiology_workflows',
          label: 'Radiology',
          moduleSlug: 'radiology-workflows',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'insurance_claims',
          label: 'Claims',
          moduleSlug: 'insurance-claims',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'physiotherapy',
          label: 'Physiotherapy',
          moduleSlug: 'physiotherapy',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'inpatient',
          label: 'IPD / beds',
          moduleSlug: 'inpatient-bed-management',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'icu',
          label: 'ICU',
          moduleSlug: 'icu-critical-care',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'theatre',
          label: 'Theatre',
          moduleSlug: 'theatre-anesthesia',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'hr',
          label: 'HR / rosters',
          moduleSlug: 'hr-rosters',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'biomed',
          label: 'Biomedical',
          moduleSlug: 'biomedical-engineering-suite',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'mortuary',
          label: 'Mortuary',
          moduleSlug: 'mortuary',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'integrations',
          label: 'Integrations',
          moduleSlug: 'integrations-core',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'compliance',
          label: 'Compliance',
          moduleSlug: 'compliance-audit-core',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'analytics',
          label: 'Analytics',
          moduleSlug: 'advanced-analytics',
        ),
        SubscriptionPlanComparisonFeature(
          id: 'developer_tools',
          label: 'Developer tools',
          moduleSlug: 'developer-tools',
        ),
      ];

  static bool includesModule(
    SubscriptionUpgradePlanOption plan,
    String moduleSlug,
  ) {
    final String tier = (plan.tierCode ?? '').trim().toUpperCase();
    if (tier == 'DEVELOPER' || tier == 'CUSTOM') {
      return true;
    }
    if (plan.includedModuleSlugs.isNotEmpty) {
      final String needle = moduleSlug.trim().toLowerCase();
      return plan.includedModuleSlugs.any(
        (String slug) => slug.trim().toLowerCase() == needle,
      );
    }
    return CommercialModuleTiers.planMeetsModuleMinimum(
      planTierCode: plan.tierCode,
      moduleCode: moduleSlug,
    );
  }

  static String limitValue(SubscriptionUpgradePlanOption plan, String key) {
    switch (key) {
      case 'users':
        return _formatCap(plan.maxUsers);
      case 'facilities':
        return _formatCap(plan.maxFacilities);
      case 'storage':
        return _formatStorage(plan.maxStorageMb);
      default:
        return '—';
    }
  }

  static String _formatCap(int? value) {
    if (value == null) {
      return 'Unlimited';
    }
    if (value <= 0) {
      return '—';
    }
    return '$value';
  }

  static String _formatStorage(int? megabytes) {
    if (megabytes == null) {
      return 'Unlimited';
    }
    if (megabytes <= 0) {
      return '—';
    }
    if (megabytes >= 1024) {
      final double gb = megabytes / 1024;
      final String text = gb % 1 == 0
          ? gb.toStringAsFixed(0)
          : gb.toStringAsFixed(1);
      return '$text GB';
    }
    return '$megabytes MB';
  }
}

final class HomeDashboardLookups {
  const HomeDashboardLookups({
    this.tenants = const <HomeLookupOption>[],
    this.facilities = const <HomeLookupOption>[],
    this.branches = const <HomeLookupOption>[],
    this.queueTypes = const <HomeLookupOption>[],
    this.datePresets = const <HomeLookupOption>[],
  });

  final List<HomeLookupOption> tenants;
  final List<HomeLookupOption> facilities;
  final List<HomeLookupOption> branches;
  final List<HomeLookupOption> queueTypes;
  final List<HomeLookupOption> datePresets;

  bool get hasTenantOptions => tenants.isNotEmpty;

  bool get hasFacilityOptions => facilities.isNotEmpty;

  bool get hasBranchOptions => branches.isNotEmpty;

  List<HomeLookupOption> facilitiesForTenant(String? tenantId) {
    if (tenantId == null || tenantId.trim().isEmpty) {
      return facilities;
    }
    return facilities
        .where(
          (HomeLookupOption option) =>
              option.metaTenantId == null || option.metaTenantId == tenantId,
        )
        .toList(growable: false);
  }

  List<HomeLookupOption> branchesForFacility(String? facilityId) {
    if (facilityId == null || facilityId.trim().isEmpty) {
      return branches;
    }
    return branches
        .where(
          (HomeLookupOption option) =>
              option.metaFacilityId == null ||
              option.metaFacilityId == facilityId,
        )
        .toList(growable: false);
  }
}

final class HomeLookupOption {
  const HomeLookupOption({
    required this.id,
    required this.label,
    this.metaTenantId,
    this.metaFacilityId,
    this.metaFacilityType,
  });

  final String id;
  final String label;
  final String? metaTenantId;
  final String? metaFacilityId;
  final String? metaFacilityType;
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/workspace/workspace_prefetch_ready_provider.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_controller.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/controllers/claims_workspace_controller.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/controllers/discharge_workspace_controller.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';
import 'package:hosspi_hms/features/integrations/presentation/controllers/integrations_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/presentation/controllers/mortuary_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/presentation/controllers/operations_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/presentation/controllers/radiology_workspace_controller.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/presentation/controllers/theater_workspace_controller.dart';

@immutable
final class ShellBadgeCounts {
  const ShellBadgeCounts({
    this.opdWorkloadCount,
    this.emergencyWorkloadCount,
    this.ipdWorkloadCount,
    this.roomsBedsWorkloadCount,
    this.icuCriticalCount,
    this.nursingWorkloadCount,
    this.clinicalWorkloadCount,
    this.labWorkloadCount,
    this.radiologyWorkloadCount,
    this.pharmacyWorkloadCount,
    this.billingWorkloadCount,
    this.claimsWorkloadCount,
    this.subscriptionsWorkloadCount,
    this.operationsWorkloadCount,
    this.housekeepingWorkloadCount,
    this.hrWorkloadCount,
    this.biomedicalWorkloadCount,
    this.communicationsWorkloadCount,
    this.integrationsWorkloadCount,
    this.dischargeWorkloadCount,
    this.mortuaryWorkloadCount,
    this.theaterWorkloadCount,
    this.notificationUnreadCount,
  });

  static const ShellBadgeCounts empty = ShellBadgeCounts();

  final int? opdWorkloadCount;
  final int? emergencyWorkloadCount;
  final int? ipdWorkloadCount;
  final int? roomsBedsWorkloadCount;
  final int? icuCriticalCount;
  final int? nursingWorkloadCount;
  final int? clinicalWorkloadCount;
  final int? labWorkloadCount;
  final int? radiologyWorkloadCount;
  final int? pharmacyWorkloadCount;
  final int? billingWorkloadCount;
  final int? claimsWorkloadCount;
  final int? subscriptionsWorkloadCount;
  final int? operationsWorkloadCount;
  final int? housekeepingWorkloadCount;
  final int? hrWorkloadCount;
  final int? biomedicalWorkloadCount;
  final int? communicationsWorkloadCount;
  final int? integrationsWorkloadCount;
  final int? dischargeWorkloadCount;
  final int? mortuaryWorkloadCount;
  final int? theaterWorkloadCount;
  final int? notificationUnreadCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ShellBadgeCounts &&
            opdWorkloadCount == other.opdWorkloadCount &&
            emergencyWorkloadCount == other.emergencyWorkloadCount &&
            ipdWorkloadCount == other.ipdWorkloadCount &&
            roomsBedsWorkloadCount == other.roomsBedsWorkloadCount &&
            icuCriticalCount == other.icuCriticalCount &&
            nursingWorkloadCount == other.nursingWorkloadCount &&
            clinicalWorkloadCount == other.clinicalWorkloadCount &&
            labWorkloadCount == other.labWorkloadCount &&
            radiologyWorkloadCount == other.radiologyWorkloadCount &&
            pharmacyWorkloadCount == other.pharmacyWorkloadCount &&
            billingWorkloadCount == other.billingWorkloadCount &&
            claimsWorkloadCount == other.claimsWorkloadCount &&
            subscriptionsWorkloadCount == other.subscriptionsWorkloadCount &&
            operationsWorkloadCount == other.operationsWorkloadCount &&
            housekeepingWorkloadCount == other.housekeepingWorkloadCount &&
            hrWorkloadCount == other.hrWorkloadCount &&
            biomedicalWorkloadCount == other.biomedicalWorkloadCount &&
            communicationsWorkloadCount == other.communicationsWorkloadCount &&
            integrationsWorkloadCount == other.integrationsWorkloadCount &&
            dischargeWorkloadCount == other.dischargeWorkloadCount &&
            mortuaryWorkloadCount == other.mortuaryWorkloadCount &&
            theaterWorkloadCount == other.theaterWorkloadCount &&
            notificationUnreadCount == other.notificationUnreadCount;
  }

  @override
  int get hashCode => Object.hashAll(<int?>[
        opdWorkloadCount,
        emergencyWorkloadCount,
        ipdWorkloadCount,
        roomsBedsWorkloadCount,
        icuCriticalCount,
        nursingWorkloadCount,
        clinicalWorkloadCount,
        labWorkloadCount,
        radiologyWorkloadCount,
        pharmacyWorkloadCount,
        billingWorkloadCount,
        claimsWorkloadCount,
        subscriptionsWorkloadCount,
        operationsWorkloadCount,
        housekeepingWorkloadCount,
        hrWorkloadCount,
        biomedicalWorkloadCount,
        communicationsWorkloadCount,
        integrationsWorkloadCount,
        dischargeWorkloadCount,
        mortuaryWorkloadCount,
        theaterWorkloadCount,
        notificationUnreadCount,
      ]);
}

int? _positiveOrNull(int count) => count > 0 ? count : null;

int? _selectBadge<S>(
  AsyncValue<Result<S>> asyncResult,
  int? Function(S state) extract,
) {
  return asyncResult.asData?.value.when(
    success: (S state) => extract(state),
    failure: (_) => null,
  );
}

/// Watches only badge counts from workspace controllers using [select],
/// preventing full-shell rebuilds when workspace data (lists, filters, etc.)
/// changes without affecting badge counts.
final shellBadgeCountsProvider = Provider<ShellBadgeCounts>((ref) {
  final bool ready = ref
      .watch(workspacePrefetchReadyProvider)
      .maybeWhen(data: (bool ready) => ready, orElse: () => false);
  if (!ready) {
    return ShellBadgeCounts.empty;
  }

  final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);

  bool canAccess(AppRouteData route) =>
      canAccessShellRoute(route, accessPolicy);

  final bool canOpd = canAccess(AppRoutes.opd);
  final bool canEmergency = canAccess(AppRoutes.emergency);
  final bool canIpd = canAccess(AppRoutes.ipd);
  final bool canRoomsBeds = canAccess(AppRoutes.roomsBeds);
  final bool canIcu = canAccess(AppRoutes.icu);
  final bool canNursing = canAccess(AppRoutes.nursing);
  final bool canClinical = canAccess(AppRoutes.clinical);
  final bool canLab = canAccess(AppRoutes.lab);
  final bool canRadiology = canAccess(AppRoutes.radiology);
  final bool canPharmacy = canAccess(AppRoutes.pharmacy);
  final bool canBilling = canAccess(AppRoutes.billing);
  final bool canClaims = canAccess(AppRoutes.claims);
  final bool canSubscriptions = canAccess(AppRoutes.subscriptions);
  final bool canOperations = canAccess(AppRoutes.operations);
  final bool canHousekeeping = canAccess(AppRoutes.housekeeping);
  final bool canHr = canAccess(AppRoutes.hr);
  final bool canBiomedical = canAccess(AppRoutes.biomedical);
  final bool canCommunications = canAccess(AppRoutes.communications);
  final bool canIntegrations = canAccess(AppRoutes.integrations);
  final bool canDischarge = canAccess(AppRoutes.discharge);
  final bool canMortuary = canAccess(AppRoutes.mortuary);
  final bool canTheater = canAccess(AppRoutes.theater);

  return ShellBadgeCounts(
    opdWorkloadCount: canOpd
        ? ref.watch(opdWorkspaceControllerProvider.select(
            (v) => _selectBadge<OpdWorkspaceState>(v, (s) => s.workloadCount),
          ))
        : null,
    emergencyWorkloadCount: canEmergency
        ? ref.watch(emergencyWorkspaceControllerProvider.select(
            (v) => _selectBadge<EmergencyWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    ipdWorkloadCount: canIpd
        ? ref.watch(ipdWorkspaceControllerProvider.select(
            (v) => _selectBadge<IpdWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    roomsBedsWorkloadCount: canRoomsBeds
        ? ref.watch(roomsBedsWorkspaceControllerProvider.select(
            (v) => _selectBadge<RoomsBedsWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    icuCriticalCount: canIcu
        ? ref.watch(icuWorkspaceControllerProvider.select(
            (v) => _selectBadge<IcuWorkspaceState>(
                v, (s) => _positiveOrNull(s.criticalCount)),
          ))
        : null,
    nursingWorkloadCount: canNursing
        ? ref.watch(nursingWorkspaceControllerProvider.select(
            (v) => _selectBadge<NursingWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    clinicalWorkloadCount: canClinical
        ? ref.watch(clinicalWorkspaceControllerProvider.select(
            (v) => _selectBadge<ClinicalWorkspaceState>(v, (s) {
              final int count = s.workloadCount;
              return count > 0 ? count : null;
            }),
          ))
        : null,
    labWorkloadCount: canLab
        ? ref.watch(labWorkspaceControllerProvider.select(
            (v) => _selectBadge<LabWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    radiologyWorkloadCount: canRadiology
        ? ref.watch(radiologyWorkspaceControllerProvider.select(
            (v) => _selectBadge<RadiologyWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    pharmacyWorkloadCount: canPharmacy
        ? ref.watch(pharmacyWorkspaceControllerProvider.select(
            (v) => _selectBadge<PharmacyWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    billingWorkloadCount: canBilling
        ? ref.watch(billingWorkspaceControllerProvider.select(
            (v) => _selectBadge<BillingWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    claimsWorkloadCount: canClaims
        ? ref.watch(claimsWorkspaceControllerProvider.select(
            (v) => _selectBadge<ClaimsWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    subscriptionsWorkloadCount: canSubscriptions
        ? ref.watch(subscriptionsWorkspaceControllerProvider.select(
            (v) => _selectBadge<SubscriptionsWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    operationsWorkloadCount: canOperations
        ? ref.watch(operationsWorkspaceControllerProvider.select(
            (v) => _selectBadge<OperationsWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    housekeepingWorkloadCount: canHousekeeping
        ? ref.watch(housekeepingWorkspaceControllerProvider.select(
            (v) => _selectBadge<HousekeepingWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    hrWorkloadCount: canHr
        ? ref.watch(hrWorkspaceControllerProvider.select(
            (v) => _selectBadge<HrWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    biomedicalWorkloadCount: canBiomedical
        ? ref.watch(biomedicalWorkspaceControllerProvider.select(
            (v) => _selectBadge<BiomedicalWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    communicationsWorkloadCount: canCommunications
        ? ref.watch(communicationsWorkspaceControllerProvider.select(
            (v) => _selectBadge<CommunicationsWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    integrationsWorkloadCount: canIntegrations
        ? ref.watch(integrationsWorkspaceControllerProvider.select(
            (v) => _selectBadge<IntegrationWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    dischargeWorkloadCount: canDischarge
        ? ref.watch(dischargeWorkspaceControllerProvider.select(
            (v) => _selectBadge<DischargeWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    mortuaryWorkloadCount: canMortuary
        ? ref.watch(mortuaryWorkspaceControllerProvider.select(
            (v) => _selectBadge<MortuaryWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    theaterWorkloadCount: canTheater
        ? ref.watch(theaterWorkspaceControllerProvider.select(
            (v) => _selectBadge<TheaterWorkspaceState>(
                v, (s) => _positiveOrNull(s.workloadCount)),
          ))
        : null,
    notificationUnreadCount: canCommunications
        ? ref.watch(communicationsWorkspaceControllerProvider.select(
            (v) => _selectBadge<CommunicationsWorkspaceState>(v, (s) {
              return s.unreadBadgeCount > 0 ? s.unreadBadgeCount : null;
            }),
          ))
        : null,
  );
});

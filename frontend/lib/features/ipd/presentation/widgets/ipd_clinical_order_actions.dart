import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<bool?> openIpdLabOrderDialog(BuildContext context) async {
  final IpdWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(ipdWorkspaceControllerProvider.notifier);
  final ClinicalReferenceData referenceData = await controller
      .clinicalReferenceData();
  if (!context.mounted) {
    return null;
  }
  final IpdAdmissionDetail? admission =
      ProviderScope.containerOf(context, listen: false)
          .read(ipdWorkspaceControllerProvider)
          .value
          ?.when(
            success: (IpdWorkspaceState state) => state.selectedAdmission,
            failure: (_) => null,
          );
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalLabOrderActionDialog(
      referenceData: referenceData,
      patientContext: ClinicalRequestPatientContext(
        patientName: admission?.summary.patientDisplayName,
        patientId: admission?.summary.patientId,
        encounterId: admission?.summary.encounterId,
      ),
      onSearchLabTests:
          ({
            required String termType,
            String? query,
            int? limit,
            String source = 'ALL',
          }) {
            return controller.searchClinicalTerms(
              termType: termType,
              query: query,
              limit: limit ?? 80,
              source: source,
            );
          },
      onRequest:
          ({
            required List<String> labTestIds,
            required List<String> labPanelIds,
            ClinicalRequestBillingSubmit? billing,
          }) {
            return controller.orderLab(
              labTestIds: labTestIds,
              labPanelIds: labPanelIds,
              billing: billing,
            );
          },
      onUpdate:
          ({
            required String labOrderId,
            required List<String> labTestIds,
            required List<String> labPanelIds,
            ClinicalRequestBillingSubmit? billing,
          }) {
            return controller.orderLab(
              labTestIds: labTestIds,
              labPanelIds: labPanelIds,
              billing: billing,
            );
          },
    ),
  );
}

Future<bool?> openIpdRadiologyOrderDialog(BuildContext context) async {
  final IpdWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(ipdWorkspaceControllerProvider.notifier);
  final ClinicalReferenceData referenceData = await controller
      .clinicalReferenceData();
  if (!context.mounted) {
    return null;
  }
  final IpdAdmissionDetail? admission =
      ProviderScope.containerOf(context, listen: false)
          .read(ipdWorkspaceControllerProvider)
          .value
          ?.when(
            success: (IpdWorkspaceState state) => state.selectedAdmission,
            failure: (_) => null,
          );
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalRadiologyOrderActionDialog(
      referenceData: referenceData,
      patientContext: ClinicalRequestPatientContext(
        patientName: admission?.summary.patientDisplayName,
        patientId: admission?.summary.patientId,
        encounterId: admission?.summary.encounterId,
      ),
      onSearchRadiologyTests:
          ({
            required String termType,
            String? query,
            int? limit,
            String source = 'ALL',
          }) {
            return controller.searchClinicalTerms(
              termType: termType,
              query: query,
              limit: limit ?? 80,
              source: source,
            );
          },
      onSubmit: controller.orderRadiology,
    ),
  );
}

Future<bool?> openIpdPrescriptionDialog(BuildContext context) async {
  final IpdWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(ipdWorkspaceControllerProvider.notifier);
  final ClinicalReferenceData referenceData = await controller
      .clinicalReferenceData();
  if (!context.mounted) {
    return null;
  }
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalPrescriptionActionDialog(
      referenceData: referenceData,
      onSubmit: controller.prescribeMedication,
    ),
  );
}

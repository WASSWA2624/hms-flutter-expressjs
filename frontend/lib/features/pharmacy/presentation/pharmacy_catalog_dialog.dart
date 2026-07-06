import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> openPharmacyCatalogDialog(
  BuildContext context,
  WidgetRef ref, {
  PharmacyCatalogTab initialTab = PharmacyCatalogTab.drugs,
}) async {
  final PharmacyWorkspaceController controller = ref.read(
    pharmacyWorkspaceControllerProvider.notifier,
  );
  controller.prepareCatalogTab(initialTab);

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, _) {
        final PharmacyWorkspaceState? state = ref
            .watch(pharmacyWorkspaceControllerProvider)
            .value
            ?.when(
              success: (PharmacyWorkspaceState value) => value,
              failure: (_) => null,
            );
        if (state == null) {
          return AppDialog(
            title: Text(dialogContext.l10n.pharmacyCatalogPanelTitle),
            icon: const Icon(Icons.inventory_2_outlined),
            content: const SizedBox.shrink(),
          );
        }
        return AppDialog(
          title: Text(dialogContext.l10n.pharmacyCatalogPanelTitle),
          icon: const Icon(Icons.inventory_2_outlined),
          scrollable: true,
          maxWidth: 1080,
          content: PharmacyCatalogPanel(state: state),
        );
      },
    ),
  );
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/platform/app_print.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

@immutable
final class PrintFormTemplateContext {
  const PrintFormTemplateContext({
    required this.appBranding,
    this.facilityBranding,
  });

  final PrintFormBranding appBranding;
  final PrintFormBranding? facilityBranding;
}

PrintFormSignatures buildPrintFormSignatures(
  AppLocalizations l10n, {
  String? printedByName,
  String? verifiedByName,
}) {
  return PrintFormSignatures(
    printedByLabel: l10n.printFormPrintedByLabel,
    verifiedByLabel: l10n.printFormVerifiedByLabel,
    printedByName: printedByName,
    verifiedByName: verifiedByName,
    signatureStampLabel: l10n.printFormSignatureStampLabel,
  );
}

PrintFormPatientContext buildPrintFormPatientContext(
  AppLocalizations l10n, {
  required String patientName,
  String? patientId,
  String? encounterId,
  String? patientNameLabel,
  String? patientIdLabel,
  String? encounterIdLabel,
}) {
  return PrintFormPatientContext(
    patientNameLabel: patientNameLabel ?? l10n.printFormPatientNameLabel,
    patientName: patientName,
    patientIdLabel: patientId != null
        ? (patientIdLabel ?? l10n.printFormPatientIdLabel)
        : null,
    patientId: patientId,
    encounterIdLabel: encounterId != null
        ? (encounterIdLabel ?? l10n.printFormEncounterIdLabel)
        : null,
    encounterId: encounterId,
  );
}

Future<void> printFormTemplateDocument({
  required WidgetRef ref,
  required BuildContext context,
  required String title,
  String? subtitle,
  String? bodyHtml,
  List<PrintFormPage> pages = const <PrintFormPage>[],
  List<PrintFormMetadataItem> metadata = const <PrintFormMetadataItem>[],
  PrintFormPatientContext? patientContext,
  PrintFormContextReference? contextReference,
  PrintFormSignatures? signatures,
  bool includeSignatures = false,
  String? verifiedByName,
  DateTime? printedAt,
  String? footerNote,
}) async {
  final PrintFormTemplateContext templateContext = await ref.read(
    printFormTemplateContextReadyProvider.future,
  );
  if (!context.mounted) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final AuthSession? session = ref.read(
    sessionStateProvider.select((state) => state.session),
  );
  final PrintFormSignatures? effectiveSignatures =
      signatures ??
      (includeSignatures
          ? buildPrintFormSignatures(
              l10n,
              printedByName: session?.user?.displayName,
              verifiedByName: verifiedByName,
            )
          : null);

  printHtmlDocument(
    PrintFormTemplate.build(
      context: context,
      title: title,
      subtitle: subtitle,
      bodyHtml: bodyHtml,
      pages: pages,
      metadata: metadata,
      patientContext: patientContext,
      contextReference: contextReference,
      signatures: effectiveSignatures,
      printedAt: printedAt,
      printedLabel: l10n.printFormPrintedLabel,
      footerNote: footerNote,
      appBranding: templateContext.appBranding,
      facilityBranding: templateContext.facilityBranding,
    ),
    title: title,
  );
}

final printFormTemplateContextProvider = Provider<PrintFormTemplateContext>((
  ref,
) {
  final AppConfig config = ref.watch(appConfigProvider);
  final AuthSession? session = ref.watch(
    sessionStateProvider.select((state) => state.session),
  );
  final FacilitySetupSnapshot? setup = _setupSnapshot(
    ref.watch(tenantFacilitySetupControllerProvider),
  );

  return PrintFormTemplateContext(
    appBranding: _appBranding(config),
    facilityBranding: _facilityBranding(setup: setup, session: session),
  );
});

final printFormTemplateContextReadyProvider =
    FutureProvider<PrintFormTemplateContext>((ref) async {
      final AppConfig config = ref.watch(appConfigProvider);
      final AuthSession? session = ref.watch(
        sessionStateProvider.select((state) => state.session),
      );
      FacilitySetupSnapshot? setup;

      try {
        final Result<FacilitySetupSnapshot> result = await ref.watch(
          tenantFacilitySetupControllerProvider.future,
        );
        setup = result.when(
          success: (FacilitySetupSnapshot snapshot) => snapshot,
          failure: (_) => null,
        );
      } catch (_) {
        setup = null;
      }

      return PrintFormTemplateContext(
        appBranding: _appBranding(config),
        facilityBranding: _facilityBranding(setup: setup, session: session),
      );
    });

PrintFormBranding _appBranding(AppConfig config) {
  return PrintFormBranding(
    name: config.appName,
    kind: PrintFormBrandingKind.app,
    logoUrl: config.appLogoUrl,
    contacts: <String>[
      if (_hasText(config.appAdministratorName))
        'Administrator: ${config.appAdministratorName!.trim()}',
      if (_hasText(config.appAdministratorEmail))
        'Email: ${config.appAdministratorEmail!.trim()}',
      if (_hasText(config.appAdministratorPhone))
        'Phone: ${config.appAdministratorPhone!.trim()}',
    ],
    details: <String>[
      if (_hasText(config.appSupportUrl))
        'Support: ${config.appSupportUrl!.trim()}',
      'Environment: ${config.environment.configValue}',
    ],
  );
}

PrintFormBranding? _facilityBranding({
  required FacilitySetupSnapshot? setup,
  required AuthSession? session,
}) {
  final FacilityProfile? facility = setup?.facility;
  final AuthUserProfile? user = session?.user;
  final String? facilityName = _firstText(<String?>[
    facility?.name,
    user?.facilityName,
  ]);
  if (facilityName == null) {
    return null;
  }

  final FacilityContactAddress contactAddress =
      setup?.contactAddress ?? const FacilityContactAddress();
  final String? tenantName = _firstText(<String?>[
    setup?.tenant?.name,
    user?.tenantName,
  ]);
  final String? facilityType = _firstText(<String?>[
    facility?.type.apiValue,
    user?.facilityType,
  ]);

  return PrintFormBranding(
    name: facilityName,
    kind: PrintFormBrandingKind.facility,
    logoUrl: facility?.logoUrl,
    contacts: <String>[
      if (_hasText(contactAddress.phone)) 'Phone: ${contactAddress.phone}',
      if (_hasText(contactAddress.email)) 'Email: ${contactAddress.email}',
    ],
    addressLines: <String>[
      if (_hasText(contactAddress.addressLine1))
        contactAddress.addressLine1!.trim(),
      _join(<String?>[contactAddress.city, contactAddress.country]),
    ],
    details: <String>[
      if (_hasText(facilityType)) 'Type: ${_displayToken(facilityType!)}',
      if (_hasText(tenantName)) 'Tenant: ${tenantName!.trim()}',
    ],
    isSubscribed: _hasFacilitySubscription(session),
  );
}

FacilitySetupSnapshot? _setupSnapshot(
  AsyncValue<Result<FacilitySetupSnapshot>> value,
) {
  return switch (value) {
    AsyncData<Result<FacilitySetupSnapshot>>(:final value) => value.when(
      success: (FacilitySetupSnapshot snapshot) => snapshot,
      failure: (_) => null,
    ),
    _ => null,
  };
}

bool _hasFacilitySubscription(AuthSession? session) {
  final Map<String, AppModuleEntitlement> entitlements =
      session?.moduleEntitlements ?? const <String, AppModuleEntitlement>{};
  if (entitlements.isEmpty) {
    return true;
  }

  return entitlements.values.any(
    (AppModuleEntitlement entitlement) => entitlement.isAvailable,
  );
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String? _firstText(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return null;
}

String _join(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(', ');
}

String _displayToken(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

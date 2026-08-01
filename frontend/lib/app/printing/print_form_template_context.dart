import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/platform/app_print.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/utils/app_media_url.dart';
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

/// Builds the same HTML document that [printFormTemplateDocument] prints.
///
/// Prefer the ready branding provider when available; falls back to the sync
/// snapshot so print previews never block forever.
String buildPrintFormTemplateHtml({
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
  PrintFormTemplateContext? templateContext,
  PrintFormBrandingOptions brandingOptions = PrintFormBrandingOptions.all,
}) {
  final PrintFormTemplateContext branding =
      templateContext ?? ref.read(printFormTemplateContextProvider);
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

  return PrintFormTemplate.build(
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
    printedOnLabel: l10n.printFormPrintedOnLabel,
    printedAtLabel: l10n.printFormPrintedAtLabel,
    footerNote: footerNote,
    appBranding: branding.appBranding,
    facilityBranding: branding.facilityBranding,
    brandingOptions: brandingOptions,
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
  PrintFormBrandingOptions brandingOptions = PrintFormBrandingOptions.all,
}) async {
  // Prefer branded facility context, but never hang Print/Copy busy forever.
  PrintFormTemplateContext templateContext;
  try {
    templateContext = await ref
        .read(printFormTemplateContextReadyProvider.future)
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    templateContext = ref.read(printFormTemplateContextProvider);
  }
  if (!context.mounted) {
    return;
  }

  printHtmlDocument(
    buildPrintFormTemplateHtml(
      ref: ref,
      context: context,
      title: title,
      subtitle: subtitle,
      bodyHtml: bodyHtml,
      pages: pages,
      metadata: metadata,
      patientContext: patientContext,
      contextReference: contextReference,
      signatures: signatures,
      includeSignatures: includeSignatures,
      verifiedByName: verifiedByName,
      printedAt: printedAt,
      footerNote: footerNote,
      templateContext: templateContext,
      brandingOptions: brandingOptions,
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
    facilityBranding: buildFacilityPrintBranding(
      setup: setup,
      session: session,
      apiBaseUrl: config.apiBaseUrl,
    ),
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
        facilityBranding: buildFacilityPrintBranding(
          setup: setup,
          session: session,
          apiBaseUrl: config.apiBaseUrl,
        ),
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

@visibleForTesting
PrintFormBranding? buildFacilityPrintBranding({
  required FacilitySetupSnapshot? setup,
  required AuthSession? session,
  required Uri apiBaseUrl,
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
  final String? phone = _firstText(<String?>[
    contactAddress.phone,
    facility?.phone,
  ]);
  final String? email = _firstText(<String?>[
    contactAddress.email,
    facility?.email,
  ]);
  final String fullAddress = _join(<String?>[
    _firstText(<String?>[contactAddress.addressLine1, facility?.addressLine1]),
    _firstText(<String?>[contactAddress.city, facility?.city]),
    _firstText(<String?>[contactAddress.country, facility?.country]),
  ]);
  final List<String> addressLines = fullAddress.isEmpty
      ? const <String>[]
      : <String>[fullAddress];

  return PrintFormBranding(
    name: facilityName,
    kind: PrintFormBrandingKind.facility,
    logoUrl: resolveAppMediaUrl(facility?.logoUrl, apiBaseUrl),
    contacts: <String>[
      if (phone != null) 'Phone: $phone',
      if (email != null) 'Email: $email',
    ],
    addressLines: addressLines,
    details: <String>[
      if (facility != null) 'Type: ${_facilityTypeLabel(facility.type)}',
      if (_hasText(facility?.displayId))
        'Facility ID: ${facility!.displayId!.trim()}',
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

String _facilityTypeLabel(FacilitySetupType type) {
  return switch (type) {
    FacilitySetupType.hospital => 'Hospital',
    FacilitySetupType.clinic => 'Clinic',
    FacilitySetupType.lab => 'Laboratory',
    FacilitySetupType.pharmacy => 'Pharmacy',
    FacilitySetupType.other => 'Other',
  };
}

import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/printing/print_form_template.dart';
import 'package:hosspi_hms/shared/reporting/report_section_selection.dart';

/// Selectable facility/app header fields for sectioned print dialogs.
enum PrintFacilitySection {
  /// Facility or app name and logo.
  brand,

  /// Address / location line.
  address,

  /// Phone contact.
  phone,

  /// Email contact.
  email,

  /// Facility type (hospital, clinic, etc.).
  facilityType,

  /// Facility display ID.
  facilityId,
}

/// Builds [PrintFormBrandingOptions] from selected [PrintFacilitySection] IDs.
PrintFormBrandingOptions brandingOptionsFromFacilitySections(
  Set<Object> selected,
) {
  return PrintFormBrandingOptions(
    includeBrand: selected.contains(PrintFacilitySection.brand),
    includeAddress: selected.contains(PrintFacilitySection.address),
    includePhone: selected.contains(PrintFacilitySection.phone),
    includeEmail: selected.contains(PrintFacilitySection.email),
    includeFacilityType: selected.contains(PrintFacilitySection.facilityType),
    includeFacilityId: selected.contains(PrintFacilitySection.facilityId),
  );
}

/// Effective branding used for print headers (facility when available).
PrintFormBranding effectivePrintBranding({
  required PrintFormBranding appBranding,
  PrintFormBranding? facilityBranding,
}) {
  return facilityBranding?.canBrandDocument == true
      ? facilityBranding!
      : appBranding;
}

/// Section picker rows for facility/app header fields that have data.
List<ReportSectionAvailability> buildFacilityPrintSectionAvailabilities(
  PrintFormBranding branding,
) {
  final bool hasBrand = branding.canBrandDocument;
  final bool hasAddress = branding.addressLines.any(
    (String line) => line.trim().isNotEmpty,
  );
  final bool hasPhone = branding.contacts.any(_isPhoneContact);
  final bool hasEmail = branding.contacts.any(_isEmailContact);
  final bool hasType = branding.details.any(_isFacilityTypeDetail);
  final bool hasFacilityId = branding.details.any(_isFacilityIdDetail);

  return <ReportSectionAvailability>[
    ReportSectionAvailability(
      id: PrintFacilitySection.brand,
      count: hasBrand ? 1 : 0,
      alwaysAvailable: hasBrand,
    ),
    ReportSectionAvailability(
      id: PrintFacilitySection.address,
      count: hasAddress ? 1 : 0,
    ),
    ReportSectionAvailability(
      id: PrintFacilitySection.phone,
      count: hasPhone ? 1 : 0,
    ),
    ReportSectionAvailability(
      id: PrintFacilitySection.email,
      count: hasEmail ? 1 : 0,
    ),
    ReportSectionAvailability(
      id: PrintFacilitySection.facilityType,
      count: hasType ? 1 : 0,
    ),
    ReportSectionAvailability(
      id: PrintFacilitySection.facilityId,
      count: hasFacilityId ? 1 : 0,
    ),
  ];
}

String printFacilitySectionLabel(
  AppLocalizations l10n,
  PrintFacilitySection section,
) {
  return switch (section) {
    PrintFacilitySection.brand => l10n.printFacilityBrandSectionLabel,
    PrintFacilitySection.address => l10n.printFacilityAddressSectionLabel,
    PrintFacilitySection.phone => l10n.printFacilityPhoneSectionLabel,
    PrintFacilitySection.email => l10n.printFacilityEmailSectionLabel,
    PrintFacilitySection.facilityType => l10n.printFacilityTypeSectionLabel,
    PrintFacilitySection.facilityId => l10n.printFacilityIdSectionLabel,
  };
}

IconData printFacilitySectionIcon(PrintFacilitySection section) {
  return switch (section) {
    PrintFacilitySection.brand => Icons.apartment_outlined,
    PrintFacilitySection.address => Icons.location_on_outlined,
    PrintFacilitySection.phone => Icons.phone_outlined,
    PrintFacilitySection.email => Icons.email_outlined,
    PrintFacilitySection.facilityType => Icons.category_outlined,
    PrintFacilitySection.facilityId => Icons.badge_outlined,
  };
}

bool _isPhoneContact(String value) {
  final String lower = value.trim().toLowerCase();
  return lower.startsWith('phone:');
}

bool _isEmailContact(String value) {
  final String lower = value.trim().toLowerCase();
  return lower.startsWith('email:');
}

bool _isFacilityTypeDetail(String value) {
  final String lower = value.trim().toLowerCase();
  return lower.startsWith('type:');
}

bool _isFacilityIdDetail(String value) {
  final String lower = value.trim().toLowerCase();
  return lower.startsWith('facility id:');
}

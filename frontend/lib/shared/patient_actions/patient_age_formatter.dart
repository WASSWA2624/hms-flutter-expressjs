import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Human-readable patient age with localized units.
String formatPatientAge(AppLocalizations l10n, DateTime? dateOfBirth) {
  if (dateOfBirth == null) {
    return l10n.profileUnknownValue;
  }

  final DateTime today = DateTime.now();
  var years = today.year - dateOfBirth.year;
  var months = today.month - dateOfBirth.month;
  var days = today.day - dateOfBirth.day;

  if (days < 0) {
    months -= 1;
    final DateTime previousMonth = DateTime(today.year, today.month, 0);
    days += previousMonth.day;
  }
  if (months < 0) {
    years -= 1;
    months += 12;
  }

  if (years > 0) {
    if (months > 0) {
      return l10n.patientsAgeYearsMonths(years, months);
    }
    return l10n.patientsAgeYears(years);
  }
  if (months > 0) {
    return l10n.patientsAgeMonths(months);
  }

  final int resolvedDays = today.difference(dateOfBirth).inDays.clamp(0, 30);
  return l10n.patientsAgeDays(resolvedDays);
}

IconData? patientGenderIcon(String? gender) {
  return switch (gender?.toUpperCase()) {
    'MALE' => Icons.male,
    'FEMALE' => Icons.female,
    _ => null,
  };
}

#!/usr/bin/env node
/**
 * Generates Flutter arb entries and hr_reference_localizations.dart
 * from backend HR reference catalog definitions.
 */
const fs = require('fs');
const path = require('path');

require('module-alias/register');
const moduleAlias = require('module-alias');
const srcRoot = path.join(__dirname, '..', 'src');
moduleAlias.addAliases({
  '@lib': path.join(srcRoot, 'lib'),
  '@config': path.join(srcRoot, 'config'),
});

const rd = require('../src/lib/hr/reference-data');
const { translate } = require('../src/lib/i18n');

const frontendRoot = path.join(__dirname, '..', '..', 'frontend');
const arbPath = path.join(frontendRoot, 'lib', 'l10n', 'app_en.arb');
const dartPath = path.join(
  frontendRoot,
  'lib',
  'features',
  'hr',
  'presentation',
  'hr_reference_localizations.dart'
);

const toArbKey = (labelKey) => {
  const prefix = 'labels.hr.reference.';
  const parts = labelKey.startsWith(prefix)
    ? labelKey.slice(prefix.length).split('.')
    : labelKey.split('.');
  return `hrReference${parts
    .map((part) =>
      part
        .split('_')
        .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
        .join('')
    )
    .join('')}`;
};

const entries = [];
for (const item of rd.STAFF_POSITION_CATALOG) {
  entries.push({
    labelKey: item.labelKey,
    arbKey: toArbKey(item.labelKey),
    value: translate(item.labelKey, 'en', item.defaultName),
  });
}
for (const item of rd.PRACTITIONER_TYPE_CATALOG) {
  entries.push({
    labelKey: item.labelKey,
    arbKey: toArbKey(item.labelKey),
    value: translate(item.labelKey, 'en', item.code),
  });
}
for (const item of rd.COMPENSATION_PAY_TYPE_CATALOG) {
  entries.push({
    labelKey: item.labelKey,
    arbKey: toArbKey(item.labelKey),
    value: translate(item.labelKey, 'en', item.code),
  });
}

const arb = JSON.parse(fs.readFileSync(arbPath, 'utf8'));
let added = 0;
for (const entry of entries) {
  if (!arb[entry.arbKey]) {
    arb[entry.arbKey] = entry.value;
    arb[`@${entry.arbKey}`] = {
      description: `Localized label for ${entry.labelKey}.`,
    };
    added += 1;
  }
}
fs.writeFileSync(arbPath, `${JSON.stringify(arb, null, 2)}\n`);

const switchLines = entries
  .map((entry) => `    '${entry.labelKey}' => ${entry.arbKey},`)
  .join('\n');

const practitionerSwitch = rd.PRACTITIONER_TYPE_CATALOG.map(
  (entry) =>
    `    '${entry.code}' => ${toArbKey(entry.labelKey)},`
).join('\n');

const payTypeSwitch = rd.COMPENSATION_PAY_TYPE_CATALOG.map(
  (entry) =>
    `    '${entry.code}' => ${toArbKey(entry.labelKey)},`
).join('\n');

const staffPositionNameSwitch = rd.STAFF_POSITION_CATALOG.map(
  (entry) =>
    `    '${entry.defaultName.toLowerCase()}' => ${toArbKey(entry.labelKey)},`
).join('\n');

const consultationFeeTypes = [...rd.CONSULTATION_FEE_PRACTITIONER_TYPES]
  .map((value) => `      '${value}',`)
  .join('\n');

const dart = `import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Resolves backend HR reference label keys to localized UI strings.
extension HrReferenceLocalizations on AppLocalizations {
  String hrLocalizedOptionLabel(HrOption option) {
    final String? labelKey = option.labelKey?.trim();
    if (labelKey != null && labelKey.isNotEmpty) {
      return hrReferenceLabel(labelKey, fallback: option.label);
    }
    return option.label;
  }

  String hrReferenceLabel(String? labelKey, {String? fallback}) {
    final String key = labelKey?.trim() ?? '';
    if (key.isEmpty) {
      return fallback ?? '';
    }
    return switch (key) {
${switchLines}
      _ => fallback ?? key,
    };
  }

  String hrReferencePractitionerTypeLabel(String? code, {String? fallback}) {
    final String normalized = (code ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return fallback ?? '';
    }
    return switch (normalized) {
${practitionerSwitch}
      _ => fallback ?? normalized,
    };
  }

  String hrReferenceCompensationPayTypeLabel(String? code, {String? fallback}) {
    final String normalized = (code ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return fallback ?? '';
    }
    return switch (normalized) {
${payTypeSwitch}
      _ => fallback ?? normalized,
    };
  }

  String hrReferenceStaffPositionLabel(String? name, {String? fallback}) {
    final String normalized = (name ?? '').trim();
    if (normalized.isEmpty) {
      return fallback ?? '';
    }
    return switch (normalized.toLowerCase()) {
${staffPositionNameSwitch}
      _ => fallback ?? normalized,
    };
  }

  bool isConsultationFeePractitionerType(String? code) {
    return <String>{
${consultationFeeTypes}
    }.contains((code ?? '').trim().toUpperCase());
  }
}
`;

fs.writeFileSync(dartPath, dart);
console.log(`Added ${added} arb keys and regenerated ${path.basename(dartPath)}`);

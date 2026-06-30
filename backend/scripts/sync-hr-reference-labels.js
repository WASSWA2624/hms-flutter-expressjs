#!/usr/bin/env node
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

const practitionerDefaults = {
  MO: 'Medical Officer (MO)',
  SPECIALIST: 'Specialist / Consultant',
  RESIDENT: 'Resident / Registrar',
  INTERN: 'Intern / House Officer',
  GP: 'General Practitioner (GP)',
  SURGEON: 'Surgeon',
  ANAESTHETIST: 'Anaesthetist',
  PAEDIATRICIAN: 'Paediatrician',
  OBGYN: 'Obstetrician/Gynaecologist',
  NURSE_PRACTITIONER: 'Nurse Practitioner',
  DENTIST: 'Dentist',
  PSYCHIATRIST: 'Psychiatrist',
  EMERGENCY_MEDICINE: 'Emergency Medicine Physician',
  FAMILY_MEDICINE: 'Family Medicine Physician',
  PATHOLOGIST: 'Pathologist',
  RADIOLOGIST: 'Radiologist',
  DERMATOLOGIST: 'Dermatologist',
  CARDIOLOGIST: 'Cardiologist',
  OPHTHALMOLOGIST: 'Ophthalmologist',
  ORTHOPAEDIC_SURGEON: 'Orthopaedic Surgeon',
};

const payDefaults = {
  PER_CONSULTATION: 'Consultation fee',
  PER_MONTH: 'Monthly salary',
  PER_DAY: 'Daily wage',
  PER_HOUR: 'Hourly rate',
  PER_PROCEDURE: 'Per procedure / per task',
};

const filePath = path.join(srcRoot, 'locales', 'en.json');
const locale = JSON.parse(fs.readFileSync(filePath, 'utf8'));
let added = 0;

for (const entry of rd.STAFF_POSITION_CATALOG) {
  if (!locale[entry.labelKey]) {
    locale[entry.labelKey] = entry.defaultName;
    added += 1;
  }
}
for (const entry of rd.PRACTITIONER_TYPE_CATALOG) {
  if (!locale[entry.labelKey]) {
    locale[entry.labelKey] = practitionerDefaults[entry.code] || entry.code;
    added += 1;
  }
}
for (const entry of rd.COMPENSATION_PAY_TYPE_CATALOG) {
  if (!locale[entry.labelKey]) {
    locale[entry.labelKey] = payDefaults[entry.code] || entry.code;
    added += 1;
  }
}

const sorted = Object.fromEntries(
  Object.keys(locale)
    .sort()
    .map((key) => [key, locale[key]])
);
fs.writeFileSync(filePath, `${JSON.stringify(sorted, null, 2)}\n`);
console.log(`Synced ${added} HR reference label keys into en.json`);

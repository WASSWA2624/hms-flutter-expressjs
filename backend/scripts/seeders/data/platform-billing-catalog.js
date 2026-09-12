/**
 * Platform currency and consultation-type presets.
 *
 * Both domains previously had no table at all: currency was a bare VarChar
 * column plus a `DEFAULT_TENANT_CURRENCY` constant, and the consultation fee
 * lived in `tenant.extension_json.billing.standard_consultation_fee`. These are
 * the first catalogs for either, so unlike the clinical packs there is no prior
 * source file to draw from.
 *
 * Currencies are ISO 4217. The list is East Africa plus the majors a Ugandan
 * facility realistically bills or reports in — deliberately short rather than
 * the full ISO table, since every entry is something a tenant has to scroll
 * past. Adding one is a platform-admin action.
 *
 * Consultation types are the encounter kinds the billing layer already
 * recognises under its `CONSULTATION` catalog type. Durations are defaults a
 * facility overrides on its own offering.
 *
 * @module scripts/seeders/data/platform-billing-catalog
 */

/** @type {{key: string, code: string, name: string, symbol: string, decimal_places: number}[]} */
const CURRENCY_CATALOG = Object.freeze([
  { key: 'ugx', code: 'UGX', name: 'Ugandan Shilling', symbol: 'USh', decimal_places: 0 },
  { key: 'kes', code: 'KES', name: 'Kenyan Shilling', symbol: 'KSh', decimal_places: 2 },
  { key: 'tzs', code: 'TZS', name: 'Tanzanian Shilling', symbol: 'TSh', decimal_places: 2 },
  { key: 'rwf', code: 'RWF', name: 'Rwandan Franc', symbol: 'FRw', decimal_places: 0 },
  { key: 'ssp', code: 'SSP', name: 'South Sudanese Pound', symbol: '£', decimal_places: 2 },
  { key: 'usd', code: 'USD', name: 'United States Dollar', symbol: '$', decimal_places: 2 },
  { key: 'eur', code: 'EUR', name: 'Euro', symbol: '€', decimal_places: 2 },
  { key: 'gbp', code: 'GBP', name: 'Pound Sterling', symbol: '£', decimal_places: 2 },
]);

/** The currency a tenant gets by default, matching DEFAULT_TENANT_CURRENCY. */
const DEFAULT_CURRENCY_CODE = 'UGX';

/** @type {{key: string, name: string, code: string, category: string, description: string, default_duration_minutes: number}[]} */
const CONSULTATION_TYPE_CATALOG = Object.freeze([
  {
    key: 'general_outpatient',
    name: 'General Outpatient Consultation',
    code: 'CONS-OPD',
    category: 'Outpatient',
    description: 'First-contact consultation with a general practitioner.',
    default_duration_minutes: 15,
  },
  {
    key: 'specialist_outpatient',
    name: 'Specialist Consultation',
    code: 'CONS-SPEC',
    category: 'Outpatient',
    description: 'Consultation with a specialist, usually on referral.',
    default_duration_minutes: 30,
  },
  {
    key: 'follow_up',
    name: 'Follow-up Consultation',
    code: 'CONS-FU',
    category: 'Outpatient',
    description: 'Review of a previously seen condition.',
    default_duration_minutes: 10,
  },
  {
    key: 'emergency',
    name: 'Emergency Consultation',
    code: 'CONS-EMG',
    category: 'Emergency',
    description: 'Unscheduled consultation in the emergency department.',
    default_duration_minutes: 20,
  },
  {
    key: 'antenatal',
    name: 'Antenatal Consultation',
    code: 'CONS-ANC',
    category: 'Maternity',
    description: 'Scheduled antenatal review.',
    default_duration_minutes: 20,
  },
  {
    key: 'paediatric',
    name: 'Paediatric Consultation',
    code: 'CONS-PAED',
    category: 'Paediatrics',
    description: 'Consultation for a patient under the paediatric threshold.',
    default_duration_minutes: 20,
  },
  {
    key: 'dental',
    name: 'Dental Consultation',
    code: 'CONS-DENT',
    category: 'Dental',
    description: 'Dental assessment and treatment planning.',
    default_duration_minutes: 30,
  },
  {
    key: 'telemedicine',
    name: 'Telemedicine Consultation',
    code: 'CONS-TELE',
    category: 'Remote',
    description: 'Consultation conducted remotely by voice or video.',
    default_duration_minutes: 15,
  },
  {
    key: 'inpatient_review',
    name: 'Inpatient Review',
    code: 'CONS-IPD',
    category: 'Inpatient',
    description: 'Ward round review of an admitted patient.',
    default_duration_minutes: 10,
  },
  {
    key: 'pre_operative',
    name: 'Pre-operative Assessment',
    code: 'CONS-PREOP',
    category: 'Theatre',
    description: 'Fitness assessment ahead of a planned procedure.',
    default_duration_minutes: 30,
  },
]);

module.exports = {
  CURRENCY_CATALOG,
  CONSULTATION_TYPE_CATALOG,
  DEFAULT_CURRENCY_CODE,
};

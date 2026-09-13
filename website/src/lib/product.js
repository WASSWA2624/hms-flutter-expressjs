/**
 * HOSSPI HMS Product Content
 *
 * Single source of truth for the marketing pages and the public documentation.
 *
 * Audience rule: this content is written for hospital decision-makers and staff.
 * Internal engineering detail — repository file names, module keys, permission
 * keys, release-gating mechanics, seeding rules — must never appear here.
 *
 * Accuracy rule: only capabilities that are reachable by users in the current
 * release may be described as available. Anything else belongs in ROADMAP and is
 * described as upcoming, never as shipped.
 *
 * @file src/lib/product.js
 */

export const HMS_NAME = 'HOSSPI Hospital Management System';
export const HMS_SHORT_NAME = 'HOSSPI HMS';

export const HMS_TAGLINE = 'Run the whole hospital from one system';

export const HMS_SUMMARY =
  'From the moment a patient walks in to the moment the invoice is settled, HOSSPI keeps reception, the consulting room, the ward, the laboratory, the pharmacy and the finance office working from the same record.';

export const HMS_INTRO =
  'HOSSPI is a complete hospital management system for clinics, hospitals and hospital groups. It replaces the paper files, spreadsheets and disconnected tools that slow your staff down, and gives every department one shared, accurate view of each patient.';

/** Platforms the application ships on. */
export const PLATFORMS = [
  { id: 'web', name: 'Web', detail: 'Any modern browser', icon: 'globe' },
  { id: 'android', name: 'Android', detail: 'Phones and tablets', icon: 'smartphone' },
  { id: 'ios', name: 'iOS', detail: 'iPhone and iPad', icon: 'tablet' },
  { id: 'desktop', name: 'Desktop', detail: 'Windows and macOS', icon: 'monitor' },
  { id: 'linux', name: 'Linux', detail: 'Native desktop app', icon: 'terminal' },
];

/** Headline value propositions. */
export const VALUE_PROPS = [
  {
    id: 'end-to-end-care',
    icon: 'clipboard',
    title: 'One record, front door to discharge',
    body: 'Registration, emergency, outpatient clinics, consultations, nursing, wards, intensive care, theatre and discharge all write to the same patient record. Nothing is re-typed between departments.',
  },
  {
    id: 'diagnostics',
    icon: 'flask',
    title: 'Diagnostics without the paper chase',
    body: 'Clinicians order laboratory tests and scans from the consultation they are already in. Results, reports and dispensed medicines come straight back to the same chart.',
  },
  {
    id: 'finance',
    icon: 'receipt',
    title: 'Money that reconciles itself',
    body: 'A cashier desk for invoices and collections, proper books behind it with journals, ledgers and period close, and insurance claims handled in the same place.',
  },
  {
    id: 'access-control',
    icon: 'shield',
    title: 'Everyone sees exactly what they should',
    body: 'Each member of staff gets the workspace their job needs and nothing more. You decide who can view, edit and approve, down to the individual action.',
  },
  {
    id: 'multi-facility',
    icon: 'building',
    title: 'Built for groups, not just one clinic',
    body: 'Run several facilities under one organisation, each with its own staff, books and reporting, while head office keeps a consolidated view.',
  },
  {
    id: 'reporting',
    icon: 'chart',
    title: 'Reports you can trust',
    body: 'Reporting reads directly from live records rather than a separate copy, so the numbers you present are the numbers your staff entered.',
  },
];

/**
 * Capability areas available to users in the current release.
 * @type {Array<{id: string, title: string, description: string, items: string[]}>}
 */
export const AVAILABLE_MODULES = [
  {
    id: 'patient-intake',
    icon: 'userPlus',
    title: 'Patient intake',
    description: 'Every way a patient reaches you, opening one shared record.',
    items: ['Reception', 'Patient registry', 'Outpatient (OPD)', 'Emergency'],
  },
  {
    id: 'inpatient-care',
    icon: 'bed',
    title: 'Inpatient care',
    description: 'Admission through to the daily running of the wards.',
    items: ['Inpatient (IPD)', 'Rooms and beds', 'Intensive care (ICU)', 'Nursing'],
  },
  {
    id: 'clinical-care',
    icon: 'stethoscope',
    title: 'Clinical care',
    description: 'The consulting room, the theatre list and the way out.',
    items: ['Clinical (doctors)', 'Physiotherapy', 'Operating theatre', 'Discharge planning'],
  },
  {
    id: 'diagnostics',
    icon: 'flask',
    title: 'Diagnostics and pharmacy',
    description: 'Investigations and medicines, ordered from the encounter itself.',
    items: ['Laboratory', 'Radiology', 'Pharmacy'],
  },
  {
    id: 'billing-revenue',
    icon: 'wallet',
    title: 'Billing and revenue',
    description: 'The cashier desk, the books behind it, and what insurers owe you.',
    items: ['Billing', 'Accounts', 'Insurance claims', 'Subscription plans'],
  },
  {
    id: 'facility-services',
    icon: 'building',
    title: 'Facility services',
    description: 'The work that keeps the building and its equipment running.',
    items: ['Operations', 'Housekeeping', 'Biomedical engineering', 'Mortuary'],
  },
  {
    id: 'administration',
    icon: 'settings',
    title: 'Administration',
    description: 'The controls that keep the organisation and its people in order.',
    items: [
      'Human resources',
      'Communications',
      'Integrations',
      'Reporting and analytics',
      'Settings, roles and permissions',
      'Tenant and facility setup',
    ],
  },
];

/**
 * Capabilities coming in future releases. Never described as available.
 * @type {Array<{id: string, title: string}>}
 */
export const ROADMAP = [
  { id: 'dental', title: 'Dental' },
  { id: 'inventory', title: 'Hospital-wide inventory and procurement' },
  { id: 'analytics', title: 'Advanced analytics' },
  { id: 'compliance', title: 'Compliance and audit pack' },
];

/**
 * Subscription packages, described by what the customer can do.
 * @type {Array<{id: string, name: string, summary: string, includes: string[], highlight?: boolean}>}
 */
export const PLANS = [
  {
    id: 'free',
    name: 'Free',
    summary: 'Register patients and get started at no cost.',
    includes: ['Patient registry and consent', 'Staff sign-in, roles and permissions'],
  },
  {
    id: 'basic',
    name: 'Basic',
    summary: 'Everything a busy outpatient clinic needs.',
    includes: [
      'Everything in Free',
      'Outpatient clinics and queues',
      'Consultations and vitals',
      'Inpatient wards and beds',
      'Pharmacy dispensing',
      'Billing, payments and accounts',
      'Communications',
    ],
  },
  {
    id: 'advanced',
    name: 'Advanced',
    summary: 'Add diagnostics, insurance and rehabilitation.',
    highlight: true,
    includes: [
      'Everything in Basic',
      'Laboratory workflows',
      'Radiology workflows',
      'Insurance claims',
      'Physiotherapy and rehabilitation',
      'Extra storage',
    ],
  },
  {
    id: 'pro',
    name: 'Pro',
    summary: 'For hospitals running critical care, surgery and their own estate.',
    includes: [
      'Everything in Advanced',
      'Intensive care',
      'Operating theatre and anaesthesia',
      'Human resources and rosters',
      'Facilities, housekeeping and maintenance',
      'Biomedical engineering',
      'Mortuary',
      'Integrations and webhooks',
    ],
  },
  {
    id: 'custom',
    name: 'Custom',
    summary: 'Shaped around how your organisation works.',
    includes: [
      'Tailored to your facilities',
      'Agreed scope and limits',
      'Direct support arrangement',
    ],
  },
];

export const PLANS_NOTE =
  'Reporting is included with every package. Move between packages as your facility grows — your data stays where it is.';

/**
 * Roles available out of the box, described for a non-technical reader.
 * @type {Array<{id: string, name: string, scope: string}>}
 */
export const ROLES = [
  { id: 'doctor', icon: 'stethoscope', name: 'Doctors', scope: 'Consultations, ward rounds, intensive care and theatre, with laboratory, imaging and prescriptions ordered from the patient encounter.' },
  { id: 'nurse', icon: 'pulse', name: 'Nurses', scope: 'Nursing care, triage and ward duties for their assigned wards, with observations recorded against the patient record.' },
  { id: 'receptionist', icon: 'headset', name: 'Reception staff', scope: 'Registering patients, managing the outpatient queue, and viewing what a visit has been billed.' },
  { id: 'pharmacist', icon: 'pill', name: 'Pharmacists', scope: 'Dispensing, stock control and pharmacy reporting.' },
  { id: 'lab', icon: 'flask', name: 'Laboratory staff', scope: 'Specimens, test workflow and results, including walk-in requests.' },
  { id: 'imaging', icon: 'scan', name: 'Radiographers and radiologists', scope: 'Performing scans and writing the interpretations that return to the patient chart.' },
  { id: 'accountant', icon: 'receipt', name: 'Finance staff', scope: 'Invoices, collections, journals, ledgers, period close and insurance claims.' },
  { id: 'hr', icon: 'users', name: 'HR staff', scope: 'Staff administration and managing user accounts, roles and permissions for the facility.' },
  { id: 'operations', icon: 'building', name: 'Operations and housekeeping', scope: 'Facility tasks, cleaning schedules and the day-to-day running of the building.' },
  { id: 'biomed', icon: 'settings', name: 'Biomedical engineers', scope: 'Equipment registers, servicing and maintenance history across the facility.' },
  { id: 'ward-managers', icon: 'bed', name: 'Ward, ICU and theatre managers', scope: 'Running their own unit — beds, staffing and the cases in front of them.' },
  { id: 'admin', icon: 'shield', name: 'Administrators', scope: 'Facility, organisation and platform level control, each with reporting across their own scope.' },
  { id: 'patient', icon: 'user', name: 'Patients', scope: 'Their own records only.' },
];

export const ROLES_NOTE =
  'Twenty-five staff roles are ready to use on day one, and you can define your own if your facility works differently.';

/**
 * How care moves through the system — written as journeys, not workflows.
 * @type {Array<{id: string, title: string, summary: string}>}
 */
export const CARE_JOURNEYS = [
  { id: 'opd', icon: 'userPlus', title: 'Outpatient visit', summary: 'Arrival, registration, queue, triage and consultation — with orders and billing raised as the visit happens.' },
  { id: 'emergency', icon: 'pulse', title: 'Emergency arrival', summary: 'Urgent presentation triaged and treated straight away, with registration and billing catching up behind the care.' },
  { id: 'ipd', icon: 'bed', title: 'Admission and ward stay', summary: 'Admission, ward allocation, nursing observations and daily clinical review, all on one running record.' },
  { id: 'icu', icon: 'pulse', title: 'Intensive care', summary: 'Critical care admission with close monitoring and the clinical detail that level of care demands.' },
  { id: 'theater', icon: 'scissors', title: 'Surgery', summary: 'Scheduling, the procedure record, and recovery notes handed back to the ward team.' },
  { id: 'lab', icon: 'flask', title: 'Laboratory testing', summary: 'Order raised in the consultation, specimen tracked through the lab, result returned to the chart.' },
  { id: 'radiology', icon: 'scan', title: 'Imaging', summary: 'Request, scan acquisition and the radiologist’s interpretation, filed against the patient.' },
  { id: 'pharmacy', icon: 'pill', title: 'Prescribing and dispensing', summary: 'Prescription written in the encounter, dispensed at the pharmacy, stock and billing updated together.' },
  { id: 'discharge', icon: 'clipboard', title: 'Discharge', summary: 'Discharge planning, paperwork and final settlement before the patient leaves.' },
];

/** Common questions from evaluating facilities. */
export const FAQS = [
  {
    id: 'devices',
    question: 'What do we need to run HOSSPI?',
    answer: 'A browser is enough to get started. There are also native apps for Android, iOS, Windows, macOS and Linux, so staff can work on whatever hardware you already have.',
  },
  {
    id: 'trial',
    question: 'Can we try it before committing?',
    answer: 'Yes. The Free package lets you register patients and explore the system at no cost, and sample data is available so you can walk through the workflows without touching real records.',
  },
  {
    id: 'growth',
    question: 'What happens when we outgrow our package?',
    answer: 'Move up a package and the additional areas become available to your staff immediately. Your existing records stay exactly where they are.',
  },
  {
    id: 'multi-facility',
    question: 'We run more than one facility. Is that supported?',
    answer: 'Yes. Each facility keeps its own staff, books and reporting, while your head office sees the organisation as a whole.',
  },
  {
    id: 'access',
    question: 'How do we control who sees patient information?',
    answer: 'Access is granted by role and can be narrowed to individual actions. Staff only reach the areas their work requires, and activity is recorded in an audit trail.',
  },
  {
    id: 'support',
    question: 'How do we get help?',
    answer: 'Get in touch through the contact page and our team will walk you through setup, training and any questions about fitting HOSSPI to your facility.',
  },
];

/** Headline figures. */
export const KEY_FIGURES = [
  { id: 'departments', icon: 'layers', value: '26', label: 'Departments and services' },
  { id: 'roles', icon: 'users', value: '25', label: 'Staff roles ready to use' },
  { id: 'platforms', icon: 'globe', value: '5', label: 'Platforms supported' },
  { id: 'record', icon: 'clipboard', value: '1', label: 'Shared patient record' },
];

/* ------------------------------------------------------------------ *
 * Company content (About and Contact pages)
 * ------------------------------------------------------------------ */

export const COMPANY_STORY =
  'HOSSPI builds hospital software for the way healthcare is actually delivered — in facilities where staff are busy, budgets are tight, and a missing file can hold up a patient for hours. We started with one conviction: a hospital should not need five disconnected systems and a stack of paper to look after one person.';

export const COMPANY_APPROACH = [
  {
    id: 'mission',
    icon: 'target',
    title: 'Our mission',
    body: 'To give every hospital, however large or small, one dependable system for running care — so staff spend their time with patients instead of chasing paperwork.',
  },
  {
    id: 'vision',
    icon: 'eye',
    title: 'Our vision',
    body: 'A healthcare sector where a patient’s record follows them through every department and every visit, complete and accurate, wherever they are treated.',
  },
  {
    id: 'values',
    icon: 'heart',
    title: 'What we value',
    body: 'Clarity over complexity, honesty about what our software does and does not do yet, and software that behaves predictably when a ward is at its busiest.',
  },
];

export const COMPANY_PRINCIPLES = [
  {
    id: 'clinical-first',
    icon: 'stethoscope',
    title: 'Designed around clinical work',
    body: 'Screens follow the order in which care actually happens, so staff are not fighting the software during a consultation.',
  },
  {
    id: 'reliable',
    icon: 'shield',
    title: 'Careful with patient data',
    body: 'Access is granted deliberately, activity is recorded, and staff only reach the parts of the system their role requires.',
  },
  {
    id: 'reachable',
    icon: 'globe',
    title: 'Works on what you already own',
    body: 'Browser, phone, tablet or desktop — including Linux — so you are not buying hardware to run your hospital software.',
  },
  {
    id: 'partnership',
    icon: 'message',
    title: 'We stay involved after go-live',
    body: 'Setup, training and the awkward questions afterwards are part of the arrangement, not an upsell.',
  },
];

/** Ways to reach the team. Values are filled in from constants at render time. */
export const CONTACT_CHANNELS = [
  {
    id: 'email',
    icon: 'mail',
    title: 'Email us',
    description: 'For enquiries, demos and support. We reply within one working day.',
  },
  {
    id: 'phone',
    icon: 'phone',
    title: 'Call us',
    description: 'Speak to someone directly about your facility and how it runs.',
  },
  {
    id: 'whatsapp',
    icon: 'message',
    title: 'Message us',
    description: 'Quick questions on WhatsApp or Telegram, answered during working hours.',
  },
  {
    id: 'address',
    icon: 'mapPin',
    title: 'Find us',
    description: 'Our team is based in Kampala, and we work with facilities across the region.',
  },
];

export const CONTACT_INTRO =
  'Tell us about your facility — how many beds, which departments, and what you are using today — and we will show you how HOSSPI would fit. Demonstrations are free and there is no obligation.';

export const CONTACT_REASONS = [
  { id: 'demo', icon: 'monitor', label: 'Book a demonstration' },
  { id: 'pricing', icon: 'receipt', label: 'Discuss packages and pricing' },
  { id: 'migration', icon: 'layers', label: 'Move from your current system' },
  { id: 'support', icon: 'headset', label: 'Get help with an existing setup' },
];

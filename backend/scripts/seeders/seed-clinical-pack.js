const { DEMO_TENANT } = require('./seed-catalog');

const DEMO_PATIENTS = Object.freeze([
  {
    key: 'p1',
    first_name: 'Amina',
    last_name: 'Demo-Alpha',
    gender: 'FEMALE',
    date_offset_days: -11680,
    identifier: 'DMO-PAT-001',
    phone: '+15550000001',
    address_line1: '101 Demo Lane',
  },
  {
    key: 'p2',
    first_name: 'Samuel',
    last_name: 'Demo-Bravo',
    gender: 'MALE',
    date_offset_days: -20440,
    identifier: 'DMO-PAT-002',
    phone: '+15550000002',
    address_line1: '102 Demo Lane',
  },
  {
    key: 'p3',
    first_name: 'Nia',
    last_name: 'Demo-Charlie',
    gender: 'FEMALE',
    date_offset_days: -14965,
    identifier: 'DMO-PAT-003',
    phone: '+15550000003',
    address_line1: '103 Demo Lane',
  },
  {
    key: 'p4',
    first_name: 'Grace',
    last_name: 'Demo-Delta',
    gender: 'FEMALE',
    date_offset_days: -17080,
    identifier: 'DMO-PAT-004',
    phone: '+15550000004',
    address_line1: '104 Demo Lane',
  },
  {
    key: 'p5',
    first_name: 'Noah',
    last_name: 'Demo-Echo',
    gender: 'MALE',
    date_offset_days: -3410,
    identifier: 'DMO-PAT-005',
    phone: '+15550000005',
    address_line1: '105 Demo Lane',
  },
]);

const findUser = (accessPack, scenarioKey, key) => accessPack.users[`${scenarioKey}:${key}`];

const getCatalogRecord = (recordSet, scenarioKey, recordKey) =>
  recordSet?.[`${scenarioKey}:${recordKey}`] || null;

const ensureLabTest = async (ctx, scenario, facility, catalogPack, recordKey, fallback) =>
  getCatalogRecord(catalogPack?.lab?.tests, scenario.key, recordKey)
  || ctx.upsert(
    'lab_test',
    `${scenario.key}:lab-test:${recordKey}`,
    {
      tenant_id: facility.tenant_id,
      ...fallback,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'LBT',
    }
  );

const ensureRadiologyTest = async (ctx, scenario, facility, catalogPack, recordKey, fallback) =>
  getCatalogRecord(catalogPack?.radiology?.tests, scenario.key, recordKey)
  || ctx.upsert(
    'radiology_test',
    `${scenario.key}:radiology-test:${recordKey}`,
    {
      tenant_id: facility.tenant_id,
      ...fallback,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'RDT',
    }
  );

const ensureDrug = async (ctx, scenario, facility, catalogPack, recordKey, fallback) =>
  getCatalogRecord(catalogPack?.pharmacy?.drugs, scenario.key, recordKey)
  || ctx.upsert(
    'drug',
    `${scenario.key}:drug:${recordKey}`,
    {
      tenant_id: facility.tenant_id,
      ...fallback,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'DRG',
    }
  );

const createPatientRecord = async (ctx, scenario, facility, patientSpec) => {
  const patient = await ctx.upsert(
    'patient',
    `${scenario.key}:patient:${patientSpec.key}`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      first_name: patientSpec.first_name,
      last_name: patientSpec.last_name,
      date_of_birth: ctx.date(patientSpec.date_offset_days),
      gender: patientSpec.gender,
      is_active: true,
      extension_json: {
        demo_profile: true,
        fictional_identity: true,
      },
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'PAT',
    }
  );

  await ctx.upsert(
    'patient_identifier',
    `${scenario.key}:patient-identifier:${patientSpec.key}`,
    {
      tenant_id: facility.tenant_id,
      patient_id: patient.id,
      identifier_type: 'MRN',
      identifier_value: patientSpec.identifier,
      is_primary: true,
    },
    {
      publicIdPrefix: 'PID',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'address',
    `${scenario.key}:patient-address:${patientSpec.key}`,
    {
      tenant_id: facility.tenant_id,
      patient_id: patient.id,
      address_type: 'HOME',
      line1: patientSpec.address_line1,
      city: 'Kampala',
      country: 'Uganda',
    },
    {
      publicIdPrefix: 'ADDR',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'patient_contact',
    `${scenario.key}:patient-contact:${patientSpec.key}`,
    {
      tenant_id: facility.tenant_id,
      patient_id: patient.id,
      contact_type: 'PHONE',
      value: patientSpec.phone,
      is_primary: true,
    },
    {
      publicIdPrefix: 'PCT',
      seedMeta: false,
    }
  );

  return patient;
};

const seedClinicalPack = async (ctx, orgPack, accessPack, catalogPack = null) => {
  const result = {
    patients: {},
    appointments: {},
    encounters: {},
    admissions: {},
  };

  const scenario = DEMO_TENANT;
  const facility = orgPack.facilities[`${scenario.key}:${scenario.facilities[0].key}`];
  const doctor = findUser(accessPack, scenario.key, 'doctor');
  const nurse = findUser(accessPack, scenario.key, 'nurse') || doctor;
  const billing = findUser(accessPack, scenario.key, 'billing') || findUser(accessPack, scenario.key, 'tenant_admin');

  for (const patientSpec of DEMO_PATIENTS) {
    const patient = await createPatientRecord(ctx, scenario, facility, patientSpec);
    result.patients[`${scenario.key}:${patientSpec.key}`] = patient;
  }

  const outpatientPatient = result.patients[`${scenario.key}:p1`];
  const inpatientPatient = result.patients[`${scenario.key}:p2`];
  const emergencyPatient = result.patients[`${scenario.key}:p3`];
  const telemedicinePatient = result.patients[`${scenario.key}:p4`];
  const malariaPatient = result.patients[`${scenario.key}:p5`];

  const outpatientAppointment = await ctx.upsert(
    'appointment',
    `${scenario.key}:appointment:outpatient-follow-up`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: outpatientPatient.id,
      provider_user_id: doctor?.id || null,
      status: 'COMPLETED',
      scheduled_start: ctx.date(-2, 30),
      scheduled_end: ctx.date(-2, 60),
      reason: 'Persistent cough and wheeze follow-up after acute asthma treatment',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'APT',
    }
  );
  result.appointments[`${scenario.key}:outpatient-follow-up`] = outpatientAppointment;

  const outpatientEncounter = await ctx.upsert(
    'encounter',
    `${scenario.key}:encounter:outpatient-follow-up`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: outpatientPatient.id,
      provider_user_id: doctor?.id || null,
      encounter_type: 'OPD',
      status: 'CLOSED',
      started_at: ctx.date(-2, 35),
      ended_at: ctx.date(-2, 70),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ENC',
    }
  );
  result.encounters[`${scenario.key}:outpatient-follow-up`] = outpatientEncounter;

  await ctx.upsert(
    'diagnosis',
    `${scenario.key}:diagnosis:outpatient-follow-up`,
    {
      encounter_id: outpatientEncounter.id,
      diagnosis_type: 'PRIMARY',
      code: 'J45.901',
      description: 'Mild asthma exacerbation improving after bronchodilator therapy.',
    },
    {
      publicIdPrefix: 'DIA',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'vital_sign',
    `${scenario.key}:vitals:outpatient-bp`,
    {
      encounter_id: outpatientEncounter.id,
      vital_type: 'BLOOD_PRESSURE',
      value: '118/76',
      systolic_value: 118,
      diastolic_value: 76,
      map_value: 90,
      unit: 'mmHg',
      recorded_at: ctx.date(-2, 40),
    },
    {
      publicIdPrefix: 'VTL',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'vital_sign',
    `${scenario.key}:vitals:outpatient-oxygen`,
    {
      encounter_id: outpatientEncounter.id,
      vital_type: 'OXYGEN_SATURATION',
      value: '97',
      unit: '%',
      recorded_at: ctx.date(-2, 41),
    },
    {
      publicIdPrefix: 'VTL',
      seedMeta: false,
    }
  );

  const outpatientInvoice = await ctx.upsert(
    'invoice',
    `${scenario.key}:patient-invoice:outpatient`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: outpatientPatient.id,
      status: 'PAID',
      billing_status: 'PAID',
      total_amount: 85,
      currency: 'USD',
      issued_at: ctx.date(-2, 75),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'INV',
    }
  );

  await ctx.upsert(
    'invoice_item',
    `${scenario.key}:patient-invoice:item:consultation`,
    {
      invoice_id: outpatientInvoice.id,
      description: 'Outpatient consultation review',
      quantity: 1,
      unit_price: 35,
      total_price: 35,
    },
    {
      publicIdPrefix: 'IITM',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'invoice_item',
    `${scenario.key}:patient-invoice:item:nebulization`,
    {
      invoice_id: outpatientInvoice.id,
      description: 'Nebulization and inhaler counselling',
      quantity: 1,
      unit_price: 50,
      total_price: 50,
    },
    {
      publicIdPrefix: 'IITM',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'payment',
    `${scenario.key}:patient-payment:outpatient`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: outpatientPatient.id,
      invoice_id: outpatientInvoice.id,
      status: 'COMPLETED',
      method: 'CASH',
      amount: 85,
      paid_at: ctx.date(-2, 90),
      transaction_ref: `CLN-${ctx.hash(`${scenario.key}:patient-payment:outpatient`).slice(0, 10).toUpperCase()}`,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'PAY',
    }
  );

  const inpatientEncounter = await ctx.upsert(
    'encounter',
    `${scenario.key}:encounter:inpatient-pneumonia`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: inpatientPatient.id,
      provider_user_id: doctor?.id || null,
      encounter_type: 'IPD',
      status: 'OPEN',
      started_at: ctx.date(-1, 10),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ENC',
    }
  );
  result.encounters[`${scenario.key}:inpatient-pneumonia`] = inpatientEncounter;

  await ctx.upsert(
    'diagnosis',
    `${scenario.key}:diagnosis:inpatient-pneumonia`,
    {
      encounter_id: inpatientEncounter.id,
      diagnosis_type: 'PRIMARY',
      code: 'J18.9',
      description: 'Community-acquired pneumonia with hypoxemia.',
    },
    {
      publicIdPrefix: 'DIA',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'vital_sign',
    `${scenario.key}:vitals:inpatient-oxygen`,
    {
      encounter_id: inpatientEncounter.id,
      vital_type: 'OXYGEN_SATURATION',
      value: '91',
      unit: '%',
      recorded_at: ctx.date(-1, 12),
    },
    {
      publicIdPrefix: 'VTL',
      seedMeta: false,
    }
  );

  const admission = await ctx.upsert(
    'admission',
    `${scenario.key}:admission:inpatient-pneumonia`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: inpatientPatient.id,
      encounter_id: inpatientEncounter.id,
      status: 'ADMITTED',
      admitted_at: ctx.date(-1, 20),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ADM',
    }
  );
  result.admissions[scenario.key] = admission;

  await ctx.upsert(
    'bed_assignment',
    `${scenario.key}:bed-assignment:inpatient-pneumonia`,
    {
      admission_id: admission.id,
      bed_id: orgPack.beds[`${scenario.key}:general`].id,
      assigned_at: ctx.date(-1, 25),
    },
    {
      publicIdPrefix: 'BASG',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'medication_administration',
    `${scenario.key}:medication-administration:ceftriaxone`,
    {
      admission_id: admission.id,
      administered_at: ctx.date(-1, 60),
      dose: '1',
      unit: 'vial',
      route: 'IV',
    },
    {
      publicIdPrefix: 'MAR',
      seedMeta: false,
    }
  );

  const whiteBloodCellTest = await ensureLabTest(
    ctx,
    scenario,
    facility,
    catalogPack,
    'white_blood_cell_count',
    {
      name: 'White Blood Cell Count',
      code: 'WBC',
      category: 'Hematology',
      specimen_type: 'Whole blood',
      result_kind: 'NUMERIC',
      unit: 'x10^9/L',
      reference_range: 'Adult 4.0 - 11.0 x10^9/L',
    }
  );

  const crpTest = await ensureLabTest(
    ctx,
    scenario,
    facility,
    catalogPack,
    'crp',
    {
      name: 'C-Reactive Protein',
      code: 'CRP',
      category: 'Chemistry',
      specimen_type: 'Serum',
      result_kind: 'NUMERIC',
      unit: 'mg/L',
      reference_range: '< 10 mg/L',
    }
  );

  const pneumoniaLabOrder = await ctx.upsert(
    'lab_order',
    `${scenario.key}:lab-order:pneumonia`,
    {
      encounter_id: inpatientEncounter.id,
      patient_id: inpatientPatient.id,
      status: 'COMPLETED',
      ordered_at: ctx.date(-1, 45),
    },
    {
      publicIdPrefix: 'LBO',
      seedMeta: false,
    }
  );

  const pneumoniaWbcItem = await ctx.upsert(
    'lab_order_item',
    `${scenario.key}:lab-order-item:pneumonia-wbc`,
    {
      lab_order_id: pneumoniaLabOrder.id,
      lab_test_id: whiteBloodCellTest.id,
      status: 'COMPLETED',
    },
    {
      publicIdPrefix: 'LBI',
      seedMeta: false,
    }
  );

  const pneumoniaCrpItem = await ctx.upsert(
    'lab_order_item',
    `${scenario.key}:lab-order-item:pneumonia-crp`,
    {
      lab_order_id: pneumoniaLabOrder.id,
      lab_test_id: crpTest.id,
      status: 'COMPLETED',
    },
    {
      publicIdPrefix: 'LBI',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'lab_sample',
    `${scenario.key}:lab-sample:pneumonia`,
    {
      lab_order_id: pneumoniaLabOrder.id,
      status: 'RECEIVED',
      collected_at: ctx.date(-1, 55),
      received_at: ctx.date(-1, 65),
    },
    {
      publicIdPrefix: 'LBS',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'lab_result',
    `${scenario.key}:lab-result:pneumonia-wbc`,
    {
      lab_order_item_id: pneumoniaWbcItem.id,
      status: 'ABNORMAL',
      result_value: '14.8',
      result_unit: 'x10^9/L',
      result_text: 'Neutrophilic leukocytosis consistent with acute bacterial infection.',
      result_flag: 'HIGH',
      is_positive: false,
      reference_range_label: 'Adult',
      reference_range_summary: 'Adult | Unit x10^9/L | 4.0 - 11.0',
      reported_at: ctx.date(-1, 90),
    },
    {
      publicIdPrefix: 'LBR',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'lab_result',
    `${scenario.key}:lab-result:pneumonia-crp`,
    {
      lab_order_item_id: pneumoniaCrpItem.id,
      status: 'ABNORMAL',
      result_value: '78',
      result_unit: 'mg/L',
      result_text: 'Elevated inflammatory marker supporting active lower respiratory infection.',
      result_flag: 'HIGH',
      is_positive: false,
      reference_range_label: 'Adult',
      reference_range_summary: 'Adult | Unit mg/L | < 10',
      reported_at: ctx.date(-1, 92),
    },
    {
      publicIdPrefix: 'LBR',
      seedMeta: false,
    }
  );

  const chestXrayTest = await ensureRadiologyTest(
    ctx,
    scenario,
    facility,
    catalogPack,
    'xray_chest_pa',
    {
      name: 'Chest X-Ray PA View',
      code: 'XR-CHEST-PA',
      modality: 'XRAY',
    }
  );

  const radiologyOrder = await ctx.upsert(
    'radiology_order',
    `${scenario.key}:radiology-order:pneumonia`,
    {
      encounter_id: inpatientEncounter.id,
      patient_id: inpatientPatient.id,
      radiology_test_id: chestXrayTest.id,
      status: 'COMPLETED',
      ordered_at: ctx.date(-1, 70),
    },
    {
      publicIdPrefix: 'RDO',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'radiology_result',
    `${scenario.key}:radiology-result:pneumonia`,
    {
      radiology_order_id: radiologyOrder.id,
      status: 'FINAL',
      report_text: 'Patchy left lower lobe air-space opacity with mild perihilar bronchitic change. No pleural effusion.',
      reported_at: ctx.date(-1, 120),
    },
    {
      publicIdPrefix: 'RDR',
      seedMeta: false,
    }
  );

  const ceftriaxone = await ensureDrug(
    ctx,
    scenario,
    facility,
    catalogPack,
    'ceftriaxone_1g_injection',
    {
      name: 'Ceftriaxone',
      code: 'CRO1G',
      form: 'Injection',
      strength: '1 g',
    }
  );

  const pneumoniaPharmacyOrder = await ctx.upsert(
    'pharmacy_order',
    `${scenario.key}:pharmacy-order:pneumonia`,
    {
      encounter_id: inpatientEncounter.id,
      patient_id: inpatientPatient.id,
      status: 'DISPENSED',
      ordered_at: ctx.date(-1, 75),
    },
    {
      publicIdPrefix: 'PHO',
      seedMeta: false,
    }
  );

  const pneumoniaPharmacyItem = await ctx.upsert(
    'pharmacy_order_item',
    `${scenario.key}:pharmacy-order-item:pneumonia`,
    {
      pharmacy_order_id: pneumoniaPharmacyOrder.id,
      drug_id: ceftriaxone.id,
      quantity: 3,
      dosage: '1 g',
      frequency: 'BID',
      route: 'IV',
      status: 'COMPLETED',
    },
    {
      publicIdPrefix: 'PHI',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'dispense_log',
    `${scenario.key}:dispense-log:pneumonia`,
    {
      pharmacy_order_item_id: pneumoniaPharmacyItem.id,
      dispense_batch_ref: 'BATCH-CRO1G-2026',
      status: 'DISPENSED',
      dispensed_at: ctx.date(-1, 95),
      quantity_dispensed: 3,
    },
    {
      publicIdPrefix: 'DSP',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'discharge_summary',
    `${scenario.key}:discharge-summary:pneumonia`,
    {
      admission_id: admission.id,
      summary: 'Responding to oxygen and IV antibiotics. Planned step-down to oral therapy after overnight review.',
      status: 'PLANNED',
      discharged_at: null,
    },
    {
      publicIdPrefix: 'DSC',
      seedMeta: false,
    }
  );

  const emergencyEncounter = await ctx.upsert(
    'encounter',
    `${scenario.key}:encounter:emergency-asthma`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: emergencyPatient.id,
      provider_user_id: doctor?.id || null,
      encounter_type: 'EMERGENCY',
      status: 'OPEN',
      started_at: ctx.date(-1, 15),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ENC',
    }
  );
  result.encounters[`${scenario.key}:emergency-asthma`] = emergencyEncounter;

  await ctx.upsert(
    'diagnosis',
    `${scenario.key}:diagnosis:emergency-asthma`,
    {
      encounter_id: emergencyEncounter.id,
      diagnosis_type: 'PRIMARY',
      code: 'J45.902',
      description: 'Severe asthma exacerbation with acute respiratory distress.',
    },
    {
      publicIdPrefix: 'DIA',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'vital_sign',
    `${scenario.key}:vitals:emergency-oxygen`,
    {
      encounter_id: emergencyEncounter.id,
      vital_type: 'OXYGEN_SATURATION',
      value: '88',
      unit: '%',
      recorded_at: ctx.date(-1, 16),
    },
    {
      publicIdPrefix: 'VTL',
      seedMeta: false,
    }
  );

  const telemedicineEncounter = await ctx.upsert(
    'encounter',
    `${scenario.key}:encounter:telemedicine-diabetes`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: telemedicinePatient.id,
      provider_user_id: doctor?.id || null,
      encounter_type: 'TELEMEDICINE',
      status: 'CLOSED',
      started_at: ctx.date(-4, 20),
      ended_at: ctx.date(-4, 55),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ENC',
    }
  );
  result.encounters[`${scenario.key}:telemedicine-diabetes`] = telemedicineEncounter;

  await ctx.upsert(
    'diagnosis',
    `${scenario.key}:diagnosis:telemedicine-diabetes`,
    {
      encounter_id: telemedicineEncounter.id,
      diagnosis_type: 'PRIMARY',
      code: 'E11.9',
      description: 'Type 2 diabetes follow-up with stable home glucose readings.',
    },
    {
      publicIdPrefix: 'DIA',
      seedMeta: false,
    }
  );

  const malariaEncounter = await ctx.upsert(
    'encounter',
    `${scenario.key}:encounter:malaria-review`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: malariaPatient.id,
      provider_user_id: doctor?.id || null,
      encounter_type: 'OPD',
      status: 'CLOSED',
      started_at: ctx.date(-3, 25),
      ended_at: ctx.date(-3, 65),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ENC',
    }
  );
  result.encounters[`${scenario.key}:malaria-review`] = malariaEncounter;

  await ctx.upsert(
    'vital_sign',
    `${scenario.key}:vitals:malaria-temperature`,
    {
      encounter_id: malariaEncounter.id,
      vital_type: 'TEMPERATURE',
      value: '38.6',
      unit: 'C',
      recorded_at: ctx.date(-3, 30),
    },
    {
      publicIdPrefix: 'VTL',
      seedMeta: false,
    }
  );

  const malariaTest = await ensureLabTest(
    ctx,
    scenario,
    facility,
    catalogPack,
    'malaria_antigen',
    {
      name: 'Malaria Rapid Antigen',
      code: 'MALRDT',
      category: 'Microbiology',
      specimen_type: 'Whole blood',
      result_kind: 'QUALITATIVE',
      reference_range: 'Expected negative',
    }
  );

  const malariaOrder = await ctx.upsert(
    'lab_order',
    `${scenario.key}:lab-order:malaria`,
    {
      encounter_id: malariaEncounter.id,
      patient_id: malariaPatient.id,
      status: 'COMPLETED',
      ordered_at: ctx.date(-3, 35),
    },
    {
      publicIdPrefix: 'LBO',
      seedMeta: false,
    }
  );

  const malariaOrderItem = await ctx.upsert(
    'lab_order_item',
    `${scenario.key}:lab-order-item:malaria`,
    {
      lab_order_id: malariaOrder.id,
      lab_test_id: malariaTest.id,
      status: 'COMPLETED',
    },
    {
      publicIdPrefix: 'LBI',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'lab_sample',
    `${scenario.key}:lab-sample:malaria`,
    {
      lab_order_id: malariaOrder.id,
      status: 'RECEIVED',
      collected_at: ctx.date(-3, 40),
      received_at: ctx.date(-3, 45),
    },
    {
      publicIdPrefix: 'LBS',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'lab_result',
    `${scenario.key}:lab-result:malaria`,
    {
      lab_order_item_id: malariaOrderItem.id,
      status: 'ABNORMAL',
      result_value: 'POSITIVE',
      result_text: 'Malaria antigen detected. Initiate ACT and supportive care.',
      result_flag: 'POSITIVE',
      is_positive: true,
      reference_range_label: 'Expected',
      reference_range_summary: 'Expected negative',
      reported_at: ctx.date(-3, 55),
    },
    {
      publicIdPrefix: 'LBR',
      seedMeta: false,
    }
  );

  const malariaDrug = await ensureDrug(
    ctx,
    scenario,
    facility,
    catalogPack,
    'artemether_lumefantrine',
    {
      name: 'Artemether + Lumefantrine',
      code: 'AL20/120',
      form: 'Tablet',
      strength: '20/120 mg',
    }
  );

  const malariaPharmacyOrder = await ctx.upsert(
    'pharmacy_order',
    `${scenario.key}:pharmacy-order:malaria`,
    {
      encounter_id: malariaEncounter.id,
      patient_id: malariaPatient.id,
      status: 'DISPENSED',
      ordered_at: ctx.date(-3, 58),
    },
    {
      publicIdPrefix: 'PHO',
      seedMeta: false,
    }
  );

  const malariaPharmacyItem = await ctx.upsert(
    'pharmacy_order_item',
    `${scenario.key}:pharmacy-order-item:malaria`,
    {
      pharmacy_order_id: malariaPharmacyOrder.id,
      drug_id: malariaDrug.id,
      quantity: 24,
      dosage: '4 tablets',
      frequency: 'BID',
      route: 'ORAL',
      status: 'COMPLETED',
    },
    {
      publicIdPrefix: 'PHI',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'dispense_log',
    `${scenario.key}:dispense-log:malaria`,
    {
      pharmacy_order_item_id: malariaPharmacyItem.id,
      dispense_batch_ref: 'BATCH-AL-2026',
      status: 'DISPENSED',
      dispensed_at: ctx.date(-3, 65),
      quantity_dispensed: 24,
    },
    {
      publicIdPrefix: 'DSP',
      seedMeta: false,
    }
  );

  void nurse;
  void billing;

  return result;
};

module.exports = {
  seedClinicalPack,
};

const { DEMO_TENANT } = require('./seed-catalog');

/**
 * Seed a compact Mortuary dataset so the workspace has realistic storage,
 * intake, custody, release, and billing states in the demo tenant.
 *
 * @param {object} ctx
 * @param {object} orgPack
 * @param {object} accessPack
 * @param {object} clinicalPack
 * @returns {Promise<object>}
 */
const seedMortuaryPack = async (ctx, orgPack, accessPack, clinicalPack) => {
  const result = {
    deceasedProfiles: {},
    storageUnits: {},
    storageSlots: {},
    cases: {},
  };

  const scenario = DEMO_TENANT;
  const facility = orgPack.facilities[`${scenario.key}:${scenario.facilities[0].key}`];
  const patient = clinicalPack.patients[`${scenario.key}:p2`] || null;
  const admission = clinicalPack.admissions[scenario.key] || null;
  const mortuaryStaff = accessPack.users[`${scenario.key}:mortuary_staff`] || accessPack.users[`${scenario.key}:operations`];
  const mortuaryManager = accessPack.users[`${scenario.key}:mortuary_manager`] || accessPack.users[`${scenario.key}:tenant_admin`];

  const storageUnit = await ctx.upsert(
    'mortuary_storage_unit',
    `${scenario.key}:mortuary:storage-unit:cold-room-a`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      name: 'Cold Room A',
      unit_type: 'COLD_ROOM',
      status: 'ACTIVE',
      location_label: 'Mortuary wing, ground floor',
      capacity: 12,
      notes: 'Primary cold-room capacity for the demo facility.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MSU',
    }
  );
  result.storageUnits[scenario.key] = storageUnit;

  const occupiedSlot = await ctx.upsert(
    'mortuary_storage_slot',
    `${scenario.key}:mortuary:slot:a1`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      storage_unit_id: storageUnit.id,
      slot_code: 'A1',
      label: 'Rack A / Slot 1',
      status: 'OCCUPIED',
      temperature_zone: '2-4C',
      is_active: true,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MSS',
    }
  );

  const cleaningSlot = await ctx.upsert(
    'mortuary_storage_slot',
    `${scenario.key}:mortuary:slot:a2`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      storage_unit_id: storageUnit.id,
      slot_code: 'A2',
      label: 'Rack A / Slot 2',
      status: 'CLEANING',
      temperature_zone: '2-4C',
      is_active: true,
      notes: 'Held after deep-clean and maintenance review.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MSS',
    }
  );

  const availableSlot = await ctx.upsert(
    'mortuary_storage_slot',
    `${scenario.key}:mortuary:slot:b1`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      storage_unit_id: storageUnit.id,
      slot_code: 'B1',
      label: 'Rack B / Slot 1',
      status: 'AVAILABLE',
      temperature_zone: '2-4C',
      is_active: true,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MSS',
    }
  );

  result.storageSlots[`${scenario.key}:occupied`] = occupiedSlot;
  result.storageSlots[`${scenario.key}:cleaning`] = cleaningSlot;
  result.storageSlots[`${scenario.key}:available`] = availableSlot;

  const unidentifiedProfile = await ctx.upsert(
    'mortuary_deceased_profile',
    `${scenario.key}:mortuary:profile:external`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      display_name: 'Unknown Male, External Arrival',
      gender: 'MALE',
      date_of_death: ctx.date(-1, -20),
      next_of_kin_name: 'Pending identification',
      external_reference: `${scenario.tenant_code}-EXT-001`,
      identification_notes: 'Awaiting police and family confirmation.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MDP',
    }
  );

  const autopsyProfile = await ctx.upsert(
    'mortuary_deceased_profile',
    `${scenario.key}:mortuary:profile:autopsy`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      first_name: 'Grace',
      last_name: 'Demo',
      display_name: 'Grace Demo',
      gender: 'FEMALE',
      date_of_birth: ctx.date(-12000),
      date_of_death: ctx.date(-2),
      next_of_kin_name: 'Moses Demo',
      next_of_kin_phone: '+256701000222',
      next_of_kin_email: 'moses.demo@example.com',
      external_reference: `${scenario.tenant_code}-EXT-002`,
      identification_notes: 'Family identity confirmed on arrival.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MDP',
    }
  );

  result.deceasedProfiles[`${scenario.key}:external`] = unidentifiedProfile;
  result.deceasedProfiles[`${scenario.key}:autopsy`] = autopsyProfile;

  const readyCase = await ctx.upsert(
    'mortuary_case',
    `${scenario.key}:mortuary:case:ready-release`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: patient?.id || null,
      status: 'READY_FOR_RELEASE',
      identification_status: 'VERIFIED',
      source_workflow: admission ? 'INPATIENT' : 'PATIENT_REGISTRY',
      source_department: 'Inpatient',
      source_reference_id: admission?.id || patient?.id || null,
      received_from: 'Ward handover',
      received_at: ctx.date(-3),
      release_ready_at: ctx.date(-1),
      next_of_kin_name: 'Amina Demo',
      authorised_contact_name: 'Amina Demo',
      authorised_contact_phone: '+256700111222',
      billing_status: 'PENDING',
      notes: 'Prepared for family release pending payment confirmation.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MCS',
    }
  );

  const identificationPendingCase = await ctx.upsert(
    'mortuary_case',
    `${scenario.key}:mortuary:case:identification`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      deceased_profile_id: unidentifiedProfile.id,
      status: 'IDENTIFICATION_PENDING',
      identification_status: 'PARTIAL',
      source_workflow: 'EXTERNAL_ARRIVAL',
      source_department: 'Emergency',
      source_reference_id: unidentifiedProfile.id,
      received_from: 'External transfer',
      received_at: ctx.date(-1, -10),
      next_of_kin_name: 'Pending identification',
      billing_status: 'PENDING',
      notes: 'External arrival awaiting identity verification and documentation.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MCS',
    }
  );

  const postMortemCase = await ctx.upsert(
    'mortuary_case',
    `${scenario.key}:mortuary:case:post-mortem`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      deceased_profile_id: autopsyProfile.id,
      status: 'POST_MORTEM_PENDING',
      identification_status: 'VERIFIED',
      source_workflow: 'THEATRE',
      source_department: 'Theatre',
      source_reference_id: autopsyProfile.id,
      received_from: 'Theatre handover',
      received_at: ctx.date(-2, 30),
      next_of_kin_name: 'Moses Demo',
      authorised_contact_name: 'Moses Demo',
      authorised_contact_phone: '+256701000222',
      billing_status: 'OPEN',
      notes: 'Held for scheduled post-mortem review.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MCS',
    }
  );

  result.cases[`${scenario.key}:ready`] = readyCase;
  result.cases[`${scenario.key}:identification`] = identificationPendingCase;
  result.cases[`${scenario.key}:post-mortem`] = postMortemCase;

  await ctx.upsert(
    'mortuary_storage_assignment',
    `${scenario.key}:mortuary:assignment:ready-release`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      mortuary_case_id: readyCase.id,
      storage_unit_id: storageUnit.id,
      storage_slot_id: occupiedSlot.id,
      assignment_status: 'ACTIVE',
      assigned_at: ctx.date(-3, 10),
      reason: 'Immediate cold-room placement after intake.',
      notes: 'Maintained in primary cold-room until release.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MSA',
    }
  );

  await ctx.upsert(
    'mortuary_custody_event',
    `${scenario.key}:mortuary:event:intake-ready`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      mortuary_case_id: readyCase.id,
      event_type: 'RECEIVED',
      event_at: ctx.date(-3),
      actor_name: mortuaryStaff?.email || 'mortuary.staff@hosspi.com',
      actor_role: 'MORTUARY_STAFF',
      location_label: 'Mortuary reception',
      reason: 'Ward handover accepted',
      notes: 'Body received with complete inpatient paperwork.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MCE',
    }
  );

  await ctx.upsert(
    'mortuary_custody_event',
    `${scenario.key}:mortuary:event:storage-ready`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      mortuary_case_id: readyCase.id,
      event_type: 'STORAGE_ASSIGNED',
      event_at: ctx.date(-3, 10),
      actor_name: mortuaryStaff?.email || 'mortuary.staff@hosspi.com',
      actor_role: 'MORTUARY_STAFF',
      location_label: 'Cold Room A / Rack A / Slot 1',
      reason: 'Primary storage allocation',
      notes: 'Slot assignment verified and documented.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MCE',
    }
  );

  await ctx.upsert(
    'mortuary_viewing',
    `${scenario.key}:mortuary:viewing:ready-release`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      mortuary_case_id: readyCase.id,
      scheduled_at: ctx.date(0, 90),
      status: 'SCHEDULED',
      authorised_by_name: 'Amina Demo',
      attendee_summary: 'Immediate family viewing approved for two attendees.',
      notes: 'Viewing room 1 prepared with security escort.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MVI',
    }
  );

  await ctx.upsert(
    'mortuary_post_mortem_request',
    `${scenario.key}:mortuary:pm-request:pending`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      mortuary_case_id: postMortemCase.id,
      requested_by_name: 'doctor@hosspi.com',
      request_reason: 'Post-operative mortality review requested by the attending clinician.',
      status: 'SCHEDULED',
      diagnostics_reference_id: `${scenario.tenant_code}-PM-001`,
      scheduled_at: ctx.date(1, 30),
      notes: 'Diagnostics team notified for specimen handling.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MPR',
    }
  );

  await ctx.upsert(
    'mortuary_release_authorisation',
    `${scenario.key}:mortuary:release-auth:ready`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      mortuary_case_id: readyCase.id,
      recipient_name: 'Amina Demo',
      recipient_relationship: 'Spouse',
      verification_reference: `${scenario.tenant_code}-REL-001`,
      funeral_service_name: 'Graceful Rest Funeral Services',
      release_method: 'FAMILY_PICKUP',
      status: 'APPROVED',
      approved_by_name: mortuaryManager?.email || 'mortuary.manager@hosspi.com',
      approved_at: ctx.date(-1, 45),
      notes: 'Approved pending cashier confirmation for release charges.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MRA',
    }
  );

  await ctx.upsert(
    'mortuary_billable_event',
    `${scenario.key}:mortuary:billing:storage-release`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      mortuary_case_id: readyCase.id,
      event_type: 'STORAGE_AND_RELEASE',
      description: 'Three days of storage plus release preparation.',
      amount: 120,
      currency: 'USD',
      status: 'PENDING',
      billing_reference_id: `${scenario.tenant_code}-MORT-INV-001`,
      charged_at: ctx.date(-1, 40),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'MBE',
    }
  );

  return result;
};

module.exports = {
  seedMortuaryPack,
};

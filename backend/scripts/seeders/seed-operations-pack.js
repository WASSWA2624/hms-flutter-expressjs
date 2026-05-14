const { DEMO_TENANT } = require('./seed-catalog');

const seedOperationsPack = async (ctx, orgPack, accessPack) => {
  const result = {
    inventoryItems: {},
    suppliers: {},
    emergencyCases: {},
    shift: null,
  };

  const scenario = DEMO_TENANT;
  const facility = orgPack.facilities[`${scenario.key}:${scenario.facilities[0].key}`];
  const departments = Object.entries(orgPack.departments)
    .filter(([key]) => key.startsWith(`${scenario.key}:`))
    .map(([, value]) => value);
  const nurseStaff = accessPack.staffProfiles[`${scenario.key}:nurse`];
  const operationsStaff = accessPack.staffProfiles[`${scenario.key}:operations`];
  const houseKeeperStaff =
    accessPack.staffProfiles[`${scenario.key}:house_keeper`] || operationsStaff || nurseStaff;
  const ambulanceUser = accessPack.users[`${scenario.key}:ambulance`];
  const doctorUser = accessPack.users[`${scenario.key}:doctor`];
  const biomedStaff = accessPack.staffProfiles[`${scenario.key}:biomed`];

  for (const [index, staffKey] of ['doctor', 'nurse', 'biomed', 'operations', 'house_keeper'].entries()) {
    const staffProfile = accessPack.staffProfiles[`${scenario.key}:${staffKey}`];
    if (!staffProfile) continue;

    await ctx.upsert(
      'staff_position',
      `${scenario.key}:staff-position:${staffKey}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        department_id: departments[index % Math.max(1, departments.length)]?.id || null,
        name: staffProfile.position || staffKey.toUpperCase(),
        description: `${staffKey} demo position`,
        is_active: true,
      },
      {
        tenantCode: scenario.tenant_code,
        scenarioKey: scenario.scenario_key,
        publicIdPrefix: 'SPOS',
      }
    );
  }

  const roster = await ctx.upsert(
    'nurse_roster',
    `${scenario.key}:nurse-roster:week`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      department_id: orgPack.departments[`${scenario.key}:Inpatient`]?.id || null,
      period_start: ctx.date(-7),
      period_end: ctx.date(0),
      status: 'PUBLISHED',
      constraints: { minimum_rest_hours: 8, max_shifts_per_week: 5 },
      published_at: ctx.date(-8),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'NRS',
    }
  );

  const shift = await ctx.upsert(
    'shift',
    `${scenario.key}:shift:night`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      nurse_roster_id: roster.id,
      shift_type: 'NIGHT',
      status: 'SCHEDULED',
      start_time: ctx.date(0, 18 * 60),
      end_time: ctx.date(1, 6 * 60),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'SFT',
    }
  );
  result.shift = shift;

  if (nurseStaff) {
    await ctx.upsert(
      'shift_assignment',
      `${scenario.key}:shift-assignment:nurse`,
      {
        shift_id: shift.id,
        staff_profile_id: nurseStaff.id,
        assigned_at: ctx.date(-1),
      },
      {
        publicIdPrefix: 'SASG',
        seedMeta: false,
      }
    );
  }

  const item = await ctx.upsert(
    'inventory_item',
    `${scenario.key}:inventory-item:syringes`,
    {
      tenant_id: facility.tenant_id,
      name: 'Sterile Syringes 10 mL',
      category: 'SUPPLY',
      sku: `${scenario.tenant_code}-SYR-10ML`,
      unit: 'box',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'IIT',
    }
  );
  result.inventoryItems[scenario.key] = item;

  await ctx.upsert(
    'inventory_stock',
    `${scenario.key}:inventory-stock:syringes`,
    {
      inventory_item_id: item.id,
      facility_id: facility.id,
      quantity: 96,
      reorder_level: 20,
    },
    {
      publicIdPrefix: 'STK',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'stock_movement',
    `${scenario.key}:stock-movement:syringes`,
    {
      inventory_item_id: item.id,
      facility_id: facility.id,
      movement_type: 'INBOUND',
      reason: 'PURCHASE',
      quantity: 96,
      occurred_at: ctx.date(-6),
    },
    {
      publicIdPrefix: 'SMV',
      seedMeta: false,
    }
  );

  const supplier = await ctx.upsert(
    'supplier',
    `${scenario.key}:supplier:medsupply`,
    {
      tenant_id: facility.tenant_id,
      name: 'DemoCare Medical Supplies Ltd',
      contact_email: 'supplies@hms-demo.test',
      phone: '+15550110000',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'SUP',
    }
  );
  result.suppliers[scenario.key] = supplier;

  const purchaseRequest = await ctx.upsert(
    'purchase_request',
    `${scenario.key}:purchase-request:supplies`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      requested_by_user_id: doctorUser?.id || null,
      status: 'APPROVED',
      requested_at: ctx.date(-5),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'PRQ',
    }
  );

  const purchaseOrder = await ctx.upsert(
    'purchase_order',
    `${scenario.key}:purchase-order:supplies`,
    {
      purchase_request_id: purchaseRequest.id,
      supplier_id: supplier.id,
      status: 'RECEIVED',
      ordered_at: ctx.date(-4),
    },
    {
      publicIdPrefix: 'POD',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'goods_receipt',
    `${scenario.key}:goods-receipt:supplies`,
    {
      purchase_order_id: purchaseOrder.id,
      received_at: ctx.date(-3),
      status: 'VERIFIED',
    },
    {
      publicIdPrefix: 'GRN',
      seedMeta: false,
    }
  );

  const room = orgPack.rooms[`${scenario.key}:general`] || null;
  if (room && houseKeeperStaff) {
    await ctx.upsert(
      'housekeeping_task',
      `${scenario.key}:housekeeping-task:room-turnover`,
      {
        facility_id: facility.id,
        room_id: room.id,
        assigned_to_staff_id: houseKeeperStaff.id,
        status: 'COMPLETED',
        scheduled_at: ctx.date(-1, 30),
        completed_at: ctx.date(-1, 90),
      },
      {
        publicIdPrefix: 'HKT',
        seedMeta: false,
      }
    );
  }

  await ctx.upsert(
    'maintenance_request',
    `${scenario.key}:maintenance-request:oxygen-outlet`,
    {
      facility_id: facility.id,
      asset_id: null,
      status: 'OPEN',
      description: 'Ward nurse reported intermittent oxygen wall outlet pressure in bay 1.',
      reported_at: ctx.date(-1, 20),
    },
    {
      publicIdPrefix: 'MNT',
      seedMeta: false,
    }
  );

  const emergencyPatient = ctx.ref(`patient:${scenario.key}:patient:p3`);
  const emergencyCase = await ctx.upsert(
    'emergency_case',
    `${scenario.key}:emergency-case:ambulance`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      patient_id: emergencyPatient.id,
      severity: 'CRITICAL',
      status: 'OPEN',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EMR',
    }
  );
  result.emergencyCases[scenario.key] = emergencyCase;

  await ctx.upsert(
    'triage_assessment',
    `${scenario.key}:triage-assessment:ambulance`,
    {
      emergency_case_id: emergencyCase.id,
      triage_level: 'LEVEL_1',
      notes: 'Arrived with severe wheeze, accessory muscle use, and oxygen saturation below 90%.',
    },
    {
      publicIdPrefix: 'TRI',
      seedMeta: false,
    }
  );

  const ambulance = await ctx.upsert(
    'ambulance',
    `${scenario.key}:ambulance:unit-1`,
    {
      tenant_id: facility.tenant_id,
      facility_id: facility.id,
      identifier: 'AMB-UNIT-1',
      status: 'TRANSPORTING',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'AMB',
    }
  );

  await ctx.upsert(
    'ambulance_dispatch',
    `${scenario.key}:ambulance-dispatch:unit-1`,
    {
      ambulance_id: ambulance.id,
      emergency_case_id: emergencyCase.id,
      dispatched_at: ctx.date(-1, 15),
      status: 'TRANSPORTING',
    },
    {
      publicIdPrefix: 'AMD',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'ambulance_trip',
    `${scenario.key}:ambulance-trip:unit-1`,
    {
      ambulance_id: ambulance.id,
      emergency_case_id: emergencyCase.id,
      started_at: ctx.date(-1, 18),
      ended_at: ctx.date(-1, 58),
    },
    {
      publicIdPrefix: 'AMT',
      seedMeta: false,
    }
  );

  void ambulanceUser;
  void biomedStaff;

  return result;
};

module.exports = {
  seedOperationsPack,
};

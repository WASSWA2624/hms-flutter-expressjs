const { DEMO_TENANTS } = require('./seed-catalog');

const seedOrgPack = async (ctx) => {
  const result = {
    tenants: {},
    facilities: {},
    branches: {},
    departments: {},
    units: {},
    wards: {},
    rooms: {},
    beds: {},
  };

  for (const scenario of DEMO_TENANTS) {
    const tenant = await ctx.upsert(
      'tenant',
      `${scenario.key}:tenant`,
      {
        name: scenario.name,
        slug: scenario.slug,
        is_active: true,
      },
      {
        tenantCode: scenario.tenant_code,
        scenarioKey: scenario.scenario_key,
        publicIdPrefix: 'TEN',
      }
    );
    result.tenants[scenario.key] = tenant;

    for (const [facilityIndex, facilityDefinition] of scenario.facilities.entries()) {
      const facility = await ctx.upsert(
        'facility',
        `${scenario.key}:facility:${facilityDefinition.key}`,
        {
          tenant_id: tenant.id,
          name: facilityDefinition.name,
          facility_type: facilityDefinition.type,
          is_active: true,
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'FAC',
        }
      );

      result.facilities[`${scenario.key}:${facilityDefinition.key}`] = facility;

      await ctx.upsert(
        'address',
        `${scenario.key}:facility-address:${facilityDefinition.key}`,
        {
          tenant_id: tenant.id,
          facility_id: facility.id,
          address_type: 'WORK',
          line1: `${facilityIndex + 1} Demo Hospital Avenue`,
          city: 'Kampala',
          state: 'Central Region',
          postal_code: `P${facilityIndex + 100}`,
          country: 'Uganda',
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'ADDR',
          seedMeta: false,
        }
      );

      await ctx.upsert(
        'contact',
        `${scenario.key}:facility-contact:${facilityDefinition.key}`,
        {
          tenant_id: tenant.id,
          facility_id: facility.id,
          contact_type: 'PHONE',
          value: `+25670010${String(facilityIndex).padStart(2, '0')}`,
          is_primary: true,
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'CNT',
          seedMeta: false,
        }
      );
    }

    for (const branchDefinition of scenario.branches || []) {
      const facility = result.facilities[`${scenario.key}:${branchDefinition.facility_key}`];
      const branch = await ctx.upsert(
        'branch',
        `${scenario.key}:branch:${branchDefinition.key}`,
        {
          tenant_id: tenant.id,
          facility_id: facility?.id || null,
          name: branchDefinition.name,
          is_active: true,
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'BRN',
        }
      );
      result.branches[`${scenario.key}:${branchDefinition.key}`] = branch;

      await ctx.upsert(
        'address',
        `${scenario.key}:branch-address:${branchDefinition.key}`,
        {
          tenant_id: tenant.id,
          branch_id: branch.id,
          address_type: 'WORK',
          line1: `${branchDefinition.name} Road`,
          city: 'Kampala',
          country: 'Uganda',
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'ADDR',
          seedMeta: false,
        }
      );
    }

    const anchorFacility = result.facilities[`${scenario.key}:${scenario.facilities[0].key}`];
    for (const [departmentIndex, departmentName] of scenario.departments.entries()) {
      const branch = scenario.branches?.[departmentIndex % Math.max(1, scenario.branches.length)]
        ? result.branches[`${scenario.key}:${scenario.branches[departmentIndex % scenario.branches.length].key}`]
        : null;
      const department = await ctx.upsert(
        'department',
        `${scenario.key}:department:${departmentName}`,
        {
          tenant_id: tenant.id,
          facility_id: anchorFacility?.id || null,
          branch_id: branch?.id || null,
          name: departmentName,
          short_name: departmentName.slice(0, 8).toUpperCase(),
          department_type: /billing|executive|compliance|it|front office|operations|hr/i.test(departmentName)
            ? 'ADMINISTRATIVE'
            : /lab|radiology|diagnostics|research/i.test(departmentName)
              ? 'DIAGNOSTICS'
              : 'CLINICAL',
          is_active: true,
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'DEP',
        }
      );
      result.departments[`${scenario.key}:${departmentName}`] = department;

      const unit = await ctx.upsert(
        'unit',
        `${scenario.key}:unit:${departmentName}`,
        {
          tenant_id: tenant.id,
          facility_id: anchorFacility?.id || null,
          department_id: department.id,
          name: `${departmentName} Unit`,
          is_active: true,
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'UNT',
        }
      );
      result.units[`${scenario.key}:${departmentName}`] = unit;
    }

    const inpatientNeeded = scenario.seed_inpatient_resources !== false;
    if (anchorFacility && inpatientNeeded) {
      const ward = await ctx.upsert(
        'ward',
        `${scenario.key}:ward:general`,
        {
          tenant_id: tenant.id,
          facility_id: anchorFacility.id,
          department_id: result.departments[`${scenario.key}:Inpatient`]?.id || null,
          name: `${scenario.name} General Ward`,
          ward_type: 'GENERAL',
          is_active: true,
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'WRD',
        }
      );
      result.wards[`${scenario.key}:general`] = ward;

      const room = await ctx.upsert(
        'room',
        `${scenario.key}:room:general`,
        {
          tenant_id: tenant.id,
          facility_id: anchorFacility.id,
          ward_id: ward.id,
          name: `${scenario.name} Room 101`,
          floor: '1',
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'ROM',
        }
      );
      result.rooms[`${scenario.key}:general`] = room;

      const bed = await ctx.upsert(
        'bed',
        `${scenario.key}:bed:general`,
        {
          tenant_id: tenant.id,
          facility_id: anchorFacility.id,
          ward_id: ward.id,
          room_id: room.id,
          label: 'Bed A1',
          status: 'AVAILABLE',
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'BED',
        }
      );
      result.beds[`${scenario.key}:general`] = bed;
    }
  }

  return result;
};

module.exports = {
  seedOrgPack,
};

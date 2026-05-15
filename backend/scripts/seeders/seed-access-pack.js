const {
  DEMO_ROLE_CODES,
  DEMO_TENANTS,
} = require('./seed-catalog');
const { ROLE_PERMISSIONS } = require('@config/permissions');

const ROLE_PERMISSION_MAP = Object.freeze(
  Object.fromEntries(
    DEMO_ROLE_CODES.map((roleName) => [roleName, ROLE_PERMISSIONS[roleName] || []])
  )
);

const DEMO_PERMISSION_CATALOG = Object.freeze(
  Array.from(
    new Set(
      Object.values(ROLE_PERMISSION_MAP).flat().filter(Boolean)
    )
  ).sort()
);

const PROFILE_GENDER_BY_ROLE = Object.freeze({
  DOCTOR: 'MALE',
  NURSE: 'FEMALE',
  MORTUARY_STAFF: 'OTHER',
  MORTUARY_MANAGER: 'OTHER',
  PATIENT: 'OTHER',
});

const departmentForRole = (scenarioKey, role) => {
  const lookup = {
    SUPER_ADMIN: 'Operations',
    TENANT_ADMIN: 'Operations',
    FACILITY_ADMIN: 'Operations',
    LAB_TECH: 'Laboratory',
    RADIOLOGY_TECH: 'Radiology',
    PHARMACIST: 'Pharmacy',
    BILLING: 'Billing',
    BIOMED: 'Biomedical',
    HR: 'Support Services',
    OPERATIONS: 'Operations',
    AMBULANCE_OPERATOR: 'Emergency',
    RECEPTIONIST: 'Front Office',
    HOUSE_KEEPER: 'Support Services',
    HOUSEKEEPING_MANAGER: 'Support Services',
    BIOMED_MANAGER: 'Biomedical',
    MORTUARY_STAFF: 'Mortuary',
    MORTUARY_MANAGER: 'Mortuary',
  };

  if (lookup[role]) return lookup[role];
  if (role === 'UNIT_MANAGER') return 'Operations';
  if (role === 'WARD_MANAGER') return 'Inpatient';
  if (role === 'ICU_MANAGER') return 'Inpatient';
  if (role === 'THEATRE_MANAGER') return 'Outpatient';
  if (role === 'DOCTOR') return 'Outpatient';
  if (role === 'NURSE') return 'Inpatient';
  return null;
};

const seedAccessPack = async (ctx, orgPack) => {
  const result = {
    roles: {},
    permissions: {},
    users: {},
    profiles: {},
    staffProfiles: {},
  };

  for (const scenario of DEMO_TENANTS) {
    const tenant = orgPack.tenants[scenario.key];
    const anchorFacility = orgPack.facilities[`${scenario.key}:${scenario.facilities[0].key}`];

    for (const permissionName of DEMO_PERMISSION_CATALOG) {
      const permission = await ctx.upsert(
        'permission',
        `${scenario.key}:permission:${permissionName}`,
        {
          tenant_id: tenant.id,
          name: permissionName,
          description: `${permissionName} permission`,
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'PERM',
        }
      );
      result.permissions[`${scenario.key}:${permissionName}`] = permission;
    }

    for (const roleName of DEMO_ROLE_CODES) {
      const role = await ctx.upsert(
        'role',
        `${scenario.key}:role:${roleName}`,
        {
          tenant_id: tenant.id,
          facility_id: roleName === 'FACILITY_ADMIN' ? anchorFacility?.id || null : null,
          name: roleName,
          description: `${roleName} demo role`,
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'ROLE',
        }
      );
      result.roles[`${scenario.key}:${roleName}`] = role;

      for (const permissionName of ROLE_PERMISSION_MAP[roleName] || []) {
        await ctx.upsert(
          'role_permission',
          `${scenario.key}:role-permission:${roleName}:${permissionName}`,
          {
            role_id: role.id,
            permission_id: result.permissions[`${scenario.key}:${permissionName}`].id,
          },
          {
            publicIdPrefix: 'RPERM',
            seedMeta: false,
          }
        );
      }
    }

    const passwordHash = await ctx.passwordHash();

    for (const userDefinition of scenario.users) {
      const departmentName = departmentForRole(scenario.scenario_key, userDefinition.role);
      const department = departmentName
        ? orgPack.departments[`${scenario.key}:${departmentName}`]
        : null;

      const user = await ctx.upsert(
        'user',
        `${scenario.key}:user:${userDefinition.key}`,
        {
          tenant_id: tenant.id,
          facility_id: anchorFacility?.id || null,
          position_title: userDefinition.title,
          email: userDefinition.email,
          phone: `+2567${ctx.hash(userDefinition.email).slice(0, 8)}`,
          password_hash: passwordHash,
          status: 'ACTIVE',
        },
        {
          tenantCode: scenario.tenant_code,
          scenarioKey: scenario.scenario_key,
          publicIdPrefix: 'USR',
        }
      );
      result.users[`${scenario.key}:${userDefinition.key}`] = user;

      const profile = await ctx.upsert(
        'user_profile',
        `${scenario.key}:profile:${userDefinition.key}`,
        {
          user_id: user.id,
          facility_id: anchorFacility?.id || null,
          first_name: userDefinition.first_name,
          last_name: userDefinition.last_name,
          gender: PROFILE_GENDER_BY_ROLE[userDefinition.role] || 'OTHER',
        },
        {
          publicIdPrefix: 'UPR',
          seedMeta: false,
        }
      );
      result.profiles[`${scenario.key}:${userDefinition.key}`] = profile;

      const assignedRoles = Array.from(
        new Set([
          userDefinition.role,
          ...((Array.isArray(userDefinition.extra_roles) ? userDefinition.extra_roles : []).filter(Boolean)),
        ])
      );

      for (const assignedRole of assignedRoles) {
        await ctx.upsert(
          'user_role',
          `${scenario.key}:user-role:${userDefinition.key}:${assignedRole}`,
          {
            user_id: user.id,
            role_id: result.roles[`${scenario.key}:${assignedRole}`].id,
            tenant_id: tenant.id,
            facility_id: anchorFacility?.id || null,
          },
          {
            publicIdPrefix: 'UROL',
            seedMeta: false,
          }
        );
      }

      if (userDefinition.role !== 'PATIENT' && userDefinition.role !== 'SUPER_ADMIN') {
        const staffProfile = await ctx.upsert(
          'staff_profile',
          `${scenario.key}:staff:${userDefinition.key}`,
          {
            tenant_id: tenant.id,
            user_id: user.id,
            department_id: department?.id || null,
            staff_number: `${scenario.tenant_code}-${userDefinition.role}-${ctx.hash(userDefinition.email).slice(0, 4).toUpperCase()}`,
            position: userDefinition.title,
            practitioner_type: ['DOCTOR', 'NURSE', 'LAB_TECH', 'RADIOLOGY_TECH', 'PHARMACIST'].includes(userDefinition.role)
              ? userDefinition.role
              : null,
            consultation_fee: userDefinition.role === 'DOCTOR' ? 35 : null,
            consultation_currency: userDefinition.role === 'DOCTOR' ? 'USD' : null,
            is_fee_overridden: userDefinition.role === 'DOCTOR',
            hire_date: ctx.date(-180),
          },
          {
            publicIdPrefix: 'STF',
            seedMeta: false,
          }
        );
        result.staffProfiles[`${scenario.key}:${userDefinition.key}`] = staffProfile;
      }

      await ctx.upsert(
        'contact',
        `${scenario.key}:user-contact:${userDefinition.key}`,
        {
          tenant_id: tenant.id,
          user_profile_id: profile.id,
          contact_type: 'EMAIL',
          value: userDefinition.email,
          is_primary: true,
        },
        {
          publicIdPrefix: 'CNT',
          seedMeta: false,
        }
      );
    }
  }

  return result;
};

module.exports = {
  seedAccessPack,
};

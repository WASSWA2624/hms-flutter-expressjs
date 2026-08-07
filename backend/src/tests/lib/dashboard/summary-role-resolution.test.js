const { ROLES } = require('@config/roles');
const { resolveDashboardRole, resolveEffectiveRole } = require('@lib/dashboard/summary');

describe('dashboard summary role resolution', () => {
  it('resolveDashboardRole prefers operational role over manager overlay', () => {
    expect(
      resolveDashboardRole({ roles: [ROLES.DOCTOR, ROLES.THEATRE_MANAGER] })
    ).toBe(ROLES.DOCTOR);
    expect(
      resolveDashboardRole({
        roles: [ROLES.NURSE, ROLES.WARD_MANAGER, ROLES.ICU_MANAGER]})
    ).toBe(ROLES.NURSE);
    expect(
      resolveDashboardRole({ roles: [ROLES.BIOMED, ROLES.BIOMED_MANAGER] })
    ).toBe(ROLES.BIOMED);
    expect(
      resolveDashboardRole({
        roles: [ROLES.HOUSE_KEEPER, ROLES.HOUSEKEEPING_MANAGER]})
    ).toBe(ROLES.HOUSE_KEEPER);
  });

  it('resolveDashboardRole keeps tenant admin over unit manager overlay', () => {
    expect(
      resolveDashboardRole({ roles: [ROLES.TENANT_ADMIN, ROLES.UNIT_MANAGER] })
    ).toBe(ROLES.TENANT_ADMIN);
  });

  it('resolveEffectiveRole still prefers highest ranked role', () => {
    expect(
      resolveEffectiveRole({ roles: [ROLES.DOCTOR, ROLES.THEATRE_MANAGER] })
    ).toBe(ROLES.THEATRE_MANAGER);
  });
});

const { ROLE_PACKS, metricsToRoleSummary } = require('@lib/dashboard/summary');

describe('super admin dashboard summary cards', () => {
  it('maps subscription health to tenant coverage instead of subscription record counts', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.SUPER_ADMIN, {
      tenantsTotal: 3,
      tenantsActive: 3,
      tenantsWithoutSubscription: 2,
      tenantsWithSubscription: 1,
      facilitiesTotal: 1,
      facilitiesActive: 1,
      subscriptionsTotal: 1,
      subscriptionsActive: 1,
      moduleEntitlementIssues: 0});

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'subscriptions_health',
          value: 1,
          secondary_value: 3,
          format: 'ratio',
          hint: '2 tenants without subscription'}),
        expect.objectContaining({
          id: 'facilities_active',
          value: 1,
          secondary_value: 1,
          format: 'ratio'})])
    );
  });
});

describe('tenant admin dashboard summary cards', () => {
  it('maps tenant facility governance metrics with ratio and percent formats', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.TENANT_ADMIN, {
      facilitiesTotal: 3,
      facilitiesActive: 2,
      activeUsers: 18,
      moduleAdoption: 75,
      subscriptionHealth: 100});

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'facilities_active',
          value: 2,
          secondary_value: 3,
          format: 'ratio'}),
        expect.objectContaining({
          id: 'active_users',
          value: 18}),
        expect.objectContaining({
          id: 'module_adoption',
          value: 75,
          format: 'percent'}),
        expect.objectContaining({
          id: 'subscription_health',
          value: 100,
          format: 'percent'})])
    );
    expect(cards).toHaveLength(4);
  });
});

describe('per-card required_permissions (Dashboard.md)', () => {
  it('emits distinct HR and roster permissions on HR pack cards', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.HR, {
      activeStaff: 10,
      shiftsToday: 4,
      pendingLeaves: 2,
      unassignedShifts: 1,
      attendedToday: 8,
      missedShiftsToday: 0,
      payrollPending: 1,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'active_staff',
          required_permissions: ['hr:read'],
        }),
        expect.objectContaining({
          id: 'shifts_today',
          required_permissions: ['roster:read'],
        }),
        expect.objectContaining({
          id: 'unassigned_shifts',
          required_permissions: ['roster:read'],
        }),
      ])
    );
  });

  it('gates facility-admin pack cards per Dashboard.md permissions', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.FACILITY_ADMIN, {
      patientsToday: 4,
      appointmentsToday: 6,
      activeAdmissions: 2,
      occupiedBeds: 10,
      emergencyCasesToday: 1,
      paymentsToday: 1500,
      openInvoices: 3,
      lowStock: 5,
      criticalLabs: 2,
      pendingLeaves: 1,
      openIncidents: 1,
      openMaintenance: 2,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'active_admissions',
          required_permissions: ['patient:read'],
        }),
        expect.objectContaining({
          id: 'emergency_cases_today',
          required_permissions: ['emergency:read'],
        }),
        expect.objectContaining({
          id: 'collections_today',
          required_permissions: ['billing:read'],
          format: 'currency',
        }),
        expect.objectContaining({
          id: 'low_stock',
          required_permissions: ['pharmacy:read'],
        }),
        expect.objectContaining({
          id: 'critical_labs',
          required_permissions: ['lab:read'],
        }),
        expect.objectContaining({
          id: 'pending_leaves',
          required_permissions: ['hr:read'],
        }),
        expect.objectContaining({
          id: 'open_incidents',
          required_permissions: ['biomed:read'],
        }),
      ])
    );
  });

  it('gates pharmacy billing_pending on billing:read', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.PHARMACIST, {
      ordersToday: 4,
      pendingDispense: 2,
      pendingBalanceAmount: 900,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'billing_pending',
          required_permissions: ['billing:read'],
          value: 900,
          format: 'currency',
        }),
      ])
    );
  });

  it('emits doctor secondary Dashboard.md atoms with per-card permissions', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.DOCTOR, {
      assigned: 3,
      inProgress: 1,
      resultsPendingReview: 2,
      radiologyPending: 4,
      prescriptionsPending: 5,
      criticalLabs: 1,
      shiftsToday: 2,
      followUpsDue: 0,
      completed: 1,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'results_pending_review',
          required_permissions: ['clinical:read'],
          value: 2,
        }),
        expect.objectContaining({
          id: 'radiology_pending',
          required_permissions: ['clinical:read'],
          value: 4,
        }),
        expect.objectContaining({
          id: 'prescriptions_pending',
          required_permissions: ['clinical:read'],
          value: 5,
        }),
        expect.objectContaining({
          id: 'critical_labs',
          required_permissions: ['clinical:read'],
          value: 1,
        }),
        expect.objectContaining({
          id: 'shifts_today',
          required_permissions: ['roster:read'],
          value: 2,
        }),
      ])
    );
    expect(cards.map((card) => card.id)).not.toContain('emergency_cases_today');
  });

  it('gates biomed work orders on biomed:write and ambulance fleet_out on operations:read', () => {
    const biomed = metricsToRoleSummary(ROLE_PACKS.BIOMED, {
      openWorkOrders: 3,
      openIncidents: 1,
    });
    const ambulance = metricsToRoleSummary(ROLE_PACKS.AMBULANCE_OPERATOR, {
      dispatchesToday: 2,
      fleetOut: 1,
    });

    expect(biomed).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'open_work_orders',
          required_permissions: ['biomed:write'],
        }),
        expect.objectContaining({
          id: 'open_incidents',
          required_permissions: ['biomed:read'],
        }),
      ])
    );
    expect(ambulance).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'dispatches_today',
          required_permissions: ['emergency:read'],
        }),
        expect.objectContaining({
          id: 'fleet_out',
          required_permissions: ['operations:read'],
        }),
      ])
    );
  });

  it('emits lab week and month volume KPIs from computed pack metrics', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.LAB_TECH, {
      pending: 4,
      critical: 1,
      completed: 6,
      allPatients: 12,
      ordersThisWeek: 20,
      ordersThisMonth: 55,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'lab_pending', value: 4 }),
        expect.objectContaining({ id: 'lab_orders_week', value: 20 }),
        expect.objectContaining({ id: 'lab_orders_month', value: 55 }),
      ])
    );
  });
});

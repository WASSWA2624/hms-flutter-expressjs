const {
  buildOrderScopeWhere,
  matchesOrderScope,
} = require('@services/pharmacy-workspace/pharmacy.shared');

describe('pharmacy.shared order scope', () => {
  const tenantScope = {
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    can_manage_all_tenants: false,
  };

  describe('matchesOrderScope', () => {
    it('matches patient-scoped clinical orders', () => {
      expect(
        matchesOrderScope(
          {
            patient_id: 'patient-1',
            patient: {
              tenant_id: 'tenant-1',
              facility_id: 'facility-1',
            },
          },
          tenantScope
        )
      ).toBe(true);
    });

    it('rejects patient orders outside facility scope', () => {
      expect(
        matchesOrderScope(
          {
            patient_id: 'patient-1',
            patient: {
              tenant_id: 'tenant-1',
              facility_id: 'facility-other',
            },
          },
          tenantScope
        )
      ).toBe(false);
    });

    it('matches anonymous walk-in orders by drug tenant', () => {
      expect(
        matchesOrderScope(
          {
            patient_id: null,
            patient: null,
            items: [
              {
                drug: { tenant_id: 'tenant-1' },
              },
            ],
          },
          tenantScope
        )
      ).toBe(true);
    });

    it('rejects anonymous walk-in orders from another tenant', () => {
      expect(
        matchesOrderScope(
          {
            patient_id: null,
            patient: null,
            items: [
              {
                drug: { tenant_id: 'tenant-other' },
              },
            ],
          },
          tenantScope
        )
      ).toBe(false);
    });
  });

  describe('buildOrderScopeWhere', () => {
    it('includes anonymous walk-in orders alongside patient-scoped rows', () => {
      expect(buildOrderScopeWhere(tenantScope)).toEqual({
        OR: [
          {
            patient: {
              tenant_id: 'tenant-1',
              facility_id: 'facility-1',
            },
          },
          {
            patient_id: null,
            items: {
              some: {
                deleted_at: null,
                drug: { tenant_id: 'tenant-1' },
              },
            },
          },
        ],
      });
    });
  });
});

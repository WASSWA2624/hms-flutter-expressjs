/**
 * backfill-ambulance-operator-role script tests
 */

jest.mock('@prisma/client', () => ({
  tenant: {
    findMany: jest.fn(),
  },
  facility: {
    findMany: jest.fn(),
  },
  role: {
    findFirst: jest.fn(),
    create: jest.fn(),
  },
  $disconnect: jest.fn(),
}));

const prisma = require('@prisma/client');
const {
  parseCliArgs,
  backfillAmbulanceOperatorRole,
} = require('../../../scripts/backfill-ambulance-operator-role');

describe('backfill-ambulance-operator-role script', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('parseCliArgs', () => {
    it('supports --dry-run and --tenant-id in equals and split forms', () => {
      expect(parseCliArgs(['--dry-run', '--tenant-id=tenant-a'])).toEqual({
        dryRun: true,
        tenantId: 'tenant-a',
      });

      expect(parseCliArgs(['--tenant-id', 'tenant-b'])).toEqual({
        dryRun: false,
        tenantId: 'tenant-b',
      });
    });

    it('throws when --tenant-id value is missing', () => {
      expect(() => parseCliArgs(['--tenant-id='])).toThrow('Missing value for --tenant-id');
      expect(() => parseCliArgs(['--tenant-id'])).toThrow('Missing value for --tenant-id');
      expect(() => parseCliArgs(['--tenant-id', '--dry-run'])).toThrow(
        'Missing value for --tenant-id'
      );
    });
  });

  describe('backfillAmbulanceOperatorRole', () => {
    it('tracks dry-run create/skip counts for facility-scoped roles', async () => {
      prisma.tenant.findMany.mockResolvedValue([{ id: 'tenant-1', name: 'Tenant One' }]);
      prisma.facility.findMany.mockResolvedValue([
        { id: 'facility-1', name: 'Facility One' },
        { id: 'facility-2', name: 'Facility Two' },
      ]);
      prisma.role.findFirst
        .mockResolvedValueOnce({ id: 'existing-role' })
        .mockResolvedValueOnce(null);

      const summary = await backfillAmbulanceOperatorRole({
        dryRun: true,
      });

      expect(summary).toEqual({
        dryRun: true,
        tenantFilter: null,
        tenantsProcessed: 1,
        facilitiesProcessed: 2,
        rolesCreated: 0,
        rolesSkipped: 1,
        rolesWouldCreate: 1,
        failures: 0,
      });
      expect(prisma.role.create).not.toHaveBeenCalled();
    });

    it('creates tenant-level role when no facilities exist and role is missing', async () => {
      prisma.tenant.findMany.mockResolvedValue([{ id: 'tenant-1', name: 'Tenant One' }]);
      prisma.facility.findMany.mockResolvedValue([]);
      prisma.role.findFirst.mockResolvedValue(null);
      prisma.role.create.mockResolvedValue({ id: 'created-role' });

      const summary = await backfillAmbulanceOperatorRole({
        dryRun: false,
        tenantId: 'tenant-1',
      });

      expect(summary).toEqual({
        dryRun: false,
        tenantFilter: 'tenant-1',
        tenantsProcessed: 1,
        facilitiesProcessed: 0,
        rolesCreated: 1,
        rolesSkipped: 0,
        rolesWouldCreate: 0,
        failures: 0,
      });
      expect(prisma.role.create).toHaveBeenCalledWith({
        data: {
          tenant_id: 'tenant-1',
          facility_id: null,
          name: 'AMBULANCE_OPERATOR',
          description: 'Default AMBULANCE_OPERATOR role',
        },
      });
    });
  });
});

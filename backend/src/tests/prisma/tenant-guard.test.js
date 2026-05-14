const { runWithRequestContext } = require('@lib/context/request-context-store');
const {
  buildGuardedWhere,
  createTenantGuardQueryExtension
} = require('../../prisma/tenant-guard');

const ADDRESS_METADATA = {
  hasId: true,
  hasTenantId: true,
  hasDeletedAt: true
};

const createHandlers = (baseClient) =>
  createTenantGuardQueryExtension({
    baseClient,
    modelMetadata: new Map([['address', ADDRESS_METADATA]])
  }).$allModels;

describe('tenant guard query extension', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('scopes id-based reads to the active tenant', async () => {
    const baseClient = {
      address: {
        findFirst: jest.fn().mockResolvedValue({ id: 'address-123' })
      }
    };
    const handlers = createHandlers(baseClient);
    const query = jest.fn();

    const result = await runWithRequestContext(
      {
        actor: { roles: ['NURSE'] },
        scope: { tenant_id: 'tenant-1' }
      },
      () =>
        handlers.findUnique({
          model: 'address',
          args: { where: { id: 'address-123' } },
          query
        })
    );

    expect(result).toEqual({ id: 'address-123' });
    expect(query).not.toHaveBeenCalled();
    expect(baseClient.address.findFirst).toHaveBeenCalledWith({
      where: buildGuardedWhere({ id: 'address-123' }, ADDRESS_METADATA, 'tenant-1', {
        enforceActiveRecord: true
      })
    });
  });

  it('blocks cross-tenant updates with not-found semantics', async () => {
    const baseClient = {
      address: {
        findFirst: jest.fn().mockResolvedValue(null)
      }
    };
    const handlers = createHandlers(baseClient);
    const query = jest.fn();

    await expect(
      runWithRequestContext(
        {
          actor: { roles: ['NURSE'] },
          scope: { tenant_id: 'tenant-1' }
        },
        () =>
          handlers.update({
            model: 'address',
            args: {
              where: { id: 'address-123' },
              data: { city: 'Kampala' }
            },
            query
          })
      )
    ).rejects.toMatchObject({ code: 'P2025' });

    expect(query).not.toHaveBeenCalled();
  });

  it('blocks cross-tenant deletes with not-found semantics', async () => {
    const baseClient = {
      address: {
        findFirst: jest.fn().mockResolvedValue(null)
      }
    };
    const handlers = createHandlers(baseClient);
    const query = jest.fn();

    await expect(
      runWithRequestContext(
        {
          actor: { roles: ['NURSE'] },
          scope: { tenant_id: 'tenant-1' }
        },
        () =>
          handlers.delete({
            model: 'address',
            args: { where: { id: 'address-123' } },
            query
          })
      )
    ).rejects.toMatchObject({ code: 'P2025' });

    expect(query).not.toHaveBeenCalled();
  });

  it('injects tenant_id into create operations', async () => {
    const baseClient = {
      address: {
        findFirst: jest.fn()
      }
    };
    const handlers = createHandlers(baseClient);
    const query = jest.fn(async (args) => args.data);

    const result = await runWithRequestContext(
      {
        actor: { roles: ['NURSE'] },
        scope: { tenant_id: 'tenant-1' }
      },
      () =>
        handlers.create({
          model: 'address',
          args: {
            data: {
              line1: 'Plot 1'
            }
          },
          query
        })
    );

    expect(query).toHaveBeenCalledWith({
      data: {
        tenant_id: 'tenant-1',
        line1: 'Plot 1'
      }
    });
    expect(result).toEqual({
      tenant_id: 'tenant-1',
      line1: 'Plot 1'
    });
  });

  it('bypasses tenant guard for elevated roles', async () => {
    const baseClient = {
      address: {
        findFirst: jest.fn()
      }
    };
    const handlers = createHandlers(baseClient);
    const query = jest.fn(async (args) => args);

    const result = await runWithRequestContext(
      {
        actor: { roles: ['SUPER_ADMIN'] },
        scope: { tenant_id: 'tenant-1' }
      },
      () =>
        handlers.findMany({
          model: 'address',
          args: { where: { city: 'Kampala' } },
          query
        })
    );

    expect(baseClient.address.findFirst).not.toHaveBeenCalled();
    expect(query).toHaveBeenCalledWith({
      where: { city: 'Kampala' }
    });
    expect(result).toEqual({
      where: { city: 'Kampala' }
    });
  });
});

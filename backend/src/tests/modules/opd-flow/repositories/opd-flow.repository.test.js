const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  encounter: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const prisma = require('@prisma/client');
const repository = require('@repositories/opd-flow/opd-flow.repository');

describe('opd-flow.repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('findById returns encounter with soft-delete filter', async () => {
    prisma.encounter.findFirst.mockResolvedValue({ id: 'enc-1' });

    const result = await repository.findById('enc-1');

    expect(result).toEqual({ id: 'enc-1' });
    expect(prisma.encounter.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: 'enc-1',
          deleted_at: null
        }
      })
    );
  });

  it('findMany applies OPD/EMERGENCY filter', async () => {
    prisma.encounter.findMany.mockResolvedValue([]);

    await repository.findMany({ tenant_id: 'tenant-1' }, 0, 10, { started_at: 'desc' });

    expect(prisma.encounter.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenant_id: 'tenant-1',
          encounter_type: { in: ['OPD', 'EMERGENCY'] }
        }),
        skip: 0,
        take: 10
      })
    );
  });

  it('count applies OPD/EMERGENCY filter', async () => {
    prisma.encounter.count.mockResolvedValue(3);

    const result = await repository.count({});

    expect(result).toBe(3);
    expect(prisma.encounter.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          encounter_type: { in: ['OPD', 'EMERGENCY'] }
        })
      })
    );
  });

  it('create maps unique violation to HttpError', async () => {
    const error = new Error('unique violation');
    error.code = 'P2002';
    error.meta = { target: ['id'] };
    prisma.encounter.create.mockRejectedValue(error);

    await expect(repository.create({})).rejects.toBeInstanceOf(HttpError);
  });

  it('create maps foreign key violation to HttpError', async () => {
    const error = new Error('foreign key violation');
    error.code = 'P2003';
    error.meta = { field_name: 'patient_id' };
    prisma.encounter.create.mockRejectedValue(error);

    await expect(repository.create({})).rejects.toBeInstanceOf(HttpError);
  });

  it('update maps not-found to encounter not found', async () => {
    const error = new Error('not found');
    error.code = 'P2025';
    prisma.encounter.update.mockRejectedValue(error);

    await expect(repository.update('enc-1', {})).rejects.toBeInstanceOf(HttpError);
  });

  it('update maps foreign key violation to HttpError', async () => {
    const error = new Error('foreign key violation');
    error.code = 'P2003';
    error.meta = { field_name: 'provider_user_id' };
    prisma.encounter.update.mockRejectedValue(error);

    await expect(repository.update('enc-1', {})).rejects.toBeInstanceOf(HttpError);
  });

  it('softDelete sets deleted_at', async () => {
    prisma.encounter.update.mockResolvedValue({ id: 'enc-1' });

    await repository.softDelete('enc-1');

    expect(prisma.encounter.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'enc-1' },
        data: {
          deleted_at: expect.any(Date)
        }
      })
    );
  });
});

/**
 * Clinical Alert repository tests
 *
 * @module tests/modules/clinical-alert/repositories
 * @description Tests for clinical alert repository
 * Per testing.mdc: Repository tests with mocked Prisma client
 */

const clinicalAlertRepository = require('@repositories/clinical-alert/clinical-alert.repository');
const prisma = require('@prisma/client');

jest.mock('@prisma/client', () => ({
  clinical_alert: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Clinical Alert Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should find clinical alert by ID', async () => {
    const mockAlert = { id: '1', severity: 'HIGH', message: 'Test alert', deleted_at: null };
    prisma.clinical_alert.findFirst.mockResolvedValue(mockAlert);

    const result = await clinicalAlertRepository.findById('1');
    expect(result).toEqual(mockAlert);
  });

  it('should create new clinical alert', async () => {
    const newAlert = { severity: 'HIGH', message: 'New alert' };
    const createdAlert = { id: '1', ...newAlert };
    prisma.clinical_alert.create.mockResolvedValue(createdAlert);

    const result = await clinicalAlertRepository.create(newAlert);
    expect(result).toEqual(createdAlert);
  });

  it('should update clinical alert', async () => {
    const updateData = { severity: 'CRITICAL' };
    const updatedAlert = { id: '1', ...updateData };
    prisma.clinical_alert.update.mockResolvedValue(updatedAlert);

    const result = await clinicalAlertRepository.update('1', updateData);
    expect(result).toEqual(updatedAlert);
  });

  it('should soft delete clinical alert', async () => {
    const id = '1';
    const deletedAlert = { id, deleted_at: new Date() };
    prisma.clinical_alert.update.mockResolvedValue(deletedAlert);

    const result = await clinicalAlertRepository.softDelete(id);
    expect(result.deleted_at).toBeDefined();
  });
});

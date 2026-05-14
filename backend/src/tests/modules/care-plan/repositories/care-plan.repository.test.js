/**
 * Care Plan repository tests
 *
 * @module tests/modules/care-plan/repositories
 * @description Tests for care plan repository
 * Per testing.mdc: Repository tests with mocked Prisma client
 */

const carePlanRepository = require('@repositories/care-plan/care-plan.repository');
const prisma = require('@prisma/client');

jest.mock('@prisma/client', () => ({
  care_plan: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Care Plan Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should find care plan by ID', async () => {
    const mockCarePlan = { id: '1', plan: 'Test plan', deleted_at: null };
    prisma.care_plan.findFirst.mockResolvedValue(mockCarePlan);

    const result = await carePlanRepository.findById('1');
    expect(result).toEqual(mockCarePlan);
  });

  it('should create new care plan', async () => {
    const newCarePlan = { plan: 'New plan' };
    const createdCarePlan = { id: '1', ...newCarePlan };
    prisma.care_plan.create.mockResolvedValue(createdCarePlan);

    const result = await carePlanRepository.create(newCarePlan);
    expect(result).toEqual(createdCarePlan);
  });

  it('should update care plan', async () => {
    const updateData = { plan: 'Updated plan' };
    const updatedCarePlan = { id: '1', ...updateData };
    prisma.care_plan.update.mockResolvedValue(updatedCarePlan);

    const result = await carePlanRepository.update('1', updateData);
    expect(result).toEqual(updatedCarePlan);
  });

  it('should soft delete care plan', async () => {
    const id = '1';
    const deletedCarePlan = { id, deleted_at: new Date() };
    prisma.care_plan.update.mockResolvedValue(deletedCarePlan);

    const result = await carePlanRepository.softDelete(id);
    expect(result.deleted_at).toBeDefined();
  });
});

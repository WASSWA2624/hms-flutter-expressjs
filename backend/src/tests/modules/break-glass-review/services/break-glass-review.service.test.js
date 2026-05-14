jest.mock('@repositories/break-glass-review/break-glass-review.repository');
jest.mock('@repositories/break-glass-access/break-glass-access.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(() => Promise.resolve({})),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
}));
jest.mock('@lib/last-office/events', () => ({
  ACCESS_CONTROL_EVENTS: {
    BREAK_GLASS_REVIEWED: 'access_control.break_glass.reviewed',
  },
  emitAccessControlEvent: jest.fn(async () => ({})),
}));
jest.mock('@lib/telemetry/metrics', () => ({
  recordWorkflowEvent: jest.fn(),
}));

const breakGlassReviewRepository = require('@repositories/break-glass-review/break-glass-review.repository');
const breakGlassAccessRepository = require('@repositories/break-glass-access/break-glass-access.repository');
const { createAuditLog } = require('@lib/audit');
const { emitAccessControlEvent } = require('@lib/last-office/events');
const { HttpError } = require('@lib/errors');
const breakGlassReviewService = require('@services/break-glass-review/break-glass-review.service');

const buildAccess = (overrides = {}) => ({
  id: 'break-glass-access-1',
  human_friendly_id: 'BGA-001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-1',
  target_resource_type: 'patient',
  target_resource_id: 'patient-1',
  requested_by_user_id: 'user-doctor',
  approved_by_user_id: null,
  reason: 'Emergency access requested for review',
  status: 'REQUESTED',
  review_status: 'PENDING',
  requested_at: '2026-04-09T07:00:00.000Z',
  approved_at: null,
  starts_at: null,
  expires_at: null,
  reviewed_at: null,
  version: 1,
  created_at: '2026-04-09T07:00:00.000Z',
  updated_at: '2026-04-09T07:00:00.000Z',
  deleted_at: null,
  ...overrides,
});

const buildReview = (overrides = {}) => ({
  id: 'break-glass-review-1',
  human_friendly_id: 'BGR-001',
  break_glass_access_id: 'break-glass-access-1',
  tenant_id: 'tenant-1',
  reviewer_user_id: 'user-ops',
  status: 'APPROVED',
  notes: 'Approved for time-bounded emergency access',
  decided_at: '2026-04-09T07:05:00.000Z',
  created_at: '2026-04-09T07:05:00.000Z',
  updated_at: '2026-04-09T07:05:00.000Z',
  deleted_at: null,
  version: 1,
  ...overrides,
});

describe('break-glass-review.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('requires an expiry when approving access that has no current expiry', async () => {
    breakGlassAccessRepository.findById.mockResolvedValue(buildAccess());

    await expect(
      breakGlassReviewService.createBreakGlassReview(
        {
          break_glass_access_id: 'BGA-001',
          status: 'APPROVED',
          notes: 'Approve now',
        },
        {
          tenant_id: 'tenant-1',
          user_id: 'user-ops',
          facility_id: 'facility-1',
        }
      )
    ).rejects.toMatchObject({ statusCode: 400 });

    expect(breakGlassReviewRepository.create).not.toHaveBeenCalled();
    expect(breakGlassAccessRepository.update).not.toHaveBeenCalled();
  });

  it('creates a review and activates the emergency access window when approved', async () => {
    const access = buildAccess();
    const review = buildReview();
    const nextAccess = buildAccess({
      status: 'ACTIVE',
      review_status: 'APPROVED',
      approved_by_user_id: 'user-ops',
      approved_at: '2026-04-09T07:05:00.000Z',
      starts_at: '2026-04-09T07:05:00.000Z',
      expires_at: '2026-04-09T07:50:00.000Z',
      reviewed_at: '2026-04-09T07:05:00.000Z',
      version: 2,
    });

    breakGlassAccessRepository.findById.mockResolvedValue(access);
    breakGlassReviewRepository.create.mockResolvedValue(review);
    breakGlassAccessRepository.update.mockResolvedValue(nextAccess);

    const result = await breakGlassReviewService.createBreakGlassReview(
      {
        break_glass_access_id: 'BGA-001',
        status: 'APPROVED',
        notes: 'Approved for emergency review',
        expires_at: '2026-04-09T07:50:00.000Z',
      },
      {
        tenant_id: 'tenant-1',
        user_id: 'user-ops',
        facility_id: 'facility-1',
        ip_address: '127.0.0.1',
      }
    );

    expect(breakGlassReviewRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        break_glass_access_id: 'break-glass-access-1',
        reviewer_user_id: 'user-ops',
        status: 'APPROVED',
      })
    );
    expect(breakGlassAccessRepository.update).toHaveBeenCalledWith(
      'break-glass-access-1',
      expect.objectContaining({
        status: 'ACTIVE',
        review_status: 'APPROVED',
        approved_by_user_id: 'user-ops',
        version: 2,
      })
    );
    expect(createAuditLog).toHaveBeenCalled();
    expect(emitAccessControlEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      })
    );
    expect(result).toEqual(
      expect.objectContaining({
        review: expect.objectContaining({ id: 'BGR-001', status: 'APPROVED' }),
        access: expect.objectContaining({ id: 'BGA-001', status: 'ACTIVE', review_status: 'APPROVED' }),
      })
    );
  });

  it('throws when the target access record is missing', async () => {
    breakGlassAccessRepository.findById.mockResolvedValue(null);

    await expect(
      breakGlassReviewService.createBreakGlassReview(
        {
          break_glass_access_id: 'BGA-404',
          status: 'REJECTED',
        },
        {
          tenant_id: 'tenant-1',
          user_id: 'user-ops',
        }
      )
    ).rejects.toThrow(HttpError);
  });
});

/**
 * @jest-environment node
 */

const {
  assertPermissionNamesIncludeRequiredReads,
  expandPermissionNamesWithRequiredReads,
  findMissingRequiredReads,
  requiredReadPermissionFor,
} = require('@lib/authorization/permission-read-dependency');
const { PERMISSIONS } = require('@config/permissions');
const { HttpError } = require('@lib/errors');

describe('permission-read-dependency', () => {
  describe('requiredReadPermissionFor', () => {
    it('requires domain:read for write/delete/manage actions', () => {
      expect(requiredReadPermissionFor(PERMISSIONS.BILLING_WRITE)).toBe(
        PERMISSIONS.BILLING_READ
      );
      expect(requiredReadPermissionFor(PERMISSIONS.PATIENT_DELETE)).toBe(
        PERMISSIONS.PATIENT_READ
      );
      expect(requiredReadPermissionFor(PERMISSIONS.UNIT_MANAGE)).toBe(
        PERMISSIONS.UNIT_READ
      );
      expect(requiredReadPermissionFor(PERMISSIONS.PROFILE_UPDATE)).toBe(
        PERMISSIONS.PROFILE_READ
      );
    });

    it('returns null for read actions and domains without a catalog read', () => {
      expect(requiredReadPermissionFor(PERMISSIONS.BILLING_READ)).toBeNull();
      expect(requiredReadPermissionFor(PERMISSIONS.PLATFORM_ADMIN)).toBeNull();
      expect(requiredReadPermissionFor(PERMISSIONS.TENANT_ADMIN)).toBeNull();
      expect(requiredReadPermissionFor(PERMISSIONS.BREAK_GLASS_REQUEST)).toBeNull();
      expect(requiredReadPermissionFor(PERMISSIONS.FINANCIAL_APPROVE)).toBeNull();
      expect(requiredReadPermissionFor(PERMISSIONS.EVIDENCE_EXPORT)).toBeNull();
    });
  });

  describe('findMissingRequiredReads', () => {
    it('flags write without read in the same assignment set', () => {
      expect(
        findMissingRequiredReads([PERMISSIONS.BILLING_WRITE])
      ).toEqual([
        {
          permission: PERMISSIONS.BILLING_WRITE,
          required_read: PERMISSIONS.BILLING_READ,
        },
      ]);
    });

    it('accepts write when read is in the same set or already attached', () => {
      expect(
        findMissingRequiredReads([
          PERMISSIONS.BILLING_READ,
          PERMISSIONS.BILLING_WRITE,
        ])
      ).toEqual([]);
      expect(
        findMissingRequiredReads([PERMISSIONS.BILLING_WRITE], {
          existingPermissionNames: [PERMISSIONS.BILLING_READ],
        })
      ).toEqual([]);
    });
  });

  describe('assertPermissionNamesIncludeRequiredReads', () => {
    it('throws when required reads are missing', () => {
      expect(() =>
        assertPermissionNamesIncludeRequiredReads([PERMISSIONS.LAB_WRITE])
      ).toThrow(HttpError);
      try {
        assertPermissionNamesIncludeRequiredReads([PERMISSIONS.LAB_WRITE]);
      } catch (error) {
        expect(error.message).toBe('errors.permission.read_required');
        expect(error.statusCode).toBe(400);
        expect(error.errors[0].reason).toBe('read_permission_required');
      }
    });

    it('allows coherent sets and exempt domains', () => {
      expect(() =>
        assertPermissionNamesIncludeRequiredReads([
          PERMISSIONS.LAB_READ,
          PERMISSIONS.LAB_WRITE,
          PERMISSIONS.PLATFORM_ADMIN,
          PERMISSIONS.BREAK_GLASS_APPROVE,
        ])
      ).not.toThrow();
    });
  });

  describe('expandPermissionNamesWithRequiredReads', () => {
    it('auto-attaches missing read companions', () => {
      expect(
        expandPermissionNamesWithRequiredReads([
          PERMISSIONS.PHARMACY_WRITE,
          PERMISSIONS.PLATFORM_ADMIN,
        ]).sort()
      ).toEqual(
        [
          PERMISSIONS.PHARMACY_READ,
          PERMISSIONS.PHARMACY_WRITE,
          PERMISSIONS.PLATFORM_ADMIN,
        ].sort()
      );
    });
  });

  describe('shipped packs stay coherent', () => {
    const { ROLE_PERMISSIONS } = require('@config/permissions');
    const {
      PLAN_PERMISSION_CAPS,
    } = require('@lib/subscriptions/subscription-permission-caps');

    it('role packs never grant write-without-read', () => {
      for (const names of Object.values(ROLE_PERMISSIONS)) {
        expect(findMissingRequiredReads(names)).toEqual([]);
      }
    });

    it('subscription tier caps never grant write-without-read', () => {
      for (const names of Object.values(PLAN_PERMISSION_CAPS)) {
        expect(findMissingRequiredReads(names)).toEqual([]);
      }
    });
  });
});

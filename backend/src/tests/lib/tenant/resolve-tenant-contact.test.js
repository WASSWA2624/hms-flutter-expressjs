/**
 * resolve-tenant-contact unit tests
 */

const {
  resolveTenantContact,
  buildRegistrationContactExtension,
  hasResolvedContact,
} = require('@lib/tenant/resolve-tenant-contact');

describe('resolve-tenant-contact', () => {
  it('prefers extension_json.contact when present', () => {
    const contact = resolveTenantContact({
      extension_json: {
        contact: {
          name: 'Extension Name',
          email: 'extension@example.com',
          phone: '256700000001',
        },
      },
      primary_tenant_admin: {
        full_name: 'Admin Name',
        email: 'admin@example.com',
        phone: '256700000002',
      },
    });

    expect(contact).toEqual({
      name: 'Extension Name',
      email: 'extension@example.com',
      phone: '256700000001',
    });
  });

  it('fills missing extension fields from primary tenant admin', () => {
    const contact = resolveTenantContact({
      extension_json: {
        contact: {
          name: 'Extension Name',
          email: null,
          phone: '',
        },
      },
      primary_tenant_admin: {
        full_name: 'Admin Name',
        email: 'admin@example.com',
        phone: '256700000002',
      },
    });

    expect(contact).toEqual({
      name: 'Extension Name',
      email: 'admin@example.com',
      phone: '256700000002',
    });
  });

  it('falls back to TENANT_ADMIN user_roles when extension contact is absent', () => {
    const contact = resolveTenantContact({
      extension_json: null,
      user_roles: [
        {
          user: {
            email: 'owner@example.com',
            phone: '256783230321',
            profile: {
              first_name: 'Wilson',
              last_name: 'Wasswa',
            },
          },
        },
      ],
    });

    expect(contact).toEqual({
      name: 'Wilson Wasswa',
      email: 'owner@example.com',
      phone: '256783230321',
    });
    expect(hasResolvedContact(contact)).toBe(true);
  });

  it('builds registration extension with UGX defaults and owner contact', () => {
    expect(
      buildRegistrationContactExtension({
        admin_name: ' Wilson Wasswa ',
        email: 'owner@example.com',
        phone: '256783230321',
      })
    ).toEqual({
      currency: 'UGX',
      billing: {
        standard_consultation_fee: 25000,
      },
      contact: {
        name: 'Wilson Wasswa',
        email: 'owner@example.com',
        phone: '256783230321',
      },
    });
  });
});

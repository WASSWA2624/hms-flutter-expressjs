const fs = require('fs');
const path = require('path');

const subject = require('@routes/user-role/user-role.routes');

describe('user-role.routes contract', () => {
  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('lets platform owners assign, change and revoke roles', () => {
    // Role-name gate with no elevated fallback: an omitted role is a hard 403
    // on every write route, which reads to the admin as a silent no-op.
    const source = fs.readFileSync(
      path.join(__dirname, '../../../../modules/user-role/routes/user-role.routes.js'),
      'utf8'
    );
    const declaration = source.slice(
      source.indexOf('const ADMIN_ROLE_SET'),
      source.indexOf(';', source.indexOf('const ADMIN_ROLE_SET'))
    );

    expect(declaration).toContain('PLATFORM_OWNER');
    expect(declaration).toContain('PLATFORM_ADMIN');
    expect(declaration).toContain('TENANT_ADMIN');
    expect(declaration).toContain('FACILITY_ADMIN');
    expect(declaration).toContain('HR');

    const writeRoutes = subject.stack
      .filter((layer) => layer.route)
      .filter((layer) =>
        ['post', 'put', 'delete'].some((method) => layer.route.methods[method])
      );
    expect(writeRoutes.length).toBeGreaterThanOrEqual(3);
  });
});

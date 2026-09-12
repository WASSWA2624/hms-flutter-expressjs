/**
 * Demo seeding reachability tests
 *
 * Step 05, AC3: no registration or tenant-creation path may trigger demo or
 * filler seeding, in development or production. Two independent guarantees are
 * checked here - nothing under `src/` imports a seeder, and a seeder refuses to
 * load inside the API process even if something one day does.
 */

const fs = require('fs');
const path = require('path');

const SRC_ROOT = path.join(__dirname, '..', '..');

/** Require specifiers that would pull demo seeding into the request path. */
const SEEDER_SPECIFIERS = [
  'scripts/seeders',
  'seed-runtime',
  'seed-demo-data',
  'seed-filler-pack',
  'seed-volume-pack',
  'seed-volume-extended-pack',
  'seed-catalog',
  'seed-org-pack',
  'seed-access-pack',
  'seed-clinical-pack',
];

const listJsFiles = (dir) => {
  const found = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'tests' || entry.name === 'node_modules') continue;
      found.push(...listJsFiles(full));
    } else if (entry.isFile() && entry.name.endsWith('.js')) {
      found.push(full);
    }
  }
  return found;
};

describe('demo seeding is unreachable from the request path', () => {
  it('has no seeder import anywhere under src/', () => {
    const offenders = [];

    for (const file of listJsFiles(SRC_ROOT)) {
      const source = fs.readFileSync(file, 'utf8');
      const requires = source.match(/require\(\s*['"]([^'"]+)['"]\s*\)/g) || [];

      for (const statement of requires) {
        const specifier = statement.replace(/^require\(\s*['"]/, '').replace(/['"]\s*\)$/, '');
        if (SEEDER_SPECIFIERS.some((needle) => specifier.includes(needle))) {
          offenders.push(`${path.relative(SRC_ROOT, file)} -> ${specifier}`);
        }
      }
    }

    expect(offenders).toEqual([]);
  });

  it('refuses to load a seeder inside the API server process', () => {
    const previous = process.env.HMS_PROCESS_ROLE;
    process.env.HMS_PROCESS_ROLE = 'api-server';
    jest.resetModules();

    try {
      expect(() => require('../../../scripts/seeders/seed-runtime')).toThrow(
        /cannot be loaded inside the API server process/i
      );
    } finally {
      if (previous === undefined) delete process.env.HMS_PROCESS_ROLE;
      else process.env.HMS_PROCESS_ROLE = previous;
      jest.resetModules();
    }
  });

  it('stamps the process role before the API starts listening', () => {
    const source = fs.readFileSync(path.join(SRC_ROOT, 'server.js'), 'utf8');
    const stampIndex = source.indexOf("process.env.HMS_PROCESS_ROLE = 'api-server'");
    const listenIndex = source.indexOf('app.listen(');

    expect(stampIndex).toBeGreaterThan(-1);
    expect(listenIndex).toBeGreaterThan(-1);
    expect(stampIndex).toBeLessThan(listenIndex);
  });

  it('guards the seeders regardless of NODE_ENV', () => {
    const source = fs.readFileSync(
      path.join(SRC_ROOT, '..', 'scripts', 'seeders', 'seed-runtime.js'),
      'utf8'
    );
    const guard = source.slice(
      source.indexOf('HMS_PROCESS_ROLE'),
      source.indexOf('cannot be loaded inside the API server process')
    );

    // The guard must not branch on environment - it applies everywhere.
    expect(guard).not.toMatch(/NODE_ENV/);
  });
});

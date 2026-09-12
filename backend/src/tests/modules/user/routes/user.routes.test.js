const subject = require('@routes/user/user.routes');

describe('user.routes contract', () => {
  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('registers the permanent delete route', () => {
    const registered = subject.stack
      .filter((layer) => layer.route)
      .map((layer) => `${Object.keys(layer.route.methods)[0]} ${layer.route.path}`);

    expect(registered).toContain('delete /:id');
    expect(registered).toContain('delete /:id/permanent');
    expect(registered).toContain('post /:id/restore');
  });
});

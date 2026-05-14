const { z } = require('zod');
const { validateRequest } = require('@middlewares/validate.middleware');

describe('validate middleware', () => {
  let res;
  let next;

  beforeEach(() => {
    res = {};
    next = jest.fn();
  });

  it('parses and assigns body, params, and query payloads', () => {
    const middleware = validateRequest({
      body: z.object({ active: z.coerce.boolean() }),
      params: z.object({ id: z.coerce.number().int() }),
      query: z.object({ page: z.coerce.number().int() })
    });

    const req = {
      body: { active: 'true' },
      params: { id: '42' },
      query: { page: '2' }
    };

    middleware(req, res, next);

    expect(req.body).toEqual({ active: true });
    expect(req.params).toEqual({ id: 42 });
    expect(req.query).toEqual({ page: 2 });
    expect(next).toHaveBeenCalledWith();
  });

  it('overrides getter-based query so coerced values persist', () => {
    const middleware = validateRequest({
      query: z.object({ limit: z.coerce.number().int() })
    });

    const originalQuery = { limit: '100' };
    const req = {};
    Object.defineProperty(req, 'query', {
      get: () => originalQuery,
      configurable: true,
      enumerable: true
    });

    middleware(req, res, next);

    expect(req.query).toEqual({ limit: 100 });
    expect(Object.getOwnPropertyDescriptor(req, 'query').get).toBeUndefined();
    expect(next).toHaveBeenCalledWith();
  });

  it('passes validation errors to next', () => {
    const middleware = validateRequest({
      query: z.object({
        limit: z.coerce.number().int().max(100)
      })
    });

    const req = {
      query: { limit: '250' }
    };

    middleware(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    const [error] = next.mock.calls[0];
    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe('ZodError');
  });
});

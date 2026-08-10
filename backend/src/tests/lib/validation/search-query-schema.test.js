const {
  searchQuerySchema,
  DEFAULT_SEARCH_QUERY_MAX_LENGTH,
} = require('@lib/validation/zod');

describe('searchQuerySchema', () => {
  const schema = searchQuerySchema();

  it('accepts short search strings', () => {
    expect(schema.parse('alice')).toBe('alice');
  });

  it('trims and collapses whitespace including newlines', () => {
    expect(schema.parse('  alpha\n\nbeta  ')).toBe('alpha beta');
  });

  it('truncates overlong search instead of rejecting', () => {
    const long = `${'word '.repeat(80)}\n\nmore text`;
    const parsed = schema.parse(long);
    expect(parsed).toHaveLength(DEFAULT_SEARCH_QUERY_MAX_LENGTH);
    expect(parsed.includes('\n')).toBe(false);
  });

  it('treats blank search as undefined', () => {
    expect(schema.parse('   \n\t  ')).toBeUndefined();
    expect(schema.parse(undefined)).toBeUndefined();
  });
});

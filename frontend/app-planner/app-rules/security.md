# Security Rules

## Scope
Defines security expectations for storage, networking, logging, configuration, and UI handling.

## Mandatory rules
- Do not commit secrets, API keys, private certificates, passwords, or tokens.
- Do not log sensitive values.
- Use HTTPS for production network communication unless a documented private-network exception exists.
- Store sensitive session artifacts in secure storage where supported.
- Use `shared_preferences` only for non-sensitive settings.
- Validate data at boundaries: UI input, repository input, API response, and local persistence.
- Treat data from backend and local storage as untrusted until validated or mapped.
- Avoid displaying raw server errors to users.
- Clear sensitive session state on logout.
- Keep debug tools and verbose logs disabled in production builds.

## Secure storage notes
- Native mobile and desktop may use platform-backed secure storage.
- Web secure storage has platform limitations; do not assume web storage is equivalent to native secure storage.
- Document any web auth/session strategy clearly before production use.

## Acceptance checklist
- Secret scanning finds no committed secrets.
- Production builds do not print sensitive logs.
- All auth and API failures are handled safely.
- Security-sensitive dependencies are reviewed before release.

## Related rules
- [`authentication_session.md`](./authentication_session.md)
- [`storage_strategy.md`](./storage_strategy.md)
- [`network_api.md`](./network_api.md)
- [`environment_configuration.md`](./environment_configuration.md)

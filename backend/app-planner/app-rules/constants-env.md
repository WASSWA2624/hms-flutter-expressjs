---
alwaysApply: true
---
# Constants And Environment Rules

Purpose: centralize runtime configuration.

Rules:
- `src/config/env.js` is the only place that reads raw environment variables
- all required environment variables are validated at startup
- secret values must not have silent fallbacks
- non-secret runtime constants belong in config modules, not scattered literals
- environment variable names use `UPPER_SNAKE_CASE`
- feature flags and provider selection are config-driven

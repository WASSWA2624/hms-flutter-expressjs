---
alwaysApply: true
---
# Documentation Rules

Purpose: require professional code documentation.

Rules:
- exported functions, modules, classes, and complex logic require JSDoc-style multi-line comments
- route handlers document purpose, authentication, permissions, params, body, responses, and important side effects
- repositories and services document scope assumptions, audit expectations, and non-obvious workflow constraints
- inline comments explain intent or edge cases only
- code, migrations, seeds, and docs must be updated in the same change when behavior changes

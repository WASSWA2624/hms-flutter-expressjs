# ADR 0001: Project Setup

## Status

Accepted

## Context

The template needs a Flutter project root that can run immediately while staying
backend-agnostic and ready for Android, iOS, Web, Windows desktop, macOS
desktop, and Linux desktop development.

## Decision

Use the standard Flutter scaffold, keep dependencies minimal, and normalize the
source tree to the canonical structure in
[`app-rules/project_structure.md`](../../app-planner/app-rules/project_structure.md).
The starter UI is a neutral home page with centralized strings and a shared
Material theme.

## Consequences

- Product-specific backend behavior is not part of the starter.
- Later dev-plan steps can add routing, state management, localization,
  networking, storage, and component libraries without reshaping the project.
- Line endings are normalized through `.editorconfig` and `.gitattributes`.

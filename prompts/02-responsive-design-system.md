# Responsive Design & Design System — Implementation Prompt

## Objective

Establish consistent, reusable, responsive UI across mobile (including extra-small), tablet, and desktop (including large widths) using centralized design tokens, breakpoints, and shared components — not scaled-one-layout designs.

**Source requirement:** [prompt.md](../prompt.md) §2  
**Also required:** [prompts/00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md)

---

## Mandatory reading

1. [`frontend/.cursor/design-system.mdc`](../frontend/.cursor/design-system.mdc)
2. [`frontend/.cursor/layouts.mdc`](../frontend/.cursor/layouts.mdc)
3. [`frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc)
4. [`frontend/.cursor/accessibility.mdc`](../frontend/.cursor/accessibility.mdc)
5. [`frontend/.cursor/platform_guidelines.mdc`](../frontend/.cursor/platform_guidelines.mdc)
6. [`frontend/.cursor/ui-workspace.mdc`](../frontend/.cursor/ui-workspace.mdc)

---

## Pre-implementation audit

- Inventory current breakpoints, shell, spacing, max-width utilities, icon system, and theme tokens.
- List feature screens that hardcode widths, colors, typography, or feature-specific breakpoint logic.
- Identify icons used without semantic labels or status conveyed by color alone.

---

## Step-by-step instructions

### 1. Centralize responsive foundations

- Use only the shared breakpoint, shell, spacing, and max-width utilities from frontend rules.
- Avoid feature-specific breakpoint logic and fixed widths unless intentional min/max constraints.
- Adapt navigation, density, column count, dialogs, tables, and input behavior per form factor while keeping one workflow.

### 2. Design tokens & theming

- Standardize typography, spacing, color, shape, elevation, motion, feedback, and interaction via shared tokens.
- Light and dark themes for every reusable component.
- Remove hardcoded visual values from feature code; migrate to tokens.

### 3. Icon system

Apply consistent icons to buttons, navigation, menus, list items, labels, status indicators, actions, forms, cards, tabs, dialogs, alerts, badges, and toolbars.

Rules:

- Icons improve comprehension; include localized semantic labels where needed.
- Never use icon/color as the only indicator of important status.
- Prefer concise labels; do not replace necessary labels with ambiguous icons.

### 4. Interaction modalities

- Support touch, pointer, keyboard, focus, hover, and text scaling.
- Do not hide critical controls on any supported form factor.
- Practical touch/click targets; keyboard reading order preserved.

### 5. Verification matrix

For representative screens, verify at all centralized breakpoints:

- Long localized text
- Large text scaling
- Keyboard-only input
- Constrained heights
- Light and dark themes

---

## Reusability

- Extend `frontend/lib/shared/` primitives first; do not fork layout shells per feature.
- Remove duplicate layout wrappers and ad-hoc breakpoint helpers after migration.

## Related prompts

- [03-shared-reusable-components.md](./03-shared-reusable-components.md)
- [13-general-application-consistency.md](./13-general-application-consistency.md)

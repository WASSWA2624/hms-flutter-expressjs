# Reusable Components

## Scope
Defines the shared component and layout system that keeps the app uniform without creating unnecessary custom widgets.

## Mandatory rules
- Prefer Flutter built-in Material/Cupertino widgets and wrap them only when consistency or repeated behavior is needed.
- Keep shared components minimal, flexible, and stable.
- Do not create multiple components for the same job.
- Do not put product-specific business logic in shared components.
- All user-facing labels, hints, validation messages, and accessibility labels must come from localization.
- Components must support enabled, disabled, loading, error, focused, and empty states where relevant.
- Components must adapt to supported screen sizes and input methods.
- Components must use the theme system for colors, spacing, typography, radius, and elevation.

## Standard shared components
| Component | Built on | Purpose |
|---|---|---|
| `AppButton` | `FilledButton`, `OutlinedButton`, `TextButton` | primary, secondary, tertiary actions |
| `AppIconButton` | `IconButton` | compact icon actions with required semantic labels |
| `AppTextField` | `TextFormField` | text, number, password, multiline input |
| `AppSelectField<T>` | `DropdownMenu<T>` or Material menu primitives | searchable/filterable selection where needed |
| `AppRadioGroup<T>` | `RadioGroup` / `RadioListTile` | exclusive options |
| `AppCheckboxField` | `CheckboxListTile` | boolean option |
| `AppSwitchField` | `SwitchListTile` | setting toggle |
| `AppDateField` | `showDatePicker`, `CalendarDatePicker`, `InputDatePickerFormField` | date input with one API across screen sizes |
| `AppDialog` | `Dialog` / `AlertDialog` | consistent modal content |
| `AsyncStateScaffold` | shared composition | loading, empty, error, success states |
| `ResponsivePage` | layout composition | page padding and max-width constraints |
| `ResponsiveAppShell` | `Scaffold`, `NavigationRail`, `NavigationDrawer`, `MenuBar` | mobile/tablet/desktop shell |
| `AppMenuBar` | `MenuBar` or platform menu APIs where appropriate | desktop/web app-level actions |
| `SideNavigation` | `NavigationRail` or custom Material composition | desktop side navigation with collapsed and expanded states |

## Component styling rules
- Keep normal icons at `20-24px` unless a specific layout requires a larger size.
- Keep common button heights around `40-48px`.
- Keep common radii moderate, usually `8-12px`.
- Do not add large paddings that make desktop controls feel bulky.
- Use text plus icons for important navigation or status items where space allows.

## Form component rules
- Form components must expose validation hooks but must not own feature validation rules.
- Searchable selects must show options as overlays or menus, not by pushing unrelated content down unless the layout intentionally requires inline expansion.
- Date fields must use locale-aware formatting.
- Password fields must provide accessible show/hide behavior when used.

## Acceptance checklist
- A coding agent can build forms, lists, dialogs, empty states, loading states, and shell layouts using shared components only.
- Components look consistent across features.
- Components work with keyboard, mouse, touch, and screen readers.

## Related rules
- [`forms.md`](./forms.md)
- [`theming.md`](./theming.md)
- [`responsive_adaptive_design.md`](./responsive_adaptive_design.md)
- [`accessibility.md`](./accessibility.md)
- [`localization_i18n.md`](./localization_i18n.md)

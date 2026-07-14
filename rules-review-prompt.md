Review all rule files in: [HMS rules](.cursor/**), [Backend rules](backend/.cursor/**), and [Frontend rules](frontend/.cursor/**).

For each rule file, apply the following steps where applicable:

1. Ensure `alwaysApply: false` is correctly set unless otherwise specified.

2. In the `meta` section:
  - Confirm `globs` accurately match the rule file's intended scope.
  - Verify the `description` is clear (≤21 words), concise, and states precise application conditions.

3. Remove or update only duplicate or conflicting rules to maintain consistency across the codebase.

4. Where needed, revise descriptions to be unambiguous and easily understandable.

5. Where standards for product or UI are defined (e.g., UI, sync, workflow rules), explicitly require: high performance, uniform and consistent UI, reusable components/code, real-time sync from UI to backend, full responsiveness (mobile, tablet, desktop), simple UI design, and intuitive workflows.

6. For entity reference rules between frontend and backend, where relevant, require: "Frontend must reference entities by human_friendly_id; backend maps to internal IDs. Do not expose raw table IDs in frontend or API responses."

7. Where relevant, require that themes are comprehensive and prohibit hard-coded tokens throughout the codebase.

8. Ensure all text is localized, concise, and uses appropriate terminology for its context.

9. Make changes only in those rule files or sections to which these requirements apply; leave unrelated rules unchanged.

10. For UI rules, require that reusability and consistency are prioritized. All components suitable for reuse must be implemented as reusable components and stored in the appropriate subfolder under [Shared folder](frontend/lib/shared/).

11. Where relevant, require strict enforcement of Role-Based Access Control (RBAC) and Attribute-Based Access Control (ABAC) based on user roles and permissions. Menus, interface components, actions, and workflows must not be visible or accessible to unauthorized users.

12. Allow assignment of multiple roles and modules to each user in the database, but all effective permissions must be intersected with those enabled by the user's subscription package—users cannot access any permission, module, or functionality not included in their current subscription, even if granted by role, module, or direct assignment. Store permissions at user, role, and module levels; allow permissions to be attached to users, roles, modules, and linked to subscription packages.

13. In all `.cursor/access` or relevant rule files, require a default, source-controlled set of modules, subscription packages, user roles, and associated permissions. Each module in `.cursor/access/modules.mdc` must declare default permissions as per `.cursor/access/permissions.mdc`. Subscription packages (see `.cursor/access/subscriptions.mdc`) must enumerate included modules and their effective permissions. User roles (see `.cursor/access/default_user_roles.mdc`) must ship with default module permissions, modifiable or reverted to shipped defaults by authorized administrators only. The system must:
    - Provide an out-of-the-box complete core set of modules, packages, roles, and permissions, all defined in source control.
    - Permit authorized administrators to customize, extend, or reset any module, role, or package permissions to shipped defaults at any time, with all changes versioned and auditable.
    - Require clear documentation and enforcement of all permission assignments and relationships between modules, subscriptions, roles, and users.
    - Guarantee that all defaults can be restored and all active changes are atomic, ensuring no user ever holds access beyond the intersection of their current roles and subscription package.

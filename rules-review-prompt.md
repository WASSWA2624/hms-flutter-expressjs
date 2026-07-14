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

12. Allow assignment of multiple roles and modules to each user in the database, but all effective permissions must be intersected with those enabled by the user's subscription package—users cannot access any permission, module, or functionality not included in their current subscription, even if granted by role, module, or direct assignment. Store permissions at user, role, and module levels; allow permissions to be attached to users, roles, modules, and linked to subscription packages. Permission rules must set `alwaysApply: true`.

13. (alwaysApply: true) Define a default set of modules, subscription packages, user roles, and their associated permissions. Each module must declare its default permissions; subscription packages must enumerate included modules and effective permissions for each. User roles should ship with default permissions, which may be extended, customized, or reset to defaults by authorized users only. The system must:
    - Ship with a complete set of core modules, packages, and roles/permissions out-of-the-box.
    - Allow authorized administrators to customize, extend, or reset module/role/package permissions to their shipped defaults at any time.
    - Clearly document and enforce all permission assignments and relationships between modules, subscriptions, roles, and users.
    - Ensure all defaults are modifiable but can always be restored to original values.
    - Apply changes atomically so no user has more access than permitted by their roles and subscription at any point.

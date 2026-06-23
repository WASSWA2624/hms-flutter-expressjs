The select component requires two clicks to register a selection, which is not acceptable from a UX perspective. It should respond immediately on the first click.

We also need to enhance how clinical items are managed across the system:

### 1. Favorites system (user-level)

Add support for users to mark and reuse favorites for:

* Diagnoses
* Lab tests
* Procedures
* Prescriptions
* Radiology tests

Once added, these favorites should be:

* Easily accessible in future sessions
* Visible directly in selection forms for quick entry

### 2. Facility-level configuration

Each facility should be able to define and manage its own available service lists, such as:

* Lab tests offered
* Procedures available
* Radiology tests available
* Prescriptions or medication templates (where applicable)

Facilities may not offer all possible items, so the system should allow them to configure only what they provide.

### 3. Data visibility layers

Each module (lab, radiology, procedures, prescriptions, diagnoses) should support three structured sources:

| Source            | Description                        |
| ----------------- | ---------------------------------- |
| Favorites         | User-defined frequently used items |
| Facility-specific | Items configured by the facility   |
| Global list       | Full system-wide catalog           |

Users should be able to switch or search across these layers when entering data.

### 4. Configuration structure

These settings should be organized logically in the system:

* Facility setup → facility-specific service configuration
* Lab settings / lab configuration → lab-specific tests and rules
* Clinical settings → prescriptions, diagnoses, procedures configuration

### 5. Expected outcome

* Faster data entry with fewer clicks
* Reduced clutter by filtering irrelevant items per facility
* Personalized workflow through favorites
* Flexible configuration per healthcare institution

Ensure these changes are applied on the backend and frontend.
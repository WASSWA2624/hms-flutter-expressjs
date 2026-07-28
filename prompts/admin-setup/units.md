On the **Units** screen, the system incorrectly displays **"No units have been added. Create at least one department before adding units."** even when departments already exist. This should be fixed.

### Access by Account Type

The screen is accessible to three account types, each with different data visibility:

* **Platform Admin** – Has unrestricted access to **all tenants, facilities, departments, and units** across the platform.
* **Tenant Admin** – Has access only to **their tenant**, including all facilities, departments, and units within that tenant.
* **Facility Admin** – Has access only to **their assigned facility**, including its departments and units.

The Units list should display only the data the logged-in user is authorized to access.

### Create Unit

Clicking **Create Unit** should open the **Create Unit** dialog.

The form should adapt based on the user's account type:

* **Platform Admin:** Select **Tenant → Facility → Department**.
* **Tenant Admin:** Tenant is preselected; select **Facility → Department**.
* **Facility Admin:** Tenant and Facility are preselected; select **Department** only.

Before creating a unit, perform a **comprehensive similarity check** against existing units within the relevant scope. The check should:

* Open a **dedicated modal dialog** to display the results, **regardless of whether matches are found**.
* Display a clear summary, including the overall outcome and the highest similarity score.
* Show similarity percentages for all relevant matches.
* Detect spelling variations, typos, abbreviations, word order differences, and other closely matching names.
* Clearly indicate when **no similar units** are found.
* Allow the user to review the results before proceeding with or cancelling the creation.
* Prevent accidental duplicate unit creation based on configured validation rules.

### Edit Unit

Each unit should have an **Edit** button.

The edit flow should:

* Follow the same validation rules as unit creation.
* Perform the same similarity check.
* Compare against **all other units within the user's accessible scope**, excluding the unit being edited.
* Display the similarity results in the same dedicated modal dialog before saving changes.

### Delete Unit

Each unit should have a **Delete** button.

Deletion should:

* Use **soft delete** only.
* Include confirmation before deletion.
* Be safe, robust, and provide appropriate error handling.

### User Interface

* Use a clean, modern, and responsive design.
* On **large screens**, arrange form fields into multiple columns.
* On **small screens**, stack form fields vertically in a single column.
* Display only the controls and selection fields relevant to the logged-in user's account type.

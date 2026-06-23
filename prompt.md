### Lab Module – Refined Requirements

In the lab module, when a patient has requested lab tests (single tests or panels), the system should provide a highly efficient and user-friendly interface for entering and managing results.

#### 1. Core Result Entry Workflow

* Support both **single tests and test panels**
* Allow **fast result entry in batch or individual mode**
* Each test should clearly show:

  * Test name
  * Expected unit (descriptive and context-aware)
  * Reference range (auto-applied based on patient context)

#### 2. Result States & Actions

Each test or batch should support the following actions:

* Save as draft
* Submit results
* Verify results
* Reject tests/results
* Remove results

#### 3. Partial Save Handling

* The system must allow **partial saves in batch operations**
* If some tests are incomplete or invalid:

  * Valid entries are saved normally
  * Invalid/missing entries are flagged but do not block the rest

#### 4. Real-Time Updates

* Once results are submitted or verified:

  * The requesting doctor should receive **real-time updates/notifications**
  * Updates should be tied directly to the patient and the original test request
  * Changes must reflect immediately in the doctor’s view

#### 5. Clinical Reference Ranges

* The system must support **dynamic reference ranges based on:**

  * Patient age group
  * Sex
  * Clinical configuration rules
* When entering results:

  * Appropriate reference ranges should auto-populate
  * Abnormal values should be automatically flagged with annotations
* Users may override ranges or interpretations manually if needed

#### 6. Test Configuration & Reusability

* Support **facility-specific, tenant-specific, and user-specific test setups**
* Include a concept of:

  * Favorite or frequently used tests
  * Configurable templates for common lab workflows

#### 7. UX & Automation Goals

* Minimize manual input as much as possible
* Automate:

  * Unit selection
  * Reference range assignment
  * Result interpretation hints
* Still allow full manual override where necessary for clinical flexibility

#### 8. Design Principle

The overall goal is:

* High-speed data entry for lab staff
* Minimal cognitive load
* Maximum automation with safe manual control when required

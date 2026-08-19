# HMS Financial Modules: Billing, Accounts & Finance, and Insurance & Claims

## 1. Purpose and scope

A comprehensive Hospital Management System (HMS) needs more than journals, ledgers, invoices, and receipts. Its financial capabilities should be exposed through three separate top-level menu items:

1. **Billing** — retain the existing menu name.
2. **Accounts & Finance** — rename the existing **Accounts** menu.
3. **Insurance & Claims** — rename the existing **Insurance Claims** menu.

Together, these modules should connect:

- Patient billing and collections
- Insurance and corporate claims
- General accounting
- Procurement and supplier payments
- Expense management
- Cash and bank management
- Budgeting and financial reporting

> **Core principle:** Record each financial event once, then carry it through the relevant subledger, general ledger, and financial reports.

This document defines the recommended functional scope, information flows, navigation and tab structure, and core data relationships for these modules.

## 2. Design principles

1. **Use double-entry accounting.** Every posted transaction must produce balanced debit and credit journal lines.
2. **Keep source documents traceable.** Each journal entry should link to the invoice, payment, receipt, claim, purchase, expense, or adjustment that created it.
3. **Separate transactions from evidence.** For example, a payment records the movement of money; a receipt proves that an incoming payment was received.
4. **Use subledgers.** Patient, supplier, insurance, cash, bank, inventory, and asset activity should reconcile with their general-ledger control accounts.
5. **Control posting.** Use draft, review, approval, posting, reversal, and period-locking workflows.
6. **Preserve posted history.** Correct posted transactions with reversals, credit notes, or debit notes instead of silently editing or deleting them.
7. **Support allocations.** A payment may settle one or many invoices, and an invoice may be settled by one or many payments.
8. **Make actions auditable.** Store who created, approved, posted, reversed, or refunded each transaction, together with timestamps and reasons.
9. **Preserve module ownership.** Billing, accounting, and insurance should exchange references and posting events without duplicating each other's authoritative records.

## 3. Core accounting foundation

### 3.1 Chart of Accounts

The Chart of Accounts (COA) defines the hospital's financial structure and is the foundation for journals, ledgers, and reports.

Recommended account groups include:

- **Assets**
  - Cash
  - Bank
  - Accounts receivable
  - Inventory
  - Medical equipment
  - Buildings
- **Liabilities**
  - Accounts payable
  - Loans
  - Taxes payable
  - Salaries payable
- **Equity**
  - Owner's capital
  - Retained earnings
- **Revenue**
  - Consultation revenue
  - Laboratory revenue
  - Pharmacy revenue
  - Admission revenue
  - Surgery revenue
- **Expenses**
  - Salaries
  - Rent
  - Utilities
  - Medical supplies
  - Maintenance
  - Transport

Each account should define:

- Account code and name
- Account type and parent account
- Normal balance
- General-ledger or control-account role
- Department or cost-centre restrictions, where applicable
- Currency, where applicable
- Active/inactive status

### 3.2 Journals

Journals record financial transactions chronologically before or as they are posted to the ledger.

Recommended journal types:

- General journal
- Sales/revenue journal
- Purchase journal
- Cash receipts journal
- Cash payments journal
- Adjustment journal
- Payroll journal
- Inventory/stock journal
- Patient billing journal
- Insurance journal
- Asset journal

A journal entry should contain:

- Entry date and accounting period
- Journal and reference number
- Description
- Source module and source-document reference
- Currency and exchange rate, where applicable
- Patient/customer, supplier, insurer, department, or cost centre, where applicable
- Created, reviewed, approved, and posted by
- Status
- Supporting documents or attachments

Each journal entry should have two or more lines containing:

- Account
- Debit or credit amount
- Line description
- Patient/customer, supplier, insurer, department, or cost centre, where applicable

The total debits and credits must be equal before an entry can be posted.

### 3.3 Ledgers

Ledgers organize posted journal lines by account or party. They should be generated from posted transactions rather than maintained as separate, disconnected records.

The module should support:

- General ledger
- Accounts receivable ledger
- Accounts payable ledger
- Patient ledger
- Supplier ledger
- Cash ledger
- Bank ledger
- Inventory ledger
- Asset ledger
- Insurance/corporate ledger

A ledger view should show:

- Opening balance
- Transaction date
- Source document and reference
- Description
- Debit
- Credit
- Running balance

Typical uses include:

- **Cash account:** opening balance, receipts, payments, transfers, and closing balance
- **Pharmacy revenue:** sales, returns, adjustments, and current balance
- **Patient receivables:** charges, adjustments, payments, and outstanding balance

### 3.4 Accounting periods and posting controls

The accounting foundation should also include:

- Fiscal years and accounting periods
- Open, closed, and locked period statuses
- Numbering sequences for financial documents
- Recurring and reversing journal entries
- Posting validation and balancing rules
- Role-based posting and approval permissions

## 4. Patient billing and revenue cycle

### 4.1 Charges and invoices

Invoices represent amounts owed to the hospital. They may be generated from:

Consultations

Laboratory services

Radiology

Procedures and surgery

Admissions and bed charges

Pharmacy

Medical supplies

Ambulance services

Theatre services

Doctor services

Insurance claims

Corporate services

An invoice header should contain:

- Invoice number and date
- Patient/customer
- Encounter, admission, or source reference
- Payer: self, insurer, corporate client, or another sponsor
- Payment terms and due date
- Currency
- Status
- Issued and approved by

Each invoice line should contain:

- Service or item
- Quantity
- Unit price
- Discount
- Tax
- Line total
- Department or revenue account

Invoice totals should show:

- Subtotal
- Total discounts
- Total taxes
- Grand total
- Amount paid
- Balance due

Recommended invoice statuses are draft, issued, partially paid, paid, overdue, cancelled, and written off.

### 4.2 Payments, allocations, and receipts

These records have distinct responsibilities:

- A **payment** records an incoming or outgoing movement of money.
- A **payment allocation** applies some or all of a payment to one or more invoices or other obligations.
- A **receipt** is the document issued as evidence that the hospital received money.

The system should support:

- Patient payments
- Insurance and corporate payments
- Supplier and staff payments
- Advance/deposit payments
- Partial payments
- Refunds
- Unallocated payments
- Payment reallocations

Supported payment methods may include:

- Cash
- Bank transfer or deposit
- Mobile money
- Debit or credit card
- Cheque
- Insurance remittance

A receipt should contain:

- Receipt number
- Payment and invoice references
- Patient/customer or payer
- Amount and currency
- Payment method
- External transaction/reference number
- Date and time
- Cashier or receiving account
- Received by
- Description
- Remaining balance, where applicable

Receipt types may include cash, bank, mobile money, card, insurance, partial-payment, advance/deposit, and refund receipts.

### 4.3 Credit notes and debit notes

Credit and debit notes correct or adjust invoices without changing the original posted document.

Use a **credit note** when:

- A patient was overcharged
- A service was cancelled
- An item was returned
- A discount was applied after invoicing

Use a **debit note** when:

- An additional charge is required
- Under-billing must be corrected
- An additional service was provided

Each note should reference the original invoice, state the reason, follow an approval workflow, and produce the appropriate journal entry.

### 4.4 Accounts receivable

Accounts receivable tracks money owed to the hospital by patients, insurers, corporate clients, and other debtors.

Typical patient flow:

> Patient → Invoice → Partial or full payment → Allocation → Remaining balance

Typical insurer/corporate flow:

> Payer → Claim or invoice → Approved amount → Payment → Allocation → Outstanding amount

The module should support:

- Open balances by payer
- Due dates and payment terms
- Aging analysis
- Statements
- Follow-up and collection notes
- Credit limits, where applicable
- Write-offs with approval

### 4.5 Patient account and statement

A patient account should provide the complete financial history across encounters, invoices, adjustments, payments, and refunds.

| Date  | Description  | Debit (UGX) | Credit (UGX) | Balance (UGX) |
| ----- | ------------ | ----------: | -----------: | ------------: |
| Aug 1 | Consultation |      30,000 |           — |        30,000 |
| Aug 1 | Laboratory   |      50,000 |           — |        80,000 |
| Aug 1 | Payment      |          — |       50,000 |        30,000 |

Users should be able to filter the statement by date, encounter, facility, payer, and status, then print or export it.

### 4.6 Insurance and claims

The insurance module should track:

- Insurance companies and corporate payers
- Patient policies and memberships
- Coverage rules and limits
- Pre-authorizations
- Claims and claim items
- Submitted, approved, rejected, paid, and outstanding amounts
- Rejection and adjustment reasons
- Claim status and submission history
- Remittances and payment allocations

### 4.7 Refunds and advances

Refund processing should cover:

- Patient overpayments
- Cancelled services
- Returned deposits
- Insurance adjustments
- Duplicate or incorrect payments

Refunds should require authorization, retain the reason and original payment reference, and produce reversal or refund journal entries. Advance payments should remain as customer liabilities until they are allocated to an invoice or refunded.

## 5. Procurement, suppliers, and expenditure

### 5.1 Purchases and suppliers

The recommended procurement flow is:

> Purchase Requisition → Purchase Order → Goods Received Note → Supplier Invoice → Payment

This flow is especially important for:

- Medicines
- Laboratory supplies
- Medical consumables
- Equipment
- Stationery
- Maintenance parts

Each document should retain links to the preceding and following documents so users can trace quantities, costs, approvals, deliveries, invoices, and payments.

### 5.2 Accounts payable

Accounts payable tracks money the hospital owes suppliers and other creditors.

> Supplier → Invoice → Credit/debit note → Payment → Allocation → Outstanding balance

The module should support:

- Supplier balances and statements
- Invoice due dates
- Payment scheduling
- Aging analysis
- Partial and batch payments
- Withholding taxes, where applicable
- Payment approvals

### 5.3 Expense management

A dedicated expense workflow should capture recurring and ad hoc costs such as:

- Utilities
- Rent
- Salaries
- Internet
- Fuel and transport
- Medical supplies
- Equipment maintenance
- Cleaning and security
- Office supplies

An expense record should include the expense category/account, department or cost centre, supplier/payee, amount, tax, date, payment method, supporting documents, and approval status. Approved expenses should automatically feed the accounting system.

## 6. Cash and bank management

### 6.1 Cashier and cash management

Hospitals commonly operate several cash points, such as:

- Main reception
- Outpatient department
- Pharmacy
- Laboratory
- Radiology
- Accounts office

Each cashier session should track:

- Cash point and cashier
- Opening cash
- Receipts and payments
- Refunds
- Cash transfers
- Expected closing cash
- Counted closing cash
- Cash variance and explanation
- Supervisor approval

The system should support cashier handover, denomination counts, end-of-day closure, and reconciliation with issued receipts.

### 6.2 Bank accounts and reconciliation

Bank management should include:

- Bank accounts
- Deposits and withdrawals
- Internal transfers
- Bank charges and interest
- Statement imports
- Matched and unmatched transactions
- Bank reconciliation
- Reconciliation history

Deposits should be traceable back to cashier collections, and reconciled bank movements should produce or link to the relevant journal entries.

## 7. Planning, reporting, and financial control

### 7.1 Budgets

Budgeting should support:

- Annual budgets
- Department budgets
- Project budgets
- Budget revisions and approvals
- Commitments, actuals, and remaining balances
- Actual-versus-budget reporting
- Budget variance analysis

Example:

> Pharmacy budget: UGX 50 million
> Actual expenditure: UGX 43 million
> Remaining budget: UGX 7 million

### 7.2 Financial reports

The HMS should generate reports directly from posted accounting and subledger data.

**Core financial statements**

- Trial balance
- Income statement/profit and loss
- Balance sheet
- Cash flow statement
- General ledger

**Receivables and payables**

- Accounts receivable aging
- Accounts payable aging
- Patient and payer balances
- Supplier balances
- Collections and outstanding claims

**Operational finance**

- Revenue by service, department, provider, and facility
- Patient revenue
- Pharmacy revenue
- Expense analysis
- Budget versus actual
- Insurance claims

**Cash, compliance, and audit**

- Daily cashier report
- End-of-day report
- Bank reconciliation report
- Tax report
- Financial audit report

Reports should support date, facility, department, payer, account, currency, and status filters, subject to role permissions.

### 7.3 Internal controls and auditability

At minimum, the module should provide:

- Role-based access and segregation of duties
- Configurable approval limits
- Maker-checker workflows
- Period locks
- Unique document numbering
- Required reasons for voids, reversals, write-offs, and refunds
- Complete change and posting history
- Attachment retention
- Cash, bank, receivable, payable, and subledger reconciliations
- Exception reporting for unbalanced, unallocated, overdue, or unreconciled items

## 8. Integrated transaction flows

Finance features should not operate as isolated screens. Recommended end-to-end flows include:

### 8.1 Self-pay patient

> Clinical Service → Charge → Invoice → Payment → Allocation → Receipt → Journal Entry → Ledger → Financial Reports

### 8.2 Insured or corporate patient

> Clinical Service → Charge → Pre-authorization/Claim → Approval → Insurer Payment → Allocation → Journal Entry → Ledger → Financial Reports

### 8.3 Procurement

> Purchase Requisition → Purchase Order → Goods Received Note → Supplier Invoice → Payment → Journal Entry → Ledger → Financial Reports

### 8.4 Direct expense

> Expense Request → Approval → Payment → Journal Entry → Ledger → Financial Reports

### 8.5 Cashier closure

> Open Cashier Session → Receive Payments → Issue Receipts → Count Cash → Reconcile → Approve Closure → Deposit to Bank

## 9. Application menu and tab structure

### 9.1 Navigation rules

The application sidebar should expose **Billing**, **Accounts & Finance**, and **Insurance & Claims** as three independent first-level menu items. Billing and insurance must not be nested under Accounts & Finance.

Apply these rules consistently:

1. **Every** finance menu — Billing, Accounts & Finance, and Insurance & Claims — is expandable and nests exactly **one level**. Expanding a menu reveals its category menu items; selecting a category opens the workspace on that category's first authorized section.
2. The third level is a **tab in the workspace**, not a menu item. Each category renders one flat tab strip built from `frontend/lib/shared/components/app_tab_strip.dart`, holding that category's sections.
3. Never add a second sidebar nesting level, a category tab row above the section strip, or the `nested` tab-strip variant. Where a menu tree shows a fourth level (`General Accounting → Journal Entries → …`), those entries flatten into the same tab strip.
4. Every permanent tab represents a searchable, filterable data table or worklist. The required columns are defined in Section 10.
5. Create, edit, approve, post, allocate, reconcile, close, and reverse operations are actions from a table row or toolbar; they are not permanent menu tabs.
6. Forms open in a drawer, modal, or contextual record tab, then return the user to the originating table after completion.
7. Reopening the same destination focuses its existing tab or menu item instead of creating a duplicate.
8. Record-specific tabs may open from a table, for example `Invoice INV-000123` or `Claim CLM-000045`.
9. Tabs and menu-item sections preserve filters, sorting, pagination, selected columns, and unsaved state while open.
10. Tabs are closable, reorderable, deep-linkable, and restorable after an accidental refresh where practical.
11. The active sidebar entry, active tab, page title, and breadcrumb remain synchronized.
12. Menu entries, tabs, actions, totals, and badges respect role, tenant, and facility permissions.
13. Worklist tabs and leaf menu items may show badges such as pending approvals, overdue balances, rejected claims, or unreconciled transactions.
14. Cross-module links open the authoritative record's tab instead of creating a duplicate copy in another module.
15. Never build a new menu item, tab, table, model, route, or service for a capability the codebase already implements. Section 13 defines the reuse audit that precedes any finance implementation work.

### 9.2 Billing

Keep the existing menu name **Billing**. It owns patient and customer charging, invoicing, collection, allocation, adjustment, and receivable follow-up.

Like every finance menu, it nests exactly one level. The first indentation level below the menu is a **category menu item**; its children are **tabs** in the workspace tab strip.

```text
BILLING
│
├── Overview
│   └── Overview
│
├── Setup & Pricing
│   ├── Price Lists & Tariffs
│   ├── Packages & Bundles
│   ├── Billing Rules
│   ├── Discount Rules
│   ├── Tax Rules
│   └── Document Templates
│
├── Charges & Invoicing
│   ├── Charges
│   ├── Unbilled Charges
│   ├── Estimates & Quotations
│   ├── Invoices
│   ├── Credit Notes
│   └── Debit Notes
│
├── Payments & Receipts
│   ├── Payments
│   ├── Payment Allocations
│   ├── Receipts
│   ├── Advances & Deposits
│   ├── Refunds
│   └── Write-offs
│
├── Accounts & Collections
│   ├── Patient Accounts
│   ├── Patient Statements
│   ├── Receivables
│   └── Collection Follow-up
│
└── Billing Reports
    └── Billing Reports
```

### 9.3 Accounts & Finance

Rename the existing **Accounts** menu to **Accounts & Finance**. It must be an expandable first-level menu with nested, permission-aware submenu entries. It owns the accounting books, payables, expenditure, treasury, assets, budgets, period close, compliance, and financial reporting.

The tree below spans two surfaces. The first indentation level is a **nested sidebar menu item** — the only nesting the menu allows. Everything below it is a **tab in the workspace page**, rendered as one flat strip per category. Adding a second menu level, or a category tab row above the section strip, violates rule 3 in Section 9.1.

Currency handling is deliberately absent from this menu. The application already resolves currency from the tenant/facility setup defaults and formats and converts amounts through existing shared code; Accounts & Finance must reuse that, not introduce a currency registry tab of its own.

```text
ACCOUNTS & FINANCE
│
├── Overview
│   └── Overview
│
├── General Accounting
│   ├── Chart of Accounts
│   ├── Journal Entries (flattened into the General Accounting tab strip)
│   │   ├── All Journal Entries
│   │   ├── General Journal
│   │   ├── Sales Journal
│   │   ├── Purchase Journal
│   │   ├── Cash Receipts Journal
│   │   ├── Cash Payments Journal
│   │   ├── Adjustment Journal
│   │   ├── Payroll Journal
│   │   ├── Inventory Journal
│   │   └── Asset Journal
│   ├── General Ledger
│   ├── Control Accounts
│   ├── Recurring Entries
│   └── Reversing Entries
│
├── Purchases & Payables
│   ├── Suppliers
│   ├── Purchase Requisitions
│   ├── Purchase Orders
│   ├── Goods Received Notes
│   ├── Supplier Invoices
│   ├── Supplier Adjustments
│   ├── Payment Runs
│   ├── Supplier Payments
│   ├── Supplier Statements
│   ├── AP Aging
│   └── AP Reconciliation
│
├── Expenses
│   ├── Expense Entries
│   ├── Expense Requests
│   ├── Expense Approvals
│   ├── Recurring Expenses
│   ├── Staff Reimbursements
│   ├── Expense Categories
│   └── Expense Analysis
│
├── Cash Management
│   ├── Cash Points
│   ├── Cashier Sessions
│   ├── Cash Transactions
│   ├── Cash Transfers
│   ├── Cash Counts
│   ├── Session Closures
│   ├── Cash Variances
│   └── Cash Reconciliation
│
├── Bank Management
│   ├── Bank Accounts
│   ├── Bank Transactions
│   ├── Bank Deposits
│   ├── Withdrawals & Charges
│   ├── Bank Transfers
│   ├── Statement Imports
│   ├── Matching Workbench
│   └── Bank Reconciliations
│
├── Fixed Assets
│   ├── Asset Register
│   ├── Asset Categories
│   ├── Asset Acquisitions
│   ├── Depreciation Runs
│   ├── Asset Transfers
│   ├── Revaluations
│   ├── Disposals
│   └── Asset Ledger
│
├── Budgets & Cost Control
│   ├── Annual Budgets
│   ├── Department Budgets
│   ├── Project Budgets
│   ├── Budget Revisions
│   ├── Commitments
│   ├── Budget vs Actual
│   └── Variance Analysis
│
├── Tax & Compliance
│   ├── Tax Codes & Rates
│   ├── Tax Transactions
│   ├── Withholding Tax
│   ├── Tax Returns
│   ├── Regulatory Reports
│   └── Audit Schedules
│
├── Period Close
│   ├── Close Checklist
│   ├── Reconciliation Checklist
│   ├── Period Adjustments
│   ├── Reopen Requests
│   ├── Close History
│   └── Year-end Close Runs
│
├── Financial Reports
│   ├── Trial Balance
│   ├── Income Statement
│   ├── Balance Sheet
│   ├── Cash Flow Statement
│   ├── General Ledger Report
│   ├── Revenue & Expense Analysis
│   ├── Department Performance
│   ├── Cashier & Bank Reports
│   └── Consolidated Reports
│
├── Setup & Controls
│   ├── Fiscal Years & Periods
│   ├── Payment Methods
│   ├── Document Numbering
│   ├── Departments & Cost Centres
│   ├── Posting Rules
│   ├── Approval Rules
│   ├── Opening Balances
│   └── Integration Mappings
│
└── Audit Trail
    ├── Transaction History
    ├── Approval History
    ├── Posting History
    ├── Reversals & Voids
    └── Data Exports
```

### 9.4 Insurance & Claims

Rename the existing **Insurance Claims** menu to **Insurance & Claims**. It owns insurer and corporate-payer administration, eligibility, pre-authorization, claims, adjudication results, remittances, denials, and payer follow-up.

It nests exactly one level: category menu items, then tabs.

```text
INSURANCE & CLAIMS
│
├── Overview
│   └── Overview
│
├── Payers & Contracts
│   ├── Insurance Providers
│   ├── Corporate Payers
│   ├── Plans & Products
│   ├── Contracts
│   └── Tariffs & Price Lists
│
├── Coverage & Claim Rules
│   ├── Coverage Rules
│   ├── Exclusions & Limits
│   ├── Required Documents
│   ├── Denial Codes
│   ├── Submission Channels
│   ├── Claim Templates
│   └── Claim Rules
│
├── Membership & Eligibility
│   ├── Patient Policies
│   ├── Members & Dependants
│   ├── Eligibility Checks
│   ├── Coverage Balances
│   └── Pre-authorizations
│
├── Claims Processing
│   ├── Claims
│   ├── Claim Validations
│   ├── Claim Batches
│   ├── Claim Submissions
│   ├── Adjudications
│   ├── Denials
│   └── Resubmissions & Appeals
│
├── Remittances & Reconciliation
│   ├── Remittance Advice
│   ├── Insurer Payments
│   ├── Remittance Allocations
│   ├── Payer Balances
│   └── Claim Reconciliation
│
├── Payer Follow-up
│   ├── Payer Statements
│   ├── Claims Aging
│   ├── Collection Follow-up
│   └── Disputes
│
└── Insurance Reports
    └── Insurance Reports
```

### 9.5 Module boundaries and hand-offs

- **Billing → Accounts & Finance:** Posted invoices, payments, allocations, credit/debit notes, refunds, and write-offs create balanced accounting events.
- **Billing → Insurance & Claims:** Insured charges and supporting clinical documents become pre-authorization or claim inputs.
- **Insurance & Claims → Billing:** Coverage decisions determine patient, insurer, and corporate-payer responsibility.
- **Insurance & Claims → Accounts & Finance:** Approved claims, remittances, denials, and adjustments update receivable control accounts and journals.
- **Accounts & Finance → all financial modules:** Accounts, periods, currencies, payment methods, posting rules, and close status are shared as controlled reference data.
- A cross-module link should open the source record in its owning module's tab while preserving the user's current tabs.

## 10. Tabular workspaces and table columns

### 10.1 Shared table requirements

Every permanent tab defined in Section 9 must render a primary table or worklist. Creation and processing forms are launched from the table toolbar or row actions rather than being permanent tabs.

All tables should provide:

- Server-side search, filtering, sorting, and pagination
- Sticky headers and frozen identifying columns
- Column chooser, column reordering, density control, and saved views
- Date-range, facility, department, payer, currency, owner, and status filters where applicable
- Bulk selection and permission-aware bulk actions
- Subtotals and grand totals for monetary columns
- Export to CSV/XLSX/PDF, subject to permissions
- Print support where the record is a formal document
- Loading, empty, error, and partial-data states
- Responsive layouts with horizontal scrolling for wide financial tables
- A consistent row-action column for view, edit, approve, post, print, export, reverse, void, or reconcile actions as permitted

Unless inapplicable, operational tables should also include **Select**, **Reference**, **Facility**, **Status**, **Created At**, **Created By**, **Updated At**, **Updated By**, and **Actions**. Monetary tables must show **Currency**, right-align amounts, use the configured decimal precision, and display totals for the current filtered result.

### 10.2 Billing tab tables

- **Overview** — Queue/Metric, Current Count, Total Value, Currency, Today, Month to Date, Overdue Count, Oldest Item Age, Assigned Team, SLA Status, Trend, Last Refreshed
- **Charges** — Charge No., Charge Date/Time, Patient No., Patient Name, Encounter No., Visit Type, Department, Service/Item Code, Service/Item Description, Quantity, Unit Price, Discount, Tax, Net Amount, Payer Type, Payer, Invoice No., Charge Status, Charged By
- **Unbilled Charges** — Charge No., Charge Date/Time, Patient No., Patient Name, Encounter No., Department, Service/Item, Quantity, Net Amount, Payer, Eligibility Status, Billing Hold Reason, Age, Responsible User, Selected for Billing
- **Estimates & Quotations** — Estimate No., Estimate Date, Valid Until, Patient/Customer, Encounter No., Payer, Item Count, Subtotal, Discount, Tax, Total, Currency, Approval Status, Conversion Status, Invoice No., Prepared By
- **Packages & Bundles** — Package Code, Package Name, Category, Included Services, Included Quantity, Standard Price, Package Price, Discount Value, Payer/Price List, Effective From, Effective To, Usage Limit, Status
- **Invoices** — Invoice No., Invoice Date, Due Date, Patient/Customer, Patient No., Encounter No., Payer Type, Payer, Subtotal, Discount, Tax, Total, Paid Amount, Allocated Amount, Balance, Currency, Aging Days, Invoice Status, Issued By
- **Payments** — Payment No., Payment Date/Time, Patient/Customer, Payer, Payment Method, Provider/Bank, External Reference, Amount, Allocated Amount, Unallocated Amount, Currency, Cash Point/Bank Account, Receipt No., Reversal Status, Payment Status, Received By
- **Payment Allocations** — Allocation No., Allocation Date, Payment No., Invoice No., Patient/Customer, Payer, Invoice Total, Balance Before, Allocated Amount, Balance After, Currency, Allocation Status, Allocated By, Reversal Reference, Reversal Reason
- **Receipts** — Receipt No., Receipt Date/Time, Payment No., Invoice Reference(s), Patient/Customer, Payer, Payment Method, External Reference, Amount, Currency, Cash Point, Cashier, Remaining Balance, Print Count, Delivery Method, Receipt Status
- **Advances & Deposits** — Advance No., Receipt Date, Patient/Customer, Payer, Payment No., Original Amount, Allocated Amount, Refunded Amount, Available Balance, Currency, Expiry Date, Last Allocation Date, Advance Status, Received By
- **Credit Notes** — Credit Note No., Note Date, Original Invoice No., Patient/Customer, Payer, Reason Code, Reason, Subtotal, Tax, Total Credit, Applied Amount, Remaining Credit, Currency, Approval Status, Journal Entry No., Approved By
- **Debit Notes** — Debit Note No., Note Date, Original Invoice No., Patient/Customer, Payer, Reason Code, Reason, Subtotal, Tax, Total Debit, Applied Amount, Remaining Debit, Currency, Approval Status, Journal Entry No., Approved By
- **Refunds** — Refund No., Request Date, Original Payment No., Receipt No., Patient/Customer, Payer, Reason Code, Requested Amount, Approved Amount, Refunded Amount, Currency, Refund Method, External Reference, Refund Status, Requested By, Approved By, Processed By, Journal Entry No.
- **Write-offs** — Write-off No., Request Date, Invoice No., Patient/Customer, Payer, Invoice Balance, Requested Amount, Approved Amount, Currency, Write-off Category, Reason, Approval Status, Approved By, Journal Entry No., Posted Date
- **Patient Accounts** — Account No., Patient No., Patient Name, Primary Payer, Last Encounter No., Last Encounter Date, Total Charges, Adjustments, Payments, Credits, Current Balance, Current, 1–30 Days, 31–60 Days, 61–90 Days, Over 90 Days, Last Activity, Account Status
- **Patient Statements** — Transaction Date/Time, Account No., Patient No., Patient Name, Encounter No., Transaction Type, Document Reference, Description, Payer, Debit, Credit, Running Balance, Currency, Posting Status
- **Receivables** — Debtor Account No., Patient/Customer/Payer, Debtor Type, Open Invoice Count, Current Amount, 1–30 Days, 31–60 Days, 61–90 Days, Over 90 Days, Total Outstanding, Currency, Oldest Due Date, Days Overdue, Credit Limit, Collection Status, Assigned Collector
- **Collection Follow-up** — Collection Case No., Debtor, Debtor Type, Outstanding Amount, Currency, Oldest Invoice No., Maximum Days Overdue, Priority, Last Contact Date, Last Contact Method, Promise Date, Promise Amount, Next Follow-up Date, Assigned Collector, Follow-up Status, Notes
- **Price Lists & Tariffs** — Price List Code, Price List Name, Payer/Customer Group, Service/Item Code, Service/Item Name, Department, Standard Price, Contract Price, Discount Ceiling, Tax Code, Currency, Effective From, Effective To, Version, Status
- **Billing Rules** — Rule Code, Rule Name, Rule Type, Facility Scope, Payer Scope, Service Scope, Trigger Event, Condition Summary, Action Summary, Priority, Effective From, Effective To, Version, Status, Last Changed By
- **Discount Rules** — Rule Code, Rule Name, Discount Type, Percentage/Fixed Value, Maximum Amount, Patient/Payer Scope, Service/Department Scope, Minimum Amount, Approval Required, Approver Role, Effective From, Effective To, Status
- **Tax Rules** — Tax Code, Tax Name, Tax Type, Rate, Inclusive/Exclusive, Recoverable, Service/Item Scope, Payer Exemption, GL Account, Effective From, Effective To, Jurisdiction, Status
- **Document Templates** — Template Code, Template Name, Document Type, Facility, Language, Page Size, Header/Footer Version, Numbering Sequence, Default Template, Effective From, Effective To, Last Published At, Published By, Status
- **Billing Reports** — Report Name, Report Category, Description, Default Period, Available Filters, Default Grouping, Last Generated At, Generated By, Output Format, Row Count, Schedule, Delivery Recipients, Report Status

### 10.3 Accounts & Finance tab tables

#### 10.3.1 Overview and general accounting

- **Overview** — Queue/Metric, Current Count, Debit Value, Credit Value, Net Value, Currency, Current Period, Exceptions, Pending Approvals, Unposted Items, Unreconciled Items, Oldest Item Age, Responsible Team, Last Refreshed
- **Chart of Accounts** — Account Code, Account Name, Account Type, Parent Account, Normal Balance, Control Account, Subledger Type, Currency, Department/Cost Centre Required, Opening Balance, Current Balance, Posting Allowed, Reconciliation Required, Effective From, Status
- **All Journal Entries, General Journal, Sales Journal, Purchase Journal, Cash Receipts Journal, Cash Payments Journal, Adjustment Journal, Payroll Journal, Inventory Journal, and Asset Journal** — Entry No., Journal Type, Entry Date, Posting Date, Fiscal Period, Source Module, Source Document Type, Source Reference, Description, Total Debit, Total Credit, Difference, Currency, Department, Cost Centre, Entry Status, Approval Status, Created By, Approved By, Posted By
- **General Ledger** — Posting Date, Fiscal Period, Account Code, Account Name, Entry No., Journal Type, Source Module, Document Reference, Line Description, Party Type, Party, Department, Cost Centre, Debit, Credit, Running Balance, Currency, Posted By
- **Control Accounts** — Control Account Code, Control Account Name, Subledger, GL Balance, Subledger Balance, Difference, Currency, Last Reconciled At, Reconciliation Reference, Exception Count, Responsible Owner, Reconciliation Status
- **Recurring Entries** — Template No., Template Name, Journal Type, Description, Frequency, Start Date, Next Run Date, End Date, Total Debit, Total Credit, Currency, Auto-post, Approval Required, Last Generated Entry, Last Run Status, Template Status
- **Reversing Entries** — Reversal No., Original Entry No., Original Posting Date, Reversal Date, Fiscal Period, Journal Type, Reason Code, Reason, Debit, Credit, Currency, Reversal Entry No., Requested By, Approved By, Reversal Status

#### 10.3.2 Purchases and payables

- **Suppliers** — Supplier No., Supplier Name, Supplier Type, Tax ID, Contact Person, Phone, Email, Address, Payment Terms, Default Currency, Credit Limit, Current AP Balance, Bank Account Summary, On Hold, Last Transaction Date, Supplier Status
- **Purchase Requisitions** — Requisition No., Request Date, Requested By, Department, Cost Centre, Required Date, Item Count, Estimated Amount, Currency, Budget Reference, Available Budget, Priority, Approval Level, Approval Status, Purchase Order No., Requisition Status
- **Purchase Orders** — PO No., PO Date, Supplier, Requisition Reference(s), Buyer, Expected Delivery Date, Item Count, Subtotal, Discount, Tax, Total, Currency, Received Amount, Invoiced Amount, Remaining Amount, Approval Status, PO Status
- **Goods Received Notes** — GRN No., Receipt Date, Supplier, PO No., Delivery Note No., Warehouse/Store, Item Count, Ordered Quantity, Received Quantity, Rejected Quantity, Accepted Value, Currency, Inspection Status, Received By, Posted Status
- **Supplier Invoices** — Supplier Invoice No., Internal Reference, Invoice Date, Due Date, Supplier, PO No., GRN No., Subtotal, Tax, Withholding Tax, Total, Paid Amount, Balance, Currency, Aging Days, Matching Status, Approval Status, Posting Status
- **Supplier Adjustments** — Adjustment No., Adjustment Type, Adjustment Date, Supplier, Supplier Invoice No., Reason Code, Description, Debit Amount, Credit Amount, Tax Effect, Currency, Approval Status, Journal Entry No., Posted Date
- **Payment Runs** — Run No., Run Date, Payment Date, Bank/Cash Account, Supplier Count, Invoice Count, Gross Amount, Discounts, Withholding Tax, Net Amount, Currency, Prepared By, Approval Status, Processing Status, Export Reference
- **Supplier Payments** — Payment No., Payment Date, Supplier, Payment Run No., Invoice Reference(s), Payment Method, Bank/Cash Account, External Reference, Gross Amount, Withholding Tax, Net Amount, Allocated Amount, Unallocated Amount, Currency, Approval Status, Payment Status, Processed By
- **Supplier Statements** — Transaction Date, Supplier, Document Type, Document Reference, Description, Due Date, Debit, Credit, Running Balance, Currency, Matching Reference, Posting Status
- **AP Aging** — Supplier No., Supplier Name, Open Invoice Count, Current Amount, 1–30 Days, 31–60 Days, 61–90 Days, Over 90 Days, Total Outstanding, Currency, Oldest Due Date, Maximum Days Overdue, On Hold, Payment Priority, Account Owner
- **AP Reconciliation** — Reconciliation No., Reconciliation Date, Supplier, Statement Balance, Subledger Balance, GL Balance, Unmatched Invoice Amount, Unmatched Payment Amount, Difference, Currency, Exception Count, Prepared By, Reviewed By, Reconciliation Status

#### 10.3.3 Expenses

- **Expense Entries** — Expense No., Expense Date, Expense Category, GL Account, Supplier/Payee, Department, Cost Centre, Project, Description, Net Amount, Tax, Gross Amount, Currency, Payment Method, Payment Reference, Receipt Attached, Approval Status, Posting Status
- **Expense Requests** — Request No., Request Date, Requested By, Payee, Expense Category, Department, Cost Centre, Purpose, Required Date, Requested Amount, Currency, Available Budget, Priority, Attachment Count, Current Approver, Request Status
- **Expense Approvals** — Request No., Request Date, Requester, Department, Expense Category, Purpose, Requested Amount, Currency, Approval Level, Current Approver, Submitted At, Waiting Time, Budget Check, Policy Exceptions, Decision Due, Approval Status
- **Recurring Expenses** — Schedule No., Expense Name, Supplier/Payee, Expense Category, GL Account, Department, Frequency, Next Due Date, End Date, Expected Amount, Currency, Auto-create, Approval Required, Last Expense No., Last Run Status, Schedule Status
- **Staff Reimbursements** — Claim No., Claim Date, Employee No., Employee Name, Department, Expense Category, Travel/Activity Reference, Claimed Amount, Approved Amount, Paid Amount, Currency, Receipt Count, Policy Exceptions, Approval Status, Payment No., Reimbursement Status
- **Expense Categories** — Category Code, Category Name, Parent Category, Default GL Account, Tax Code, Budget Required, Receipt Required, Approval Rule, Spending Limit, Allowed Payment Methods, Effective From, Effective To, Category Status
- **Expense Analysis** — Period, Expense Category, GL Account, Department, Cost Centre, Project, Supplier/Payee, Transaction Count, Actual Amount, Budget Amount, Committed Amount, Variance Amount, Variance Percentage, Currency, Prior-period Amount

#### 10.3.4 Cash management

- **Cash Points** — Cash Point Code, Cash Point Name, Facility, Department, Location, Default Currency, GL Account, Custodian, Allowed Payment Methods, Opening Float Limit, Maximum Balance, Active Session Count, Last Reconciled At, Cash Point Status
- **Cashier Sessions** — Session No., Business Date, Cash Point, Cashier, Opened At, Opening Float, Receipt Count, Cash Receipts, Non-cash Receipts, Cash Payments, Refunds, Transfers In, Transfers Out, Expected Cash, Counted Cash, Variance, Currency, Closed At, Session Status
- **Cash Transactions** — Transaction No., Date/Time, Session No., Cash Point, Cashier, Transaction Type, Source Module, Source Document, Patient/Payee, Description, Cash In, Cash Out, Running Balance, Currency, Receipt/Payment No., Transaction Status
- **Cash Transfers** — Transfer No., Request Date/Time, From Cash Point, From Session, To Cash Point/Bank, Transfer Amount, Currency, Reason, Requested By, Released By, Received By, Released At, Received At, Difference, Transfer Status
- **Cash Counts** — Count No., Count Date/Time, Session No., Cash Point, Cashier, Currency, Denomination, Quantity, Counted Value, System Expected Value, Total Counted, Variance, Counted By, Witnessed By, Count Status
- **Session Closures** — Closure No., Business Date, Session No., Cash Point, Cashier, Expected Cash, Counted Cash, Variance, Currency, Receipt Sequence From, Receipt Sequence To, Refund Total, Transfer Total, Variance Reason, Closed By, Approved By, Closure Status
- **Cash Variances** — Variance No., Business Date, Session No., Cash Point, Cashier, Expected Amount, Counted Amount, Variance Amount, Currency, Variance Type, Reason Code, Explanation, Investigation Owner, Resolution, Journal Entry No., Approval Status
- **Cash Reconciliation** — Reconciliation No., Business Date, Cash Point, Session Count, Receipt Total, System Cash Total, Counted Cash Total, Deposit Total, Outstanding Deposit, Difference, Currency, Exception Count, Prepared By, Reviewed By, Reconciliation Status

#### 10.3.5 Bank management

- **Bank Accounts** — Account Code, Bank Name, Branch, Account Name, Masked Account No., Account Type, Currency, GL Account, Opening Balance, Book Balance, Statement Balance, Available Balance, Last Statement Date, Last Reconciled Date, Signatory Rule, Account Status
- **Bank Transactions** — Transaction No., Value Date, Posting Date, Bank Account, Transaction Type, Description, Counterparty, External Reference, Source Document, Debit, Credit, Running Balance, Currency, Match Status, Reconciliation No., Posting Status
- **Bank Deposits** — Deposit No., Deposit Date, Bank Account, Source Cash Point(s), Cashier Session(s), Deposit Slip No., Receipt Count, Cash Amount, Cheque Amount, Total Deposit, Currency, Deposited By, Confirmed Date, Bank Reference, Match Status, Deposit Status
- **Withdrawals & Charges** — Transaction No., Value Date, Bank Account, Type, Payee/Bank, Description, External Reference, Gross Amount, Tax, Net Amount, Currency, GL Account, Journal Entry No., Approval Status, Reconciliation Status
- **Bank Transfers** — Transfer No., Transfer Date, From Account, To Account, From Amount, From Currency, Exchange Rate, To Amount, To Currency, Bank Charges, External Reference, Requested By, Approved By, Processed At, Transfer Status
- **Statement Imports** — Import No., Bank Account, Statement From, Statement To, File Name, File Format, Imported At, Imported By, Opening Balance, Closing Balance, Row Count, Duplicate Rows, Invalid Rows, Matched Rows, Unmatched Rows, Import Status
- **Matching Workbench** — Statement Line No., Value Date, Description, External Reference, Statement Amount, Currency, Suggested System Transaction, Suggested Reference, Suggested Amount, Match Score, Difference, Match Rule, Assigned To, Match Status, Reconciliation No.
- **Bank Reconciliations** — Reconciliation No., Bank Account, Period From, Period To, Statement Opening Balance, Statement Closing Balance, Book Balance, Deposits in Transit, Unpresented Payments, Bank-only Items, Adjusted Balance, Difference, Currency, Prepared By, Reviewed By, Reconciliation Status

#### 10.3.6 Fixed assets

- **Asset Register** — Asset No., Asset Name, Asset Category, Serial No., Tag No., Acquisition Date, In-service Date, Supplier, Location, Department, Custodian, Acquisition Cost, Accumulated Depreciation, Net Book Value, Currency, Useful Life, Depreciation Method, Asset Status
- **Asset Categories** — Category Code, Category Name, Parent Category, Asset GL Account, Accumulated Depreciation Account, Depreciation Expense Account, Disposal Gain/Loss Account, Default Useful Life, Depreciation Method, Residual Value Rule, Capitalization Threshold, Status
- **Asset Acquisitions** — Acquisition No., Acquisition Date, Asset No./Count, Supplier, PO No., Supplier Invoice No., Department, Location, Gross Cost, Tax, Capitalized Cost, Currency, In-service Date, Approval Status, Journal Entry No., Acquisition Status
- **Depreciation Runs** — Run No., Fiscal Period, Run Date, Asset Category, Asset Count, Opening Cost, Depreciable Base, Period Depreciation, Accumulated Depreciation, Net Book Value, Currency, Exception Count, Calculated By, Approved By, Journal Entry No., Run Status
- **Asset Transfers** — Transfer No., Transfer Date, Asset No., Asset Name, From Facility, From Location, From Department/Custodian, To Facility, To Location, To Department/Custodian, Reason, Requested By, Approved By, Received By, Transfer Status
- **Revaluations** — Revaluation No., Revaluation Date, Asset No., Asset Name, Previous Cost, Previous Net Book Value, Revalued Amount, Increase/Decrease, Currency, Valuer, Valuation Reference, Reason, Approval Status, Journal Entry No., Revaluation Status
- **Disposals** — Disposal No., Disposal Date, Asset No., Asset Name, Disposal Method, Buyer/Recipient, Proceeds, Net Book Value, Gain/Loss, Currency, Reason, Approval Status, Receipt Reference, Journal Entry No., Disposal Status
- **Asset Ledger** — Posting Date, Fiscal Period, Asset No., Asset Name, Transaction Type, Document Reference, Description, Cost Debit, Cost Credit, Depreciation Debit, Depreciation Credit, Net Book Value, Currency, Journal Entry No., Posting Status

#### 10.3.7 Budgets and cost control

- **Annual Budgets** — Budget No., Fiscal Year, Budget Version, Entity/Facility, Currency, Department Count, Line Count, Original Budget, Approved Revisions, Current Budget, Commitments, Actual Amount, Available Amount, Utilization Percentage, Prepared By, Approved By, Budget Status
- **Department Budgets** — Budget No., Fiscal Year, Department, Cost Centre, Budget Owner, Currency, Original Budget, Revised Budget, Commitments, Actual Amount, Available Amount, Utilization Percentage, Forecast Amount, Variance, Approval Status
- **Project Budgets** — Budget No., Project Code, Project Name, Sponsor/Funder, Start Date, End Date, Project Manager, Currency, Approved Budget, Revisions, Commitments, Actual Amount, Available Amount, Burn Rate, Forecast at Completion, Budget Status
- **Budget Revisions** — Revision No., Revision Date, Budget No., Fiscal Year, Department/Project, Revision Type, Source Line, Destination Line, Increase, Decrease, Net Change, Currency, Reason, Requested By, Approved By, Approval Status
- **Commitments** — Commitment No., Commitment Date, Source Type, Source Reference, Supplier/Payee, Budget No., Budget Line, Department, Description, Original Amount, Liquidated Amount, Open Amount, Currency, Expected Date, Commitment Status
- **Budget vs Actual** — Fiscal Period, Budget No., Department, Cost Centre, Project, Account Code, Account Name, Original Budget, Revised Budget, Commitments, Actual Amount, Available Amount, Variance Amount, Variance Percentage, Currency, Forecast
- **Variance Analysis** — Fiscal Period, Department, Cost Centre, Project, Account, Budget Amount, Actual Amount, Variance Amount, Variance Percentage, Favorable/Unfavorable, Threshold, Explanation, Corrective Action, Responsible Owner, Review Status

#### 10.3.8 Tax and compliance

- **Tax Codes & Rates** — Tax Code, Tax Name, Tax Type, Jurisdiction, Rate, Inclusive/Exclusive, Recoverable Percentage, Input Tax Account, Output Tax Account, Payable Account, Effective From, Effective To, Filing Category, Tax Authority, Status
- **Tax Transactions** — Tax Date, Tax Period, Tax Code, Transaction Type, Source Document, Document Reference, Party, Taxable Amount, Tax Rate, Input Tax, Output Tax, Withheld Tax, Currency, GL Account, Filing Status, Journal Entry No.
- **Withholding Tax** — Certificate No., Transaction Date, Supplier/Payee, Tax ID, Source Invoice/Payment, Withholding Code, Gross Amount, Rate, Withheld Amount, Net Paid, Currency, Certificate Date, Filing Period, Remittance Reference, Filing Status
- **Tax Returns** — Return No., Tax Type, Filing Period, Due Date, Taxable Sales/Purchases, Input Tax, Output Tax, Tax Withheld, Adjustments, Tax Payable/Refundable, Currency, Submitted Date, Submission Reference, Payment Reference, Prepared By, Approved By, Return Status
- **Regulatory Reports** — Report Name, Regulator, Report Type, Reporting Period, Due Date, Entity/Facility, Currency, Record Count, Reported Amount, Generated At, Generated By, Submission Date, Submission Reference, Acknowledgement, Report Status
- **Audit Schedules** — Schedule No., Schedule Name, Fiscal Period, Account/Area, Prepared Balance, Supporting Balance, Difference, Currency, Attachment Count, Prepared By, Reviewed By, Review Notes, Prepared At, Reviewed At, Schedule Status

#### 10.3.9 Period close

- **Close Checklist** — Fiscal Period, Checklist Item, Category, Description, Dependency, Responsible Role/User, Due Date, Completion Date, Evidence Required, Evidence Attached, Exception Count, Reviewed By, Review Date, Checklist Status
- **Reconciliation Checklist** — Fiscal Period, Reconciliation Type, Account/Subledger, Responsible Owner, GL Balance, Supporting Balance, Difference, Currency, Last Reconciled At, Reconciliation Reference, Exception Count, Reviewer, Reconciliation Status
- **Period Adjustments** — Adjustment No., Fiscal Period, Entry Date, Adjustment Type, Description, Total Debit, Total Credit, Currency, Supporting Reference, Requested By, Approved By, Journal Entry No., Posting Date, Adjustment Status
- **Reopen Requests** — Request No., Fiscal Period, Requested At, Requested By, Reason, Affected Module, Affected Document(s), Risk Assessment, Current Approver, Approved At, Reopen From, Reopen Until, Reclosed At, Request Status
- **Close History** — Fiscal Period, Entity/Facility, Close Type, Closed At, Closed By, Reopened Count, Last Reopened At, Reclosed At, Journal Count, Adjustment Count, Exception Count, Lock Status, Audit Reference
- **Year-end Close Runs** — Run No., Fiscal Year, Entity/Facility, Run Date, Closing Period, Profit/Loss Amount, Retained Earnings Account, Closing Entry No., Opening Entry No., Currency, Exception Count, Prepared By, Approved By, Completed At, Run Status

#### 10.3.10 Financial reports

- **Trial Balance** — Account Code, Account Name, Account Type, Opening Debit, Opening Credit, Period Debit, Period Credit, Closing Debit, Closing Credit, Currency, Comparative Closing Balance, Difference
- **Income Statement** — Section, Account Group, Account Code, Account Name, Current Period, Year to Date, Prior Period, Prior Year, Budget, Variance Amount, Variance Percentage, Currency
- **Balance Sheet** — Section, Account Group, Account Code, Account Name, Current Balance, Prior-period Balance, Prior-year Balance, Movement, Currency, Supporting Schedule, Reconciliation Status
- **Cash Flow Statement** — Cash Flow Section, Line Item, Source Account(s), Current-period Inflow, Current-period Outflow, Net Cash Flow, Year-to-date Amount, Prior-period Amount, Budget Amount, Variance, Currency
- **General Ledger Report** — Posting Date, Fiscal Period, Account Code, Account Name, Journal Entry No., Source Module, Document Reference, Description, Party, Department, Cost Centre, Debit, Credit, Running Balance, Currency
- **Revenue & Expense Analysis** — Fiscal Period, Account Type, Account Group, Account, Facility, Department, Cost Centre, Service/Expense Category, Actual Amount, Budget Amount, Variance, Prior-period Amount, Growth Percentage, Currency
- **Department Performance** — Fiscal Period, Facility, Department, Revenue, Direct Costs, Allocated Costs, Gross Margin, Operating Margin, Budget, Variance, Patient/Activity Volume, Revenue per Activity, Cost per Activity, Currency
- **Cashier & Bank Reports** — Report Date, Facility, Cash Point/Bank Account, Session/Statement Count, Opening Balance, Receipts, Payments, Refunds, Transfers, Deposits, Closing Balance, Variance, Unreconciled Amount, Currency, Report Status
- **Consolidated Reports** — Reporting Period, Entity/Facility, Consolidation Group, Local Currency, Reporting Currency, Exchange Rate, Revenue, Expenses, Assets, Liabilities, Equity, Eliminations, Consolidated Amount, Validation Difference, Consolidation Status

#### 10.3.11 Setup and controls

- **Fiscal Years & Periods** — Fiscal Year, Period No., Period Name, Start Date, End Date, Entity/Facility, Module, Open Date, Soft-close Date, Close Date, Lock Date, Reopened At, Reopened By, Period Status
- **Payment Methods** — Method Code, Method Name, Method Type, Incoming/Outgoing, Provider, Settlement Account, Clearing Account, Requires External Reference, Requires Approval, Fee Rule, Facility Scope, Effective From, Effective To, Status
- **Document Numbering** — Sequence Code, Document Type, Module, Facility, Prefix, Suffix, Date Pattern, Next Number, Minimum Length, Reset Frequency, Last Issued Number, Last Issued At, Gap Policy, Sequence Status
- **Departments & Cost Centres** — Department Code, Department Name, Cost Centre Code, Cost Centre Name, Parent, Facility, Manager, Default Revenue Account, Default Expense Account, Budget Owner, Effective From, Effective To, Status
- **Posting Rules** — Rule Code, Rule Name, Source Module, Event Type, Debit Account Rule, Credit Account Rule, Tax Rule, Department Rule, Cost Centre Rule, Priority, Effective From, Effective To, Version, Test Status, Rule Status
- **Approval Rules** — Rule Code, Rule Name, Module, Document Type, Facility/Department Scope, Minimum Amount, Maximum Amount, Currency, Approval Levels, Approver Role(s), Escalation Time, Segregation Rule, Effective From, Effective To, Rule Status
- **Opening Balances** — Import/Batch No., Effective Date, Account/Party/Asset, Reference, Description, Debit, Credit, Currency, Department, Cost Centre, Source File, Validation Status, Error Message, Approved By, Journal Entry No., Posting Status
- **Integration Mappings** — Mapping Code, Integration/System, Source Entity, Source Event, Source Value, Target Entity, Target Value/Account, Facility Scope, Direction, Transformation Rule, Last Synced At, Error Count, Version, Mapping Status

#### 10.3.12 Audit trail

- **Transaction History** — Event Date/Time, Module, Entity Type, Entity Reference, Event Type, Before Summary, After Summary, Amount, Currency, Facility, Performed By, Role, Source IP/Device, Correlation ID, Outcome
- **Approval History** — Decision Date/Time, Module, Document Type, Document Reference, Amount, Currency, Approval Level, Decision, Decision Reason, Approver, Delegated From, Waiting Time, SLA Status, Correlation ID
- **Posting History** — Posting Date/Time, Source Module, Document Type, Document Reference, Journal Entry No., Fiscal Period, Debit, Credit, Currency, Posting Rule, Posted By, Repost/Reversal Reference, Posting Outcome
- **Reversals & Voids** — Action Date/Time, Module, Document Type, Original Reference, Action Type, Reason Code, Reason, Original Amount, Reversed/Voided Amount, Currency, Replacement Reference, Requested By, Approved By, Journal Entry No., Action Status
- **Data Exports** — Export No., Requested At, Requested By, Module, Tab/Report, Filter Summary, Date Range, Facility Scope, Column Count, Row Count, File Format, File Size, Completed At, Download Count, Expires At, Export Status

### 10.4 Insurance & Claims tab tables

- **Overview** — Queue/Metric, Current Count, Submitted Amount, Approved Amount, Rejected Amount, Paid Amount, Outstanding Amount, Currency, Average Turnaround Time, Oldest Item Age, SLA Status, Assigned Team, Trend, Last Refreshed
- **Insurance Providers** — Provider Code, Provider Name, Provider Type, Tax/Registration No., Contact Person, Phone, Email, Address, Default Submission Channel, Settlement Terms, Default Currency, Active Plan Count, Open Claim Count, Outstanding Balance, Contract Expiry, Provider Status
- **Corporate Payers** — Payer Code, Corporate Name, Registration/Tax No., Industry, Contact Person, Phone, Email, Billing Address, Contract No., Credit Limit, Payment Terms, Currency, Employee/Member Count, Open Invoice/Claim Count, Outstanding Balance, Account Manager, Payer Status
- **Plans & Products** — Plan Code, Plan Name, Provider/Corporate Payer, Product Type, Coverage Class, Network Type, Annual Limit, Co-pay Rule, Deductible Rule, Default Tariff, Currency, Effective From, Effective To, Active Member Count, Plan Status
- **Contracts** — Contract No., Payer, Contract Type, Start Date, End Date, Renewal Date, Payment Terms, Claim Submission Deadline, Reimbursement Method, Tariff/Price List, Currency, Credit Limit, SLA, Document Count, Account Manager, Approval Status, Contract Status
- **Tariffs & Price Lists** — Tariff Code, Tariff Name, Payer, Plan, Service/Item Code, Service/Item Name, Department, Standard Price, Contract Price, Co-pay Amount/Rate, Tax Code, Currency, Effective From, Effective To, Version, Tariff Status
- **Coverage Rules** — Rule Code, Rule Name, Payer, Plan, Benefit Category, Service/Item Scope, Coverage Percentage, Co-pay, Deductible, Per-visit Limit, Annual Limit, Waiting Period, Pre-authorization Required, Referral Required, Effective From, Effective To, Rule Status
- **Exclusions & Limits** — Rule Code, Payer, Plan, Exclusion/Limit Type, Service/Diagnosis/Category, Description, Limit Quantity, Limit Amount, Frequency, Currency, Waiting Period, Exception Conditions, Effective From, Effective To, Rule Status
- **Patient Policies** — Policy No., Member No., Patient No., Patient Name, Payer, Plan, Principal Member, Relationship, Start Date, End Date, Coverage Status, Eligibility Status, Remaining Limit, Currency, Employer/Corporate, Last Verified At, Policy Status
- **Members & Dependants** — Member No., Patient No., Member Name, Payer, Plan, Policy No., Principal Member No., Relationship, Date of Birth, National ID, Employer/Corporate, Enrolment Date, Coverage Start, Coverage End, Eligibility Status, Member Status
- **Eligibility Checks** — Check No., Check Date/Time, Patient/Member, Policy No., Payer, Plan, Encounter No., Service/Benefit, Coverage Status, Available Limit, Co-pay, Deductible, Currency, Response Code, Response Message, External Reference, Checked By
- **Coverage Balances** — Member No., Patient Name, Policy No., Payer, Plan, Benefit Category, Coverage Period, Annual/Period Limit, Used Amount, Reserved Amount, Remaining Amount, Currency, Last Claim Date, Last Updated At, Balance Status
- **Pre-authorizations** — Authorization No., Request Date, Patient/Member, Policy No., Payer, Plan, Encounter No., Requested Service/Procedure, Diagnosis, Provider/Doctor, Requested Amount, Approved Amount, Patient Share, Currency, Valid From, Valid Until, External Reference, Decision Reason, Authorization Status
- **Claims** — Claim No., Claim Date, Service From, Service To, Patient/Member, Policy No., Payer, Plan, Encounter/Admission No., Invoice No., Diagnosis Summary, Item Count, Submitted Amount, Approved Amount, Rejected Amount, Patient Share, Paid Amount, Outstanding Amount, Currency, Submission Date, Claim Status, Assigned To
- **Claim Validations** — Validation No., Claim No., Patient/Member, Payer, Validation Date/Time, Rule Code, Validation Category, Severity, Field/Item, Error Code, Error Message, Suggested Resolution, Resolved By, Resolved At, Validation Status
- **Claim Batches** — Batch No., Batch Date, Payer, Plan/Contract, Facility, Claim Count, Submitted Amount, Currency, Service Period From, Service Period To, Submission Channel, Submission File, External Batch Reference, Accepted Count, Rejected Count, Prepared By, Batch Status
- **Claim Submissions** — Submission No., Submission Date/Time, Claim/Batch No., Payer, Submission Channel, External Reference, Submitted Amount, Currency, Document Count, Payload/File Name, Response Code, Response Message, Acknowledged At, Retry Count, Next Retry At, Submitted By, Submission Status
- **Adjudications** — Adjudication No., Adjudication Date, Claim No., Claim Item No., Payer, Service/Item, Submitted Amount, Allowed Amount, Approved Amount, Rejected Amount, Patient Share, Co-pay, Deductible, Currency, Decision Code, Decision Reason, Adjudicator Reference, Decision Status
- **Denials** — Denial No., Decision Date, Claim No., Claim Item No., Patient/Member, Payer, Submitted Amount, Denied Amount, Currency, Denial Code, Denial Category, Denial Reason, Correctable, Appeal Deadline, Assigned Owner, Follow-up Date, Denial Status
- **Resubmissions & Appeals** — Appeal/Resubmission No., Type, Original Claim No., Payer, Patient/Member, Original Denied Amount, Requested Amount, Currency, Reason, Supporting Document Count, Submitted Date, External Reference, Appeal Deadline, Decision Date, Approved Amount, Assigned Owner, Appeal Status
- **Remittance Advice** — Remittance No., Remittance Date, Payer, Payment Reference, Service Period, Claim Count, Gross Approved Amount, Deductions, Net Remittance Amount, Currency, File/Document Name, Imported At, Matched Claim Count, Unmatched Claim Count, Exception Amount, Remittance Status
- **Insurer Payments** — Payment No., Payment Date, Payer, Remittance No., Payment Method, Bank Account, External Reference, Gross Amount, Deductions, Net Amount, Allocated Amount, Unallocated Amount, Currency, Value Date, Journal Entry No., Reconciliation Status, Payment Status
- **Remittance Allocations** — Allocation No., Allocation Date, Remittance No., Payment No., Claim No., Invoice No., Patient/Member, Payer, Approved Amount, Allocated Amount, Short/Over Amount, Currency, Adjustment Code, Allocation Status, Allocated By
- **Payer Balances** — Payer Code, Payer Name, Payer Type, Open Claim Count, Submitted Amount, Approved Unpaid Amount, Denied Amount Under Appeal, Unallocated Payments, Current Amount, 1–30 Days, 31–60 Days, 61–90 Days, Over 90 Days, Total Outstanding, Currency, Credit Limit, Account Status
- **Claim Reconciliation** — Reconciliation No., Reconciliation Date, Payer, Period From, Period To, Submitted Claim Amount, Adjudicated Amount, Remittance Amount, Payment Amount, Allocated Amount, GL Receivable Balance, Difference, Currency, Exception Count, Prepared By, Reviewed By, Reconciliation Status
- **Payer Statements** — Transaction Date, Payer, Document Type, Claim/Invoice/Payment Reference, Patient/Member, Description, Due Date, Debit, Credit, Running Balance, Currency, Allocation Reference, Posting Status
- **Claims Aging** — Payer, Plan/Contract, Claim Count, Current Amount, 1–30 Days, 31–60 Days, 61–90 Days, Over 90 Days, Total Outstanding, Currency, Oldest Claim Date, Maximum Age, Denied Amount, Under-appeal Amount, Assigned Owner
- **Collection Follow-up** — Follow-up No., Payer, Claim/Batch Reference, Outstanding Amount, Currency, Maximum Age, Priority, Last Contact Date, Contact Person, Contact Method, Promise Date, Promise Amount, Next Follow-up Date, Assigned Owner, Escalation Level, Follow-up Status, Notes
- **Disputes** — Dispute No., Opened Date, Payer, Claim/Payment Reference, Dispute Type, Disputed Amount, Currency, Issue Summary, Evidence Count, Assigned Owner, Payer Contact, Response Due Date, Last Response Date, Resolution, Resolved Amount, Closed Date, Dispute Status
- **Claim Rules** — Rule Code, Rule Name, Payer/Plan Scope, Rule Category, Trigger Stage, Condition Summary, Validation/Action, Severity, Auto-reject, Override Role, Priority, Effective From, Effective To, Version, Last Tested At, Rule Status
- **Required Documents** — Requirement Code, Document Type, Payer, Plan, Claim/Service Type, Required Stage, Mandatory, Minimum Count, Accepted Format(s), Maximum Size, Validity Period, Conditional Rule, Effective From, Effective To, Requirement Status
- **Denial Codes** — Denial Code, External Code, Denial Name, Category, Description, Correctable, Default Action, Appeal Allowed, Appeal Deadline Days, Responsible Team, GL Adjustment Rule, Effective From, Effective To, Code Status
- **Submission Channels** — Channel Code, Channel Name, Payer, Channel Type, Endpoint/Portal, File Format, Authentication Profile, Submission Schedule, Acknowledgement Expected, Retry Policy, Last Successful Submission, Last Failure, Error Count, Channel Status
- **Claim Templates** — Template Code, Template Name, Payer, Plan/Contract, Claim Type, File/Message Format, Version, Required Sections, Item Grouping, Currency Rule, Effective From, Effective To, Last Published At, Published By, Template Status
- **Insurance Reports** — Report Name, Report Category, Description, Payer/Plan Scope, Default Period, Available Filters, Default Grouping, Last Generated At, Generated By, Output Format, Row Count, Schedule, Delivery Recipients, Report Status

## 11. Module ownership and core data relationships

The records below are tightly related but must retain a clear authoritative owner:

- **Billing:** Charge, Estimate, Invoice, Invoice Item, Credit Note, Debit Note, Patient Account, Payment, Payment Allocation, Receipt, Refund, Advance, Statement, and Write-off
- **Accounts & Finance — accounting:** Account, Fiscal Period, Journal, Journal Entry, Journal Line, Control Account, and Reconciliation
- **Accounts & Finance — procurement and payables:** Supplier, Requisition, Purchase Order, Goods Receipt, Supplier Invoice, Supplier Payment, and AP Allocation
- **Accounts & Finance — treasury and planning:** Cash Point, Cashier Session, Bank Account, Bank Transaction, Fixed Asset, Depreciation Run, Budget, Budget Line, Commitment, and Variance
- **Insurance & Claims:** Insurer, Corporate Payer, Plan, Contract, Patient Policy, Eligibility Check, Pre-authorization, Claim, Claim Item, Adjudication, Remittance, Denial, and Appeal
- **Shared references:** Patient, Encounter, Admission, Facility, Department, Cost Centre, Staff User, Service, Inventory Item, Currency, and Attachment

Key relationship rules:

1. Every posted source document creates or references a balanced journal entry.
2. Every journal line references one account and may also reference a party, department, cost centre, or source item.
3. A payment can have multiple allocations, but allocations cannot exceed the available payment amount.
4. A receipt references an incoming payment; it does not replace the payment record.
5. Credit notes, debit notes, refunds, reversals, and write-offs must retain links to the original transaction.
6. Ledger balances and financial reports must come from posted entries, not from separately maintained totals.
7. Subledger balances must reconcile with their corresponding general-ledger control accounts.

Together, these rules make the HMS financial modules an integrated accounting system rather than a collection of unrelated billing, accounting, and claim screens.

## 12. Derived tab implementation specifications

The implementation-ready decomposition of Sections 9 and 10 lives in [`.cursor/finance/`](finance/README.md).

- Each main menu is represented by a folder.
- Each Accounts & Finance submenu is represented by a nested folder.
- Each permanent tab is represented by one Markdown file.
- Every tab file defines its table columns, filters, toolbar buttons, row buttons, bulk actions, CRUD behavior, forms, nested detail tables, statuses, permissions, API contract, validation, audit requirements, implementation references, and acceptance criteria.
- Shared Pharmacy-guided workspace conventions live in [`.cursor/finance/_shared/`](finance/_shared/README.md).

This document remains the source of truth for scope, menu hierarchy, tab labels, and table columns. After changing Sections 9 or 10, regenerate and verify the derived specifications:

```powershell
python tool/generate_finance_tab_docs.py
python tool/generate_finance_tab_docs.py --check
```

## 13. Existing implementation and the reuse audit

Sections 9 and 10 describe the **target** menu and columns, not a greenfield build. Much of this scope already exists in the codebase under different names, in a different module, or behind a different route. Treat every finance leaf as a refactor of existing code until an audit proves otherwise.

### 13.1 Reuse audit (run before writing code for any finance leaf)

1. Search the backend for an owning module, Prisma model, service, and route that already stores or exposes the record.
2. Search the frontend for an existing panel, table, dialog, DTO, entity, repository, and controller for the same record.
3. Search for an existing permission key, entitlement, ABAC scope, and access atom before adding new ones.
4. Search for an existing localized string, formatter, print helper, and export mapping before adding new ones.
5. Record the outcome in the change description: what was found, what is extended, and what genuinely did not exist.

Only step 5's "genuinely did not exist" list may be implemented from scratch. Everything else is extended in place: new columns, filters, statuses, and actions are added to the owning module rather than to a parallel one.

### 13.2 Never duplicate these

| Capability | Authoritative existing implementation |
|---|---|
| Currency resolution, formatting, precision, conversion | `frontend/lib/shared/components/app_currency.dart`, `frontend/lib/core/currency/effective_default_currency_provider.dart`, `frontend/lib/core/currency/fx_currency_utils.dart`, `frontend/lib/shared/components/app_currency_amount_field.dart`, `frontend/lib/shared/components/app_currency_select_field.dart` |
| Chart of accounts | `backend/src/modules/chart-account/`, `chart_account` model, `frontend/lib/features/accounts/presentation/widgets/accounts_chart_panel.dart` |
| Fiscal periods and period locks | `backend/src/modules/accounts-workspace/services/fiscal-period.service.js`, `fiscal_period` model, `frontend/lib/features/accounts/presentation/widgets/accounts_fiscal_periods_panel.dart` |
| Accounts desk work queues, journals, approvals, GL, patient ledgers, invoices | `backend/src/modules/accounts-workspace/`, `backend/src/modules/accounts-invoice/`, `frontend/lib/features/accounts/` |
| Patient charges, invoices, payments, refunds, adjustments | `backend/src/modules/billing/`, `invoice/`, `payment/`, `refund/`, `billing-adjustment/`, `frontend/lib/features/billing/` |
| Price lists, tariffs, pricing and discount rules | `backend/src/modules/price-book-entry/`, `pricing-rule/`, `scheme-offer/`, `frontend/lib/features/billing/presentation/widgets/billing_price_book_panel.dart` |
| Insurers, plans, policies, pre-authorizations, claims | `backend/src/modules/insurance-company/`, `coverage-plan/`, `patient-insurance-enrollment/`, `pre-authorization/`, `insurance-claim/`, `insurer-integration/`, `claims-workspace/`, `frontend/lib/features/claims/` |
| Suppliers, requisitions, purchase orders, goods receipts | `backend/src/modules/supplier/`, `purchase-request/`, `purchase-order/`, `goods-receipt/` |
| Fixed assets and service history | `backend/src/modules/asset/`, `asset-service-log/` |
| Payroll postings | `backend/src/modules/payroll-run/`, `payroll-item/` |
| Inventory movements and valuation inputs | `backend/src/modules/stock-movement/`, `stock-adjustment/`, `inventory-item/` |
| Cash points, shift and day closure | `backend/src/modules/shift-close/`, `day-close/`, `closeout-pack/` |
| Departments and cost centres | `backend/src/modules/department/`, `unit/` |
| Report definitions, runs, schedules, exports | `backend/src/modules/report-definition/`, `report-run/`, `report-schedule/`, `reports-workspace/`, `frontend/lib/features/reports/` |
| Audit, change, and PHI access history | `backend/src/modules/audit-log/`, `system-change-log/`, `phi-access-log/` |
| Workspace shell, tables, dialogs, forms, print, access gates | `frontend/lib/shared/components/`, `frontend/lib/shared/layout/`, `frontend/lib/core/permissions/` |

### 13.3 When the target and the existing implementation disagree

- The target column set, statuses, and permissions in Sections 9 and 10 win.
- The owning module, model, route family, and identifier scheme of the existing implementation win.
- Reconcile by migrating the existing implementation toward the target, keeping compatible deep links and data, and retiring superseded code only after parity tests pass.
- If a leaf would introduce a second source of truth for a record another module already owns, do not build it: extend the owning module and link to it instead.

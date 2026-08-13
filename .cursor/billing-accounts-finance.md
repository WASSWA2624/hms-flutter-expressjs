# HMS Financial Modules: Billing & Receivables, Accounts & Finance, and Insurance & Claims

## 1. Purpose and scope

A comprehensive Hospital Management System (HMS) needs more than journals, ledgers, invoices, and receipts. Its financial capabilities should be exposed through three separate top-level menu items:

1. **Billing & Receivables** — rename the existing **Billing** menu.
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

The application sidebar should expose **Billing & Receivables**, **Accounts & Finance**, and **Insurance & Claims** as three independent first-level menu items. Billing and insurance must not be nested under Accounts & Finance.

Apply these rules consistently:

1. Every named menu or submenu entry opens a tab with the same name.
2. Selecting the label of an expandable entry opens its overview/worklist tab; selecting its chevron expands or collapses its children.
3. Reopening the same destination focuses its existing tab instead of creating a duplicate.
4. Record-specific tabs may open from a worklist, for example `Invoice INV-000123` or `Claim CLM-000045`.
5. Tabs should preserve filters, pagination, and unsaved form state while open.
6. Tabs should be closable, reorderable, deep-linkable, and restorable after an accidental refresh where practical.
7. The active sidebar entry, active tab, page title, and breadcrumb must remain synchronized.
8. Menu entries, tabs, actions, totals, and badges must respect role and facility permissions.
9. Worklist tabs may show useful badges such as pending approvals, overdue balances, rejected claims, or unreconciled transactions.
10. Cross-module links must open the authoritative record's tab instead of creating a duplicate copy in another module.

### 9.2 Billing & Receivables

Rename the existing **Billing** menu to **Billing & Receivables**. It owns patient and customer charging, invoicing, collection, allocation, adjustment, and receivable follow-up.

```text
BILLING & RECEIVABLES
│
├── Overview
│
├── Charge Management
│   ├── Charge Entry
│   ├── Unbilled Charges
│   ├── Charge Review
│   ├── Estimates & Quotations
│   └── Packages & Bundles
│
├── Invoices
│   ├── All Invoices
│   ├── Create Invoice
│   ├── Draft Invoices
│   ├── Issued Invoices
│   ├── Outstanding & Overdue
│   └── Cancelled & Written-off
│
├── Payments & Receipts
│   ├── Receive Payment
│   ├── Payment Transactions
│   ├── Payment Allocations
│   ├── Unallocated Payments
│   ├── Receipts
│   └── Advances & Deposits
│
├── Adjustments & Refunds
│   ├── Credit Notes
│   ├── Debit Notes
│   ├── Refund Requests
│   ├── Approved Refunds
│   └── Write-offs
│
├── Patient Accounts
│   ├── Account Search
│   ├── Patient Statements
│   ├── Encounter Balances
│   ├── Guarantors & Sponsors
│   └── Credit Balances
│
├── Accounts Receivable
│   ├── Receivable Worklist
│   ├── Aging Analysis
│   ├── Collection Follow-up
│   ├── Payer Statements
│   └── Receivable Reconciliation
│
├── Billing Reports
│   ├── Daily Billing
│   ├── Collections
│   ├── Outstanding Balances
│   ├── Revenue by Service
│   ├── Discounts & Adjustments
│   └── Payment Allocation
│
└── Billing Setup
    ├── Price Lists & Tariffs
    ├── Billing Rules
    ├── Discount Rules
    ├── Tax Rules
    ├── Invoice Templates
    └── Receipt Templates
```

### 9.3 Accounts & Finance

Rename the existing **Accounts** menu to **Accounts & Finance**. It must be an expandable first-level menu with nested, permission-aware submenu entries. It owns the accounting books, payables, expenditure, treasury, assets, budgets, period close, compliance, and financial reporting.

```text
ACCOUNTS & FINANCE
│
├── Overview
│
├── General Accounting
│   ├── Accounting Overview
│   ├── Chart of Accounts
│   ├── Journal Entries
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
│   ├── Payables Overview
│   ├── Suppliers
│   ├── Purchase Requisitions
│   ├── Purchase Orders
│   ├── Goods Received Notes
│   ├── Supplier Invoices
│   ├── Supplier Adjustments
│   ├── Payment Runs
│   ├── Make Payment
│   ├── Supplier Statements
│   ├── AP Aging
│   └── AP Reconciliation
│
├── Expenses
│   ├── Expense Overview
│   ├── Expense Entries
│   ├── Expense Requests
│   ├── Approval Worklist
│   ├── Recurring Expenses
│   ├── Staff Reimbursements
│   ├── Expense Categories
│   └── Expense Analysis
│
├── Cash Management
│   ├── Cash Overview
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
│   ├── Bank Overview
│   ├── Bank Accounts
│   ├── Bank Transactions
│   ├── Deposits
│   ├── Withdrawals & Charges
│   ├── Bank Transfers
│   ├── Statement Imports
│   ├── Matching Workbench
│   └── Bank Reconciliation
│
├── Fixed Assets
│   ├── Asset Overview
│   ├── Asset Register
│   ├── Asset Categories
│   ├── Acquisitions
│   ├── Depreciation Runs
│   ├── Asset Transfers
│   ├── Revaluations
│   ├── Disposals
│   └── Asset Ledger
│
├── Budgets & Cost Control
│   ├── Budget Overview
│   ├── Annual Budgets
│   ├── Department Budgets
│   ├── Project Budgets
│   ├── Budget Revisions
│   ├── Commitments
│   ├── Budget vs Actual
│   └── Variance Analysis
│
├── Tax & Compliance
│   ├── Tax Overview
│   ├── Tax Codes & Rates
│   ├── Tax Transactions
│   ├── Withholding Tax
│   ├── Tax Returns
│   ├── Regulatory Reports
│   └── Audit Schedules
│
├── Period Close
│   ├── Close Dashboard
│   ├── Reconciliation Checklist
│   ├── Period Adjustments
│   ├── Close Period
│   ├── Reopen Requests
│   └── Year-end Close
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
│   ├── Currencies & Exchange Rates
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

```text
INSURANCE & CLAIMS
│
├── Overview
│
├── Payers & Contracts
│   ├── Insurance Providers
│   ├── Corporate Payers
│   ├── Plans & Products
│   ├── Corporate Contracts
│   ├── Tariffs & Price Lists
│   ├── Coverage Rules
│   ├── Exclusions & Limits
│   └── Contract Expiry
│
├── Membership & Eligibility
│   ├── Patient Policies
│   ├── Member Enrolment
│   ├── Dependants
│   ├── Eligibility Checks
│   ├── Coverage Balances
│   └── Expiring & Inactive Policies
│
├── Pre-authorizations
│   ├── All Pre-authorizations
│   ├── New Request
│   ├── Pending
│   ├── Approved
│   ├── Rejected
│   └── Expiring
│
├── Claims
│   ├── Claim Worklist
│   ├── New & Generated Claims
│   ├── Draft Claims
│   ├── Validation Errors
│   ├── Ready for Submission
│   ├── Submitted & In Review
│   ├── Approved & Partially Approved
│   ├── Rejected & Denied
│   ├── Resubmissions & Appeals
│   └── Claim Batches
│
├── Remittances & Collections
│   ├── Remittance Advice
│   ├── Insurer Payments
│   ├── Remittance Allocations
│   ├── Underpayments & Overpayments
│   ├── Unallocated Remittances
│   └── Outstanding Payer Balances
│
├── Reconciliation & Follow-up
│   ├── Claim Reconciliation
│   ├── Payer Statements
│   ├── Claims Aging
│   ├── Denial Follow-up
│   ├── Collection Notes
│   └── Disputes
│
├── Insurance Reports
│   ├── Claims Summary
│   ├── Claims Aging
│   ├── Approval & Rejection Rates
│   ├── Revenue by Payer
│   ├── Turnaround Time
│   ├── Denial Reasons
│   └── Outstanding Claims
│
└── Insurance Setup
    ├── Claim Numbering
    ├── Claim Rules
    ├── Required Documents
    ├── Denial Codes
    ├── Submission Channels
    ├── Claim Templates
    └── Approval Rules
```

### 9.5 Module boundaries and hand-offs

- **Billing & Receivables → Accounts & Finance:** Posted invoices, payments, allocations, credit/debit notes, refunds, and write-offs create balanced accounting events.
- **Billing & Receivables → Insurance & Claims:** Insured charges and supporting clinical documents become pre-authorization or claim inputs.
- **Insurance & Claims → Billing & Receivables:** Coverage decisions determine patient, insurer, and corporate-payer responsibility.
- **Insurance & Claims → Accounts & Finance:** Approved claims, remittances, denials, and adjustments update receivable control accounts and journals.
- **Accounts & Finance → all financial modules:** Accounts, periods, currencies, payment methods, posting rules, and close status are shared as controlled reference data.
- A cross-module link should open the source record in its owning module's tab while preserving the user's current tabs.

## 10. Module ownership and core data relationships

The records below are tightly related but must retain a clear authoritative owner:

- **Billing & Receivables:** Charge, Estimate, Invoice, Invoice Item, Credit Note, Debit Note, Patient Account, Payment, Payment Allocation, Receipt, Refund, Advance, Statement, and Write-off
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

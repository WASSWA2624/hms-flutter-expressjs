/// English UI copy for the Accounts desk (exact blueprint labels for tests).
abstract final class AccountsStrings {
  static const String workspaceTitle = 'Accounts';
  static const String loadingTitle = 'Loading accounts';
  static const String loadingBody = 'Fetching facility books…';
  static const String navLabel = 'Accounts';
  static const String navShortLabel = 'Accounts';

  static const String searchHint = 'Account, journal, reference…';
  static const String searchSemantic = 'Search accounts';
  static const String clearSearch = 'Clear search';
  static const String filtersLabel = 'Filters';
  static const String clearFilters = 'Clear filters';
  static const String allFields = 'All';
  static const String notesLabel = 'Notes';
  static const String reasonLabel = 'Reason';
  static const String reasonValidation = 'Reason is required.';
  static const String unknownValue = '—';

  static const String openWorkLabel = 'Open work';
  static const String openWorkTooltip =
      'All accounting items that still need action across journals, approvals, and period tasks';
  static const String toPostLabel = 'To post';
  static const String toPostTooltip =
      'Draft journal entries ready to post to the books';
  static const String needApprovalLabel = 'Need approval';
  static const String needApprovalTooltip =
      'Journal posts, voids, reversals, and period close awaiting approval';
  static const String generalLedgerLabel = 'General ledger';
  static const String generalLedgerTooltip =
      'Facility account balances and activity by GL account';
  static const String patientLedgersLabel = 'Patient ledgers';
  static const String patientLedgersTooltip =
      'Patient invoiced, paid, and outstanding balances';
  static const String accountChartLabel = 'Account chart';
  static const String accountChartTooltip =
      'Chart of accounts codes, types, and status';
  static const String closeBooksLabel = 'Close books';
  static const String closeBooksTooltip =
      'Fiscal periods: open, review checklist, and close';

  static const String glEmpty = 'No accounts match.';
  static const String openWorkEmpty = 'No open work.';
  static const String toPostEmpty = 'No drafts to post.';
  static const String needApprovalEmpty = 'No pending approvals.';
  static const String patientLedgersEmpty = 'No patients match.';
  static const String chartEmpty = 'No accounts match.';
  static const String booksEmpty = 'No periods match.';

  static const String patientLedgersSearchHint = 'Patient…';
  static const String patientLedgersSearchSemantic = 'Search patient ledgers';
  static const String patientColumn = 'Patient';
  static const String invoicedColumn = 'Invoiced';
  static const String paidColumn = 'Paid';
  static const String clearanceColumn = 'Clearance';
  static const String clearanceCleared = 'Cleared';
  static const String clearancePartial = 'Partial';
  static const String clearanceOutstanding = 'Outstanding';
  static const String patientLedgerTitle = 'Patient ledger';
  static const String patientLedgerEmpty = 'No ledger entries.';
  static const String payAction = 'Pay';
  static const String payActionTooltip =
      'Receive payment in Billing Collect due';
  static const String ledgerAction = 'Ledger';
  static const String ledgerActionTooltip = 'Open the patient money ledger';

  static const String journalColumn = 'Journal';
  static const String amountColumn = 'Amount';
  static const String statusColumn = 'Status';
  static const String nextColumn = 'Next';
  static const String sourceColumn = 'Source';
  static const String accountColumn = 'Account';
  static const String debitColumn = 'Debit';
  static const String creditColumn = 'Credit';
  static const String balanceColumn = 'Balance';
  static const String typeColumn = 'Type';
  static const String byColumn = 'By';
  static const String reasonColumn = 'Reason';
  static const String periodColumn = 'Period';
  static const String openedColumn = 'Opened';
  static const String closedColumn = 'Closed';
  static const String facilityColumn = 'Facility';
  static const String updatedColumn = 'Updated';

  static const String statusPending = 'Pending';
  static const String statusApproved = 'Approved';
  static const String statusRejected = 'Rejected';
  static const String statusDraft = 'Draft';
  static const String statusPosted = 'Posted';
  static const String statusOpen = 'Open';
  static const String statusClosed = 'Closed';
  static const String statusPendingApproval = 'Pending approval';
  static const String statusOverdue = 'Overdue';

  static const String postAllAction = 'Post all';
  static const String postAllConfirmTitle = 'Post all drafts?';
  static const String postAllConfirmBody =
      'Post every draft journal on this page to the books.';
  static const String postDialogTitle = 'Post journal';
  static const String editDraftAction = 'Edit';
  static const String editDraftActionTooltip = 'Edit this draft journal';
  static const String editJournalTitle = 'Edit journal';
  static const String posted = 'Posted.';
  static const String detailJournalTitle = detailTitleJournal;
  static const String booksOpenFilter = 'Open';
  static const String booksOverdueFilter = 'Overdue close';
  static const String booksSearchHint = 'Period, facility, status…';

  static const String openPeriodAction = 'Open period';
  static const String closePeriodAction = 'Close period';
  static const String openPeriodDialogTitle = 'Open period';
  static const String closePeriodDialogTitle = 'Close period';
  static const String openAction = 'Open';
  static const String openActionTooltip = 'Open a new fiscal period';
  static const String closeAction = 'Close';
  static const String closeActionTooltip = 'Close this fiscal period';
  static const String booksAction = 'Books';
  static const String booksActionTooltip =
      'Open period detail and close checklist';
  static const String periodLabelField = 'Label';
  static const String periodStartField = 'Start date';
  static const String periodEndField = 'End date';
  static const String periodUnpostedLabel = 'Unposted journals';
  static const String periodPendingApprovalsLabel = 'Pending approvals';
  static const String periodChecklistTitle = 'Close checklist';
  static const String periodViewUnposted = 'View unposted';
  static const String detailTitlePeriod = 'Period';
  static const String periodLabelRequired = 'Label is required.';
  static const String periodDatesRequired = 'Start and end dates are required.';

  static const String approvalTypeJournalPost = 'Journal post';
  static const String approvalTypeVoid = 'Void';
  static const String approvalTypeReversal = 'Reversal';
  static const String approvalTypePeriodClose = 'Period close';
  static const String anyApprovalType = 'Any type';
  static const String anyStatus = 'Any status';
  static const String anySource = 'Any source';
  static const String statusFilterLabel = 'Status';
  static const String sourceFilterLabel = 'Source';
  static const String typeFilterLabel = 'Type';
  static const String sourceManual = 'Manual';
  static const String sourceBilling = 'Billing';

  static const String approveAction = 'Approve';
  static const String approveActionTooltip =
      'Approve this pending accounting request';
  static const String rejectAction = 'Reject';
  static const String detailTitleApproval = 'Approval';
  static const String detailTitleJournal = 'Journal';

  static const String nextGl = 'GL';
  static const String nextGlTooltip = 'Open the facility account ledger';
  static const String journalAction = 'Journal';
  static const String journalActionTooltip =
      'Create a draft journal entry for the books';
  static const String periodFilterLabel = 'Period';
  static const String journalDateLabel = 'Date';
  static const String journalDateHint = 'YYYY-MM-DD (optional)';
  static const String journalLinesLabel = 'Lines';
  static const String journalLineLabel = 'Line';
  static const String journalAddLineAction = 'Add line';
  static const String journalRemoveLineAction = 'Remove line';
  static const String journalAccountIdLabel = 'Account';
  static const String journalMemoLabel = 'Memo';
  static const String journalBalanceValidation =
      'Total debits must equal total credits.';
  static const String postAction = 'Post';
  static const String postActionTooltip =
      'Post this draft journal to the books';
  static const String reverseAction = 'Reverse';
  static const String reverseActionTooltip =
      'Request a reversal of this posting';
  static const String voidAction = 'Void';
  static const String voidActionTooltip = 'Request to void this journal';
  static const String sendAction = 'Send';
  static const String sendActionTooltip = 'Send or export this journal';
  static const String glAction = 'GL';
  static const String glActionTooltip = 'Open the facility account ledger';
  static const String printAction = 'Print';
  static const String accountLedgerTitle = 'Account ledger';
  static const String accountLedgerEmpty = 'No ledger entries.';
  static const String activityFilter = 'Activity';
  static const String activityWith = 'With activity';
  static const String activityWithout = 'Without activity';
  static const String saved = 'Saved.';
  static const String submittedForApproval = 'Submitted for approval.';
  static const String stubSectionBody = 'This section is not implemented yet.';

  static const String chartSearchHint = 'Account, code, type…';
  static const String chartEmptyBody = 'Try another search or add an account.';
  static const String chartAddTitle = 'Add account';
  static const String chartEditTitle = 'Edit account';
  static const String chartCodeLabel = 'Code';
  static const String chartCodeRequired = 'Code is required.';
  static const String chartNameLabel = 'Name';
  static const String chartNameRequired = 'Name is required.';
  static const String chartTypeLabel = 'Type';
  static const String chartParentLabel = 'Parent';
  static const String chartCurrencyLabel = 'Currency';
  static const String chartCurrencyRequired = 'Currency is required.';
  static const String chartEffectiveLabel = 'Effective';
  static const String chartActiveLabel = 'Active';
  static const String chartStatusActive = 'Active';
  static const String chartStatusInactive = 'Inactive';
  static const String chartCodeColumn = 'Code';
  static const String chartActionsColumn = 'Actions';
  static const String chartParentColumn = 'Parent';
  static const String chartCurrencyColumn = 'Currency';
  static const String chartEffectiveColumn = 'Effective';
  static const String chartDeactivateTitle = 'Deactivate account';
  static const String chartDeactivateAction = 'Deactivate';
  static const String chartTypeAsset = 'Asset';
  static const String chartTypeLiability = 'Liability';
  static const String chartTypeEquity = 'Equity';
  static const String chartTypeRevenue = 'Revenue';
  static const String chartTypeExpense = 'Expense';
  static const String chartEffectiveCurrent = 'Current';
  static const String chartEffectiveOther = 'Other';

  static String chartDeactivateBody(String accountLabel) =>
      'Deactivate $accountLabel? It will no longer appear as an active chart account.';
}

/// Compatibility alias used across Accounts widgets.
typedef AccountsCopy = AccountsStrings;

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
  static const String applyFilters = 'Apply filters';
  static const String postedDateFilterLabel = 'Posted date';
  static const String updatedDateFilterLabel = 'Updated date';
  static const String allFields = 'All';
  static const String notesLabel = 'Notes';
  static const String reasonLabel = 'Reason';
  static const String reasonValidation = 'Reason is required.';
  static const String unknownValue = '—';

  static const String journalExactSimilarDialogTitle = 'Exact draft journal found';
  static const String journalSimilarDialogTitle = 'Similar draft journals';
  static const String journalNoSimilarDialogTitle = 'No similar drafts';

  static const String openWorkLabel = 'Open work';
  static const String openWorkTooltip =
      'All accounting items that still need action across journals and approvals';
  static const String toPostLabel = 'To post';
  static const String toPostTooltip =
      'Draft journal entries ready to post to the books';
  static const String needApprovalLabel = 'Need approval';
  static const String needApprovalTooltip =
      'Journal posts, voids, and reversals awaiting approval';
  static const String generalLedgerLabel = 'General ledger';
  static const String generalLedgerTooltip =
      'Facility account balances and activity by GL account';
  static const String patientLedgersLabel = 'Patient ledgers';
  static const String patientLedgersTooltip =
      'Patient invoiced, paid, and outstanding balances';
  static const String accountChartLabel = 'Account chart';
  static const String accountChartTooltip =
      'Chart of accounts codes, types, and status';
  static const String invoicesLabel = 'Invoices';
  static const String invoicesTooltip =
      'Facility outflow invoices — money leaving the facility';

  static const String glEmpty = 'No accounts match.';
  static const String openWorkEmpty = 'No open work.';
  static const String toPostEmpty = 'No drafts to post.';
  static const String needApprovalEmpty = 'No pending approvals.';
  static const String patientLedgersEmpty = 'No patients match.';
  static const String chartEmpty = 'No accounts match.';
  static const String invoicesEmpty = 'No invoices match.';
  static const String invoicesEmptyBody =
      'Try another search or create an invoice.';
  static const String invoicesSearchHint = 'Invoice, payee, status…';
  static const String createInvoiceAction = 'Create';
  static const String createInvoiceTitle = 'Create invoice';
  static const String editInvoiceTitle = 'Edit invoice';
  static const String createInvoiceSubmitAction = 'Create Invoice';
  static const String invoiceDetailsTitle = 'Invoice details';
  static const String invoicePayeeSectionTitle = 'Payee';
  static const String invoiceItemsSectionTitle = 'Items';
  static const String invoicePayeeLabel = 'Payee';
  static const String invoiceDateLabel = 'Invoice date';
  static const String invoiceReferenceLabel = 'Reference';
  static const String invoiceCurrencyLabel = 'Currency';
  static const String invoiceNumberColumn = 'Invoice';
  static const String invoicePayeeColumn = 'Payee';
  static const String invoiceDateColumn = 'Date';
  static const String invoiceTotalColumn = 'Total';
  static const String invoiceActionsColumn = 'Actions';
  static const String invoiceItemNameLabel = 'Item name';
  static const String invoiceItemDescriptionLabel = 'Description';
  static const String invoiceItemQuantityLabel = 'Quantity';
  static const String invoiceItemUnitPriceLabel = 'Unit price';
  static const String invoiceItemLineTotalLabel = 'Line total';
  static const String invoiceAddItemAction = 'Add item';
  static const String createItemTitle = 'Add item';
  static const String editItemTitle = 'Edit item';
  static const String invoiceRemoveItemAction = 'Delete';
  static const String invoiceGrandTotalLabel = 'Total';
  static const String invoiceItemsRequired = 'Add at least one line item.';
  static const String invoiceItemsEmpty = 'No items yet.';
  static const String invoiceItemsEmptyBody = 'Add an item to add it here.';
  static const String invoicePayeeRequired = 'Payee is required.';
  static const String invoiceItemNameRequired = 'Item name is required.';
  static const String invoiceItemQuantityRequired = 'Quantity is required.';
  static const String invoiceItemUnitPriceRequired = 'Unit price is required.';

  static String invoiceItemsCountLabel(int count) {
    return count == 1 ? '1 item' : '$count items';
  }
  static const String invoiceVoidTitle = 'Delete invoice';
  static const String invoiceVoided = 'Invoice deleted.';
  static const String statusVoided = 'Voided';
  static const String statusIssued = 'Issued';

  static const String patientLedgersSearchHint = 'Patient…';
  static const String patientLedgersSearchSemantic = 'Search patient ledgers';
  static const String patientColumn = 'Patient';
  static const String patientIdColumn = 'Patient ID';
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
  static const String periodDatesField = 'Dates';
  static const String periodTrialSnapshotLabel = 'Trial snapshot';
  static const String periodTrialSnapshotValue = 'Available in books detail';
  static const String periodPrintAction = 'Print';

  static const String periodExactDialogTitle = 'Exact or overlapping period';
  static const String periodSimilarDialogTitle = 'Similar periods';
  static const String periodNoSimilarDialogTitle = 'No similar periods';
  static const String periodExactBannerTitle = 'Exact match';
  static const String periodSimilarBannerTitle = 'Near match';
  static const String periodNoSimilarBannerTitle = 'No matches';
  static const String periodExactDialogBody =
      'An identical period already exists. Select the existing period or cancel.';
  static const String periodOverlapDialogBody =
      'This date range overlaps an open period. Select the existing period or cancel.';
  static const String periodSimilarDialogBody =
      'Review near-duplicate periods before opening another.';
  static const String periodNoSimilarDialogBody =
      'No similar periods found. You can continue.';
  static const String periodSelectExisting = 'Select existing';
  static const String periodContinueOpen = 'Continue open';

  static const String booksPrintOptionsSection = 'Print sections';
  static const String booksPrintSectionHeader = 'Header / facility';
  static const String booksPrintSectionPeriod = 'Period';
  static const String booksPrintSectionChecklist = 'Close checklist';
  static const String booksPrintSectionNotes = 'Notes';
  static const String booksPrintSectionFooter = 'Footer / signature';
  static const String booksPrintFooter = 'Accounts period print';

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
  static const String notRecorded = 'Not recorded';

  static const String chartExactDialogTitle = 'Exact chart account found';
  static const String chartSimilarDialogTitle = 'Similar chart accounts';
  static const String chartNoSimilarDialogTitle = 'No similar accounts';
  static const String chartExactBannerTitle = 'Exact match';
  static const String chartSimilarBannerTitle = 'Near match';
  static const String chartNoSimilarBannerTitle = 'No matches';
  static const String chartExactCodeDialogBody =
      'An account with this code already exists. Select the existing account or cancel.';
  static const String chartExactDialogBody =
      'An identical chart account already exists. Select it or cancel.';
  static const String chartSimilarDialogBody =
      'Review near-duplicate chart accounts before saving.';
  static const String chartNoSimilarDialogBody =
      'No similar accounts found. You can continue.';
  static const String chartSelectExisting = 'Select existing';
  static const String chartOverwriteExisting = 'Overwrite';
  static const String chartContinueCreate = 'Continue create';
  static const String chartContinueSave = 'Continue save';

  static const String chartPrintAction = 'Print';
  static const String chartPrintTitle = 'Account chart';
  static const String chartPrintOptionsSection = 'Print sections';
  static const String chartPrintSectionSummary = 'Summary';
  static const String chartPrintSectionRows = 'Accounts';
  static const String chartPrintSectionFooter = 'Footer / signature';
  static const String chartPrintFooter = 'Accounts chart print';

  static String chartPrintRowCount(int count) =>
      count == 1 ? '1 account' : '$count accounts';

  static String chartDeactivateBody(String accountLabel) =>
      'Deactivate $accountLabel? It will no longer appear as an active chart account.';
}

/// Compatibility alias used across Accounts widgets.
typedef AccountsCopy = AccountsStrings;

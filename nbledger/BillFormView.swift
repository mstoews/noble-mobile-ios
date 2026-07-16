//
//  BillFormView.swift
//  nbledger
//
//  Bill entry form shared by the capture-confirm flow (prefilled from the
//  AI extraction, with the uploaded document attached on save) and the
//  manual entry tab (no prefill, no document).
//
//  Save path per CONTRACT.md §4/§2.1: POST create_bill (booked:false)
//  -> header.journal_id -> POST attach_bill_asset. If the attach fails
//  the bill is already saved; the form keeps the journal id and offers a
//  retry instead of failing silently.
//

import SwiftUI

/// Extraction-derived prefill. Fields the server could not read arrive as
/// "" / 0.0 and must be mapped to nil (leave the form field empty) before
/// constructing this.
struct BillPrefill {
    var invoiceNumber: String?
    var amount: String?
    var description: String?
    var invoiceDate: Date?
    var dueDate: Date?
    var vendorName: String?
}

struct BillFormView: View {
    @Environment(APIService.self) private var apiService

    /// Confirmed asset to attach after a successful create_bill.
    let assetId: String?
    /// Captured document shown above the form, when present.
    let capturedImage: UIImage?
    let prefill: BillPrefill?
    /// Called after "New Invoice" resets the form (the capture flow uses
    /// this to clear its upload/extraction state). The form always resets
    /// itself in place, so the manual tab works without wiring this.
    var onDone: (() -> Void)?
    /// Shows a "View in Journal Booking" action on the saved state — the
    /// capture loop uses it to land in the booking queue with a banner
    /// (create_bill writes an OPEN unbooked AP journal).
    var onViewInPayables: (() -> Void)?

    // Form fields
    @State private var invoiceNumber = ""
    @State private var amount = ""
    @State private var billDescription = ""
    @State private var invoiceDate = Date()
    @State private var dueDate = Date()
    @State private var selectedVendor: APVendor?
    @State private var selectedFund: FundRef?
    @State private var selectedAccount: GLAccountRef?

    // Reference data
    @State private var vendors: [APVendor] = []
    @State private var funds: [FundRef] = []
    @State private var accounts: [GLAccountRef] = []
    @State private var isLoadingReferenceData = false
    @State private var referenceDataError: String?
    @State private var didApplyPrefill = false

    // Pickers
    @State private var showVendorPicker = false
    @State private var showFundPicker = false
    @State private var showAccountPicker = false

    // Save state
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var savedJournalId: Int?
    @State private var attachedAssetId: String?
    @State private var attachError: String?

    /// Expense accounts eligible for the single expense line.
    private var expenseAccounts: [GLAccountRef] {
        accounts.filter {
            $0.acctType?.uppercased() == "EXPENSE"
                && $0.parentAccount != true
                && ($0.status ?? "ACTIVE").uppercased() == "ACTIVE"
        }
    }

    private var canSubmit: Bool {
        guard !isSubmitting,
              selectedVendor != nil,
              selectedFund != nil,
              selectedAccount != nil,
              !invoiceNumber.trimmingCharacters(in: .whitespaces).isEmpty
        else { return false }
        guard let value = Decimal(string: amount.trimmingCharacters(in: .whitespaces)),
              value > 0
        else { return false }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                if let savedJournalId {
                    savedSection(journalId: savedJournalId)
                } else {
                    formSection
                }
            }
            .padding(.top)
        }
        .task { await loadReferenceData() }
        .sheet(isPresented: $showVendorPicker) {
            VendorPickerSheet(vendors: vendors, selected: $selectedVendor) { vendor in
                applyVendorDefaults(vendor)
            }
        }
        .sheet(isPresented: $showFundPicker) {
            FundPickerSheet(funds: funds, selected: $selectedFund)
        }
        .sheet(isPresented: $showAccountPicker) {
            AccountPickerSheet(accounts: expenseAccounts, selected: $selectedAccount)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bill Details")
                .font(.headline)
                .padding(.horizontal)

            if isLoadingReferenceData {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading vendors and accounts...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            if let referenceDataError {
                VStack(spacing: 8) {
                    Text(referenceDataError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await loadReferenceData() } }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }

            VStack(spacing: 12) {
                FormField(label: "Invoice Number", text: $invoiceNumber)
                FormField(label: "Amount", text: $amount, keyboard: .decimalPad)
                FormField(label: "Description", text: $billDescription)

                pickerRow(label: "Vendor",
                          value: selectedVendor?.displayName,
                          placeholder: "Select a vendor") {
                    showVendorPicker = true
                }
                pickerRow(label: "Fund",
                          value: selectedFund?.displayName,
                          placeholder: "Select a fund") {
                    showFundPicker = true
                }
                pickerRow(label: "Expense Account",
                          value: selectedAccount.map { "\($0.displayName) (\($0.codeLabel))" },
                          placeholder: "Select an account") {
                    showAccountPicker = true
                }

                DatePicker("Invoice Date", selection: $invoiceDate, displayedComponents: .date)
                    .font(.subheadline)
                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    .font(.subheadline)
            }
            .padding(.horizontal)

            Button {
                Task { await save() }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Bill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
            .padding(.horizontal)

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Saved state

    private func savedSection(journalId: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Bill created (journal #\(journalId))", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                if attachedAssetId != nil {
                    Label("Document attached", systemImage: "paperclip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            if let attachError {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The bill was saved, but attaching the document failed: \(attachError)")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Button {
                        Task { await attachDocumentIfNeeded() }
                    } label: {
                        Label("Retry Attach", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }

            BillDocumentsView(journalId: journalId)
                .padding(.horizontal)

            if let onViewInPayables {
                Button {
                    onViewInPayables()
                } label: {
                    Text("View in Journal Booking")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.nobleEmerald, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal)
            }

            Button {
                startNewBill()
            } label: {
                Text("New Invoice")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
    }

    // MARK: - Rows

    private func pickerRow(label: String, value: String?, placeholder: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: action) {
                HStack {
                    Text(value ?? placeholder)
                        .foregroundStyle(value != nil ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func loadReferenceData() async {
        guard vendors.isEmpty || funds.isEmpty || accounts.isEmpty else { return }
        isLoadingReferenceData = true
        referenceDataError = nil
        defer { isLoadingReferenceData = false }

        do {
            async let vendorsTask = apiService.fetchAPVendors()
            async let fundsTask = apiService.fetchFunds()
            async let accountsTask = apiService.fetchGLAccounts()
            let (v, f, a) = try await (vendorsTask, fundsTask, accountsTask)
            vendors = v
            funds = f
            accounts = a
            applyPrefillIfNeeded()
        } catch {
            referenceDataError = error.localizedDescription
        }
    }

    private func applyPrefillIfNeeded() {
        guard !didApplyPrefill, let prefill else { return }
        didApplyPrefill = true

        invoiceNumber = prefill.invoiceNumber ?? ""
        amount = prefill.amount ?? ""
        billDescription = prefill.description ?? ""
        if let date = prefill.invoiceDate { invoiceDate = date }
        if let date = prefill.dueDate { dueDate = date }

        // The extracted vendor_name is a hint — preselect a match for the
        // user to confirm, never submit it blindly.
        if let vendorName = prefill.vendorName {
            if let match = vendors.first(where: {
                $0.displayName.localizedCaseInsensitiveContains(vendorName)
                    || vendorName.localizedCaseInsensitiveContains($0.displayName)
            }) {
                selectedVendor = match
                applyVendorDefaults(match)
            }
        }
    }

    /// Prefill the expense account from the vendor's default account/child,
    /// but only when that exact pair exists in the chart of accounts.
    private func applyVendorDefaults(_ vendor: APVendor) {
        guard selectedAccount == nil,
              let account = vendor.account, let child = vendor.child else { return }
        if let match = expenseAccounts.first(where: { $0.account == account && $0.child == child }) {
            selectedAccount = match
        }
    }

    private func save() async {
        guard let vendor = selectedVendor,
              let fund = selectedFund,
              let account = selectedAccount else { return }
        let amountString = amount.trimmingCharacters(in: .whitespaces)
        guard let amountValue = Decimal(string: amountString), amountValue > 0 else {
            errorMessage = "Enter an amount greater than zero."
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let request = CreateBillRequest(
            vendorId: vendor.id,
            invoiceNo: invoiceNumber.trimmingCharacters(in: .whitespaces),
            transactionDate: Self.rfc3339DateOnly(invoiceDate),
            dueDate: Self.rfc3339DateOnly(dueDate),
            description: billDescription,
            expenseLines: [
                CreateBillExpenseLine(
                    fund: fund.fund,
                    account: account.account,
                    child: account.child,
                    amount: amountString,
                    description: billDescription
                )
            ],
            booked: false
        )

        do {
            let response = try await apiService.createBill(request)
            savedJournalId = response.header.journalId
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        await attachDocumentIfNeeded()
    }

    /// Attaches the captured document to the saved bill. Only runs with a
    /// journal id the server returned, and only for a confirmed asset
    /// (uploadAsset confirms before returning).
    private func attachDocumentIfNeeded() async {
        attachError = nil
        guard let journalId = savedJournalId,
              let assetId,
              attachedAssetId == nil else { return }
        do {
            try await apiService.attachBillAsset(journalId: journalId, assetId: assetId)
            attachedAssetId = assetId
        } catch {
            // The asset stays listed under listAssets(kind:"receipts") and
            // can be re-attached — surface the failure with a retry.
            attachError = error.localizedDescription
        }
    }

    /// Resets the form for a new bill. Reference data is kept; the stale
    /// prefill is not re-applied to the new blank form. In the capture flow
    /// `onDone` clears the parent's upload/extraction state (which also
    /// recreates this view with a fresh identity); on the manual tab the
    /// in-place reset is the whole behavior.
    private func startNewBill() {
        invoiceNumber = ""
        amount = ""
        billDescription = ""
        invoiceDate = Date()
        dueDate = Date()
        selectedVendor = nil
        selectedFund = nil
        selectedAccount = nil
        errorMessage = nil
        savedJournalId = nil
        attachedAssetId = nil
        attachError = nil
        didApplyPrefill = true
        onDone?()
    }

    /// RFC3339 timestamp at UTC midnight for the calendar date the user
    /// picked (create_bill requires RFC3339 `time.Time` fields).
    static func rfc3339DateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date) + "T00:00:00Z"
    }
}

// MARK: - Picker sheets

private struct VendorPickerSheet: View {
    let vendors: [APVendor]
    @Binding var selected: APVendor?
    var onSelect: ((APVendor) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [APVendor] {
        if searchText.isEmpty { return vendors }
        return vendors.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { vendor in
                Button {
                    selected = vendor
                    onSelect?(vendor)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(vendor.displayName)
                                .font(.body)
                            if let type = vendor.type {
                                Text(type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if vendor.id == selected?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search vendors")
            .navigationTitle("Select Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct FundPickerSheet: View {
    let funds: [FundRef]
    @Binding var selected: FundRef?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(funds) { fund in
                Button {
                    selected = fund
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(fund.fund)
                                .font(.body)
                            if let description = fund.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if fund.id == selected?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Fund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct AccountPickerSheet: View {
    let accounts: [GLAccountRef]
    @Binding var selected: GLAccountRef?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [GLAccountRef] {
        if searchText.isEmpty { return accounts }
        return accounts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.codeLabel.contains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { account in
                Button {
                    selected = account
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.displayName)
                                .font(.body)
                            Text(account.codeLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if account.id == selected?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search accounts")
            .navigationTitle("Select Expense Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

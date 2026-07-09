//
//  GLJournalView.swift
//  nbledger
//
//  Created by Murray Toews on 4/10/26.
//

import SwiftUI

// MARK: - Journal Filter

enum JournalFilterTab: String, CaseIterable {
    case all = "All"
    case open = "Open"
    case booked = "Booked"
    case closed = "Closed"
}

// MARK: - GL Journal List View

struct GLJournalView: View {
    @Environment(APIService.self) private var apiService

    @State private var journals: [JournalHeader] = []
    @State private var activeFilter: JournalFilterTab = .all
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false

    private var filteredJournals: [JournalHeader] {
        switch activeFilter {
        case .all:
            return journals
        case .open:
            return journals.filter { $0.status?.uppercased() == "OPEN" }
        case .booked:
            return journals.filter { $0.booked == true }
        case .closed:
            return journals.filter { $0.status?.uppercased() == "CLOSED" }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $activeFilter) {
                    ForEach(JournalFilterTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    if isLoading {
                        ProgressView("Loading journals...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text(errorMessage)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            Button("Retry") { Task { await loadJournals() } }
                                .buttonStyle(.bordered)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredJournals.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No journals found.")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filteredJournals) { journal in
                            NavigationLink(value: journal.journalId) {
                                JournalHeaderRow(journal: journal)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Journals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await loadJournals() }
            .refreshable { await loadJournals() }
            .navigationDestination(for: Int.self) { journalId in
                GLJournalDetailView(
                    journalId: journalId,
                    onUpdate: { await loadJournals() }
                )
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateJournalSheet(onCreate: {
                    showCreateSheet = false
                    Task { await loadJournals() }
                })
            }
        }
    }

    private func loadJournals() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            journals = try await apiService.fetchJournalHeaders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Journal Header Row

struct JournalHeaderRow: View {
    let journal: JournalHeader

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(journal.description)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("J-\(journal.journalId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let status = journal.status {
                        Text(status)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor(status, booked: journal.booked).opacity(0.15), in: Capsule())
                            .foregroundStyle(statusColor(status, booked: journal.booked))
                    }
                    if journal.booked == true {
                        Text("Booked")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                    if let type = journal.type {
                        Text(type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let evidenceCount = journal.evidenceCount {
                        HStack(spacing: 2) {
                            Image(systemName: "paperclip")
                            Text("\(evidenceCount)")
                        }
                        .font(.caption)
                        .foregroundStyle(evidenceCount > 0 ? Color.blue : Color(.systemGray2))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(evidenceCount > 0
                            ? "\(evidenceCount) evidence attachments"
                            : "No evidence attached")
                    }
                }
                if let date = journal.transactionDate {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let amount = journal.amount {
                Text(amount, format: .currency(code: "USD"))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(amount < 0 ? .red : .primary)
            }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ status: String, booked: Bool?) -> Color {
        if booked == true { return .blue }
        switch status.uppercased() {
        case "OPEN":   return .orange
        case "CLOSED": return .secondary
        default:       return .blue
        }
    }
}

// MARK: - GL Journal Detail View

struct GLJournalDetailView: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let journalId: Int
    var onUpdate: () async -> Void

    @State private var entry: JournalEntry?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showBookConfirmation = false
    @State private var showCloseConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showCloneSheet = false
    @State private var actionMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading journal...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let entry {
                journalContent(entry)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await loadJournal() } }
                        .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .navigationTitle("Journal \(journalId)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadJournal() }
    }

    private func journalContent(_ entry: JournalEntry) -> some View {
        List {
            Section("Header") {
                LabeledContent("Journal #", value: "\(entry.journalId ?? 0)")
                LabeledContent("Description", value: entry.displayDescription)
                if let type = entry.type {
                    LabeledContent("Type", value: type)
                }
                if let status = entry.status {
                    LabeledContent("Status") {
                        Text(status)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(journalStatusColor(status, booked: entry.booked).opacity(0.15), in: Capsule())
                            .foregroundStyle(journalStatusColor(status, booked: entry.booked))
                    }
                }
                if entry.booked == true {
                    LabeledContent("Booked") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    if let bookedDate = entry.bookedDate {
                        LabeledContent("Booked Date", value: bookedDate)
                    }
                    if let bookedUser = entry.bookedUser {
                        LabeledContent("Booked By", value: bookedUser)
                    }
                }
                if let date = entry.transactionDate {
                    LabeledContent("Transaction Date", value: date)
                }
                if let period = entry.period, let year = entry.periodYear {
                    LabeledContent("Period", value: "\(period) / \(year)")
                }
                if let partyId = entry.partyId {
                    LabeledContent("Party", value: partyId)
                }
                if let invoiceNo = entry.invoiceNo {
                    LabeledContent("Invoice #", value: invoiceNo)
                }
                if let dueDate = entry.dueDate {
                    LabeledContent("Due Date", value: dueDate)
                }
                if let templateName = entry.templateName {
                    LabeledContent("Template", value: templateName)
                }
            }

            Section("Amounts") {
                if let amount = entry.amount {
                    LabeledContent("Total Amount") {
                        Text(amount, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                }
                if let details = entry.details, !details.isEmpty {
                    let totalDebit = details.compactMap(\.debit).reduce(0, +)
                    let totalCredit = details.compactMap(\.credit).reduce(0, +)
                    LabeledContent("Total Debits") {
                        Text(totalDebit, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                    LabeledContent("Total Credits") {
                        Text(totalCredit, format: .currency(code: "USD"))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    }
                    if abs(totalDebit - totalCredit) > 0.005 {
                        LabeledContent("Difference") {
                            Text(totalDebit - totalCredit, format: .currency(code: "USD"))
                                .monospacedDigit()
                                .foregroundStyle(.red)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }

            Section("Journal Lines") {
                if let details = entry.details, !details.isEmpty {
                    ForEach(details) { detail in
                        JournalDetailRow(detail: detail)
                    }
                } else {
                    Text("No journal lines.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            JournalEvidenceSection(journalId: journalId, onEvidenceChanged: onUpdate)

            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.subheadline)
                        .foregroundStyle(actionMessage.contains("Error") ? .red : .green)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            Section("Actions") {
                if entry.booked != true {
                    Button {
                        showBookConfirmation = true
                    } label: {
                        Label("Book Journal", systemImage: "book.closed")
                    }
                }

                if entry.status?.uppercased() != "CLOSED" {
                    Button {
                        showCloseConfirmation = true
                    } label: {
                        Label("Close Journal", systemImage: "lock")
                    }
                }

                Button {
                    showCloneSheet = true
                } label: {
                    Label("Clone as Template", systemImage: "doc.on.doc")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Journal", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .confirmationDialog("Book this journal entry?", isPresented: $showBookConfirmation, titleVisibility: .visible) {
            Button("Book") {
                Task { await bookJournal(entry) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will post the journal to the general ledger.")
        }
        .confirmationDialog("Close this journal entry?", isPresented: $showCloseConfirmation, titleVisibility: .visible) {
            Button("Close") {
                Task { await closeJournal(entry) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this journal entry?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deleteJournal(entry) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCloneSheet) {
            CloneJournalSheet(journalId: entry.journalId ?? 0, onClone: {
                showCloneSheet = false
                Task { await loadJournal() }
            })
        }
    }

    private func loadJournal() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            entry = try await apiService.fetchJournalById(journalId)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
    }

    private func bookJournal(_ entry: JournalEntry) async {
        actionMessage = nil
        let params = BookJournalRequest(
            journalId: entry.journalId ?? 0,
            userName: "MOBILE",
            period: entry.period ?? 1,
            year: entry.periodYear ?? 2026
        )
        do {
            try await apiService.bookJournalEntry(params)
            actionMessage = "Journal booked successfully."
            await onUpdate()
            await loadJournal()
        } catch {
            actionMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func closeJournal(_ entry: JournalEntry) async {
        actionMessage = nil
        let params = CloseJournalRequest(
            journalId: entry.journalId ?? 0,
            bookedUser: "MOBILE"
        )
        do {
            try await apiService.closeJournalEntry(params)
            actionMessage = "Journal closed successfully."
            await onUpdate()
            await loadJournal()
        } catch {
            actionMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func deleteJournal(_ entry: JournalEntry) async {
        do {
            try await apiService.deleteJournalEntry(DeleteJournalRequest(journalId: entry.journalId ?? 0))
            await onUpdate()
            dismiss()
        } catch {
            actionMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func journalStatusColor(_ status: String, booked: Bool?) -> Color {
        if booked == true { return .blue }
        switch status.uppercased() {
        case "OPEN":   return .orange
        case "CLOSED": return .secondary
        default:       return .blue
        }
    }
}

// MARK: - Journal Detail Row

struct JournalDetailRow: View {
    let detail: JournalDetail

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.description ?? "Line \(detail.journalSubid ?? 0)")
                    .font(.subheadline)
                HStack(spacing: 6) {
                    if let account = detail.account {
                        Text("Acct: \(account)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let child = detail.child, child > 0 {
                        Text(".\(child)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let childDesc = detail.childDesc {
                        Text(childDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let fund = detail.fund, !fund.isEmpty {
                    Text("Fund: \(fund)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let debit = detail.debit, debit > 0 {
                    Text("Dr: \(debit, format: .currency(code: "USD"))")
                        .font(.caption.monospacedDigit())
                }
                if let credit = detail.credit, credit > 0 {
                    Text("Cr: \(credit, format: .currency(code: "USD"))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

// MARK: - Evidence Row

struct EvidenceRow: View {
    let evidence: GlEvidence

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(evidence.description ?? "Evidence")
                    .font(.subheadline)
                HStack(spacing: 6) {
                    if let reference = evidence.reference {
                        Text(reference)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let date = evidence.dateCreated {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if evidence.confirmed == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Create Journal Sheet

struct CreateJournalSheet: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    var onCreate: () -> Void

    @State private var description = ""
    @State private var amount = ""
    @State private var journalType = ""
    @State private var transactionDate = Date()
    @State private var partyId = ""

    // Detail lines
    @State private var detailLines: [EditableDetailLine] = [
        EditableDetailLine(),
        EditableDetailLine()
    ]

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    // Templates
    @State private var templates: [JournalTemplate] = []
    @State private var selectedTemplate: JournalTemplate?
    @State private var showTemplatePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Template selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Template")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            showTemplatePicker = true
                        } label: {
                            HStack {
                                Text(selectedTemplate?.displayName ?? "Select a template (optional)")
                                    .foregroundStyle(selectedTemplate != nil ? .primary : .secondary)
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
                    .padding(.horizontal)

                    // Header fields
                    VStack(spacing: 12) {
                        FormField(label: "Description", text: $description)
                        FormField(label: "Amount", text: $amount, keyboard: .decimalPad)
                        FormField(label: "Type (e.g., JE, AP, AR)", text: $journalType)
                        FormField(label: "Party ID (optional)", text: $partyId)

                        DatePicker("Transaction Date", selection: $transactionDate, displayedComponents: .date)
                            .font(.subheadline)
                    }
                    .padding(.horizontal)

                    // Detail lines
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Journal Lines")
                                .font(.headline)
                            Spacer()
                            Button {
                                detailLines.append(EditableDetailLine())
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }
                        .padding(.horizontal)

                        ForEach($detailLines) { $line in
                            EditableDetailLineView(line: $line, onDelete: {
                                if detailLines.count > 2 {
                                    detailLines.removeAll { $0.id == line.id }
                                }
                            })
                        }

                        // Balance check
                        let totalDebit = detailLines.compactMap { Double($0.debit) }.reduce(0, +)
                        let totalCredit = detailLines.compactMap { Double($0.credit) }.reduce(0, +)
                        HStack {
                            Text("Debits: \(totalDebit, format: .currency(code: "USD"))")
                                .font(.caption.monospacedDigit())
                            Spacer()
                            Text("Credits: \(totalCredit, format: .currency(code: "USD"))")
                                .font(.caption.monospacedDigit())
                        }
                        .padding(.horizontal)

                        if abs(totalDebit - totalCredit) > 0.005 {
                            Text("Out of balance by \(abs(totalDebit - totalCredit), format: .currency(code: "USD"))")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                    }

                    Button {
                        Task { await submitJournal() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Journal")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || description.isEmpty)
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Create Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadTemplates() }
            .sheet(isPresented: $showTemplatePicker) {
                templatePickerSheet
            }
        }
    }

    private var templatePickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    selectedTemplate = nil
                    showTemplatePicker = false
                } label: {
                    Text("None")
                        .foregroundStyle(selectedTemplate == nil ? .blue : .primary)
                }
                .buttonStyle(.plain)

                ForEach(templates) { template in
                    Button {
                        applyTemplate(template)
                        showTemplatePicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(template.displayName)
                                    .font(.body)
                                if let desc = template.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if template.id == selectedTemplate?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Select Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTemplatePicker = false }
                }
            }
        }
    }

    private func applyTemplate(_ template: JournalTemplate) {
        selectedTemplate = template
        if let type = template.journalType {
            journalType = type
        }
        if let desc = template.description {
            description = desc
        }
        if let templateDetails = template.details, !templateDetails.isEmpty {
            detailLines = templateDetails.map { detail in
                var line = EditableDetailLine()
                line.account = detail.account.map(String.init) ?? ""
                line.child = detail.child.map(String.init) ?? ""
                line.description = detail.description ?? ""
                line.debit = detail.debit.map { String(format: "%.2f", $0) } ?? ""
                line.credit = detail.credit.map { String(format: "%.2f", $0) } ?? ""
                line.fund = detail.fund ?? ""
                return line
            }
        }
    }

    private func loadTemplates() async {
        do {
            templates = try await apiService.fetchTemplates()
        } catch {
            templates = []
        }
    }

    private func submitJournal() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let details = detailLines.enumerated().compactMap { index, line -> CreateJournalDetailRequest? in
            let debit = Double(line.debit) ?? 0
            let credit = Double(line.credit) ?? 0
            guard debit > 0 || credit > 0 else { return nil }
            return CreateJournalDetailRequest(
                journalId: 0,
                journalSubid: index + 1,
                account: Int(line.account),
                child: Int(line.child),
                description: line.description.isEmpty ? nil : line.description,
                debit: debit > 0 ? debit : nil,
                credit: credit > 0 ? credit : nil,
                createDate: formatter.string(from: Date()),
                createUser: "MOBILE",
                fund: line.fund.isEmpty ? nil : line.fund
            )
        }

        let params = CreateFullJournalRequest(
            description: description,
            createUser: "MOBILE",
            transactionDate: formatter.string(from: transactionDate),
            type: journalType.isEmpty ? "JE" : journalType,
            amount: Double(amount),
            partyId: partyId.isEmpty ? nil : partyId,
            templateRef: selectedTemplate?.templateRef,
            details: details.isEmpty ? nil : details
        )

        do {
            try await apiService.createFullJournal(params)
            onCreate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Editable Detail Line

struct EditableDetailLine: Identifiable {
    let id = UUID()
    var account = ""
    var child = ""
    var description = ""
    var debit = ""
    var credit = ""
    var fund = ""
}

struct EditableDetailLineView: View {
    @Binding var line: EditableDetailLine
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Account")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Acct", text: $line.account)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Child")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Child", text: $line.child)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Description")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Desc", text: $line.description)
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Debit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $line.debit)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Credit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $line.credit)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fund")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Fund", text: $line.fund)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - Clone Journal Sheet

struct CloneJournalSheet: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let journalId: Int
    var onClone: () -> Void

    @State private var templateDescription = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Clone journal \(journalId) as a template")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                FormField(label: "Template Description", text: $templateDescription)
                    .padding(.horizontal)

                Button {
                    Task { await cloneJournal() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Clone as Template")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || templateDescription.isEmpty)
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Clone Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func cloneJournal() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await apiService.cloneJournalEntry(CloneJournalRequest(
                journalId: journalId,
                templateDescription: templateDescription
            ))
            onClone()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    GLJournalView()
        .environment(APIService())
}

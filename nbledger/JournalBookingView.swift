//
//  JournalBookingView.swift
//  nbledger
//
//  Confirmation screen for booking and closing open GL journals in bulk.
//  Booking flips the booked flag to true and triggers regeneration of the
//  account balances on the server; closing marks a journal CLOSED without
//  posting. The server enforces separation of duties per journal (the
//  creator of a journal cannot book or close it).
//

import SwiftUI

struct JournalBookingView: View {
    @Environment(APIService.self) private var apiService

    @State private var journals: [JournalHeader] = []
    @State private var selection: Set<Int> = []
    @State private var currentPeriod: CurrentPeriod?
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var bulkResult: BulkJournalResponse?
    @State private var showBookConfirmation = false
    @State private var showCloseConfirmation = false

    /// Journals eligible for confirmation: open and not yet booked.
    private var openJournals: [JournalHeader] {
        journals
            .filter { ($0.status ?? "") == "OPEN" && $0.booked != true }
            .sorted { $0.journalId > $1.journalId }
    }

    private var selectedAmount: Double {
        openJournals
            .filter { selection.contains($0.journalId) }
            .compactMap(\.amount)
            .reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            if !openJournals.isEmpty {
                actionBar
            }
        }
        .navigationTitle("Journal Booking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(selection.count == openJournals.count ? "Deselect All" : "Select All") {
                    if selection.count == openJournals.count {
                        selection.removeAll()
                    } else {
                        selection = Set(openJournals.map(\.journalId))
                    }
                }
                .disabled(openJournals.isEmpty)
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
        .sheet(item: $bulkResult) { result in
            BulkResultSheet(result: result)
        }
        .confirmationDialog(
            bookPrompt,
            isPresented: $showBookConfirmation,
            titleVisibility: .visible
        ) {
            Button("Book \(selection.count) Journal\(selection.count == 1 ? "" : "s")") {
                Task { await bookSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Booking sets the booked flag and regenerates the affected account balances. Booked journals cannot be edited or deleted.")
        }
        .confirmationDialog(
            "Close \(selection.count) journal\(selection.count == 1 ? "" : "s")?",
            isPresented: $showCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Close \(selection.count) Journal\(selection.count == 1 ? "" : "s")") {
                Task { await closeSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Closing marks the journals CLOSED without posting to account balances.")
        }
    }

    private var bookPrompt: String {
        if let period = currentPeriod {
            return "Book \(selection.count) journal\(selection.count == 1 ? "" : "s") into period \(period.periodId)/\(period.periodYear)?"
        }
        return "Book \(selection.count) journal\(selection.count == 1 ? "" : "s")?"
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && journals.isEmpty {
            ProgressView("Loading journals...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await loadData() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if openJournals.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.rectangle.stack")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No open journals")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("All journal entries have been confirmed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(openJournals) { journal in
                        SelectableJournalRow(
                            journal: journal,
                            isSelected: selection.contains(journal.journalId)
                        ) {
                            if selection.contains(journal.journalId) {
                                selection.remove(journal.journalId)
                            } else {
                                selection.insert(journal.journalId)
                            }
                        }
                    }
                } header: {
                    Text("\(openJournals.count) open journal\(openJournals.count == 1 ? "" : "s")")
                } footer: {
                    if let period = currentPeriod {
                        Text("Booking posts into period \(period.periodId)/\(period.periodYear) and updates account balances. You cannot book or close journals you created.")
                    } else {
                        Text("You cannot book or close journals you created.")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            if !selection.isEmpty {
                HStack {
                    Text("\(selection.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(selectedAmount, format: .currency(code: "USD"))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }

            HStack(spacing: 12) {
                Button {
                    showCloseConfirmation = true
                } label: {
                    Label("Close", systemImage: "lock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(selection.isEmpty || isSubmitting)

                Button {
                    showBookConfirmation = true
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Book", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection.isEmpty || isSubmitting || currentPeriod == nil)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            journals = try await apiService.fetchJournalHeaders()
            currentPeriod = try? await apiService.fetchCurrentActivePeriod()
            // Drop selections that no longer correspond to an open journal.
            let openIds = Set(openJournals.map(\.journalId))
            selection = selection.intersection(openIds)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func bookSelected() async {
        guard let period = currentPeriod else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let result = try await apiService.bulkBookJournalEntries(
                journalIds: Array(selection).sorted(),
                period: period.periodId,
                periodYear: period.periodYear
            )
            bulkResult = result
            selection.removeAll()
            await loadData()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func closeSelected() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let result = try await apiService.bulkCloseJournalEntries(journalIds: Array(selection).sorted())
            bulkResult = result
            selection.removeAll()
            await loadData()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - Selectable row

struct SelectableJournalRow: View {
    let journal: JournalHeader
    let isSelected: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(journal.description)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("J-\(journal.journalId)")
                        if let type = journal.type, !type.isEmpty {
                            Text(type)
                        }
                        if let date = journal.transactionDate {
                            Text(date)
                        }
                        if let creator = journal.createUser, !creator.isEmpty {
                            Text("by \(creator)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if let amount = journal.amount {
                    Text(amount, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(amount < 0 ? .red : .primary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bulk result sheet

extension BulkJournalResponse: Identifiable {
    var id: String { "\(operation)-\(total)-\(succeeded)-\(failed)" }
}

struct BulkResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: BulkJournalResponse

    private var operationTitle: String {
        result.operation == "bulk_book" ? "Booking Results" : "Closing Results"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("\(result.succeeded) succeeded", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        if result.failed > 0 {
                            Label("\(result.failed) failed", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Section("Journals") {
                    ForEach(result.results) { row in
                        HStack(alignment: .top) {
                            Image(systemName: row.ok ? "checkmark.circle" : "xmark.circle")
                                .foregroundStyle(row.ok ? .green : .red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("J-\(row.journalId)")
                                    .font(.subheadline.weight(.medium))
                                if let error = row.error, !row.ok {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            Spacer()
                            if let status = row.status {
                                Text(status)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(operationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

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
    @State private var balanceByJournal: [Int: (debit: Double, credit: Double)] = [:]
    @State private var currentPeriod: CurrentPeriod?
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var bulkResult: BulkJournalResponse?
    @State private var showBookConfirmation = false

    /// Journals eligible for booking: open and not yet booked.
    private var openJournals: [JournalHeader] {
        journals
            .filter { ($0.status ?? "") == "OPEN" && $0.booked != true }
            .sorted { $0.journalId > $1.journalId }
    }

    private func isBalanced(_ journal: JournalHeader) -> Bool {
        guard let sums = balanceByJournal[journal.journalId] else { return false }
        return abs(sums.debit - sums.credit) < 0.005
    }

    private var balancedJournals: [JournalHeader] { openJournals.filter(isBalanced) }
    private var unbalancedCount: Int { openJournals.count - balancedJournals.count }
    private var openTotal: Double { openJournals.compactMap(\.amount).reduce(0, +) }

    var body: some View {
        content
            .navigationTitle("Journal Booking")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() }
            .refreshable { await loadData() }
            .safeAreaInset(edge: .bottom) {
                if !openJournals.isEmpty {
                    actionBar
                }
            }
            .sheet(item: $bulkResult) { result in
                BulkResultSheet(result: result)
            }
            .confirmationDialog(
                bookPrompt,
                isPresented: $showBookConfirmation,
                titleVisibility: .visible
            ) {
                Button("Book \(balancedJournals.count) Journal\(balancedJournals.count == 1 ? "" : "s")") {
                    Task { await bookBalanced() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Booking sets the booked flag and regenerates the affected account balances. Booked journals cannot be edited or deleted.")
            }
    }

    private var bookPrompt: String {
        let count = balancedJournals.count
        if let period = currentPeriod {
            return "Book \(count) balanced journal\(count == 1 ? "" : "s") into period \(period.periodId)/\(period.periodYear)?"
        }
        return "Book \(count) balanced journal\(count == 1 ? "" : "s")?"
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
                Text("All journal entries have been booked.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open entries")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text.money(openTotal)
                                .font(.title2.weight(.bold))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        Spacer()
                        if unbalancedCount > 0 {
                            StatusPill.overdue("\(unbalancedCount) unbalanced")
                        } else {
                            StatusPill.success("All balanced")
                        }
                    }
                }

                Section {
                    ForEach(openJournals) { journal in
                        NavigationLink {
                            GLJournalDetailView(
                                journalId: journal.journalId,
                                onUpdate: { await loadData() }
                            )
                        } label: {
                            BookingJournalRow(journal: journal, balanced: isBalanced(journal))
                        }
                    }
                } header: {
                    Text("\(openJournals.count) entr\(openJournals.count == 1 ? "y" : "ies") to review")
                } footer: {
                    if let period = currentPeriod {
                        Text("Booking posts into period \(period.periodId)/\(String(period.periodYear)) and updates account balances. You cannot book journals you created.")
                    } else {
                        Text("You cannot book journals you created.")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 6) {
            Button {
                showBookConfirmation = true
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Book \(balancedJournals.count) balanced entr\(balancedJournals.count == 1 ? "y" : "ies")")
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    balancedJournals.isEmpty ? Color.nobleSlateMuted : Color.nobleEmerald,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .disabled(balancedJournals.isEmpty || isSubmitting || currentPeriod == nil)

            if unbalancedCount > 0 {
                Text("\(unbalancedCount) unbalanced entr\(unbalancedCount == 1 ? "y" : "ies") skipped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        // Line sums decide the balanced/unbalanced state per entry.
        do {
            let details = try await apiService.fetchOpenJournalDetails()
            var sums: [Int: (debit: Double, credit: Double)] = [:]
            for line in details {
                guard let journalId = line.journalId else { continue }
                var entry = sums[journalId] ?? (0, 0)
                entry.debit += line.debit ?? 0
                entry.credit += line.credit ?? 0
                sums[journalId] = entry
            }
            balanceByJournal = sums
        } catch {
            balanceByJournal = [:]
        }
        isLoading = false
    }

    private func bookBalanced() async {
        guard let period = currentPeriod else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let result = try await apiService.bulkBookJournalEntries(
                journalIds: balancedJournals.map(\.journalId).sorted(),
                period: period.periodId,
                periodYear: period.periodYear
            )
            bulkResult = result
            await loadData()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - Booking row

struct BookingJournalRow: View {
    let journal: JournalHeader
    let balanced: Bool

    private var subtitle: String {
        if !balanced {
            return "J-\(journal.journalId) · Debits ≠ credits"
        }
        return ["J-\(journal.journalId)", journal.type, journal.transactionDate]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(balanced ? Color.nobleEmeraldSoft : Color.nobleWarnSoft)
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: balanced ? "checkmark" : "exclamationmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(balanced ? Color.nobleEmerald : Color.nobleWarn)
                }
                .accessibilityLabel(balanced ? "Balanced" : "Unbalanced")

            VStack(alignment: .leading, spacing: 2) {
                Text(journal.description)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(balanced ? Color.secondary : Color.nobleWarn)
                    .fontWeight(balanced ? .regular : .semibold)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let amount = journal.amount {
                Text.money(amount)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 2)
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

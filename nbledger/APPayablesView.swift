//
//  APPayablesView.swift
//  nbledger
//
//  Created by Murray Toews on 4/10/26.
//
//  Payables — what the tenant owes, by period.
//
//  Rebuilt on the bills surface. The `ap_transactions` family this screen was
//  originally written against (read_ap_transactions, create_ap_transaction,
//  update_ap_transaction_amount_paid, delete_ap_transaction) was deleted
//  server-side on 2026-08-16, so every one of its calls 404'd. The live source
//  of truth is `read_aging_bills_by_period` over ap_bills / gl_journal_header.
//
//  Creating a payable is not here on purpose: bills enter through the capture
//  flow's `create_bill`, and the deleted routes had no replacement for a
//  hand-entered AP transaction. Detail, approval and scheduling live in the
//  shared `BillDetailView`.
//

import SwiftUI

// MARK: - Date helper

private let apDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private func overdueDays(_ dueDate: String?) -> Int? {
    guard let dueDate, let date = apDateFormatter.date(from: dueDate) else { return nil }
    let days = Calendar.current.dateComponents(
        [.day], from: date, to: Calendar.current.startOfDay(for: Date())
    ).day ?? 0
    return days > 0 ? days : nil
}

// MARK: - Filter Tab

enum APFilterTab: String, CaseIterable {
    case open = "Open"
    case drafts = "Drafts"
    case paid = "Paid"
    case all = "All"
}

// MARK: - AP Payables Container

struct APPayablesView: View {
    @Environment(APIService.self) private var apiService

    @State private var bills: [AgingBill] = []
    @State private var vendorNames: [String: String] = [:]
    @State private var filter: APFilterTab = .open
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var readOnlyRole = false
    @State private var periodYear = Calendar.current.component(.year, from: Date())

    private var filtered: [AgingBill] {
        switch filter {
        case .open:
            // Owed money: posted to the ledger and not yet settled. A draft is
            // not yet a liability, so it gets its own tab rather than padding
            // this one.
            return bills.filter { $0.isPosted && !$0.isPaid }
        case .drafts:
            return bills.filter { $0.isDraft }
        case .paid:
            return bills.filter { $0.isPaid }
        case .all:
            return bills
        }
    }

    /// Sorted by urgency: most overdue first, then by due date.
    private var sorted: [AgingBill] {
        filtered.sorted { lhs, rhs in
            let l = overdueDays(lhs.dueDate) ?? -1
            let r = overdueDays(rhs.dueDate) ?? -1
            if l != r { return l > r }
            return lhs.dueDate < rhs.dueDate
        }
    }

    private var outstanding: Double {
        bills.filter { $0.isPosted && !$0.isPaid }.map(\.remainder).reduce(0, +)
    }

    private var overdue: Double {
        bills
            .filter { $0.isPosted && !$0.isPaid && overdueDays($0.dueDate) != nil }
            .map(\.remainder)
            .reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {
            summary

            Picker("Filter", selection: $filter) {
                ForEach(APFilterTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            content
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Payables")
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    // MARK: Summary

    private var summary: some View {
        HStack(spacing: 12) {
            summaryTile("Outstanding", outstanding, tint: .primary)
            summaryTile("Overdue", overdue, tint: overdue > 0 ? Color.nobleWarn : .secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func summaryTile(_ label: String, _ value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .currency(code: "USD"))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: NobleRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if isLoading && bills.isEmpty {
            ProgressView("Loading payables...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, bills.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text(errorMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await loadData() } }
                    .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if sorted.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(sorted) { bill in
                NavigationLink {
                    BillDetailView(
                        bill: bill,
                        vendorName: vendorNames[bill.vendorId],
                        readOnlyRole: readOnlyRole,
                        onUpdated: { Task { await loadData() } }
                    )
                } label: {
                    APBillRow(bill: bill, vendorName: vendorNames[bill.vendorId])
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .open:   return "Nothing outstanding in \(periodYear)."
        case .drafts: return "No unposted bills."
        case .paid:   return "No settled bills in \(periodYear)."
        case .all:    return "No bills in \(periodYear)."
        }
    }

    // MARK: Data

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if let period = try? await apiService.fetchCurrentActivePeriod() {
            periodYear = period.periodYear
        }

        do {
            // ALL, then filtered on the client: the server's `status` query
            // narrows by journal lifecycle, while the tabs here span both that
            // and the settlement state.
            bills = try await apiService.fetchAgingBills(periodYear: periodYear, status: "ALL")
        } catch {
            errorMessage = error.localizedDescription
        }

        if let vendors = try? await apiService.fetchApVendors() {
            vendorNames = Dictionary(uniqueKeysWithValues: vendors.map { ($0.id, $0.name) })
        }
        if let profile = try? await apiService.fetchMyProfile() {
            readOnlyRole = (profile.role ?? "").uppercased() == "READONLY"
        }
    }
}

// MARK: - AP Bill Row

struct APBillRow: View {
    let bill: AgingBill
    let vendorName: String?

    private var days: Int? { overdueDays(bill.dueDate) }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(vendorName ?? bill.vendorId)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(bill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !bill.invoiceNumber.isEmpty {
                        Text(bill.invoiceNumber)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let days {
                        StatusPill.open("\(days)d overdue")
                    } else if !bill.dueDate.isEmpty {
                        Text("due \(bill.dueDate)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if bill.isDraft {
                        // Not yet posted, so not yet a liability.
                        StatusPill.open("Draft")
                    }
                    if bill.approvalStatus == "PENDING" || bill.approvalStatus == "REVIEW" {
                        ApprovalStatusBadge(status: bill.approvalStatus)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(bill.remainder, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(days != nil ? Color.nobleWarn : .primary)
                if bill.amountPaid > 0 {
                    Text("of \(bill.amount, format: .currency(code: "USD"))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        APPayablesView()
    }
    .environment(APIService())
}

//
//  ActivityView.swift
//  nbledger
//
//  Activity tab — a unified feed of AP payments and AR receipts, with a
//  "Needs sign-off" segment fed by the bill-approval queue. Sign-off rows
//  push the same BillSignOffDetailView used by Payment Sign-Off.
//

import SwiftUI

struct ActivityView: View {
    @Environment(APIService.self) private var apiService

    enum Segment: Hashable {
        case all
        case signOff
    }

    @State private var segment: Segment = .all
    @State private var payments: [Payment] = []
    @State private var arTransactions: [ArTransaction] = []
    @State private var signOffBills: [AgingBill] = []
    @State private var vendorNames: [String: String] = [:]
    @State private var customerNames: [String: String] = [:]
    @State private var readOnlyRole = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var feed: [ActivityItem] {
        let out = payments.map { ActivityItem.payment($0) }
        let inn = arTransactions.map { ActivityItem.receipt($0) }
        return (out + inn).sorted { ($0.sortDate ?? "") > ($1.sortDate ?? "") }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $segment) {
                    Text("All").tag(Segment.all)
                    Text("Needs sign-off · \(signOffBills.count)").tag(Segment.signOff)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                content
            }
            .navigationTitle("Activity")
            .task { await loadData() }
            .refreshable { await loadData() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && payments.isEmpty && arTransactions.isEmpty {
            ProgressView("Loading activity...")
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
        } else if segment == .signOff {
            signOffList
        } else {
            allList
        }
    }

    @ViewBuilder
    private var allList: some View {
        if feed.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No transactions yet.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(feed) { item in
                NavigationLink {
                    switch item {
                    case .payment(let payment):
                        APPaymentDetailView(payment: payment, onUpdate: { await loadData() })
                    case .receipt(let transaction):
                        ARTransactionDetailView(transaction: transaction, onUpdate: { await loadData() })
                    }
                } label: {
                    ActivityRow(item: item, partyName: partyName(for: item))
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var signOffList: some View {
        if signOffBills.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Nothing awaiting sign-off.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(signOffBills) { bill in
                NavigationLink {
                    BillSignOffDetailView(
                        bill: bill,
                        vendorName: vendorNames[bill.vendorId],
                        readOnlyRole: readOnlyRole,
                        onUpdated: { Task { await loadData() } }
                    )
                } label: {
                    SignOffBillRow(bill: bill, vendorName: vendorNames[bill.vendorId])
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func partyName(for item: ActivityItem) -> String? {
        switch item {
        case .payment(let payment):
            guard let vendorId = payment.vendorId else { return nil }
            return vendorNames[vendorId]
        case .receipt(let transaction):
            guard let customerId = transaction.customerId else { return nil }
            return customerNames[customerId]
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            payments = try await apiService.fetchApTransactions()
        } catch {
            errorMessage = error.localizedDescription
        }
        do {
            arTransactions = try await apiService.fetchArTransactions()
        } catch {
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }

        // Feed loaded — a failure past this point shouldn't blank the screen.
        if errorMessage != nil && (!payments.isEmpty || !arTransactions.isEmpty) {
            errorMessage = nil
        }

        var year = Calendar.current.component(.year, from: Date())
        if let period = try? await apiService.fetchCurrentActivePeriod() {
            year = period.periodYear
        }
        if let bills = try? await apiService.fetchAgingBills(periodYear: year, status: "ALL") {
            signOffBills = bills.filter {
                $0.approvalStatus == "PENDING" || $0.approvalStatus == "REVIEW"
            }
        }
        if let vendors = try? await apiService.fetchApVendors() {
            vendorNames = Dictionary(uniqueKeysWithValues: vendors.map { ($0.id, $0.name) })
        }
        if let customers = try? await apiService.fetchArCustomers() {
            customerNames = Dictionary(uniqueKeysWithValues: customers.map { ($0.customerId, $0.customerName) })
        }
        if let profile = try? await apiService.fetchMyProfile() {
            let role = (profile.role ?? "").uppercased()
            readOnlyRole = role == "AUDITOR" || role == "REVIEWER"
        }
    }
}

// MARK: - Feed Item

enum ActivityItem: Identifiable {
    case payment(Payment)
    case receipt(ArTransaction)

    var id: String {
        switch self {
        case .payment(let payment): return "ap-\(payment.transactionId)"
        case .receipt(let transaction): return "ar-\(transaction.id)"
        }
    }

    /// ISO yyyy-MM-dd strings sort correctly lexicographically.
    var sortDate: String? {
        switch self {
        case .payment(let payment): return payment.transactionDate
        case .receipt(let transaction): return transaction.transactionDate
        }
    }

    var isMoneyIn: Bool {
        if case .receipt = self { return true }
        return false
    }
}

// MARK: - Row

private struct ActivityRow: View {
    let item: ActivityItem
    let partyName: String?

    private var title: String {
        switch item {
        case .payment(let payment):
            return partyName ?? payment.displayDescription
        case .receipt(let transaction):
            return partyName ?? transaction.displayDescription
        }
    }

    private var subtitle: String {
        switch item {
        case .payment(let payment):
            let ref = payment.invoiceId ?? payment.reference
            return [ref, payment.transactionDate].compactMap { $0 }.joined(separator: " · ")
        case .receipt(let transaction):
            let ref = transaction.receiptNo ?? transaction.reference
            return [ref, transaction.transactionDate].compactMap { $0 }.joined(separator: " · ")
        }
    }

    private var amount: Double {
        switch item {
        case .payment(let payment): return payment.amount ?? 0
        case .receipt(let transaction): return transaction.amount ?? 0
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(item.isMoneyIn ? Color.nobleEmerald : Color.nobleWarn)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: item.isMoneyIn ? "arrow.down" : "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(item.isMoneyIn ? "Money in" : "Money out")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text("\(item.isMoneyIn ? "+" : "–")\(abs(amount), format: .currency(code: "USD"))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(item.isMoneyIn ? Color.nobleEmerald : .primary)
        }
        .padding(.vertical, 2)
    }
}

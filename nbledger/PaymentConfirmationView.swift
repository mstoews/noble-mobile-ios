//
//  PaymentConfirmationView.swift
//  nbledger
//
//  Confirming AP payments the web has already raised.
//
//  The division of labour is deliberate. Linking a bank account is a web-side
//  setup step for an administrator, and the web builds the payment — header,
//  GL lines, apply lines — behind its own separation of duties. Without a
//  linked bank account no payment can be raised at all, on either surface, so
//  there is nothing for this screen to work around.
//
//  What is left for mobile is the confirmation. `post_payment` is the only
//  route that flips `approval_state` to APPROVED (`SetPaymentApprovalState`
//  exists in SQL but is exposed on no route), and it writes the journal and
//  closes the settled bills in the same act. So confirming IS posting, and
//  this screen never chooses an account or composes a line.
//
//  Cheque and cash payments follow the same path: the method is recorded on
//  the payment the web raised, and confirmation is identical.
//

import SwiftUI

struct PaymentConfirmationView: View {
    @Environment(APIService.self) private var apiService

    @State private var payments: [APPayment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var readOnlyRole = false

    /// Matches the window the More hub's badge counts.
    private static let windowDays = 90

    var body: some View {
        Group {
            if isLoading && payments.isEmpty {
                ProgressView("Loading payments...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, payments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.bordered)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if payments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Nothing awaiting confirmation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Payments are raised on the web.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(payments) { payment in
                    NavigationLink {
                        PaymentConfirmationDetailView(
                            payment: payment,
                            readOnlyRole: readOnlyRole,
                            onConfirmed: { Task { await load() } }
                        )
                    } label: {
                        PaymentAwaitingRow(payment: payment)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Confirm Payments")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -Self.windowDays, to: to) ?? to
        do {
            payments = try await apiService.fetchPaymentsAwaitingConfirmation(from: from, to: to)
        } catch {
            errorMessage = error.localizedDescription
        }
        if let profile = try? await apiService.fetchMyProfile() {
            readOnlyRole = (profile.role ?? "").uppercased() == "READONLY"
        }
    }
}

// MARK: - Row

struct PaymentAwaitingRow: View {
    let payment: APPayment

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(payment.displayParty)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let reference = payment.reference, !reference.isEmpty {
                        Text(reference)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let method = payment.method {
                        Text(method)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let state = payment.approvalState, state != "APPROVED" {
                        ApprovalStatusBadge(status: state)
                    }
                }
                if let date = payment.receiptDate {
                    Text(String(date.prefix(10)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(payment.amount ?? 0, format: .currency(code: payment.currency ?? "USD"))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail

struct PaymentConfirmationDetailView: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let payment: APPayment
    let readOnlyRole: Bool
    var onConfirmed: () -> Void

    @State private var lines: [PaymentTxnLine] = []
    @State private var applies: [PaymentApplyLine] = []
    @State private var period: CurrentPeriod?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    private var totalDebit: Double { lines.compactMap(\.debit).reduce(0, +) }
    private var totalCredit: Double { lines.compactMap(\.credit).reduce(0, +) }

    /// `post_payment` refuses anything outside 0.001, so say so before the
    /// round trip rather than after.
    private var isBalanced: Bool { abs(totalDebit - totalCredit) < 0.001 }

    private var canConfirm: Bool {
        !readOnlyRole && !isLoading && !isSubmitting && !lines.isEmpty && isBalanced && period != nil
    }

    var body: some View {
        List {
            Section("Payment") {
                DetailRow(label: "Party", value: payment.displayParty)
                if let reference = payment.reference { DetailRow(label: "Reference", value: reference) }
                if let receiptNo = payment.receiptNo { DetailRow(label: "Receipt #", value: receiptNo) }
                if let method = payment.method { DetailRow(label: "Method", value: method) }
                if let date = payment.receiptDate { DetailRow(label: "Paid on", value: String(date.prefix(10))) }
                if let account = payment.depositAccountDesc ?? payment.depositAccount {
                    DetailRow(label: "From", value: account)
                }
                HStack {
                    Text("Amount")
                    Spacer()
                    Text(payment.amount ?? 0, format: .currency(code: payment.currency ?? "USD"))
                        .monospacedDigit()
                        .fontWeight(.semibold)
                }
            }

            if isLoading {
                Section { ProgressView() }
            } else {
                // The journal the web built, shown before it is committed.
                Section {
                    ForEach(lines) { line in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\((line.debit ?? 0) > 0 ? "DR" : "CR") \(line.accountName ?? line.accountCode ?? "—")")
                                    .font(.subheadline)
                                Text([line.accountCode, line.fund].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(max(line.debit ?? 0, line.credit ?? 0),
                                 format: .currency(code: payment.currency ?? "USD"))
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                } header: {
                    Text("Journal to post")
                } footer: {
                    if lines.isEmpty {
                        Text("This payment has no GL lines, so it can't be posted. It needs finishing on the web.")
                            .foregroundStyle(Color.nobleWarn)
                    } else if !isBalanced {
                        Text("Debits \(totalDebit, format: .currency(code: "USD")) ≠ credits \(totalCredit, format: .currency(code: "USD")). The server will refuse it; it needs correcting on the web.")
                            .foregroundStyle(Color.nobleWarn)
                    } else if let period {
                        Text("Posts to period \(period.periodId)/\(period.periodYear), and closes any bill it settles in full.")
                    }
                }

                if !applies.isEmpty {
                    Section("Settles") {
                        ForEach(applies) { apply in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(apply.chargeDescription ?? apply.chargeNo ?? "Charge")
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    if let billId = apply.billJournalId {
                                        Text("Bill J-\(billId)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(apply.applyAmount ?? 0,
                                     format: .currency(code: payment.currency ?? "USD"))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            if !readOnlyRole {
                Section {
                    Button {
                        showConfirmation = true
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Label("Confirm payment", systemImage: "checkmark.circle")
                        }
                    }
                    .disabled(!canConfirm)
                } footer: {
                    Text("Confirming posts the journal above. An admin can reverse it afterwards.")
                }
            }
        }
        .navigationTitle("Payment \(payment.id)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .confirmationDialog(
            "Post this payment of \((payment.amount ?? 0).formatted(.currency(code: payment.currency ?? "USD")))?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm payment") { Task { await confirm() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func load() async {
        defer { isLoading = false }
        lines = (try? await apiService.fetchPaymentTxnLines(paymentId: payment.id)) ?? []
        applies = (try? await apiService.fetchPaymentApplyLines(paymentId: payment.id)) ?? []
        period = try? await apiService.fetchCurrentActivePeriod()
    }

    private func confirm() async {
        guard let period else { return }
        guard await BiometricGate.confirm(
            "Confirm a \((payment.amount ?? 0).formatted(.currency(code: payment.currency ?? "USD"))) payment"
        ) else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            _ = try await apiService.postPayment(PostPaymentRequest(
                id: payment.id,
                period: period.periodId,
                periodYear: period.periodYear,
                description: String("Payment \(payment.reference ?? String(payment.id)) — \(payment.displayParty)".prefix(200))
            ))
            onConfirmed()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

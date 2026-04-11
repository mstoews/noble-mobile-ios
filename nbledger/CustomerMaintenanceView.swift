//
//  CustomerMaintenanceView.swift
//  nbledger
//
//  Created by Murray Toews on 4/11/26.
//

import SwiftUI

// MARK: - Customer Filter

enum CustomerFilterTab: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case inactive = "Inactive"
}

// MARK: - Customer Maintenance

struct CustomerMaintenanceView: View {
    @Environment(APIService.self) private var apiService

    @State private var customers: [ArCustomer] = []
    @State private var activeFilter: CustomerFilterTab = .all
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false

    private var filteredCustomers: [ArCustomer] {
        var result = customers
        switch activeFilter {
        case .all: break
        case .active:
            result = result.filter { $0.customerStatus?.uppercased() == "ACTIVE" }
        case .inactive:
            result = result.filter { $0.customerStatus?.uppercased() != "ACTIVE" }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.customerName.localizedCaseInsensitiveContains(searchText)
                || ($0.customerShortName ?? "").localizedCaseInsensitiveContains(searchText)
                || ($0.customerContact ?? "").localizedCaseInsensitiveContains(searchText)
                || $0.customerId.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $activeFilter) {
                ForEach(CustomerFilterTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                if isLoading {
                    ProgressView("Loading customers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await loadCustomers() } }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredCustomers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No customers found.")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredCustomers) { customer in
                        NavigationLink(value: customer.id) {
                            CustomerRow(customer: customer)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Search customers")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("AR Customers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await loadCustomers() }
        .refreshable { await loadCustomers() }
        .navigationDestination(for: String.self) { customerId in
            if let customer = customers.first(where: { $0.id == customerId }) {
                CustomerDetailView(customer: customer, onUpdate: { await loadCustomers() })
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CustomerFormSheet(mode: .create, onSave: {
                showCreateSheet = false
                Task { await loadCustomers() }
            })
        }
    }

    private func loadCustomers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            customers = try await apiService.fetchArCustomers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Customer Row

struct CustomerRow: View {
    let customer: ArCustomer

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(customer.customerName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(customer.customerId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let status = customer.customerStatus {
                        Text(status)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(status.uppercased() == "ACTIVE" ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(status.uppercased() == "ACTIVE" ? .green : .secondary)
                    }
                    if let type = customer.customerType {
                        Text(type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let phone = customer.customerPhone, !phone.isEmpty {
                Image(systemName: "phone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Customer Detail

struct CustomerDetailView: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let customer: ArCustomer
    var onUpdate: () async -> Void

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Contact") {
                LabeledContent("Customer ID", value: customer.customerId)
                LabeledContent("Name", value: customer.customerName)
                if let shortName = customer.customerShortName {
                    LabeledContent("Short Name", value: shortName)
                }
                if let contact = customer.customerContact {
                    LabeledContent("Contact", value: contact)
                }
                if let phone = customer.customerPhone {
                    LabeledContent("Phone", value: phone)
                }
                if let fax = customer.customerFax {
                    LabeledContent("Fax", value: fax)
                }
            }

            Section("Address") {
                if let a1 = customer.customerAddress1 { LabeledContent("Address 1", value: a1) }
                if let a2 = customer.customerAddress2 { LabeledContent("Address 2", value: a2) }
                if let a3 = customer.customerAddress3 { LabeledContent("Address 3", value: a3) }
                if let pc = customer.customerPostalCode { LabeledContent("Postal Code", value: pc) }
            }

            Section("Account Links") {
                if let acct = customer.customerAccount {
                    LabeledContent("Account", value: String(format: "%.0f", acct))
                }
                if let child = customer.customerChild {
                    LabeledContent("Child", value: String(format: "%.0f", child))
                }
                if let vat = customer.customerVatAccount {
                    LabeledContent("VAT Account", value: String(format: "%.0f", vat))
                }
                if let vatChild = customer.customerVatChild {
                    LabeledContent("VAT Child", value: String(format: "%.0f", vatChild))
                }
                if let ar = customer.customerApAccount {
                    LabeledContent("AR Account", value: String(format: "%.0f", ar))
                }
                if let arChild = customer.customerApChild {
                    LabeledContent("AR Child", value: String(format: "%.0f", arChild))
                }
            }

            Section("Info") {
                if let type = customer.customerType {
                    LabeledContent("Type", value: type)
                }
                if let status = customer.customerStatus {
                    LabeledContent("Status") {
                        Text(status)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(status.uppercased() == "ACTIVE" ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(status.uppercased() == "ACTIVE" ? .green : .secondary)
                    }
                }
                if let terms = customer.customerTerms {
                    LabeledContent("Terms (days)", value: String(format: "%.0f", terms))
                }
                if let desc = customer.customerDescription {
                    LabeledContent("Description", value: desc)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit Customer", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Customer", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(customer.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            CustomerFormSheet(mode: .edit(customer), onSave: {
                showEditSheet = false
                await onUpdate()
                dismiss()
            })
        }
        .confirmationDialog("Delete this customer?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await apiService.deleteArCustomer(id: customer.customerId)
                        await onUpdate()
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Customer Form Sheet (Create / Edit)

enum CustomerFormMode {
    case create
    case edit(ArCustomer)
}

struct CustomerFormSheet: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let mode: CustomerFormMode
    var onSave: () async -> Void

    @State private var customerId = ""
    @State private var customerName = ""
    @State private var shortName = ""
    @State private var contact = ""
    @State private var phone = ""
    @State private var fax = ""
    @State private var address1 = ""
    @State private var address2 = ""
    @State private var address3 = ""
    @State private var postalCode = ""
    @State private var account = ""
    @State private var child = ""
    @State private var vatAccount = ""
    @State private var vatChild = ""
    @State private var arAccount = ""
    @State private var arChild = ""
    @State private var customerType = ""
    @State private var status = "ACTIVE"
    @State private var terms = ""
    @State private var customerDescription = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    if !isEditing {
                        TextField("Customer ID *", text: $customerId)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    TextField("Name *", text: $customerName)
                    TextField("Short Name", text: $shortName)
                    TextField("Contact", text: $contact)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Fax", text: $fax)
                        .keyboardType(.phonePad)
                }

                Section("Address") {
                    TextField("Address 1", text: $address1)
                    TextField("Address 2", text: $address2)
                    TextField("Address 3", text: $address3)
                    TextField("Postal Code", text: $postalCode)
                }

                Section("Account Links") {
                    TextField("Account", text: $account)
                        .keyboardType(.numberPad)
                    TextField("Child", text: $child)
                        .keyboardType(.numberPad)
                    TextField("VAT Account", text: $vatAccount)
                        .keyboardType(.numberPad)
                    TextField("VAT Child", text: $vatChild)
                        .keyboardType(.numberPad)
                    TextField("AR Account", text: $arAccount)
                        .keyboardType(.numberPad)
                    TextField("AR Child", text: $arChild)
                        .keyboardType(.numberPad)
                }

                Section("Info") {
                    TextField("Type", text: $customerType)
                    TextField("Status", text: $status)
                    TextField("Terms (days)", text: $terms)
                        .keyboardType(.numberPad)
                    TextField("Description", text: $customerDescription)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Customer" : "New Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting || customerName.isEmpty || (!isEditing && customerId.isEmpty))
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        guard case .edit(let c) = mode else { return }
        customerId = c.customerId
        customerName = c.customerName
        shortName = c.customerShortName ?? ""
        contact = c.customerContact ?? ""
        phone = c.customerPhone ?? ""
        fax = c.customerFax ?? ""
        address1 = c.customerAddress1 ?? ""
        address2 = c.customerAddress2 ?? ""
        address3 = c.customerAddress3 ?? ""
        postalCode = c.customerPostalCode ?? ""
        account = c.customerAccount.map { String(format: "%.0f", $0) } ?? ""
        child = c.customerChild.map { String(format: "%.0f", $0) } ?? ""
        vatAccount = c.customerVatAccount.map { String(format: "%.0f", $0) } ?? ""
        vatChild = c.customerVatChild.map { String(format: "%.0f", $0) } ?? ""
        arAccount = c.customerApAccount.map { String(format: "%.0f", $0) } ?? ""
        arChild = c.customerApChild.map { String(format: "%.0f", $0) } ?? ""
        customerType = c.customerType ?? ""
        status = c.customerStatus ?? "ACTIVE"
        terms = c.customerTerms.map { String(format: "%.0f", $0) } ?? ""
        customerDescription = c.customerDescription ?? ""
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        do {
            switch mode {
            case .create:
                let params = CreateArCustomerRequest(
                    customerId: customerId,
                    customerName: customerName,
                    customerShortName: shortName.isEmpty ? nil : shortName,
                    customerAddress1: address1.isEmpty ? nil : address1,
                    customerAddress2: address2.isEmpty ? nil : address2,
                    customerAddress3: address3.isEmpty ? nil : address3,
                    customerPostalCode: postalCode.isEmpty ? nil : postalCode,
                    customerPhone: phone.isEmpty ? nil : phone,
                    customerFax: fax.isEmpty ? nil : fax,
                    customerAccount: Double(account),
                    customerChild: Double(child),
                    customerVatAccount: Double(vatAccount),
                    customerVatChild: Double(vatChild),
                    customerApAccount: Double(arAccount),
                    customerApChild: Double(arChild),
                    customerDescription: customerDescription.isEmpty ? nil : customerDescription,
                    customerContact: contact.isEmpty ? nil : contact,
                    customerType: customerType.isEmpty ? nil : customerType,
                    customerStatus: status.isEmpty ? "ACTIVE" : status,
                    customerTerms: Double(terms),
                    createDate: today,
                    createUser: "MOBILE"
                )
                try await apiService.createArCustomer(params)

            case .edit(let c):
                let params = UpdateArCustomerRequest(
                    customerId: c.customerId,
                    customerName: customerName,
                    customerShortName: shortName.isEmpty ? nil : shortName,
                    customerAddress1: address1.isEmpty ? nil : address1,
                    customerAddress2: address2.isEmpty ? nil : address2,
                    customerAddress3: address3.isEmpty ? nil : address3,
                    customerPostalCode: postalCode.isEmpty ? nil : postalCode,
                    customerPhone: phone.isEmpty ? nil : phone,
                    customerFax: fax.isEmpty ? nil : fax,
                    customerAccount: Double(account),
                    customerChild: Double(child),
                    customerVatAccount: Double(vatAccount),
                    customerVatChild: Double(vatChild),
                    customerApAccount: Double(arAccount),
                    customerApChild: Double(arChild),
                    customerDescription: customerDescription.isEmpty ? nil : customerDescription,
                    customerContact: contact.isEmpty ? nil : contact,
                    customerType: customerType.isEmpty ? nil : customerType,
                    customerStatus: status.isEmpty ? nil : status,
                    customerTerms: Double(terms),
                    updateDate: today,
                    updateUser: "MOBILE"
                )
                try await apiService.updateArCustomer(params)
            }
            await onSave()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CustomerMaintenanceView()
            .environment(APIService())
    }
}

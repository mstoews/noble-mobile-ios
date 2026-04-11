//
//  VendorMaintenanceView.swift
//  nbledger
//
//  Created by Murray Toews on 4/11/26.
//

import SwiftUI

// MARK: - Vendor Filter

enum VendorFilterTab: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case inactive = "Inactive"
}

// MARK: - Vendor Maintenance

struct VendorMaintenanceView: View {
    @Environment(APIService.self) private var apiService

    @State private var vendors: [ApVendor] = []
    @State private var activeFilter: VendorFilterTab = .all
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false

    private var filteredVendors: [ApVendor] {
        var result = vendors
        switch activeFilter {
        case .all: break
        case .active:
            result = result.filter { $0.status?.uppercased() == "ACTIVE" }
        case .inactive:
            result = result.filter { $0.status?.uppercased() != "ACTIVE" }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.shortName ?? "").localizedCaseInsensitiveContains(searchText)
                || ($0.contact ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $activeFilter) {
                ForEach(VendorFilterTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                if isLoading {
                    ProgressView("Loading vendors...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await loadVendors() } }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredVendors.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No vendors found.")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredVendors) { vendor in
                        NavigationLink(value: vendor.id) {
                            VendorRow(vendor: vendor)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Search vendors")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("AP Vendors")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await loadVendors() }
        .refreshable { await loadVendors() }
        .navigationDestination(for: String.self) { vendorId in
            if let vendor = vendors.first(where: { $0.id == vendorId }) {
                VendorDetailView(vendor: vendor, onUpdate: { await loadVendors() })
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            VendorFormSheet(mode: .create, onSave: {
                showCreateSheet = false
                Task { await loadVendors() }
            })
        }
    }

    private func loadVendors() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            vendors = try await apiService.fetchApVendors()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Vendor Row

struct VendorRow: View {
    let vendor: ApVendor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vendor.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let shortName = vendor.shortName {
                        Text(shortName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let status = vendor.status {
                        Text(status)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(status.uppercased() == "ACTIVE" ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(status.uppercased() == "ACTIVE" ? .green : .secondary)
                    }
                    if let type = vendor.type {
                        Text(type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let phone = vendor.phone, !phone.isEmpty {
                Image(systemName: "phone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Vendor Detail

struct VendorDetailView: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let vendor: ApVendor
    var onUpdate: () async -> Void

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Contact") {
                LabeledContent("Name", value: vendor.name)
                if let shortName = vendor.shortName {
                    LabeledContent("Short Name", value: shortName)
                }
                if let contact = vendor.contact {
                    LabeledContent("Contact", value: contact)
                }
                if let phone = vendor.phone {
                    LabeledContent("Phone", value: phone)
                }
                if let fax = vendor.fax {
                    LabeledContent("Fax", value: fax)
                }
            }

            Section("Address") {
                if let a1 = vendor.address1 { LabeledContent("Address 1", value: a1) }
                if let a2 = vendor.address2 { LabeledContent("Address 2", value: a2) }
                if let a3 = vendor.address3 { LabeledContent("Address 3", value: a3) }
                if let pc = vendor.postalCode { LabeledContent("Postal Code", value: pc) }
            }

            Section("Account Links") {
                if let acct = vendor.account {
                    LabeledContent("Account", value: String(format: "%.0f", acct))
                }
                if let child = vendor.child {
                    LabeledContent("Child", value: String(format: "%.0f", child))
                }
                if let vat = vendor.vatAccount {
                    LabeledContent("VAT Account", value: String(format: "%.0f", vat))
                }
                if let vatChild = vendor.vatChild {
                    LabeledContent("VAT Child", value: String(format: "%.0f", vatChild))
                }
                if let ap = vendor.apAccount {
                    LabeledContent("AP Account", value: String(format: "%.0f", ap))
                }
                if let apChild = vendor.apChild {
                    LabeledContent("AP Child", value: String(format: "%.0f", apChild))
                }
            }

            Section("Info") {
                if let type = vendor.type {
                    LabeledContent("Type", value: type)
                }
                if let status = vendor.status {
                    LabeledContent("Status") {
                        Text(status)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(status.uppercased() == "ACTIVE" ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(status.uppercased() == "ACTIVE" ? .green : .secondary)
                    }
                }
                if let terms = vendor.vendorTerms {
                    LabeledContent("Terms (days)", value: String(format: "%.0f", terms))
                }
                if let desc = vendor.description {
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
                    Label("Edit Vendor", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Vendor", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(vendor.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            VendorFormSheet(mode: .edit(vendor), onSave: {
                showEditSheet = false
                await onUpdate()
                dismiss()
            })
        }
        .confirmationDialog("Delete this vendor?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await apiService.deleteApVendor(id: vendor.id)
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

// MARK: - Vendor Form Sheet (Create / Edit)

enum VendorFormMode {
    case create
    case edit(ApVendor)
}

struct VendorFormSheet: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let mode: VendorFormMode
    var onSave: () async -> Void

    @State private var name = ""
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
    @State private var apAccount = ""
    @State private var apChild = ""
    @State private var vendorType = ""
    @State private var status = "ACTIVE"
    @State private var vendorTerms = ""
    @State private var vendorDescription = ""

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
                    TextField("Name *", text: $name)
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
                    TextField("AP Account", text: $apAccount)
                        .keyboardType(.numberPad)
                    TextField("AP Child", text: $apChild)
                        .keyboardType(.numberPad)
                }

                Section("Info") {
                    TextField("Type", text: $vendorType)
                    TextField("Status", text: $status)
                    TextField("Terms (days)", text: $vendorTerms)
                        .keyboardType(.numberPad)
                    TextField("Description", text: $vendorDescription)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Vendor" : "New Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting || name.isEmpty)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        guard case .edit(let v) = mode else { return }
        name = v.name
        shortName = v.shortName ?? ""
        contact = v.contact ?? ""
        phone = v.phone ?? ""
        fax = v.fax ?? ""
        address1 = v.address1 ?? ""
        address2 = v.address2 ?? ""
        address3 = v.address3 ?? ""
        postalCode = v.postalCode ?? ""
        account = v.account.map { String(format: "%.0f", $0) } ?? ""
        child = v.child.map { String(format: "%.0f", $0) } ?? ""
        vatAccount = v.vatAccount.map { String(format: "%.0f", $0) } ?? ""
        vatChild = v.vatChild.map { String(format: "%.0f", $0) } ?? ""
        apAccount = v.apAccount.map { String(format: "%.0f", $0) } ?? ""
        apChild = v.apChild.map { String(format: "%.0f", $0) } ?? ""
        vendorType = v.type ?? ""
        status = v.status ?? "ACTIVE"
        vendorTerms = v.vendorTerms.map { String(format: "%.0f", $0) } ?? ""
        vendorDescription = v.description ?? ""
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
                let params = CreateApVendorRequest(
                    name: name,
                    shortName: shortName.isEmpty ? nil : shortName,
                    address1: address1.isEmpty ? nil : address1,
                    address2: address2.isEmpty ? nil : address2,
                    address3: address3.isEmpty ? nil : address3,
                    postalCode: postalCode.isEmpty ? nil : postalCode,
                    phone: phone.isEmpty ? nil : phone,
                    fax: fax.isEmpty ? nil : fax,
                    account: Double(account),
                    child: Double(child),
                    vatAccount: Double(vatAccount),
                    vatChild: Double(vatChild),
                    apAccount: Double(apAccount),
                    apChild: Double(apChild),
                    description: vendorDescription.isEmpty ? nil : vendorDescription,
                    contact: contact.isEmpty ? nil : contact,
                    type: vendorType.isEmpty ? nil : vendorType,
                    status: status.isEmpty ? "ACTIVE" : status,
                    vendorTerms: Double(vendorTerms),
                    createDate: today,
                    createUser: "MOBILE"
                )
                try await apiService.createApVendor(params)

            case .edit(let v):
                let params = UpdateApVendorRequest(
                    id: v.id,
                    name: name,
                    shortName: shortName.isEmpty ? nil : shortName,
                    address1: address1.isEmpty ? nil : address1,
                    address2: address2.isEmpty ? nil : address2,
                    address3: address3.isEmpty ? nil : address3,
                    postalCode: postalCode.isEmpty ? nil : postalCode,
                    phone: phone.isEmpty ? nil : phone,
                    fax: fax.isEmpty ? nil : fax,
                    account: Double(account),
                    child: Double(child),
                    vatAccount: Double(vatAccount),
                    vatChild: Double(vatChild),
                    apAccount: Double(apAccount),
                    apChild: Double(apChild),
                    description: vendorDescription.isEmpty ? nil : vendorDescription,
                    contact: contact.isEmpty ? nil : contact,
                    type: vendorType.isEmpty ? nil : vendorType,
                    status: status.isEmpty ? nil : status,
                    vendorTerms: Double(vendorTerms),
                    updateDate: today,
                    updateUser: "MOBILE"
                )
                try await apiService.updateApVendor(params)
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
        VendorMaintenanceView()
            .environment(APIService())
    }
}

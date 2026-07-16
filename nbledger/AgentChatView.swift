//
//  AgentChatView.swift
//  nbledger
//
//  Created by Murray Toews on 4/5/26.
//

import SwiftUI

struct AgentChatView: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("companyName") private var companyName = ""

    /// Routes a bulk action to its reviewed, Face ID-gated screen (the
    /// presenter dismisses this sheet and navigates). Ledger mutations
    /// never run from a chat tap.
    var onOpenDestination: ((MoreDestination) -> Void)?

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false
    @State private var openJournalCount: Int?
    private let loadingID = UUID()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatMessages
                Divider()
                inputBar
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        messages.removeAll()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
    }

    // MARK: - Chat Messages

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if isSending {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Thinking...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .id(loadingID)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(messages.last?.id ?? loadingID, anchor: .bottom)
                }
            }
        }
    }

    private static let suggestions = [
        "What's overdue right now?",
        "How are we tracking against budget?",
        "Summarize this month's utilities spend"
    ]

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.nobleSlateInk)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image("NobleCrown")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityHidden(true)
                Text("Ask about your books")
                    .font(.headline)
                Text(companyName.isEmpty
                     ? "Answers come from your live ledger."
                     : "Answers come from \(companyName)'s live ledger.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)

            VStack(spacing: 8) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button {
                        Task { await sendMessage(suggestion) }
                    } label: {
                        Text(suggestion)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.nobleEmerald)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending)
                }
            }
            .padding(.top, 20)

            // Bulk operations route to their reviewed, Face ID-gated screens —
            // the ledger is never mutated from a one-tap chat suggestion.
            if onOpenDestination != nil {
                SectionLabel("Bulk actions · confirmation required")
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                VStack(spacing: 0) {
                    bulkActionRow(
                        icon: "text.book.closed",
                        title: "Book open journals",
                        subtitle: bookSubtitle,
                        destination: .journalBooking
                    )
                    Divider().padding(.leading, 43)
                    bulkActionRow(
                        icon: "lock",
                        title: "Close journals",
                        subtitle: "Irreversible · reviewed per entry",
                        destination: .journals
                    )
                }
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .task { await loadOpenJournalCount() }
    }

    private var bookSubtitle: String {
        guard let openJournalCount else { return "You'll review the list first" }
        if openJournalCount == 0 { return "All entries booked" }
        let entries = openJournalCount == 1 ? "1 open entry" : "\(openJournalCount) open entries"
        return "\(entries) · you'll review the list first"
    }

    private func bulkActionRow(icon: String, title: String, subtitle: String, destination: MoreDestination) -> some View {
        Button {
            onOpenDestination?(destination)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.nobleSlate)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }

    private func loadOpenJournalCount() async {
        if let journals = try? await apiService.fetchJournalHeaders() {
            openJournalCount = journals
                .filter { ($0.status ?? "") == "OPEN" && $0.booked != true }
                .count
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask a question...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? Color.nobleEmerald : .gray.opacity(0.4))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    // MARK: - Send Message

    private func sendMessage(_ prompt: String? = nil) async {
        let text = (prompt ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: "user", content: text)
        messages.append(userMessage)
        inputText = ""
        isSending = true

        // Add placeholder assistant message that will be built up from stream
        let placeholder = ChatMessage(role: "assistant", content: "")
        messages.append(placeholder)
        let assistantIndex = messages.count - 1

        var accumulated = ""
        for await chunk in apiService.streamAgentMessage(messages: Array(messages.dropLast())) {
            accumulated += chunk
            messages[assistantIndex] = ChatMessage(role: "assistant", content: accumulated)
        }

        // If nothing was received, show an error
        if accumulated.isEmpty {
            messages[assistantIndex] = ChatMessage(role: "assistant", content: "Sorry, I couldn't get a response. Please try again.")
        }

        isSending = false
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.nobleEmerald : Color(.systemGray5), in: ChatBubbleShape(isUser: isUser))
                .foregroundStyle(isUser ? .white : .primary)

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailRadius: CGFloat = 6

        var path = Path()

        if isUser {
            // Rounded rect with bottom-right tail
            path.addRoundedRect(in: CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width - tailRadius,
                height: rect.height
            ), cornerSize: CGSize(width: radius, height: radius))
            // Small tail
            path.move(to: CGPoint(x: rect.maxX - tailRadius, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.maxX - tailRadius, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - tailRadius - 4, y: rect.maxY),
                control: CGPoint(x: rect.maxX - tailRadius - 2, y: rect.maxY)
            )
        } else {
            // Rounded rect with bottom-left tail
            path.addRoundedRect(in: CGRect(
                x: rect.minX + tailRadius,
                y: rect.minY,
                width: rect.width - tailRadius,
                height: rect.height
            ), cornerSize: CGSize(width: radius, height: radius))
            // Small tail
            path.move(to: CGPoint(x: rect.minX + tailRadius, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.minX + tailRadius, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + tailRadius + 4, y: rect.maxY),
                control: CGPoint(x: rect.minX + tailRadius + 2, y: rect.maxY)
            )
        }

        return path
    }
}

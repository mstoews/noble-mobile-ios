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

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false
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

    @State private var showActions = false
    @State private var isRunningAction = false

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Ask me anything about your accounts, transactions, or ledger.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Quick action suggestions
            VStack(spacing: 8) {
                Text("Quick Actions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                quickActionButton("Close all open journals", icon: "lock") {
                    await closeAllOpenJournals()
                }
                quickActionButton("Book all open journals", icon: "book.closed") {
                    await bookAllOpenJournals()
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func quickActionButton(_ title: String, icon: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isSending || isRunningAction)
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
                    .foregroundStyle(canSend ? .blue : .gray.opacity(0.4))
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

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
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

    // MARK: - Quick Actions

    private func closeAllOpenJournals() async {
        isRunningAction = true
        defer { isRunningAction = false }

        messages.append(ChatMessage(role: "user", content: "Close all open journal entries"))
        let statusMsg = ChatMessage(role: "assistant", content: "Working...")
        messages.append(statusMsg)
        let statusIndex = messages.count - 1

        do {
            let headers = try await apiService.fetchJournalHeaders()
            let openJournals = headers.filter { $0.booked != true && $0.status?.uppercased() != "CLOSED" }

            if openJournals.isEmpty {
                messages[statusIndex] = ChatMessage(role: "assistant", content: "No open journal entries found. All journals are already closed or booked.")
                return
            }

            var closed = 0
            var failed = 0
            for journal in openJournals {
                do {
                    try await apiService.closeJournalEntry(CloseJournalRequest(
                        journalId: journal.journalId,
                        bookedUser: "MOBILE"
                    ))
                    closed += 1
                    messages[statusIndex] = ChatMessage(role: "assistant", content: "Closing journals... \(closed)/\(openJournals.count)")
                } catch {
                    failed += 1
                }
            }

            var summary = "Closed \(closed) journal\(closed == 1 ? "" : "s")."
            if failed > 0 {
                summary += " \(failed) failed."
            }
            messages[statusIndex] = ChatMessage(role: "assistant", content: summary)
        } catch {
            messages[statusIndex] = ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)")
        }
    }

    private func bookAllOpenJournals() async {
        isRunningAction = true
        defer { isRunningAction = false }

        messages.append(ChatMessage(role: "user", content: "Book all open journal entries"))
        let statusMsg = ChatMessage(role: "assistant", content: "Working...")
        messages.append(statusMsg)
        let statusIndex = messages.count - 1

        do {
            let headers = try await apiService.fetchJournalHeaders()
            let openJournals = headers.filter { $0.booked != true && $0.status?.uppercased() != "CLOSED" }

            if openJournals.isEmpty {
                messages[statusIndex] = ChatMessage(role: "assistant", content: "No open journal entries to book. All journals are already booked or closed.")
                return
            }

            let currentMonth = Calendar.current.component(.month, from: Date())
            let currentYear = Calendar.current.component(.year, from: Date())

            var booked = 0
            var failed = 0
            for journal in openJournals {
                do {
                    try await apiService.bookJournalEntry(BookJournalRequest(
                        journalId: journal.journalId,
                        userName: "MOBILE",
                        period: journal.period ?? currentMonth,
                        year: journal.periodYear ?? currentYear
                    ))
                    booked += 1
                    messages[statusIndex] = ChatMessage(role: "assistant", content: "Booking journals... \(booked)/\(openJournals.count)")
                } catch {
                    failed += 1
                }
            }

            var summary = "Booked \(booked) journal\(booked == 1 ? "" : "s") to the general ledger."
            if failed > 0 {
                summary += " \(failed) failed."
            }
            messages[statusIndex] = ChatMessage(role: "assistant", content: summary)
        } catch {
            messages[statusIndex] = ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)")
        }
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
                .background(isUser ? Color.blue : Color(.systemGray5), in: ChatBubbleShape(isUser: isUser))
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

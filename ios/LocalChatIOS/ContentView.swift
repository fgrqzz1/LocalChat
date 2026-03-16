import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showConnectionSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                chatSection
                composerSection
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.secondarySystemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Сообщения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showConnectionSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showConnectionSheet) {
                connectionSheet
                    .presentationDetents([.fraction(0.45)])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                if !viewModel.isConnected {
                    showConnectionSheet = true
                }
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorText != nil },
            set: { _ in viewModel.errorText = nil }
        )) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.errorText ?? "")
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.nickname.isEmpty ? "LocalChat" : viewModel.nickname)
                    .font(.headline)
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(viewModel.isConnected ? .green : .secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isConnected ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text("\(viewModel.onlineUsers.count) online")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.messages) { item in
                            MessageBubble(item: item)
                                .id(item.id)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .onChange(of: viewModel.messages.count) { _ in
                guard let last = viewModel.messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "message.badge.waveform")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Нет сообщений")
                .font(.headline)
            Text("Подключитесь и начните диалог")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var composerSection: some View {
        VStack(spacing: 8) {
            if !viewModel.onlineUsers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.onlineUsers) { user in
                            Text(user.nickname)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Сообщение", text: $viewModel.inputMessage, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .disabled(!viewModel.isConnected)
                    .onSubmit {
                        viewModel.sendMessage()
                    }

                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? Color.blue : Color.gray)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }

    private var connectionSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("ws://192.168.1.10:8765/ws", text: $viewModel.serverAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("Ник", text: $viewModel.nickname)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 12) {
                    if viewModel.isConnected {
                        Button("Отключиться", role: .destructive) {
                            viewModel.disconnect()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Подключиться") {
                            viewModel.connect()
                            if viewModel.isConnected {
                                showConnectionSheet = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button("Закрыть") {
                        showConnectionSheet = false
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Подключение")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var canSend: Bool {
        viewModel.isConnected && !viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct MessageBubble: View {
    let item: ChatItem

    var body: some View {
        if item.kind == .system {
            systemBubble
        } else {
            chatBubble
        }
    }

    private var systemBubble: some View {
        HStack {
            Spacer()
            Text(item.body)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
            Spacer()
        }
    }

    private var chatBubble: some View {
        HStack {
            if item.isOwn { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                if !item.isOwn {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(item.isOwn ? .white : .primary)
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(item.isOwn ? Color.white.opacity(0.9) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(item.isOwn ? Color.blue : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: item.isOwn ? .trailing : .leading)

            if !item.isOwn { Spacer(minLength: 40) }
        }
    }
}

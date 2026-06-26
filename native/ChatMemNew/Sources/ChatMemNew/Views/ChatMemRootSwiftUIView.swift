import SwiftUI
import AppKit

struct ChatMemRootSwiftUIView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                topbar
                HStack(spacing: 0) {
                    ChatMemSidebarSwiftUIView(store: store)
                        .frame(width: 330)
                    ZStack {
                        ChatMemWorkspaceSwiftUIView(store: store)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            if store.memoryDrawerOpen {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { store.toggleMemoryDrawer() }
                ChatMemMemoryDrawerSwiftUIView(store: store)
                    .frame(width: 420)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(SwiftUITheme.appBackground)
        .sheet(isPresented: modalBinding) {
            QueuedActionSheet(message: store.modalMessage ?? "") {
                store.clearModal()
            }
        }
    }

    private var modalBinding: Binding<Bool> {
        Binding(
            get: { store.modalMessage != nil },
            set: { if !$0 { store.clearModal() } }
        )
    }

    private var topbar: some View {
        ZStack {
            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(SwiftUITheme.accent)
                        .frame(width: 30, height: 30)
                        .overlay(Image(systemName: "brain.head.profile").foregroundStyle(.white))
                    Text("ChatMem")
                        .font(.system(size: 20, weight: .bold))
                    Text("New")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SwiftUITheme.softStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer(minLength: 0)
            }

            HStack {
                Spacer()
                Button { store.toggleMemoryDrawer(tab: .review) } label: {
                    Label("记忆", systemImage: "tray.full")
                }
                Button { store.openWorkspace(.help) } label: {
                    Image(systemName: "questionmark.circle")
                }
                Button { store.openWorkspace(.about) } label: {
                    Image(systemName: "info.circle")
                }
                Button { store.openWorkspace(.settings) } label: {
                    Image(systemName: "gearshape")
                }
            }
            .buttonStyle(.borderless)
            .padding(.trailing, 16)
        }
        .frame(height: 56)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(SwiftUITheme.border).frame(height: 1), alignment: .bottom)
    }
}

private struct QueuedActionSheet: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ChatMemNew")
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("知道了", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}

import AppKit

@MainActor
final class RootViewController: NSViewController {
    private let store: AppStore
    private let modalCoordinator = ModalCoordinator()
    private var sidebar: SidebarView?
    private var workspace: WorkspaceView?
    private var drawer: MemoryDrawerView?
    private var drawerWidthConstraint: NSLayoutConstraint?

    init(store: AppStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        store.onChange = { [weak self] in
            self?.reload()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = DesignSystem.appBackground.cgColor
        view = root

        let topbar = buildTopbar()
        let body = NSView()
        body.translatesAutoresizingMaskIntoConstraints = false

        let sidebar = SidebarView(store: store)
        let workspace = WorkspaceView(store: store)
        let drawer = MemoryDrawerView(store: store)
        self.sidebar = sidebar
        self.workspace = workspace
        self.drawer = drawer
        let drawerWidthConstraint = drawer.widthAnchor.constraint(equalToConstant: store.memoryDrawerOpen ? DesignSystem.drawerWidth : 0)
        self.drawerWidthConstraint = drawerWidthConstraint

        body.addSubview(sidebar)
        body.addSubview(workspace)
        body.addSubview(drawer)
        root.addSubview(topbar)
        root.addSubview(body)

        NSLayoutConstraint.activate([
            topbar.topAnchor.constraint(equalTo: root.topAnchor),
            topbar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            topbar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            topbar.heightAnchor.constraint(equalToConstant: DesignSystem.topBarHeight),
            body.topAnchor.constraint(equalTo: topbar.bottomAnchor),
            body.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            sidebar.topAnchor.constraint(equalTo: body.topAnchor),
            sidebar.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: body.bottomAnchor),
            workspace.topAnchor.constraint(equalTo: body.topAnchor),
            workspace.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            workspace.bottomAnchor.constraint(equalTo: body.bottomAnchor),
            drawer.topAnchor.constraint(equalTo: body.topAnchor),
            drawer.leadingAnchor.constraint(equalTo: workspace.trailingAnchor),
            drawer.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            drawer.bottomAnchor.constraint(equalTo: body.bottomAnchor),
            drawerWidthConstraint
        ])
    }

    private func buildTopbar() -> NSView {
        let topbar = NSView()
        topbar.wantsLayer = true
        topbar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.82).cgColor
        topbar.translatesAutoresizingMaskIntoConstraints = false

        let left = ViewFactory.horizontalStack(spacing: 10)
        left.addArrangedSubviews([
            ViewFactory.label("ChatMem", font: DesignSystem.titleFont(20)),
            ViewFactory.label("New · Native AppKit", font: DesignSystem.captionFont(), color: .secondaryLabelColor)
        ])

        let actions = ViewFactory.horizontalStack(spacing: 8)
        actions.addArrangedSubviews([
            ViewFactory.iconButton("Memory", target: self, action: #selector(openMemory)),
            ViewFactory.iconButton("Help", target: self, action: #selector(openHelp)),
            ViewFactory.iconButton("About", target: self, action: #selector(openAbout)),
            ViewFactory.iconButton("Settings", target: self, action: #selector(openSettings))
        ])

        topbar.addSubview(left)
        topbar.addSubview(actions)
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: topbar.leadingAnchor, constant: 72),
            left.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),
            actions.trailingAnchor.constraint(equalTo: topbar.trailingAnchor, constant: -18),
            actions.centerYAnchor.constraint(equalTo: topbar.centerYAnchor)
        ])
        return topbar
    }

    private func reload() {
        sidebar?.reload()
        workspace?.reload()
        drawerWidthConstraint?.constant = store.memoryDrawerOpen ? DesignSystem.drawerWidth : 0
        drawer?.reload()
        if let message = store.modalMessage {
            modalCoordinator.showInfo(message: message, in: view.window)
            store.clearModal()
        }
    }

    @objc private func openMemory() {
        store.toggleMemoryDrawer(tab: .review)
    }

    @objc private func openHelp() {
        store.openWorkspace(.help)
    }

    @objc private func openAbout() {
        store.openWorkspace(.about)
    }

    @objc private func openSettings() {
        store.openWorkspace(.settings)
    }
}

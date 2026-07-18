import SwiftUI
import AppKit

struct ChatMemWorkspaceSwiftUIView: View {
    @ObservedObject var store: AppStore
    @State private var showingAgentIntegrationList = false
    @State private var selectedIntegrationAgent: AgentKind?

    var body: some View {
        ZStack {
            SwiftUITheme.appBackground
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    workspaceCommandBar
                    switch store.workspace {
                    case .workbench:
                        workbench
                    case .conversation:
                        conversationWorkspace
                    case .localHistory:
                        localHistory
                    case .review:
                        review
                    case .history:
                        history
                    case .settings:
                        settings
                    case .favorites:
                        listWorkspace("收藏", "固定的重要对话，便于快速恢复工作。", store.favorites)
                    case .trash:
                        listWorkspace("回收站", "在永久删除前复核低信号或已移除的对话。", store.trashed)
                    case .help:
                        help
                    case .about:
                        about
                    }
                }
                .padding(22)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(SwiftUITheme.surface)
                    .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 12)
                    .padding(16)
            )
        }
    }

    private var workspaceCommandBar: some View {
        HStack(spacing: 8) {
            Spacer()
            commandChip("继续工作", "rectangle.grid.1x2", .workbench)
            commandChip("待确认", "checklist", .review)
            commandChip("历史", "clock.arrow.circlepath", .history)
            commandChip("设置", "gearshape", .settings)
            Button {
                store.toggleMemoryDrawer(tab: .review)
            } label: {
                Label("记忆视图", systemImage: "tray.full")
            }
            .buttonStyle(.borderedProminent)
            .tint(SwiftUITheme.accent)
        }
    }

    private func commandChip(_ title: String, _ icon: String, _ destination: WorkspaceDestination) -> some View {
        Button {
            store.openWorkspace(destination)
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(store.workspace == destination ? SwiftUITheme.accent : SwiftUITheme.secondaryText)
    }

    private var conversationWorkspace: some View {
        guard let detail = store.selectedConversation else { return AnyView(workbench) }
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                conversationHeader(detail)
                metaStrip(detail)
                memorySummary
                HStack(alignment: .top, spacing: 14) {
                    transcript(detail)
                        .frame(maxWidth: .infinity)
                    recoveryRail(detail)
                        .frame(width: 280)
                }
            }
        )
    }

    private var workbench: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("继续工作")
                        .font(.system(size: 28, weight: .bold))
                    Text("把最近进度、恢复命令、项目记忆和下一步集中在一个工作台里。")
                        .foregroundStyle(SwiftUITheme.secondaryText)
                }
                Spacer()
                Button("打开记忆视图") { store.toggleMemoryDrawer(tab: .review) }
            }

            if let detail = store.selectedConversation {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("01", "可恢复进度", detail.summary.sourceAgent.label)
                    Text(detail.summary.title)
                        .font(.system(size: 18, weight: .bold))
                    Text(detail.summary.projectDirectory)
                        .font(.system(size: 12))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                    Text(detail.continuationPrompt)
                        .font(.system(size: 12))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                        .lineLimit(3)
                    HStack {
                        primaryButton("恢复命令", "terminal") { copy(detail.summary.resumeCommand) }
                        secondaryButton("查看对话", "text.bubble") { store.openWorkspace(.conversation) }
                        secondaryButton("本地历史", "clock.arrow.circlepath") { store.openWorkspace(.localHistory) }
                        secondaryButton("创建交接", "arrow.left.arrow.right") { store.showQueuedAction("创建交接包") }
                    }
                }
                .chatMemCard()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard("本地历史", "\(store.snapshot.repoHealth.indexedConversations)", "已索引对话")
                metricCard("待确认", "\(store.snapshot.memoryCandidates.count)", "候选规则")
                metricCard("项目规则", "\(store.snapshot.approvedMemories.count)", "已批准记忆")
                metricCard("Wiki", "\(store.snapshot.wikiPages.count)", "可读投影")
            }

            HStack(alignment: .top, spacing: 14) {
                panel("最近任务") {
                    ForEach(store.filteredConversations.prefix(5)) { conversation in
                        Button { store.selectConversation(conversation.id) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(conversation.title).font(.system(size: 13, weight: .semibold))
                                    Text(conversation.projectDirectory).font(.system(size: 11)).foregroundStyle(SwiftUITheme.secondaryText)
                                }
                                Spacer()
                                Text(conversation.updatedAt).font(.system(size: 11)).foregroundStyle(SwiftUITheme.mutedText)
                            }
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                panel("待处理") {
                    Text("\(store.snapshot.memoryCandidates.count) 条候选规则需要审批")
                    Text("\(store.snapshot.handoffs.count) 个交接包等待复核")
                    Text(store.snapshot.repoHealth.aliasWarnings.first ?? "路径别名状态正常")
                        .foregroundStyle(SwiftUITheme.secondaryText)
                    Button("进入待确认") { store.toggleMemoryDrawer(tab: .review) }
                }
                .frame(width: 300)
            }
        }
    }

    private func conversationHeader(_ detail: ConversationDetail) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(detail.summary.sourceAgent.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SwiftUITheme.secondaryText)
                Text(detail.summary.title)
                    .font(.system(size: 25, weight: .bold))
                    .lineLimit(2)
                Text(detail.summary.projectDirectory)
                    .font(.system(size: 12))
                    .foregroundStyle(SwiftUITheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 8) {
                primaryButton("迁移", "arrow.left.arrow.right") { store.showQueuedAction("迁移") }
                secondaryButton("路径", "doc.on.doc") { copy(detail.summary.storagePath) }
                secondaryButton("恢复", "terminal") { copy(detail.summary.resumeCommand) }
                secondaryButton("续接", "sparkles") { copy(detail.continuationPrompt) }
                secondaryButton("历史", "clock.arrow.circlepath") { store.openWorkspace(.localHistory) }
                secondaryButton("记忆", "tray.full") { store.toggleMemoryDrawer(tab: .review) }
            }
        }
    }

    private func metaStrip(_ detail: ConversationDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            metaRow("文件位置", detail.summary.storagePath)
            metaRow("恢复命令", detail.summary.resumeCommand)
            metaRow("续接提示词", detail.continuationPrompt)
        }
        .chatMemCard(padding: 12)
    }

    private var memorySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("05", "项目记忆沉淀", store.selectedConversation?.summary.projectDirectory ?? "暂未识别项目路径")
            HStack(spacing: 10) {
                miniStat("\(store.snapshot.approvedMemories.count)", "规则")
                miniStat("\(store.snapshot.memoryCandidates.count)", "待确认")
                miniStat("\(store.snapshot.wikiPages.count)", "Wiki")
            }
            Button("打开项目记忆视图") { store.toggleMemoryDrawer(tab: store.snapshot.memoryCandidates.isEmpty ? .rules : .review) }
                .buttonStyle(.bordered)
        }
        .chatMemCard()
    }

    private func transcript(_ detail: ConversationDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("对话")
                .font(.system(size: 17, weight: .bold))
            ForEach(detail.messages) { message in
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.role.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                    Text(message.content)
                        .font(.system(size: 13))
                    ForEach(message.toolCalls) { tool in
                        Text("工具: \(tool.name) · \(tool.status) · \(tool.output)")
                            .font(.system(size: 11))
                            .foregroundStyle(SwiftUITheme.secondaryText)
                    }
                }
                .chatMemCard(padding: 12)
            }
        }
    }

    private func recoveryRail(_ detail: ConversationDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            panel("可恢复进度") {
                Text(detail.summary.title).font(.system(size: 13, weight: .semibold))
                Text(detail.summary.resumeCommand).font(.system(size: 11, design: .monospaced)).foregroundStyle(SwiftUITheme.secondaryText)
                Button("创建检查点") { store.showQueuedAction("创建检查点") }
            }
            panel("文件变更") {
                ForEach(detail.fileChanges) { change in
                    Text("\(change.changeType): \(change.path)")
                        .font(.system(size: 11))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                        .lineLimit(2)
                }
            }
        }
    }

    private var localHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("本地历史").font(.system(size: 26, weight: .bold))
            Text("需要证据链时，再下钻到完整历史、路径别名和检索状态。")
                .foregroundStyle(SwiftUITheme.secondaryText)
            panel("项目索引状态") {
                Text("已索引对话：\(store.snapshot.repoHealth.indexedConversations)")
                Text("待确认候选：\(store.snapshot.repoHealth.pendingCandidates)")
                Text("启动上下文就绪：\(store.snapshot.repoHealth.bootstrapReady ? "是" : "否")")
                ForEach(store.snapshot.repoHealth.aliasWarnings, id: \.self) { warning in
                    Text(warning).foregroundStyle(SwiftUITheme.secondaryText)
                }
                HStack {
                    primaryButton("扫描", "arrow.clockwise") { store.showQueuedAction("仓库扫描") }
                    secondaryButton("导入", "tray.and.arrow.down") { store.showQueuedAction("导入全部本地历史") }
                    secondaryButton("合并别名", "link") { store.showQueuedAction("合并路径别名") }
                    secondaryButton("召回", "magnifyingglass") { store.showQueuedAction("历史召回") }
                }
            }
        }
    }

    private var settings: some View {
        if let selectedIntegrationAgent {
            return AnyView(agentIntegrationDetail(selectedIntegrationAgent))
        }

        if showingAgentIntegrationList {
            return AnyView(agentIntegrationList)
        }

        return AnyView(settingsRoot)
    }

    private var settingsRoot: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("设置").font(.system(size: 26, weight: .bold))
                    Text("尽量还原旧版设置页的信息分组。当前按钮保留 UI 入口，真实安装、同步和更新逻辑待桥接。")
                        .foregroundStyle(SwiftUITheme.secondaryText)
                }
                Spacer()
                Button("返回工作台") { store.openWorkspace(.workbench) }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                settingsPanel("通用", "设置界面语言、字体和恢复点行为。") {
                    settingRow("语言", value: "简体中文")
                    settingRow("字体", value: "系统默认 / 苹方 / SF Mono")
                    settingToggle("自动保留恢复点", enabled: true)
                    settingToggle("启动时自动检查更新", enabled: true)
                }

                settingsPanel("Agent 集成", "安装 MCP 与各 Agent 的原生引导入口。") {
                    settingRow("已支持 Agent", value: "\(AgentKind.allCases.count) 个")
                    settingRow("配置方式", value: "逐个 Agent 单独配置")
                    settingRow("状态", value: "MCP / 引导入口 / 配置路径")
                    HStack {
                        primaryButton("进入 Agent 配置", "rectangle.stack") { showingAgentIntegrationList = true }
                        secondaryButton("重新检测", "arrow.clockwise") { store.showQueuedAction("重新检测 Agent 集成") }
                    }
                }

                settingsPanel("同步", "WebDAV、OneDrive、本地同步文件夹。") {
                    settingRow("同步方式", value: "OneDrive / WebDAV / 本地文件夹")
                    settingRow("远程路径", value: "ChatMem/backups")
                    settingRow("凭据", value: "系统钥匙串")
                    HStack {
                        primaryButton("验证服务器", "checkmark.shield") { store.showQueuedAction("验证同步服务器") }
                        secondaryButton("立即同步", "arrow.triangle.2.circlepath") { store.showQueuedAction("立即同步") }
                    }
                }

                settingsPanel("自动备份", "控制静默备份和间隔。") {
                    settingToggle("启用自动备份", enabled: true)
                    settingRow("备份间隔", value: "30 分钟")
                    settingRow("保留策略", value: "最近 14 天")
                    secondaryButton("查看备份状态", "externaldrive") { store.showQueuedAction("查看备份状态") }
                }

                settingsPanel("更新与诊断", "版本更新、升级自检和日志。") {
                    settingRow("当前版本", value: "v1.3.2 / Native New")
                    settingRow("Telemetry", value: "com.chatmem.native")
                    HStack {
                        primaryButton("检查更新", "arrow.down.circle") { store.showQueuedAction("检查更新") }
                        secondaryButton("升级自检", "stethoscope") { store.showQueuedAction("升级自检") }
                    }
                }

                settingsPanel("危险操作", "保留确认流程，不执行静默破坏。") {
                    settingRow("回收站保留", value: "14 天")
                    settingRow("删除远端备份", value: "需要二次确认")
                    secondaryButton("清空回收站", "trash") { store.showQueuedAction("清空回收站") }
                }
            }
        }
    }

    private var agentIntegrationList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                pageHeader("Agent 集成", "逐个配置 MCP、原生引导入口、配置路径和安装动作。")
                Spacer()
                Button("返回设置") {
                    showingAgentIntegrationList = false
                    selectedIntegrationAgent = nil
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(AgentKind.allCases) { agent in
                    Button {
                        selectedIntegrationAgent = agent
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                agentIcon(agent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(agent.label).font(.system(size: 17, weight: .bold))
                                    Text(agentSubtitle(agent)).font(.system(size: 12)).foregroundStyle(SwiftUITheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(SwiftUITheme.mutedText)
                            }
                            HStack(spacing: 8) {
                                statusPill("MCP", ready: agent != .gemini)
                                statusPill("引导", ready: agent == .codex || agent == .claude)
                                statusPill("路径", ready: true)
                            }
                            Text(agentConfigPath(agent))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(SwiftUITheme.mutedText)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .chatMemCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func agentIntegrationDetail(_ agent: AgentKind) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    agentIcon(agent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(agent.label) 集成配置").font(.system(size: 26, weight: .bold))
                        Text(agentSubtitle(agent)).foregroundStyle(SwiftUITheme.secondaryText)
                    }
                }
                Spacer()
                Button("返回 Agent 列表") {
                    selectedIntegrationAgent = nil
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                settingsPanel("MCP 配置", "让该 Agent 能通过 MCP 调用 ChatMem。") {
                    settingRow("安装状态", value: agent == .gemini ? "待修复" : "已检测")
                    settingRow("Server 名称", value: "chatmem")
                    settingRow("启动命令", value: mcpCommand(agent))
                    HStack {
                        primaryButton("安装 / 修复 MCP", "wrench.and.screwdriver") { store.showQueuedAction("安装 \(agent.label) MCP") }
                        secondaryButton("复制命令", "doc.on.doc") { copy(mcpCommand(agent)) }
                    }
                }

                settingsPanel("原生引导入口", "写入该 Agent 自己会读取的规则文件。") {
                    settingRow("安装状态", value: agent == .codex || agent == .claude ? "已检测" : "未安装")
                    settingRow("入口文件", value: guidancePath(agent))
                    settingRow("触发词", value: "继续 / 记得吗 / 迁移 / 本地历史")
                    HStack {
                        primaryButton("安装引导", "square.and.arrow.down") { store.showQueuedAction("安装 \(agent.label) 引导入口") }
                        secondaryButton("打开路径", "folder") { store.showQueuedAction("打开 \(agent.label) 引导路径") }
                    }
                }

                settingsPanel("路径与权限", "显示配置文件、历史目录和可写状态。") {
                    settingRow("配置路径", value: agentConfigPath(agent))
                    settingRow("历史目录", value: historyPath(agent))
                    settingRow("写入权限", value: "待桥接检测")
                    settingRow("最近检测", value: "本次 UI 预览数据")
                }

                settingsPanel("操作", "单独处理该 Agent，不影响其他 Agent。") {
                    HStack {
                        primaryButton("检测 \(agent.label)", "magnifyingglass") { store.showQueuedAction("检测 \(agent.label)") }
                        secondaryButton("卸载集成", "trash") { store.showQueuedAction("卸载 \(agent.label) 集成") }
                    }
                    secondaryButton("重置该 Agent 状态", "arrow.counterclockwise") { store.showQueuedAction("重置 \(agent.label) 集成状态") }
                }
            }
        }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 14) {
            pageHeader("待确认", "只把需要人工判断的候选规则、过期规则和交接包集中在这里。")
            HStack(alignment: .top, spacing: 14) {
                panel("候选规则") {
                    ForEach(store.snapshot.memoryCandidates) { candidate in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(candidate.title).font(.system(size: 14, weight: .semibold))
                            Text(candidate.reason).foregroundStyle(SwiftUITheme.secondaryText)
                            Text(candidate.value).font(.system(size: 12)).foregroundStyle(SwiftUITheme.mutedText)
                            HStack {
                                primaryButton("确认保留", "checkmark") { store.showQueuedAction("审批候选规则") }
                                secondaryButton("稍后再看", "clock") { store.showQueuedAction("暂缓候选规则") }
                                secondaryButton("拒绝", "xmark") { store.showQueuedAction("拒绝候选规则") }
                            }
                        }
                        Divider()
                    }
                }
                panel("项目规则复核") {
                    ForEach(store.snapshot.approvedMemories) { memory in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(memory.title).font(.system(size: 14, weight: .semibold))
                            Text(memory.usageHint).foregroundStyle(SwiftUITheme.secondaryText)
                            Text("状态：\(memory.freshness)").font(.system(size: 11)).foregroundStyle(SwiftUITheme.mutedText)
                            Button("重新核验") { store.showQueuedAction("重新核验规则") }
                        }
                        Divider()
                    }
                }
                .frame(width: 320)
            }
            panel("待确认交接") {
                ForEach(store.snapshot.handoffs) { handoff in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(handoff.goal).font(.system(size: 13, weight: .semibold))
                            Text("\(handoff.fromAgent.label) → \(handoff.toAgent.label) · \(handoff.nextItem)")
                                .foregroundStyle(SwiftUITheme.secondaryText)
                        }
                        Spacer()
                        Button("标记已查看") { store.showQueuedAction("标记交接包已查看") }
                    }
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            pageHeader("历史", "需要下钻时再看详细记录：对话、恢复、交接、输出和阶段。")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                historyPanel("对话", "打开完整 transcript、工具调用和文件变更。", "\(store.snapshot.conversations.count) 条记录") {
                    store.openWorkspace(.conversation)
                }
                historyPanel("恢复", "检查点、恢复命令和可提升为交接包的状态。", "\(store.snapshot.checkpoints.count) 个检查点") {
                    store.showQueuedAction("打开恢复历史")
                }
                historyPanel("交接", "跨 Agent handoff packet 和接收状态。", "\(store.snapshot.handoffs.count) 个交接包") {
                    store.showQueuedAction("打开交接历史")
                }
                historyPanel("输出", "运行记录、产物和阶段性摘要。", "\(store.snapshot.runs.count) 个运行 / \(store.snapshot.artifacts.count) 个产物") {
                    store.showQueuedAction("打开输出历史")
                }
            }
            panel("项目资料库") {
                ForEach(store.snapshot.wikiPages) { page in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(page.title).font(.system(size: 13, weight: .semibold))
                            Text(page.preview).foregroundStyle(SwiftUITheme.secondaryText)
                        }
                        Spacer()
                        Button("打开") { store.toggleMemoryDrawer(tab: .wiki) }
                    }
                    Divider()
                }
            }
        }
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("帮助").font(.system(size: 26, weight: .bold))
            settingsSection("继续工作", ["复制恢复命令、查看对话证据，或打开本地历史检索。"])
            settingsSection("审批记忆", ["只把稳定规则批准为启动规则；普通历史无需审批也能检索。"])
            settingsSection("Agent 集成", ["安装 MCP 和各 Agent 引导，让“继续/记得吗/迁移”先查 ChatMem。"])
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ChatMemNew").font(.system(size: 30, weight: .bold))
            Text("SwiftUI/AppKit 并行原生版本。它不会替换 /Applications/ChatMem.app。")
                .foregroundStyle(SwiftUITheme.secondaryText)
            settingsSection("构建状态", ["SwiftUI UI 还原中；当前使用 sample data 和待桥接状态。"])
        }
    }

    private func listWorkspace(_ title: String, _ subtitle: String, _ conversations: [ConversationSummary]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).foregroundStyle(SwiftUITheme.secondaryText)
            ForEach(conversations) { conversation in
                HStack {
                    VStack(alignment: .leading) {
                        Text(conversation.title).font(.system(size: 14, weight: .semibold))
                        Text("\(conversation.sourceAgent.label) · \(conversation.projectDirectory)")
                            .font(.system(size: 12))
                            .foregroundStyle(SwiftUITheme.secondaryText)
                    }
                    Spacer()
                    Button("打开") { store.selectConversation(conversation.id) }
                }
                .chatMemCard()
            }
        }
    }

    private func pageHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).foregroundStyle(SwiftUITheme.secondaryText)
        }
    }

    private func historyPanel(_ title: String, _ body: String, _ stat: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 17, weight: .bold))
            Text(body).foregroundStyle(SwiftUITheme.secondaryText)
            Text(stat).font(.system(size: 20, weight: .bold))
            Button("打开") { action() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chatMemCard()
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 16, weight: .bold))
            content()
        }
        .chatMemCard()
    }

    private func metricCard(_ value: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 24, weight: .bold))
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(detail).font(.system(size: 11)).foregroundStyle(SwiftUITheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chatMemCard()
    }

    private func settingsSection(_ title: String, _ rows: [String]) -> some View {
        panel(title) {
            ForEach(rows, id: \.self) { row in
                Text(row).foregroundStyle(SwiftUITheme.secondaryText)
            }
        }
    }

    private func settingsPanel<Content: View>(_ title: String, _ helper: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold))
                Text(helper).font(.system(size: 12)).foregroundStyle(SwiftUITheme.secondaryText)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chatMemCard()
    }

    private func agentIcon(_ agent: AgentKind) -> some View {
        Text(String(agent.label.prefix(1)))
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(agent == .codex ? SwiftUITheme.accent : SwiftUITheme.secondaryText)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusPill(_ title: String, ready: Bool) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ready ? SwiftUITheme.accent : SwiftUITheme.mutedText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(ready ? SwiftUITheme.selected : SwiftUITheme.softStrong)
            .clipShape(Capsule())
    }

    private func agentSubtitle(_ agent: AgentKind) -> String {
        switch agent {
        case .claude: "Claude Desktop / Claude Code 本地历史与引导"
        case .codex: "Codex AGENTS.md、MCP 和本地线程历史"
        case .gemini: "Gemini / Antigravity 历史与项目上下文"
        case .antigravity: "Antigravity JSONL 历史和工作台记录"
        case .opencode: "OpenCode 本地会话与迁移入口"
        case .zcode: "ZCode 多 CLI 来源历史"
        case .hermes: "Hermes 桌面端和 Hermes Agent 配置"
        }
    }

    private func agentConfigPath(_ agent: AgentKind) -> String {
        switch agent {
        case .claude: "~/.claude/settings.json"
        case .codex: "\(NSHomeDirectory())/.codex/config.toml"
        case .gemini: "~/.gemini/settings.json"
        case .antigravity: "~/Library/Application Support/Antigravity"
        case .opencode: "~/.config/opencode/opencode.json"
        case .zcode: "~/.zcode/config.json"
        case .hermes: "~/.hermes/config.json"
        }
    }

    private func guidancePath(_ agent: AgentKind) -> String {
        switch agent {
        case .claude: "~/.claude/CLAUDE.md"
        case .codex: "AGENTS.md / ~/.codex/instructions.md"
        case .gemini: "GEMINI.md"
        case .antigravity: "Antigravity rules entry"
        case .opencode: "OPENCODE.md"
        case .zcode: "ZCODE.md"
        case .hermes: "~/.hermes/instructions.md"
        }
    }

    private func historyPath(_ agent: AgentKind) -> String {
        switch agent {
        case .claude: "~/.claude/projects"
        case .codex: "~/.codex/history"
        case .gemini: "~/.gemini/history"
        case .antigravity: "~/Library/Application Support/Antigravity"
        case .opencode: "~/.local/share/opencode"
        case .zcode: "~/.zcode/history"
        case .hermes: "~/.hermes/history"
        }
    }

    private func mcpCommand(_ agent: AgentKind) -> String {
        switch agent {
        case .codex:
            "chatmem --mcp --agent codex"
        case .claude:
            "chatmem --mcp --agent claude"
        case .hermes:
            "chatmem --mcp --agent hermes"
        default:
            "chatmem --mcp --agent \(agent.rawValue)"
        }
    }

    private func settingRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(SwiftUITheme.secondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func settingToggle(_ title: String, enabled: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(enabled ? "已开启" : "已关闭")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(enabled ? SwiftUITheme.accent : SwiftUITheme.mutedText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(enabled ? SwiftUITheme.selected : SwiftUITheme.softStrong)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private func sectionHeader(_ number: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(SwiftUITheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(SwiftUITheme.secondaryText).lineLimit(1)
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(SwiftUITheme.mutedText)
            Text(value).font(.system(size: 11)).foregroundStyle(SwiftUITheme.secondaryText).lineLimit(2)
        }
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.system(size: 20, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundStyle(SwiftUITheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(SwiftUITheme.soft)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func primaryButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.borderedProminent)
        .tint(SwiftUITheme.accent)
    }

    private func secondaryButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        store.telemetry.workspace("Copied value to pasteboard")
    }
}

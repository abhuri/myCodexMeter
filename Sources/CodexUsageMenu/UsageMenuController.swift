import AppKit

final class UsageMenuController: NSObject, NSMenuDelegate {
    private let client = CodexAppServerClient()
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var refreshTimer: Timer?
    private var snapshot: UsageSnapshot?
    private var errorMessage: String?
    private var isRefreshing = false

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu

        configureStatusButton()

        client.onRateLimitsUpdated = { [weak self] in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }

        refreshTimer = Timer.scheduledTimer(
            timeInterval: 60,
            target: self,
            selector: #selector(refreshFromTimer),
            userInfo: nil,
            repeats: true
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refreshAfterWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        rebuildMenu()
        refresh()
    }

    func stop() {
        refreshTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        client.stop()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }

        button.image = CodexMenuIcon.make()
        button.imagePosition = .imageLeading
        button.title = " --%"
        button.toolTip = "กำลังอ่าน Codex Usage"
        button.setAccessibilityLabel("myCodex Meter")
    }

    @objc private func refreshFromTimer() {
        refresh()
    }

    @objc private func refreshAfterWake() {
        refresh()
    }

    @objc private func refreshFromMenu() {
        refresh()
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        rebuildMenu()

        client.fetchRateLimits { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false

                switch result {
                case let .success(snapshot):
                    self.snapshot = snapshot
                    self.errorMessage = nil
                    self.updateStatusButton(with: snapshot)
                case let .failure(error):
                    self.errorMessage = error.localizedDescription
                    self.updateStatusButtonForError(error)
                }

                self.rebuildMenu()
            }
        }
    }

    private func updateStatusButton(with snapshot: UsageSnapshot) {
        guard let button = statusItem.button,
              let headline = snapshot.headlineWindow
        else {
            return
        }

        let percent = UsageFormatting.percent(headline.remainingPercent)
        let title = " \(percent)"
        let color: NSColor

        switch headline.remainingPercent {
        case 50...:
            color = .systemGreen
        case 20..<50:
            color = .systemOrange
        default:
            color = .systemRed
        }

        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: NSFont.systemFontSize,
                    weight: .semibold
                ),
                .foregroundColor: color,
            ]
        )
        button.toolTip = UsageFormatting.tooltip(for: snapshot)
        button.setAccessibilityValue("Codex คงเหลือ \(percent)")
    }

    private func updateStatusButtonForError(_ error: Error) {
        guard let button = statusItem.button else { return }

        button.attributedTitle = NSAttributedString(
            string: " !",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .bold),
                .foregroundColor: NSColor.systemRed,
            ]
        )
        button.toolTip = "อ่าน Codex Usage ไม่สำเร็จ\n\(error.localizedDescription)"
        button.setAccessibilityValue("อ่าน Codex Usage ไม่สำเร็จ")
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let heading = NSMenuItem(title: "myCodex Meter", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        heading.attributedTitle = NSAttributedString(
            string: "myCodex Meter",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            ]
        )
        menu.addItem(heading)
        menu.addItem(.separator())

        if let snapshot {
            appendSnapshot(snapshot)
        } else if let errorMessage {
            let errorItem = NSMenuItem(
                title: "อ่านข้อมูลไม่สำเร็จ: \(errorMessage)",
                action: nil,
                keyEquivalent: ""
            )
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        } else {
            let loadingItem = NSMenuItem(
                title: "กำลังอ่านข้อมูลจาก Codex…",
                action: nil,
                keyEquivalent: ""
            )
            loadingItem.isEnabled = false
            menu.addItem(loadingItem)
        }

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(
            title: isRefreshing ? "กำลังรีเฟรช…" : "รีเฟรชตอนนี้",
            action: #selector(refreshFromMenu),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        refreshItem.isEnabled = !isRefreshing
        menu.addItem(refreshItem)

        let dashboardItem = NSMenuItem(
            title: "เปิด Usage Dashboard",
            action: #selector(openUsageDashboard),
            keyEquivalent: ""
        )
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        let launchItem = NSMenuItem(
            title: "เปิดพร้อม macOS",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "ออกจาก myCodex Meter",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func appendSnapshot(_ snapshot: UsageSnapshot) {
        for (groupIndex, group) in snapshot.groupedWindows.enumerated() {
            if groupIndex > 0 {
                menu.addItem(.separator())
            }

            let groupTitle = group.name ?? (group.limitID == "codex" ? "Codex" : group.limitID)
            let groupItem = NSMenuItem(title: groupTitle, action: nil, keyEquivalent: "")
            groupItem.isEnabled = false
            groupItem.attributedTitle = NSAttributedString(
                string: groupTitle,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                ]
            )
            menu.addItem(groupItem)

            for window in group.windows {
                let remaining = UsageFormatting.percent(window.remainingPercent)
                let duration = UsageFormatting.duration(minutes: window.windowDurationMinutes)

                let usageItem = NSMenuItem(
                    title: "  รอบ \(duration) — คงเหลือ \(remaining)",
                    action: nil,
                    keyEquivalent: ""
                )
                usageItem.isEnabled = false
                menu.addItem(usageItem)

                let resetItem = NSMenuItem(
                    title: "  รีเซ็ต \(UsageFormatting.resetDate(window.resetsAt))",
                    action: nil,
                    keyEquivalent: ""
                )
                resetItem.isEnabled = false
                menu.addItem(resetItem)
            }
        }

        let updatedItem = NSMenuItem(
            title: "อัปเดตล่าสุด \(UsageFormatting.fetchedTime(snapshot.fetchedAt))",
            action: nil,
            keyEquivalent: ""
        )
        updatedItem.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(updatedItem)

        if let errorMessage {
            let warningItem = NSMenuItem(
                title: "รีเฟรชล่าสุดไม่สำเร็จ: \(errorMessage)",
                action: nil,
                keyEquivalent: ""
            )
            warningItem.isEnabled = false
            menu.addItem(warningItem)
        }
    }

    @objc private func openUsageDashboard() {
        guard let url = URL(string: "https://chatgpt.com/codex/settings/usage") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            try LaunchAtLoginManager.setEnabled(!LaunchAtLoginManager.isEnabled)
            sender.state = LaunchAtLoginManager.isEnabled ? .on : .off
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "ตั้งค่าเปิดพร้อม macOS ไม่สำเร็จ"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

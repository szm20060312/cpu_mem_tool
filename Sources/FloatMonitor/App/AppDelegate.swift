import SwiftUI
import AppKit
import Combine

// MARK: - 双行菜单栏文本视图

/// 自定义 NSView，在菜单栏中以双行紧凑布局显示 CPU/内存数据
/// 宽度仅 ~36pt，避免因文字过长被系统隐藏
@MainActor
final class StatusBarTextView: NSView {
    var cpuText: String = "--" {
        didSet { needsDisplay = true }
    }
    var memText: String = "--" {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 37, height: 22)
    }

    override func draw(_ dirtyRect: NSRect) {
        // 根据深色/浅色模式自适应文字颜色
        let isDark = effectiveAppearance.name == .darkAqua
            || effectiveAppearance.name == .vibrantDark
        let textColor: NSColor = isDark ? .white : .black

        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.5, weight: .medium),
            .foregroundColor: textColor,
            .kern: -0.2 as NSNumber,
        ]

        let cpuLine = "C \(cpuText)" as NSString
        let memLine = "M \(memText)" as NSString

        cpuLine.draw(at: NSPoint(x: 1, y: bounds.height - 9.5), withAttributes: lineAttrs)
        memLine.draw(at: NSPoint(x: 1, y: 1.5), withAttributes: lineAttrs)
    }
}

// MARK: - AppDelegate

/// 管理 NSStatusBar 和 NSPopover
/// 通过 NSApplicationDelegateAdaptor 集成到 SwiftUI App 生命周期
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusView: StatusBarTextView!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        setupPopover()
        observeStats()
        observeSettings()
    }

    // MARK: - 状态栏

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 37)
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)

            statusView = StatusBarTextView(frame: button.bounds)
            statusView.autoresizingMask = [.width, .height]
            button.addSubview(statusView)
        }

        applyMenuBarMode(AppSettings.shared.menuBarMode)
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 310)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(SystemMonitorService.shared)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - 监听数据更新

    private func observeStats() {
        SystemMonitorService.shared.$stats
            .sink { [weak self] stats in
                self?.updateStatusBar(
                    cpu: stats.cpuUsage,
                    memoryUsed: stats.memoryUsed,
                    memoryTotal: stats.memoryTotal
                )
            }
            .store(in: &cancellables)
    }

    private func updateStatusBar(cpu: Double, memoryUsed: UInt64, memoryTotal: UInt64) {
        // 每次更新时确保菜单栏项可见（防止被系统隐藏）
        statusItem.isVisible = true

        let cpuInt = Int(cpu)
        let memInt = memoryTotal > 0 ? Int(Double(memoryUsed) / Double(memoryTotal) * 100) : 0

        switch AppSettings.shared.menuBarMode {
        case .compact:
            statusView.cpuText = String(format: "%02d%%", cpuInt)
            statusView.memText = String(format: "%02d%%", memInt)

        case .textOnly:
            statusItem.button?.title = String(format: "CPU %02d%% MEM %02d%%", cpuInt, memInt)

        case .iconText:
            statusItem.button?.title = String(format: "C %02d%% M %02d%%", cpuInt, memInt)
        }
    }

    // MARK: - 监听设置变更

    private func observeSettings() {
        AppSettings.shared.$menuBarMode
            .sink { [weak self] mode in
                self?.applyMenuBarMode(mode)
            }
            .store(in: &cancellables)
    }

    /// 切换显示模式，不销毁 statusItem（避免 scene 断开）
    private func applyMenuBarMode(_ mode: MenuBarMode) {
        statusItem.isVisible = true
        switch mode {
        case .compact:
            statusItem.length = 37
            statusItem.button?.title = ""
            statusView.isHidden = false

        case .textOnly, .iconText:
            statusItem.length = NSStatusItem.variableLength
            statusView.isHidden = true
        }
    }
}

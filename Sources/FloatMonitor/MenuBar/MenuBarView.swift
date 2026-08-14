import SwiftUI

// MARK: - 菜单栏弹出面板

struct MenuBarView: View {
    @EnvironmentObject var monitorService: SystemMonitorService
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var expandedSections: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            headerView
            separator

            ScrollView {
                VStack(spacing: 6) {
                    cpuSection
                    separator
                    memorySection
                    separator
                    networkSection
                    separator
                    gpuSection
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

            separator
            footerView
        }
        .frame(width: 260)
        .fixedSize(horizontal: false, vertical: true)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(hex: 0x7A91B4, alpha: 0.12), lineWidth: 0.5)
        )
    }

    // MARK: - 面板背景

    private var panelBackground: some View {
        colorScheme == .dark
            ? Color.black.opacity(0.25)
            : Color.white.opacity(0.35)
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 5, height: 5)
            Text("FloatMonitor")
                .font(.caption.weight(.semibold))
            Spacer()
            Button { openMainWindow() } label: {
                Label("桌面窗口", systemImage: "macwindow")
                    .labelStyle(.iconOnly)
                    .font(.caption)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .help("打开桌面窗口")
            Button { openSettings() } label: {
                Label("设置", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
                    .font(.caption)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .help("设置")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - 底部控制栏

    private var footerView: some View {
        HStack(spacing: 5) {
            Picker("", selection: $monitorService.refreshInterval) {
                ForEach(SystemMonitorService.availableIntervals, id: \.self) { interval in
                    Text(formatInterval(interval)).tag(interval).font(.caption2)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
            Spacer()
            Button { NSApplication.shared.terminate(nil) } label: {
                Label("退出", systemImage: "power")
                    .labelStyle(.iconOnly)
                    .font(.caption2)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .help("退出")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    // MARK: - CPU

    private var cpuSection: some View {
        let isExpanded = expandedSections.contains("cpu")
        return sectionCard(kind: .cpu) {
            VStack(alignment: .leading, spacing: 5) {
                sectionHeader("CPU", icon: "cpu", color: .blue,
                              value: monitorService.stats.cpuUsage)
                gaugeBar(monitorService.stats.cpuUsage, color: .blue, height: 4)
                if isExpanded {
                    if !monitorService.stats.cpuPerCore.isEmpty {
                        perCoreBars(cores: monitorService.stats.cpuPerCore)
                    }
                    if let t = monitorService.stats.cpuTemperature {
                        HStack(spacing: 4) {
                            Image(systemName: "thermometer.medium")
                                .font(.caption2)
                                .foregroundStyle(tempColor(t))
                            Text(String(format: "%2.0f°C", t))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(tempColor(t))
                            Spacer()
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isExpanded)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded { expandedSections.remove("cpu") }
            else { expandedSections.insert("cpu") }
        }
    }

    private func perCoreBars(cores: [Double]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(cores.enumerated()), id: \.offset) { _, u in
                RoundedRectangle(cornerRadius: 1)
                    .fill(coreColor(u))
                    .frame(height: max(2, 14 * min(u, 100) / 100))
                    .frame(maxWidth: .infinity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: u)
            }
        }
        .frame(height: 16)
    }

    // MARK: - 内存

    private var memorySection: some View {
        let isExpanded = expandedSections.contains("memory")
        return sectionCard(kind: .memory) {
            VStack(alignment: .leading, spacing: 5) {
                let pct = monitorService.stats.memoryTotal > 0
                    ? Double(monitorService.stats.memoryUsed) / Double(monitorService.stats.memoryTotal) * 100 : 0
                sectionHeader("内存", icon: "memorychip", color: pressureColor,
                              value: pct)
                gaugeBar(pct, color: pressureColor, height: 4)
                if isExpanded {
                    HStack(spacing: 0) {
                        Circle().fill(pressureColor).frame(width: 6, height: 6)
                        Text(" \(monitorService.stats.memoryPressure.label)")
                            .font(.caption2).foregroundStyle(pressureColor)
                        Spacer()
                        Text(formatMemoryBytes(monitorService.stats.memoryUsed))
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        Text(" / ").font(.caption2).foregroundStyle(.quaternary)
                        Text(formatMemoryBytes(monitorService.stats.memoryTotal))
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isExpanded)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded { expandedSections.remove("memory") }
            else { expandedSections.insert("memory") }
        }
    }

    private var pressureColor: Color {
        switch monitorService.stats.memoryPressure {
        case .normal: .green; case .warning: .orange; case .critical: .red
        }
    }

    // MARK: - 网络

    private var networkSection: some View {
        let isExpanded = expandedSections.contains("network")
        return sectionCard(kind: .network) {
            VStack(alignment: .leading, spacing: 5) {
                sectionHeader("网络", icon: "network", color: .purple, value: nil)
                if isExpanded {
                    HStack(spacing: 10) {
                        netItem("↓ 下载", bytes: monitorService.stats.networkDownload, color: .blue)
                        Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 28)
                        netItem("↑ 上传", bytes: monitorService.stats.networkUpload, color: .purple)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isExpanded)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded { expandedSections.remove("network") }
            else { expandedSections.insert("network") }
        }
    }

    private func netItem(_ label: String, bytes: UInt64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(formatNetworkRate(bytes))
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(bytes)))
        }
    }

    // MARK: - GPU

    private var gpuSection: some View {
        Group {
            if let g = monitorService.stats.gpuUsage {
                sectionCard(kind: .gpu) {
                    VStack(alignment: .leading, spacing: 5) {
                        sectionHeader("GPU", icon: "display", color: .pink, value: g)
                        gaugeBar(g, color: .pink, height: 4)
                    }
                }
            }
        }
    }

    // MARK: - 组件

    private func sectionCard<C: View>(kind: ModuleKind, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(moduleCardTint(for: kind))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(moduleCardBorder(for: kind), lineWidth: 0.5)
            )
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    private func sectionHeader(_ title: String, icon: String, color: Color, value: Double?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
            if let v = value {
                Text(formatPercent(v))
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(v > 80 ? .red : v > 60 ? .orange : .primary)
                    .contentTransition(.numericText(value: v))
            }
        }
    }

    // MARK: - 格式化

    private func formatInterval(_ interval: TimeInterval) -> String {
        interval >= 1.0 ? "\(Int(interval))秒" : String(format: "%.1f秒", interval)
    }

    // MARK: - 动作

    private func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApp.activate()
    }
}

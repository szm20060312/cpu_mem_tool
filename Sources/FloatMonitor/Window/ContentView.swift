import SwiftUI
import Charts

// MARK: - 桌面窗口

struct ContentView: View {
    @EnvironmentObject var monitorService: SystemMonitorService
    @State private var selectedTab: Tab = .overview
    @State private var floatOnTop = false

    enum Tab: String, CaseIterable {
        case overview = "概览", cpu = "CPU", memory = "内存", network = "网络"
        var icon: String {
            switch self {
            case .overview: "square.grid.2x2"
            case .cpu: "cpu"
            case .memory: "memorychip"
            case .network: "network"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            separator
            tabContent
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 420, idealHeight: 560)
        .onChange(of: floatOnTop) { _, new in
            for w in NSApp.windows {
                if !w.isKind(of: NSClassFromString("NSStatusBarWindow") ?? NSWindow.self) {
                    w.level = new ? .floating : .normal
                }
            }
        }
    }

    // MARK: Top Bar

    private var headerBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let sel = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .font(.caption.weight(sel ? .semibold : .regular))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(sel ? .primary : .secondary)
                .background(sel ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: Capsule())
            }
            Spacer()
            Button { floatOnTop.toggle() } label: {
                Image(systemName: floatOnTop ? "pin.fill" : "pin").font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(floatOnTop ? .blue : .secondary)
            .help(floatOnTop ? "取消置顶" : "窗口置顶")
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }

    private var separator: some View {
        Rectangle().fill(.quaternary).frame(height: 0.5)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview: OverviewTab()
        case .cpu:      CPUTab()
        case .memory:   MemoryTab()
        case .network:  NetworkTab()
        }
    }
}

// MARK: - 概览 Tab

private struct OverviewTab: View {
    @EnvironmentObject var s: SystemMonitorService

    private var memPct: Double {
        s.stats.memoryTotal > 0 ? Double(s.stats.memoryUsed) / Double(s.stats.memoryTotal) * 100 : 0
    }
    private var memColor: Color {
        switch s.stats.memoryPressure { case .normal: .green; case .warning: .orange; case .critical: .red }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                metricCard(kind: .cpu, "CPU", icon: "cpu", color: .blue, value: s.stats.cpuUsage) {
                    gaugeBar(s.stats.cpuUsage, color: .blue)
                    miniCores(s.stats.cpuPerCore)
                    if let t = s.stats.cpuTemperature {
                        HStack(spacing: 4) {
                            Image(systemName: "thermometer.medium")
                                .font(.caption).foregroundStyle(tempColor(t))
                            Text(String(format: "%.0f°C", t))
                                .font(.callout.weight(.semibold).monospacedDigit())
                                .foregroundStyle(tempColor(t))
                        }
                    }
                }
                metricCard(kind: .memory, "内存", icon: "memorychip", color: memColor, value: memPct) {
                    gaugeBar(memPct, color: memColor)
                    HStack {
                        Circle().fill(memColor).frame(width: 5, height: 5)
                        Text(s.stats.memoryPressure.label).font(.caption2).foregroundStyle(memColor)
                        Spacer()
                        Text(formatMemoryBytes(s.stats.memoryUsed)).font(.caption2).foregroundStyle(.secondary)
                        Text(" / ").font(.caption2).foregroundStyle(.quaternary)
                        Text(formatMemoryBytes(s.stats.memoryTotal)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if let g = s.stats.gpuUsage {
                    metricCard(kind: .gpu, "GPU", icon: "display", color: .pink, value: g) {
                        gaugeBar(g, color: .pink)
                    }
                }
                metricCard(kind: .network, "网络", icon: "network", color: .purple, value: nil) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("↓ 下载").font(.caption2).foregroundStyle(.secondary)
                            Text(formatNetworkRate(s.stats.networkDownload))
                                .font(.body.weight(.semibold).monospaced()).foregroundStyle(.blue)
                        }
                        Spacer()
                        Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 32)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("↑ 上传").font(.caption2).foregroundStyle(.secondary)
                            Text(formatNetworkRate(s.stats.networkUpload))
                                .font(.body.weight(.semibold).monospaced()).foregroundStyle(.purple)
                        }
                    }
                }
                refreshRow
            }
            .padding(16)
        }
    }

    private var refreshRow: some View {
        HStack {
            Text("刷新间隔").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: $s.refreshInterval) {
                ForEach(SystemMonitorService.availableIntervals, id: \.self) { i in
                    Text(i >= 1 ? "\(Int(i))秒" : "0.5秒").tag(i)
                }
            }
            .pickerStyle(.segmented).controlSize(.small).frame(maxWidth: 220)
            Spacer()
        }
    }

    private func miniCores(_ cores: [Double]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(cores.enumerated()), id: \.offset) { _, u in
                RoundedRectangle(cornerRadius: 1)
                    .fill(coreColor(u))
                    .frame(height: max(2, 16 * min(u, 100) / 100))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 18)
    }

    private func metricCard<V: View>(kind: ModuleKind, _ title: String, icon: String, color: Color, value: Double?, @ViewBuilder sub: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption.weight(.semibold)).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(.primary)
                Spacer()
                if let v = value {
                    Text(formatPercent(v))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(v > 80 ? .red : v > 60 ? .orange : .primary)
                        .contentTransition(.numericText(value: v))
                }
            }
            sub()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(moduleCardTint(for: kind))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(moduleCardBorder(for: kind), lineWidth: 0.5)
        )
    }
}

// MARK: - CPU Tab

private struct CPUTab: View {
    @EnvironmentObject var s: SystemMonitorService

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    HStack { Image(systemName: "cpu").foregroundStyle(.blue); Text("总使用率").font(.caption) }
                    Text(String(format: "%.1f%%", s.stats.cpuUsage))
                        .font(.system(size: 48, weight: .thin, design: .rounded))
                        .contentTransition(.numericText(value: s.stats.cpuUsage))
                    gaugeBar(s.stats.cpuUsage, color: .blue)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Image(systemName: "cpu").foregroundStyle(.blue); Text("每核心负载").font(.caption) }
                    ForEach(Array(s.stats.cpuPerCore.enumerated()), id: \.offset) { i, u in
                        HStack(spacing: 8) {
                            Text(String(format: "%2d", i)).font(.caption2.monospaced()).foregroundStyle(.secondary).frame(width: 16)
                            gaugeBar(u, color: coreColor(u))
                            Text(String(format: "%3.0f%%", u)).font(.caption2.monospacedDigit()).foregroundStyle(coreColor(u)).frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - 内存 Tab

private struct MemoryTab: View {
    @EnvironmentObject var s: SystemMonitorService

    private var memPct: Double {
        s.stats.memoryTotal > 0 ? Double(s.stats.memoryUsed) / Double(s.stats.memoryTotal) * 100 : 0
    }
    private var memColor: Color {
        switch s.stats.memoryPressure { case .normal: .green; case .warning: .orange; case .critical: .red }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    HStack { Image(systemName: "memorychip").foregroundStyle(memColor); Text("内存使用").font(.caption) }
                    Text(String(format: "%.1f%%", memPct))
                        .font(.system(size: 48, weight: .thin, design: .rounded))
                        .contentTransition(.numericText(value: memPct))
                    gaugeBar(memPct, color: memColor)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("已使用").font(.caption2).foregroundStyle(.secondary)
                            Text(formatMemoryBytes(s.stats.memoryUsed)).font(.body.weight(.semibold))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("总容量").font(.caption2).foregroundStyle(.secondary)
                            Text(formatMemoryBytes(s.stats.memoryTotal)).font(.body.weight(.semibold))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Image(systemName: "gauge.with.dots.needle.33percent").foregroundStyle(.orange); Text("内存压力").font(.caption) }
                    HStack(spacing: 20) {
                        ForEach(MemoryPressure.allCases, id: \.self) { lv in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(s.stats.memoryPressure == lv ? pressureColor(lv) : .clear)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                                Text(lv.label).font(.caption2)
                                    .foregroundStyle(s.stats.memoryPressure == lv ? .primary : .secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func pressureColor(_ p: MemoryPressure) -> Color {
        switch p { case .normal: .green; case .warning: .orange; case .critical: .red }
    }
}

// MARK: - 网络 Tab

private struct NetworkTab: View {
    @EnvironmentObject var s: SystemMonitorService
    @StateObject private var h = NetworkHistoryManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    rateCard("↓ 下载", rate: s.stats.networkDownload, color: .blue)
                    rateCard("↑ 上传", rate: s.stats.networkUpload, color: .purple)
                }
                chartCard("下载速率", color: .blue, points: h.recentPoints, kp: \.download)
                chartCard("上传速率", color: .purple, points: h.recentPoints, kp: \.upload)
                dailyCard
            }
            .padding(16)
        }
    }

    private func rateCard(_ label: String, rate: UInt64, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(formatNetworkRate(rate))
                .font(.title2.weight(.semibold).monospaced())
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(rate)))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
    }

    private func chartCard(_ title: String, color: Color, points: [NetworkDataPoint], kp: KeyPath<NetworkDataPoint, UInt64>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if points.count < 2 {
                Text("等待数据…").font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 110)
            } else {
                Chart(points) { p in
                    LineMark(x: .value("时间", p.timestamp), y: .value("速率", p[keyPath: kp]))
                        .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 1.5))
                    AreaMark(x: .value("时间", p.timestamp), y: .value("速率", p[keyPath: kp]))
                        .foregroundStyle(LinearGradient(
                            colors: [color.opacity(0.12), color.opacity(0.01)],
                            startPoint: .top, endPoint: .bottom))
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .frame(height: 120)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.05), lineWidth: 0.5))
    }

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日流量统计").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                dailyItem("总下载", bytes: h.todayStats.download, color: .blue)
                Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 32)
                dailyItem("总上传", bytes: h.todayStats.upload, color: .purple)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.05), lineWidth: 0.5))
    }

    private func dailyItem(_ label: String, bytes: UInt64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(formatTotal(bytes)).font(.callout.weight(.semibold).monospaced()).foregroundStyle(color)
        }
    }

    private func formatTotal(_ b: UInt64) -> String {
        if b >= 1_073_741_824 { return String(format: "%.2f GB", Double(b) / 1_073_741_824) }
        if b >= 1_048_576 { return String(format: "%.1f MB", Double(b) / 1_048_576) }
        if b >= 1_024 { return String(format: "%.0f KB", Double(b) / 1_024) }
        return "\(b) B"
    }
}

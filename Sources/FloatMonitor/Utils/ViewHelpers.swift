import SwiftUI

// MARK: - Shared View Helpers

/// 统一的进度条组件
@ViewBuilder
func gaugeBar(_ value: Double, color: Color, height: CGFloat = 5) -> some View {
    GeometryReader { g in
        ZStack(alignment: .leading) {
            Capsule().fill(.quaternary).frame(height: height)
            Capsule()
                .fill(coreColor(value))
                .frame(width: max(height, g.size.width * min(value, 100) / 100), height: height)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
        }
    }
    .frame(height: height)
}

/// 根据使用率返回对应颜色：>80% 红，>60% 橙，否则蓝
func coreColor(_ usage: Double) -> Color {
    usage > 80 ? .red : usage > 60 ? .orange : .blue
}

/// 根据温度返回对应颜色：>90°C 红，>70°C 橙，否则青
func tempColor(_ t: Double) -> Color {
    t > 90 ? .red : t > 70 ? .orange : .teal
}

// MARK: - 模块色板

/// 模块标识，用于卡片着色
enum ModuleKind: String, CaseIterable {
    case cpu, memory, network, gpu
}

/// 根据模块返回微弱的卡片底色（基于 HagimiMonitor 的 balanced 色板）
func moduleCardTint(for kind: ModuleKind) -> Color {
    switch kind {
    case .cpu:     Color(hex: 0xD27A4A, alpha: 0.14)
    case .memory:  Color(hex: 0x42A39A, alpha: 0.14)
    case .network: Color(hex: 0x8B5CF6, alpha: 0.14)
    case .gpu:     Color(hex: 0x5D8CF0, alpha: 0.14)
    }
}

/// 根据模块返回卡片边框色（HagimiMonitor 的 rowSeparator: 约 0.22 暗色 / 0.14 亮色）
func moduleCardBorder(for kind: ModuleKind) -> Color {
    switch kind {
    case .cpu:     Color(hex: 0xD27A4A, alpha: 0.22)
    case .memory:  Color(hex: 0x42A39A, alpha: 0.22)
    case .network: Color(hex: 0x8B5CF6, alpha: 0.22)
    case .gpu:     Color(hex: 0x5D8CF0, alpha: 0.22)
    }
}

// MARK: - 格式化（固定宽度，视觉对齐）

/// 格式化百分比，固定 4 字符宽度："  5%", " 45%", "100%"
func formatPercent(_ v: Double) -> String {
    String(format: "%3.0f%%", v)
}

/// 格式化字节为可读字符串（内存用，固定 7 字符宽度：" 14.4 GB"）
func formatMemoryBytes(_ bytes: UInt64) -> String {
    String(format: "%5.1f GB", Double(bytes) / 1_073_741_824)
}

/// 格式化网络速率（固定宽度，支持 MB/s 和 Mbps）
@MainActor
func formatNetworkRate(_ bytes: UInt64) -> String {
    let unit = AppSettings.shared.networkUnit
    if unit == .bitsPerSec {
        let bps = Double(bytes) * 8
        if bps >= 1_000_000_000 { return String(format: "%4.1f Gbps", bps / 1_000_000_000) }
        if bps >= 1_000_000 { return String(format: "%4.1f Mbps", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%4.0f Kbps", bps / 1_000) }
        return String(format: "%4d bps", Int(bps))
    }
    if bytes >= 1_000_000 { return String(format: "%4.1f MB/s", Double(bytes) / 1_000_000) }
    if bytes >= 1_000     { return String(format: "%4.0f KB/s", Double(bytes) / 1_000) }
    return String(format: "%4d B/s", bytes)
}

// MARK: - 颜色扩展

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

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

/// 格式化字节为可读字符串（内存用，二进制单位）
func formatMemoryBytes(_ bytes: UInt64) -> String {
    String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
}

/// 格式化网络速率（支持 MB/s 和 Mbps）
@MainActor
func formatNetworkRate(_ bytes: UInt64) -> String {
    let unit = AppSettings.shared.networkUnit
    if unit == .bitsPerSec {
        let bps = Double(bytes) * 8
        if bps >= 1_000_000_000 { return String(format: "%.1f Gbps", bps / 1_000_000_000) }
        if bps >= 1_000_000 { return String(format: "%.1f Mbps", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0f Kbps", bps / 1_000) }
        return "\(Int(bps)) bps"
    }
    if bytes >= 1_000_000 { return String(format: "%.1f MB/s", Double(bytes) / 1_000_000) }
    if bytes >= 1_000     { return String(format: "%.0f KB/s", Double(bytes) / 1_000) }
    return "\(bytes) B/s"
}

import Foundation

/// 系统监控数据模型
struct SystemStats {
    // CPU
    var cpuUsage: Double = 0.0              // 整体使用率 0-100
    var cpuPerCore: [Double] = []           // 每核心使用率

    // 内存
    var memoryTotal: UInt64 = 0             // 物理内存总量 (bytes)
    var memoryUsed: UInt64 = 0              // 已用内存 (bytes)
    var memoryPressure: MemoryPressure = .normal

    // GPU
    var gpuUsage: Double? = nil             // 0-100

    // 温度 (°C)
    var cpuTemperature: Double? = nil

    // 网络 (bytes/s)
    var networkDownload: UInt64 = 0
    var networkUpload: UInt64 = 0
}

/// 内存压力级别
enum MemoryPressure: String, CaseIterable {
    case normal
    case warning
    case critical

    var label: String {
        switch self {
        case .normal:   return "正常"
        case .warning:  return "警告"
        case .critical: return "紧急"
        }
    }
}

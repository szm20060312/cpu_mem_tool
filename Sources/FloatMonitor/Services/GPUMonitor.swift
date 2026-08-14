import Foundation
import IOKit
import os

/// GPU 监控器
/// 通过 IOKit 匹配 IOAccelerator 服务获取 GPU 使用率
enum GPUMonitor {
    /// 获取 GPU 使用率（0-100%）
    /// 在 Apple Silicon 上读取 IOAccelerator 的 PerformanceStatistics
    static func getUsage() -> Double? {
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        ) == KERN_SUCCESS else { return nil }

        defer { IOObjectRelease(iterator) }

        var gpuUsage: Double? = nil

        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let usage = readGPUsage(service) {
                gpuUsage = max(gpuUsage ?? 0, usage)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return gpuUsage
    }

    private static func readGPUsage(_ service: io_service_t) -> Double? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            service,
            &properties,
            kCFAllocatorDefault,
            0
        ) == KERN_SUCCESS,
        let props = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        guard let perfStats = props["PerformanceStatistics"] as? [String: Any] else {
            return nil
        }

        // 尝试已知的 GPU 使用率 key（不同 GPU 型号 key 名不同）
        let candidateKeys = [
            "GPU Core Utilization",
            "gpuCoreUtilization",
            "Device Utilization %",
            "GPU Utilization",
            "GPU utilization",
            "gpuUtilization",
        ]

        for key in candidateKeys {
            if let raw = perfStats[key] {
                // 值可能为 Int (百分比整数) 或 Double (0-1 小数)
                if let percent = raw as? Int {
                    return Double(percent)
                } else if let fraction = raw as? Double {
                    return fraction <= 1.0 ? fraction * 100 : fraction
                } else if let percent = raw as? UInt64 {
                    return Double(percent)
                }
            }
        }

        // 日志未匹配到的 key，方便调试
        #if DEBUG
        let statKeys = perfStats.keys.sorted()
        if !statKeys.isEmpty {
            Logger.app.debug("Available PerformanceStatistics keys: \(statKeys)")
        }
        #endif

        return nil
    }
}

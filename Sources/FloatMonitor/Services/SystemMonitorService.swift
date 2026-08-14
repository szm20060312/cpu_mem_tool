import Foundation
import Darwin

/// 系统监控服务（全局单例）
/// 按可配置的间隔采集 CPU/内存/温度/网络/GPU 真实数据
@MainActor
final class SystemMonitorService: ObservableObject {
    static let shared = SystemMonitorService()

    /// 可用的刷新间隔选项
    static let availableIntervals: [TimeInterval] = [0.5, 1.0, 2.0, 5.0]

    @Published var stats = SystemStats()

    /// 当前刷新间隔（与 AppSettings 同步）
    @Published var refreshInterval: TimeInterval = AppSettings.shared.refreshInterval {
        didSet {
            guard refreshInterval != oldValue else { return }
            AppSettings.shared.refreshInterval = refreshInterval
            restartTimer()
        }
    }

    private var timer: Timer?
    private let smcMonitor: SMCMonitor? = SMCMonitor()

    // 用于计算差值的上一轮数据
    private var previousCPUTicks: [processor_cpu_load_info]?
    private var previousNetworkBytes: (received: UInt64, sent: UInt64)?
    private var settingsObserver: Any?

    private init() {
        startMonitoring()
        // 同步 AppSettings 变更
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                let newVal = AppSettings.shared.refreshInterval
                if self?.refreshInterval != newVal {
                    self?.refreshInterval = newVal
                }
            }
        }
    }


    func startMonitoring() {
        refreshStats()
        scheduleTimer()
    }

    /// 重启定时器（间隔变更时调用）
    private func restartTimer() {
        timer?.invalidate()
        // 重置差值基准，避免因间隔变化导致 CPU/网络数据异常
        previousCPUTicks = nil
        previousNetworkBytes = nil
        refreshStats()
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: refreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStats()
            }
        }
    }

    // MARK: - 主刷新

    private func refreshStats() {
        let cpu = fetchCPU()
        let memory = fetchMemory()
        let network = fetchNetwork()
        let gpuUsage = GPUMonitor.getUsage()
        let cpuTemp = smcMonitor?.cpuTemperature()

        stats = SystemStats(
            cpuUsage: cpu.overall,
            cpuPerCore: cpu.perCore,
            memoryTotal: memory.total,
            memoryUsed: memory.used,
            memoryPressure: memory.pressure,
            gpuUsage: gpuUsage,
            cpuTemperature: cpuTemp,
            networkDownload: network.download,
            networkUpload: network.upload
        )

        // 记录网络历史（用于折线图和每日统计）
        NetworkHistoryManager.shared.record(
            download: network.download,
            upload: network.upload,
            interval: refreshInterval
        )
    }

    // MARK: - CPU

    private func fetchCPU() -> (overall: Double, perCore: [Double]) {
        var count = mach_msg_type_number_t()
        var info: processor_info_array_t?
        var cpuCount = natural_t()

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &count
        )

        guard result == KERN_SUCCESS, let info = info, cpuCount > 0 else {
            return (0, [])
        }

        let ticks = info.withMemoryRebound(
            to: processor_cpu_load_info.self,
            capacity: Int(cpuCount)
        ) { ptr in
            Array(UnsafeBufferPointer(start: ptr, count: Int(cpuCount)))
        }

        // 释放内核分配的内存
        let infoAddr = vm_address_t(bitPattern: info)
        vm_deallocate(
            mach_task_self_,
            infoAddr,
            vm_size_t(Int(count) * MemoryLayout<integer_t>.size)
        )

        defer { previousCPUTicks = ticks }

        guard let previous = previousCPUTicks, previous.count == ticks.count else {
            return (0, [])
        }

        var perCore: [Double] = []
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0..<Int(cpuCount) {
            let cur = ticks[i].cpu_ticks
            let prev = previous[i].cpu_ticks

            let dUser   = max(0, Int64(cur.0) - Int64(prev.0))
            let dSystem = max(0, Int64(cur.1) - Int64(prev.1))
            let dIdle   = max(0, Int64(cur.2) - Int64(prev.2))
            let dNice   = max(0, Int64(cur.3) - Int64(prev.3))

            let total = dUser + dSystem + dIdle + dNice
            let used = dUser + dSystem + dNice

            perCore.append(total > 0 ? (Double(used) / Double(total)) * 100 : 0)

            totalUser   += UInt64(dUser)
            totalSystem += UInt64(dSystem)
            totalIdle   += UInt64(dIdle)
            totalNice   += UInt64(dNice)
        }

        let totalAll = totalUser + totalSystem + totalIdle + totalNice
        let totalUsed = totalUser + totalSystem + totalNice
        let overall = totalAll > 0 ? (Double(totalUsed) / Double(totalAll)) * 100 : 0

        return (overall, perCore)
    }

    // MARK: - 内存

    private func fetchMemory() -> (total: UInt64, used: UInt64, pressure: MemoryPressure) {
        let total = physicalMemorySize()
        let used = usedMemory()
        let pressure = memoryPressure()
        return (total, used, pressure)
    }

    private func physicalMemorySize() -> UInt64 {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        sysctl(&mib, 2, &size, &len, nil, 0)
        return size
    }

    private func usedMemory() -> UInt64 {
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let pageSize = UInt64(sysconf(Int32(_SC_PAGESIZE)))

        // macOS Activity Monitor 口径:
        // Used = App Memory + Wired + Compressed
        // App Memory ≈ internal - speculative + purgeable
        let internalCount = UInt64(vmStat.internal_page_count)
        let speculativeCount = UInt64(vmStat.speculative_count)
        let appMemory: UInt64 = internalCount > speculativeCount ? internalCount - speculativeCount : 0
        let wired        = UInt64(vmStat.wire_count)
        let compressed   = UInt64(vmStat.compressor_page_count)
        let purgeable    = UInt64(vmStat.purgeable_count)

        return (appMemory + wired + compressed + purgeable) * pageSize
    }

    private func memoryPressure() -> MemoryPressure {
        var pressure: Int32 = 0
        var len = MemoryLayout<Int32>.size

        let result = sysctlbyname(
            "kern.memorystatus_vm_pressure_level",
            &pressure,
            &len,
            nil,
            0
        )

        guard result == 0 else { return .normal }

        switch pressure {
        case 2:  return .warning    // VM_PRESSURE_WARNING
        case 4:  return .critical   // VM_PRESSURE_CRITICAL
        default: return .normal
        }
    }

    // MARK: - 网络

    private func fetchNetwork() -> (download: UInt64, upload: UInt64) {
        let current = networkBytes()
        defer { previousNetworkBytes = current }

        guard let prev = previousNetworkBytes else {
            return (0, 0) // 首次采集无差值，返回 0（1 个间隔后自动正常）
        }

        let download = max(0, Int64(current.received) - Int64(prev.received))
        let upload   = max(0, Int64(current.sent) - Int64(prev.sent))

        return (UInt64(download), UInt64(upload))
    }

    private func networkBytes() -> (received: UInt64, sent: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(first) }

        var totalReceived: UInt64 = 0
        var totalSent: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let ifa = ptr?.pointee else { continue }
            let name = String(cString: ifa.ifa_name)

            // 排除回环接口
            guard name != "lo0" else { continue }

            // 只统计 UP + RUNNING 的接口
            let flags = ifa.ifa_flags
            guard (flags & UInt32(IFF_UP)) != 0,
                  (flags & UInt32(IFF_RUNNING)) != 0 else { continue }

            guard let addr = ifa.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK),
                  let data = ifa.ifa_data else { continue }

            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
            totalReceived += UInt64(networkData.ifi_ibytes)
            totalSent     += UInt64(networkData.ifi_obytes)
        }

        return (totalReceived, totalSent)
    }
}

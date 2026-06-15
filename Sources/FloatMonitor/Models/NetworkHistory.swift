import Foundation

// MARK: - 网络历史数据点

/// 单个采样点的网络数据
struct NetworkDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let download: UInt64  // bytes/s
    let upload: UInt64
}

// MARK: - 每日流量统计

/// 某一天的累计流量
struct DailyNetworkStats: Codable {
    var download: UInt64  // 累计下载 bytes
    var upload: UInt64    // 累计上传 bytes
    var date: String      // "YYYY-MM-DD"

    static func todayKey() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func loadToday() -> DailyNetworkStats {
        let key = todayKey()
        guard let data = UserDefaults.standard.data(forKey: "net_daily_\(key)"),
              let stats = try? JSONDecoder().decode(DailyNetworkStats.self, from: data) else {
            return DailyNetworkStats(download: 0, upload: 0, date: key)
        }
        return stats
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "net_daily_\(date)")
    }
}

// MARK: - 网络历史管理器

final class NetworkHistoryManager: ObservableObject {
    @MainActor static let shared = NetworkHistoryManager()

    /// 最近 N 个采样点（用于折线图）
    @Published var recentPoints: [NetworkDataPoint] = []
    /// 今日累计统计
    @Published var todayStats = DailyNetworkStats.loadToday()

    private let maxPoints = 120
    private var accumulatedDownload: UInt64 = 0
    private var accumulatedUpload: UInt64 = 0
    private var lastSaveTime = Date()

    @MainActor
    func record(download: UInt64, upload: UInt64, interval: TimeInterval) {
        let now = Date()
        let point = NetworkDataPoint(timestamp: now, download: download, upload: upload)

        recentPoints.append(point)
        if recentPoints.count > maxPoints {
            recentPoints.removeFirst(recentPoints.count - maxPoints)
        }

        // 累计流量（字节/秒 × 间隔秒 = 字节）
        accumulatedDownload += UInt64(Double(download) * interval)
        accumulatedUpload   += UInt64(Double(upload)   * interval)

        // 每 10 秒持久化一次
        if now.timeIntervalSince(lastSaveTime) >= 10 {
            cleanOldDailyStats()
            saveDailyStats()
            lastSaveTime = now
        }
    }

    /// 清理 30 天前的旧每日统计，防止 UserDefaults 键无限累积
    private func cleanOldDailyStats() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        let cutoffKey = f.string(from: cutoff)

        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix("net_daily_") {
                let dateString = String(key.dropFirst("net_daily_".count))
                if dateString.count == 10 && dateString < cutoffKey {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }

    private func saveDailyStats() {
        var stats = DailyNetworkStats.loadToday()
        stats.download += accumulatedDownload
        stats.upload   += accumulatedUpload
        stats.save()

        accumulatedDownload = 0
        accumulatedUpload = 0
        todayStats = stats
    }
}

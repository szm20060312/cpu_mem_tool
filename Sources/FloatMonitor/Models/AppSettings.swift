import Foundation
import os
import ServiceManagement

// MARK: - 菜单栏显示模式

enum MenuBarMode: String, CaseIterable {
    case compact = "紧凑双行"
    case textOnly = "纯文字"
    case iconText = "图标+文字"

    var description: String {
        switch self {
        case .compact: "C 23% / M 58%"
        case .textOnly: "CPU 23% MEM 58%"
        case .iconText: "cpu C 23% M 58%"
        }
    }
}

// MARK: - 网络速率单位

enum NetworkUnit: String, CaseIterable {
    case bytesPerSec = "MB/s"
    case bitsPerSec  = "Mbps"
}

// MARK: - 应用设置

final class AppSettings: ObservableObject {
    @MainActor static let shared = AppSettings()

    // 刷新间隔
    @Published var refreshInterval: TimeInterval {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "com.floatmonitor.refresh_interval") }
    }

    // 菜单栏显示模式
    @Published var menuBarMode: MenuBarMode {
        didSet { UserDefaults.standard.set(menuBarMode.rawValue, forKey: "com.floatmonitor.menu_bar_mode") }
    }

    // 网络速率单位
    @Published var networkUnit: NetworkUnit {
        didSet { UserDefaults.standard.set(networkUnit.rawValue, forKey: "com.floatmonitor.network_unit") }
    }

    // 开机启动
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Logger.app.error("开机启动设置失败: \(error)")
                launchAtLogin = oldValue
            }
        }
    }

    // 窗口默认置顶
    @Published var floatOnTopByDefault: Bool {
        didSet { UserDefaults.standard.set(floatOnTopByDefault, forKey: "com.floatmonitor.float_on_top") }
    }

    private init() {
        let ud = UserDefaults.standard

        self.refreshInterval = ud.double(forKey: "com.floatmonitor.refresh_interval").nonZero ?? 1.0
        self.menuBarMode = MenuBarMode(rawValue: ud.string(forKey: "com.floatmonitor.menu_bar_mode") ?? "") ?? .compact
        self.networkUnit = NetworkUnit(rawValue: ud.string(forKey: "com.floatmonitor.network_unit") ?? "") ?? .bytesPerSec
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.floatOnTopByDefault = ud.bool(forKey: "com.floatmonitor.float_on_top")
    }
}

private extension Double {
    var nonZero: Double? { self > 0 ? self : nil }
}

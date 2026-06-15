import SwiftUI

/// FloatMonitor — Mac 菜单栏系统监控应用
/// macOS 26 "液态玻璃"设计风格
@main
struct FloatMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(SystemMonitorService.shared)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 480, height: 560)

        Settings {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

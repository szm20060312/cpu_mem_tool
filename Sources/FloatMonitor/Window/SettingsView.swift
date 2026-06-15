import SwiftUI

// MARK: - 设置页面

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            generalTab.tabItem { Label("通用", systemImage: "gearshape") }
            menuBarTab.tabItem { Label("菜单栏", systemImage: "menubar.rectangle") }
        }
        .frame(width: 420, height: 340)
    }

    // MARK: 通用

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 刷新间隔
                settingSection("刷新间隔", icon: "clock") {
                    HStack {
                        ForEach(SystemMonitorService.availableIntervals, id: \.self) { i in
                            Button {
                                settings.refreshInterval = i
                            } label: {
                                Text(formatInterval(i))
                                    .font(.caption.weight(settings.refreshInterval == i ? .semibold : .regular))
                                    .padding(.horizontal, 12).padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(settings.refreshInterval == i ? .white : .primary)
                            .background(
                                settings.refreshInterval == i
                                    ? Capsule().fill(.blue)
                                    : Capsule().fill(.clear)
                            )
                        }
                    }
                    Text("数据更新频率，越低响应越快但消耗稍高")
                        .font(.caption2).foregroundStyle(.tertiary)
                }

                Divider().padding(.horizontal, 16)

                // 开机启动
                settingSection("开机启动", icon: "power.circle") {
                    Toggle("登录时自动启动 FloatMonitor", isOn: $settings.launchAtLogin)
                        .font(.caption)
                }

                Divider().padding(.horizontal, 16)

                // 窗口置顶
                settingSection("窗口置顶", icon: "pin") {
                    Toggle("桌面窗口默认置顶", isOn: $settings.floatOnTopByDefault)
                        .font(.caption)
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: 菜单栏

    private var menuBarTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 显示模式
                settingSection("显示模式", icon: "textformat") {
                    VStack(spacing: 8) {
                        ForEach(MenuBarMode.allCases, id: \.self) { mode in
                            Button {
                                settings.menuBarMode = mode
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.rawValue).font(.caption.weight(.medium))
                                        Text(mode.description).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if settings.menuBarMode == mode {
                                        Image(systemName: "checkmark").font(.caption).foregroundStyle(.blue)
                                    }
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(
                                    settings.menuBarMode == mode ? .blue.opacity(0.1) : .clear
                                ))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().padding(.horizontal, 16)

                // 网络单位
                settingSection("网络速率单位", icon: "arrow.left.arrow.right") {
                    HStack {
                        ForEach(NetworkUnit.allCases, id: \.self) { unit in
                            Button {
                                settings.networkUnit = unit
                            } label: {
                                Text(unit.rawValue)
                                    .font(.caption.weight(settings.networkUnit == unit ? .semibold : .regular))
                                    .padding(.horizontal, 12).padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(settings.networkUnit == unit ? .white : .primary)
                            .background(
                                settings.networkUnit == unit
                                    ? Capsule().fill(.blue)
                                    : Capsule().fill(.clear)
                            )
                        }
                    }
                    Text("MB/s = 兆字节/秒，Mbps = 兆比特/秒 (1 MB/s = 8 Mbps)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: 组件

    private func settingSection<V: View>(_ title: String, icon: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption).foregroundStyle(.blue).frame(width: 16)
                Text(title).font(.caption.weight(.semibold))
            }
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func formatInterval(_ i: TimeInterval) -> String {
        i >= 1.0 ? "\(Int(i))秒" : String(format: "%.1f秒", i)
    }
}

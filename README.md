# FloatMonitor

Mac 菜单栏系统监控工具，实时显示 CPU / 内存占用，点击弹出详细面板查看 GPU、网络等完整数据。macOS 原生设计风格。

## ✨ 功能

### 菜单栏实时监控
- **双行紧凑显示** — `C 23%` / `M 58%` 只占 37pt 宽度，不挤占菜单栏空间
- **三种显示模式** — 紧凑双行 / 纯文字 / 图标+文字，可在设置中切换
- **等宽数字字体** — 数值变化时宽度不跳动
- **深色/浅色自适应** — 自动跟随系统外观

### 弹出面板 (Popover)
- **CPU** — 总使用率 + 每核心竖状图，颜色随负载变化（蓝→橙→红）
- **内存** — 使用率进度条 + 内存压力指示灯（绿/橙/红）+ 已用/总量
- **网络** — 下载/上传实时速率，支持 MB/s 和 Mbps 两种单位
- **GPU** — Apple Silicon GPU 实时使用率
- **底部控制栏** — 刷新间隔一键切换（0.5s / 1s / 2s / 5s）+ 退出按钮

### 桌面窗口模式
- **概览** — 指标卡片网格（CPU / 内存 / GPU / 网络），含进度条和辅助信息
- **CPU** — 总使用率大数字 + 每核心负载条带标签
- **内存** — 使用率仪表 + 已用/总量对比 + 压力状态
- **网络** — Swift Charts 折线图（下载/上传 LineMark + AreaMark）+ 今日累计流量
- **窗口置顶** — 📌 pin 图标一键切换浮动窗口

### 设置
- 刷新间隔（0.5s / 1s / 2s / 5s）
- 菜单栏显示模式（紧凑 / 纯文字 / 图标+文字）
- 网络速率单位（MB/s / Mbps）
- 开机自动启动（SMAppService）
- 窗口默认置顶

## 📋 系统要求

| 项目 | 要求 |
|------|------|
| 系统 | 已经支持 macOS 27 beta |
| 芯片 | Apple Silicon / Intel |
| 开发 | Xcode 26.5+ / Swift 6.0+ |

## 📦 安装

### 下载 DMG

从 [Releases](https://github.com/szm20060312/FloatMonitor/releases) 页面下载最新 `.dmg` 文件，拖入 Applications 即可。

### 从源码构建

```bash
git clone https://github.com/szm20060312/FloatMonitor.git
cd FloatMonitor

# 一键构建 + 启动
bash scripts/build_app.sh --run

# 停止
killall FloatMonitor
```

或使用 Xcode：

```bash
open Package.swift   # Xcode → Cmd+R 运行
```

## 🛠 技术栈

| 层面 | 技术 |
|------|------|
| UI | SwiftUI + AppKit (`NSStatusBar` / `NSPopover`) |
| 语言 | Swift 6 |
| CPU | `host_processor_info` (PROCESSOR_CPU_LOAD_INFO) |
| 内存 | `host_statistics64` + `sysctl(HW_MEMSIZE)` |
| 网络 | `getifaddrs` 遍历接口 + 差值法计算速率 |
| GPU | IOKit `IOAccelerator` → `PerformanceStatistics` |
| 图表 | Swift Charts (`LineMark` + `AreaMark`) |
| 持久化 | `UserDefaults` / `@AppStorage` |
| 构建 | Swift Package Manager |
| 打包 | 自定义 `.app` bundle + DMG |

## 📁 项目结构

```
FloatMonitor/
├── Package.swift                          # SPM 包定义
├── Sources/FloatMonitor/
│   ├── App/
│   │   ├── FloatMonitorApp.swift          # @main 入口 + Scene 定义
│   │   └── AppDelegate.swift              # NSStatusBar + NSPopover 管理
│   ├── MenuBar/
│   │   └── MenuBarView.swift              # 弹出面板（Popover 内容）
│   ├── Window/
│   │   ├── ContentView.swift              # 桌面窗口（概览/CPU/内存/网络）
│   │   └── SettingsView.swift             # 设置页面
│   ├── Services/
│   │   ├── SystemMonitorService.swift     # 核心监控服务（Timer + @Published）
│   │   └── GPUMonitor.swift               # GPU 使用率（IOKit IOAccelerator）
│   ├── Models/
│   │   ├── SystemStats.swift              # 系统数据模型
│   │   ├── AppSettings.swift              # 应用设置（UserDefaults + SMAppService）
│   │   └── NetworkHistory.swift           # 网络历史数据管理
│   └── Utils/
│       └── ViewHelpers.swift              # 共享 UI 组件和格式化函数
├── Resources/
│   ├── Info.plist                         # App 包配置（LSUIElement=true）
│   └── AppIcon.icns                       # 应用图标
├── scripts/
│   ├── build_app.sh                       # 编译 + 打包 .app
│   ├── package_release.sh                 # Release DMG 打包
│   └── generate_icon.swift                # 图标生成脚本
└── docs/                                  # 设计文档
    ├── requirements.md
    ├── tech-spec.md
    ├── design-spec.md
    └── implementation-steps.md
```

## ⚠️ 已知限制

- **温度传感器** — Apple Silicon 上标准 IOKit 路径无法获取 CPU/GPU 温度（macOS 安全限制），后续可通过 `powermetrics` 方案获取（需 sudo 授权）
- **菜单栏空间** — macOS 会在菜单栏空间不足时自动隐藏部分图标，FloatMonitor 紧凑模式已尽力减小宽度
- **Intel GPU** — GPU 使用率通过 `IOAccelerator` 读取，仅 Apple Silicon 可用

## 📝 更新日志

### v1.1.0 (2026-06-15)

**UI**
- 移除手动模拟的液态玻璃效果，窗口/面板回归 macOS 原生外观（macOS 27 已支持任务栏默认液态玻璃效果）

**并发安全**
- `SystemMonitorService` / `NetworkHistoryManager` / `AppSettings` 迁移至 `@MainActor`，提升 Swift 6 并发安全性

**Bug 修复**
- 内存计算 `&-` 下溢保护，防止异常状态下显示天文数字
- 每日网络统计 UserDefaults key 30 天自动清理，防止永久累积
- UserDefaults key 添加 `com.floatmonitor.` 命名空间前缀
- `openMainWindow()` 不再强制 `ignoringOtherApps`，不打断当前工作
- `todayKey()` 日期格式化锁定 `en_US_POSIX` locale
- 删除 `stopMonitoring()` / `formatRate()` 死代码
- 移除 `@MainActor` 类中冗余的 `.receive(on: DispatchQueue.main)`

**重构**
- 新建 `Utils/ViewHelpers.swift`，提取 `gaugeBar` / `coreColor` / 格式化函数，消除 MenuBarView 和 ContentView 间 4 处代码重复


## 📄 许可证

MIT License

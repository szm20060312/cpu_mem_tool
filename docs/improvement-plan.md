# FloatMonitor 长期改进计划

> 基于 [HagimiMonitor](https://github.com/Acerola-1/hagimi-monitor) 源码研究，结合 FloatMonitor 自身定位制定。

---

## 改进原则

1. **保持简洁** — FloatMonitor 的定位是轻量菜单栏监控，不过度工程化
2. **渐进演进** — 每阶段可独立交付，不依赖后续阶段
3. **用户感知** — 优先做用户能看到/感受到的改进
4. **先质量后功能** — 基础设施完善后再加新功能

---

## Phase 1：质量基础设施（v1.2.0）

> 目标：提升代码质量和可维护性，改动小、风险低。

### 1.1 菜单栏宽度锁定 （已完成✅）

**现状**：使用等宽数字字体 `monospacedDigitSystemFont` 减少跳动，但不同位数的值（如 5% vs 100%）仍会改变宽度。

**改进**：预计算每种模式最大可能字符串宽度，用固定占位符渲染。

```
C  5%  →  C  5%
M 38%  →  M 38%
C 100% →  C 100%   ← 宽度不变
M 98%  →  M 98%    ← 宽度不变
```

**涉及文件**：`AppDelegate.swift` 中的 `StatusBarTextView` 或 `updateStatusBar()`

**工作量**：小（~30 行改动）

---

### 1.2 OSLog 替代 print()  （已完成✅）

**现状**：`SystemMonitorService` 和 `AppSettings` 中使用 `print()` 输出调试信息。

**改进**：
```swift
import os

extension Logger {
    static let sampler  = Logger(subsystem: "com.floatmonitor.app", category: "sampler")
    static let settings = Logger(subsystem: "com.floatmonitor.app", category: "settings")
    static let ui       = Logger(subsystem: "com.floatmonitor.app", category: "ui")
}
```

**优势**：Console.app 可按分类过滤、生产环境延迟序列化（几乎零开销）、自动包含时间戳和调用位置。

**涉及文件**：`SystemMonitorService.swift`、`AppSettings.swift`

**工作量**：小（~10 行替换）

---

### 1.3 集中常量管理

**现状**：阈值、尺寸、动画参数散落在各视图文件中。

**改进**：新建 `Constants.swift`，集中管理：

```swift
enum Constants {
    enum Threshold {
        static let cpuWarning: Double = 60
        static let cpuCritical: Double = 80
        static let gpuWarning: Double = 70
        static let gpuCritical: Double = 85
    }
    enum Layout {
        static let popoverWidth: CGFloat = 260
        static let panelCornerRadius: CGFloat = 14
        static let cardCornerRadius: CGFloat = 12
        static let gaugeBarHeight: CGFloat = 5
    }
    enum Animation {
        static let gaugeSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    }
    enum Sampling {
        static let defaultInterval: TimeInterval = 1.0
        static let availableIntervals: [TimeInterval] = [0.5, 1.0, 2.0, 5.0]
        static let maxNetworkHistoryPoints = 120
    }
}
```

**涉及文件**：新建 `Constants.swift`，修改引用处

**工作量**：小（新建 1 个文件，修改 5-6 处引用）

---

## Phase 2：采集引擎升级（v1.3.0）

> 目标：提升数据采集效率和稳定性。

### 2.1 模块化刷新间隔

**现状**：所有指标统一按 `refreshInterval`（默认 1s）采集，GPU 和存储等低频需求浪费 CPU。

**改进**：为不同模块设置独立默认间隔，用户仍可按需覆盖。

```
刷新调度表（1s 心跳）：
┌──────────┬───────────┬──────────────┐
│ 模块     │ 默认间隔  │ 节省         │
├──────────┼───────────┼──────────────┤
│ CPU      │ 1s        │ —            │
│ 网络     │ 1s        │ —            │
│ 内存     │ 2s        │ 50% syscall  │
│ GPU      │ 2s        │ 50% IOKit    │
│ 温度     │ 5s        │ 80%（未来）  │
│ 存储     │ 10s       │ 90%（未来）  │
└──────────┴───────────┴──────────────┘
```

**实现**：新增 `MonitorRefreshSchedule` 结构体，跟踪每个模块的上次刷新时间和到期判断。

**涉及文件**：`SystemMonitorService.swift`（核心改动）、`AppSettings.swift`（新增间隔设置）

**工作量**：中（~100 行改动，需重构 Timer 管理）

---

### 2.2 优雅降级（部分失败处理）

**现状**：某个数据源失败时静默返回 0 或 nil，用户不知道发生了什么。

**改进**：
- 每个数据采集方法返回 `Result<T, SamplingError>`
- `refreshStats()` 收集所有成功结果，记录失败
- 面板中失败模块显示 "不可用" 而非空白

**涉及文件**：`SystemMonitorService.swift`、`GPUMonitor.swift`、UI 视图

**工作量**：中（~80 行）

---

### 2.3 采集性能优化

- `autoreleasepool` 包裹 IOKit 调用，控制峰值内存
- 可考虑用 `DispatchQueue.utility` 后台采集（当前全在主线程，虽然是同步调用耗时短，但高频采样仍可能影响 UI 响应）
- Timer 加入 `.common` RunLoop mode，避免滚动时暂停更新

**涉及文件**：`SystemMonitorService.swift`

**工作量**：小-中

---

## Phase 3：UI 体验提升（v1.4.0）

> 目标：菜单栏和面板交互更精细。

### 3.1 菜单栏指标可切换

**现状**：菜单栏固定显示 CPU + 内存，无法自定义。

**改进**：设置中新增"菜单栏指标"选项，支持选择最多 4 项：

```
可选指标：
  CPU     内存     GPU     网络↓    网络↑    存储    温度
```

默认显示 CPU + 内存（保持向后兼容），用户可在设置中增删。

**涉及文件**：`AppDelegate.swift`（更新 StatusBarTextView 文本生成）、`SettingsView.swift`（新增选项 UI）、`AppSettings.swift`（持久化选择）

**工作量**：中（~150 行）

---

### 3.2 面板 Sparkline 迷你图

**现状**：面板指标只有进度条和数值，没有趋势信息。

**改进**：在 CPU/内存模块中内嵌小型 sparkline 折线图（最近 24 点），让用户一眼看到变化趋势。

```
CPU ████████████▁▂▃▄▅▆▇█▇▆▅▄▃▂ 45%
```

**替代方案**：在现有进度条上叠加趋势方向指示符（↑↓→），更轻量。

**涉及文件**：`MenuBarView.swift`、`ContentView.swift`

**工作量**：中（sparkline ~80 行）或 小（方向符 ~15 行）

---

### 3.3 颜色语义化改善

**现状**：使用系统原始颜色（`.blue`、`.purple`、`.pink`），深浅模式切换时对比度不可控。

**改进**：新建轻量调色板，定义语义颜色：

```swift
enum MonitorColors {
    static func cpuTint(_ value: Double) -> Color { ... }
    static func memoryTint(_ pressure: MemoryPressure) -> Color { ... }
    static func networkDownloadTint() -> Color { .blue }
    static func gpuTint() -> Color { .pink }
}
```

**涉及文件**：`MenuBarView.swift`、`ContentView.swift`、新建 `MonitorColors.swift`

**工作量**：小（~30 行）

---

## Phase 4：新功能模块（v1.5.0+）

> 目标：增加用户可感知的新能力。

### 4.1 进程 Top 5 列表

**功能**：面板和桌面窗口中显示占用最高的 5 个进程。

```
CPU Top:
  1. WindowServer      12.3%
  2. Xcode             8.7%
  3. Safari            5.2%
  4. Terminal          2.1%
  5. FloatMonitor      1.8%

内存 Top:
  1. Xcode             2.4 GB
  2. Safari            1.8 GB
  3. WindowServer      823 MB
  4. SourceKitService  512 MB
  5. Terminal          245 MB
```

**技术方案**：
- CPU：`proc_pid_rusage` + shell `ps -Aceo pid,pcpu,comm -r`
- 内存：`proc_listallpids` + `proc_pid_rusage`（`ri_phys_footprint`）
- 进程图标：`NSRunningApplication` → `icon`
- 分组：按 Bundle ID 合并（避免 Safari 子进程分散显示）

**涉及文件**：新建 `ProcessMonitor.swift`、新增 UI 模块

**工作量**：大（~300 行）

---

### 4.2 计算负载环形图标

**功能**：菜单栏文字替换为 18×18pt 动态环形图，环形进度条颜色随系统综合负载从蓝→橙→红渐变。

**综合负载计算**：
```
combinedLoad = softmax(CPU负载, GPU负载, 内存压力指数, k=0.08)
```
- CPU 100% / GPU 10% / 内存正常 → 偏向 CPU 瓶颈值
- CPU 30% / GPU 30% / 内存警告 → 趋向压力均值
- 参数 k=0.08 控制瓶颈敏感度

**渲染**：
- 缓存：`NSCache` 最多 404 帧（101 负载级 × 2 配色 × 2 深浅模式）
- 量化：负载取整到 1%，使平滑动画几乎全部命中缓存
- ease-out 平滑：负载稳定时定时器自动停，零开销

**涉及文件**：新建 `MenuBarRingIcon.swift`、修改 `AppDelegate.swift`

**工作量**：大（~250 行，含缓存和动画逻辑）

---

### 4.3 应用内自动更新检查

**功能**：启动时检查 GitHub Releases，有新版时在面板底部显示提示。

**技术方案**：
- 查询 `https://api.github.com/repos/szm20060312/FloatMonitor/releases/latest`
- 语义化版本比较（`v1.2.0` > `1.1.0`）
- 状态机：检查中 → 有更新（提供下载链接）/ 已最新 / 检查失败
- 内存缓存结果 24 小时，避免频繁 API 调用
- 尊重 GitHub 速率限制（403/429 退避）

**涉及文件**：新建 `UpdateChecker.swift`、在 `MenuBarView.swift` 或 `SettingsView.swift` 中添加 UI

**工作量**：中（~150 行）

---

### 4.4 电池信息模块（MacBook 用户）

**功能**：面板中新增电池模块，显示电量百分比、充放电状态、循环次数、健康度。

**技术方案**：`IOKit` → `AppleSmartBattery` 服务，兼容 macOS 26/27 的 IORegistry 路径变更。

**涉及文件**：新建 `BatteryMonitor.swift`、修改 `SystemStats`、面板 UI

**工作量**：中（~120 行）

---

### 4.5 存储空间模块

**功能**：面板中显示主磁盘剩余空间。

**技术方案**：`URL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])`

**涉及文件**：新增 `SystemMonitorService` 采集方法、修改 `SystemStats`、UI

**工作量**：小（~40 行）

---

## Phase 5：工程化提升（持续）

> 不与具体版本绑定，持续改进。

### 5.1 测试基础设施

**当前状态**：零测试。

**建议**：至少覆盖：
- `SystemMonitorService` 数据格式化正确性
- `AppSettings` 读写一致性
- `NetworkHistoryManager` 数据点数量上限
- 内存计算边界情况（internal < speculative）

**技术**：`XCTest` + `@testable import FloatMonitor`

**工作量**：中（首批 ~200 行测试）

---

### 5.2 多语言支持

**当前状态**：全部 UI 字符串硬编码为中文。

**建议**：最低支持英文，使用 `.xcstrings`（Xcode String Catalog）：
```
"cpu"  → zh: "CPU"   en: "CPU"
"内存" → zh: "内存"  en: "Memory"
"网络" → zh: "网络"  en: "Network"
```

**工作量**：中（~100 条字符串迁移）

---

### 5.3 MenuBarExtra 迁移

**当前状态**：`AppDelegate.swift` 167 行，手动管理 `NSStatusItem` + `NSPopover`。

**目标**：用 macOS 原生 `MenuBarExtra` 替代：
```swift
MenuBarExtra("FloatMonitor", systemImage: "cpu") {
    MenuBarView().environmentObject(monitorService)
}
.menuBarExtraStyle(.window)
```

**注意**：此迁移需要评估 `MenuBarExtra` 是否支持自定义视图替换文字（环形图标），以及是否支持 `.window` 之外的弹出样式差异。`StatusBarTextView` 的自定义 NSView 绘制能力（双行紧凑文本）是 FloatMonitor 的差异化功能，迁移时必须保留。

**工作量**：大（需要验证可行性）

---

## 路线图总览

```
v1.1.0 ✅（已完成）
 │
 ├─ v1.2.0  质量基础设施
 │   ├─ 菜单栏宽度锁定
 │   ├─ OSLog 结构化日志
 │   └─ Constants.swift 集中常量
 │
 ├─ v1.3.0  采集引擎升级
 │   ├─ 模块化刷新间隔
 │   ├─ 优雅降级
 │   └─ 采集性能优化
 │
 ├─ v1.4.0  UI 体验提升
 │   ├─ 菜单栏指标可切换
 │   ├─ Sparkline / 方向指示
 │   ├─ 颜色语义化
 │   └─ 存储空间模块
 │
 ├─ v1.5.0  新功能模块
 │   ├─ 进程 Top 5 列表
 │   └─ 电池信息模块
 │
 ├─ v2.0.0  重大升级
 │   ├─ 计算负载环形图标
 │   ├─ 应用内更新检查
 │   └─ 多语言支持（英文）
 │
 └─ 持续
     ├─ 测试覆盖
     └─ MenuBarExtra 迁移
```

---

## 与 HagimiMonitor 的差异化定位

HagimiMonitor 是全能型系统仪表盘，FloatMonitor 应保持自己的路线：

| | HagimiMonitor | FloatMonitor 路线 |
|------|---------------|-------------------|
| 定位 | 全能仪表盘 + 显示器控制 | 轻量菜单栏监控 |
| 代码量 | 35+ 文件 | 保持 15-20 文件 |
| 菜单栏 | 环形图 + 多指标 | 紧凑双行文本（核心特色），可选环形图 |
| DDC 显示器控制 | 有 | 不跟进（超出范围） |
| 媒体键 | 有 | 不跟进 |
| 测试 | 8 个文件 | 逐步建立，覆盖核心逻辑 |

FloatMonitor 的核心优势是**极简紧凑的菜单栏体验**（37pt 双行文本），不应该因为增加功能而牺牲这一特色。

---

*计划制定：2026-06-15*
*参考：HagimiMonitor (Acerola-1/hagimi-monitor) 源码分析*

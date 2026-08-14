# HagimiMonitor 代码仓库研究报告

> 基于 [Acerola-1/hagimi-monitor](https://github.com/Acerola-1/hagimi-monitor) 源码完整阅读，与 FloatMonitor 做全面对比分析。

---

## 1. 项目概况

| 项目 | HagimiMonitor | FloatMonitor |
|------|:-------------:|:------------:|
| 作者 | Acerola-1 | szm20060312 |
| 语言 | Swift | Swift |
| UI | SwiftUI + AppKit | SwiftUI + AppKit |
| 最低系统 | macOS 26+ | macOS 27 beta |
| 构建 | Xcode 27 `.xcodeproj` | SPM `Package.swift` |
| 包管理 | Xcode Project | Swift Package Manager |
| 授权 | 未注明 | MIT |
| 代码规模 | ~35+ Swift 文件 | 10 Swift 文件 |
| 测试 | 8 个测试文件 | 无 |
| 本地化 | 中文/英文/日文 | 仅中文硬编码 |

---

## 2. 架构对比

### 2.1 应用入口

| | HagimiMonitor | FloatMonitor |
|------|---------------|--------------|
| 方式 | 纯 SwiftUI `MenuBarExtra` | `NSApplicationDelegateAdaptor` + 手动 `NSStatusItem` |
| 菜单栏 | `.menuBarExtraStyle(.window)` 原生 API | `AppDelegate` 中手动 `setupStatusBar()` |
| 弹出面板 | SwiftUI 自动管理窗口 | `NSPopover` + `NSHostingController` 桥接 |
| 桌面窗口 | 共用 `MonitorPanelView` | 独立 `ContentView` 含所有逻辑 |
| 数据 Store | `@StateObject` 非单例 | `SystemMonitorService.shared` 全局单例 |

**HagimiMonitor 优势**：`MenuBarExtra` 是 macOS 26+ 原生 SwiftUI API，省去整个 AppDelegate 的样板代码。FloatMonitor 当前需要手动管理 `NSStatusItem`、`NSPopover`、`NSHostingController`、Combine 订阅等大量胶水代码（[AppDelegate.swift](../Sources/FloatMonitor/App/AppDelegate.swift) 167 行）。

**FloatMonitor 劣势**：全局单例 `SystemMonitorService.shared` 不利于测试和依赖注入，任何需要 mock 数据的场景都受限。

### 2.2 数据采集

| | HagimiMonitor | FloatMonitor |
|------|---------------|--------------|
| 架构 | 协议驱动 `MonitorSampler`，每种指标独立实现 | 单一 `SystemMonitorService` 集中采集 |
| 刷新策略 | `MonitorRefreshSchedule` — 每种模块独立间隔（CPU 1s，GPU 2s，电池 5s，存储 10s） | 统一 `Timer`，所有指标相同频率 |
| 错误处理 | `SamplingError` 枚举 + 部分失败返回 | 静默返回 0 |
| 内存管理 | `autoreleasepool` 包裹 | 无 |
| 并行 | `DispatchGroup` 并行采集进程数据 | 同步顺序执行 |

**HagimiMonitor 的模块化刷新设计**：
```
MonitorRefreshSchedule:
  CPU/网络 → 1s
  GPU/电源  → 2s
  内存      → 3s
  电池      → 5s
  存储      → 10s
```

**FloatMonitor 当前**：所有模块以统一 `refreshInterval`（默认 1s）采集全部数据，存储/电池等低频需求指标浪费 CPU。

### 2.3 数据模型

| | HagimiMonitor | FloatMonitor |
|------|---------------|--------------|
| 模型 | `MonitorModule`（含 kind, value, summary, metrics, samples, pressure, context） | `SystemStats`（扁平的 8 个字段） |
| 模块化 | 每个 module 独立封装 sparkline 样本历史 | `cpuPerCore` 数组，network 依赖外部 `NetworkHistoryManager` |
| 进程 | `TopCPUProcess` / `TopMemoryProcess` 等，含 responsible-pid 分组 | 无 |

**HagimiMonitor 的 `MonitorModule`** 是自包含的：每个模块携带自己的 sparkline 样本数组 `samples: [Double]`，可以在面板内渲染迷你趋势图而不需要外部历史管理器。FloatMonitor 的网络图表依赖独立的 `NetworkHistoryManager`（[NetworkHistory.swift](../Sources/FloatMonitor/Models/NetworkHistory.swift)），其他模块没有历史记录。

### 2.4 进程监控

HagimiMonitor 实现了完整的进程级监控系统，FloatMonitor 完全没有。

**两层架构**：
1. **Raw 层**（后台线程安全）：纯系统调用获取原始数据
   - CPU：`ps -Aceo pid,pcpu,comm -r`
   - 内存：`proc_listallpids` + `proc_pid_rusage`（`ri_phys_footprint`）
   - 磁盘：`proc_pid_rusage`（`ri_diskio_bytesread/written`）
   - 网络：`nettop` CSV 解析
2. **Enriched 层**（主线程）：`NSRunningApplication` 获取名称和图标

**关键技巧**：
- `responsibility_get_pid_responsible_for_pid`（私有 libsystem API）按宿主应用对子进程分组 — 与活动监视器相同的分组逻辑
- 针对 Safari WebContent 等系统路径下的进程白名单
- 16×16pt 预缩放图标缓存

### 2.5 UI 渲染

| | HagimiMonitor | FloatMonitor |
|------|---------------|--------------|
| 玻璃效果 | `GlassEffectContainer` + `.glassEffect()` + `TransparentWindowBackground`（NSViewRepresentable 穿透） | v1.1.0 已移除，使用 macOS 原生外观 |
| 主题 | `MonitorPalette`：balanced/vibrant × light/dark = 4 套配色 | 硬编码系统颜色 |
| 颜色 | 语义方法：`moduleTint(for:)`、`severityTint(for:)`、`rowGlassTint(for:)` | 直接使用 `.blue` / `.purple` / `.pink` 等 |
| 性能优化 | `ThemeCache`（@MainActor 4 条目缓存）+ `Equatable` View | 无 |
| 面板行 | 可展开/折叠 `MetricGlassRow`，含 sparkline 迷你图 | 静态 `VStack` 卡片 |

**HagimiMonitor 的 ThemeCache**：
```swift
@MainActor private var themeCache: [ThemeKey: MonitorPanelTheme] = [:]
// 在每秒采样刷新时避免重建颜色树
// 4 个缓存条目覆盖当前主题 × 配色方案组合
```

这是一个小而精的优化：SwiftUI 每次 `body` 重新计算时都会重建整个视图树，包括 `Color` 值。对每秒刷新的监控应用，缓存主题对象可显著减少不必要的分配。

### 2.6 菜单栏渲染

| | HagimiMonitor | FloatMonitor |
|------|---------------|--------------|
| 方式 | 纯 SwiftUI `Image` / `Text` | 自定义 `StatusBarTextView: NSView` + `.draw()` |
| 环形图标 | `NSCache` 缓存 840 帧，量化 101 个负载级别 | 无，仅文字 |
| 显示模式 | `.ring` 环形图 / `.metrics` 多指标文本 | 紧凑双行 / 纯文字 / 图标+文字 |
| 防抖动 | 占位符宽度锁定（`" %3d%%"` 固定宽度） | 等宽字体（`monospacedDigit`） |
| 可选指标 | CPU/GPU/内存/电池/网络/温度/存储 可切换 | 仅 CPU + 内存 |

**HagimiMonitor 的环形图标系统**：
- `MenuBarComputeRingIcon` 使用 `NSCache<NSString, NSImage>` 缓存渲染帧
- 负载级别量化到 101 个桶（0-100），使 1/30s 的平滑帧几乎总是缓存命中
- `ComputeLoadModel.softmaxAggregate(k=0.08)` 将 CPU + GPU + 内存压力聚合成统一负载值
- ease-out 平滑：负载稳定时定时器自动停止，零开销

**FloatMonitor 的防抖动**：使用等宽数字字体防止数值变化时宽度跳动。HagimiMonitor 更进一步：预先计算最大可能字符串宽度（如 `"100%"`），分配固定占位符空间。

### 2.7 设置管理

| | HagimiMonitor | FloatMonitor |
|------|---------------|--------------|
| 键管理 | 集中式 `Keys` 枚举 | 分散在各属性 `didSet` 中 |
| 绑定方式 | Combine `setupBindings()` + `dropFirst()` | 属性 `didSet {}` 观察器 |
| 持久化层 | UserDefaults | UserDefaults |
| 登录项 | `SMAppService.mainApp` | `SMAppService.mainApp` |
| 模块可见性 | 可配置哪些模块显示 | 无 |
| 每模块指标 | 可配置每模块显示哪些具体指标 | 无 |
| 指标迁移 | `migrateMetrics()` 兼容旧版本键名 | 无 |

**HagimiMonitor 的设置更丰富**：
- 主题选择（balanced/vibrant）
- 配色方案（随系统/强制浅色/深色）
- 菜单栏显示模式（ring/metrics）
- 菜单栏指标选择（最多 4 个，拖放排序）
- 可见模块切换
- 显示器控制（DDC/CI）
- 媒体键捕获

**FloatMonitor 的设置**：刷新间隔、菜单栏模式、网络单位、开机启动、窗口置顶 — 共 5 项。

### 2.8 日志与诊断

| | HagimiMonitor | FloatMonitor |
|------|---------------|--------------|
| 日志 | `OSLog` 结构化日志（4 个 category） | `print()` |
| 搜索 | Console.app 可搜索 | 无 |
| 应用内日志 | `AppLogStore` 环形缓冲区 + 诊断导出 | 无 |
| 性能 | `os_log` 延迟序列化，几乎零成本 | `print()` 阻塞格式化 |

**HagimiMonitor 的日志分类**：
```swift
Logger(subsystem: "com.acerola.hagimi-monitor", category: "sampler")
Logger(subsystem: "com.acerola.hagimi-monitor", category: "ui")
Logger(subsystem: "com.acerola.hagimi-monitor", category: "settings")
Logger(subsystem: "com.acerola.hagimi-monitor", category: "diagnostics")
```

用 Console.app 可以按子系统和分类过滤，特别是在调试采样问题时极其有用。

### 2.9 更新检查

HagimiMonitor 实现了完整的应用内更新检查器（[UpdateChecker.swift](https://github.com/Acerola-1/hagimi-monitor/blob/main/HagimiMonitor/UpdateChecker.swift)）：
- `@MainActor @Observable` 类
- 查询 GitHub Releases API
- 语义化版本比较（去除 `v`/`V` 前缀，按 `.` 分段比较）
- 状态机：`.idle` → `.checking` → `.updateAvailable(downloadURL:)` / `.upToDate` / `.failed(String)`
- 错误处理：速率限制（403/429）、无发布（404）、GitHub 宕机（5xx）
- 依赖注入设计（`DataLoader` 闭包可 mock 用于测试）

FloatMonitor 无此功能。

### 2.10 统计系统

HagimiMonitor 有长期统计采集系统：
- 持续记录采样数据
- 健康评分
- 事件检测：内存压力变化、CPU 持续高负载（>85%，持续 5 分钟，带去重）、电池过热（>40°C）、电源类型切换、热状态变化
- 事件时间线查询（范围扩展至一年）

FloatMonitor 只有 120 个网络数据点用于图表，无长期统计。

### 2.11 外部显示器控制

HagimiMonitor 的 `HagimiMonitorDirectOnly/` 子模块通过 DDC/CI 协议控制外部显示器：
- `DisplayDDCBridge` — 亮度/音量/对比度
- `DisplayClassifier` — 显示器型号识别
- `DisplayChangeObserver` — 热插拔检测
- `MediaKeyController` — 媒体键映射
- `AccessibilityPermissionService` — 辅助功能权限

FloatMonitor 无此功能，也非核心需求。

### 2.12 本地化

HagimiMonitor 使用 `Localizable.xcstrings`（Xcode 15+ String Catalog 格式）：
- 源语言：中文（简体）
- 完整翻译：英文、日文
- ~200+ 条目，覆盖全部 UI 标签、指标名称、菜单项、设置描述、事件类型、错误消息
- 结构化键名（如 `"kind.cpu"`、`"metric.cpu.system"`、`"color-scheme.balanced"`）

FloatMonitor 所有字符串硬编码为中文，无本地化基础设施。

---

## 3. 代码质量与工程实践

### 3.1 测试

HagimiMonitor 有 8 个测试文件覆盖核心逻辑：
- `StatisticsTests` — 统计数据正确性
- `SettingsTests` — 设置持久化
- `UpdateCheckerTests` — 版本比较、API 解析
- `DDCFaultRegistryTests` / `DDCRawConversionTests` — 显示器协议
- `MenuBarComputeRingIconCacheTests` — 缓存逻辑
- `AppDiagnosticsTests` — 诊断功能

FloatMonitor 无任何测试。

### 3.2 文档

HagimiMonitor 有：
- 中英文双 README
- `RELEASE_NOTES.md` 详细记录每个版本的变更
- `docs/SwiftUI_MenuBar_Reference.md` — 开发参考文档

FloatMonitor 有完整的中文文档体系（`docs/` + `CLAUDE.md`），覆盖需求/技术/设计/实施四个维度。

### 3.3 构建系统

HagimiMonitor 使用 `.xcodeproj`（Xcode 原生项目），依赖 Xcode IDE 管理构建配置。

FloatMonitor 使用 `Package.swift`（SPM），可在 CLI 下独立编译，更灵活。`scripts/build_app.sh` 自动打包 `.app`。

---

## 4. 架构哲学差异

| | HagimiMonitor | FloatMonitor |
|------|---------------|--------------|
| **设计目标** | 全能系统仪表盘（监控 + 控制 + 诊断） | 轻量菜单栏系统信息显示 |
| **代码规模** | 大而全，35+ 文件，覆盖 7 个模块 | 小而精，10 文件，专注核心指标 |
| **复杂度管控** | 协议抽象 + 状态机 + 缓存层 | 直接实现，最简路径 |
| **依赖方向** | 单向依赖 + 依赖注入 + 可测试 | 全局单例 + 环境对象 |
| **用户群体** | 进阶用户/开发者 | 一般 Mac 用户 |

HagimiMonitor 追求**功能全面性和工程严谨性**：模块化采样器架构、状态机驱动的采样调度、性能优化的渲染缓存、完整的测试覆盖。代价是代码量大、学习曲线陡峭。

FloatMonitor 追求**简洁实用**：最少的文件、最简单的数据流、直接的实现方式。代价是扩展性有限、缺少测试和错误处理。

---

## 5. 对 FloatMonitor 的建议

### 5.1 立即可采用（低成本高收益）

| 改进 | 来源 | 工作量 |
|------|------|:--:|
| **菜单栏宽度锁定** | HagimiMonitor 的占位符宽度模式 | 小 |
| **OSLog 替代 print()** | `Logger(subsystem:category:)` 结构化日志 | 小 |
| **Constants.swift 集中常量** | 集中管理阈值/尺寸/动画参数 | 小 |
| **UserDefaults Key 枚举集中** | HagimiMonitor 的 `Keys` 枚举模式 | 小 |

### 5.2 中期值得投入

| 改进 | 来源 | 工作量 |
|------|------|:--:|
| **模块化刷新间隔** | HagimiMonitor 的 `MonitorRefreshSchedule` | 中 |
| **优雅降级（部分失败）** | `SamplingError` + 部分成功返回 | 中 |
| **调色板/主题系统** | `MonitorPalette` 语义颜色方法 | 中 |
| **菜单栏指标可切换** | `MenuBarMetricKind` + 最多 N 个可选 | 中 |
| **Sparkline 迷你图** | 每个模块内嵌最近 N 点的趋势图 | 中 |
| **进程 Top 列表** | 使用 `proc_pid_rusage` 获取 Top 5 | 中 |

### 5.3 长期愿景

| 改进 | 来源 | 工作量 |
|------|------|:--:|
| **SwiftUI MenuBarExtra 迁移** | 抛弃 AppDelegate 样板代码 | 大 |
| **计算负载环形图标** | `MenuBarComputeRingIcon` + Softmax 聚合 | 大 |
| **长期统计 + 健康评分** | `StatisticsRecorder` + 事件检测 | 大 |
| **应用内自动更新** | GitHub Releases API 检查器 | 中 |
| **多语言支持 (.xcstrings)** | String Catalog 本地化 | 中 |
| **单元测试基础设施** | 覆盖数据采集和核心逻辑 | 中 |

---

## 6. 技术亮点详解

### 6.1 Softmax 计算负载聚合

HagimiMonitor 的 `ComputeLoadModel` 不使用简单的 `max()` 或 `average()`，而是用 softmax（k=0.08）在瓶颈偏差和均值偏差之间平滑过渡：

```
combinedLoad = Σ(load_i × softmax_weight(load_i))
```

- 当某个组件负载远高于其他时（瓶颈），softmax 偏向最大值 — 反映实际瓶颈
- 当所有组件负载接近时，softmax 趋向均值 — 反映整体压力
- 参数 k=0.08 控制偏差敏感度

这比 `平均 CPU + GPU + MEM 压力` 的简单算法更能反映真实系统负载感受。

### 6.2 菜单栏环形图标缓存

```swift
NSCache<NSString, NSImage> // 最大 840 条目
键 = "loadLevel_colorScheme_darkMode"
loadBucket = Int(load * 100) // 量化到 101 个桶
```

- 101 个负载桶 × 2 个配色方案 × 2 个深浅模式 = 最多 404 个不同帧
- 平滑动画帧几乎总是命中缓存（仅负载变化时重新渲染）
- `NSCache` 自动在内存压力下逐出（macOS 管理）

### 6.3 部分失败降级

```swift
func sample(kinds: [MonitorKind], previousModules: [MonitorModule])
    -> (modules: [MonitorModule], errors: [SamplingError])
```

如果某个采样器失败（例如 IOKit 超时），它返回该模块的占位数据 + 错误信息，而不影响其他模块。这种设计防止一个模块的故障瘫痪整个监控面板。

### 6.4 占位符宽度锁定

```swift
func reservedValue() -> String {
    switch self {
    case .cpuUsage: return "100%"
    case .memoryUsage: return "100%"
    case .networkDownload: return "9.9G"
    case .temperature: return "999°"
    }
}
```

预先计算每种指标的最大字符串宽度，用 `NSString.size(withAttributes:)` 测量，确保值从 "12%" 变为 "100%" 时菜单栏图标位置不变。

---

## 7. 总结

HagimiMonitor 是一个工程化水平很高的 macOS 系统监控应用，其在架构设计、性能优化、用户体验细节、测试覆盖等方面的实践值得 FloatMonitor 认真学习。

核心差距不在于功能数量，而在于**架构的可扩展性**和**工程严谨度**：
- 协议驱动的采样器设计使添加新指标非常容易
- 模块化刷新计划减少不必要的 CPU 消耗
- 错误处理范式防止单个模块故障扩散
- 渲染缓存和 Equatable 优化确保高频刷新的流畅性

建议 FloatMonitor 按照「低复杂度高收益 → 中复杂度 → 长期愿景」的路径渐进式采用这些改进，同时保持自身简洁实用的设计哲学。

---

*文档日期：2026-06-15*
*分析基于：HagimiMonitor (Acerola-1/hagimi-monitor) 主分支源码*

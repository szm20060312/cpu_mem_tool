# 技术规范

## 技术栈

| 层面 | 选型 | 版本要求 |
|------|------|----------|
| 语言 | Swift | 5.10+ |
| UI 框架 | SwiftUI | macOS 26 原生 |
| IDE | Xcode | 26.5 |
| 目标系统 | macOS | 26 (Tahoe) |
| 包管理 | Swift Package Manager | 内置 |

## 系统框架依赖

| 框架 | 用途 | 关键 API |
|------|------|----------|
| `Host.framework` | CPU/内存统计 | `host_processor_info()`, `host_statistics64()` |
| `IOKit` | 温度/GPU 数据 | `IOServiceGetMatchingServices`, SMC 通信 |
| `Network.framework` | 网络监控 | `NWPathMonitor` + `sysctl` 获取接口字节数 |
| `SwiftUI` | UI 层 | `@ObservableObject`, Swift Charts |
| `AppKit` | 菜单栏集成 | `NSStatusBar`, `NSPopover`, `NSHostingView` |
| `Swift Charts` | 历史图表 | `Chart`, `LineMark` |
| `ServiceManagement` | 开机启动 | `SMAppService` |

## 架构设计

```
┌─────────────────────────────────────┐
│               App 入口               │
│         FloatMonitorApp.swift        │
│     (WindowGroup + MenuBarExtra)     │
└──────────┬──────────────┬────────────┘
           │              │
     ┌─────▼─────┐  ┌─────▼─────┐
     │  MenuBar  │  │  Window   │
     │  View     │  │  View     │
     │ (Popover) │  │ (Window)  │
     └─────┬─────┘  └─────┬─────┘
           │              │
     ┌─────▼──────────────▼─────┐
     │     Detail Views         │
     │  CPU / MEM / NET / TEMP  │
     │       GPU / Chart        │
     └─────────────┬────────────┘
                   │
     ┌─────────────▼────────────┐
     │  SystemMonitorService    │
     │  (ObservableObject)      │
     │  - @Published stats      │
     │  - Timer 采集            │
     └─────────────┬────────────┘
                   │
     ┌─────────────▼────────────┐
     │   System Data Sources    │
     │  IOKit / Host / sysctl   │
     └──────────────────────────┘
```

## 数据模型

```swift
struct SystemStats {
    var cpuUsage: Double              // 0-100 整体使用率
    var cpuPerCore: [Double]          // 每核使用率
    var memoryTotal: UInt64           // 物理内存总量
    var memoryUsed: UInt64            // 已用内存
    var memoryPressure: MemoryPressure // 内存压力级别
    var gpuUsage: Double?             // GPU 使用率 0-100
    var networkDownload: UInt64       // 下载速率 bytes/s
    var networkUpload: UInt64         // 上传速率 bytes/s
}

enum MemoryPressure {
    case normal, warning, critical
}
```

## 关键实现要点

### CPU 使用率计算
```
usage = 1.0 - (idleTicks / totalTicks)
```
通过 `host_processor_info()` 获取两次快照，计算差值得到使用率。

### 内存压力
macOS 使用内存压力而非简单的"已用/总量"：
- `VM_PAGE_FREE()` / `VM_PAGE_ACTIVE()` 等宏计算
- 通过 `host_statistics64()` 和 `vm_statistics64` 获取

### 温度监控（已移除）
- v1.0.0 中尝试通过 SMC / IORegistry / PMU 读取温度，Apple Silicon（M 系列）因安全限制无法访问
- v1.1.0 温度相关代码已完全移除，后续可通过 `sudo powermetrics` 方案获取

### 网络速率
- 首次获取各接口字节数作为基准
- 每次采集中计算 `(currentBytes - previousBytes) / interval`
- 使用 `sysctl` 获取 `net.inet.tcp.stats` 和各接口 MIB

### GPU 使用率
- 通过 IOKit 匹配 `IOAccelerator` 服务
- 读取 `PerformanceStatistics` 属性字典
- 计算 `(activeTime / totalTime) * 100`

## 版本历史

### v1.1.0
- 移除自定义液态玻璃效果，采用 macOS 原生外观
- 重构：提取共享 UI 组件到 `Utils/ViewHelpers.swift`
- 修复：UserDefaults key 命名空间化，防止日积月累的泄漏
- 修复：`@MainActor` 迁移提升 Swift 6 并发安全性
- 修复：内存计算溢出保护

### v1.0.0
- 初始发布，全部 10 个实施步骤完成

## 性能要求
- 监控服务刷新间隔默认 1s，最低 0.5s
- 监控服务自身 CPU 占用 < 2%（Release 构建）
- 内存占用 < 50MB
- 数据采集异步执行，不阻塞主线程

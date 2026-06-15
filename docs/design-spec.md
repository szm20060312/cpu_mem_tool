# 设计规范

## 设计语言：macOS 原生外观

v1.1.0 起，FloatMonitor 采用 macOS 原生窗口外观，不再手动模拟玻璃效果。窗口和面板使用系统默认材质，自动适配浅色/深色模式。

## 色彩系统

### 主色调
由于监控数据需要清晰易读，采用系统原生语义色：

| 用途 | 浅色模式 | 深色模式 |
|------|----------|----------|
| 面板背景 | 系统默认 | 系统默认 |
| 文字主色 | `.primary` | `.primary` |
| 文字次色 | `.secondary` | `.secondary` |
| CPU 色 | `blue` | `blue` |
| 内存色 | `green` | `green` |
| 温度色 | `orange`(热) / `teal`(凉) | 同浅色 |
| 网络色 | `purple` | `purple` |
| GPU 色 | `pink` | `pink` |
| 警告色 | `systemYellow` / `systemRed` | 同浅色 |

### 数值颜色映射
- CPU > 80%：红色警告
- 内存压力 critical：红色
- 温度 > 90°C：红色
- 温度 > 70°C：黄色

## 字体排版

| 层级 | 字体 | 大小 | 用途 |
|------|------|------|------|
| 标题 | SF Pro Display Semibold | 18pt | 面板标题、模块标题 |
| 数值 | SF Pro Display Bold | 28pt | 主要百分比数值 |
| 副标题 | SF Pro Text Semibold | 13pt | 模块标签 |
| 正文 | SF Pro Text Regular | 12pt | 详细数据说明 |
| 菜单栏 | SF Pro Text Medium | 11pt | 菜单栏文本显示 |

## 图标系统
使用 **SF Symbols 6**（macOS 26 新增符号）：

| 模块 | 图标 |
|------|------|
| CPU | `cpu` |
| 内存 | `memorychip` |
| 温度 | `thermometer.medium` |
| 网络下载 | `arrow.down.circle` |
| 网络上传 | `arrow.up.circle` |
| GPU | `display` |
| 设置 | `gearshape` |
| 图表 | `chart.xyaxis.line` |
| 窗口 | `macwindow` |

## 布局规范

### 弹出面板 (Popover)
- 宽度：320pt（固定）
- 高度：自适应，约 400-500pt
- 内边距：16pt
- 模块间距：12pt
- 圆角：16pt

### 桌面窗口
- 默认尺寸：480×600pt
- 最小尺寸：400×400pt
- 内边距：20pt
- 模块间距：16pt

### 菜单栏
- 高度：系统菜单栏高度（约 24pt）
- 文字最大宽度：120pt

## 动效规范

| 场景 | 动画 | 时长 |
|------|------|------|
| 数值变化 | `.animation(.smooth, value: stat)` | 默认 |
| 面板出现 | `.spring(response: 0.3)` | 0.3s |
| 面板消失 | `.easeIn` | 0.2s |
| Tab 切换 | `.easeInOut` | 0.25s |
| 图表更新 | `.animation(.smooth, value: data)` | 默认 |

## 窗口样式

v1.1.0 起采用 macOS 原生外观，窗口使用 `.hiddenTitleBar` 隐藏标题栏。
所有视图不再手动设置材质背景，由系统自动处理。

## 适配要求
- [x] 浅色模式
- [x] 深色模式
- [ ] 高对比度模式
- [ ] 降低透明度模式

# 燃脂心率 — Apple Watch 爬坡减脂心率监测 App

根据实时心率判断是否处于最佳燃脂区间（最大心率 × 60%~70%），通过触觉通知指导用户调整爬坡强度。

## 项目结构

```
FatBurnZone/
├── project.yml              # XcodeGen 项目描述文件
├── WatchApp/                # watchOS 独立 App
│   ├── FatBurnZoneApp.swift     # App 入口
│   ├── Info.plist               # 权限 & 后台模式配置
│   ├── FatBurnZone.entitlements # HealthKit 授权
│   ├── Models/
│   │   ├── HeartRateZone.swift      # 区间状态枚举 & 数据模型
│   │   └── UserProfile.swift        # 用户年龄 & 资料
│   ├── Services/
│   │   ├── HealthKitService.swift   # HealthKit 交互（授权/HR 流/锻炼）
│   │   ├── HeartRateZoneCalculator.swift  # 燃脂区间计算
│   │   └── NotificationService.swift      # 触觉通知 & 防抖
│   ├── ViewModels/
│   │   └── WorkoutViewModel.swift   # 核心状态管理
│   └── Views/
│       ├── ContentView.swift        # 根路由
│       ├── SetupView.swift          # 年龄设置
│       ├── WorkoutView.swift        # 锻炼主界面
│       └── ZoneGaugeView.swift      # 弧形仪表盘
├── iOSApp/                  # iOS 配套 App（可选）
│   ├── iOSApp.swift
│   ├── SettingsView.swift
│   └── Info.plist
└── Shared/
    └── Constants.swift       # 全局常量
```

## 功能

- **实时心率监测**：通过 HealthKit `HKWorkoutSession` 获取后台持续心率数据
- **年龄自动获取**：优先从 HealthKit 读取出生日期，失败后支持手动输入
- **燃脂区间计算**：`220 - 年龄` 得到最大心率，`× 60%~70%` 得到最佳燃脂区间
- **智能通知**：
  - 心率偏高 → 触觉反馈 + "建议降低坡度或速度"
  - 心率偏低 → 触觉反馈 + "建议增大坡度或速度"
  - 防抖机制：连续 5 秒异常才触发，两次通知间隔 ≥ 30 秒
- **可视化表盘**：弧形仪表盘显示燃脂区间（绿色高亮）和当前心率位置

## 快速开始

### 前置条件

- macOS + Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（可选，用于生成 .xcodeproj）

### 方式 1：使用 XcodeGen 生成项目

```bash
# 安装 XcodeGen（如果没有）
brew install xcodegen

# 生成 Xcode 项目
cd FatBurnZone
xcodegen generate

# 打开项目
open FatBurnZone.xcodeproj
```

### 方式 2：手动创建 Xcode 项目

1. 打开 Xcode → New Project → watchOS → App
2. 选择 SwiftUI + Swift
3. 将 `WatchApp/`、`Shared/` 目录下的文件拖入项目
4. 在 Target → Info 中配置 HealthKit 权限
5. 在 Target → Signing & Capabilities 中添加 HealthKit

### 运行

1. 选择 `WatchApp` scheme
2. 目标设备选择 Apple Watch 模拟器或真机
3. ⌘R 运行

## 注意事项

- **HealthKit 授权**：首次启动会请求心率读取 + 出生日期权限
- **后台心率**：需要开启锻炼会话才会持续获取心率（`HKWorkoutSession`）
- **真机测试**：需要 Apple Developer 账号配置签名
- **模拟器**：HealthKit 模拟器可注入假心率数据用于开发测试

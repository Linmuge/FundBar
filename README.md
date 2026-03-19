# FundBar - macOS 菜单栏基金估值工具

一款轻量级 macOS 菜单栏应用，实时展示自选基金的估算净值与涨跌幅，让你在工作时随时掌握基金动态。

## 功能特性

- **菜单栏常驻** - 一键点击即可查看所有自选基金估值，不干扰日常工作
- **实时估值** - 接入天天基金 API，获取盘中实时估算净值和涨跌幅
- **自动刷新** - 每 30 秒自动更新数据，交易时间绿点指示器提示盘中状态
- **总收益率** - 汇总展示所有自选基金的平均涨跌幅
- **自选管理** - 输入 6 位基金代码即可添加，右键移除，数据本地持久化
- **涨跌配色** - 红涨绿跌，直观清晰

## 技术栈

| 项目 | 说明 |
|------|------|
| 语言 | Swift |
| 框架 | SwiftUI (MenuBarExtra) |
| 架构 | MVVM |
| 最低系统 | macOS 14.0 |
| 数据源 | 天天基金 JSONP API |
| 存储 | UserDefaults |

## 项目结构

```
FundBar/
├── FundBarApp.swift          # App 入口，MenuBarExtra 配置
├── Models/
│   └── Fund.swift            # 基金数据模型
├── ViewModels/
│   └── FundViewModel.swift   # 数据管理、自动刷新、持久化
├── Views/
│   ├── ContentView.swift     # 主面板（列表 + 汇总 + 底栏）
│   ├── FundRowView.swift     # 单只基金行视图
│   └── AddFundView.swift     # 添加基金输入视图
├── Services/
│   └── FundService.swift     # 网络请求 & JSONP 解析
└── Assets.xcassets/          # 资源文件
```

## 使用方法

1. 使用 Xcode 打开 `FundBar.xcodeproj`
2. 选择 **My Mac** 作为运行目标
3. `Cmd + R` 运行
4. 菜单栏出现图表图标，点击展开面板
5. 点击 **+** 按钮，输入 6 位基金代码添加自选

## 构建要求

- Xcode 15.0+
- macOS 14.0+

## 许可证

MIT License

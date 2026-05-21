# EfficientTime Agent Guide

## 项目定位

EfficientTime 是一个本地单机 macOS 日程执行助手。第一版聚焦严格时间表、菜单栏常驻、桌面悬浮窗、系统通知、本地排程和 AI 规划接口预留。

不要把它扩展成通用项目管理系统、云同步 Todo、多人协作平台或完整日历替代品。

## 语言与文档

- 面向用户和协作者的文档默认使用中文。
- Swift 类型、函数、配置 key、CLI 参数使用英文。
- 不要把 API key、私人计划、账户信息或本地路径写入文档或测试夹具。

## 模块边界

- `Sources/EfficientTimeCore/Domain`：纯领域模型，不依赖 SwiftUI/AppKit。
- `Sources/EfficientTimeCore/Scheduling`：确定性本地排程和校验逻辑。
- `Sources/EfficientTimeCore/AI`：AI 规划协议、上下文裁剪、DeepSeek 预留实现。
- `Sources/EfficientTimeApp/Views`：主窗口 SwiftUI 视图。
- `Sources/EfficientTimeApp/MenuBar`：菜单栏入口。
- `Sources/EfficientTimeApp/FloatingPanel`：桌面常驻悬浮窗。
- `Sources/EfficientTimeApp/Notifications`：macOS 通知。
- `Sources/EfficientTimeApp/Persistence`：本地持久化。

## AI 边界

AI 只能生成草稿，不允许直接覆盖正式 `DayPlan`。

流程必须保持：

```text
User Input -> Context Packer -> AI Draft -> Local Validation -> User Confirmation -> DayPlan
```

默认不要把完整历史、财务细节、账户信息、私密备注或本地文件内容发送给模型。任务应支持 `Private`、`Anonymized`、`AI Visible` 三种隐私级别。

## 验证要求

改动核心模型、排程、AI 上下文打包时，至少运行：

```bash
swift test
```

改动 App 层时，至少运行：

```bash
swift build
```


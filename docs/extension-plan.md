# EfficientTime Extension 能力规划

调研日期：2026-05-20

## 规划结论

EfficientTime 最值得优先做的不是“很多插件”，而是几个能降低日程执行摩擦的系统入口：

1. `App Intents / Shortcuts`：让用户可以用快捷指令、Siri 或自动化触发“添加任务草稿、开始计划、完成当前任务、跳过当前任务、延长当前任务”。
2. `Notification Actions`：在系统通知上直接完成、跳过、延长、稍后提醒，减少打开主窗口的次数。
3. `URL Scheme / Deep Link`：作为所有外部入口的底座，先把外部命令路由打通。
4. `WidgetKit`：适合做“当前任务 / 下一个任务 / 今日进度”的只读 glance，不适合作为秒级倒计时主界面。
5. `Share / Action Extension`：适合从网页、邮件、备忘录、选中文本里快速捕获任务草稿，但应晚于 App Intents。
6. `MCP / Raycast / CLI`：适合 power user 和 AI 助手本地集成，价值高，但不应影响第一版普通用户路径。

不建议第一阶段做 Safari 网站阻断、Network/System Extension、Finder Sync、File Provider、完整外部日历双向同步。这些会把产品从“日程执行助手”拉向浏览器管控、文件同步、企业管控或完整 calendar 生态。

## 参考依据

上一轮竞品调研里有几个稳定结论：

- `Chunk` 验证了菜单栏、浮窗、倒计时、本地优先和本地 MCP 的方向。
- `Turtl` 验证了菜单栏自然语言捕获任务的低摩擦价值。
- `Timdo` 验证了全局热键、浮动计时器和执行日志的重要性。
- `Structured` / `Ellie` 验证了 inbox、rollover、daily timeline 的日计划体验。
- `Morgen` / `Reclaim` 验证了 AI 草稿、用户确认、buffer、偏好时段、习惯规则的价值。

Apple 官方能力边界：

- [App Intents](https://developer.apple.com/documentation/AppIntents/app-intents) 用于把 app action 暴露给 Shortcuts、Siri 等系统体验。
- [App and system extensions](https://developer.apple.com/documentation/technologyoverviews/app-extensions) 说明 app extension 是独立 bundle，可由系统独立启动；如果要共享数据，应使用 App Group。
- [WidgetKit](https://developer.apple.com/documentation/widgetkit) 可在 Mac 等平台提供系统 widget。
- [Safari web extensions](https://developer.apple.com/documentation/SafariServices/safari-web-extensions) 用 JS/HTML/CSS 扩展 Safari，并作为 app extension 随 Mac app 分发。

## 候选 Extension Type 分析

### 1. App Intents / Shortcuts

建议：优先做。

适合 EfficientTime 的动作：

- `AddTaskDraftIntent`：添加一个待安排任务草稿。
- `PlanFromTextIntent`：输入自然语言，生成 `PlanDraft`，但不直接写入 `DayPlan`。
- `StartTodayPlanIntent`：开始今天计划。
- `CompleteCurrentBlockIntent`：完成当前时间块。
- `SkipCurrentBlockIntent`：跳过当前时间块。
- `ExtendCurrentBlockIntent`：延长当前任务 5 / 10 / 15 / 30 分钟。
- `OpenCurrentPlanIntent`：打开今日计划或悬浮窗。

可吸取的优点：

- 借鉴 Turtl 的“一句话捕获任务”，但输出进入本地草稿池。
- 借鉴 Timdo 的键盘和自动化友好体验。
- 借鉴 Morgen 的“AI 结果必须 preview + confirm”原则。

产品价值：

- 很适合 macOS power user。
- 能被 Shortcuts、Siri、自动化、Focus 模式、键盘快捷流串起来。
- 是后续 Widget 交互、Raycast、AI 本地助手的共同动作层。

风险：

- extension 或后台 intent 访问本地计划时，需要解决数据共享和并发写入。
- 如果 intent 直接写正式计划，会破坏 AI 边界。

推荐边界：

- 允许 intent 写入 `TaskDraft`、触发运行态操作和打开 app。
- 不允许 AI intent 直接覆盖 `DayPlan`。
- 所有修改正式计划的动作都走本地 `ScheduleValidator`。

### 2. Notification Actions

建议：优先做，成本低于完整 extension。

适合的通知动作：

- 任务开始：`开始执行`、`跳过`。
- 即将结束：`延长 5 分钟`、`延长 15 分钟`、`完成`。
- 任务结束：`完成`、`推迟`、`加入重排候选`。

可吸取的优点：

- 借鉴 Chunk 的任务开始/结束提醒。
- 借鉴 Reclaim 的 snooze / log work 行为。
- 借鉴 Jamf Notifier 的 action button 和旧通知清理思路。

产品价值：

- 用户不用打开主窗口，也能保持 Run Mode 继续推进。
- 直接服务“严格时间表执行”，不扩大产品边界。

风险：

- 如果通知太多，会让用户疲劳。
- 任务被调整后，旧通知必须取消或更新，否则会产生误提醒。

推荐边界：

- v0.2 只做 3 类通知和 3 类动作：完成、跳过、延长。
- 不做复杂富通知 UI。

### 3. URL Scheme / Deep Link

建议：作为底座优先做。

候选路由：

```text
efficienttime://add-task?title=...
efficienttime://plan-from-text?text=...
efficienttime://run/complete-current
efficienttime://run/skip-current
efficienttime://run/extend-current?minutes=10
efficienttime://open/today
efficienttime://open/settings
```

可吸取的优点：

- 给 App Intents、Raycast、Share Extension、CLI 留统一入口。
- 可以先让主 app 处理命令，避免 extension 进程直接写本地 JSON。

产品价值：

- 实现成本相对低。
- 让外部触发点不必都理解 EfficientTime 的内部模型。

风险：

- URL 参数可能包含隐私信息，日志和错误提示不能泄露完整内容。
- 外部命令需要鉴权或来源限制吗？第一版可先只支持本机打开 app，不开放网络监听。

推荐边界：

- Deep link 只接收用户主动触发的本机 URL。
- 对 AI 相关路由，只创建 `PlanDraft`，不直接应用。

### 4. WidgetKit Widget

建议：第二阶段做，不能替代菜单栏和悬浮窗。

候选 widget：

- 小号：当前任务 + 剩余时间。
- 中号：当前任务、下一个任务、今日完成率。
- 大号：今日 timeline 的紧凑版。
- 交互按钮：完成、跳过、延长、打开悬浮窗。

可吸取的优点：

- 借鉴 Structured 的 timeline glance。
- 借鉴 NextUp 的当前/下一个日程提示。
- 借鉴 Chunk 的“低打扰执行态”。

产品价值：

- 桌面 glance 很符合 macOS 使用场景。
- 对不喜欢常驻浮窗的用户是一个替代入口。

风险：

- Widget 不适合作为精确秒级倒计时。
- Widget 刷新由系统调度，不能依赖它做严格提醒。
- 交互动作仍要通过 App Intents 或打开 app 完成。

推荐边界：

- Widget 只做状态展示和少量动作。
- 精确提醒继续由 `NotificationScheduler` 负责。
- 秒级反馈继续由菜单栏和悬浮窗负责。

### 5. Share / Action Extension

建议：第三阶段做，适合捕获任务，不适合排程。

典型场景：

- 在 Safari 选中网页标题或一段文字，发送到 EfficientTime，生成阅读/处理任务草稿。
- 在 Mail 里把邮件主题作为任务草稿。
- 在 Notes / Preview / Finder 的分享菜单里捕获文本或文件名。

可吸取的优点：

- 借鉴 Structured / Ellie 的 inbox 捕获模式。
- 借鉴 Turtl 的低摩擦输入，但避免强依赖 AI。

产品价值：

- 让任务进入 EfficientTime 的入口更自然。
- 与“待安排任务池”强相关。

风险：

- Share Extension 是独立进程，数据共享需要 App Group 或 deep link 转交。
- 输入来源很杂，清洗和隐私标记很重要。
- 容易把 EfficientTime 拉成通用稍后读 / Todo inbox。

推荐边界：

- 只创建 `TaskDraft`，不自动安排时间。
- 默认隐私级别为 `Private` 或 `Anonymized`，用户确认后才变成 `AI Visible`。
- 不接收文件内容，只接收标题、URL、选中文本摘要。

### 6. Safari Web Extension

建议：暂缓。

可能功能：

- 把当前网页加入今天的阅读任务。
- 在 Focus Mode 下对指定网站显示提醒或轻量阻断。
- 从网页选中文字生成任务草稿。

可吸取的优点：

- Timdo 的阻断分心方向有一定价值。
- Turtl 的浏览场景自然语言任务捕获也有价值。

不优先的原因：

- Safari extension 权限敏感，会削弱本地隐私定位。
- 网页阻断会把 EfficientTime 推向 focus blocker 产品。
- 浏览器扩展需要额外前端、权限文案和分发测试。

推荐边界：

- 如果未来做，只做“捕获当前网页为任务草稿”。
- 不做浏览历史读取，不做默认网站阻断，不做跨浏览器同步。

### 7. Local MCP / CLI / Raycast Extension

建议：后续做，适合高级用户。

候选能力：

- `efficienttimectl add-task "写报告" --estimate 45`
- `efficienttimectl current`
- `efficienttimectl complete`
- Raycast command：Add Task、Start Plan、Complete Current、Show Timeline。
- 本地 MCP：让本机 AI 助手读取当前计划、生成草稿、列出未完成任务。

可吸取的优点：

- Chunk 的本地 MCP 思路非常贴合 EfficientTime 的本地优先定位。
- Timdo 的全局热键和快速捕获可以用 CLI/Raycast 形态补强。

产品价值：

- 对开发者和重度 macOS 用户有吸引力。
- 给 AI 工具提供本地安全入口，比上传完整历史更可控。

风险：

- MCP 如果暴露写操作，必须严格区分 draft 和 confirmed plan。
- 本地 server 或 CLI 需要权限、路径、生命周期管理。

推荐边界：

- 先做 CLI，命令通过同一个 `ExternalCommandRouter`。
- MCP 第一版只读当前计划和创建 `PlanDraft`，不直接改 `DayPlan`。

### 8. Calendar / Reminders Integration

建议：作为 integration，不作为第一批 extension。

可能功能：

- 只读导入 Calendar busy blocks。
- 从 Reminders 导入待安排任务。
- 把 EfficientTime 的计划导出到一个专用本地 calendar。

可吸取的优点：

- Chunk 证明 Calendar / Reminders integration 对 time blocking 很有价值。
- Reminders MenuBar 和 NextUp 证明 EventKit 本地读取是可行路径。

不优先的原因：

- 双向同步很容易带来冲突、权限、重复事件和隐私问题。
- EfficientTime 第一版不是完整 Calendar 替代品。

推荐边界：

- 先只读 Calendar，生成不可编辑 busy blocks。
- Reminders 只导入标题、截止时间、备注摘要，默认 `Private`。
- 导出只写入 EfficientTime 专用 calendar，不修改用户原始日历。

## 不建议做的 Extension Type

### Finder Sync Extension

不适合。它主要服务文件同步状态、Finder badge 和上下文菜单，和日程执行助手关系弱。

### File Provider Extension

不适合。它服务云文件系统和文档提供方，会把产品拉向文件同步。

### Network Extension / System Extension

不适合第一版。它们适合 VPN、DNS、内容过滤、Endpoint Security、DriverKit 等系统级能力，权限重、审核重、风险高。

### Custom Keyboard / Photo Editing / Audio Unit

不适合。和 EfficientTime 的核心任务无关。

### Notification Content Extension

暂不建议。EfficientTime 需要的是通知动作和及时提醒，不需要复杂自定义通知 UI。

## 推荐版本规划

### v0.2.5：外部命令底座和执行控制

目标：把 Run Mode 操作外露，但不引入复杂 extension target。

功能：

- `ExternalCommandRouter`：统一处理外部命令。
- URL Scheme：打开今日计划、完成当前任务、跳过、延长。
- Notification Actions：完成、跳过、延长。
- 菜单栏继续显示当前任务和剩余时间。

验收标准：

- 通知按钮可以改变当前 block 状态，并写入 `ExecutionLog`。
- 延长当前任务后，本地校验后更新后续时间块或进入重排提示。
- 旧通知能被取消，避免过期提醒。

### v0.3：App Intents + AI Draft

目标：把 EfficientTime 接入系统自动化，但保持 AI 边界。

功能：

- `AddTaskDraftIntent`。
- `PlanFromTextIntent`。
- `StartTodayPlanIntent`。
- `CompleteCurrentBlockIntent` / `SkipCurrentBlockIntent` / `ExtendCurrentBlockIntent`。
- App Intents 调用同一个 `ExternalCommandRouter`。

验收标准：

- Shortcuts 中能找到 EfficientTime actions。
- `PlanFromTextIntent` 只能生成 `PlanDraft`，不能直接写入 `DayPlan`。
- intent 写入或读取不会绕过隐私级别。

工程前置：

- 当前项目是 Swift Package executable。真正添加 Widget/App Extension target 时，可能需要补 Xcode app project 或生成可维护的 Xcode targets。
- 如果 intent 需要后台写数据，要引入 App Group container 或改成唤起主 app 处理。

### v0.4：Widget + Rollover Glance

目标：提供桌面 glance，不替代悬浮窗。

功能：

- 当前任务 widget。
- 今日进度 widget。
- 明天待安排 / rollover widget。
- Widget action 复用 App Intents。

验收标准：

- Widget 展示和主 app 状态一致。
- Widget 不承担秒级计时准确性。
- Widget 不触发 AI 请求，除非用户显式点击并进入确认流程。

### v0.5：Capture Extension 和高级用户入口

目标：扩展任务捕获来源。

功能：

- Share / Action Extension：选中文本、URL、邮件主题进入 `TaskDraft`。
- CLI：`efficienttimectl current/add/complete/skip/extend`。
- Raycast Extension：封装 CLI 或 URL Scheme。
- 本地 MCP：只读计划和创建草稿。

验收标准：

- 外部捕获默认进入草稿池。
- 所有外部文本都带来源和隐私级别。
- MCP 不直接覆盖正式计划。

## 建议的最终取舍

如果只选一个 extension 方向，应该先选 `App Intents / Shortcuts`，因为它同时服务系统自动化、Widget 交互、Siri、快捷键工作流和未来 Apple Intelligence 风格入口。

如果只选一个“马上能提升体验”的功能，应该先做 `Notification Actions`，因为它直接解决 Run Mode 中“提醒到了之后还要打开 app 操作”的摩擦。

如果只选一个“为未来铺路”的底座，应该先做 `URL Scheme / ExternalCommandRouter`，因为它能让 App Intents、Share Extension、Raycast、CLI、MCP 都复用同一套命令语义。

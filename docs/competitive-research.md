# EfficientTime 同类产品与开源实现调研

调研日期：2026-05-19

## 结论摘要

EfficientTime 的第一版最接近的产品不是通用 Todo 或团队项目管理工具，而是“菜单栏常驻 + 当天时间块 + 执行提醒 + 轻量浮窗”的本地 macOS 工具。当前看到的产品里，`Chunk` 与 EfficientTime 的定位最接近；`TaskLine`、`Timdo`、`Turtl` 是更轻量的 macOS 单点参考；`Structured`、`Sunsama`、`Ellie`、`Morgen`、`Reclaim` 更适合借鉴计划流程、AI 草稿、时间块和重排策略。

核心判断：

- 第一版要继续坚持“本地单机、严格时间表、执行助手”，不要扩成协作型 Todo、完整日历或云项目管理。
- AI 应该做计划草稿、拆分和建议，不应直接覆盖正式 `DayPlan`。Morgen 的“预览后确认”、Structured 的“AI 创建/编辑任务”、Turtl 的“菜单栏自然语言排程”都能支持这个边界。
- 菜单栏应该不仅是入口，还要承担“当前任务 + 剩余时间”的低摩擦反馈。Chunk、TaskLine、Timdo、NextUp 都验证了这个方向。
- 悬浮窗要走 macOS 原生 `NSPanel` 路线，支持全屏应用上方显示、跨 Space、尽量不抢焦点。

## 高相似产品

### Chunk

链接：[chunkapp.net](https://www.chunkapp.net/en)

定位：macOS 菜单栏时间块规划器，强调 zero-bloat、菜单栏入口、时间块、任务拖拽、浮窗、倒计时和本地优先。

重要特性：

- 菜单栏入口和快捷键打开规划面板。
- 任务可以拖到当天时间线。
- 支持 Apple Reminders、Apple Calendar、Google Calendar、Outlook。
- 面板可以浮在其他窗口和全屏应用之上。
- 菜单栏显示当前倒计时，任务开始/结束有通知。
- 支持 day templates 和 routines，把固定日程结构自动套到工作日。
- 数据本地存储；可选本地 MCP，让 AI 助手读写本机日程。

对 EfficientTime 的借鉴：

- `Run Mode` 的菜单栏文案应该显示当前任务和剩余时间，而不只是静态图标。
- 悬浮窗要服务执行，不要成为另一个完整主窗口。默认显示“当前 + 前后若干项”的设计与 Chunk 的 flow-state 方向一致。
- 可以在 v0.3/v0.4 后引入“日模板 / routine”，例如工作日模板、周末模板、晨间模板，但它应生成本地草稿，再走校验。
- 如果未来接入 AI 或 MCP，仍保持本地服务边界：AI 可以提出草稿操作，正式计划要本地校验和用户确认。

不建议照搬：

- 第一版不做 Google/Outlook 双向同步。Chunk 的同步能力是成熟产品能力，对 EfficientTime v0.1/v0.2 会显著扩大权限、冲突处理和测试面。

### TaskLine

链接：[App Store - TaskLine](https://apps.apple.com/us/app/taskline-todo-timeline/id6755985828?mt=12)

定位：极简 macOS 菜单栏 Todo + Timeline。用户先列出今天要做的事，再拖到时间线决定什么时候做。

重要特性：

- 菜单栏常驻。
- Todo 与 Timeline 结合。
- 菜单栏显示剩余任务时间。
- 支持同一任务在一天中多次出现。
- 颜色编码。
- 聚焦“今天的任务”，不做重型日历。

对 EfficientTime 的借鉴：

- v0.2 的计划编辑可以先保留轻量表单，同时为后续拖拽式 timeline 留接口。
- “同一任务多次出现”应该在模型上支持，例如 `Task` 与多个 `TimeBlock` 分离，不把任务实体和时间块绑死。
- 当前时间块的剩余时间应该是菜单栏和悬浮窗的第一信息。

### Turtl

链接：[turtleai.dev](https://www.turtleai.dev/)

定位：菜单栏 AI 任务排程工具。用户用自然语言描述任务，AI 根据优先级和已有日历安排时间。

重要特性：

- 菜单栏打开。
- 一句话创建排程请求。
- 设置优先级，由 AI 推荐时段。
- 强调不打开重型应用、不切换上下文。

对 EfficientTime 的借鉴：

- AI Builder 的入口可以做得非常轻：在菜单栏或主窗口里输入一句话，生成 `PlanDraft`。
- AI 请求应该围绕“任务标题、耗时、优先级、可用时间段、固定约束”裁剪上下文。
- 不要让 AI 直接修改正式计划；需要先生成草稿，再本地校验，再用户确认。

### Timdo

链接：[timdo.app](https://timdo.app/)

定位：native macOS 计划、计时、阻断分心、记录进度的执行工具。

重要特性：

- 任务计时。
- 自动记录每次执行 session。
- 浮动计时器常驻屏幕。
- 键盘优先：方向键导航、空格开始、全局热键捕获任务。
- 可阻断分心网站。

对 EfficientTime 的借鉴：

- `ExecutionLog` 不只是复盘数据，也可以驱动“实际耗时 vs 计划耗时”的后续本地排程改进。
- 浮动计时器可以提供紧凑态：当前任务、剩余时间、完成/跳过/延长。
- 全局热键适合后续加入“快速捕获任务”和“显示/隐藏悬浮窗”。

不建议第一版做：

- 应用/网站阻断会涉及浏览器、网络过滤或 Accessibility 权限，不适合 EfficientTime 第一版。

## 计划流程与 AI 参考

### Structured

链接：[structured.app](https://structured.app/)，[Structured App Store](https://apps.apple.com/us/app/structured-daily-planner-todo/id1499198946)

定位：视觉化日计划，把任务、日历、routine 和提醒放进一天时间线。

重要特性：

- 打开后第一屏就是 daily timeline。
- Inbox 用于捕获还没有具体日期或时间的任务。
- 支持 recurring tasks、alerts、drag and drop、图标、颜色编码。
- AI 可以创建或编辑任务。
- Pro 功能包括日历/Reminders 接入、AI day planning、Replan missed tasks。

对 EfficientTime 的借鉴：

- EfficientTime 可以保留一个非常简单的“待安排任务池”，本质类似 Inbox，但不要发展成完整 Todo 系统。
- “错过任务重排”应成为本地确定性功能：任务错过后进入 `unscheduledTasks` 或弹出本地重排建议，而不是立即让 AI 改正式计划。
- 图标和颜色可用于提升时间线扫读效率，但模型层只需要保留 `category` / `colorTag` 这类弱字段。

### Sunsama

链接：[Sunsama Timeboxing](https://help.sunsama.com/docs/usage-guides/timeboxing/)，[Workspace Navigation](https://help.sunsama.com/docs/usage-guides/workspace-navigation/)

定位：面向日/周计划 ritual 的时间块工作台，强调 daily planning、daily shutdown、focus mode 和 task/calendar side-by-side。

重要特性：

- 把任务拖到 calendar 上进行 timeboxing。
- 任务可以进入外部日历，也可以只放在内部日历。
- timeboxed task 可配置 privacy、busy/free、reminders 和目标日历。
- Focus Mode 只显示当前任务和计时器。
- Daily Planning、Daily Shutdown、Weekly Planning/Review 形成 ritual。

对 EfficientTime 的借鉴：

- `Plan Mode -> Run Mode -> Review Mode` 是正确主线。后续可以把开始和结束做成 ritual，而不是普通页面切换。
- 如果未来做 Calendar 接入，需要把“内部计划”和“外部日历事件”分开建模，避免污染用户主日历。
- Focus Mode 的极简视图可以对应 EfficientTime 的悬浮窗紧凑态。

### Ellie

链接：[ellieplanner.com](https://ellieplanner.com/)，[The Timebox](https://guide.ellieplanner.com/features/the-timebox)

定位：brain dump + daily Kanban + timebox。强调不是通用项目系统，而是日计划工具。

重要特性：

- 任务从 Kanban 拖到 calendar/timebox。
- 不强制连接真实日历，也可以单独 timebox。
- 支持多日/周视图、calendar toggle、task rollover、rituals、focus mode。
- 可配置 week start、隐藏周末、时间粒度。

对 EfficientTime 的借鉴：

- “不强制连接真实日历”很符合 EfficientTime 的本地单机第一版。
- 未完成任务 rollover 可以是 v0.4 复盘后的动作：继承到明天草稿，而不是自动写入明天正式计划。
- 时间粒度需要可配置，例如 5/10/15/30 分钟；这会影响排程器和编辑 UI。

### Morgen

链接：[Morgen AI Planner](https://www.morgen.so/ai-planner)

定位：AI daily planner，跨日历和任务源做 time blocking，并强调用户控制。

重要特性：

- AI 根据 priority、capacity 和工作方式生成 daily plan。
- Frames：给不同任务类型定义固定时段，例如 deep work、quick wins、personal tasks。
- 冲突出现时提醒，并可一键重排。
- AI 计划需要 preview 和用户调整。
- 可给耗时估算加 20% buffer，让计划更现实。

对 EfficientTime 的借鉴：

- `Frames` 可以转化成本地的 `AvailabilityWindow` 或 `WorkCategoryWindow`，例如“上午只放深度工作”“晚上只放私人事项”。
- AI 只输出建议，用户预览、调整后确认，这与 EfficientTime 的 AI 边界一致。
- “耗时估算加 buffer”可以先本地实现：例如给可拆分任务、低确定性任务加 10%-20% 弹性。

### Reclaim

链接：[Reclaim Habits](https://help.reclaim.ai/en/articles/4129152-habits-overview-auto-schedule-flexible-time-for-your-routines)

定位：AI calendar scheduling，核心是 flexible habits、priority、hours、duration、frequency、dependencies 和 buffer。

重要特性：

- Habit 有 priority、category、preferred hours、min/max duration、frequency。
- 可以避免重复事件。
- 支持 habit 之间的 dependencies。
- 可以 disable、snooze、delete、log work。
- 支持 buffer time、breaks、free/busy time defense。

对 EfficientTime 的借鉴：

- 本地排程模型可以逐步加入 `minDuration` / `maxDuration`、`preferredWindow`、`dependency`。
- “snooze / skip / log work”适合 Run Mode 的任务操作。
- `dependencies` 很适合严格时间表：例如“准备材料”必须早于“会议”。

不建议第一版做：

- 自动拒绝会议、跨团队可见性、Slack 状态同步等协作功能都超出 EfficientTime 边界。

## GitHub / 开源实现参考

### Reminders MenuBar

链接：[DamascenoRafael/reminders-menubar](https://github.com/DamascenoRafael/reminders-menubar)

价值：

- SwiftUI macOS 菜单栏应用。
- 使用 `EKEventStore` 访问 Apple Reminders。
- 支持创建、编辑、完成、移动、删除提醒。
- 支持自然语言日期。
- 多语言和权限说明做得完整。

借鉴方式：

- 如果 EfficientTime 后续接入 Apple Reminders，可以参考它的权限提示、EventKit 访问和提醒列表交互。
- 许可证是 GPL-3.0，只适合学习设计和 API 思路，不适合复制代码进入本项目。

### Calendr

链接：[pakerwreah/Calendr](https://github.com/pakerwreah/Calendr)

价值：

- 成熟的 macOS 菜单栏 calendar，Swift 为主，采用 MVVM、AppKit、SwiftUI。
- 有大量 release 和实际用户验证。
- 支持菜单栏日期/时间显示、URL scheme 打开日期、calendar/agenda 场景。

借鉴方式：

- 学习菜单栏 calendar/event 的性能、权限、设置页和 release 打包经验。
- 对 EfficientTime 来说，只需要“读取和展示日程上下文”，不要变成完整 calendar 替代品。

### NextUp

链接：[Broky64/NextUp](https://github.com/Broky64/NextUp)

价值：

- Native macOS 菜单栏日程 companion。
- 显示当前或下一个日历事件，并有 live countdown。
- Popover 按 TODAY、TOMORROW 和日期分组。
- EventKit 本地读取，偏好存 `UserDefaults`，无分析、无远程同步。

借鉴方式：

- 菜单栏动态标题和 live countdown 与 EfficientTime 的 Run Mode 高度相关。
- “当前 / 下一个事项”的状态推导可以作为 `DayPlan` 运行态 selector 的参考。
- 本地隐私说明可以作为 EfficientTime 文档的一种写法。

### Jamf Notifier

链接：[jamf/Notifier](https://github.com/jamf/Notifier)

价值：

- Swift macOS 通知实现，基于 `UserNotifications`。
- 支持 banner / alert、按钮动作、点击动作、移除历史通知。

借鉴方式：

- EfficientTime 的通知模块应该支持清理旧通知，避免任务频繁调整后 Notification Center 留下一堆过期提醒。
- 需要区分“任务开始提醒”“即将结束提醒”“任务结束提醒”的 action 行为。

### Fazm / NSPanel 相关实践

链接：[SwiftUI Menu Bar App With a Floating Window](https://fazm.ai/blog/swiftui-menu-bar-app-floating-window-best-practices)

价值：

- 清楚区分 `MenuBarExtra(.window)` 与 `NSStatusItem + NSPanel`。
- 对常驻浮窗，建议 `NSPanel`、`.nonactivatingPanel`、`level = .floating`、`.canJoinAllSpaces`、`.fullScreenAuxiliary`、`becomesKeyOnlyIfNeeded`。
- 用 `NSHostingView` 承载 SwiftUI，必要时使用全局事件监听处理外部点击。
- `LSUIElement` 可让应用保持菜单栏形态，不出现在 Dock。

借鉴方式：

- EfficientTime 的悬浮窗应优先采用 `NSPanel`，因为它需要跨 Space、全屏可见、低打扰。
- 输入型控件只在展开态需要抢焦点；紧凑态不应打断当前应用。
- 后续要专门测试全屏、外接屏、Stage Manager、多个 Space 的行为。

## 可落到 EfficientTime 的设计清单

### v0.2 优先

- 菜单栏显示当前任务和剩余时间。
- 悬浮窗紧凑态只放当前任务、剩余时间、完成/跳过/延长。
- 系统通知支持开始、即将结束、结束，并能清理过期通知。
- 任务和时间块继续分离，允许同一任务拆成多个 `TimeBlock`。
- 未完成/跳过任务进入本地重排候选，不自动写入正式计划。

### v0.3 AI Plan Builder

- 自然语言输入生成 `PlanDraft`。
- AI 草稿必须显示预览：新增、修改、删除、未安排项分组展示。
- 本地 `ScheduleValidator` 对 AI 输出做硬约束校验。
- 上下文打包继续支持 `Private`、`Anonymized`、`AI Visible`。
- 可以加入“耗时估算 buffer”和“偏好时段”字段。

### v0.4 执行复盘

- `ExecutionLog` 展示计划耗时、实际耗时、延迟、跳过、完成率。
- 支持 rollover：把未完成任务生成明天草稿。
- 支持本地 routine/template：例如工作日默认结构，但仍需要用户确认。
- 增加基于历史实际耗时的本地估算建议。

## 明确不做或延后

- 不做多人协作、团队排班、会议自动拒绝、Slack 状态同步。
- 不做完整外部日历替代品。
- 不在第一版做 Google/Outlook 双向同步。
- 不做云账号、跨设备同步或公共服务端。
- 不默认上传完整历史、完整日历、私密备注或本地文件内容给 AI。
- 不让 AI 直接覆盖正式 `DayPlan`。

## 产品机会

同类产品普遍在两个方向上分化：

- 大型 planner：Sunsama、Morgen、Reclaim、Akiflow，能力强但重，依赖账号和外部集成。
- 轻量 macOS 工具：Chunk、TaskLine、Timdo、NextUp，低摩擦、菜单栏优先，更适合 EfficientTime。

EfficientTime 的机会在于把第二类工具的低摩擦体验，与第一类工具的计划质量结合起来，但实现上坚持本地确定性排程和 AI 草稿确认。它不需要成为“更大的 Todo”，而应该成为“今天这张严格时间表真的能执行下去”的助手。

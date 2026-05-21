# EfficientTime 架构

## 总体数据流

```text
User Input
  -> TaskDraft / Task
  -> RuleBasedScheduler
  -> DayPlan
  -> Run Mode
  -> ExecutionLog
  -> Review
```

AI 规划路径：

```text
User Input
  -> PlanningContextPacker
  -> AIPlanningService
  -> PlanDraft
  -> ScheduleValidator
  -> User Confirmation
  -> DayPlan
```

## 核心模型

- `Task`：用户想做的事情。
- `TimeBlock`：任务在某一天被安排到的具体时间块。
- `DayPlan`：某一天的完整严格时间表。
- `ExecutionLog`：执行过程中的状态事件。
- `TaskDraft` / `PlanDraft`：AI 输出的草稿。

## 排程策略

第一版使用确定性规则：

1. 先安排固定时间任务。
2. 检查固定任务是否冲突或超出可用时间段。
3. 按优先级、截止时间、预计耗时安排弹性任务。
4. 任务之间保留 buffer。
5. 安排失败的任务进入 `unscheduledTasks`。

## DeepSeek 预留

`DeepSeekPlanningService` 负责后续真实 API 接入。当前阶段只定义配置、接口和错误边界。

API key 不进入 Git，不进入文档，不进入测试数据。


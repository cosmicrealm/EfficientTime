import EfficientTimeCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var deepSeekAPIKey = ""
    @State private var arkAPIKey = ""
    @State private var reminderTimeText = "20:00"
    @State private var planningStartText = AIPlanningDefaults.defaultStart.displayString
    @State private var planningEndText = AIPlanningDefaults.defaultEnd.displayString
    @State private var lunchStartText = "12:00"
    @State private var lunchEndText = "14:00"
    @State private var dinnerStartText = "18:00"
    @State private var dinnerEndText = "19:00"
    @State private var settingsMessage: String?
    @State private var settingsMessageIsError = false

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题色", selection: $model.settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            }

            Section("AI 服务商") {
                Picker("当前服务商", selection: $model.settings.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

            aiPlanningDefaultsSection

            if model.settings.aiProvider == .deepSeek {
                Section("DeepSeek 配置") {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("粘贴 DeepSeek API Key（sk-...）", text: $deepSeekAPIKey)
                        Label(
                            deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "尚未配置 API Key。AI 规划和 AI 复盘需要先填写这里，并点击底部“保存设置”。"
                                : "已填写 API Key。点击底部“保存设置”后会保存在本机配置中，之后 AI 规划不会再要求重复输入。",
                            systemImage: deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "exclamationmark.circle" : "checkmark.seal"
                        )
                        .font(.caption)
                        .foregroundStyle(deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .orange : .green)
                    }

                    TextField("Model", text: $model.settings.deepSeekModel)
                    Picker("推理强度", selection: $model.settings.deepSeekEffort) {
                        ForEach(PlanningEffort.allCases, id: \.self) { effort in
                            Text(effort.title).tag(effort)
                        }
                    }
                }
            } else {
                Section("火山方舟配置") {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("粘贴火山方舟 API Key（ARK_API_KEY）", text: $arkAPIKey)
                        Label(
                            arkAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "尚未配置火山方舟 API Key。选择火山方舟作为服务商后，需要先填写这里并保存。"
                                : "已填写火山方舟 API Key。点击底部“保存设置”后会保存在本机配置中。",
                            systemImage: arkAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "exclamationmark.circle" : "checkmark.seal"
                        )
                        .font(.caption)
                        .foregroundStyle(arkAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .orange : .green)
                    }

                    TextField("Model", text: $model.settings.arkModel)
                    Text("默认使用 doubao-seed-2-0-pro-260215，通过火山方舟 Responses API 调用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("悬浮窗") {
                Picker("背景颜色", selection: $model.settings.floatingPanelAppearance) {
                    ForEach(FloatingPanelAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                Picker("倒计时样式", selection: $model.settings.countdownStyle) {
                    ForEach(CountdownStyle.allCases, id: \.self) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)
                VStack(alignment: .leading, spacing: 6) {
                    Text("透明度 \(Int(model.settings.floatingPanelOpacity * 100))%")
                    Slider(value: $model.settings.floatingPanelOpacity, in: 0.45...1.0, step: 0.05)
                }
                Stepper("显示前 \(model.settings.floatingPreviousCount) 个", value: $model.settings.floatingPreviousCount, in: 0...8)
                Stepper("显示后 \(model.settings.floatingNextCount) 个", value: $model.settings.floatingNextCount, in: 0...8)
            }

            Section("提醒") {
                HStack {
                    Text("系统通知权限")
                    Spacer()
                    Text(model.notificationAuthorizationStatus)
                        .foregroundStyle(notificationStatusColor)
                }
                Text(model.notificationAuthorizationHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.notificationRuntimeHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        model.requestNotificationAuthorization()
                    } label: {
                        Label("申请系统通知权限", systemImage: "bell.badge")
                    }

                    Button {
                        model.sendTestNotification()
                    } label: {
                        Label("发送测试通知", systemImage: "paperplane")
                    }
                }

                Toggle("任务开始提醒", isOn: $model.settings.startNotificationsEnabled)
                Toggle("任务结束提醒", isOn: $model.settings.endNotificationsEnabled)
                Stepper("提前 \(model.settings.advanceReminderMinutes) 分钟提醒", value: $model.settings.advanceReminderMinutes, in: 0...60, step: 5)
                Toggle("提醒规划明天", isOn: $model.settings.tomorrowPlanningReminderEnabled)
                TextField("规划提醒时间 20:00", text: $reminderTimeText)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                Button {
                    saveAllSettings()
                } label: {
                    Label("保存设置", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)

                if let settingsMessage {
                    Text(settingsMessage)
                        .font(.caption)
                        .foregroundStyle(settingsMessageIsError ? .red : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            deepSeekAPIKey = model.loadSavedDeepSeekAPIKey()
            arkAPIKey = model.loadSavedArkAPIKey()
            reminderTimeText = model.settings.tomorrowPlanningReminderTime.displayString
            loadPlanningDefaults(model.settings.aiPlanningDefaults)
            model.refreshNotificationAuthorizationStatus()
        }
    }

    private var notificationStatusColor: Color {
        switch model.notificationAuthorizationStatus {
        case "已允许":
            .green
        case "已拒绝":
            .red
        case "未申请", "临时允许":
            .orange
        default:
            .secondary
        }
    }

    private var aiPlanningDefaultsSection: some View {
        Section("AI 默认规划") {
            HStack(spacing: 10) {
                compactPlanningTimeField(title: "开始", placeholder: "09:30", text: $planningStartText)
                compactPlanningTimeField(title: "结束", placeholder: "21:30", text: $planningEndText)
                compactPlanningRangeField(
                    title: "午饭",
                    startPlaceholder: "12:00",
                    endPlaceholder: "14:00",
                    startText: $lunchStartText,
                    endText: $lunchEndText
                )
                compactPlanningRangeField(
                    title: "晚饭",
                    startPlaceholder: "18:00",
                    endPlaceholder: "19:00",
                    startText: $dinnerStartText,
                    endText: $dinnerEndText
                )
                Spacer(minLength: 0)
            }

            Button {
                resetPlanningDefaultsToStandard()
            } label: {
                Label("恢复默认选项", systemImage: "arrow.counterclockwise")
            }
        }
    }

    private func compactPlanningTimeField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            TextField("", text: text, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
                .frame(width: 62)
                .monospacedDigit()
                .accessibilityLabel(title)
        }
        .font(.callout)
    }

    private func compactPlanningRangeField(
        title: String,
        startPlaceholder: String,
        endPlaceholder: String,
        startText: Binding<String>,
        endText: Binding<String>
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            TextField("", text: startText, prompt: Text(startPlaceholder))
                .textFieldStyle(.roundedBorder)
                .frame(width: 62)
                .monospacedDigit()
                .accessibilityLabel("\(title)开始")
            Text("–")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.9))
            TextField("", text: endText, prompt: Text(endPlaceholder))
                .textFieldStyle(.roundedBorder)
                .frame(width: 62)
                .monospacedDigit()
                .accessibilityLabel("\(title)结束")
        }
        .font(.callout)
    }

    private func saveAllSettings() {
        guard let planningDefaults = parsedPlanningDefaults() else {
            return
        }
        model.settings.aiPlanningDefaults = planningDefaults
        if let parsed = try? ClockTime(parsing: reminderTimeText) {
            model.settings.tomorrowPlanningReminderTime = parsed
        }
        _ = model.saveDeepSeekAPIKey(deepSeekAPIKey)
        _ = model.saveArkAPIKey(arkAPIKey)
        model.saveSettings()
        model.scheduleNotifications()
        settingsMessage = "设置已保存。"
        settingsMessageIsError = false
    }

    private func parsedPlanningDefaults() -> AIPlanningDefaultSchedule? {
        do {
            let start = try ClockTime(parsing: planningStartText.trimmingCharacters(in: .whitespacesAndNewlines))
            let end = try ClockTime(parsing: planningEndText.trimmingCharacters(in: .whitespacesAndNewlines))
            let lunchStart = try ClockTime(parsing: lunchStartText.trimmingCharacters(in: .whitespacesAndNewlines))
            let lunchEnd = try ClockTime(parsing: lunchEndText.trimmingCharacters(in: .whitespacesAndNewlines))
            let dinnerStart = try ClockTime(parsing: dinnerStartText.trimmingCharacters(in: .whitespacesAndNewlines))
            let dinnerEnd = try ClockTime(parsing: dinnerEndText.trimmingCharacters(in: .whitespacesAndNewlines))
            let schedule = AIPlanningDefaultSchedule(
                start: start,
                end: end,
                breaks: [
                    AIPlanningDefaultBreak(title: "午饭", start: lunchStart, end: lunchEnd),
                    AIPlanningDefaultBreak(title: "晚饭", start: dinnerStart, end: dinnerEnd)
                ]
            )

            guard schedule.isValid else {
                settingsMessage = "默认规划时间需要满足：开始早于结束，午饭和晚饭都在规划范围内且互不重叠。"
                settingsMessageIsError = true
                return nil
            }

            return schedule
        } catch {
            settingsMessage = "默认规划时间格式需要是 HH:mm，例如 09:30。"
            settingsMessageIsError = true
            return nil
        }
    }

    private func resetPlanningDefaultsToStandard() {
        model.settings.aiPlanningDefaults = AIPlanningDefaults.standard
        loadPlanningDefaults(AIPlanningDefaults.standard)
        settingsMessage = "已恢复默认选项，点击“保存设置”后生效。"
        settingsMessageIsError = false
    }

    private func loadPlanningDefaults(_ schedule: AIPlanningDefaultSchedule) {
        let resolved = schedule.isValid ? schedule : AIPlanningDefaults.standard
        planningStartText = resolved.start.displayString
        planningEndText = resolved.end.displayString
        let lunchBreak = resolved.breaks.first { $0.title == "午饭" || $0.title == "午饭和午休" }
        lunchStartText = lunchBreak?.start.displayString ?? "12:00"
        lunchEndText = lunchBreak?.end.displayString ?? "14:00"
        dinnerStartText = resolved.breaks.first(where: { $0.title == "晚饭" })?.start.displayString ?? "18:00"
        dinnerEndText = resolved.breaks.first(where: { $0.title == "晚饭" })?.end.displayString ?? "19:00"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppModel())
}

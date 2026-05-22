import EfficientTimeCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var deepSeekAPIKey = ""
    @State private var arkAPIKey = ""
    @State private var openAIAPIKey = ""
    @State private var geminiAPIKey = ""
    @State private var claudeAPIKey = ""
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
            Section(model.tr("语言")) {
                Picker(model.tr("界面语言"), selection: $model.settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.settingsTitle).tag(language)
                    }
                }
                Text(model.tr("语言会影响界面、提醒和 AI 输出语言。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(model.tr("外观")) {
                Picker(model.tr("主题色"), selection: $model.settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.localizedTitle(model.effectiveLanguage)).tag(theme)
                    }
                }
            }

            aiPlanningDefaultsSection

            Section(model.tr("AI 服务商")) {
                Picker(model.tr("当前服务商"), selection: $model.settings.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.localizedTitle(model.effectiveLanguage)).tag(provider)
                    }
                }
                .pickerStyle(.menu)
            }

            providerConfigurationSection

            Section(model.tr("悬浮窗")) {
                Picker(model.tr("背景颜色"), selection: $model.settings.floatingPanelAppearance) {
                    ForEach(FloatingPanelAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.localizedTitle(model.effectiveLanguage)).tag(appearance)
                    }
                }
                Picker(model.tr("倒计时样式"), selection: $model.settings.countdownStyle) {
                    ForEach(CountdownStyle.allCases, id: \.self) { style in
                        Text(style.localizedTitle(model.effectiveLanguage)).tag(style)
                    }
                }
                .pickerStyle(.menu)
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.trf("透明度 %d%%", Int(model.settings.floatingPanelOpacity * 100)))
                    Slider(value: $model.settings.floatingPanelOpacity, in: 0.0...1.0, step: 0.05)
                }
                Stepper(model.trf("显示前 %d 个", model.settings.floatingPreviousCount), value: $model.settings.floatingPreviousCount, in: 0...8)
                Stepper(model.trf("显示后 %d 个", model.settings.floatingNextCount), value: $model.settings.floatingNextCount, in: 0...8)
            }

            Section(model.tr("提醒")) {
                HStack {
                    Text(model.tr("系统通知权限"))
                    Spacer()
                    Text(model.notificationAuthorizationStatus)
                        .foregroundStyle(notificationStatusColor)
                }

                HStack {
                    Button {
                        model.requestNotificationAuthorization()
                    } label: {
                        Label(model.tr("申请系统通知权限"), systemImage: "bell.badge")
                    }

                    Button {
                        model.sendTestNotification()
                    } label: {
                        Label(model.tr("发送测试通知"), systemImage: "paperplane")
                    }
                }

                Toggle(model.tr("任务开始提醒"), isOn: $model.settings.startNotificationsEnabled)
                Toggle(model.tr("任务结束提醒"), isOn: $model.settings.endNotificationsEnabled)
                Stepper(model.trf("提前 %d 分钟提醒", model.settings.advanceReminderMinutes), value: $model.settings.advanceReminderMinutes, in: 0...60, step: 5)
                Toggle(model.tr("提醒规划明天"), isOn: $model.settings.tomorrowPlanningReminderEnabled)
                TextField(model.tr("规划提醒时间 20:00"), text: $reminderTimeText)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                Button {
                    saveAllSettings()
                } label: {
                    Label(model.tr("保存设置"), systemImage: "checkmark.circle")
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
            openAIAPIKey = model.loadSavedOpenAIAPIKey()
            geminiAPIKey = model.loadSavedGeminiAPIKey()
            claudeAPIKey = model.loadSavedClaudeAPIKey()
            reminderTimeText = model.settings.tomorrowPlanningReminderTime.displayString
            loadPlanningDefaults(model.settings.aiPlanningDefaults)
            model.refreshNotificationAuthorizationStatus()
        }
    }

    private var notificationStatusColor: Color {
        if model.notificationAuthorizationStatus == model.tr("已允许") {
            return .green
        }
        if model.notificationAuthorizationStatus == model.tr("已拒绝") {
            return .red
        }
        if model.notificationAuthorizationStatus == model.tr("未申请") ||
            model.notificationAuthorizationStatus == model.tr("临时允许") {
            return .orange
        }
        return .secondary
    }

    private var aiPlanningDefaultsSection: some View {
        Section(model.tr("AI 默认规划")) {
            HStack(alignment: .top, spacing: 10) {
                compactPlanningWorkdayRangeGroup(
                    startTitle: model.tr("开始"),
                    endTitle: model.tr("结束"),
                    placeholder: "09:30",
                    endPlaceholder: "21:30",
                    startText: $planningStartText,
                    endText: $planningEndText
                )
                compactPlanningRangeGroup(
                    title: model.tr("午饭"),
                    startPlaceholder: "12:00",
                    endPlaceholder: "14:00",
                    startText: $lunchStartText,
                    endText: $lunchEndText
                )
                compactPlanningRangeGroup(
                    title: model.tr("晚饭"),
                    startPlaceholder: "18:00",
                    endPlaceholder: "19:00",
                    startText: $dinnerStartText,
                    endText: $dinnerEndText
                )
            }
            .fixedSize(horizontal: true, vertical: false)

            Button {
                resetPlanningDefaultsToStandard()
            } label: {
                Label(model.tr("恢复默认选项"), systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var providerConfigurationSection: some View {
        let providerTitle = model.settings.aiProvider.localizedTitle(model.effectiveLanguage)
        let trimmedKey = selectedProviderAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return Section(model.trf("%@ 配置", providerTitle)) {
            VStack(alignment: .leading, spacing: 8) {
                SecureField(providerAPIKeyPrompt, text: selectedProviderAPIKeyBinding)
                Label(
                    trimmedKey.isEmpty
                        ? model.trf("尚未配置 %@ API Key。选择 %@ 作为服务商后，需要先填写这里并保存。", providerTitle, providerTitle)
                        : model.trf("%@ API Key 已填写。点击底部“保存设置”后会保存在本机配置中。", providerTitle),
                    systemImage: trimmedKey.isEmpty ? "exclamationmark.circle" : "checkmark.seal"
                )
                .font(.caption)
                .foregroundStyle(trimmedKey.isEmpty ? .orange : .green)
            }

            VStack(alignment: .leading, spacing: 8) {
                Picker(model.tr("常用模型"), selection: selectedProviderModelBinding) {
                    ForEach(providerModelOptions, id: \.self) { modelID in
                        Text(modelID).tag(modelID)
                    }
                }
                .pickerStyle(.menu)

                TextField(model.tr("模型 ID"), text: selectedProviderModelBinding)
                    .textFieldStyle(.roundedBorder)
                    .monospaced()
                    .textSelection(.enabled)
            }

            if model.settings.aiProvider == .deepSeek {
                Picker(model.tr("推理强度"), selection: $model.settings.deepSeekEffort) {
                    ForEach(PlanningEffort.allCases, id: \.self) { effort in
                        Text(effort.localizedTitle(model.effectiveLanguage)).tag(effort)
                    }
                }
            }

            Text(providerHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var providerModelOptions: [String] {
        let presets: [String]
        switch model.settings.aiProvider {
        case .deepSeek:
            presets = [
                "deepseek-v4-flash",
                "deepseek-v4-pro"
            ]
        case .ark:
            presets = [
                "doubao-seed-2-0-pro-260215",
                "doubao-seed-2-0-lite-260215",
                "doubao-seed-2-0-mini-260215",
                "doubao-seed-code-preview-251028",
                "doubao-seed-1-8-251228"
            ]
        case .openAI:
            presets = [
                "gpt-5.5",
                "gpt-5.5-pro",
                "gpt-5.4-mini",
                "gpt-5.4",
                "gpt-5.4-pro",
                "gpt-5.3-codex",
                "gpt-5.3-codex-spark",
                "gpt-5.3-chat",
                "chat-latest"
            ]
        case .gemini:
            presets = [
                "gemini-3.5-flash",
                "gemini-3.1-pro-preview",
                "gemini-3-flash-preview",
                "gemini-3.1-flash-lite",
                "gemini-3.1-flash-lite-preview",
                "gemini-2.5-pro",
                "gemini-2.5-flash",
                "gemini-2.5-flash-lite"
            ]
        case .claude:
            presets = [
                "claude-opus-4-7",
                "claude-opus-4-6",
                "claude-sonnet-4-6",
                "claude-haiku-4-5",
                "claude-haiku-4-5-20251001"
            ]
        }

        let current = selectedProviderModelBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty, !presets.contains(current) {
            return [current] + presets
        }
        return presets
    }

    private var selectedProviderAPIKey: String {
        switch model.settings.aiProvider {
        case .deepSeek:
            return deepSeekAPIKey
        case .ark:
            return arkAPIKey
        case .openAI:
            return openAIAPIKey
        case .gemini:
            return geminiAPIKey
        case .claude:
            return claudeAPIKey
        }
    }

    private var selectedProviderAPIKeyBinding: Binding<String> {
        Binding(
            get: { selectedProviderAPIKey },
            set: { newValue in
                switch model.settings.aiProvider {
                case .deepSeek:
                    deepSeekAPIKey = newValue
                case .ark:
                    arkAPIKey = newValue
                case .openAI:
                    openAIAPIKey = newValue
                case .gemini:
                    geminiAPIKey = newValue
                case .claude:
                    claudeAPIKey = newValue
                }
            }
        )
    }

    private var selectedProviderModelBinding: Binding<String> {
        Binding(
            get: {
                switch model.settings.aiProvider {
                case .deepSeek:
                    return model.settings.deepSeekModel
                case .ark:
                    return model.settings.arkModel
                case .openAI:
                    return model.settings.openAIModel
                case .gemini:
                    return model.settings.geminiModel
                case .claude:
                    return model.settings.claudeModel
                }
            },
            set: { newValue in
                switch model.settings.aiProvider {
                case .deepSeek:
                    model.settings.deepSeekModel = newValue
                case .ark:
                    model.settings.arkModel = newValue
                case .openAI:
                    model.settings.openAIModel = newValue
                case .gemini:
                    model.settings.geminiModel = newValue
                case .claude:
                    model.settings.claudeModel = newValue
                }
            }
        )
    }

    private var providerAPIKeyPrompt: String {
        switch model.settings.aiProvider {
        case .deepSeek:
            return model.tr("粘贴 DeepSeek API Key（sk-...）")
        case .ark:
            return model.tr("粘贴火山方舟 API Key（ARK_API_KEY）")
        case .openAI:
            return model.tr("粘贴 OpenAI API Key（sk-...）")
        case .gemini:
            return model.tr("粘贴 Gemini API Key（AIza...）")
        case .claude:
            return model.tr("粘贴 Claude API Key（sk-ant-...）")
        }
    }

    private var providerHelpText: String {
        switch model.settings.aiProvider {
        case .deepSeek:
            return model.tr("默认使用 deepseek-v4-flash；深入模式会启用 DeepSeek 的 thinking 参数。")
        case .ark:
            return model.tr("默认使用 doubao-seed-2-0-pro-260215，通过火山方舟 Responses API 调用。")
        case .openAI:
            return model.tr("默认使用 gpt-5.4-mini，通过 OpenAI Chat Completions API 调用。")
        case .gemini:
            return model.tr("默认使用 gemini-3.5-flash，通过 Gemini generateContent API 调用。")
        case .claude:
            return model.tr("默认使用 claude-sonnet-4-6，通过 Claude Messages API 调用。")
        }
    }

    private func compactPlanningTitle(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(width: width, height: 16, alignment: .center)
    }

    private func compactPlanningWorkdayRangeGroup(
        startTitle: String,
        endTitle: String,
        placeholder: String,
        endPlaceholder: String,
        startText: Binding<String>,
        endText: Binding<String>
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            compactPlanningTimeGroup(
                title: startTitle,
                placeholder: placeholder,
                text: startText
            )
            compactPlanningSeparatorGroup()
            compactPlanningTimeGroup(
                title: endTitle,
                placeholder: endPlaceholder,
                text: endText
            )
        }
    }

    private func compactPlanningRangeGroup(
        title: String,
        startPlaceholder: String,
        endPlaceholder: String,
        startText: Binding<String>,
        endText: Binding<String>
    ) -> some View {
        VStack(alignment: .center, spacing: 6) {
            compactPlanningTitle(title, width: 150)
            compactPlanningRangeField(
                title: title,
                startPlaceholder: startPlaceholder,
                endPlaceholder: endPlaceholder,
                startText: startText,
                endText: endText
            )
        }
    }

    private func compactPlanningTimeGroup(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .center, spacing: 6) {
            compactPlanningTitle(title, width: 66)
            compactPlanningTimeField(placeholder: placeholder, text: text, accessibilityLabel: title)
        }
    }

    private func compactPlanningSeparatorGroup() -> some View {
        VStack(alignment: .center, spacing: 6) {
            Color.clear
                .frame(width: 12, height: 16)
            compactPlanningSeparator()
        }
    }

    private func compactPlanningSeparator() -> some View {
        ZStack {
            Capsule()
                .fill(.secondary.opacity(0.7))
                .frame(width: 12, height: 2)
        }
        .frame(width: 12, height: 40)
    }

    private func compactPlanningTimeField(
        placeholder: String,
        text: Binding<String>,
        accessibilityLabel: String
    ) -> some View {
        TextField("", text: text, prompt: Text(placeholder))
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .frame(width: 66, height: 40)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.secondary.opacity(0.16), lineWidth: 1)
            }
            .monospacedDigit()
            .accessibilityLabel(accessibilityLabel)
    }

    private func compactPlanningRangeField(
        title: String,
        startPlaceholder: String,
        endPlaceholder: String,
        startText: Binding<String>,
        endText: Binding<String>
    ) -> some View {
        HStack(spacing: 6) {
            TextField("", text: startText, prompt: Text(startPlaceholder))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: 62, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.secondary.opacity(0.16), lineWidth: 1)
                }
                .monospacedDigit()
                .accessibilityLabel("\(title)\(model.tr("开始"))")
            compactPlanningSeparator()
            TextField("", text: endText, prompt: Text(endPlaceholder))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: 62, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.secondary.opacity(0.16), lineWidth: 1)
                }
                .monospacedDigit()
                .accessibilityLabel("\(title)\(model.tr("结束"))")
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
        _ = model.saveOpenAIAPIKey(openAIAPIKey)
        _ = model.saveGeminiAPIKey(geminiAPIKey)
        _ = model.saveClaudeAPIKey(claudeAPIKey)
        model.saveSettings()
        model.scheduleNotifications()
        settingsMessage = model.tr("设置已保存。")
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
                settingsMessage = model.tr("默认规划时间需要满足：开始早于结束，午饭和晚饭都在规划范围内且互不重叠。")
                settingsMessageIsError = true
                return nil
            }

            return schedule
        } catch {
            settingsMessage = model.tr("默认规划时间格式需要是 HH:mm，例如 09:30。")
            settingsMessageIsError = true
            return nil
        }
    }

    private func resetPlanningDefaultsToStandard() {
        model.settings.aiPlanningDefaults = AIPlanningDefaults.standard
        loadPlanningDefaults(AIPlanningDefaults.standard)
        settingsMessage = model.tr("已恢复默认选项，点击“保存设置”后生效。")
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

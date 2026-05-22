import EfficientTimeCore
import Foundation

struct AppWorkspace: Codable, Sendable {
    var selectedDate: LocalDate
    var dailyWorkspaces: [LocalDate: DailyWorkspace]
    var settings: AppSettings

    init(
        selectedDate: LocalDate,
        dailyWorkspaces: [LocalDate: DailyWorkspace],
        settings: AppSettings = AppSettings()
    ) {
        self.selectedDate = selectedDate
        self.dailyWorkspaces = dailyWorkspaces
        self.settings = settings
    }

    enum CodingKeys: String, CodingKey {
        case selectedDate
        case dailyWorkspaces
        case settings
        case tasks
        case plan
        case logs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        if let selectedDate = try container.decodeIfPresent(LocalDate.self, forKey: .selectedDate),
           let encodedDailyWorkspaces = try container.decodeIfPresent([String: DailyWorkspace].self, forKey: .dailyWorkspaces) {
            self.selectedDate = selectedDate
            self.dailyWorkspaces = Dictionary(
                uniqueKeysWithValues: encodedDailyWorkspaces.compactMap { key, value in
                    guard let date = Self.localDate(from: key) else { return nil }
                    return (date, value)
                }
            )
            return
        }

        let tasks = try container.decode([EfficientTimeCore.Task].self, forKey: .tasks)
        let plan = try container.decode(DayPlan.self, forKey: .plan)
        let logs = try container.decodeIfPresent([ExecutionLog].self, forKey: .logs) ?? []
        self.selectedDate = plan.date
        self.dailyWorkspaces = [
            plan.date: DailyWorkspace(tasks: tasks, plan: plan, logs: logs)
        ]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedDate, forKey: .selectedDate)
        try container.encode(settings, forKey: .settings)
        let encodedDailyWorkspaces = Dictionary(
            uniqueKeysWithValues: dailyWorkspaces.map { date, workspace in
                (date.displayString, workspace)
            }
        )
        try container.encode(encodedDailyWorkspaces, forKey: .dailyWorkspaces)
    }

    private static func localDate(from value: String) -> LocalDate? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }
        return LocalDate(year: year, month: month, day: day)
    }
}

struct DailyWorkspace: Codable, Sendable {
    var tasks: [EfficientTimeCore.Task]
    var plan: DayPlan
    var logs: [ExecutionLog]

    init(tasks: [EfficientTimeCore.Task], plan: DayPlan, logs: [ExecutionLog] = []) {
        self.tasks = tasks
        self.plan = plan
        self.logs = logs
    }
}

struct AppSettings: Codable, Sendable {
    static let defaultDeepSeekModel = "deepseek-v4-flash"
    static let legacyDefaultDeepSeekModel = "deepseek-v4-pro"
    static let defaultArkModel = "doubao-seed-2-0-pro-260215"
    static let defaultOpenAIModel = "gpt-5.4-mini"
    static let defaultGeminiModel = "gemini-3.5-flash"
    static let defaultClaudeModel = "claude-sonnet-4-6"

    var language: AppLanguage
    var theme: AppTheme
    var floatingPanelAppearance: FloatingPanelAppearance
    var floatingPanelOpacity: Double
    var countdownStyle: CountdownStyle
    var aiProvider: AIProvider
    var deepSeekModel: String
    var arkModel: String
    var openAIModel: String
    var geminiModel: String
    var claudeModel: String
    var deepSeekEffort: PlanningEffort
    var aiPlanningDefaults: AIPlanningDefaultSchedule
    var floatingPreviousCount: Int
    var floatingNextCount: Int
    var startNotificationsEnabled: Bool
    var endNotificationsEnabled: Bool
    var advanceReminderMinutes: Int
    var tomorrowPlanningReminderEnabled: Bool
    var tomorrowPlanningReminderTime: ClockTime

    init(
        language: AppLanguage = .system,
        theme: AppTheme = .teal,
        floatingPanelAppearance: FloatingPanelAppearance = .mint,
        floatingPanelOpacity: Double = 0.92,
        countdownStyle: CountdownStyle = .vivid,
        aiProvider: AIProvider = .deepSeek,
        deepSeekModel: String = Self.defaultDeepSeekModel,
        arkModel: String = Self.defaultArkModel,
        openAIModel: String = Self.defaultOpenAIModel,
        geminiModel: String = Self.defaultGeminiModel,
        claudeModel: String = Self.defaultClaudeModel,
        deepSeekEffort: PlanningEffort = .normal,
        aiPlanningDefaults: AIPlanningDefaultSchedule = AIPlanningDefaults.standard,
        floatingPreviousCount: Int = 3,
        floatingNextCount: Int = 4,
        startNotificationsEnabled: Bool = true,
        endNotificationsEnabled: Bool = true,
        advanceReminderMinutes: Int = 5,
        tomorrowPlanningReminderEnabled: Bool = true,
        tomorrowPlanningReminderTime: ClockTime = ClockTime(hour: 20, minute: 0)
    ) {
        self.language = language
        self.theme = theme
        self.floatingPanelAppearance = floatingPanelAppearance
        self.floatingPanelOpacity = floatingPanelOpacity
        self.countdownStyle = countdownStyle
        self.aiProvider = aiProvider
        self.deepSeekModel = Self.normalizedDeepSeekModel(deepSeekModel)
        self.arkModel = Self.normalizedModel(arkModel, defaultValue: Self.defaultArkModel)
        self.openAIModel = Self.normalizedModel(openAIModel, defaultValue: Self.defaultOpenAIModel)
        self.geminiModel = Self.normalizedModel(geminiModel, defaultValue: Self.defaultGeminiModel)
        self.claudeModel = Self.normalizedModel(claudeModel, defaultValue: Self.defaultClaudeModel)
        self.deepSeekEffort = deepSeekEffort
        self.aiPlanningDefaults = Self.normalizedPlanningDefaults(aiPlanningDefaults)
        self.floatingPreviousCount = floatingPreviousCount
        self.floatingNextCount = floatingNextCount
        self.startNotificationsEnabled = startNotificationsEnabled
        self.endNotificationsEnabled = endNotificationsEnabled
        self.advanceReminderMinutes = advanceReminderMinutes
        self.tomorrowPlanningReminderEnabled = tomorrowPlanningReminderEnabled
        self.tomorrowPlanningReminderTime = tomorrowPlanningReminderTime
    }

    enum CodingKeys: String, CodingKey {
        case language
        case theme
        case floatingPanelAppearance
        case floatingPanelOpacity
        case countdownStyle
        case aiProvider
        case deepSeekModel
        case arkModel
        case openAIModel
        case geminiModel
        case claudeModel
        case deepSeekEffort
        case aiPlanningDefaults
        case floatingPreviousCount
        case floatingNextCount
        case startNotificationsEnabled
        case endNotificationsEnabled
        case advanceReminderMinutes
        case tomorrowPlanningReminderEnabled
        case tomorrowPlanningReminderTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        self.theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .teal
        self.floatingPanelAppearance = try container.decodeIfPresent(FloatingPanelAppearance.self, forKey: .floatingPanelAppearance) ?? .mint
        self.floatingPanelOpacity = try container.decodeIfPresent(Double.self, forKey: .floatingPanelOpacity) ?? 0.92
        self.countdownStyle = try container.decodeIfPresent(CountdownStyle.self, forKey: .countdownStyle) ?? .vivid
        self.aiProvider = try container.decodeIfPresent(AIProvider.self, forKey: .aiProvider) ?? .deepSeek
        self.deepSeekModel = Self.normalizedDeepSeekModel(
            try container.decodeIfPresent(String.self, forKey: .deepSeekModel) ?? Self.defaultDeepSeekModel
        )
        self.arkModel = Self.normalizedModel(
            try container.decodeIfPresent(String.self, forKey: .arkModel) ?? Self.defaultArkModel,
            defaultValue: Self.defaultArkModel
        )
        self.openAIModel = Self.normalizedModel(
            try container.decodeIfPresent(String.self, forKey: .openAIModel) ?? Self.defaultOpenAIModel,
            defaultValue: Self.defaultOpenAIModel
        )
        self.geminiModel = Self.normalizedModel(
            try container.decodeIfPresent(String.self, forKey: .geminiModel) ?? Self.defaultGeminiModel,
            defaultValue: Self.defaultGeminiModel
        )
        self.claudeModel = Self.normalizedModel(
            try container.decodeIfPresent(String.self, forKey: .claudeModel) ?? Self.defaultClaudeModel,
            defaultValue: Self.defaultClaudeModel
        )
        self.deepSeekEffort = try container.decodeIfPresent(PlanningEffort.self, forKey: .deepSeekEffort) ?? .normal
        let decodedPlanningDefaults = try container.decodeIfPresent(AIPlanningDefaultSchedule.self, forKey: .aiPlanningDefaults) ?? AIPlanningDefaults.standard
        self.aiPlanningDefaults = Self.normalizedPlanningDefaults(decodedPlanningDefaults)
        self.floatingPreviousCount = try container.decodeIfPresent(Int.self, forKey: .floatingPreviousCount) ?? 3
        self.floatingNextCount = try container.decodeIfPresent(Int.self, forKey: .floatingNextCount) ?? 4
        self.startNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .startNotificationsEnabled) ?? true
        self.endNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .endNotificationsEnabled) ?? true
        self.advanceReminderMinutes = try container.decodeIfPresent(Int.self, forKey: .advanceReminderMinutes) ?? 5
        self.tomorrowPlanningReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .tomorrowPlanningReminderEnabled) ?? true
        self.tomorrowPlanningReminderTime = try container.decodeIfPresent(ClockTime.self, forKey: .tomorrowPlanningReminderTime) ?? ClockTime(hour: 20, minute: 0)
    }

    private static func normalizedDeepSeekModel(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == legacyDefaultDeepSeekModel {
            return defaultDeepSeekModel
        }
        return trimmed
    }

    static func normalizedModel(_ model: String, defaultValue: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }

    static func normalizedPlanningDefaults(_ schedule: AIPlanningDefaultSchedule) -> AIPlanningDefaultSchedule {
        let resolved = schedule.isValid ? schedule : AIPlanningDefaults.standard
        let breaks = resolved.breaks.map { defaultBreak in
            let normalizedTitle: String
            switch defaultBreak.title.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "午饭和午休", "午饭午休":
                normalizedTitle = "午饭"
            case "":
                normalizedTitle = "休息"
            default:
                normalizedTitle = defaultBreak.title
            }
            return AIPlanningDefaultBreak(
                title: normalizedTitle,
                start: defaultBreak.start,
                end: defaultBreak.end
            )
        }
        let normalized = AIPlanningDefaultSchedule(start: resolved.start, end: resolved.end, breaks: breaks)
        return normalized.isValid ? normalized : AIPlanningDefaults.standard
    }
}

actor LocalJSONWorkspaceStore {
    private let fileURL: URL

    init(filename: String = "workspace.json") {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("EfficientTime", isDirectory: true)
        let resolvedDirectory = directory ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: resolvedDirectory, withIntermediateDirectories: true)
        self.fileURL = resolvedDirectory.appendingPathComponent(filename)
    }

    func save(workspace: AppWorkspace) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(workspace)
        try data.write(to: fileURL, options: .atomic)
    }

    func load() throws -> AppWorkspace? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppWorkspace.self, from: data)
    }
}

import Foundation

public enum PlanningSkill: String, Codable, CaseIterable, Sendable {
    case taskDecomposition
    case clarification
    case scheduleProposal
    case scheduleRepair
    case dayReview
}

public enum PlanningEffort: String, Codable, CaseIterable, Sendable {
    case fast
    case normal
    case deep
}

public struct TaskDraft: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var estimatedDurationMinutes: Int
    public var priority: TaskPriority
    public var category: TaskCategory
    public var fixedStart: ClockTime?
    public var earliestStart: ClockTime?
    public var latestEnd: ClockTime?
    public var canSplit: Bool
    public var assumptions: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        estimatedDurationMinutes: Int,
        priority: TaskPriority = .medium,
        category: TaskCategory = .other,
        fixedStart: ClockTime? = nil,
        earliestStart: ClockTime? = nil,
        latestEnd: ClockTime? = nil,
        canSplit: Bool = false,
        assumptions: [String] = []
    ) {
        self.id = id
        self.title = title
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.priority = priority
        self.category = category
        self.fixedStart = fixedStart
        self.earliestStart = earliestStart
        self.latestEnd = latestEnd
        self.canSplit = canSplit
        self.assumptions = assumptions
    }

    public func makeTask(privacyLevel: TaskPrivacyLevel = .anonymized) -> Task {
        Task(
            title: title,
            notes: assumptions.joined(separator: "\n"),
            estimatedDurationMinutes: estimatedDurationMinutes,
            priority: priority,
            category: category,
            earliestStart: earliestStart,
            latestEnd: latestEnd,
            fixedStart: fixedStart,
            canSplit: canSplit,
            privacyLevel: privacyLevel
        )
    }
}

public struct PlanDraft: Codable, Hashable, Sendable {
    public var date: LocalDate
    public var blocks: [TimeBlock]
    public var unscheduledTaskTitles: [String]
    public var assumptions: [String]
    public var clarifyingQuestions: [String]

    public init(
        date: LocalDate,
        blocks: [TimeBlock],
        unscheduledTaskTitles: [String] = [],
        assumptions: [String] = [],
        clarifyingQuestions: [String] = []
    ) {
        self.date = date
        self.blocks = blocks.sorted { $0.start < $1.start }
        self.unscheduledTaskTitles = unscheduledTaskTitles
        self.assumptions = assumptions
        self.clarifyingQuestions = clarifyingQuestions
    }
}

public struct PlanningContext: Sendable {
    public var date: LocalDate
    public var availableWindows: [TimeWindow]
    public var tasks: [Task]
    public var rawUserInput: String
    public var effort: PlanningEffort
    public var defaultSchedule: AIPlanningDefaultSchedule

    public init(
        date: LocalDate,
        availableWindows: [TimeWindow],
        tasks: [Task] = [],
        rawUserInput: String = "",
        effort: PlanningEffort = .normal,
        defaultSchedule: AIPlanningDefaultSchedule = AIPlanningDefaults.standard
    ) {
        self.date = date
        self.availableWindows = availableWindows
        self.tasks = tasks
        self.rawUserInput = rawUserInput
        self.effort = effort
        self.defaultSchedule = defaultSchedule
    }
}

public protocol AIPlanningService: Sendable {
    func extractTasks(from input: String, context: PlanningContext) async throws -> [TaskDraft]
    func askClarifyingQuestions(context: PlanningContext) async throws -> [String]
    func proposeSchedule(context: PlanningContext) async throws -> PlanDraft
    func summarizeDay(plan: DayPlan, logs: [ExecutionLog], outputLanguage: String) async throws -> String
}

public enum AIPlanningError: Error, Equatable, LocalizedError {
    case notConfigured
    case httpStatus(Int)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "请先在设置中配置当前 AI 服务商的 API Key。"
        case let .httpStatus(status):
            return "AI 请求失败，HTTP 状态码：\(status)。"
        case let .invalidResponse(message):
            return message
        }
    }
}

public struct DeepSeekConfiguration: Sendable {
    public var apiKey: String?
    public var baseURL: URL
    public var model: String

    public init(
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://api.deepseek.com")!,
        model: String = "deepseek-v4-pro"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }
}

public struct ArkConfiguration: Sendable {
    public var apiKey: String?
    public var baseURL: URL
    public var model: String

    public init(
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://ark.cn-beijing.volces.com/api/v3")!,
        model: String = "doubao-seed-2-0-pro-260215"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }
}

public struct OpenAIConfiguration: Sendable {
    public var apiKey: String?
    public var baseURL: URL
    public var model: String

    public init(
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        model: String = "gpt-5.4-mini"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }
}

public struct GeminiConfiguration: Sendable {
    public var apiKey: String?
    public var baseURL: URL
    public var model: String

    public init(
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com")!,
        model: String = "gemini-3.5-flash"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }
}

public struct ClaudeConfiguration: Sendable {
    public var apiKey: String?
    public var baseURL: URL
    public var model: String

    public init(
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        model: String = "claude-sonnet-4-6"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }
}

private func taskExtractionTokenBudget(for input: String) -> Int {
    let separators = CharacterSet(charactersIn: "\n;；,，、")
    let estimatedTaskCount = max(
        1,
        input.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
            .count
    )
    return min(4_200, max(1_500, 1_000 + estimatedTaskCount * 180))
}

public actor DeepSeekPlanningService: AIPlanningService {
    private let configuration: DeepSeekConfiguration
    private let contextPacker: PlanningContextPacker

    public init(
        configuration: DeepSeekConfiguration,
        contextPacker: PlanningContextPacker = PlanningContextPacker()
    ) {
        self.configuration = configuration
        self.contextPacker = contextPacker
    }

    public func extractTasks(from input: String, context: PlanningContext) async throws -> [TaskDraft] {
        try ensureConfigured()
        let packedContext = contextPacker.pack(context)
        let payload: DeepSeekTaskExtractionPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.taskExtraction,
            userPrompt: DeepSeekPrompts.userPrompt(
                instruction: """
                请从用户输入中拆分任务，并给出轻量的初始时间建议。输出 json，字段必须符合示例结构。
                默认规划范围是 \(context.defaultSchedule.windowDescription)。如果用户没有指定开始时间，请按输入顺序估算 fixedStart。
                默认休息为：\(context.defaultSchedule.breakDescription)。未指定时间的工作任务不要占用这些休息时段。
                如果用户没有指定耗时，请根据任务内容估算 estimatedDurationMinutes，不要使用机械固定值。
                不同任务允许安排在同一时间；如果输入里有重复或同名任务，请合并成一个任务。
                assumptions 每个任务最多 1 条短句，语言遵循用户输入中的输出语言要求。不要反问用户，不要输出长解释。
                你只需要给建议；最终基础校验和同名任务合并会由本地排程器完成。
                """,
                packedContext: packedContext,
                rawInput: input
            ),
            effort: context.effort,
            maxTokens: taskExtractionTokenBudget(for: input)
        )
        return payload.tasks.map(\.taskDraft)
    }

    public func askClarifyingQuestions(context: PlanningContext) async throws -> [String] {
        try ensureConfigured()
        let payload: DeepSeekClarificationPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.clarification,
            userPrompt: DeepSeekPrompts.userPrompt(
                instruction: "请判断为了生成严格时间表，还需要追问用户哪些关键问题。最多 3 个问题。输出 json。",
                packedContext: contextPacker.pack(context),
                rawInput: context.rawUserInput
            ),
            effort: .fast,
            maxTokens: 900
        )
        return payload.clarifyingQuestions
    }

    public func proposeSchedule(context: PlanningContext) async throws -> PlanDraft {
        try ensureConfigured()
        let payload: DeepSeekPlanDraftPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.scheduleProposal,
            userPrompt: DeepSeekPrompts.userPrompt(
                instruction: "请生成严格时间表草稿。输出 json。时间使用 HH:mm。",
                packedContext: contextPacker.pack(context),
                rawInput: context.rawUserInput
            ),
            effort: context.effort,
            maxTokens: 2_500
        )
        return try payload.planDraft(date: context.date)
    }

    public func summarizeDay(plan: DayPlan, logs: [ExecutionLog], outputLanguage: String = "Simplified Chinese") async throws -> String {
        try ensureConfigured()
        let payload: DeepSeekSummaryPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.dayReview,
            userPrompt: DeepSeekPrompts.reviewPrompt(plan: plan, logs: logs, outputLanguage: outputLanguage),
            effort: .normal,
            maxTokens: 1_500
        )
        return payload.summary
    }

    private func ensureConfigured() throws {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIPlanningError.notConfigured
        }
    }

    private func sendJSONRequest<Response: Decodable>(
        systemPrompt: String,
        userPrompt: String,
        effort: PlanningEffort,
        maxTokens: Int
    ) async throws -> Response {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIPlanningError.notConfigured
        }

        let requestPayload = DeepSeekChatRequest(
            model: configuration.model,
            messages: [
                DeepSeekChatMessage(role: "system", content: systemPrompt),
                DeepSeekChatMessage(role: "user", content: userPrompt)
            ],
            thinking: DeepSeekThinking(effort: effort),
            responseFormat: DeepSeekResponseFormat(type: "json_object"),
            maxTokens: maxTokens,
            temperature: 0.2
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("chat/completions"), timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.deepSeek.encode(requestPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AIPlanningError.httpStatus(httpResponse.statusCode)
        }

        let completion = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let content = completion.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIPlanningError.invalidResponse("DeepSeek returned empty content.")
        }

        let jsonContent = Self.extractJSONObject(from: content) ?? content
        guard let contentData = jsonContent.data(using: .utf8) else {
            throw AIPlanningError.invalidResponse("DeepSeek content is not UTF-8.")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: contentData)
        } catch {
            throw AIPlanningError.invalidResponse(Self.invalidJSONMessage(from: error, content: content))
        }
    }

    fileprivate static func extractJSONObject(from content: String) -> String? {
        guard let start = content.firstIndex(of: "{") else { return nil }
        var depth = 0
        var isInsideString = false
        var isEscaped = false
        var index = start

        while index < content.endIndex {
            let character = content[index]
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else {
                if character == "\"" {
                    isInsideString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(content[start...index])
                    }
                }
            }
            index = content.index(after: index)
        }

        return nil
    }

    fileprivate static func invalidJSONMessage(from error: Error, content: String, providerName: String = "DeepSeek") -> String {
        if content.contains("{") && extractJSONObject(from: content) == nil {
            return "\(providerName) 返回的规划结果不完整，通常是任务太多或输出过长导致 JSON 被截断。请再试一次，或把任务拆成两批规划。底层错误：\(error.localizedDescription)"
        }
        return "\(providerName) 返回的规划结果不是合法 JSON。请再试一次，或减少一次输入的任务数量。底层错误：\(error.localizedDescription)"
    }
}

public actor ArkPlanningService: AIPlanningService {
    private let configuration: ArkConfiguration
    private let contextPacker: PlanningContextPacker

    public init(
        configuration: ArkConfiguration,
        contextPacker: PlanningContextPacker = PlanningContextPacker()
    ) {
        self.configuration = configuration
        self.contextPacker = contextPacker
    }

    public func extractTasks(from input: String, context: PlanningContext) async throws -> [TaskDraft] {
        try ensureConfigured()
        let payload: DeepSeekTaskExtractionPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.taskExtraction,
            userPrompt: DeepSeekPrompts.userPrompt(
                instruction: """
                请从用户输入中拆分任务，并给出轻量的初始时间建议。输出 json，字段必须符合示例结构。
                默认规划范围是 \(context.defaultSchedule.windowDescription)。如果用户没有指定开始时间，请按输入顺序估算 fixedStart。
                默认休息为：\(context.defaultSchedule.breakDescription)。未指定时间的工作任务不要占用这些休息时段。
                如果用户没有指定耗时，请根据任务内容估算 estimatedDurationMinutes，不要使用机械固定值。
                不同任务允许安排在同一时间；如果输入里有重复或同名任务，请合并成一个任务。
                assumptions 每个任务最多 1 条短句，语言遵循用户输入中的输出语言要求。不要反问用户，不要输出长解释。
                你只需要给建议；最终基础校验和同名任务合并会由本地排程器完成。
                """,
                packedContext: contextPacker.pack(context),
                rawInput: input
            ),
            maxTokens: taskExtractionTokenBudget(for: input)
        )
        return payload.tasks.map(\.taskDraft)
    }

    public func askClarifyingQuestions(context: PlanningContext) async throws -> [String] {
        []
    }

    public func proposeSchedule(context: PlanningContext) async throws -> PlanDraft {
        throw AIPlanningError.invalidResponse("火山方舟当前用于生成任务建议，暂未启用独立时间表草稿接口。")
    }

    public func summarizeDay(plan: DayPlan, logs: [ExecutionLog], outputLanguage: String = "Simplified Chinese") async throws -> String {
        try ensureConfigured()
        let payload: DeepSeekSummaryPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.dayReview,
            userPrompt: DeepSeekPrompts.reviewPrompt(plan: plan, logs: logs, outputLanguage: outputLanguage),
            maxTokens: 1_500
        )
        return payload.summary
    }

    private func ensureConfigured() throws {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIPlanningError.notConfigured
        }
    }

    private func sendJSONRequest<Response: Decodable>(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int
    ) async throws -> Response {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIPlanningError.notConfigured
        }

        let requestPayload = ArkResponsesRequest(
            model: configuration.model,
            input: [
                ArkInputMessage(
                    role: "system",
                    content: [.inputText(systemPrompt)]
                ),
                ArkInputMessage(
                    role: "user",
                    content: [.inputText(userPrompt)]
                )
            ],
            maxOutputTokens: maxTokens,
            temperature: 0.2
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("responses"), timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.deepSeek.encode(requestPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AIPlanningError.httpStatus(httpResponse.statusCode)
        }

        let completion = try JSONDecoder().decode(ArkResponsesResponse.self, from: data)
        guard let content = completion.outputText,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIPlanningError.invalidResponse("火山方舟返回了空内容。")
        }

        let jsonContent = DeepSeekPlanningService.extractJSONObject(from: content) ?? content
        guard let contentData = jsonContent.data(using: .utf8) else {
            throw AIPlanningError.invalidResponse("火山方舟返回内容不是 UTF-8。")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: contentData)
        } catch {
            throw AIPlanningError.invalidResponse(DeepSeekPlanningService.invalidJSONMessage(from: error, content: content, providerName: "火山方舟"))
        }
    }
}

public actor OpenAIPlanningService: AIPlanningService {
    private let configuration: OpenAIConfiguration
    private let contextPacker: PlanningContextPacker

    public init(
        configuration: OpenAIConfiguration,
        contextPacker: PlanningContextPacker = PlanningContextPacker()
    ) {
        self.configuration = configuration
        self.contextPacker = contextPacker
    }

    public func extractTasks(from input: String, context: PlanningContext) async throws -> [TaskDraft] {
        let payload: DeepSeekTaskExtractionPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.taskExtraction,
            userPrompt: DeepSeekPrompts.userPrompt(
                instruction: Self.taskExtractionInstruction(context: context),
                packedContext: contextPacker.pack(context),
                rawInput: input
            ),
            maxTokens: taskExtractionTokenBudget(for: input)
        )
        return payload.tasks.map(\.taskDraft)
    }

    public func askClarifyingQuestions(context: PlanningContext) async throws -> [String] {
        []
    }

    public func proposeSchedule(context: PlanningContext) async throws -> PlanDraft {
        throw AIPlanningError.invalidResponse("OpenAI 当前用于生成任务建议，暂未启用独立时间表草稿接口。")
    }

    public func summarizeDay(plan: DayPlan, logs: [ExecutionLog], outputLanguage: String = "Simplified Chinese") async throws -> String {
        let payload: DeepSeekSummaryPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.dayReview,
            userPrompt: DeepSeekPrompts.reviewPrompt(plan: plan, logs: logs, outputLanguage: outputLanguage),
            maxTokens: 1_500
        )
        return payload.summary
    }

    private func sendJSONRequest<Response: Decodable>(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int
    ) async throws -> Response {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIPlanningError.notConfigured
        }

        let requestPayload = OpenAIChatRequest(
            model: configuration.model,
            messages: [
                OpenAIChatMessage(role: "system", content: systemPrompt),
                OpenAIChatMessage(role: "user", content: userPrompt)
            ],
            responseFormat: OpenAIResponseFormat(type: "json_object"),
            maxCompletionTokens: maxTokens
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("chat/completions"), timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.deepSeek.encode(requestPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AIPlanningError.httpStatus(httpResponse.statusCode)
        }

        let completion = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = completion.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIPlanningError.invalidResponse("OpenAI 返回了空内容。")
        }

        return try Self.decodeJSONPayload(Response.self, providerName: "OpenAI", content: content)
    }
}

public actor GeminiPlanningService: AIPlanningService {
    private let configuration: GeminiConfiguration
    private let contextPacker: PlanningContextPacker

    public init(
        configuration: GeminiConfiguration,
        contextPacker: PlanningContextPacker = PlanningContextPacker()
    ) {
        self.configuration = configuration
        self.contextPacker = contextPacker
    }

    public func extractTasks(from input: String, context: PlanningContext) async throws -> [TaskDraft] {
        let payload: DeepSeekTaskExtractionPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.taskExtraction,
            userPrompt: DeepSeekPrompts.userPrompt(
                instruction: Self.taskExtractionInstruction(context: context),
                packedContext: contextPacker.pack(context),
                rawInput: input
            ),
            maxTokens: taskExtractionTokenBudget(for: input)
        )
        return payload.tasks.map(\.taskDraft)
    }

    public func askClarifyingQuestions(context: PlanningContext) async throws -> [String] {
        []
    }

    public func proposeSchedule(context: PlanningContext) async throws -> PlanDraft {
        throw AIPlanningError.invalidResponse("Gemini 当前用于生成任务建议，暂未启用独立时间表草稿接口。")
    }

    public func summarizeDay(plan: DayPlan, logs: [ExecutionLog], outputLanguage: String = "Simplified Chinese") async throws -> String {
        let payload: DeepSeekSummaryPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.dayReview,
            userPrompt: DeepSeekPrompts.reviewPrompt(plan: plan, logs: logs, outputLanguage: outputLanguage),
            maxTokens: 1_500
        )
        return payload.summary
    }

    private func sendJSONRequest<Response: Decodable>(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int
    ) async throws -> Response {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIPlanningError.notConfigured
        }

        let requestPayload = GeminiGenerateContentRequest(
            systemInstruction: GeminiContent(parts: [GeminiPart(text: systemPrompt)]),
            contents: [
                GeminiContent(
                    role: "user",
                    parts: [GeminiPart(text: userPrompt)]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                responseMimeType: "application/json",
                maxOutputTokens: maxTokens,
                temperature: 0.2
            )
        )

        let modelPath = "v1beta/models/\(configuration.model):generateContent"
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(modelPath), timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder.deepSeek.encode(requestPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AIPlanningError.httpStatus(httpResponse.statusCode)
        }

        let completion = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        guard let content = completion.outputText,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIPlanningError.invalidResponse("Gemini 返回了空内容。")
        }

        return try Self.decodeJSONPayload(Response.self, providerName: "Gemini", content: content)
    }
}

public actor ClaudePlanningService: AIPlanningService {
    private let configuration: ClaudeConfiguration
    private let contextPacker: PlanningContextPacker

    public init(
        configuration: ClaudeConfiguration,
        contextPacker: PlanningContextPacker = PlanningContextPacker()
    ) {
        self.configuration = configuration
        self.contextPacker = contextPacker
    }

    public func extractTasks(from input: String, context: PlanningContext) async throws -> [TaskDraft] {
        let payload: DeepSeekTaskExtractionPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.taskExtraction,
            userPrompt: DeepSeekPrompts.userPrompt(
                instruction: Self.taskExtractionInstruction(context: context),
                packedContext: contextPacker.pack(context),
                rawInput: input
            ),
            maxTokens: taskExtractionTokenBudget(for: input)
        )
        return payload.tasks.map(\.taskDraft)
    }

    public func askClarifyingQuestions(context: PlanningContext) async throws -> [String] {
        []
    }

    public func proposeSchedule(context: PlanningContext) async throws -> PlanDraft {
        throw AIPlanningError.invalidResponse("Claude 当前用于生成任务建议，暂未启用独立时间表草稿接口。")
    }

    public func summarizeDay(plan: DayPlan, logs: [ExecutionLog], outputLanguage: String = "Simplified Chinese") async throws -> String {
        let payload: DeepSeekSummaryPayload = try await sendJSONRequest(
            systemPrompt: DeepSeekPrompts.dayReview,
            userPrompt: DeepSeekPrompts.reviewPrompt(plan: plan, logs: logs, outputLanguage: outputLanguage),
            maxTokens: 1_500
        )
        return payload.summary
    }

    private func sendJSONRequest<Response: Decodable>(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int
    ) async throws -> Response {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIPlanningError.notConfigured
        }

        let requestPayload = ClaudeMessagesRequest(
            model: configuration.model,
            maxTokens: maxTokens,
            temperature: 0.2,
            system: systemPrompt,
            messages: [ClaudeInputMessage(role: "user", content: userPrompt)]
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("v1/messages"), timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder.deepSeek.encode(requestPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AIPlanningError.httpStatus(httpResponse.statusCode)
        }

        let completion = try JSONDecoder().decode(ClaudeMessagesResponse.self, from: data)
        guard let content = completion.outputText,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIPlanningError.invalidResponse("Claude 返回了空内容。")
        }

        return try Self.decodeJSONPayload(Response.self, providerName: "Claude", content: content)
    }
}

private extension AIPlanningService {
    static func taskExtractionInstruction(context: PlanningContext) -> String {
        """
        请从用户输入中拆分任务，并给出轻量的初始时间建议。输出 json，字段必须符合示例结构。
        默认规划范围是 \(context.defaultSchedule.windowDescription)。如果用户没有指定开始时间，请按输入顺序估算 fixedStart。
        默认休息为：\(context.defaultSchedule.breakDescription)。未指定时间的工作任务不要占用这些休息时段。
        如果用户没有指定耗时，请根据任务内容估算 estimatedDurationMinutes，不要使用机械固定值。
        不同任务允许安排在同一时间；如果输入里有重复或同名任务，请合并成一个任务。
        assumptions 每个任务最多 1 条短句，语言遵循用户输入中的输出语言要求。不要反问用户，不要输出长解释。
        你只需要给建议；最终基础校验和同名任务合并会由本地排程器完成。
        """
    }

    static func decodeJSONPayload<Response: Decodable>(
        _ responseType: Response.Type,
        providerName: String,
        content: String
    ) throws -> Response {
        let jsonContent = DeepSeekPlanningService.extractJSONObject(from: content) ?? content
        guard let contentData = jsonContent.data(using: .utf8) else {
            throw AIPlanningError.invalidResponse("\(providerName) 返回内容不是 UTF-8。")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: contentData)
        } catch {
            throw AIPlanningError.invalidResponse(
                DeepSeekPlanningService.invalidJSONMessage(
                    from: error,
                    content: content,
                    providerName: providerName
                )
            )
        }
    }
}

private enum DeepSeekPrompts {
    static let taskExtraction = """
    你是 EfficientTime 的任务拆分模块。
    只返回合法 json，不要包含 markdown。
    为严格时间表拆分任务。
    所有自然语言内容必须使用用户消息里要求的输出语言；如果用户没有指定输出语言，使用简体中文。JSON key 保持英文；枚举值保持下方给定的英文值。
    这是一个“规划建议”任务，不是问答任务。不要反问用户。
    默认规划范围和固定休息以用户消息中的规划配置为准。
    如果用户没有给开始时间，你必须自己估算 fixedStart，并让任务按输入顺序在默认规划范围和可用时间段内不重叠排列。
    除非用户明确指定，不要把任务安排到默认规划范围之外，尤其不要安排在清晨、凌晨或深夜。
    默认休息只作为避让约束；除非用户明确写了吃饭或休息任务，不要额外生成 rest 任务。
    如果用户没有给耗时，你必须根据任务内容估算 estimatedDurationMinutes，例如快速检查 10-20 分钟、阅读/整理 30-90 分钟、深度编码 60-180 分钟、复盘 15-30 分钟。
    每个任务的 assumptions 最多 1 条短句，使用同一种输出语言说明关键估算依据。
    顶层 assumptions 和 clarifyingQuestions 返回空数组。
    JSON 结构：
    {
      "tasks": [
        {
          "title": "string",
          "estimatedDurationMinutes": 30,
          "priority": "low|medium|high|critical",
          "category": "work|study|finance|life|rest|review|other",
          "fixedStart": "HH:mm",
          "earliestStart": "HH:mm or null",
          "latestEnd": "HH:mm or null",
          "canSplit": false,
          "assumptions": ["string"]
        }
      ],
      "assumptions": ["string"],
      "clarifyingQuestions": ["string"]
    }
    """

    static let clarification = """
    你是 EfficientTime 的规划确认模块。
    只返回合法 json，不要包含 markdown。
    在生成严格时间表前，最多提出 3 个需要用户确认的具体问题。
    所有问题必须使用用户消息里要求的输出语言；如果用户没有指定输出语言，使用简体中文。
    JSON 结构：
    { "clarifyingQuestions": ["string"] }
    """

    static let scheduleProposal = """
    你是 EfficientTime 的严格时间表草稿模块。
    只返回合法 json，不要包含 markdown。
    默认规划范围和固定休息以用户消息中的规划配置为准。
    在可用时间段内生成不重叠的时间块草稿；除非用户明确指定，不要把时间块安排到默认规划范围之外。
    默认休息只作为避让约束；除非用户明确写了吃饭或休息任务，不要额外生成休息时间块。
    所有自然语言内容必须使用用户消息里要求的输出语言；如果用户没有指定输出语言，使用简体中文。JSON key 保持英文。
    JSON 结构：
    {
      "blocks": [
        { "title": "string", "start": "HH:mm", "end": "HH:mm" }
      ],
      "unscheduledTaskTitles": ["string"],
      "assumptions": ["string"],
      "clarifyingQuestions": ["string"]
    }
    """

    static let dayReview = """
    你是 EfficientTime 的每日复盘模块。
    只返回合法 json，不要包含 markdown。
    简短、具体、可执行地总结当天执行情况。
    summary 必须全部使用用户消息里要求的输出语言，不要中英混写，不要输出英文事件名、英文原因或英文状态。
    如果输入中出现内部标识，请理解含义后翻译成目标语言再总结，不要原样引用。
    JSON 结构：
    { "summary": "string" }
    """

    static func userPrompt(
        instruction: String,
        packedContext: PackedPlanningContext,
        rawInput: String
    ) -> String {
        let contextData = (try? JSONEncoder.deepSeek.encode(packedContext)) ?? Data()
        let contextJSON = String(data: contextData, encoding: .utf8) ?? "{}"
        return """
        \(instruction)

        上下文 json：
        \(contextJSON)

        用户输入：
        \(rawInput)
        """
    }

    static func reviewPrompt(plan: DayPlan, logs: [ExecutionLog], outputLanguage: String) -> String {
        let review = DeepSeekReviewInput(plan: plan, logs: logs)
        let data = (try? JSONEncoder.deepSeek.encode(review)) ?? Data()
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return """
        请根据下面的复盘输入生成 summary。summary 只能使用 \(outputLanguage)。

        复盘输入 json：
        \(json)
        """
    }
}

private struct DeepSeekChatRequest: Encodable {
    var model: String
    var messages: [DeepSeekChatMessage]
    var thinking: DeepSeekThinking
    var responseFormat: DeepSeekResponseFormat
    var maxTokens: Int
    var temperature: Double

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case thinking
        case responseFormat = "response_format"
        case maxTokens = "max_tokens"
        case temperature
    }
}

private struct DeepSeekChatMessage: Codable {
    var role: String
    var content: String
}

private struct DeepSeekThinking: Encodable {
    var type: String
    var reasoningEffort: String?

    init(effort: PlanningEffort) {
        switch effort {
        case .fast:
            self.type = "disabled"
            self.reasoningEffort = nil
        case .normal:
            self.type = "disabled"
            self.reasoningEffort = nil
        case .deep:
            self.type = "enabled"
            self.reasoningEffort = "max"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case reasoningEffort = "reasoning_effort"
    }
}

private struct DeepSeekResponseFormat: Codable {
    var type: String
}

private struct DeepSeekChatResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String?
    }
}

private struct ArkResponsesRequest: Encodable {
    var model: String
    var input: [ArkInputMessage]
    var maxOutputTokens: Int
    var temperature: Double

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case maxOutputTokens = "max_output_tokens"
        case temperature
    }
}

private struct ArkInputMessage: Encodable {
    var role: String
    var content: [ArkInputContent]
}

private enum ArkInputContent: Encodable {
    case inputText(String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .inputText(text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        }
    }
}

private struct ArkResponsesResponse: Decodable {
    var output: [OutputItem]?
    var outputTextField: String?

    var outputText: String? {
        if let outputTextField {
            return outputTextField
        }
        return output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
    }

    enum CodingKeys: String, CodingKey {
        case output
        case outputTextField = "output_text"
    }

    struct OutputItem: Decodable {
        var content: [ContentItem]?
    }

    struct ContentItem: Decodable {
        var type: String?
        var text: String?
    }
}

private struct OpenAIChatRequest: Encodable {
    var model: String
    var messages: [OpenAIChatMessage]
    var responseFormat: OpenAIResponseFormat
    var maxCompletionTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
        case maxCompletionTokens = "max_completion_tokens"
    }
}

private struct OpenAIChatMessage: Codable {
    var role: String
    var content: String
}

private struct OpenAIResponseFormat: Codable {
    var type: String
}

private struct OpenAIChatResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String?
    }
}

private struct GeminiGenerateContentRequest: Encodable {
    var systemInstruction: GeminiContent
    var contents: [GeminiContent]
    var generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Encodable {
    var role: String?
    var parts: [GeminiPart]

    init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}

private struct GeminiPart: Codable {
    var text: String
}

private struct GeminiGenerationConfig: Encodable {
    var responseMimeType: String
    var maxOutputTokens: Int
    var temperature: Double
}

private struct GeminiGenerateContentResponse: Decodable {
    var candidates: [Candidate]

    var outputText: String? {
        candidates.first?.content.parts.map(\.text).joined(separator: "\n")
    }

    struct Candidate: Decodable {
        var content: Content
    }

    struct Content: Decodable {
        var parts: [GeminiPart]
    }
}

private struct ClaudeMessagesRequest: Encodable {
    var model: String
    var maxTokens: Int
    var temperature: Double
    var system: String
    var messages: [ClaudeInputMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case temperature
        case system
        case messages
    }
}

private struct ClaudeInputMessage: Encodable {
    var role: String
    var content: String
}

private struct ClaudeMessagesResponse: Decodable {
    var content: [ClaudeContentBlock]

    var outputText: String? {
        content.compactMap(\.text).joined(separator: "\n")
    }
}

private struct ClaudeContentBlock: Decodable {
    var type: String
    var text: String?
}

private struct DeepSeekTaskExtractionPayload: Decodable {
    var tasks: [DeepSeekTaskDraftPayload]
    var assumptions: [String]?
    var clarifyingQuestions: [String]?
}

private struct DeepSeekTaskDraftPayload: Decodable {
    var title: String
    var estimatedDurationMinutes: Int
    var priority: String
    var category: String
    var fixedStart: String?
    var earliestStart: String?
    var latestEnd: String?
    var canSplit: Bool
    var assumptions: [String]

    var taskDraft: TaskDraft {
        TaskDraft(
            title: title,
            estimatedDurationMinutes: max(5, estimatedDurationMinutes),
            priority: TaskPriority(rawValue: priority) ?? .medium,
            category: TaskCategory(rawValue: category) ?? .other,
            fixedStart: try? fixedStart.flatMap(ClockTime.init(parsing:)),
            earliestStart: try? earliestStart.flatMap(ClockTime.init(parsing:)),
            latestEnd: try? latestEnd.flatMap(ClockTime.init(parsing:)),
            canSplit: canSplit,
            assumptions: assumptions
        )
    }
}

private struct DeepSeekClarificationPayload: Decodable {
    var clarifyingQuestions: [String]
}

private struct DeepSeekPlanDraftPayload: Decodable {
    var blocks: [Block]
    var unscheduledTaskTitles: [String]
    var assumptions: [String]
    var clarifyingQuestions: [String]

    struct Block: Decodable {
        var title: String
        var start: String
        var end: String
    }

    func planDraft(date: LocalDate) throws -> PlanDraft {
        let parsedBlocks = try blocks.map {
            TimeBlock(
                taskId: nil,
                title: $0.title,
                start: try ClockTime(parsing: $0.start),
                end: try ClockTime(parsing: $0.end)
            )
        }
        return PlanDraft(
            date: date,
            blocks: parsedBlocks,
            unscheduledTaskTitles: unscheduledTaskTitles,
            assumptions: assumptions,
            clarifyingQuestions: clarifyingQuestions
        )
    }
}

private struct DeepSeekSummaryPayload: Decodable {
    var summary: String
}

private struct DeepSeekReviewInput: Codable {
    var date: LocalDate
    var blocks: [ReviewBlock]
    var logs: [ReviewLog]

    init(plan: DayPlan, logs: [ExecutionLog]) {
        self.date = plan.date
        self.blocks = plan.blocks.map(ReviewBlock.init)
        let blockTitles = Dictionary(uniqueKeysWithValues: plan.blocks.map { ($0.id, $0.title) })
        self.logs = logs.map { log in
            ReviewLog(log: log, blockTitle: blockTitles[log.blockId] ?? "未知任务")
        }
    }
}

private struct ReviewBlock: Codable {
    var title: String
    var start: String
    var end: String
    var status: String
    var plannedMinutes: Int
    var actualStartRecorded: Bool
    var actualEndRecorded: Bool

    init(block: TimeBlock) {
        self.title = block.title
        self.start = block.start.displayString
        self.end = block.end.displayString
        self.status = Self.statusTitle(block.status)
        self.plannedMinutes = block.durationMinutes
        self.actualStartRecorded = block.actualStartAt != nil
        self.actualEndRecorded = block.actualEndAt != nil
    }

    private static func statusTitle(_ status: TimeBlockStatus) -> String {
        switch status {
        case .planned: "待开始"
        case .active: "进行中"
        case .done: "已完成"
        case .skipped: "已跳过"
        case .delayed: "已推迟"
        case .interrupted: "已中断"
        case .deleted: "已删除"
        }
    }
}

private struct ReviewLog: Codable {
    var blockTitle: String
    var event: String
    var details: [String]

    init(log: ExecutionLog, blockTitle: String) {
        self.blockTitle = blockTitle
        self.event = Self.eventTitle(log.eventType)
        self.details = log.payload.map { key, value in
            Self.detailText(key: key, value: value)
        }
    }

    private static func eventTitle(_ eventType: ExecutionEventType) -> String {
        switch eventType {
        case .started: "开始"
        case .completed: "完成"
        case .skipped: "跳过"
        case .delayed: "推迟"
        case .extended: "延长"
        case .interrupted: "中断"
        case .replanned: "重新规划"
        case .notified: "提醒"
        }
    }

    private static func detailText(key: String, value: String) -> String {
        switch (key, value) {
        case ("scope", "day"):
            return "范围：全天"
        case ("reason", "manual"):
            return "原因：手动重新规划"
        case ("reason", "ai-draft-applied"):
            return "原因：应用 AI 草稿"
        case ("reason", "delete"):
            return "原因：删除任务"
        case ("reason", let reason):
            return "原因：\(reason)"
        default:
            return "\(key)：\(value)"
        }
    }
}

private extension JSONEncoder {
    static var deepSeek: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

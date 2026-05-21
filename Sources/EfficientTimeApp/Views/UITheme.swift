import EfficientTimeCore
import SwiftUI

enum AppTheme: String, Codable, CaseIterable, Sendable {
    case teal
    case pink
    case mint
    case graphite

    var title: String {
        switch self {
        case .teal: "青蓝"
        case .pink: "柔粉"
        case .mint: "薄荷"
        case .graphite: "石墨"
        }
    }
}

enum FloatingPanelAppearance: String, Codable, CaseIterable, Sendable {
    case mint
    case pink
    case sky
    case lavender
    case system

    var title: String {
        switch self {
        case .mint: "浅绿色"
        case .pink: "粉红色"
        case .sky: "浅蓝色"
        case .lavender: "淡紫色"
        case .system: "系统色"
        }
    }
}

enum CountdownStyle: String, Codable, CaseIterable, Sendable {
    case vivid
    case mint
    case sunset
    case candy

    var title: String {
        switch self {
        case .vivid: "活力青蓝"
        case .mint: "清亮薄荷"
        case .sunset: "明亮日落"
        case .candy: "糖果粉蓝"
        }
    }
}

enum AIProvider: String, Codable, CaseIterable, Sendable {
    case deepSeek
    case ark

    var title: String {
        switch self {
        case .deepSeek: "DeepSeek"
        case .ark: "火山方舟"
        }
    }

    var apiKeyHint: String {
        switch self {
        case .deepSeek: "粘贴 DeepSeek API Key（sk-...）"
        case .ark: "粘贴火山方舟 API Key（ARK_API_KEY）"
        }
    }
}

extension AppSettings {
    var accentColor: Color {
        switch theme {
        case .teal: Color(red: 0.07, green: 0.48, blue: 0.58)
        case .pink: Color(red: 0.86, green: 0.32, blue: 0.52)
        case .mint: Color(red: 0.20, green: 0.56, blue: 0.43)
        case .graphite: Color(red: 0.24, green: 0.27, blue: 0.31)
        }
    }

    var pageBackground: Color {
        switch theme {
        case .teal: Color(red: 0.94, green: 0.98, blue: 0.98)
        case .pink: Color(red: 1.0, green: 0.95, blue: 0.97)
        case .mint: Color(red: 0.94, green: 0.98, blue: 0.95)
        case .graphite: Color(red: 0.96, green: 0.97, blue: 0.98)
        }
    }

    var floatingPanelBackground: Color {
        switch floatingPanelAppearance {
        case .mint: Color(red: 0.80, green: 0.96, blue: 0.83)
        case .pink: Color(red: 1.00, green: 0.84, blue: 0.91)
        case .sky: Color(red: 0.82, green: 0.92, blue: 1.00)
        case .lavender: Color(red: 0.89, green: 0.86, blue: 1.00)
        case .system: Color(nsColor: .windowBackgroundColor)
        }
    }

    var floatingPanelHeaderBackground: Color {
        switch floatingPanelAppearance {
        case .mint: Color(red: 0.66, green: 0.91, blue: 0.72)
        case .pink: Color(red: 1.00, green: 0.70, blue: 0.83)
        case .sky: Color(red: 0.68, green: 0.86, blue: 1.00)
        case .lavender: Color(red: 0.79, green: 0.74, blue: 1.00)
        case .system: Color(nsColor: .controlBackgroundColor)
        }
    }

    var floatingPanelRowBackground: Color {
        switch floatingPanelAppearance {
        case .system: Color(nsColor: .controlBackgroundColor)
        default: Color.white.opacity(0.62)
        }
    }

    var floatingPanelBorderColor: Color {
        switch floatingPanelAppearance {
        case .system: Color(nsColor: .separatorColor).opacity(0.5)
        default: Color.black.opacity(0.14)
        }
    }
}

extension TimeBlockStatus {
    var title: String {
        switch self {
        case .planned: "待开始"
        case .active: "进行中"
        case .done: "已完成"
        case .skipped: "已跳过"
        case .delayed: "已推迟"
        case .interrupted: "已中断"
        }
    }

    var tint: Color {
        switch self {
        case .planned: .blue
        case .active: .orange
        case .done: .green
        case .skipped: .gray
        case .delayed: .purple
        case .interrupted: .red
        }
    }

    var softBackground: Color {
        tint.opacity(0.12)
    }
}

extension DayPlanStatus {
    var title: String {
        switch self {
        case .draft: "草稿"
        case .ready: "已确认"
        case .running: "执行中"
        case .finished: "已结束"
        case .archived: "已归档"
        }
    }
}

extension PlanningEffort {
    var title: String {
        switch self {
        case .fast: "快速"
        case .normal: "标准"
        case .deep: "深入"
        }
    }
}

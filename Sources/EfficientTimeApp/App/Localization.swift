import Foundation
import EfficientTimeCore

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case zhHans
    case en
    case ja
    case ko
    case fr
    case de
    case es

    var id: String { rawValue }

    var settingsTitle: String {
        switch self {
        case .system: "System"
        case .zhHans: "简体中文"
        case .en: "English"
        case .ja: "日本語"
        case .ko: "한국어"
        case .fr: "Français"
        case .de: "Deutsch"
        case .es: "Español"
        }
    }

    var localeIdentifier: String {
        switch resolved {
        case .system: "en"
        case .zhHans: "zh-Hans"
        case .en: "en"
        case .ja: "ja"
        case .ko: "ko"
        case .fr: "fr"
        case .de: "de"
        case .es: "es"
        }
    }

    var aiInstructionName: String {
        switch resolved {
        case .system: "English"
        case .zhHans: "Simplified Chinese"
        case .en: "English"
        case .ja: "Japanese"
        case .ko: "Korean"
        case .fr: "French"
        case .de: "German"
        case .es: "Spanish"
        }
    }

    var resolved: AppLanguage {
        guard self == .system else { return self }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("zh") { return .zhHans }
        if preferred.hasPrefix("ja") { return .ja }
        if preferred.hasPrefix("ko") { return .ko }
        if preferred.hasPrefix("fr") { return .fr }
        if preferred.hasPrefix("de") { return .de }
        if preferred.hasPrefix("es") { return .es }
        return .en
    }
}

enum AppLocalization {
    static func text(_ key: String, language: AppLanguage) -> String {
        let resolved = language.resolved
        if resolved == .zhHans { return key }
        return translations[key]?[resolved] ?? translations[key]?[.en] ?? key
    }

    static func format(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        format(key, language: language, arguments: arguments)
    }

    static func format(_ key: String, language: AppLanguage, arguments: [CVarArg]) -> String {
        String(format: text(key, language: language), locale: Locale(identifier: language.localeIdentifier), arguments: arguments)
    }

    static func weekdayTitle(for date: LocalDate, language: AppLanguage) -> String {
        let weekday = Calendar.current.component(.weekday, from: date.date())
        let titles: [AppLanguage: [String]] = [
            .zhHans: ["周日", "周一", "周二", "周三", "周四", "周五", "周六"],
            .en: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
            .ja: ["日", "月", "火", "水", "木", "金", "土"],
            .ko: ["일", "월", "화", "수", "목", "금", "토"],
            .fr: ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."],
            .de: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"],
            .es: ["dom.", "lun.", "mar.", "mié.", "jue.", "vie.", "sáb."]
        ]
        let resolved = language.resolved
        return titles[resolved]?[safe: weekday - 1] ?? titles[.en]?[safe: weekday - 1] ?? ""
    }

    static func shortWeekdayTitles(language: AppLanguage) -> [String] {
        switch language.resolved {
        case .system, .en: ["S", "M", "T", "W", "T", "F", "S"]
        case .zhHans: ["日", "一", "二", "三", "四", "五", "六"]
        case .ja: ["日", "月", "火", "水", "木", "金", "土"]
        case .ko: ["일", "월", "화", "수", "목", "금", "토"]
        case .fr: ["D", "L", "M", "M", "J", "V", "S"]
        case .de: ["S", "M", "D", "M", "D", "F", "S"]
        case .es: ["D", "L", "M", "X", "J", "V", "S"]
        }
    }

    static func itemCount(_ count: Int, language: AppLanguage) -> String {
        switch language.resolved {
        case .zhHans: "\(count) 项"
        case .ja: "\(count) 件"
        case .ko: "\(count)개"
        case .fr: "\(count) élément\(count > 1 ? "s" : "")"
        case .de: "\(count) Element\(count == 1 ? "" : "e")"
        case .es: "\(count) elemento\(count == 1 ? "" : "s")"
        case .system, .en: "\(count) item\(count == 1 ? "" : "s")"
        }
    }

    static func minutes(_ minutes: Int, language: AppLanguage) -> String {
        switch language.resolved {
        case .zhHans: "\(minutes) 分钟"
        case .ja: "\(minutes) 分"
        case .ko: "\(minutes)분"
        case .fr: "\(minutes) min"
        case .de: "\(minutes) Min."
        case .es: "\(minutes) min"
        case .system, .en: "\(minutes) min"
        }
    }

    static func duration(seconds: Int, language: AppLanguage) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            if remainingMinutes == 0 {
                return hoursText(hours, language: language)
            }
            return "\(hoursText(hours, language: language)) \(minutes(remainingMinutes, language: language))"
        }
        if seconds >= 60 {
            let minutesValue = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return minutes(minutesValue, language: language)
            }
            return "\(minutes(minutesValue, language: language)) \(secondsText(remainingSeconds, language: language))"
        }
        return secondsText(seconds, language: language)
    }

    static func statusTitle(_ status: TimeBlockStatus, language: AppLanguage) -> String {
        switch status {
        case .planned: text("待开始", language: language)
        case .active: text("进行中", language: language)
        case .done: text("已完成", language: language)
        case .skipped: text("已跳过", language: language)
        case .delayed: text("已推迟", language: language)
        case .interrupted: text("已中断", language: language)
        case .deleted: text("已删除", language: language)
        }
    }

    static func planStatusTitle(_ status: DayPlanStatus, language: AppLanguage) -> String {
        switch status {
        case .draft: text("草稿", language: language)
        case .ready: text("已确认", language: language)
        case .running: text("执行中", language: language)
        case .finished: text("已结束", language: language)
        case .archived: text("已归档", language: language)
        }
    }

    private static func hoursText(_ hours: Int, language: AppLanguage) -> String {
        switch language.resolved {
        case .zhHans: "\(hours) 小时"
        case .ja: "\(hours) 時間"
        case .ko: "\(hours)시간"
        case .fr: "\(hours) h"
        case .de: "\(hours) Std."
        case .es: "\(hours) h"
        case .system, .en: "\(hours) hr"
        }
    }

    private static func secondsText(_ seconds: Int, language: AppLanguage) -> String {
        switch language.resolved {
        case .zhHans: "\(seconds) 秒"
        case .ja: "\(seconds) 秒"
        case .ko: "\(seconds)초"
        case .fr: "\(seconds) s"
        case .de: "\(seconds) Sek."
        case .es: "\(seconds) s"
        case .system, .en: "\(seconds) sec"
        }
    }

    private static let translations: [String: [AppLanguage: String]] = [
        "计划": [.en: "Plan", .ja: "計画", .ko: "계획", .fr: "Planning", .de: "Plan", .es: "Plan"],
        "智能规划": [.en: "AI Plan", .ja: "AI 計画", .ko: "AI 계획", .fr: "Plan IA", .de: "KI-Plan", .es: "Plan IA"],
        "复盘": [.en: "Review", .ja: "振り返り", .ko: "회고", .fr: "Bilan", .de: "Review", .es: "Revisión"],
        "设置": [.en: "Settings", .ja: "設定", .ko: "설정", .fr: "Réglages", .de: "Einstellungen", .es: "Ajustes"],
        "语言": [.en: "Language", .ja: "言語", .ko: "언어", .fr: "Langue", .de: "Sprache", .es: "Idioma"],
        "界面语言": [.en: "Interface language", .ja: "表示言語", .ko: "인터페이스 언어", .fr: "Langue de l'interface", .de: "Oberflächensprache", .es: "Idioma de la interfaz"],
        "语言会影响界面、提醒和 AI 输出语言。": [.en: "Language affects the interface, reminders, and AI output.", .ja: "言語は画面、通知、AI 出力に反映されます。", .ko: "언어는 화면, 알림, AI 출력에 적용됩니다.", .fr: "La langue s'applique à l'interface, aux rappels et aux sorties IA.", .de: "Die Sprache gilt für Oberfläche, Erinnerungen und KI-Ausgaben.", .es: "El idioma afecta a la interfaz, los recordatorios y la salida de IA."],
        "外观": [.en: "Appearance", .ja: "外観", .ko: "외관", .fr: "Apparence", .de: "Darstellung", .es: "Apariencia"],
        "主题色": [.en: "Theme color", .ja: "テーマカラー", .ko: "테마 색상", .fr: "Couleur du thème", .de: "Designfarbe", .es: "Color del tema"],
        "青蓝": [.en: "Teal", .ja: "ティール", .ko: "청록", .fr: "Bleu-vert", .de: "Türkis", .es: "Verde azulado"],
        "柔粉": [.en: "Soft pink", .ja: "ソフトピンク", .ko: "소프트 핑크", .fr: "Rose doux", .de: "Weiches Pink", .es: "Rosa suave"],
        "薄荷": [.en: "Mint", .ja: "ミント", .ko: "민트", .fr: "Menthe", .de: "Mint", .es: "Menta"],
        "石墨": [.en: "Graphite", .ja: "グラファイト", .ko: "그래파이트", .fr: "Graphite", .de: "Graphit", .es: "Grafito"],
        "浅绿色": [.en: "Light green", .ja: "ライトグリーン", .ko: "연녹색", .fr: "Vert clair", .de: "Hellgrün", .es: "Verde claro"],
        "粉红色": [.en: "Pink", .ja: "ピンク", .ko: "분홍", .fr: "Rose", .de: "Pink", .es: "Rosa"],
        "浅蓝色": [.en: "Light blue", .ja: "ライトブルー", .ko: "연파랑", .fr: "Bleu clair", .de: "Hellblau", .es: "Azul claro"],
        "淡紫色": [.en: "Lavender", .ja: "ラベンダー", .ko: "라벤더", .fr: "Lavande", .de: "Lavendel", .es: "Lavanda"],
        "系统色": [.en: "System", .ja: "システム", .ko: "시스템", .fr: "Système", .de: "System", .es: "Sistema"],
        "活力青蓝": [.en: "Vivid cyan", .ja: "鮮やかシアン", .ko: "선명한 청록", .fr: "Cyan vif", .de: "Lebendiges Cyan", .es: "Cian vivo"],
        "清亮薄荷": [.en: "Bright mint", .ja: "明るいミント", .ko: "밝은 민트", .fr: "Menthe vive", .de: "Helles Mint", .es: "Menta brillante"],
        "明亮日落": [.en: "Bright sunset", .ja: "明るい夕焼け", .ko: "밝은 석양", .fr: "Coucher lumineux", .de: "Heller Sonnenuntergang", .es: "Atardecer brillante"],
        "糖果粉蓝": [.en: "Candy blue-pink", .ja: "キャンディブルーピンク", .ko: "캔디 핑크 블루", .fr: "Bonbon rose bleu", .de: "Candy Blau-Pink", .es: "Caramelo azul rosa"],
        "快速": [.en: "Fast", .ja: "高速", .ko: "빠름", .fr: "Rapide", .de: "Schnell", .es: "Rápido"],
        "标准": [.en: "Standard", .ja: "標準", .ko: "표준", .fr: "Standard", .de: "Standard", .es: "Estándar"],
        "深入": [.en: "Deep", .ja: "詳細", .ko: "심층", .fr: "Approfondi", .de: "Tief", .es: "Profundo"],
        "AI 服务商": [.en: "AI provider", .ja: "AI プロバイダー", .ko: "AI 제공자", .fr: "Fournisseur IA", .de: "KI-Anbieter", .es: "Proveedor IA"],
        "当前服务商": [.en: "Current provider", .ja: "現在のプロバイダー", .ko: "현재 제공자", .fr: "Fournisseur actuel", .de: "Aktueller Anbieter", .es: "Proveedor actual"],
        "AI 默认规划": [.en: "AI planning defaults", .ja: "AI 計画の既定値", .ko: "AI 계획 기본값", .fr: "Réglages par défaut IA", .de: "KI-Planungsstandard", .es: "Valores predeterminados IA"],
        "开始": [.en: "Start", .ja: "開始", .ko: "시작", .fr: "Début", .de: "Start", .es: "Inicio"],
        "结束": [.en: "End", .ja: "終了", .ko: "종료", .fr: "Fin", .de: "Ende", .es: "Fin"],
        "午饭": [.en: "Lunch", .ja: "昼食", .ko: "점심", .fr: "Déjeuner", .de: "Mittagessen", .es: "Almuerzo"],
        "晚饭": [.en: "Dinner", .ja: "夕食", .ko: "저녁", .fr: "Dîner", .de: "Abendessen", .es: "Cena"],
        "恢复默认选项": [.en: "Restore defaults", .ja: "既定値に戻す", .ko: "기본값 복원", .fr: "Restaurer", .de: "Standard wiederherstellen", .es: "Restaurar valores"],
        "%@ 配置": [.en: "%@ configuration", .ja: "%@ 設定", .ko: "%@ 설정", .fr: "Configuration %@", .de: "%@-Konfiguration", .es: "Configuración de %@"],
        "DeepSeek 配置": [.en: "DeepSeek configuration", .ja: "DeepSeek 設定", .ko: "DeepSeek 설정", .fr: "Configuration DeepSeek", .de: "DeepSeek-Konfiguration", .es: "Configuración DeepSeek"],
        "火山方舟配置": [.en: "Volcengine Ark configuration", .ja: "Volcengine Ark 設定", .ko: "화산 Ark 설정", .fr: "Configuration Volcengine Ark", .de: "Volcengine-Ark-Konfiguration", .es: "Configuración Volcengine Ark"],
        "粘贴 DeepSeek API Key（sk-...）": [.en: "Paste DeepSeek API Key (sk-...)", .ja: "DeepSeek API Key（sk-...）を貼り付け", .ko: "DeepSeek API Key(sk-...) 붙여넣기", .fr: "Collez la clé API DeepSeek (sk-...)", .de: "DeepSeek API Key einfügen (sk-...)", .es: "Pega la API Key de DeepSeek (sk-...)"],
        "粘贴火山方舟 API Key（ARK_API_KEY）": [.en: "Paste Volcengine Ark API Key (ARK_API_KEY)", .ja: "Volcengine Ark API Key（ARK_API_KEY）を貼り付け", .ko: "Volcengine Ark API Key(ARK_API_KEY) 붙여넣기", .fr: "Collez la clé API Volcengine Ark (ARK_API_KEY)", .de: "Volcengine Ark API Key einfügen (ARK_API_KEY)", .es: "Pega la API Key de Volcengine Ark (ARK_API_KEY)"],
        "粘贴 OpenAI API Key（sk-...）": [.en: "Paste OpenAI API Key (sk-...)", .ja: "OpenAI API Key（sk-...）を貼り付け", .ko: "OpenAI API Key(sk-...) 붙여넣기", .fr: "Collez la clé API OpenAI (sk-...)", .de: "OpenAI API Key einfügen (sk-...)", .es: "Pega la API Key de OpenAI (sk-...)"],
        "粘贴 Gemini API Key（AIza...）": [.en: "Paste Gemini API Key (AIza...)", .ja: "Gemini API Key（AIza...）を貼り付け", .ko: "Gemini API Key(AIza...) 붙여넣기", .fr: "Collez la clé API Gemini (AIza...)", .de: "Gemini API Key einfügen (AIza...)", .es: "Pega la API Key de Gemini (AIza...)"],
        "粘贴 Claude API Key（sk-ant-...）": [.en: "Paste Claude API Key (sk-ant-...)", .ja: "Claude API Key（sk-ant-...）を貼り付け", .ko: "Claude API Key(sk-ant-...) 붙여넣기", .fr: "Collez la clé API Claude (sk-ant-...)", .de: "Claude API Key einfügen (sk-ant-...)", .es: "Pega la API Key de Claude (sk-ant-...)"],
        "尚未配置 %@ API Key。选择 %@ 作为服务商后，需要先填写这里并保存。": [.en: "%@ API Key is not configured. If %@ is selected, fill this in and save first.", .ja: "%@ API Key が未設定です。%@ を選ぶ場合はここに入力して保存してください。", .ko: "%@ API Key가 설정되지 않았습니다. %@를 선택하려면 먼저 입력하고 저장하세요.", .fr: "La clé API %@ n'est pas configurée. Si %@ est sélectionné, renseignez-la puis enregistrez.", .de: "%@ API Key ist nicht konfiguriert. Wenn %@ ausgewählt ist, hier eintragen und speichern.", .es: "La API Key de %@ no está configurada. Si eliges %@, rellénala y guarda."],
        "%@ API Key 已填写。点击底部“保存设置”后会保存在本机配置中。": [.en: "%@ API Key is filled in. Click “Save settings” to store it locally.", .ja: "%@ API Key は入力済みです。「設定を保存」でローカルに保存されます。", .ko: "%@ API Key가 입력되었습니다. “설정 저장”을 누르면 로컬에 저장됩니다.", .fr: "La clé API %@ est renseignée. Cliquez sur Enregistrer pour la stocker localement.", .de: "%@ API Key ist eingetragen. Klicken Sie auf „Einstellungen speichern“, um sie lokal zu speichern.", .es: "La API Key de %@ está rellenada. Pulsa “Guardar ajustes” para guardarla localmente."],
        "模型": [.en: "Model", .ja: "モデル", .ko: "모델", .fr: "Modèle", .de: "Modell", .es: "Modelo"],
        "常用模型": [.en: "Common model", .ja: "よく使うモデル", .ko: "일반 모델", .fr: "Modèle courant", .de: "Häufiges Modell", .es: "Modelo común"],
        "模型 ID": [.en: "Model ID", .ja: "モデル ID", .ko: "모델 ID", .fr: "ID du modèle", .de: "Modell-ID", .es: "ID del modelo"],
        "默认使用 deepseek-v4-flash；深入模式会启用 DeepSeek 的 thinking 参数。": [.en: "Defaults to deepseek-v4-flash; Deep mode enables DeepSeek thinking.", .ja: "既定は deepseek-v4-flash。詳細モードでは DeepSeek thinking を有効にします。", .ko: "기본값은 deepseek-v4-flash이며, 심층 모드는 DeepSeek thinking을 켭니다.", .fr: "Par défaut : deepseek-v4-flash ; le mode approfondi active thinking.", .de: "Standard: deepseek-v4-flash; Tief aktiviert DeepSeek thinking.", .es: "Predeterminado: deepseek-v4-flash; el modo profundo activa thinking."],
        "默认使用 doubao-seed-2-0-pro-260215，通过火山方舟 Responses API 调用。": [.en: "Defaults to doubao-seed-2-0-pro-260215 via the Volcengine Ark Responses API.", .ja: "既定は doubao-seed-2-0-pro-260215、Volcengine Ark Responses API 経由です。", .ko: "기본값은 doubao-seed-2-0-pro-260215이며 Volcengine Ark Responses API를 사용합니다.", .fr: "Par défaut : doubao-seed-2-0-pro-260215 via l'API Responses Volcengine Ark.", .de: "Standard: doubao-seed-2-0-pro-260215 über die Volcengine Ark Responses API.", .es: "Predeterminado: doubao-seed-2-0-pro-260215 mediante la API Responses de Volcengine Ark."],
        "默认使用 gpt-5.4-mini，通过 OpenAI Chat Completions API 调用。": [.en: "Defaults to gpt-5.4-mini via the OpenAI Chat Completions API.", .ja: "既定は gpt-5.4-mini、OpenAI Chat Completions API 経由です。", .ko: "기본값은 gpt-5.4-mini이며 OpenAI Chat Completions API를 사용합니다.", .fr: "Par défaut : gpt-5.4-mini via l'API Chat Completions OpenAI.", .de: "Standard: gpt-5.4-mini über die OpenAI Chat Completions API.", .es: "Predeterminado: gpt-5.4-mini mediante la API Chat Completions de OpenAI."],
        "默认使用 gemini-3.5-flash，通过 Gemini generateContent API 调用。": [.en: "Defaults to gemini-3.5-flash via the Gemini generateContent API.", .ja: "既定は gemini-3.5-flash、Gemini generateContent API 経由です。", .ko: "기본값은 gemini-3.5-flash이며 Gemini generateContent API를 사용합니다.", .fr: "Par défaut : gemini-3.5-flash via l'API generateContent Gemini.", .de: "Standard: gemini-3.5-flash über die Gemini generateContent API.", .es: "Predeterminado: gemini-3.5-flash mediante la API generateContent de Gemini."],
        "默认使用 claude-sonnet-4-6，通过 Claude Messages API 调用。": [.en: "Defaults to claude-sonnet-4-6 via the Claude Messages API.", .ja: "既定は claude-sonnet-4-6、Claude Messages API 経由です。", .ko: "기본값은 claude-sonnet-4-6이며 Claude Messages API를 사용합니다.", .fr: "Par défaut : claude-sonnet-4-6 via l'API Messages Claude.", .de: "Standard: claude-sonnet-4-6 über die Claude Messages API.", .es: "Predeterminado: claude-sonnet-4-6 mediante la API Messages de Claude."],
        "悬浮窗": [.en: "Floating panel", .ja: "フローティングパネル", .ko: "플로팅 패널", .fr: "Panneau flottant", .de: "Schwebefenster", .es: "Panel flotante"],
        "背景颜色": [.en: "Background color", .ja: "背景色", .ko: "배경색", .fr: "Couleur de fond", .de: "Hintergrundfarbe", .es: "Color de fondo"],
        "倒计时样式": [.en: "Countdown style", .ja: "カウントダウン形式", .ko: "카운트다운 스타일", .fr: "Style du compte à rebours", .de: "Countdown-Stil", .es: "Estilo de cuenta atrás"],
        "透明度 %d%%": [.en: "Opacity %d%%", .ja: "透明度 %d%%", .ko: "투명도 %d%%", .fr: "Opacité %d %%", .de: "Deckkraft %d %%", .es: "Opacidad %d %%"],
        "显示前 %d 个": [.en: "Show %d before", .ja: "前を %d 件表示", .ko: "이전 %d개 표시", .fr: "Afficher %d avant", .de: "%d vorher anzeigen", .es: "Mostrar %d anteriores"],
        "显示后 %d 个": [.en: "Show %d after", .ja: "後を %d 件表示", .ko: "이후 %d개 표시", .fr: "Afficher %d après", .de: "%d danach anzeigen", .es: "Mostrar %d posteriores"],
        "提醒": [.en: "Reminders", .ja: "リマインダー", .ko: "알림", .fr: "Rappels", .de: "Erinnerungen", .es: "Recordatorios"],
        "系统通知权限": [.en: "System notification permission", .ja: "システム通知権限", .ko: "시스템 알림 권한", .fr: "Autorisation de notification", .de: "Benachrichtigungsrecht", .es: "Permiso de notificaciones"],
        "申请系统通知权限": [.en: "Request notification permission", .ja: "通知権限を要求", .ko: "알림 권한 요청", .fr: "Demander l'autorisation", .de: "Benachrichtigungen erlauben", .es: "Solicitar permiso"],
        "发送测试通知": [.en: "Send test notification", .ja: "テスト通知を送信", .ko: "테스트 알림 보내기", .fr: "Envoyer un test", .de: "Test senden", .es: "Enviar prueba"],
        "任务开始提醒": [.en: "Task start reminders", .ja: "タスク開始通知", .ko: "작업 시작 알림", .fr: "Rappels de début", .de: "Start-Erinnerungen", .es: "Avisos de inicio"],
        "任务结束提醒": [.en: "Task end reminders", .ja: "タスク終了通知", .ko: "작업 종료 알림", .fr: "Rappels de fin", .de: "End-Erinnerungen", .es: "Avisos de fin"],
        "提前 %d 分钟提醒": [.en: "Remind %d min early", .ja: "%d 分前に通知", .ko: "%d분 전 알림", .fr: "Rappeler %d min avant", .de: "%d Min. vorher erinnern", .es: "Avisar %d min antes"],
        "提醒规划明天": [.en: "Remind me to plan tomorrow", .ja: "明日の計画を通知", .ko: "내일 계획 알림", .fr: "Rappeler de planifier demain", .de: "An Morgenplanung erinnern", .es: "Recordar planificar mañana"],
        "保存设置": [.en: "Save settings", .ja: "設定を保存", .ko: "설정 저장", .fr: "Enregistrer", .de: "Einstellungen speichern", .es: "Guardar ajustes"],
        "设置已保存。": [.en: "Settings saved.", .ja: "設定を保存しました。", .ko: "설정이 저장되었습니다.", .fr: "Réglages enregistrés.", .de: "Einstellungen gespeichert.", .es: "Ajustes guardados."],
        "快速添加": [.en: "Quick add", .ja: "クイック追加", .ko: "빠른 추가", .fr: "Ajout rapide", .de: "Schnell hinzufügen", .es: "Añadir rápido"],
        "任务名称": [.en: "Task name", .ja: "タスク名", .ko: "작업 이름", .fr: "Nom de la tâche", .de: "Aufgabenname", .es: "Nombre de tarea"],
        "开始 默认 %@": [.en: "Start default %@", .ja: "開始 既定 %@", .ko: "시작 기본 %@", .fr: "Début par défaut %@", .de: "Start Standard %@", .es: "Inicio predeterminado %@"],
        "结束 默认 +90 分钟": [.en: "End default +90 min", .ja: "終了 既定 +90 分", .ko: "종료 기본 +90분", .fr: "Fin par défaut +90 min", .de: "Ende Standard +90 Min.", .es: "Fin predeterminado +90 min"],
        "添加": [.en: "Add", .ja: "追加", .ko: "추가", .fr: "Ajouter", .de: "Hinzufügen", .es: "Añadir"],
        "应用": [.en: "Apply", .ja: "適用", .ko: "적용", .fr: "Appliquer", .de: "Anwenden", .es: "Aplicar"],
        "删除": [.en: "Delete", .ja: "削除", .ko: "삭제", .fr: "Supprimer", .de: "Löschen", .es: "Eliminar"],
        "清理": [.en: "Clear", .ja: "消去", .ko: "정리", .fr: "Nettoyer", .de: "Bereinigen", .es: "Limpiar"],
        "取消": [.en: "Cancel", .ja: "キャンセル", .ko: "취소", .fr: "Annuler", .de: "Abbrechen", .es: "Cancelar"],
        "确定清理": [.en: "Confirm clear", .ja: "消去を確認", .ko: "정리 확인", .fr: "Confirmer", .de: "Bereinigen bestätigen", .es: "Confirmar limpieza"],
        "今天": [.en: "Today", .ja: "今日", .ko: "오늘", .fr: "Aujourd'hui", .de: "Heute", .es: "Hoy"],
        "明天": [.en: "Tomorrow", .ja: "明日", .ko: "내일", .fr: "Demain", .de: "Morgen", .es: "Mañana"],
        "选择日期": [.en: "Select date", .ja: "日付を選択", .ko: "날짜 선택", .fr: "Choisir la date", .de: "Datum wählen", .es: "Seleccionar fecha"],
        "本周概览": [.en: "This week", .ja: "今週の概要", .ko: "이번 주 개요", .fr: "Cette semaine", .de: "Diese Woche", .es: "Esta semana"],
        "复制当前计划": [.en: "Copy current plan", .ja: "現在の計画をコピー", .ko: "현재 계획 복사", .fr: "Copier le plan", .de: "Aktuellen Plan kopieren", .es: "Copiar plan actual"],
        "复制": [.en: "Copy", .ja: "コピー", .ko: "복사", .fr: "Copier", .de: "Kopieren", .es: "Copiar"],
        "开始执行": [.en: "Start execution", .ja: "実行開始", .ko: "실행 시작", .fr: "Démarrer", .de: "Starten", .es: "Iniciar"],
        "完成": [.en: "Done", .ja: "完了", .ko: "완료", .fr: "Terminé", .de: "Erledigt", .es: "Completado"],
        "取消完成": [.en: "Undo done", .ja: "完了を取消", .ko: "완료 취소", .fr: "Annuler terminé", .de: "Erledigt zurücknehmen", .es: "Deshacer completado"],
        "跳过": [.en: "Skip", .ja: "スキップ", .ko: "건너뛰기", .fr: "Sauter", .de: "Überspringen", .es: "Omitir"],
        "取消跳过": [.en: "Undo skip", .ja: "スキップを取消", .ko: "건너뛰기 취소", .fr: "Annuler saut", .de: "Überspringen zurücknehmen", .es: "Deshacer omisión"],
        "推迟 20 分钟": [.en: "Delay 20 min", .ja: "20 分遅らせる", .ko: "20분 연기", .fr: "Reporter 20 min", .de: "20 Min. verschieben", .es: "Retrasar 20 min"],
        "取消推迟": [.en: "Undo delay", .ja: "延期を取消", .ko: "연기 취소", .fr: "Annuler report", .de: "Verschiebung zurücknehmen", .es: "Deshacer retraso"],
        "待开始": [.en: "Planned", .ja: "予定", .ko: "예정", .fr: "Prévu", .de: "Geplant", .es: "Planificado"],
        "进行中": [.en: "Active", .ja: "進行中", .ko: "진행 중", .fr: "En cours", .de: "Aktiv", .es: "En curso"],
        "已完成": [.en: "Done", .ja: "完了", .ko: "완료됨", .fr: "Terminé", .de: "Erledigt", .es: "Completado"],
        "已跳过": [.en: "Skipped", .ja: "スキップ済み", .ko: "건너뜀", .fr: "Sauté", .de: "Übersprungen", .es: "Omitido"],
        "已推迟": [.en: "Delayed", .ja: "延期済み", .ko: "연기됨", .fr: "Reporté", .de: "Verschoben", .es: "Retrasado"],
        "已中断": [.en: "Interrupted", .ja: "中断", .ko: "중단됨", .fr: "Interrompu", .de: "Unterbrochen", .es: "Interrumpido"],
        "已删除": [.en: "Deleted", .ja: "削除済み", .ko: "삭제됨", .fr: "Supprimé", .de: "Gelöscht", .es: "Eliminado"],
        "草稿": [.en: "Draft", .ja: "下書き", .ko: "초안", .fr: "Brouillon", .de: "Entwurf", .es: "Borrador"],
        "已确认": [.en: "Ready", .ja: "確認済み", .ko: "확인됨", .fr: "Confirmé", .de: "Bereit", .es: "Confirmado"],
        "执行中": [.en: "Running", .ja: "実行中", .ko: "실행 중", .fr: "En exécution", .de: "Läuft", .es: "En ejecución"],
        "已结束": [.en: "Finished", .ja: "終了済み", .ko: "종료됨", .fr: "Terminé", .de: "Beendet", .es: "Finalizado"],
        "已归档": [.en: "Archived", .ja: "アーカイブ済み", .ko: "보관됨", .fr: "Archivé", .de: "Archiviert", .es: "Archivado"],
        "时间块": [.en: "Time block", .ja: "時間ブロック", .ko: "시간 블록", .fr: "Bloc horaire", .de: "Zeitblock", .es: "Bloque de tiempo"],
        "状态": [.en: "Status", .ja: "状態", .ko: "상태", .fr: "Statut", .de: "Status", .es: "Estado"],
        "更新时间": [.en: "Update time", .ja: "時間を更新", .ko: "시간 업데이트", .fr: "Mettre à jour", .de: "Zeit aktualisieren", .es: "Actualizar hora"],
        "状态归类": [.en: "Status groups", .ja: "状態グループ", .ko: "상태 그룹", .fr: "Groupes d'état", .de: "Statusgruppen", .es: "Grupos de estado"],
        "24 小时状态": [.en: "24-hour status", .ja: "24 時間ステータス", .ko: "24시간 상태", .fr: "État sur 24 h", .de: "24-Stunden-Status", .es: "Estado 24 h"],
        "状态示意": [.en: "Legend", .ja: "凡例", .ko: "범례", .fr: "Légende", .de: "Legende", .es: "Leyenda"],
        "内圈": [.en: "Inner", .ja: "内側", .ko: "내부", .fr: "Intérieur", .de: "Innen", .es: "Interior"],
        "外圈": [.en: "Outer", .ja: "外側", .ko: "외부", .fr: "Extérieur", .de: "Außen", .es: "Exterior"],
        "空闲": [.en: "Idle", .ja: "空き", .ko: "비어 있음", .fr: "Libre", .de: "Frei", .es: "Libre"],
        "任务": [.en: "Task", .ja: "タスク", .ko: "작업", .fr: "Tâche", .de: "Aufgabe", .es: "Tarea"],
        "待规划": [.en: "No plan", .ja: "未計画", .ko: "계획 없음", .fr: "À planifier", .de: "Ungeplant", .es: "Sin plan"],
        "日程草稿": [.en: "Schedule draft", .ja: "日程案", .ko: "일정 초안", .fr: "Brouillon d'horaire", .de: "Terminplan-Entwurf", .es: "Borrador de horario"],
        "原始计划": [.en: "Raw plan", .ja: "元の計画", .ko: "원본 계획", .fr: "Plan brut", .de: "Rohplan", .es: "Plan inicial"],
        "语音录入": [.en: "Dictate", .ja: "音声入力", .ko: "음성 입력", .fr: "Dicter", .de: "Diktieren", .es: "Dictar"],
        "停止录入": [.en: "Stop dictation", .ja: "音声入力停止", .ko: "음성 입력 중지", .fr: "Arrêter", .de: "Diktat stoppen", .es: "Detener dictado"],
        "清空": [.en: "Clear", .ja: "クリア", .ko: "비우기", .fr: "Effacer", .de: "Leeren", .es: "Vaciar"],
        "把今天要做的事直接粘进来，例如：\n09:30 看股票账户 20 分钟\n读论文综述，大概 1 小时\n写项目代码\n晚上复盘": [.en: "Paste what you need to do today, for example:\n09:30 Check investment account 20 min\nRead paper summaries, about 1 hour\nWrite project code\nEvening review", .ja: "今日やることをそのまま貼り付けてください。例：\n09:30 投資口座を確認 20 分\n論文サマリーを読む、約 1 時間\nプロジェクトのコードを書く\n夜に振り返り", .ko: "오늘 할 일을 그대로 붙여넣으세요. 예:\n09:30 투자 계좌 확인 20분\n논문 요약 읽기, 약 1시간\n프로젝트 코드 작성\n저녁 회고", .fr: "Collez directement les tâches du jour, par exemple :\n09:30 Vérifier le compte d'investissement 20 min\nLire des résumés d'articles, environ 1 h\nCoder le projet\nBilan du soir", .de: "Fügen Sie die heutigen Aufgaben direkt ein, z. B.:\n09:30 Anlagekonto prüfen 20 Min.\nPaper-Zusammenfassungen lesen, ca. 1 Std.\nProjektcode schreiben\nAbend-Review", .es: "Pega directamente lo que tienes que hacer hoy, por ejemplo:\n09:30 Revisar cuenta de inversión 20 min\nLeer resúmenes de artículos, aprox. 1 h\nEscribir código del proyecto\nRevisión por la noche"],
        "生成分时段日程": [.en: "Generate schedule", .ja: "時間割を生成", .ko: "시간표 생성", .fr: "Générer l'horaire", .de: "Zeitplan erstellen", .es: "Generar horario"],
        "等待生成": [.en: "Waiting", .ja: "生成待ち", .ko: "대기 중", .fr: "En attente", .de: "Warten", .es: "Esperando"],
        "内容说明": [.en: "Notes", .ja: "説明", .ko: "내용 설명", .fr: "Notes", .de: "Notizen", .es: "Notas"],
        "时长": [.en: "Duration", .ja: "時間", .ko: "소요", .fr: "Durée", .de: "Dauer", .es: "Duración"],
        "规划": [.en: "Window", .ja: "時間帯", .ko: "계획", .fr: "Plage", .de: "Zeitraum", .es: "Franja"],
        "到": [.en: "to", .ja: "〜", .ko: "까지", .fr: "à", .de: "bis", .es: "a"],
        "间隔": [.en: "Break", .ja: "間隔", .ko: "간격", .fr: "Pause", .de: "Pause", .es: "Pausa"],
        "分钟": [.en: "min", .ja: "分", .ko: "분", .fr: "min", .de: "Min.", .es: "min"],
        "附近任务": [.en: "Nearby tasks", .ja: "近くのタスク", .ko: "주변 작업", .fr: "Tâches proches", .de: "Nahe Aufgaben", .es: "Tareas cercanas"],
        "实时执行": [.en: "Live execution", .ja: "リアルタイム実行", .ko: "실시간 실행", .fr: "Exécution en direct", .de: "Live-Ausführung", .es: "Ejecución en vivo"],
        "透明": [.en: "Opacity", .ja: "透明", .ko: "투명도", .fr: "Opacité", .de: "Deckkraft", .es: "Opacidad"],
        "剩余": [.en: "left", .ja: "残り", .ko: "남음", .fr: "restant", .de: "übrig", .es: "restante"],
        "后开始": [.en: "until start", .ja: "後に開始", .ko: "후 시작", .fr: "avant début", .de: "bis Start", .es: "hasta inicio"],
        "下一项": [.en: "Next", .ja: "次", .ko: "다음", .fr: "Suivant", .de: "Nächste", .es: "Siguiente"],
        "没有事项": [.en: "No task", .ja: "タスクなし", .ko: "작업 없음", .fr: "Aucune tâche", .de: "Keine Aufgabe", .es: "Sin tareas"],
        "今天已结束": [.en: "Today is finished", .ja: "今日は終了", .ko: "오늘 종료", .fr: "Journée terminée", .de: "Heute beendet", .es: "Día finalizado"],
        "当前": [.en: "Current", .ja: "現在", .ko: "현재", .fr: "Actuel", .de: "Aktuell", .es: "Actual"],
        "下一个": [.en: "Next", .ja: "次", .ko: "다음", .fr: "Suivant", .de: "Nächste", .es: "Siguiente"],
        "今天没有更多任务": [.en: "No more tasks today", .ja: "今日のタスクはもうありません", .ko: "오늘 남은 작업 없음", .fr: "Plus de tâches aujourd'hui", .de: "Keine weiteren Aufgaben heute", .es: "No hay más tareas hoy"],
        "开始今天": [.en: "Start today", .ja: "今日を開始", .ko: "오늘 시작", .fr: "Démarrer la journée", .de: "Heute starten", .es: "Iniciar día"],
        "完成当前": [.en: "Complete current", .ja: "現在を完了", .ko: "현재 완료", .fr: "Terminer l'actuel", .de: "Aktuelle erledigen", .es: "Completar actual"],
        "跳过当前": [.en: "Skip current", .ja: "現在をスキップ", .ko: "현재 건너뛰기", .fr: "Sauter l'actuel", .de: "Aktuelle überspringen", .es: "Omitir actual"],
        "显示悬浮窗": [.en: "Show floating panel", .ja: "フローティングパネルを表示", .ko: "플로팅 패널 표시", .fr: "Afficher le panneau", .de: "Schwebefenster anzeigen", .es: "Mostrar panel flotante"],
        "结束今天": [.en: "Finish today", .ja: "今日を終了", .ko: "오늘 종료", .fr: "Terminer la journée", .de: "Heute beenden", .es: "Finalizar día"],
        "未记录": [.en: "Not logged", .ja: "未記録", .ko: "기록 없음", .fr: "Non enregistré", .de: "Nicht erfasst", .es: "No registrado"],
        "实际 %dm": [.en: "Actual %dm", .ja: "実績 %d分", .ko: "실제 %d분", .fr: "Réel %d min", .de: "Ist %d Min.", .es: "Real %d min"],
        "AI 规划待开始。": [.en: "AI planning is ready.", .ja: "AI 計画を開始できます。", .ko: "AI 계획 준비 완료.", .fr: "Planification IA prête.", .de: "KI-Planung bereit.", .es: "Planificación IA lista."],
        "AI 规划失败。": [.en: "AI planning failed.", .ja: "AI 計画に失敗しました。", .ko: "AI 계획 실패.", .fr: "Échec de la planification IA.", .de: "KI-Planung fehlgeschlagen.", .es: "Falló la planificación IA."],
        "正在使用本地 mock 拆分任务...": [.en: "Using local mock to split tasks...", .ja: "ローカル mock でタスクを分割中...", .ko: "로컬 mock으로 작업 분리 중...", .fr: "Découpage local des tâches...", .de: "Lokaler Mock teilt Aufgaben...", .es: "Dividiendo tareas con mock local..."],
        "正在调用 %@ 生成规划建议，请求已发送...": [.en: "Calling %@ to generate planning suggestions...", .ja: "%@ で計画案を生成中...", .ko: "%@로 계획 제안 생성 중...", .fr: "Appel de %@ pour générer des suggestions...", .de: "%@ erstellt Planungsvorschläge...", .es: "Llamando a %@ para generar sugerencias..."],
        "%@ 已生成 %d 个规划建议，用时 %@。": [.en: "%@ generated %d planning suggestions in %@.", .ja: "%@ が %d 件の計画案を生成しました（%@）。", .ko: "%@가 %d개 계획 제안을 생성했습니다. 소요 %@", .fr: "%@ a généré %d suggestions en %@.", .de: "%@ hat %d Vorschläge in %@ erstellt.", .es: "%@ generó %d sugerencias en %@."],
        "AI 规划失败，用时 %@：%@": [.en: "AI planning failed after %@: %@", .ja: "AI 計画に失敗しました（%@）：%@", .ko: "AI 계획 실패, 소요 %@: %@", .fr: "Échec IA après %@ : %@", .de: "KI-Planung nach %@ fehlgeschlagen: %@", .es: "Falló IA tras %@: %@"],
        "AI 复盘失败：%@": [.en: "AI review failed: %@", .ja: "AI 振り返りに失敗：%@", .ko: "AI 회고 실패: %@", .fr: "Échec du bilan IA : %@", .de: "KI-Review fehlgeschlagen: %@", .es: "Falló revisión IA: %@"],
        "请先到设置中配置 DeepSeek API Key。": [.en: "Configure the DeepSeek API Key in Settings first.", .ja: "先に設定で DeepSeek API Key を設定してください。", .ko: "먼저 설정에서 DeepSeek API Key를 구성하세요.", .fr: "Configurez d'abord la clé API DeepSeek dans Réglages.", .de: "Konfigurieren Sie zuerst den DeepSeek API Key.", .es: "Configura primero la API Key de DeepSeek."],
        "请先到设置中配置火山方舟 API Key。": [.en: "Configure the Volcengine Ark API Key in Settings first.", .ja: "先に設定で Volcengine Ark API Key を設定してください。", .ko: "먼저 설정에서 화산 Ark API Key를 구성하세요.", .fr: "Configurez d'abord la clé API Volcengine Ark.", .de: "Konfigurieren Sie zuerst den Volcengine Ark API Key.", .es: "Configura primero la API Key de Volcengine Ark."],
        "请先到设置中配置 %@ API Key。": [.en: "Configure the %@ API Key in Settings first.", .ja: "先に設定で %@ API Key を設定してください。", .ko: "먼저 설정에서 %@ API Key를 구성하세요.", .fr: "Configurez d'abord la clé API %@ dans Réglages.", .de: "Konfigurieren Sie zuerst den %@ API Key.", .es: "Configura primero la API Key de %@."],
        "保存 API Key 失败：%@": [.en: "Failed to save API Key: %@", .ja: "API Key の保存に失敗：%@", .ko: "API Key 저장 실패: %@", .fr: "Échec de l'enregistrement de la clé API : %@", .de: "API Key konnte nicht gespeichert werden: %@", .es: "No se pudo guardar la API Key: %@"],
        "系统通知权限未开启，请在 macOS 设置里允许 EfficientTime 发送通知。": [.en: "Notifications are not allowed. Enable EfficientTime notifications in macOS Settings.", .ja: "通知が許可されていません。macOS 設定で EfficientTime の通知を許可してください。", .ko: "알림 권한이 꺼져 있습니다. macOS 설정에서 EfficientTime 알림을 허용하세요.", .fr: "Les notifications ne sont pas autorisées. Activez EfficientTime dans Réglages macOS.", .de: "Benachrichtigungen sind nicht erlaubt. EfficientTime in macOS-Einstellungen erlauben.", .es: "Las notificaciones no están permitidas. Actívalas para EfficientTime."],
        "EfficientTime 测试提醒": [.en: "EfficientTime test reminder", .ja: "EfficientTime テスト通知", .ko: "EfficientTime 테스트 알림", .fr: "Rappel de test EfficientTime", .de: "EfficientTime-Test", .es: "Recordatorio de prueba EfficientTime"],
        "如果系统通知不可用，这个置顶提醒仍会显示。": [.en: "If system notifications are unavailable, this top reminder still appears.", .ja: "システム通知が使えない場合も、この前面通知は表示されます。", .ko: "시스템 알림을 사용할 수 없어도 이 상단 알림은 표시됩니다.", .fr: "Si les notifications système échouent, ce rappel au premier plan reste affiché.", .de: "Wenn Systembenachrichtigungen fehlen, erscheint diese Vordergrundmeldung.", .es: "Si las notificaciones del sistema fallan, este aviso seguirá visible."],
        "系统通知已触发。": [.en: "System notification triggered.", .ja: "システム通知を送信しました。", .ko: "시스템 알림이 전송되었습니다.", .fr: "Notification système déclenchée.", .de: "Systembenachrichtigung ausgelöst.", .es: "Notificación del sistema activada."],
        "系统通知发送失败：%@。已显示 EfficientTime 置顶提醒。": [.en: "System notification failed: %@. EfficientTime top reminder was shown.", .ja: "システム通知に失敗：%@。EfficientTime の前面通知を表示しました。", .ko: "시스템 알림 실패: %@. EfficientTime 상단 알림을 표시했습니다.", .fr: "Notification système échouée : %@. Rappel EfficientTime affiché.", .de: "Systembenachrichtigung fehlgeschlagen: %@. Vordergrundmeldung angezeigt.", .es: "Falló la notificación: %@. Se mostró el aviso de EfficientTime."],
        "测试通知已发送；如果没看到横幅，请检查 macOS 通知设置里的 EfficientTime。": [.en: "Test notification sent. If no banner appears, check EfficientTime in macOS notification settings.", .ja: "テスト通知を送信しました。バナーが出ない場合は macOS 通知設定を確認してください。", .ko: "테스트 알림을 보냈습니다. 배너가 보이지 않으면 macOS 알림 설정을 확인하세요.", .fr: "Notification de test envoyée. Si aucune bannière n'apparaît, vérifiez les réglages macOS.", .de: "Test gesendet. Wenn kein Banner erscheint, macOS-Mitteilungen prüfen.", .es: "Notificación de prueba enviada. Si no ves banner, revisa Ajustes de macOS."],
        "点击“申请系统通知权限”，macOS 会弹出授权确认。": [.en: "Click “Request notification permission”; macOS will show the permission dialog.", .ja: "「通知権限を要求」をクリックすると macOS の確認が表示されます。", .ko: "“알림 권한 요청”을 누르면 macOS 권한 창이 표시됩니다.", .fr: "Cliquez sur la demande d'autorisation ; macOS affichera la confirmation.", .de: "Klicken Sie auf „Benachrichtigungen erlauben“; macOS fragt nach.", .es: "Pulsa solicitar permiso; macOS mostrará la confirmación."],
        "请到 macOS 系统设置 > 通知 > EfficientTime，允许通知、横幅和声音。": [.en: "Go to macOS Settings > Notifications > EfficientTime and allow notifications, banners, and sounds.", .ja: "macOS 設定 > 通知 > EfficientTime で通知、バナー、サウンドを許可してください。", .ko: "macOS 설정 > 알림 > EfficientTime에서 알림, 배너, 사운드를 허용하세요.", .fr: "Dans Réglages macOS > Notifications > EfficientTime, autorisez notifications, bannières et sons.", .de: "In macOS Einstellungen > Mitteilungen > EfficientTime Benachrichtigungen, Banner und Ton erlauben.", .es: "En Ajustes > Notificaciones > EfficientTime, permite avisos, banners y sonido."],
        "系统通知已开启；如果看不到横幅，请检查专注模式和通知样式。": [.en: "Notifications are enabled. If banners do not appear, check Focus mode and notification style.", .ja: "通知は有効です。バナーが出ない場合は集中モードと通知形式を確認してください。", .ko: "알림이 켜져 있습니다. 배너가 없으면 집중 모드와 알림 스타일을 확인하세요.", .fr: "Notifications activées. Vérifiez Concentration et le style si aucune bannière n'apparaît.", .de: "Benachrichtigungen aktiv. Falls keine Banner erscheinen, Fokusmodus und Stil prüfen.", .es: "Notificaciones activas. Si no hay banners, revisa Concentración y estilo."],
        "系统允许静默通知；建议在 macOS 通知设置里改为允许横幅。": [.en: "macOS allows quiet notifications. Consider enabling banners in notification settings.", .ja: "macOS は静かな通知を許可しています。通知設定でバナーを有効にしてください。", .ko: "macOS가 조용한 알림을 허용합니다. 배너를 켜는 것을 권장합니다.", .fr: "macOS autorise les notifications silencieuses. Activez les bannières.", .de: "macOS erlaubt stille Mitteilungen. Banner in den Einstellungen aktivieren.", .es: "macOS permite notificaciones silenciosas. Activa banners en ajustes."],
        "macOS 返回了未识别的通知状态，请尝试重新申请权限或从 .app 启动。": [.en: "macOS returned an unknown notification status. Request permission again or launch from the .app.", .ja: "macOS が不明な通知状態を返しました。再申請するか .app から起動してください。", .ko: "macOS가 알 수 없는 알림 상태를 반환했습니다. 다시 요청하거나 .app에서 실행하세요.", .fr: "macOS a renvoyé un état inconnu. Redemandez l'autorisation ou lancez l'app.", .de: "macOS meldete einen unbekannten Status. Erneut anfragen oder aus .app starten.", .es: "macOS devolvió un estado desconocido. Solicita permiso de nuevo o abre la .app."],
        "该规划明天了": [.en: "Time to plan tomorrow", .ja: "明日の計画時間です", .ko: "내일 계획할 시간", .fr: "Il est temps de planifier demain", .de: "Zeit, morgen zu planen", .es: "Hora de planificar mañana"],
        "打开 EfficientTime 安排明天的时间表": [.en: "Open EfficientTime to arrange tomorrow's schedule", .ja: "EfficientTime を開いて明日の予定を組みましょう", .ko: "EfficientTime을 열어 내일 일정을 정리하세요", .fr: "Ouvrez EfficientTime pour préparer demain", .de: "Öffnen Sie EfficientTime für den morgigen Zeitplan", .es: "Abre EfficientTime para organizar mañana"],
        "即将开始：%@": [.en: "Starting soon: %@", .ja: "まもなく開始：%@", .ko: "곧 시작: %@", .fr: "Bientôt : %@", .de: "Beginnt bald: %@", .es: "Empieza pronto: %@"],
        "还有 %d 分钟开始": [.en: "Starts in %d min", .ja: "あと %d 分で開始", .ko: "%d분 후 시작", .fr: "Début dans %d min", .de: "Start in %d Min.", .es: "Empieza en %d min"],
        "开始：%@": [.en: "Start: %@", .ja: "開始：%@", .ko: "시작: %@", .fr: "Début : %@", .de: "Start: %@", .es: "Inicio: %@"],
        "结束：%@": [.en: "End: %@", .ja: "終了：%@", .ko: "종료: %@", .fr: "Fin : %@", .de: "Ende: %@", .es: "Fin: %@"],
        "当前任务开始了，%@-%@": [.en: "Current task started, %@-%@", .ja: "現在のタスクが開始しました、%@-%@", .ko: "현재 작업 시작, %@-%@", .fr: "La tâche actuelle a commencé, %@-%@", .de: "Aktuelle Aufgabe gestartet, %@-%@", .es: "La tarea actual empezó, %@-%@"],
        "当前任务到结束时间了，请标记完成或跳过": [.en: "Current task reached its end time. Mark it done or skipped.", .ja: "現在のタスクが終了時刻です。完了またはスキップにしてください。", .ko: "현재 작업 종료 시간입니다. 완료 또는 건너뜀으로 표시하세요.", .fr: "La tâche actuelle est arrivée à sa fin. Marquez-la terminée ou sautée.", .de: "Die aktuelle Aufgabe ist am Ende. Als erledigt oder übersprungen markieren.", .es: "La tarea llegó al final. Márcala completada u omitida."]
        ,
        "%@计划：%d 个时间块，计划 %d 分钟。": [.en: "%@ plan: %d time blocks, %d min planned.", .ja: "%@の計画：%d 個の時間ブロック、%d 分予定。", .ko: "%@ 계획: 시간 블록 %d개, 계획 %d분.", .fr: "Plan %@ : %d blocs, %d min prévues.", .de: "%@ Plan: %d Zeitblöcke, %d Min. geplant.", .es: "Plan %@: %d bloques, %d min planificados."],
        "已完成：%d 个；已跳过：%d 个；已推迟：%d 个。": [.en: "Done: %d; skipped: %d; delayed: %d.", .ja: "完了：%d；スキップ：%d；延期：%d。", .ko: "완료: %d; 건너뜀: %d; 연기: %d.", .fr: "Terminés : %d ; sautés : %d ; reportés : %d.", .de: "Erledigt: %d; übersprungen: %d; verschoben: %d.", .es: "Completados: %d; omitidos: %d; retrasados: %d."],
        "已记录实际耗时：%d 分钟；执行事件：%d 条。": [.en: "Logged actual time: %d min; execution events: %d.", .ja: "記録済み実績：%d 分；実行イベント：%d 件。", .ko: "기록된 실제 시간: %d분; 실행 이벤트: %d개.", .fr: "Temps réel enregistré : %d min ; événements : %d.", .de: "Erfasste Ist-Zeit: %d Min.; Ereignisse: %d.", .es: "Tiempo real registrado: %d min; eventos: %d."],
        "状态：%@。": [.en: "Status: %@.", .ja: "状態：%@。", .ko: "상태: %@.", .fr: "Statut : %@.", .de: "Status: %@.", .es: "Estado: %@."],
        "已结束 %@ 的计划。": [.en: "Finished the plan for %@.", .ja: "%@ の計画を終了しました。", .ko: "%@ 계획을 종료했습니다.", .fr: "Plan %@ terminé.", .de: "Plan für %@ beendet.", .es: "Plan de %@ finalizado."],
        "已清空 %@ 的所有任务。": [.en: "Cleared all tasks for %@.", .ja: "%@ の全タスクを消去しました。", .ko: "%@의 모든 작업을 비웠습니다.", .fr: "Toutes les tâches de %@ ont été effacées.", .de: "Alle Aufgaben für %@ gelöscht.", .es: "Todas las tareas de %@ fueron borradas."],
        "已删除 %@ 的计划。": [.en: "Deleted the plan for %@.", .ja: "%@ の計画を削除しました。", .ko: "%@ 계획을 삭제했습니다.", .fr: "Plan %@ supprimé.", .de: "Plan für %@ gelöscht.", .es: "Plan de %@ eliminado."],
        "已复制到 %@。": [.en: "Copied to %@.", .ja: "%@ にコピーしました。", .ko: "%@에 복사했습니다.", .fr: "Copié vers %@.", .de: "Nach %@ kopiert.", .es: "Copiado a %@"],
        "已完成「%@」。": [.en: "Marked “%@” done.", .ja: "「%@」を完了にしました。", .ko: "“%@” 완료 처리.", .fr: "« %@ » marqué terminé.", .de: "„%@“ als erledigt markiert.", .es: "“%@” marcado completado."],
        "已跳过「%@」。": [.en: "Skipped “%@”.", .ja: "「%@」をスキップしました。", .ko: "“%@” 건너뜀.", .fr: "« %@ » sauté.", .de: "„%@“ übersprungen.", .es: "“%@” omitido."],
        "已取消跳过「%@」。": [.en: "Undo skip for “%@”.", .ja: "「%@」のスキップを取り消しました。", .ko: "“%@” 건너뛰기 취소.", .fr: "Saut annulé pour « %@ ».", .de: "Überspringen für „%@“ zurückgenommen.", .es: "Omisión deshecha para “%@”."],
        "已将「%@」移到已删除。": [.en: "Moved “%@” to deleted.", .ja: "「%@」を削除済みに移動しました。", .ko: "“%@”을 삭제됨으로 이동했습니다.", .fr: "« %@ » déplacé dans les supprimés.", .de: "„%@“ nach gelöscht verschoben.", .es: "“%@” movido a eliminados."],
        "已彻底清理 %d 个已删除事项。": [.en: "Permanently cleared %d deleted items.", .ja: "削除済み %d 件を完全に消去しました。", .ko: "삭제된 항목 %d개를 완전히 정리했습니다.", .fr: "%d éléments supprimés définitivement nettoyés.", .de: "%d gelöschte Elemente endgültig bereinigt.", .es: "%d elementos eliminados limpiados permanentemente."],
        "已将 AI 草稿应用到 %@。": [.en: "Applied AI draft to %@.", .ja: "AI 草稿を %@ に適用しました。", .ko: "AI 초안을 %@에 적용했습니다.", .fr: "Brouillon IA appliqué à %@.", .de: "KI-Entwurf auf %@ angewendet.", .es: "Borrador IA aplicado a %@"],
        "未应用到%@：%d 个任务中只有 %d 个能排进时间表。%@": [.en: "Not applied to %@: of %d tasks, only %d fit. %@", .ja: "%@ に適用できません：%d 件中 %d 件だけ配置可能。%@", .ko: "%@에 적용 안 됨: %d개 중 %d개만 배치 가능. %@", .fr: "Non appliqué à %@ : sur %d tâches, seulement %d tiennent. %@", .de: "Nicht auf %@ angewendet: Von %d Aufgaben passen nur %d. %@", .es: "No aplicado a %@: de %d tareas, solo %d caben. %@"],
        "主要原因：%@": [.en: "Main reason: %@", .ja: "主な理由：%@", .ko: "주요 이유: %@", .fr: "Raison principale : %@", .de: "Hauptgrund: %@", .es: "Motivo principal: %@"],
        "请调整草稿时间，保证任务都在规划范围内。": [.en: "Adjust draft times so all tasks fit inside the planning range.", .ja: "すべてのタスクが計画範囲に入るよう草稿時間を調整してください。", .ko: "모든 작업이 계획 범위에 들어가도록 초안 시간을 조정하세요.", .fr: "Ajustez les horaires du brouillon pour rester dans la plage.", .de: "Passen Sie die Entwurfszeiten an, damit alle Aufgaben in den Zeitraum passen.", .es: "Ajusta las horas del borrador para que todo quepa en el rango."],
        "请先选择一个时间块，或等到当前时间进入某个任务。": [.en: "Select a time block first, or wait until a task is active.", .ja: "先に時間ブロックを選択するか、タスク開始まで待ってください。", .ko: "먼저 시간 블록을 선택하거나 현재 시간이 작업에 들어갈 때까지 기다리세요.", .fr: "Sélectionnez d'abord un bloc ou attendez une tâche active.", .de: "Wählen Sie zuerst einen Zeitblock oder warten Sie auf eine aktive Aufgabe.", .es: "Selecciona un bloque o espera a que una tarea esté activa."],
        "请先选择一个时间块。": [.en: "Select a time block first.", .ja: "先に時間ブロックを選択してください。", .ko: "먼저 시간 블록을 선택하세요.", .fr: "Sélectionnez d'abord un bloc.", .de: "Wählen Sie zuerst einen Zeitblock.", .es: "Selecciona primero un bloque."],
        "任务名称不能为空。": [.en: "Task name cannot be empty.", .ja: "タスク名は空にできません。", .ko: "작업 이름은 비워둘 수 없습니다.", .fr: "Le nom de tâche est obligatoire.", .de: "Aufgabenname darf nicht leer sein.", .es: "El nombre de tarea no puede estar vacío."],
        "开始时间必须早于结束时间。": [.en: "Start time must be before end time.", .ja: "開始時刻は終了時刻より前にしてください。", .ko: "시작 시간은 종료 시간보다 빨라야 합니다.", .fr: "Le début doit précéder la fin.", .de: "Startzeit muss vor Endzeit liegen.", .es: "La hora de inicio debe ser anterior al fin."],
        "时间格式需要是 HH:mm，例如 09:30。": [.en: "Time format must be HH:mm, for example 09:30.", .ja: "時刻形式は HH:mm（例：09:30）です。", .ko: "시간 형식은 HH:mm이어야 합니다. 예: 09:30.", .fr: "Le format doit être HH:mm, par exemple 09:30.", .de: "Zeitformat HH:mm, z. B. 09:30.", .es: "Formato HH:mm, por ejemplo 09:30."],
        "至少需要一个可用时间段。": [.en: "At least one available time window is required.", .ja: "少なくとも 1 つの利用可能時間帯が必要です。", .ko: "사용 가능한 시간대가 하나 이상 필요합니다.", .fr: "Au moins une plage disponible est requise.", .de: "Mindestens ein verfügbares Zeitfenster ist erforderlich.", .es: "Se requiere al menos una franja disponible."],
        "时间段格式需要类似：09:30-21:30。": [.en: "Time window format should look like 09:30-21:30.", .ja: "時間帯形式は 09:30-21:30 のようにしてください。", .ko: "시간대 형식은 09:30-21:30처럼 입력하세요.", .fr: "Format attendu : 09:30-21:30.", .de: "Zeitfensterformat wie 09:30-21:30.", .es: "Formato de franja: 09:30-21:30."],
        "时间块必须落在可用时间段内。": [.en: "The time block must fit inside available windows.", .ja: "時間ブロックは利用可能時間帯内にしてください。", .ko: "시간 블록은 사용 가능한 시간대 안에 있어야 합니다.", .fr: "Le bloc doit rester dans les plages disponibles.", .de: "Zeitblock muss in verfügbaren Zeitfenstern liegen.", .es: "El bloque debe estar dentro de franjas disponibles."],
        "已删除事项不能更新时间；可以先从已删除中清理。": [.en: "Deleted items cannot be updated; clear them from deleted items first.", .ja: "削除済み項目は更新できません。先に削除済みから消去してください。", .ko: "삭제된 항목은 업데이트할 수 없습니다. 먼저 정리하세요.", .fr: "Les éléments supprimés ne peuvent pas être modifiés ; nettoyez-les d'abord.", .de: "Gelöschte Elemente können nicht aktualisiert werden; zuerst bereinigen.", .es: "Los eliminados no se pueden actualizar; límpialos primero."],
        "当前没有需要清理的已删除事项。": [.en: "There are no deleted items to clear.", .ja: "消去する削除済み項目はありません。", .ko: "정리할 삭제 항목이 없습니다.", .fr: "Aucun élément supprimé à nettoyer.", .de: "Keine gelöschten Elemente zum Bereinigen.", .es: "No hay elementos eliminados que limpiar."],
        "当前冲突没有可直接采用的建议时间。": [.en: "This conflict has no suggestion that can be applied directly.", .ja: "この競合には直接適用できる推奨時間がありません。", .ko: "이 충돌에는 바로 적용할 추천 시간이 없습니다.", .fr: "Ce conflit n'a pas de suggestion directement applicable.", .de: "Für diesen Konflikt gibt es keinen direkt anwendbaren Vorschlag.", .es: "Este conflicto no tiene una sugerencia aplicable directamente."],
        "已选中冲突事项「%@」，可以在右侧修改它的时间。": [.en: "Selected conflicting item “%@”; edit its time on the right.", .ja: "競合項目「%@」を選択しました。右側で時間を変更できます。", .ko: "충돌 항목 “%@” 선택됨. 오른쪽에서 시간을 수정하세요.", .fr: "Élément en conflit « %@ » sélectionné ; modifiez son horaire à droite.", .de: "Konfliktelement „%@“ ausgewählt; Zeit rechts bearbeiten.", .es: "Elemento en conflicto “%@” seleccionado; edita su hora a la derecha."],
        "%.1f 秒": [.en: "%.1f sec", .ja: "%.1f 秒", .ko: "%.1f초", .fr: "%.1f s", .de: "%.1f Sek.", .es: "%.1f s"],
        "未申请": [.en: "Not requested", .ja: "未要求", .ko: "요청 안 됨", .fr: "Non demandé", .de: "Nicht angefragt", .es: "No solicitado"],
        "已拒绝": [.en: "Denied", .ja: "拒否済み", .ko: "거부됨", .fr: "Refusé", .de: "Abgelehnt", .es: "Denegado"],
        "已允许": [.en: "Allowed", .ja: "許可済み", .ko: "허용됨", .fr: "Autorisé", .de: "Erlaubt", .es: "Permitido"],
        "临时允许": [.en: "Provisional", .ja: "暫定許可", .ko: "임시 허용", .fr: "Provisoire", .de: "Vorläufig", .es: "Provisional"],
        "未知": [.en: "Unknown", .ja: "不明", .ko: "알 수 없음", .fr: "Inconnu", .de: "Unbekannt", .es: "Desconocido"],
        "Start": [.en: "Start", .ja: "開始", .ko: "시작", .fr: "Début", .de: "Start", .es: "Inicio"],
        "End": [.en: "End", .ja: "終了", .ko: "종료", .fr: "Fin", .de: "Ende", .es: "Fin"],
        "空": [.en: "Empty", .ja: "空", .ko: "비어 있음", .fr: "Vide", .de: "Leer", .es: "Vacío"],
        "今天还没有任务": [.en: "No tasks today", .ja: "今日のタスクはありません", .ko: "오늘 작업이 없습니다", .fr: "Aucune tâche aujourd'hui", .de: "Heute keine Aufgaben", .es: "No hay tareas hoy"],
        "前一天": [.en: "Previous day", .ja: "前日", .ko: "이전 날", .fr: "Jour précédent", .de: "Vorheriger Tag", .es: "Día anterior"],
        "后一天": [.en: "Next day", .ja: "翌日", .ko: "다음 날", .fr: "Jour suivant", .de: "Nächster Tag", .es: "Día siguiente"],
        "上一年": [.en: "Previous year", .ja: "前年", .ko: "이전 해", .fr: "Année précédente", .de: "Vorjahr", .es: "Año anterior"],
        "上一月": [.en: "Previous month", .ja: "前月", .ko: "이전 달", .fr: "Mois précédent", .de: "Vormonat", .es: "Mes anterior"],
        "下一月": [.en: "Next month", .ja: "翌月", .ko: "다음 달", .fr: "Mois suivant", .de: "Nächster Monat", .es: "Mes siguiente"],
        "下一年": [.en: "Next year", .ja: "翌年", .ko: "다음 해", .fr: "Année suivante", .de: "Nächstes Jahr", .es: "Año siguiente"],
        "%d 年 %d 月": [.en: "%d/%d", .ja: "%d年%d月", .ko: "%d년 %d월", .fr: "%d/%d", .de: "%d/%d", .es: "%d/%d"],
        "目标：%@": [.en: "Target: %@", .ja: "対象：%@", .ko: "대상: %@", .fr: "Cible : %@", .de: "Ziel: %@", .es: "Destino: %@"],
        "目标：%@ %@": [.en: "Target: %@ %@", .ja: "対象：%@ %@", .ko: "대상: %@ %@", .fr: "Cible : %@ %@", .de: "Ziel: %@ %@", .es: "Destino: %@ %@"],
        "%@时间表": [.en: "%@ schedule", .ja: "%@の時間表", .ko: "%@ 시간표", .fr: "Horaire %@", .de: "%@ Zeitplan", .es: "Horario de %@"],
        "%@复盘": [.en: "%@ review", .ja: "%@の振り返り", .ko: "%@ 회고", .fr: "Bilan %@", .de: "%@ Review", .es: "Revisión de %@"],
        "%@ 复盘": [.en: "%@ review", .ja: "%@ 振り返り", .ko: "%@ 회고", .fr: "Bilan %@", .de: "%@ Review", .es: "Revisión %@"],
        "完成 %d/%d · %@": [.en: "Done %d/%d · %@", .ja: "完了 %d/%d · %@", .ko: "완료 %d/%d · %@", .fr: "Terminé %d/%d · %@", .de: "Erledigt %d/%d · %@", .es: "Completado %d/%d · %@"],
        "%d 分钟已安排": [.en: "%d min scheduled", .ja: "%d 分を予定", .ko: "%d분 배정됨", .fr: "%d min planifiées", .de: "%d Min. geplant", .es: "%d min programados"],
        "%@ 空闲": [.en: "%@ idle", .ja: "%@ 空き", .ko: "%@ 비어 있음", .fr: "%@ libre", .de: "%@ frei", .es: "%@ libre"],
        "空闲区间 %@-%@": [.en: "Idle window %@-%@", .ja: "空き時間 %@-%@", .ko: "빈 시간 %@-%@", .fr: "Plage libre %@-%@", .de: "Freies Zeitfenster %@-%@", .es: "Franja libre %@-%@"],
        "%@ 有 %d 项任务": [.en: "%@ has %d tasks", .ja: "%@ に %d 件のタスク", .ko: "%@에 %d개 작업", .fr: "%@ contient %d tâches", .de: "%@ hat %d Aufgaben", .es: "%@ tiene %d tareas"],
        "还有 %d 项同时进行": [.en: "%d more running at the same time", .ja: "同時進行があと %d 件", .ko: "%d개 더 동시에 진행", .fr: "%d autres en parallèle", .de: "%d weitere gleichzeitig", .es: "%d más en paralelo"],
        "同时进行 %d 项": [.en: "%d simultaneous tasks", .ja: "%d 件同時進行", .ko: "%d개 동시 진행", .fr: "%d tâches en parallèle", .de: "%d gleichzeitige Aufgaben", .es: "%d tareas simultáneas"],
        "%@ 等 %d 项": [.en: "%@ and %d items", .ja: "%@ ほか %d 件", .ko: "%@ 외 %d개", .fr: "%@ et %d éléments", .de: "%@ und %d Elemente", .es: "%@ y %d elementos"],
        "进行中 · %d项": [.en: "Active · %d items", .ja: "進行中 · %d 件", .ko: "진행 중 · %d개", .fr: "En cours · %d", .de: "Aktiv · %d", .es: "En curso · %d"],
        "当前：%@": [.en: "Current: %@", .ja: "現在：%@", .ko: "현재: %@", .fr: "Actuel : %@", .de: "Aktuell: %@", .es: "Actual: %@"],
        "下一个：%@": [.en: "Next: %@", .ja: "次：%@", .ko: "다음: %@", .fr: "Suivant : %@", .de: "Nächste: %@", .es: "Siguiente: %@"],
        "剩余 %d 分钟": [.en: "%d min left", .ja: "残り %d 分", .ko: "%d분 남음", .fr: "%d min restantes", .de: "%d Min. übrig", .es: "%d min restantes"],
        "应用目标日期": [.en: "Apply target date", .ja: "適用先の日付", .ko: "적용 대상 날짜", .fr: "Date cible", .de: "Zieldatum", .es: "Fecha de destino"],
        "左侧输入计划后会在这里变成可编辑时间轴。": [.en: "Paste a rough plan on the left; it becomes an editable timeline here.", .ja: "左側に計画を入力すると、ここで編集可能な時間軸になります。", .ko: "왼쪽에 계획을 입력하면 여기에서 편집 가능한 타임라인이 됩니다.", .fr: "Collez un plan à gauche ; il devient ici une chronologie modifiable.", .de: "Fügen Sie links einen groben Plan ein; hier wird daraus eine bearbeitbare Zeitleiste.", .es: "Pega un plan a la izquierda; aquí se convertirá en una línea de tiempo editable."],
        "生成后可直接改时间并应用。": [.en: "After generation, adjust times and apply.", .ja: "生成後に時間を編集して適用できます。", .ko: "생성 후 시간을 수정하고 적용할 수 있습니다.", .fr: "Après génération, modifiez les horaires puis appliquez.", .de: "Nach dem Erstellen Zeiten anpassen und anwenden.", .es: "Tras generar, ajusta las horas y aplica."],
        "%d 个任务 · 预计 %d 分钟": [.en: "%d tasks · %d min estimated", .ja: "%d 件 · 予想 %d 分", .ko: "%d개 작업 · 예상 %d분", .fr: "%d tâches · %d min prévues", .de: "%d Aufgaben · ca. %d Min.", .es: "%d tareas · %d min estimados"],
        "已应用到%@：%d 个任务。%@": [.en: "Applied to %@: %d tasks. %@", .ja: "%@ に適用しました：%d 件。%@", .ko: "%@에 적용됨: %d개 작업. %@", .fr: "Appliqué à %@ : %d tâches. %@", .de: "Auf %@ angewendet: %d Aufgaben. %@", .es: "Aplicado a %@: %d tareas. %@"],
        "点击应用时%@。": [.en: "When applying, %@.", .ja: "適用時に%@。", .ko: "적용 시 %@.", .fr: "À l'application, %@.", .de: "Beim Anwenden: %@.", .es: "Al aplicar, %@."],
        "扩展到 %@": [.en: "extend to %@", .ja: "%@ まで延長", .ko: "%@까지 확장", .fr: "extension jusqu'à %@", .de: "bis %@ erweitert", .es: "ampliar hasta %@"],
        "早于当前起点的任务已从 %@ 开始安排": [.en: "tasks before the current start were moved to %@", .ja: "現在の開始前のタスクは %@ から配置", .ko: "현재 시작 전 작업은 %@부터 배치됨", .fr: "les tâches avant le début actuel commencent à %@", .de: "Aufgaben vor dem Start wurden auf %@ verschoben", .es: "las tareas anteriores al inicio actual se movieron a %@"],
        "自动补全无效或缺失时间": [.en: "auto-filled invalid or missing times", .ja: "無効または欠落した時間を自動補完", .ko: "잘못되거나 누락된 시간 자동 보완", .fr: "heures invalides ou manquantes complétées", .de: "ungültige oder fehlende Zeiten ergänzt", .es: "horas inválidas o faltantes completadas"],
        "自动扩展当天时间范围": [.en: "expanded the day's time range", .ja: "当日の時間範囲を自動延長", .ko: "당일 시간 범위 자동 확장", .fr: "plage de la journée étendue", .de: "Tageszeitraum erweitert", .es: "rango del día ampliado"],
        "按任务顺序自动顺延重叠时间": [.en: "overlaps shifted by task order", .ja: "重複時間をタスク順に後ろ倒し", .ko: "작업 순서대로 겹침 시간 순연", .fr: "chevauchements décalés selon l'ordre", .de: "Überschneidungen nach Reihenfolge verschoben", .es: "solapamientos desplazados por orden"],
        "压缩部分任务时长": [.en: "compressed some task durations", .ja: "一部のタスク時間を短縮", .ko: "일부 작업 시간 압축", .fr: "certaines durées réduites", .de: "einige Dauern gekürzt", .es: "algunas duraciones comprimidas"],
        "新任务": [.en: "New task", .ja: "新規タスク", .ko: "새 작업", .fr: "Nouvelle tâche", .de: "Neue Aufgabe", .es: "Nueva tarea"],
        "间隔需为 0-120": [.en: "Break must be 0-120", .ja: "間隔は 0〜120", .ko: "간격은 0-120", .fr: "Pause : 0-120", .de: "Pause 0-120", .es: "Pausa 0-120"],
        "时间格式 HH:mm": [.en: "Time format HH:mm", .ja: "時刻形式 HH:mm", .ko: "시간 형식 HH:mm", .fr: "Format HH:mm", .de: "Zeitformat HH:mm", .es: "Formato HH:mm"],
        "语音输入待开始。": [.en: "Dictation is ready.", .ja: "音声入力待機中。", .ko: "음성 입력 대기 중.", .fr: "Dictée prête.", .de: "Diktat bereit.", .es: "Dictado listo."],
        "语音已写入原始计划。": [.en: "Dictation added to the raw plan.", .ja: "音声入力を元の計画に追加しました。", .ko: "음성 입력이 원본 계획에 추가되었습니다.", .fr: "Dictée ajoutée au plan brut.", .de: "Diktat zum Rohplan hinzugefügt.", .es: "Dictado añadido al plan inicial."],
        "没有识别到可写入的文字。": [.en: "No usable speech text was recognized.", .ja: "書き込める音声テキストがありません。", .ko: "쓸 수 있는 음성 텍스트를 인식하지 못했습니다.", .fr: "Aucun texte vocal utilisable reconnu.", .de: "Kein verwendbarer Sprachtext erkannt.", .es: "No se reconoció texto útil."],
        "当前系统不支持所选语言的语音识别。": [.en: "Speech recognition is not available for the selected language.", .ja: "選択した言語の音声認識は利用できません。", .ko: "선택한 언어의 음성 인식을 사용할 수 없습니다.", .fr: "La reconnaissance vocale n'est pas disponible pour cette langue.", .de: "Spracherkennung ist für die gewählte Sprache nicht verfügbar.", .es: "El reconocimiento de voz no está disponible para el idioma seleccionado."],
        "正在申请语音识别权限...": [.en: "Requesting speech recognition permission...", .ja: "音声認識権限を要求中...", .ko: "음성 인식 권한 요청 중...", .fr: "Demande d'autorisation de reconnaissance vocale...", .de: "Spracherkennungserlaubnis wird angefragt...", .es: "Solicitando permiso de reconocimiento de voz..."],
        "正在申请麦克风权限...": [.en: "Requesting microphone permission...", .ja: "マイク権限を要求中...", .ko: "마이크 권한 요청 중...", .fr: "Demande d'autorisation du microphone...", .de: "Mikrofonerlaubnis wird angefragt...", .es: "Solicitando permiso de micrófono..."],
        "正在听写...": [.en: "Listening...", .ja: "聞き取り中...", .ko: "듣는 중...", .fr: "Écoute...", .de: "Hört zu...", .es: "Escuchando..."],
        "识别完成，正在写入...": [.en: "Recognition complete, writing...", .ja: "認識完了、書き込み中...", .ko: "인식 완료, 쓰는 중...", .fr: "Reconnaissance terminée, écriture...", .de: "Erkennung fertig, schreibe...", .es: "Reconocimiento completo, escribiendo..."],
        "正在识别：%@": [.en: "Recognizing: %@", .ja: "認識中：%@", .ko: "인식 중: %@", .fr: "Reconnaissance : %@", .de: "Erkennung: %@", .es: "Reconociendo: %@"],
        "录音启动失败：%@": [.en: "Recording failed to start: %@", .ja: "録音を開始できません：%@", .ko: "녹음 시작 실패: %@", .fr: "Échec du démarrage : %@", .de: "Aufnahme konnte nicht starten: %@", .es: "No se pudo iniciar la grabación: %@"],
        "没有检测到可用麦克风输入，请检查系统输入设备。": [.en: "No usable microphone input detected. Check system input devices.", .ja: "利用可能なマイク入力がありません。システム入力を確認してください。", .ko: "사용 가능한 마이크 입력이 없습니다. 시스템 입력 장치를 확인하세요.", .fr: "Aucune entrée micro utilisable. Vérifiez les périphériques d'entrée.", .de: "Kein nutzbarer Mikrofoneingang erkannt. Eingabegeräte prüfen.", .es: "No se detectó entrada de micrófono. Revisa los dispositivos de entrada."],
        "麦克风权限未开启，请在 macOS 设置里允许 EfficientTime 使用麦克风。": [.en: "Microphone permission is off. Allow EfficientTime in macOS Settings.", .ja: "マイク権限が無効です。macOS 設定で EfficientTime を許可してください。", .ko: "마이크 권한이 꺼져 있습니다. macOS 설정에서 EfficientTime을 허용하세요.", .fr: "Le micro n'est pas autorisé. Autorisez EfficientTime dans Réglages macOS.", .de: "Mikrofonzugriff fehlt. EfficientTime in macOS-Einstellungen erlauben.", .es: "Permiso de micrófono desactivado. Permite EfficientTime en Ajustes de macOS."],
        "语音识别权限已拒绝，请在 macOS 设置里允许 EfficientTime 使用语音识别。": [.en: "Speech recognition was denied. Allow EfficientTime in macOS Settings.", .ja: "音声認識が拒否されています。macOS 設定で EfficientTime を許可してください。", .ko: "음성 인식 권한이 거부되었습니다. macOS 설정에서 EfficientTime을 허용하세요.", .fr: "Reconnaissance vocale refusée. Autorisez EfficientTime dans Réglages macOS.", .de: "Spracherkennung abgelehnt. EfficientTime in macOS-Einstellungen erlauben.", .es: "Reconocimiento de voz denegado. Permite EfficientTime en Ajustes de macOS."],
        "当前系统限制了语音识别功能。": [.en: "Speech recognition is restricted by the system.", .ja: "システムにより音声認識が制限されています。", .ko: "시스템에서 음성 인식이 제한되었습니다.", .fr: "La reconnaissance vocale est limitée par le système.", .de: "Spracherkennung ist vom System eingeschränkt.", .es: "El sistema restringe el reconocimiento de voz."],
        "语音识别权限尚未授权。": [.en: "Speech recognition is not authorized yet.", .ja: "音声認識はまだ許可されていません。", .ko: "음성 인식이 아직 승인되지 않았습니다.", .fr: "Reconnaissance vocale non encore autorisée.", .de: "Spracherkennung noch nicht autorisiert.", .es: "Reconocimiento de voz aún no autorizado."],
        "语音识别已授权。": [.en: "Speech recognition is authorized.", .ja: "音声認識は許可済みです。", .ko: "음성 인식이 허용되었습니다.", .fr: "Reconnaissance vocale autorisée.", .de: "Spracherkennung erlaubt.", .es: "Reconocimiento de voz autorizado."],
        "语音识别权限状态未知。": [.en: "Speech recognition permission status is unknown.", .ja: "音声認識権限の状態が不明です。", .ko: "음성 인식 권한 상태를 알 수 없습니다.", .fr: "État d'autorisation vocal inconnu.", .de: "Status der Spracherkennung unbekannt.", .es: "Estado del permiso de voz desconocido."]
    ]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension AppModel {
    var effectiveLanguage: AppLanguage {
        settings.language.resolved
    }

    func tr(_ key: String) -> String {
        AppLocalization.text(key, language: effectiveLanguage)
    }

    func trf(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.format(key, language: effectiveLanguage, arguments: arguments)
    }

    func statusTitle(_ status: TimeBlockStatus) -> String {
        AppLocalization.statusTitle(status, language: effectiveLanguage)
    }

    func planStatusTitle(_ status: DayPlanStatus) -> String {
        AppLocalization.planStatusTitle(status, language: effectiveLanguage)
    }

    func weekdayTitle(for date: LocalDate) -> String {
        AppLocalization.weekdayTitle(for: date, language: effectiveLanguage)
    }

    func itemCountText(_ count: Int) -> String {
        AppLocalization.itemCount(count, language: effectiveLanguage)
    }

    func minutesText(_ minutes: Int) -> String {
        AppLocalization.minutes(minutes, language: effectiveLanguage)
    }

    func durationText(seconds: Int) -> String {
        AppLocalization.duration(seconds: seconds, language: effectiveLanguage)
    }
}

extension AppTheme {
    func localizedTitle(_ language: AppLanguage) -> String {
        AppLocalization.text(title, language: language)
    }
}

extension FloatingPanelAppearance {
    func localizedTitle(_ language: AppLanguage) -> String {
        AppLocalization.text(title, language: language)
    }
}

extension CountdownStyle {
    func localizedTitle(_ language: AppLanguage) -> String {
        AppLocalization.text(title, language: language)
    }
}

extension AIProvider {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .deepSeek:
            return "DeepSeek"
        case .ark:
            return language.resolved == .zhHans ? "火山方舟" : "Volcengine Ark"
        case .openAI:
            return "OpenAI"
        case .gemini:
            return "Gemini"
        case .claude:
            return "Claude"
        }
    }
}

extension PlanningEffort {
    func localizedTitle(_ language: AppLanguage) -> String {
        AppLocalization.text(title, language: language)
    }
}

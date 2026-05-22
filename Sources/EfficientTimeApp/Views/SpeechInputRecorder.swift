import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechInputRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var statusText = "语音输入待开始。"

    private let audioEngine = AVAudioEngine()
    private var language: AppLanguage = .system
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioTap: SpeechAudioTap?
    private var latestTranscript = ""
    private var transcriptHandler: (@MainActor (String) -> Void)?
    private var permissionTimeoutTask: Task<Void, Never>?

    func setLanguage(_ language: AppLanguage) {
        guard !isRecording else { return }
        self.language = language
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: speechLocaleIdentifier(for: language)))
        if statusText == "语音输入待开始。" {
            statusText = tr("语音输入待开始。")
        }
    }

    func toggleRecording(onTranscript: @escaping @MainActor (String) -> Void) {
        if isRecording {
            stopRecording(commitTranscript: true)
        } else {
            requestAuthorizationAndStart(onTranscript: onTranscript)
        }
    }

    func stopRecording(commitTranscript: Bool = true) {
        guard isRecording || recognitionRequest != nil || recognitionTask != nil else { return }

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioTap = nil
        recognitionRequest?.endAudio()

        let didCommit = commitTranscript ? commitLatestTranscript() : false

        let task = recognitionTask
        recognitionTask = nil
        recognitionRequest = nil
        transcriptHandler = nil
        permissionTimeoutTask?.cancel()
        permissionTimeoutTask = nil
        isRecording = false
        statusText = didCommit ? tr("语音已写入原始计划。") : tr("没有识别到可写入的文字。")
        task?.cancel()
    }

    private func requestAuthorizationAndStart(onTranscript: @escaping @MainActor (String) -> Void) {
        guard speechRecognizer != nil else {
            statusText = tr("当前系统不支持所选语言的语音识别。")
            return
        }

        transcriptHandler = onTranscript
        statusText = tr("正在申请语音识别权限...")
        startPermissionTimeout(message: tr("如果系统弹出语音识别权限确认，请先允许；如果没有看到弹窗，请到 macOS 设置里检查 EfficientTime 的语音识别权限。"))
        SpeechPermissionRequester.requestSpeechAuthorization { [weak self] speechStatus in
            guard let self else { return }
            self.permissionTimeoutTask?.cancel()
            self.permissionTimeoutTask = nil
            guard speechStatus == .authorized else {
                self.statusText = self.speechAuthorizationMessage(for: speechStatus)
                self.transcriptHandler = nil
                return
            }

            self.statusText = self.tr("正在申请麦克风权限...")
            self.startPermissionTimeout(message: self.tr("如果系统弹出麦克风权限确认，请先允许；如果没有看到弹窗，请到 macOS 设置里检查 EfficientTime 的麦克风权限。"))
            SpeechPermissionRequester.requestMicrophoneAccess { [weak self] granted in
                guard let self else { return }
                self.permissionTimeoutTask?.cancel()
                self.permissionTimeoutTask = nil
                guard granted else {
                    self.statusText = self.tr("麦克风权限未开启，请在 macOS 设置里允许 EfficientTime 使用麦克风。")
                    self.transcriptHandler = nil
                    return
                }
                self.startRecording()
            }
        }
    }

    private func startRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        latestTranscript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0,
              recordingFormat.channelCount > 0
        else {
            recognitionRequest = nil
            transcriptHandler = nil
            statusText = tr("没有检测到可用麦克风输入，请检查系统输入设备。")
            return
        }
        inputNode.removeTap(onBus: 0)
        let tap = SpeechAudioTap(request: request)
        tap.install(on: inputNode, format: recordingFormat)
        audioTap = tap

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            audioTap = nil
            recognitionRequest = nil
            transcriptHandler = nil
            statusText = AppLocalization.format("录音启动失败：%@", language: language, error.localizedDescription)
            return
        }

        isRecording = true
        statusText = tr("正在听写...")
        recognitionTask = speechRecognizer?.recognitionTask(
            with: request,
            resultHandler: SpeechPermissionRequester.recognitionResultHandler { [weak self] transcript, isFinal, didError in
                self?.handleRecognitionResult(transcript: transcript, isFinal: isFinal, didError: didError)
            }
        )
    }

    private func handleRecognitionResult(transcript: String?, isFinal: Bool, didError: Bool) {
        if let transcript {
            latestTranscript = transcript
            statusText = isFinal ? tr("识别完成，正在写入...") : AppLocalization.format("正在识别：%@", language: language, latestTranscript)
        }

        if didError {
            stopRecording(commitTranscript: !latestTranscript.isEmpty)
        } else if isFinal {
            stopRecording(commitTranscript: true)
        }
    }

    private func startPermissionTimeout(message: String) {
        permissionTimeoutTask?.cancel()
        permissionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            await MainActor.run {
                guard let self,
                      !Task.isCancelled,
                      !self.isRecording
                else { return }
                self.statusText = message
            }
        }
    }

    private func commitLatestTranscript() -> Bool {
        let text = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return false
        }
        transcriptHandler?(text)
        latestTranscript = ""
        return true
    }

    private func speechAuthorizationMessage(for status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .denied:
            return tr("语音识别权限已拒绝，请在 macOS 设置里允许 EfficientTime 使用语音识别。")
        case .restricted:
            return tr("当前系统限制了语音识别功能。")
        case .notDetermined:
            return tr("语音识别权限尚未授权。")
        case .authorized:
            return tr("语音识别已授权。")
        @unknown default:
            return tr("语音识别权限状态未知。")
        }
    }

    private func tr(_ key: String) -> String {
        AppLocalization.text(key, language: language)
    }

    private func speechLocaleIdentifier(for language: AppLanguage) -> String {
        switch language.resolved {
        case .zhHans: "zh_CN"
        case .ja: "ja_JP"
        case .ko: "ko_KR"
        case .fr: "fr_FR"
        case .de: "de_DE"
        case .es: "es_ES"
        case .system, .en: "en_US"
        }
    }
}

private final class SpeechAudioTap {
    private let request: SFSpeechAudioBufferRecognitionRequest

    init(request: SFSpeechAudioBufferRecognitionRequest) {
        self.request = request
    }

    func install(on inputNode: AVAudioInputNode, format: AVAudioFormat) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [request] buffer, _ in
            request.append(buffer)
        }
    }
}

private enum SpeechPermissionRequester {
    static func requestSpeechAuthorization(
        completion: @escaping @MainActor (SFSpeechRecognizerAuthorizationStatus) -> Void
    ) {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                completion(status)
            }
        }
    }

    static func requestMicrophoneAccess(
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                completion(granted)
            }
        }
    }

    static func recognitionResultHandler(
        _ completion: @escaping @MainActor (String?, Bool, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let didError = error != nil
            Task { @MainActor in
                completion(transcript, isFinal, didError)
            }
        }
    }
}

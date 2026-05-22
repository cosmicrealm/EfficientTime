import SwiftUI

@main
@MainActor
struct EfficientTimeApp: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("EfficientTime", id: "main") {
            ContentView()
                .environmentObject(model)
                .environment(\.locale, Locale(identifier: model.effectiveLanguage.localeIdentifier))
                .onAppear {
                    model.registerMainWindowOpener {
                        openWindow(id: "main")
                    }
                    model.performStartupPresentation()
                }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
                .environment(\.locale, Locale(identifier: model.effectiveLanguage.localeIdentifier))
        } label: {
            Label(model.menuBarTitle, systemImage: "timer")
        }
    }
}

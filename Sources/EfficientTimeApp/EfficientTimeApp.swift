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
        } label: {
            Label(model.menuBarTitle, systemImage: "timer")
        }
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            model.settings.pageBackground
                .ignoresSafeArea()

            TabView {
                HSplitView {
                    ScrollView {
                        VStack(spacing: 0) {
                            QuickAddTaskView()
                            Divider()
                            PlanSettingsView()
                        }
                    }
                    .frame(minWidth: 320, idealWidth: 350, maxWidth: 420)

                    DayTimelineView()
                        .frame(minWidth: 520)

                    BlockDetailView()
                        .frame(minWidth: 390, idealWidth: 430)
                }
                .padding(.top, 6)
                .tabItem {
                    Label("计划", systemImage: "calendar")
                }

                AIPlanBuilderView()
                    .tabItem {
                        Label("智能规划", systemImage: "sparkles")
                    }

                ReviewView()
                    .tabItem {
                        Label("复盘", systemImage: "chart.bar.doc.horizontal")
                    }

                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gearshape")
                    }
            }
            .tint(model.settings.accentColor)
            .background(model.settings.pageBackground)
            .frame(minWidth: 1280, minHeight: 680)
        }
        .frame(minWidth: 1280, minHeight: 680)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}

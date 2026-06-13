import SwiftUI
import SwiftData

@main
struct InvestorProApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var portfolioStore = PortfolioStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(settings)
                .environmentObject(portfolioStore)
                .preferredColorScheme(settings.theme.colorScheme)
                .tint(Palette.accent)
        }
        .modelContainer(for: AppSchema.models)
    }
}

/// Central list of persisted SwiftData models. Extend as features land.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        AccountConfig.self,
        InstrumentMeta.self,
        PortfolioSnapshot.self
    ]
}

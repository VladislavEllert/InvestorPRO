import SwiftUI
import LocalAuthentication

/// Wraps the app in a biometric lock when enabled in settings.
struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var authenticating = false

    var body: some View {
        ZStack {
            HomeView()
            if settings.requireBiometrics && !unlocked {
                LockScreen(authenticating: authenticating) { authenticate() }
            }
        }
        .task { unlockIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: unlockIfNeeded()
            case .background: if settings.requireBiometrics { unlocked = false }
            default: break
            }
        }
        .onChange(of: settings.requireBiometrics) { _, enabled in
            if !enabled { unlocked = true } else { authenticate() }
        }
    }

    private func unlockIfNeeded() {
        guard settings.requireBiometrics else { unlocked = true; return }
        guard !unlocked, !authenticating else { return }
        authenticate()
    }

    private func authenticate() {
        let context = LAContext()
        context.localizedFallbackTitle = "Ввести код"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            unlocked = true // no biometrics/passcode set — don't lock the user out
            return
        }
        authenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Разблокировать InvestorPro") { success, _ in
            Task { @MainActor in
                authenticating = false
                if success { withAnimation { unlocked = true } }
            }
        }
    }
}

private struct LockScreen: View {
    let authenticating: Bool
    let unlock: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Palette.accent)
                Text("InvestorPro заблокирован").font(.headline)
                Button(action: unlock) {
                    Label(authenticating ? "Проверка…" : "Разблокировать", systemImage: "faceid")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Palette.accent.opacity(0.18))
                        .clipShape(Capsule())
                }
                .disabled(authenticating)
            }
        }
    }
}

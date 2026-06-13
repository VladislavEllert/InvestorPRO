import SwiftUI

// Placeholder until the ProxyAPI assistant lands (plan step 9).
struct AssistantView: View {
    var body: some View {
        ContentUnavailableView(
            "Ассистент",
            systemImage: "sparkles",
            description: Text("AI-помощник по портфелю: анализ, советы, чаты. Появится позже.")
        )
        .navigationTitle("Ассистент")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AssistantView() }
}

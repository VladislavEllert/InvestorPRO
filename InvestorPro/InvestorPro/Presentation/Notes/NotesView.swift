import SwiftUI

// Placeholder until Notes + Notion sync land (plan step 7).
struct NotesView: View {
    var body: some View {
        ContentUnavailableView(
            "Заметки",
            systemImage: "note.text",
            description: Text("Здесь появятся заметки с импортом и экспортом в Notion.")
        )
        .navigationTitle("Заметки")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { NotesView() }
}

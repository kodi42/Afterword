import SwiftUI

/// App preferences. Small for now — display toggles that back `@AppStorage` keys
/// the Library reads live. Reached from the Library's "…" menu.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.showProgressBar) private var showProgressBar = false
    @AppStorage(AppSettings.libraryLayout) private var layout: LibraryLayout = .list

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Show progress bar", isOn: $showProgressBar)
                    Picker("Library view", selection: $layout) {
                        Text("List").tag(LibraryLayout.list)
                        Text("Covers").tag(LibraryLayout.grid)
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("“Show progress bar” replaces the “Ch X of Y” label on each book with a reading-progress bar (needs a total chapter count).")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(Theme.Palette.accent)
    }
}

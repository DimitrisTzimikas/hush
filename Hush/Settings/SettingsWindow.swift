import SwiftUI

struct SettingsWindow: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Current shortcut:")
                    Text(settings.hotkeyDisplayString)
                        .fontWeight(.medium)
                }
            }

            Section("Language") {
                Picker("Transcription language", selection: $settings.language) {
                    Text("Auto-detect").tag("auto")
                    Text("English").tag("en")
                    Text("Greek").tag("el")
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 200)
        .padding()
    }
}

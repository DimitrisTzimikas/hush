import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var hotkeyModifiers: [String] {
        didSet { UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers") }
    }

    @Published var hotkeyKey: String {
        didSet { UserDefaults.standard.set(hotkeyKey, forKey: "hotkeyKey") }
    }

    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }

    var hotkeyDisplayString: String {
        KeyCodes.displayString(modifiers: hotkeyModifiers, key: hotkeyKey)
    }

    private init() {
        self.hotkeyModifiers = UserDefaults.standard.stringArray(forKey: "hotkeyModifiers") ?? ["ctrl"]
        self.hotkeyKey = UserDefaults.standard.string(forKey: "hotkeyKey") ?? "space"
        self.language = UserDefaults.standard.string(forKey: "language") ?? "auto"
    }
}

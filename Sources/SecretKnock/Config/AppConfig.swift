import Foundation

class AppConfig: ObservableObject {
    static let shared = AppConfig()

    @Published var mappings: [KnockMapping] = [] { didSet { save() } }
    @Published var sensitivity: Double = 0.3 { didSet { save() } }
    @Published var allowSharedRhythm: Bool = false { didSet { save() } }
    @Published var isFirstLaunch: Bool {
        didSet { UserDefaults.standard.set(!isFirstLaunch, forKey: "hasLaunched") }
    }

    // Without this, load()'s first assignment fires didSet and saves the other
    // properties at their defaults, clobbering what's stored.
    private var isLoading = false

    private init() {
        isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunched")
        load()
    }

    private func save() {
        guard !isLoading else { return }
        if let d = try? JSONEncoder().encode(mappings) {
            UserDefaults.standard.set(d, forKey: "mappings")
        }
        UserDefaults.standard.set(sensitivity, forKey: "sensitivity")
        UserDefaults.standard.set(allowSharedRhythm, forKey: "allowSharedRhythm")
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        if let d = UserDefaults.standard.data(forKey: "mappings"),
           let m = try? JSONDecoder().decode([KnockMapping].self, from: d) {
            mappings = m
        }
        let s = UserDefaults.standard.double(forKey: "sensitivity")
        sensitivity = s == 0 ? 0.3 : s
        allowSharedRhythm = UserDefaults.standard.bool(forKey: "allowSharedRhythm")
    }
}

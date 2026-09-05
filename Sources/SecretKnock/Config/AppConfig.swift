import Foundation

class AppConfig: ObservableObject {
    static let shared = AppConfig()

    @Published var mappings: [KnockMapping] = [] { didSet { save() } }
    @Published var sensitivity: Double = 0.2 { didSet { save() } }
    @Published var allowSharedRhythm: Bool = false { didSet { save() } }
    @Published var contextAwareGestures: Bool = false { didSet { save() } }
    @Published var contextRules: [ContextRule] = [] { didSet { save() } }
    @Published var isFirstLaunch: Bool {
        didSet { defaults.set(!isFirstLaunch, forKey: "hasLaunched") }
    }

    // Without this, load()'s first assignment fires didSet and saves the other
    // properties at their defaults, clobbering what's stored.
    private var isLoading = false

    /// Where this config persists. The app uses the standard defaults; tests
    /// pass a throwaway suite so a test run cannot write over the knocks the
    /// person using this Mac has saved.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isFirstLaunch = !defaults.bool(forKey: "hasLaunched")
        load()
    }

    private func save() {
        guard !isLoading else { return }
        if let d = try? JSONEncoder().encode(mappings) {
            defaults.set(d, forKey: "mappings")
        }
        if let d = try? JSONEncoder().encode(contextRules) {
            defaults.set(d, forKey: "contextRules")
        }
        defaults.set(sensitivity, forKey: "sensitivity")
        defaults.set(allowSharedRhythm, forKey: "allowSharedRhythm")
        defaults.set(contextAwareGestures, forKey: "contextAwareGestures")
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        if let d = defaults.data(forKey: "mappings"),
           let m = try? JSONDecoder().decode([KnockMapping].self, from: d) {
            mappings = m
        }
        // object(forKey:), not double(forKey:): the latter reports a missing key
        // as 0, which is now a legal slider position (Light Tap) — so a user who
        // dragged it fully left had it silently snapped back to the default.
        sensitivity = (defaults.object(forKey: "sensitivity") as? Double) ?? 0.2
        allowSharedRhythm = defaults.bool(forKey: "allowSharedRhythm")
        contextAwareGestures = defaults.bool(forKey: "contextAwareGestures")
        if let d = defaults.data(forKey: "contextRules"),
           let r = try? JSONDecoder().decode([ContextRule].self, from: d) {
            contextRules = r
        }
    }
}

/// "When Safari is in front, a double knock does something else." Keyed by tap
/// count so it lines up with the three slots on the main screen.
struct ContextRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var bundleID: String
    var tapCount: Int
    var action: KnockAction

    var slot: KnockSlot? { KnockSlot(rawValue: tapCount) }
}

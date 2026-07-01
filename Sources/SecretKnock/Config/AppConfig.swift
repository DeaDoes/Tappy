import Foundation

class AppConfig: ObservableObject {
    static let shared = AppConfig()

    @Published var mappings: [KnockMapping] = [] { didSet { save() } }
    @Published var sensitivity: Double = 0.3 { didSet { save() } }
    @Published var isFirstLaunch: Bool {
        didSet { UserDefaults.standard.set(!isFirstLaunch, forKey: "hasLaunched") }
    }

    // While loading, the property didSets must not save — writing mappings would
    // otherwise clobber the stored sensitivity with its default before we read it.
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
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        if let d = UserDefaults.standard.data(forKey: "mappings"),
           let m = try? JSONDecoder().decode([KnockMapping].self, from: d) {
            mappings = m
        } else {
            migrateOldSingleMapping()
        }
        let s = UserDefaults.standard.double(forKey: "sensitivity")
        sensitivity = s == 0 ? 0.3 : s
    }

    // ponytail: one-shot migration from the old single-pattern storage; delete after a release
    private func migrateOldSingleMapping() {
        guard let pd = UserDefaults.standard.data(forKey: "knockPattern"),
              let p = try? JSONDecoder().decode(KnockPattern.self, from: pd),
              let ad = UserDefaults.standard.data(forKey: "knockAction"),
              let a = try? JSONDecoder().decode(KnockAction.self, from: ad) else { return }
        mappings = [KnockMapping(name: "My knock", pattern: p, action: a)]
    }
}

import SwiftUI

enum MainPage: String, CaseIterable, Identifiable {
    case knocks = "Knocks"
    case library = "Library"
    case knockFeel = "Knock Feel"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .knocks: return "hand.tap"
        case .library: return "square.grid.2x2"
        case .knockFeel: return "slider.horizontal.3"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {
    @ObservedObject var config: AppConfig
    // Straight to Settings on the launch after an update, because that is the
    // page that says which version you are now on.
    @State private var page: MainPage =
        UpdateChecker.shared.justUpdatedFrom == nil ? .knocks : .settings

    var body: some View {
        NavigationSplitView {
            List(MainPage.allCases, selection: Binding(
                get: { page },
                // The sidebar's selection is optional; clicking the selected row
                // again clears it, and dropping to nil would blank the detail.
                set: { if let new = $0 { page = new } }
            )) { item in
                Label(item.rawValue, systemImage: item.symbol).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            switch page {
            case .knocks:    KnocksView(config: config) { page = .library }
            case .library:   LibraryView(config: config)
            case .knockFeel: KnockFeelPage(config: config)
            case .settings:  SettingsView(config: config)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }
}

/// Knock Feel on its own page. The tuning controls themselves are unchanged —
/// only the surrounding page title and the no-sensor notice live here.
struct KnockFeelPage: View {
    @ObservedObject var config: AppConfig

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Knock Feel").font(.largeTitle).bold()
                    Text("Tune how firmly you have to tap before Tappy fires.")
                        .foregroundStyle(.secondary)
                }

                // Knock Feel is meaningless without the sensor — on a Mac that
                // fell back to trackpad clicks there is no tap strength to tune.
                if KnockDetectionEngine.shared.isUsingTrackpadFallback {
                    Text("No motion sensor on this Mac, so Tappy is counting trackpad clicks instead.")
                        .foregroundStyle(.secondary)
                } else {
                    KnockFeelView(config: config).frame(maxWidth: 560)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

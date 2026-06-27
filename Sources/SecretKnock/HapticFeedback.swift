import AppKit

enum HapticFeedback {
    static func confirm() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}

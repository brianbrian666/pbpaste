import Foundation

enum RetentionPeriod: String, CaseIterable {
    case forever
    case oneDay = "1d"
    case sevenDays = "7d"
    case thirtyDays = "30d"

    var cutoff: Date? {
        switch self {
        case .forever: return nil
        case .oneDay: return .now.addingTimeInterval(-24 * 60 * 60)
        case .sevenDays: return .now.addingTimeInterval(-7 * 24 * 60 * 60)
        case .thirtyDays: return .now.addingTimeInterval(-30 * 24 * 60 * 60)
        }
    }

    var label: String {
        switch self {
        case .forever: return String(localized: "Forever")
        case .oneDay: return String(localized: "1 Day")
        case .sevenDays: return String(localized: "7 Days")
        case .thirtyDays: return String(localized: "30 Days")
        }
    }

    static var current: RetentionPeriod {
        let raw = UserDefaults.standard.string(forKey: PreferenceKeys.retention) ?? RetentionPeriod.forever.rawValue
        return RetentionPeriod(rawValue: raw) ?? .forever
    }
}

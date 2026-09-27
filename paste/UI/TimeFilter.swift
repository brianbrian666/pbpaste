import Foundation

enum TimeFilter: String, CaseIterable {
    case all
    case lastHour
    case today
    case last7Days

    var cutoff: Date? {
        switch self {
        case .all: return nil
        case .lastHour: return .now.addingTimeInterval(-60 * 60)
        case .today: return Calendar.current.startOfDay(for: .now)
        case .last7Days: return .now.addingTimeInterval(-7 * 24 * 60 * 60)
        }
    }

    var label: String {
        switch self {
        case .all: return String(localized: "All")
        case .lastHour: return String(localized: "Last Hour")
        case .today: return String(localized: "Today")
        case .last7Days: return String(localized: "Last 7 Days")
        }
    }
}

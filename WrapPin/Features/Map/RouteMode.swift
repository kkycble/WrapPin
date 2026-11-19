import Foundation
import MapKit

/// Shared by route planning, simulation, presentation and persisted recovery.
/// Raw values are part of the recovery format; keep existing values stable.
enum RouteMode: String, Codable, CaseIterable, Identifiable {
    case walking
    case cycling
    case driving

    var id: Self { self }

    var transportType: MKDirectionsTransportType {
        switch self {
        case .walking: .walking
        case .cycling: .cycling
        case .driving: .automobile
        }
    }

    var title: String {
        switch self {
        case .walking: String(localized: "Walking route")
        case .cycling: String(localized: "Cycling route")
        case .driving: String(localized: "Driving route")
        }
    }

    var symbol: String {
        switch self {
        case .walking: "figure.walk"
        case .cycling: "bicycle"
        case .driving: "car.fill"
        }
    }

    var annotationSymbol: String {
        switch self {
        case .walking: "figure.walk.circle.fill"
        case .cycling: "bicycle.circle.fill"
        case .driving: "car.circle.fill"
        }
    }

    var previewTitle: String {
        switch self {
        case .walking: String(localized: "Preview Walk")
        case .cycling: String(localized: "Preview Cycle")
        case .driving: String(localized: "Preview Drive")
        }
    }

    var startTitle: String {
        switch self {
        case .walking: String(localized: "Start Walking")
        case .cycling: String(localized: "Start Cycling")
        case .driving: String(localized: "Start Driving")
        }
    }

    var startingTitle: String {
        switch self {
        case .walking: String(localized: "Starting walking session…")
        case .cycling: String(localized: "Starting cycling session…")
        case .driving: String(localized: "Starting driving session…")
        }
    }

    var preparingTitle: String {
        switch self {
        case .walking: String(localized: "Preparing walk")
        case .cycling: String(localized: "Preparing cycle")
        case .driving: String(localized: "Preparing drive")
        }
    }

    var activeTitle: String {
        switch self {
        case .walking: String(localized: "Walking")
        case .cycling: String(localized: "Cycling")
        case .driving: String(localized: "Driving")
        }
    }

    var pausedTitle: String {
        switch self {
        case .walking: String(localized: "Walk paused")
        case .cycling: String(localized: "Cycle paused")
        case .driving: String(localized: "Drive paused")
        }
    }

    var resumeTitle: String {
        switch self {
        case .walking: String(localized: "Resume Walking")
        case .cycling: String(localized: "Resume Cycling")
        case .driving: String(localized: "Resume Driving")
        }
    }

    var movementNameFormat: String {
        switch self {
        case .walking: NSLocalizedString("Walking to %@", comment: "")
        case .cycling: NSLocalizedString("Cycling to %@", comment: "")
        case .driving: NSLocalizedString("Driving to %@", comment: "")
        }
    }

    var interruptedSummaryFormat: String {
        switch self {
        case .walking:
            NSLocalizedString("WrapPin closed before it could confirm that the simulated walk to %@ ended. Continue from the last saved point or restore this iPhone's real location.", comment: "")
        case .cycling:
            NSLocalizedString("WrapPin closed before it could confirm that the simulated cycle to %@ ended. Continue from the last saved point or restore this iPhone's real location.", comment: "")
        case .driving:
            NSLocalizedString("WrapPin closed before it could confirm that the simulated drive to %@ ended. Continue from the last saved point or restore this iPhone's real location.", comment: "")
        }
    }

    var noRouteMessage: String {
        switch self {
        case .walking: String(localized: "No walking route was found for this destination.")
        case .cycling: String(localized: "No cycling route was found for this destination. Apple Maps cycling directions are not available in every region. You can draw a custom route or import GPX instead.")
        case .driving: String(localized: "No driving route was found for this destination.")
        }
    }

    var directionsUnavailableMessage: String {
        switch self {
        case .walking: String(localized: "Walking directions are unavailable. Check Location access and your internet connection, then try again.")
        case .cycling: String(localized: "Cycling directions are unavailable. Check Location access and your internet connection. If Apple Maps has no cycling coverage here, draw a custom route or import GPX instead.")
        case .driving: String(localized: "Driving directions are unavailable. Check Location access and your internet connection, then try again.")
        }
    }

    var speedRangeKilometresPerHour: ClosedRange<Double> {
        switch self {
        case .walking: 1...12
        case .cycling: 1...60
        case .driving: 5...240
        }
    }

    var defaultSpeedKilometresPerHour: Double {
        switch self {
        case .walking: 5
        case .cycling: 18
        case .driving: 80
        }
    }

    func clampedSpeedKilometresPerHour(_ value: Double) -> Double {
        guard value.isFinite else { return defaultSpeedKilometresPerHour }
        let range = speedRangeKilometresPerHour
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

import Foundation

struct SessionRecoveryRecord: Codable, Equatable {
    enum Kind: String, Codable {
        case fixedLocation
        case walkingRoute
        case cyclingRoute
        case drivingRoute
    }

    var kind: Kind
    var lastReportedLocation: LocationTarget
    var destination: LocationTarget?
    // Kept under its original persisted name for backward compatibility.
    // The selected mode applies to fixed, walking, cycling and driving sessions.
    var fixedCoordinateMode: FixedCoordinateMode?
    var walkingPaceMetresPerSecond: Double?
    var routeSpeedMetresPerSecond: Double?
    // Optional so records written before custom routes remain decodable.
    var customRoutePoints: [SavedRoutePoint]?
    var nextCustomRoutePointIndex: Int?
    let startedAt: Date
    var updatedAt: Date

    var isRoute: Bool {
        kind != .fixedLocation && destination != nil
    }

    var routeMode: RouteMode {
        switch kind {
        case .fixedLocation, .walkingRoute: .walking
        case .cyclingRoute: .cycling
        case .drivingRoute: .driving
        }
    }

    var savedRouteSpeed: Double? {
        routeSpeedMetresPerSecond ?? walkingPaceMetresPerSecond
    }

    static func fixed(
        at target: LocationTarget,
        mode: FixedCoordinateMode
    ) -> SessionRecoveryRecord {
        SessionRecoveryRecord(
            kind: .fixedLocation,
            lastReportedLocation: target,
            destination: nil,
            fixedCoordinateMode: mode,
            walkingPaceMetresPerSecond: nil,
            routeSpeedMetresPerSecond: nil,
            startedAt: .now,
            updatedAt: .now
        )
    }

    static func route(
        from start: LocationTarget,
        to destination: LocationTarget,
        mode: RouteMode,
        coordinateMode: FixedCoordinateMode,
        speedMetresPerSecond: Double
    ) -> SessionRecoveryRecord {
        let kind: Kind = switch mode {
        case .walking: .walkingRoute
        case .cycling: .cyclingRoute
        case .driving: .drivingRoute
        }
        return SessionRecoveryRecord(
            kind: kind,
            lastReportedLocation: start,
            destination: destination,
            fixedCoordinateMode: coordinateMode,
            walkingPaceMetresPerSecond: nil,
            routeSpeedMetresPerSecond: speedMetresPerSecond,
            startedAt: .now,
            updatedAt: .now
        )
    }
}

struct SavedRoutePoint: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

import CoreLocation
import Foundation
import MapKit
import Observation

enum WalkingPace: Double, CaseIterable, Identifiable {
    case relaxed = 1.0
    case normal = 1.4
    case brisk = 1.8

    var id: Self { self }

    var title: String {
        switch self {
        case .relaxed: String(localized: "Relaxed")
        case .normal: String(localized: "Normal")
        case .brisk: String(localized: "Brisk")
        }
    }

    var metresPerSecond: Double { rawValue }
}

enum WalkingSimulationPhase: Equatable {
    case idle
    case preparing
    // Historical name for the moving phase of walking, cycling and driving.
    case walking
    case paused
    case arrived
    case stopping
    case failed(String)
}

@MainActor
@Observable
final class WalkingSimulationController {
    private(set) var phase: WalkingSimulationPhase = .idle
    private(set) var currentCoordinate: CLLocationCoordinate2D?
    private(set) var distanceTravelled: CLLocationDistance = 0
    private(set) var totalDistance: CLLocationDistance = 0
    var pace: WalkingPace = .normal
    var customWalkingSpeedKilometresPerHour: Double?
    private(set) var mode: RouteMode = .walking
    private(set) var coordinateMode: FixedCoordinateMode = .wgs84
    var cyclingSpeedKilometresPerHour: Double = RouteMode.cycling.defaultSpeedKilometresPerHour
    var drivingSpeedKilometresPerHour: Double = RouteMode.driving.defaultSpeedKilometresPerHour

    @ObservationIgnored
    private var routePoints: [MKMapPoint] = []
    @ObservationIgnored
    private var isCustomRoute = false
    @ObservationIgnored
    private var cumulativeDistances: [CLLocationDistance] = []
    @ObservationIgnored
    private(set) var destination: LocationTarget?
    @ObservationIgnored
    private var routeStart: LocationTarget?
    @ObservationIgnored
    private var movementTask: Task<Void, Never>?

    var progress: Double {
        guard totalDistance > 0 else { return 0 }
        return min(max(distanceTravelled / totalDistance, 0), 1)
    }

    var remainingDistance: CLLocationDistance {
        max(totalDistance - distanceTravelled, 0)
    }

    var remainingDuration: TimeInterval {
        remainingDistance / speedMetresPerSecond
    }

    var customRouteSpeedKilometresPerHour: Double {
        get { customWalkingSpeedKilometresPerHour ?? 5 }
        set { customWalkingSpeedKilometresPerHour = newValue.isFinite ? min(max(newValue, 0.1), 240) : 5 }
    }

    var speedMetresPerSecond: Double {
        if isCustomRoute {
            let speed = customRouteSpeedKilometresPerHour
            return (speed.isFinite ? min(max(speed, 0.1), 240) : 5) / 3.6
        }
        switch mode {
        case .walking:
            guard let customWalkingSpeedKilometresPerHour,
                  customWalkingSpeedKilometresPerHour.isFinite else { return pace.metresPerSecond }
            return mode.clampedSpeedKilometresPerHour(customWalkingSpeedKilometresPerHour) / 3.6
        case .cycling:
            return mode.clampedSpeedKilometresPerHour(cyclingSpeedKilometresPerHour) / 3.6
        case .driving:
            return mode.clampedSpeedKilometresPerHour(drivingSpeedKilometresPerHour) / 3.6
        }
    }

    /// Use the same limits for recovery and the live speed calculation. Ignore
    /// corrupt/non-finite values rather than propagating them into route progress.
    func restoreSpeed(metresPerSecond savedSpeed: Double) {
        guard savedSpeed.isFinite else { return }
        let kilometresPerHour = savedSpeed * 3.6
        if isCustomRoute {
            customRouteSpeedKilometresPerHour = kilometresPerHour
            return
        }
        switch mode {
        case .walking:
            if let recoveredPace = WalkingPace.allCases.first(where: {
                abs($0.metresPerSecond - savedSpeed) < 0.0001
            }) {
                pace = recoveredPace
                customWalkingSpeedKilometresPerHour = nil
            } else {
                customWalkingSpeedKilometresPerHour = mode.clampedSpeedKilometresPerHour(kilometresPerHour)
            }
        case .cycling:
            cyclingSpeedKilometresPerHour = mode.clampedSpeedKilometresPerHour(kilometresPerHour)
        case .driving:
            drivingSpeedKilometresPerHour = mode.clampedSpeedKilometresPerHour(kilometresPerHour)
        }
    }

    var locksDestination: Bool {
        switch phase {
        case .preparing, .walking, .paused, .arrived, .stopping:
            true
        case .idle, .failed:
            false
        }
    }

    func prepare(
        route: SimulationRoute,
        destination: LocationTarget,
        mode: RouteMode = .walking,
        coordinateMode: FixedCoordinateMode,
        startName: String? = nil
    ) {
        movementTask?.cancel()
        movementTask = nil
        self.mode = mode
        self.coordinateMode = coordinateMode

        if isCustomRoute && !route.isCustom { customWalkingSpeedKilometresPerHour = nil }
        isCustomRoute = route.isCustom
        routePoints = route.mapPoints
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last ?? route.distance
        distanceTravelled = 0
        currentCoordinate = nil
        self.destination = destination
        if let startCoordinate = routePoints.first?.coordinate {
            routeStart = LocationTarget(
                name: startName ?? String(localized: "Route Start"),
                subtitle: String(
                    format: NSLocalizedString("Starting point for %@", comment: ""),
                    destination.name
                ),
                latitude: startCoordinate.latitude,
                longitude: startCoordinate.longitude
            )
        } else {
            routeStart = nil
        }
        phase = routePoints.count >= 2
            ? .idle
            : .failed(String(localized: "This route does not contain enough detail to simulate movement."))
    }

    func prepareReturnTrip() -> LocationTarget? {
        guard
            (mode == .walking || isCustomRoute),
            phase == .arrived,
            let returnDestination = routeStart,
            let previousDestination = destination,
            routePoints.count >= 2
        else { return nil }

        movementTask?.cancel()
        movementTask = nil
        routePoints.reverse()
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last ?? totalDistance
        distanceTravelled = 0
        currentCoordinate = nil
        destination = returnDestination
        routeStart = previousDestination
        phase = .idle
        return returnDestination
    }

    func start(using appModel: AppModel) async {
        guard
            !routePoints.isEmpty,
            let destination,
            phase == .idle || isFailed
        else { return }
        guard case .paired = appModel.pairingStatus else {
            phase = .failed(String(localized: "Pair this iPhone before starting a route session."))
            return
        }

        movementTask?.cancel()
        distanceTravelled = 0
        currentCoordinate = routePoints[0].coordinate
        phase = .preparing

        await appModel.startRouteLocationSession(
            at: movementTarget(at: routePoints[0].coordinate, destination: destination),
            destination: destination,
            mode: mode,
            coordinateMode: coordinateMode,
            speedMetresPerSecond: speedMetresPerSecond,
            customRoutePoints: isCustomRoute ? routePoints.map {
                SavedRoutePoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
            } : nil
        )

        if case .idle = appModel.deviceSession.phase, phase == .preparing {
            phase = .failed(String(localized: "WrapPin could not start the route session."))
        }
    }

    func togglePause() {
        switch phase {
        case .walking:
            phase = .paused
        case .paused:
            phase = .walking
        case .idle, .preparing, .arrived, .stopping, .failed:
            break
        }
    }

    func stop(using deviceSession: LocalDeviceSessionCoordinator) {
        guard locksDestination || isFailed else { return }
        movementTask?.cancel()
        movementTask = nil

        if case .idle = deviceSession.phase {
            currentCoordinate = nil
            distanceTravelled = 0
            phase = .idle
            return
        }

        phase = .stopping
        deviceSession.stop()
    }

    func handleDeviceSessionPhase(
        _ devicePhase: DeviceSessionPhase,
        deviceSession: LocalDeviceSessionCoordinator,
        appModel: AppModel
    ) {
        switch devicePhase {
        case .active:
            guard phase == .preparing else { return }
            phase = .walking
            beginMovement(using: deviceSession, appModel: appModel)

        case .stopping:
            if locksDestination || isFailed {
                movementTask?.cancel()
                movementTask = nil
                phase = .stopping
            }

        case .idle:
            guard phase == .stopping else { return }
            movementTask?.cancel()
            movementTask = nil
            currentCoordinate = nil
            distanceTravelled = 0
            phase = .idle

        case .failed(let message):
            guard locksDestination || phase == .preparing else { return }
            movementTask?.cancel()
            movementTask = nil
            currentCoordinate = nil
            phase = .failed(message)

        case .openingLocalDevVPN, .discovering, .connecting:
            break
        }
    }

    func reset() {
        movementTask?.cancel()
        movementTask = nil
        routePoints = []
        cumulativeDistances = []
        destination = nil
        routeStart = nil
        currentCoordinate = nil
        distanceTravelled = 0
        totalDistance = 0
        phase = .idle
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func beginMovement(using deviceSession: LocalDeviceSessionCoordinator, appModel: AppModel) {
        movementTask?.cancel()
        movementTask = Task { @MainActor [weak self, weak deviceSession, weak appModel] in
            var lastTick = Date.now

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, let deviceSession, let appModel else { return }

                let now = Date.now
                let elapsed = now.timeIntervalSince(lastTick)
                lastTick = now

                if self.phase == .paused {
                    continue
                }
                // Preserve the route point while the device channel is rebuilt;
                // elapsed reconnect time must not jump the route forward.
                if deviceSession.isReconnecting { continue }
                guard self.phase == .walking, let destination = self.destination else { return }

                self.distanceTravelled = min(
                    self.totalDistance,
                    self.distanceTravelled + (self.speedMetresPerSecond * elapsed)
                )

                guard let coordinate = self.coordinate(at: self.distanceTravelled) else {
                    self.phase = .failed(String(localized: "WrapPin could not follow this route."))
                    return
                }

                self.currentCoordinate = coordinate
                let reachedDestination = self.distanceTravelled >= self.totalDistance
                let target = reachedDestination
                    ? destination
                    : self.movementTarget(at: coordinate, destination: destination)

                // Keep MapKit's route untouched for drawing and progress. Only
                // transform the coordinate sent through LocationSimulation.
                let simulationCoordinates = FixedCoordinateTransform.coordinates(
                    for: target,
                    mode: self.coordinateMode
                )
                guard deviceSession.updateLocation(
                    target,
                    simulationCoordinates: simulationCoordinates
                ) == .updated else {
                    self.phase = .failed(String(localized: "The active location session ended before the route finished."))
                    return
                }

                if self.isCustomRoute {
                    let nextIndex = self.cumulativeDistances.firstIndex(where: { $0 > self.distanceTravelled })
                        ?? self.routePoints.count
                    appModel.recordCustomRouteProgress(nextPointIndex: nextIndex, at: target)
                }

                if reachedDestination {
                    self.currentCoordinate = destination.coordinate
                    self.phase = .arrived
                    return
                }
            }
        }
    }

    private func cumulativeDistanceValues(for points: [MKMapPoint]) -> [CLLocationDistance] {
        guard !points.isEmpty else { return [] }

        var values: [CLLocationDistance] = [0]
        values.reserveCapacity(points.count)
        for index in 1..<points.count {
            values.append(
                values[index - 1] + points[index - 1].distance(to: points[index])
            )
        }
        return values
    }

    private func coordinate(at distance: CLLocationDistance) -> CLLocationCoordinate2D? {
        guard let first = routePoints.first else { return nil }
        guard routePoints.count > 1, totalDistance > 0 else { return first.coordinate }
        if distance <= 0 { return first.coordinate }
        if distance >= totalDistance { return routePoints.last?.coordinate }

        var lower = 1
        var upper = cumulativeDistances.count - 1
        while lower < upper {
            let middle = (lower + upper) / 2
            if cumulativeDistances[middle] < distance {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        let upperIndex = lower
        let lowerIndex = max(upperIndex - 1, 0)
        let lowerDistance = cumulativeDistances[lowerIndex]
        let upperDistance = cumulativeDistances[upperIndex]
        let segmentLength = upperDistance - lowerDistance
        guard segmentLength > 0 else { return routePoints[upperIndex].coordinate }

        let fraction = (distance - lowerDistance) / segmentLength
        let start = routePoints[lowerIndex]
        let end = routePoints[upperIndex]
        return MKMapPoint(
            x: start.x + ((end.x - start.x) * fraction),
            y: start.y + ((end.y - start.y) * fraction)
        ).coordinate
    }

    private func movementTarget(
        at coordinate: CLLocationCoordinate2D,
        destination: LocationTarget
    ) -> LocationTarget {
        LocationTarget(
            name: String(
                format: mode.movementNameFormat,
                destination.name
            ),
            subtitle: String(
                format: NSLocalizedString("%lld%% complete", comment: ""),
                Int((progress * 100).rounded())
            ),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

import Foundation

/// The EPA's six Air Quality Index categories, split at the standard breakpoints
/// (50/100/150/200/300). Lives in the engine rather than the UI because the
/// breakpoints are EPA domain knowledge, not presentation — the UI layers map
/// categories to their own colors.
public enum AQICategory: Sendable, Equatable, CaseIterable {
    case good
    case moderate
    case unhealthyForSensitiveGroups
    case unhealthy
    case veryUnhealthy
    case hazardous

    public init(aqi: Int) {
        switch aqi {
        case ..<51: self = .good
        case ..<101: self = .moderate
        case ..<151: self = .unhealthyForSensitiveGroups
        case ..<201: self = .unhealthy
        case ..<301: self = .veryUnhealthy
        default: self = .hazardous
        }
    }
}

import Foundation
import MapKit

/// Represents  a token that is returns when the user authenticates.
struct Token: Codable {
    let access_token: String
    let token_type: String
    var exporationDate: Date?
    
    static func defaultExpirationDate() -> Date {
        let calendar = Calendar.current
        let currentDate = Date()
        return calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }
    
}

/// Represents a trip.
struct Trip: Codable, Identifiable, Sendable, Hashable {
    var id: Int
    var name: String
    var start_date: Date
    var end_date: Date
    var events: [Event]
}

/// Represents an event in a trip.
struct Event: Codable, Identifiable, Sendable, Hashable {
    var id: Int
    var name: String
    var note: String?
    var date: Date
    var location: Location?
    var medias: [Media]
    var transition_from_previous: String?
}

/// Represents a location.
struct Location: Codable, Sendable, Hashable {
    var latitude: Double
    var longitude: Double
    var address: String?

    var coordinate: CLLocationCoordinate2D {
        return .init(latitude: latitude, longitude: longitude)
    }
}

/// Represents a media with a URL.
struct Media: Codable, Identifiable, Sendable, Hashable {
    var id: Int
    var url: URL?
}

struct Register: Encodable, Sendable, Hashable {
    var username: String
    var password: String
}

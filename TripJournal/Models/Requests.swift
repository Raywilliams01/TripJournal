import Foundation

/// An object that can be used to create a new trip.
struct TripCreate: Codable {
    let name: String
    let start_date: Date
    let end_date: Date
}

/// An object that can be used to update an existing trip.
struct TripUpdate: Codable {
    let name: String
    let start_date: Date
    let end_date: Date
}

/// An object that can be used to create a media.
struct MediaCreate: Codable {
    let event_id: Event.ID
    let base64_data: Data
}

/// An object that can be used to create a new event.
struct EventCreate: Codable {
    let trip_id: Trip.ID
    let name: String
    let note: String?
    let date: Date
    let location: Location?
    let transition_from_previous: String?
}

/// An object that can be used to update an existing event.
struct EventUpdate: Codable {
    var name: String
    var note: String?
    var date: Date
    var location: Location?
    var transition_from_previous: String?
}

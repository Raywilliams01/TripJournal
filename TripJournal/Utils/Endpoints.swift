//
//  Endpoints.swift
//  TripJournal
//
//  Created by ray williams on 11/30/24.
//

import Foundation

enum Endpoints {
    case register
    case login
    case trips
    case events
    case media
    
    var url: String {
        switch self {
            case .register:
                return "register"
            case .login:
                return "token"
            case .trips:
                return "trips"
            case .events:
                return "events"
            case .media:
                return "media"
        }
    }
}

enum AppEnviroment: String {
    case base
    
    var baseURL: URL {
        switch self {
        case .base:
            return URL(string: "http://localhost:8000/")!
        }
    }
}

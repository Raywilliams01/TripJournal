//
//  JournalService+Live.swift
//  TripJournal
//
//  Created by ray williams on 11/17/24.
//

import Combine
import Foundation

enum NetworkError: Error {
    case badRequest
    case decodingError
    case badURL
    case badResponse
    case failedToDecodeResponse
    case encodingError
}

enum NetworkMethod: String {
    case get
    case put
    case post
    case delete
    
    var value: String {
        switch self {
            case .get:
                return "GET"
            case .put:
                return "PUT"
            case .post:
                return "POST"
            case .delete:
                return "DELETE"
        }
    }
}



class JournalServiceLive: JournalService {
    
    private var baseURL: URL
    
    var tokenExpired: Bool = false
    
    @Published private var token: Token? {
        didSet {
            if let token = token {
                try? KeychainHelper.shared.saveToken(token)
            } else {
                try? KeychainHelper.shared.deleteToken()
            }
        }
    }
    
    var isAuthenticated: AnyPublisher<Bool, Never> {
        $token
            .map { $0 != nil }
            .eraseToAnyPublisher()
    }
    
    init() {
        self.baseURL = AppEnviroment.base.baseURL
        
        if let keychainToken = try? KeychainHelper.shared.getToken(){
            if !isTokenExpired(keychainToken) {
                self.token = keychainToken
            } else {
                self.tokenExpired = true
                self.token = nil
            }
        }
    }
    
    private func isTokenExpired(_ token: Token) -> Bool {
        guard let expirationDate = token.exporationDate else {
            return false
        }
        
        return expirationDate <= Date()
    }
    
    private func createLoginRegister(username: String, password: String) throws -> URLRequest {
        guard let url = URL(string: Endpoints.register.url, relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        let register = Register(username: username, password: password)
        
        var request = URLRequest(url: url)
        request.httpMethod = NetworkMethod.post.value
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(register)
        
        return request
    }
    
    private func performNetworkRequest(_ request: URLRequest) async throws -> Token {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 else {
            throw NetworkError.badResponse
        }
        
        do {
            var token = try JSONDecoder().decode(Token.self, from: data)
            token.exporationDate = Token.defaultExpirationDate()
            self.token = token
            return token
        } catch {
            throw NetworkError.failedToDecodeResponse
        }
    }
    
    func register(username: String, password: String) async throws -> Token {
        let request = try createLoginRegister(username: username, password: password)
        return try await performNetworkRequest(request)
    }
    
    func logIn(username: String, password: String) async throws -> Token {
        guard let url = URL(string: Endpoints.login.url, relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        let loginData = "grant_type=&username=\(username)&password=\(password)"
        
        var request  = URLRequest(url: url)
        request.httpMethod = NetworkMethod.post.value
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = loginData.data(using: .utf8)
        
    do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badResponse
            }
        
            do {
                var token = try JSONDecoder().decode(Token.self, from: data)
                token.exporationDate = Token.defaultExpirationDate()
                self.token = token
                return token
            } catch {
                throw NetworkError.failedToDecodeResponse
            }
        } catch {
           throw NetworkError.badResponse
       }
    }
    
    func logOut() {
        try? KeychainHelper.shared.deleteToken()
        token = nil
    }
    
    func createTrip(with request: TripCreate) async throws -> Trip {
        guard let url = URL(string: Endpoints.trips.url, relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        var requestURL = URLRequest(url: url)
        guard let access_token = self.token?.access_token  else {
            throw NetworkError.badURL
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let jsonData = try encoder.encode(request)
            requestURL.httpBody = jsonData
        } catch {
            throw NetworkError.encodingError
        }
        
        requestURL.httpMethod = NetworkMethod.post.value
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        requestURL.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: requestURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badRequest
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let trips = try decoder.decode(Trip.self, from: data)
                return trips
            } catch {
                throw NetworkError.decodingError
            }
        } catch {
            throw NetworkError.badResponse
        }
    }
    
    func getTrips() async throws -> [Trip] {
        guard let url = URL(string: Endpoints.trips.url, relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = NetworkMethod.get.value
        
        if let access_token = self.token?.access_token {
            request.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        }
        
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badResponse
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let trips = try decoder.decode([Trip].self, from: data)
                return trips
            } catch {
                throw NetworkError.decodingError
            }
        } catch {
            throw NetworkError.badRequest
        }
    }
    
    func getTrip(withId tripId: Trip.ID) async throws -> Trip {
        guard let url = URL(string: Endpoints.trips.url+"/\(tripId)", relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        guard let access_token = self.token?.access_token  else {
            throw NetworkError.badURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = NetworkMethod.get.value
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badRequest
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let singleTrip = try decoder.decode(Trip.self, from: data)
            return singleTrip
        } catch {
            throw NetworkError.decodingError
        }
        
    }
    
    func updateTrip(withId tripId: Trip.ID, and request: TripUpdate) async throws -> Trip {
        guard let url = URL(string: Endpoints.trips.url+"/\(tripId)", relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        guard let access_token = self.token?.access_token  else {
            throw NetworkError.badURL
        }
        
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = NetworkMethod.put.value
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        requestURL.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let jsonData = try encoder.encode(request)
            requestURL.httpBody = jsonData
        } catch {
            throw NetworkError.encodingError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: requestURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badRequest
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let trips = try decoder.decode(Trip.self, from: data)
            return trips
        } catch {
            throw NetworkError.badResponse
        }
        
    }
    
    func deleteTrip(withId tripId: Trip.ID) async throws {
        guard let url = URL(string: Endpoints.trips.url+"/\(tripId)", relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        guard let access_token = self.token?.access_token else {
            throw NetworkError.badURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = NetworkMethod.delete.value
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
          
            guard let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200 ||
                    httpResponse.statusCode == 204 else {
                throw NetworkError.badRequest
            }
        } catch {
            throw NetworkError.decodingError
        }
    }
    
    func createEvent(with request: EventCreate) async throws -> Event {
        guard let url = URL(string: Endpoints.events.url, relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        guard let access_token = self.token?.access_token  else {
            throw NetworkError.badURL
        }
        
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = NetworkMethod.post.value
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        requestURL.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let jsonData = try encoder.encode(request)
            requestURL.httpBody = jsonData
        } catch {
            throw NetworkError.encodingError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: requestURL)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badRequest
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let event = try decoder.decode(Event.self, from: data)
                return event
            } catch {
                throw NetworkError.decodingError
            }
        } catch {
            throw NetworkError.badResponse
        }
    }
    
    func updateEvent(withId eventId: Event.ID, and request: EventUpdate) async throws -> Event {
        guard let url = URL(string: Endpoints.events.url+"/\(eventId)", relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        guard let access_token = self.token?.access_token  else {
            throw NetworkError.badURL
        }
        
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = NetworkMethod.put.value
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        requestURL.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let jsonData = try encoder.encode(request)
            requestURL.httpBody = jsonData
        } catch {
            throw NetworkError.encodingError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: requestURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badRequest
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let event = try decoder.decode(Event.self, from: data)
                return event
            } catch {
                throw NetworkError.decodingError
            }
        } catch {
            throw NetworkError.badResponse
        }
    }
    
    func deleteEvent(withId eventId: Event.ID) async throws {
        guard let url = URL(string: Endpoints.events.url+"/\(eventId)", relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        guard let access_token = self.token?.access_token  else {
            throw NetworkError.badURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = NetworkMethod.put.value
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badRequest
            }
        } catch {
            throw NetworkError.decodingError
        }
    }
    
    func createMedia(with request: MediaCreate) async throws -> Media {
        guard let url = URL(string: Endpoints.media.url, relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
       
        guard let access_token = self.token?.access_token  else {
            throw NetworkError.badURL
        }
        
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = NetworkMethod.post.value
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        requestURL.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let jsonData = try encoder.encode(request)
            requestURL.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: requestURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badRequest
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let media = try decoder.decode(Media.self, from: data)
            return media
        } catch {
            throw NetworkError.decodingError
        }
    }
    
    func deleteMedia(withId mediaId: Media.ID) async throws {
        guard let url = URL(string: Endpoints.media.url+"/\(mediaId)", relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        
        guard let access_token = self.token?.access_token else {
            throw NetworkError.badURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = NetworkMethod.delete.value
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.badRequest
            }
        } catch {
            throw NetworkError.decodingError
        }
        
    }
    
    
}

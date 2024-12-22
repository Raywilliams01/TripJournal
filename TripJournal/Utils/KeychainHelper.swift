//
//  KeychainHelper.swift
//  TripJournal
//
//  Created by ray williams on 12/8/24.
//

import Foundation
import Security

enum KeychainError: Error {
    case unableToSaveToken
    case unableToDeleteToken
}

class KeychainHelper {
    static let shared = KeychainHelper()
    private let serviceName = "com.TripJournal.service"
    private let accountName = "authToken"
    
    private init(){}
    
    func saveToken(_ token: Token) throws {
        let tokenData = try JSONEncoder().encode(token)
        let query: [String: Any]  = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: tokenData
        ]
        
        var status = SecItemDelete(query as CFDictionary)
        status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unableToSaveToken
        }
    }
    
    func getToken() throws -> Token? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject? = nil
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else {
            return nil
        }

        guard let data = dataTypeRef as? Data else {
            return nil
        }

        let decodedJson = try JSONDecoder().decode(Token.self, from: data)
        return decodedJson
    }
    
    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrServer as String: accountName
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.unableToDeleteToken
        }
    }
}

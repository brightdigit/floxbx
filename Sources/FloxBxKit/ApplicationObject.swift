//
//  File.swift
//  
//
//  Created by Leo Dion on 5/16/21.
//

import Combine
import SwiftUI

struct EmptyError : Error {
  
}

public struct CredentialsContainer {
  func fetch () throws -> Credentials? {
    let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                kSecAttrServer as String: ApplicationObject.server,
                                kSecMatchLimit as String: kSecMatchLimitOne,
                                kSecReturnAttributes as String: true,
                                kSecReturnData as String: true]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status != errSecItemNotFound else { throw KeychainError.noPassword }
    guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    guard let existingItem = item as? [String : Any],
        let passwordData = existingItem[kSecValueData as String] as? Data,
        let password = String(data: passwordData, encoding: String.Encoding.utf8),
        let account = existingItem[kSecAttrAccount as String] as? String
    else {
        throw KeychainError.unexpectedPasswordData
    }
    return Credentials(username: account, password: password)
  }
  
  func save (credentials: Credentials) throws {
    let account = credentials.username
    let password = credentials.password.data(using: String.Encoding.utf8)!
    let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                kSecAttrAccount as String: account,
                                kSecAttrServer as String: ApplicationObject.server,
                                kSecValueData as String: password]
    
    // on success
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
  }
}

public extension Result {
  init(success: Success?, failure: Failure?, otherwise: @autoclosure () -> Failure) {
    if let failure = failure {
      self = .failure(failure)
    } else if let success = success {
      self = .success(success)
    } else {
      self = .failure(otherwise())
    }
  }
}
public struct Credentials {
    var username: String
    var password: String
  var token: String?
}

enum KeychainError: Error {
    case noPassword
    case unexpectedPasswordData
    case unhandledError(status: OSStatus)
}

public class ApplicationObject: ObservableObject {
  @Published public var token : String? = nil
  @Published public var requiresAuthentication: Bool
  static let server = "www.example.com"
  public init () {
    #if os(macOS)
    self.requiresAuthentication = false
    #else
    self.requiresAuthentication = true
    #endif
  }
  
  public func begin() throws {
    #if os(macOS)
    self.requiresAuthentication = true
    #endif

  }
  
  public func beginSignup() {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    var request = URLRequest(url: URL(string: "http://localhost:8080/api/v1/users")!)
    request.httpMethod = "POST"
    let emailAddress = ""
    let password = ""
    let body = try! encoder.encode(CreateUserRequestContent(emailAddress: emailAddress, password: password))
    request.httpBody = body
    URLSession.shared.dataTask(with: request) { data, response, error in
      
      let result : Result<Data, Error> = Result<Data, Error>(success: data, failure: error, otherwise: EmptyError())
      let decodedResult = result.flatMap { data in
        Result {
          try decoder.decode(CreateUserResponseContent.self, from: data)
        }
      }
      let credentials = decodedResult.map{ content in
        return Credentials(username: emailAddress, password: password, token: content.token)
      }
    }
  }
  
  public func beginSignIn(withCredentials credentials: Credentials) throws {

  }
}

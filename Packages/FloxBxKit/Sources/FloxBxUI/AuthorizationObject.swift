//
//  SwiftUIView.swift
//  
//
//  Created by Leo Dion on 2/3/23.
//

import Foundation
import Combine
import FloxBxAuth
import FloxBxNetworking
import FloxBxRequests

class AuthorizationObject: ObservableObject {
  internal init(service: any AuthorizedService, account: Account? = nil) {
    self.service = service
    self.account = account
    
    successfulCompletedSubject.map(Optional.some).receive(on: DispatchQueue.main).assign(to: &self.$account)
    
    let logoutCompleted = self.logoutCompletedSubject.share()
    
    logoutCompleted.compactMap{
      (try? $0.get()).map {
        return nil
      }
    }
    .receive(on: DispatchQueue.main)
    .assign(to: &self.$account)
    
    
    logoutCompleted.compactMap {
      $0.asError()
    }.receive(on: DispatchQueue.main)
      .assign(to: &self.$error)
    
  }
  
  
  let service : any AuthorizedService
  @Published var account: Account?
  @Published var error : Error?
  let logoutCompletedSubject = PassthroughSubject<Result<Void, Error>, Never>()
  let successfulCompletedSubject = PassthroughSubject<Account, Never>()
  
  
  
  internal func beginSignup(withCredentials credentials: Credentials) {
    Task{
      let tokenContainer = try await self.service.request(SignUpRequest(body: .init(emailAddress: credentials.username, password: credentials.password)))
      let newCreds = credentials.withToken(tokenContainer.token)
#warning("Fix upsert")
      try self.service.save(credentials: newCreds)
      
      successfulCompletedSubject.send(Account(username: credentials.username))
    }
  }
  
  func beginSignIn(withCredentials credentials: Credentials) {
    Task{
      let tokenContainer = try await self.service.request(SignInCreateRequest(body: .init(emailAddress: credentials.username, password: credentials.password)))
      let newCreds = credentials.withToken(tokenContainer.token)
      #warning("Fix upsert")
      try self.service.save(credentials: newCreds)
      
      successfulCompletedSubject.send(Account(username: credentials.username))
    }
  }
  
  func logout () {
    let result = Result{
      try service.resetCredentials()
    }
    self.logoutCompletedSubject.send(result)
  }
}

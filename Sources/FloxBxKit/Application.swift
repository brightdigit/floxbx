//
//  FloxBxApp.swift
//  Shared
//
//  Created by Leo Dion on 5/10/21.
//


#if os(Linux) || os(macOS)
import SentryVanilla
#endif

#if !os(Linux)
import SentryCocoa
#endif

public enum ApplicationType {
  #if os(Linux) || os(macOS)
  case server
  #endif
#if !os(Linux)
  case client
  #endif
}
public class Sentry {
  public static func start (_ type: ApplicationType) {
    switch type {
  #if os(Linux) || os(macOS)
    case .server:
      try? SentryVanilla.Sentry.start { options in
        options.dsn = "https://d2a8d5241ccf44bba597074b56eb692d@o919385.ingest.sentry.io/5868822"
        
        //options.debug = true // Enabled debug when first installing is always helpful
      }
      SentryVanilla.Sentry.capture(event: .init(message: "Hello World", tags: nil), configureScope: nil)
      #endif
#if !os(Linux)
    case .client:
      SentrySDK.start { options in
        options.dsn = "https://d2a8d5241ccf44bba597074b56eb692d@o919385.ingest.sentry.io/5868822"
      }
      SentrySDK.capture(message: "Hello World")
      #endif
    }
//    #if canImport(SentryCocoa)
//    SentrySDK.start { options in
//      options.dsn = "https://d2a8d5241ccf44bba597074b56eb692d@o919385.ingest.sentry.io/5868822"
//    }
//    SentrySDK.capture(message: "Hello World")
//    #else
//    try? SentryVanilla.Sentry.start { options in
//      options.dsn = "https://d2a8d5241ccf44bba597074b56eb692d@o919385.ingest.sentry.io/5868822"
//
//      //options.debug = true // Enabled debug when first installing is always helpful
//    }
//    SentryVanilla.Sentry.capture(event: .init(message: "Hello World", tags: nil), configureScope: nil)
//    #endif
//    
//    SentryCocoa.SentrySDK.start { options in
//      options.dsn
//      options.de
//    }
  }
}

#if canImport(SwiftUI)
import SwiftUI

public protocol Application: App {
  
}

public extension Application {
  var body: some Scene {
      WindowGroup {
        ContentView().environmentObject(ApplicationObject()).onAppear {
          Sentry.start(.client)
        }
      }
  }
}
#endif

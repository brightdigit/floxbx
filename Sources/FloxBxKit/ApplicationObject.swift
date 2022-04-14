public enum Configuration {
  public static let dsn = "https://d2a8d5241ccf44bba597074b56eb692d@o919385.ingest.sentry.io/5868822"
}

#if canImport(Combine) && canImport(SwiftUI)
  import Canary
  import Combine
  import SwiftUI



  #if canImport(GroupActivities)
    import GroupActivities

   @available(iOS 15, macOS 12, *)
   public struct FloxBxActivity : GroupActivity  {
     
  internal init(username: String) {
    var metadata = GroupActivityMetadata()
    metadata.title = "\(username) FloxBx"
    metadata.type = .generic
    self.metadata = metadata
  }


  public let metadata : GroupActivityMetadata



   }

#endif

enum TodoListDelta : Codable {
  case upsert(UUID?, CreateTodoRequestContent)
  case remove([UUID])
}

  public class ApplicationObject: ObservableObject {
    
#if canImport(GroupActivities)
     @available(iOS 15, macOS 12, *)
     @State var groupSession: GroupSession<FloxBxActivity>?
    
    @available(iOS 15, macOS 12, *)
    private(set) lazy var messenger: GroupSessionMessenger? = nil
    
    
    var subscriptions = Set<AnyCancellable>()
    var tasks = Set<Task<Void, Never>>()
    func addDelta(_ delta: TodoListDelta) {
        DispatchQueue.main.async {
            self.listDeltas.append(delta)
        }

        if #available(iOS 15, macOS 12, *) {
            if let messenger = self.messenger {
                Task {
                    try? await messenger.send([delta])
                }
            }
        }
    }
    #endif
    
    @Published public var requiresAuthentication: Bool
    @Published var latestError: Error?
    @Published var token: String?
    @Published var username: String?
    @Published var items = [TodoContentItem]()
    @Published var listDeltas = [TodoListDelta]()
    let service: Service = ServiceImpl(host: ProcessInfo.processInfo.environment["HOST_NAME"]!, headers: ["Content-Type": "application/json; charset=utf-8"])

    let sentry = CanaryClient()

    static let baseURL: URL = {
      var components = URLComponents()
      components.host = ProcessInfo.processInfo.environment["HOST_NAME"]
      components.scheme = "https"
      return components.url!
    }()

    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
    static let server = "floxbx.work"
    public init(items _: [TodoContentItem] = []) {
      requiresAuthentication = true
      let authenticated = $token.map { $0 == nil }
      authenticated.receive(on: DispatchQueue.main).assign(to: &$requiresAuthentication)
      
      $token.share().compactMap { $0 }.flatMap { _ in
        Future { closure in
          self.service.beginRequest(GetTodoListRequest(userID: nil)) { result in
            closure(result)
          }
        }
      }.map { content in
        content.map(TodoContentItem.init)
      }
      .replaceError(with: []).receive(on: DispatchQueue.main).assign(to: &$items)

      try! sentry.start(withOptions: .init(dsn: Configuration.dsn))
    }

    public func saveItem(_ item: TodoContentItem, onlyNew: Bool = false) {
      guard let index = items.firstIndex(where: { $0.id == item.id }) else {
        return
      }

      guard !(item.isSaved && onlyNew) else {
        return
      }

      let content = CreateTodoRequestContent(title: item.title)
      let request = UpsertTodoRequest(itemID: item.serverID, body: content)

#if canImport(GroupActivities)
      self.addDelta(.upsert(item.serverID, content))
      #endif
      service.beginRequest(request) { todoItemResult in
        switch todoItemResult {
        case let .success(todoItem):

          DispatchQueue.main.async {
            self.items[index] = .init(content: todoItem)
          }

        case let .failure(error):

          DispatchQueue.main.async {
            self.latestError = error
          }
        }
      }
    }

    public func begin() {
      let credentials: Credentials?
      let error: Error?

      do {
        credentials = try service.fetchCredentials()
        error = nil
      } catch let caughtError {
        error = caughtError
        credentials = nil
      }

      latestError = latestError ?? error

      if let credentials = credentials {
        beginSignIn(withCredentials: credentials)
      } else {
        DispatchQueue.main.async {
          self.requiresAuthentication = true
        }
      }
    }

    public func beginDeleteItems(atIndexSet indexSet: IndexSet, _ completed: @escaping (Error?) -> Void) {
      let savedIndexSet = indexSet.filteredIndexSet(includeInteger: { items[$0].isSaved })

      let deletedIds = Set(savedIndexSet.map {
        items[$0].id
      })
      
      
//
      guard !deletedIds.isEmpty else {
        DispatchQueue.main.async {
          completed(nil)
        }
        return
      }

      #if canImport(GroupActivities)
      self.addDelta(.remove(Array(deletedIds)))
      #endif
      let group = DispatchGroup()

      var errors = [Error?].init(repeating: nil, count: deletedIds.count)
      for (index, id) in deletedIds.enumerated() {
        group.enter()
        let request = DeleteTodoItemRequest(itemID: id)
        service.beginRequest(request) { error in
          errors[index] = error
          group.leave()
        }
      }
      group.notify(queue: .main) {
        completed(errors.compactMap { $0 }.last)
      }
    }

    public func deleteItems(atIndexSet indexSet: IndexSet) {
      beginDeleteItems(atIndexSet: indexSet) { error in
        self.items.remove(atOffsets: indexSet)
        self.latestError = error
      }
    }

    public func beginSignup(withCredentials credentials: Credentials) {
      service.beginRequest(SignUpRequest(body: .init(emailAddress: credentials.username, password: credentials.password))) { result in
        let newCredentialsResult = result.map { content in
          credentials.withToken(content.token)
        }.tryMap { creds -> Credentials in
          try self.service.save(credentials: creds)
          return creds
        }

        switch newCredentialsResult {
        case let .failure(error):
          DispatchQueue.main.async {
            self.latestError = error
          }

        case let .success(newCreds):
          self.beginSignIn(withCredentials: newCreds)
        }
      }
    }

    public func beginSignIn(withCredentials credentials: Credentials) {
      let createToken = credentials.token == nil
      if createToken {
        service.beginRequest(SignInCreateRequest(body: .init(emailAddress: credentials.username, password: credentials.password))) { _ in
        }
      } else {
        service.beginRequest(SignInRefreshRequest()) { result in
          let newCredentialsResult: Result<Credentials, Error> = result.map { response in
            credentials.withToken(response.token)
          }.flatMapError { error in
            guard !createToken else {
              return .failure(error)
            }
            return .success(credentials.withoutToken())
          }
          let newCreds: Credentials
          switch newCredentialsResult {
          case let .failure(error):
            DispatchQueue.main.async {
              self.latestError = error
            }
            return

          case let .success(credentials):
            newCreds = credentials
          }

          switch (newCreds.token, createToken) {
          case (.none, false):
            self.beginSignIn(withCredentials: newCreds)

          case (.some, _):
            try? self.service.save(credentials: newCreds)
            DispatchQueue.main.async {
              self.username = newCreds.username
              self.token = newCreds.token
            }

          case (.none, true):
            break
          }
        }
      }
    }
    
#if canImport(GroupActivities)
    @available(iOS 15, macOS 12, *)
    func startSharing() {
        Task {
            do {
              guard let username = username else {
                return
              }

              _ = try await FloxBxActivity(username: username).activate()
            } catch {
                print("Failed to activate ShoppingListActivity activity: \(error)")
            }
        }
    }
    
    @available(iOS 15, macOS 12,*)
    func reset() {
        // Clear local drawing canvas.

        listDeltas = []

        // Teardown existing groupSession.
        messenger = nil
        tasks.forEach { $0.cancel() }
        tasks = []
        subscriptions = []
        if groupSession != nil {
            groupSession?.leave()
            groupSession = nil
            startSharing()
        }
    }
    
    @available(iOS 15,macOS 12, *)
    func configureGroupSession(_ groupSession: GroupSession<FloxBxActivity>) {
        listDeltas = []

        self.groupSession = groupSession

        let messenger = GroupSessionMessenger(session: groupSession)
        self.messenger = messenger

        self.groupSession?.$state
            .sink(receiveValue: { state in
                if case .invalidated = state {
                    self.groupSession = nil
                    self.reset()
                }
            }).store(in: &subscriptions)

        self.groupSession?.$activeParticipants
            .sink(receiveValue: { activeParticipants in
                let newParticipants = activeParticipants.subtracting(groupSession.activeParticipants)

                Task {
                    // try? await messenger.send(CanvasMessage(strokes: self.strokes, pointCount: self.pointCount), to: .only(newParticipants))
                    try? await messenger.send(self.listDeltas, to: .only(newParticipants))
                }
            }).store(in: &subscriptions)
        let task = Task {
            for await(message, _) in messenger.messages(of: [TodoListDelta].self) {
                handle(message)
            }
        }
        tasks.insert(task)

        groupSession.join()
    }
    func handle(_ deltas: [TodoListDelta]) {
        for delta in deltas {
            handle(delta)
        }
//        if requireRefresh {
//            DispatchQueue.main.async {
//                self.getList()
//            }
//        }
    }

    func handle(_ delta: TodoListDelta) {
        //switch delta {
//        case .remove(let array):
//            DispatchQueue.main.async {
//                self.list.removeAll { item in
//                    array.contains { id in
//                        item.item.listItemId == id
//                    }
//                }
//            }
//        case .insert(let shoppingListItem, let atIndex):
//            DispatchQueue.main.async {
//                self.list.insert(.init(id: UUID(), item: shoppingListItem), at: atIndex)
//            }
//        case .mark(let shoppingListItemID, let completed):
//            guard let index = list.firstIndex(where: { $0.item.listItemId == shoppingListItemID }) else {
//                break
//            }
//            DispatchQueue.main.async {
//                self.list[index].item = ShoppingListItem(basedOn: self.list[index].item, isComplete: completed)
//            }
//        case .move(let ids, let beforeId):
//            let fromOffsets: IndexSet
//            let toOffset = beforeId.flatMap(index(forID:)) ?? list.endIndex
//            let fromIndicies = indicies(forIDs: ids)
//            fromOffsets = .init(fromIndicies)
//            DispatchQueue.main.async {
//                self.list.move(fromOffsets: fromOffsets, toOffset: toOffset)
//            }
//
//        case .clear:
//            DispatchQueue.main.async {
//                self.list.removeAll()
//            }
        //}
          
        DispatchQueue.main.async {
            self.listDeltas.append(delta)
        }
    }
    #endif
  }
#endif

#if canImport(SwiftUI)
  import SwiftUI

  struct TodoList: View {
    @EnvironmentObject var object: ApplicationObject

    var body: some View {
      List {
        ForEach(self.object.items ?? .init()) { item in
          TodoListItemView(item: item)
        }.onDelete(perform: object.deleteItems(atIndexSet:))
      }
      .toolbar(content: {
        ToolbarItemGroup {
          HStack {
            #if !os(watchOS)

              EditButton()

            #endif

            Button {
              self.object.items?.append(.init(title: "New Item"))
            } label: {
              Image(systemName: "plus.circle.fill")
            }
          }
        }
      })
      .navigationTitle("Todos")
    }
  }

  struct TodoList_Previews: PreviewProvider {
    static var previews: some View {
      TodoList().environmentObject(ApplicationObject(items: [
        .init(title: "Do Stuff")
      ]))
    }
  }
#endif

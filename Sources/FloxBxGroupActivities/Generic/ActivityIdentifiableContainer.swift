import Foundation

#if canImport(GroupActivities)
  import GroupActivities
#endif

/// iOS 14 friendly abstraction for GroupActivities Activity
public struct ActivityIdentifiableContainer<IDType: Hashable>: Identifiable {
  /// Activity ID
  public let id: IDType

  private let activity: Any

  @available(iOS 15, *)

  /// Gets the GroupActivity inside the container
  /// - Returns: The GroupAcitivty
  public func getGroupActivity<GroupActivityType>() -> GroupActivityType {
    guard let actvitiy = activity as? GroupActivityType else {
      preconditionFailure()
    }
    return actvitiy
  }

  #if canImport(GroupActivities)
    @available(iOS 15, *)
    init<GroupActivityType: Identifiable & GroupActivity>(activity: GroupActivityType) where GroupActivityType: GroupActivity, GroupActivityType.ID == IDType {
      self.activity = activity
      id = activity.id
    }
  #endif
}

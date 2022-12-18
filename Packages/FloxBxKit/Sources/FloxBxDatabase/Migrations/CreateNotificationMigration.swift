import Fluent

struct CreateNotificationMigration: AsyncMigration {
  func revert(on database: FluentKit.Database) async throws {
    try await database.schema(Notification.schema).delete()
  }

  func prepare(on database: Database) async throws {
    try await database.schema(Notification.schema)
      .field(.id, .uuid, .identifier(auto: false))
      .field(Notification.FieldKeys.mobileDeviceID, .uuid, .required)
      .field(Notification.FieldKeys.payload, .dictionary, .required)
      .field(Notification.FieldKeys.createdAt, .datetime, .required)
      .foreignKey(Notification.FieldKeys.mobileDeviceID, references: MobileDevice.schema, FieldKey.id)
      .create()
  }
}

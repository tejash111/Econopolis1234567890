import Foundation
import SwiftData

@Model final class SavedEconomy {
  @Attribute(.unique) var id: String
  @Attribute(.externalStorage) var archive: Data
  var selectedWorld: String
  var updatedAt: Date
  init(archive: Data, selectedWorld: String) {
    id = "primary"
    self.archive = archive
    self.selectedWorld = selectedWorld
    updatedAt = .now
  }
}

@MainActor final class SessionStore {
  let container: ModelContainer
  init(inMemory: Bool = false) throws {
    #if os(macOS)
      let configuration: ModelConfiguration
      if inMemory {
        configuration = ModelConfiguration(isStoredInMemoryOnly: true)
      } else {
        let folder = URL.applicationSupportDirectory.appending(
          path: "ECONOPOLIS-Mac", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        configuration = ModelConfiguration(url: folder.appending(path: "session.store"))
      }
      container = try ModelContainer(for: SavedEconomy.self, configurations: configuration)
    #else
      container = try ModelContainer(
        for: SavedEconomy.self, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
    #endif
  }
  func load() throws -> SavedEconomy? {
    try container.mainContext.fetch(FetchDescriptor<SavedEconomy>()).first
  }
  func save(data: Data, world: String) throws {
    if let saved = try load() {
      saved.archive = data
      saved.selectedWorld = world
      saved.updatedAt = .now
    } else {
      container.mainContext.insert(SavedEconomy(archive: data, selectedWorld: world))
    }
    try container.mainContext.save()
  }
}

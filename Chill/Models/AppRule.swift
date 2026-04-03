import Foundation

struct AppRule: Codable, Identifiable, Hashable {
    var id: UUID
    var appName: String
    var bundleID: String
    var profileID: UUID

    init(id: UUID = UUID(), appName: String, bundleID: String, profileID: UUID) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.profileID = profileID
    }
}

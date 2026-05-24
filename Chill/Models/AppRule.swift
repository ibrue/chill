import Foundation

struct AppRule: Codable, Identifiable, Hashable {
    var id: UUID
    var appName: String
    var bundleID: String
    var profileID: UUID
    var enabled: Bool

    init(id: UUID = UUID(), appName: String, bundleID: String, profileID: UUID, enabled: Bool = true) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.profileID = profileID
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, appName, bundleID, profileID, enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        appName = try container.decode(String.self, forKey: .appName)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        profileID = try container.decode(UUID.self, forKey: .profileID)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

import XCTest
@testable import KimaiClock

@MainActor
final class UpdateManagerTests: XCTestCase {
    func testGitHubReleaseDecoding() throws {
        let json = Data("""
        {
            "tag_name": "v1.6.0"
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tag_name, "v1.6.0")
        XCTAssertEqual(release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v")), "1.6.0")
    }

    func testInitialState() {
        let manager = UpdateManager()
        XCTAssertNotNil(manager)
    }
}

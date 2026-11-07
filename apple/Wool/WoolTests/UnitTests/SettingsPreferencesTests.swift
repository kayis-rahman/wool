import XCTest
@testable import Wool

final class SettingsPreferencesTests: XCTestCase {
    func testAppThemeMapsToExpectedColorScheme() {
        XCTAssertEqual(AppTheme.light.colorScheme, .light)
        XCTAssertEqual(AppTheme.dark.colorScheme, .dark)
        XCTAssertNil(AppTheme.system.colorScheme)
    }

    func testAppThemeIsStableForPersistence() {
        for theme in AppTheme.allCases {
            XCTAssertEqual(AppTheme(rawValue: theme.rawValue), theme)
        }
    }
}

import XCTest
@testable import NoteItCore

final class L10nTests: XCTestCase {
    override func tearDown() {
        L10n.language = .en
    }

    func testEveryKeyIsTranslatedWithMatchingPlaceholders() {
        let placeholder = try! NSRegularExpression(pattern: #"\{\d\}"#)
        func placeholders(_ text: String) -> Set<String> {
            let range = NSRange(location: 0, length: (text as NSString).length)
            return Set(placeholder.matches(in: text, range: range).map { (text as NSString).substring(with: $0.range) })
        }
        for key in L10nKey.allCases {
            let english = key.text(in: .en)
            for language in AppLanguage.allCases {
                let text = key.text(in: language)
                XCTAssertFalse(text.isEmpty, "\(key) is empty in \(language)")
                XCTAssertEqual(placeholders(text), placeholders(english), "\(key) placeholders differ in \(language)")
            }
        }
    }

    func testPreferredLanguage() {
        XCTAssertEqual(AppLanguage.preferred(from: ["fr-CH", "en-US"]), .fr)
        XCTAssertEqual(AppLanguage.preferred(from: ["es-419"]), .es)
        XCTAssertEqual(AppLanguage.preferred(from: ["ja-JP", "it_IT"]), .it)
        XCTAssertEqual(AppLanguage.preferred(from: ["ja-JP"]), .en)
        XCTAssertEqual(AppLanguage.preferred(from: []), .en)
    }

    func testFormatting() {
        XCTAssertEqual(L10n.tr(.filteredCountFormat, in: .de, 3, 10), "3 von 10")
        XCTAssertEqual(L10n.tr(.filteredCountFormat, in: .es, 3, 10), "3 de 10")
        L10n.language = .it
        XCTAssertEqual(L10n.tr(.noteCountOther, 5), "5 note")
        XCTAssertEqual(NoteFileStore.sanitizedTitle(" "), "Senza titolo")
    }
}

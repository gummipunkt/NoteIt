import AppKit

/// Version, copyright and contact details. `scripts/build-app.sh` reads `version`
/// from this file for the app bundle's Info.plist, so this is the single source of truth.
enum AppInfo {
    static let name = "NoteIt"
    static let version = "0.2.1"
    static let author = "Patrick Walter"
    static let copyrightYear = "2026"
    static let website = URL(string: "https://www.gummipunkt.eu")!
    static let email = "noteit@gummipunkt.eu"
    static let repository = URL(string: "https://github.com/gummipunkt/NoteIt")!
    static let license = "GNU General Public License v3.0"
    static let licenseURL = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!

    static var copyright: String { "© \(copyrightYear) \(author)" }

    /// Build number from the bundle (set by the build script), if running as an app bundle.
    static var build: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    static var versionLabel: String {
        if let build { return "Version \(version) (\(build))" }
        return "Version \(version)"
    }

    /// Shows the standard About panel with version, copyright and contact links.
    @MainActor
    static func showAboutPanel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let credits = NSMutableAttributedString(string: "Schnelle Notizen im Stil von nvALT.\n\n", attributes: base)
        var link = base
        link[.link] = website
        credits.append(NSAttributedString(string: "www.gummipunkt.eu", attributes: link))
        credits.append(NSAttributedString(string: "\n", attributes: base))
        link[.link] = URL(string: "mailto:\(email)")!
        credits.append(NSAttributedString(string: email, attributes: link))
        credits.append(NSAttributedString(string: "\n", attributes: base))
        link[.link] = repository
        credits.append(NSAttributedString(string: "github.com/gummipunkt/NoteIt", attributes: link))
        credits.append(NSAttributedString(string: "\n\nFreie Software unter der ", attributes: base))
        link[.link] = licenseURL
        credits.append(NSAttributedString(string: "GPL 3.0", attributes: link))
        credits.append(NSAttributedString(string: ".", attributes: base))

        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: name,
            .applicationVersion: version,
            .credits: credits,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): copyright,
        ]
        if let build { options[.version] = build }
        NSApp.orderFrontStandardAboutPanel(options: options)
        NSApp.activate(ignoringOtherApps: true)
    }
}

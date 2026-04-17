import Foundation

struct AppVersion: Equatable, Sendable {
    let shortVersion: String?
    let buildNumber: String?

    init(shortVersion: String?, buildNumber: String?) {
        self.shortVersion = shortVersion
        self.buildNumber = buildNumber
    }

    init(bundle: Bundle = .main) {
        self.init(bundleURL: bundle.bundleURL)

        if shortVersion != nil || buildNumber != nil {
            return
        }

        let bundleShortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let bundleBuildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if bundleShortVersion != nil || bundleBuildNumber != nil {
            self.init(shortVersion: bundleShortVersion, buildNumber: bundleBuildNumber)
            return
        }

        if let moduleBuildInfoURL = Bundle.module.url(forResource: "BuildInfo", withExtension: "plist"),
           let values = Self.readVersionValues(from: moduleBuildInfoURL) {
            self.init(shortVersion: values.shortVersion, buildNumber: values.buildNumber)
            return
        }

        self.init(executableURL: URL(fileURLWithPath: CommandLine.arguments[0]))
    }

    init(bundleURL: URL) {
        let buildInfoURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BuildInfo.plist")

        if let values = Self.readVersionValues(from: buildInfoURL) {
            self.init(shortVersion: values.shortVersion, buildNumber: values.buildNumber)
            return
        }

        let infoPlistURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")

        if let values = Self.readVersionValues(from: infoPlistURL) {
            self.init(shortVersion: values.shortVersion, buildNumber: values.buildNumber)
            return
        }

        self.init(shortVersion: nil, buildNumber: nil)
    }

    init(executableURL: URL) {
        let infoPlistURL = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Info.plist")

        guard let values = Self.readVersionValues(from: infoPlistURL) else {
            shortVersion = nil
            buildNumber = nil
            return
        }

        shortVersion = values.shortVersion
        buildNumber = values.buildNumber
    }

    var menuTitle: String {
        switch (shortVersion, buildNumber) {
        case let (shortVersion?, buildNumber?):
            "Version \(shortVersion) (\(buildNumber))"
        case let (shortVersion?, nil):
            "Version \(shortVersion)"
        case let (nil, buildNumber?):
            "Build \(buildNumber)"
        case (nil, nil):
            "Version unknown"
        }
    }

    private static func readVersionValues(
        from plistURL: URL
    ) -> (shortVersion: String?, buildNumber: String?)? {
        guard
            let data = try? Data(contentsOf: plistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = plist as? [String: Any]
        else {
            return nil
        }

        return (
            dictionary["CFBundleShortVersionString"] as? String,
            dictionary["CFBundleVersion"] as? String
        )
    }
}

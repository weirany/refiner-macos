import Testing
@testable import Refiner
import Foundation

@Test
func promptTemplateRejectsMissingPlaceholder() {
    #expect(throws: PromptTemplate.Error.self) {
        _ = try PromptTemplate(
            rawValue: "Rewrite the text below into natural English."
        )
    }
}

@Test
func promptTemplateSubstitutesOriginalText() throws {
    let template = try PromptTemplate(
        rawValue: """
        text to rewrite:
        {original_text}
        """
    )

    let rendered = template.render(with: "hello-world")

    #expect(rendered == """
    text to rewrite:
    hello-world
    """)
}

@Test
func appVersionDisplayFormatsShortVersionAndBuild() {
    let version = AppVersion(
        shortVersion: "1.2.3",
        buildNumber: "45"
    )

    #expect(version.menuTitle == "Version 1.2.3 (45)")
}

@Test
func appVersionDisplayFallsBackWhenMetadataMissing() {
    let version = AppVersion(
        shortVersion: nil,
        buildNumber: nil
    )

    #expect(version.menuTitle == "Version unknown")
}

@Test
func appVersionLoadsFromAppBundleInfoPlistFallback() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let appDirectory = tempDirectory
        .appendingPathComponent("Refiner.app", isDirectory: true)
    let contentsDirectory = appDirectory
        .appendingPathComponent("Contents", isDirectory: true)
    let macOSDirectory = contentsDirectory
        .appendingPathComponent("MacOS", isDirectory: true)
    let executableURL = macOSDirectory.appendingPathComponent("Refiner")
    let plistURL = contentsDirectory.appendingPathComponent("Info.plist")

    try FileManager.default.createDirectory(at: macOSDirectory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    let plist: [String: Any] = [
        "CFBundleShortVersionString": "2.0.0",
        "CFBundleVersion": "9",
    ]
    let data = try PropertyListSerialization.data(
        fromPropertyList: plist,
        format: .xml,
        options: 0
    )
    try data.write(to: plistURL)
    FileManager.default.createFile(atPath: executableURL.path, contents: Data())

    let version = AppVersion(executableURL: executableURL)

    #expect(version.menuTitle == "Version 2.0.0 (9)")
}

@Test
func appVersionPrefersStampedBuildInfoFile() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let appDirectory = tempDirectory
        .appendingPathComponent("Refiner.app", isDirectory: true)
    let resourcesDirectory = appDirectory
        .appendingPathComponent("Contents/Resources", isDirectory: true)
    let buildInfoURL = resourcesDirectory.appendingPathComponent("BuildInfo.plist")

    try FileManager.default.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    let plist: [String: Any] = [
        "CFBundleShortVersionString": "3.1.0",
        "CFBundleVersion": "17",
    ]
    let data = try PropertyListSerialization.data(
        fromPropertyList: plist,
        format: .xml,
        options: 0
    )
    try data.write(to: buildInfoURL)

    let version = AppVersion(bundleURL: appDirectory)

    #expect(version.menuTitle == "Version 3.1.0 (17)")
}

@Test
func appIdentityUsesBundleIdentifierWhenPresent() {
    let identity = AppIdentity(
        bundleIdentifier: "com.weiranye.refiner",
        executablePath: "/Applications/Refiner.app/Contents/MacOS/Refiner"
    )

    #expect(identity.primaryLabel == "com.weiranye.refiner")
}

@Test
func appIdentityFallsBackToExecutablePathWhenBundleIdentifierMissing() {
    let identity = AppIdentity(
        bundleIdentifier: nil,
        executablePath: "/tmp/Refiner"
    )

    #expect(identity.primaryLabel == "/tmp/Refiner")
}

@Test
func appMenuTitlesIncludeManualRefineAction() {
    let titles = AppMenu.menuTitles(versionTitle: "Version 1.1 (2)")

    #expect(titles == ["Refine Selected Text", "Settings…", "Version 1.1 (2)", "Quit"])
}

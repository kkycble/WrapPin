import Foundation

@main
struct LocalizationBundleChecks {
    static func main() throws {
        let available = ["en", "zh-Hans", "zh-Hant"]
        for (preference, expected) in [
            ("zh-Hant-HK", "zh-Hant"), ("zh-HK", "zh-Hant"),
            ("zh-TW", "zh-Hant"), ("zh-Hant", "zh-Hant"),
            ("zh-Hans-CN", "zh-Hans"), ("en-HK", "en"),
        ] {
            let actual = Bundle.preferredLocalizations(from: available, forPreferences: [preference]).first
            precondition(actual == expected, "\(preference) should choose \(expected), not \(actual ?? "nil")")
        }
        let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("WrapPin/Resources/zh-Hant.lproj")
        guard let traditional = Bundle(url: resources) else {
            preconditionFailure("Traditional Chinese localization bundle could not be opened")
        }
        precondition(traditional.localizedString(forKey: "Settings", value: nil, table: nil) == "設定")
        precondition(traditional.localizedString(forKey: "Start Cycling", value: nil, table: nil) == "開始單車模擬")
        precondition(traditional.localizedString(forKey: "Resume Cycling", value: nil, table: nil) == "繼續單車模擬")
        let permission = traditional.localizedString(forKey: "NSLocalNetworkUsageDescription", value: nil, table: "InfoPlist")
        precondition(permission.contains("本地網絡"))
        let phrase = traditional.localizedString(forKey: "Stop ${applicationName} simulation", value: nil, table: "AppShortcuts")
        precondition(phrase == "停止${applicationName}模擬")
        print("Localization bundles: Hong Kong/Taiwan script matching, Traditional Chinese UI, permissions and Siri phrases passed")
    }
}

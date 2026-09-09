import Foundation

enum NativeHostRegistration {
    private static let hostName = "com.sfdye.mutebar"
    private static let devExtensionID = "iggmpoondbifidlpilegncmifabajbep"
    private static let storeExtensionID = "jdnohcgdlpndiinaklmckmaonpjimkfg"

    // browser-name -> native messaging manifest directory (user-level; mirrors scripts/install.sh)
    private static let browserDirs = [
        "Library/Application Support/Google/Chrome/NativeMessagingHosts",
        "Library/Application Support/Arc/User Data/NativeMessagingHosts",
        "Library/Application Support/Microsoft Edge/NativeMessagingHosts",
        "Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts",
        "Library/Application Support/Chromium/NativeMessagingHosts",
    ]

    static func register() {
        let hostBin = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/mutebar-host").path
        guard FileManager.default.isExecutableFile(atPath: hostBin) else { return }

        let manifest: [String: Any] = [
            "name": hostName,
            "description": "MuteBar native host",
            "path": hostBin,
            "type": "stdio",
            "allowed_extensions": [devExtensionID, storeExtensionID],
            "allowed_origins": [
                "chrome-extension://\(devExtensionID)/*",
                "chrome-extension://\(storeExtensionID)/*",
            ],
        ]
        guard JSONSerialization.isValidJSONObject(manifest),
              let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        else { return }

        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        for relative in browserDirs {
            let dir = home + "/" + relative
            let browserDir = (dir as NSString).deletingLastPathComponent
            guard fm.fileExists(atPath: browserDir) else { continue }
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? data.write(to: URL(fileURLWithPath: dir + "/\(hostName).json"))
        }
    }
}

import Foundation

enum UpdateInstaller {
    static func installAndRelaunch(replacing appURL: URL, update: PreparedUpdate) throws {
        let scriptURL = update.staging.appendingPathComponent("install-update.sh")
        try helperScript(appURL: appURL, update: update).write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    private static func helperScript(appURL: URL, update: PreparedUpdate) -> String {
        let pid = ProcessInfo.processInfo.processIdentifier
        return """
            #!/bin/sh
            app=\(shellQuote(appURL.path))
            new=\(shellQuote(update.app.path))
            old="$app.old"
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            rm -rf "$old"
            if mv "$app" "$old" 2>/dev/null; then
                if ditto "$new" "$app"; then
                    xattr -cr "$app" 2>/dev/null
                    rm -rf "$old"
                    open "$app"
                    rm -rf \(shellQuote(update.staging.path))
                    exit 0
                fi
                rm -rf "$app"
                mv "$old" "$app"
            fi
            open "$app"
            exit 1
            """
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

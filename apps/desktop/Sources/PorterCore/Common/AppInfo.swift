/// App-wide identity shared across services, so cross-cutting constants live in
/// one place instead of being re-typed per file.
public enum AppInfo {
    /// The stable bundle-id base. Channels append a suffix to form their own id
    /// (see `Channel.bundleSuffix`), but this base is the unified logging
    /// subsystem so every category logs under one roof.
    public static let bundleIdentifier = "com.syntaxlabtechnology.porter"

    /// A logger for `category`. Tees to Apple's unified logging (Console.app) and
    /// to Porter's persistent daily file (`~/.porter*/logs/`) so problems are
    /// debuggable after the fact — see `PorterLog` / `FileLog`.
    public static func logger(_ category: String) -> PorterLog {
        PorterLog(category: category)
    }
}

import Foundation

// MARK: - External URL Scheme (#57)

/// An action requested by a `menumijia://` link from Raycast, Alfred, Stream Deck, a Shortcut, or a
/// web page.
///
/// Links are easy to trigger from a browser, so handlers must not run them silently:
/// `URLDirectControl` decides whether the user has to confirm the action first (default: confirm).
public enum AppURLCommand: Equatable, Sendable {
    case toggle(deviceId: String)
    case scene(name: String)
    case ask(text: String)
}

/// Parsed URL command together with optional companion-bridge authentication and request tracking metadata.
public struct AppURLCommandEnvelope: Equatable, Sendable {
    public let command: AppURLCommand
    public let token: String?
    public let requestId: String?

    public init(command: AppURLCommand, token: String? = nil, requestId: String? = nil) {
        self.command = command
        self.token = token
        self.requestId = requestId
    }
}

/// Built-in quick actions and undo entry points addressable via `menumijia://scene?name=<id>`.
public enum BuiltInURLScene: String, CaseIterable, Equatable, Sendable {
    case lightsOff
    case softNightLight
    case climateSleepOff
    case allOff
    case undo

    public static func resolve(_ raw: String) -> BuiltInURLScene? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized: String
        if trimmed.lowercased().hasPrefix("quick:") {
            normalized = String(trimmed.dropFirst("quick:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            normalized = trimmed
        }
        switch normalized.lowercased() {
        case "lightsoff", "lights_off", "全屋关灯":
            return .lightsOff
        case "softnightlight", "soft_night_light", "柔和夜灯":
            return .softNightLight
        case "climatesleepoff", "climate_sleep_off", "关温控风扇", "睡眠关空调":
            return .climateSleepOff
        case "alloff", "all_off", "一键全关", "全关":
            return .allOff
        case "undo", "撤销上一步", "撤销":
            return .undo
        default:
            return nil
        }
    }

    public var quickAction: QuickAction? {
        switch self {
        case .lightsOff: return .lightsOff
        case .softNightLight: return .softNightLight
        case .climateSleepOff: return .climateSleepOff
        case .allOff, .undo: return nil
        }
    }

    public var displayTitle: String {
        switch self {
        case .lightsOff: return QuickAction.lightsOff.title
        case .softNightLight: return QuickAction.softNightLight.title
        case .climateSleepOff: return QuickAction.climateSleepOff.title
        case .allOff: return L10n.tr("一键全关", "Turn All Off")
        case .undo: return L10n.tr("撤销上一步", "Undo Last Action")
        }
    }
}

/// Parses `menumijia://toggle?device=<id>`, `menumijia://scene?name=<scene>`,
/// and `menumijia://ask?text=<sentence>`.
///
/// All parameters are required and trimmed. Long values are rejected instead of being forwarded to
/// the cloud assistant, so a stray/malicious link cannot turn into an unbounded request.
public enum AppURLParser {
    public static let scheme = "menumijia"
    public static let maximumAskLength = 500
    public static let maximumNameLength = 200
    public static let maximumTokenLength = 200
    public static let maximumRequestIdLength = 120
    public static let maximumURLLength = 4096

    public static func parse(_ url: URL) -> AppURLCommand? {
        parseEnvelope(url)?.command
    }

    public static func parseEnvelope(_ url: URL) -> AppURLCommandEnvelope? {
        guard url.scheme?.lowercased() == scheme,
              url.absoluteString.count <= maximumURLLength,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        // `menumijia://toggle?...` puts the route in the host; also accept `menumijia:/toggle?...`.
        let route = (components.host ?? components.path)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            let key = item.name.lowercased()
            guard query[key] == nil, let raw = item.value else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                query[key] = trimmed
            }
        }

        let token: String?
        if let rawToken = query["token"] {
            guard rawToken.count <= maximumTokenLength else { return nil }
            token = rawToken
        } else {
            token = nil
        }

        let requestId: String?
        if let rawId = query["id"] ?? query["request_id"] ?? query["requestid"] ?? query["req"] {
            guard rawId.count <= maximumRequestIdLength else { return nil }
            requestId = rawId
        } else {
            requestId = nil
        }

        let command: AppURLCommand
        switch route {
        case "toggle":
            guard let deviceId = query["device"], deviceId.count <= maximumNameLength else { return nil }
            command = .toggle(deviceId: deviceId)
        case "scene":
            guard let name = query["name"], name.count <= maximumNameLength else { return nil }
            command = .scene(name: name)
        case "ask":
            guard let text = query["text"], text.count <= maximumAskLength else { return nil }
            command = .ask(text: text)
        default:
            return nil
        }

        return AppURLCommandEnvelope(command: command, token: token, requestId: requestId)
    }
}

/// Confirmation gate for external links (#57).
///
/// A web page can navigate to a custom URL scheme without any user gesture the app can verify, so
/// every control action asks inside the app first. Only when the user explicitly turns on
/// “允许 URL 直控” in Settings or presents the local `0600` companion `bridgeToken` does a link run
/// without the confirmation sheet.
public enum URLDirectControl {
    public static let allowDirectControlKey = "allow_url_direct_control"
    public static let minimumBridgeTokenLength = 16

    public static func allowsDirectControl(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: allowDirectControlKey)
    }

    public static func isValidBridgeToken(_ providedToken: String?, expectedToken: String?) -> Bool {
        guard let provided = providedToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              let expected = expectedToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              provided.count >= minimumBridgeTokenLength,
              provided.utf8.count == expected.utf8.count else {
            return false
        }
        var diff: UInt8 = 0
        for (lhs, rhs) in zip(provided.utf8, expected.utf8) {
            diff |= lhs ^ rhs
        }
        return diff == 0
    }

    public static func requiresConfirmation(allowDirectControl: Bool) -> Bool {
        !allowDirectControl
    }

    public static func requiresConfirmation(
        allowDirectControl: Bool,
        providedToken: String?,
        expectedToken: String?
    ) -> Bool {
        if allowDirectControl { return false }
        if isValidBridgeToken(providedToken, expectedToken: expectedToken) { return false }
        return true
    }

    public static func requiresConfirmation(
        in defaults: UserDefaults = .standard,
        providedToken: String? = nil,
        expectedToken: String? = nil
    ) -> Bool {
        requiresConfirmation(
            allowDirectControl: allowsDirectControl(in: defaults),
            providedToken: providedToken,
            expectedToken: expectedToken
        )
    }
}

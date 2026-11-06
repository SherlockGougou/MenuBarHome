import Foundation

/// A second-confirmation prompt for a manual control action on a high-risk device (#143).
public struct ManualControlConfirmation: Equatable, Sendable {
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let cancelTitle: String

    public init(title: String, message: String, confirmTitle: String, cancelTitle: String) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
    }
}

/// Safety rules for controls the user triggers directly (card tap, detail drawer, URL, App Intent,
/// assistant). The hazard table itself stays in `ModelActionPolicy`, so manual and AI actions cannot
/// drift apart (#143).
public enum ManualControlPolicy {
    /// True when a manual operation needs a second confirmation. De-escalating actions (turning a
    /// plug, heater, or water heater off, stopping a vacuum) stay direct: making a home safer must
    /// never require fighting a dialog.
    public static func requiresConfirmation(_ intent: DeviceIntent, devices: [SmartDevice]) -> Bool {
        guard let device = devices.first(where: { $0.id == intent.targetId }) else { return false }
        return requiresConfirmation(intent.operation, for: device)
    }

    public static func requiresConfirmation(_ operation: IntentOperation, for device: SmartDevice) -> Bool {
        // Closing a cover is not automatically de-escalating: a garage door closing is itself
        // hazardous, so every cover operation goes through the subtype hazard table.
        if operation.deescalatesHazard, !device.kind.isCover { return false }
        return ModelActionPolicy.needsConfirmation(
            DeviceIntent(targetId: device.id, operation: operation),
            devices: [device]
        )
    }

    /// The prompt text for a hazardous manual operation, or nil when the action is low risk.
    public static func confirmation(_ intent: DeviceIntent, devices: [SmartDevice]) -> ManualControlConfirmation? {
        guard let device = devices.first(where: { $0.id == intent.targetId }),
              requiresConfirmation(intent.operation, for: device) else { return nil }
        return ManualControlConfirmation(
            title: L10n.tr("确认操作高风险设备？", "Control a high-risk device?"),
            message: L10n.format(
                "「%@」属于高风险设备，执行「%@」需要再次确认。",
                "\"%@\" is a high-risk device. Confirm \"%@\".",
                device.name,
                actionLabel(intent.operation)
            ),
            confirmTitle: L10n.tr("确认执行", "Confirm"),
            cancelTitle: L10n.tr("取消", "Cancel")
        )
    }

    /// The whitelist controls availability; confirmation follows the operation's meaning.
    public static func confirmation(facet: FacetControl, value: JSONValue?, for device: SmartDevice) -> ManualControlConfirmation? {
        guard facetRequiresConfirmation(facet, value: value, for: device) else { return nil }
        let title = facet.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = title.flatMap { $0.isEmpty ? nil : $0 } ?? facet.name
        return ManualControlConfirmation(
            title: L10n.tr("确认修改更多设置？", "Change this additional setting?"),
            message: L10n.format(
                "执行「%@」的「%@」可能改变设备运行，请再次确认。",
                "Confirm changing an additional setting on %@: %@. It may affect device operation.",
                device.name,
                label
            ),
            confirmTitle: L10n.tr("确认执行", "Confirm"),
            cancelTitle: L10n.tr("取消", "Cancel")
        )
    }

    private static func facetRequiresConfirmation(_ facet: FacetControl, value: JSONValue?, for device: SmartDevice) -> Bool {
        if facet.kind == .button { return true }
        if facet.target?.isAction == true { return true }
        let service = facet.serviceName.lowercased()
        let name = facet.name.lowercased()
        let tokens = Set(name.split(separator: "-").map(String.init))
        let isMode = name == "mode" || name.hasSuffix("-mode")
        let isTargetTemperature = name == "target-temperature" || name.hasSuffix("-target-temperature")
        let isPower = ["on", "power", "power-switch"].contains(name) || name.hasSuffix("-power")
        let coverServices = ["curtain", "window-opener", "airer", "clothes-airer", "garage-door"]
        if isMode, device.kind.isCover || coverServices.contains(service) { return true }

        // Indicator, sound and child-lock controls never move the appliance's main function.
        let lowRiskServices = ["indicator-light", "night-light", "buzzer", "speaker", "physical-controls-locked"]
        let lowRiskTokens: Set<String> = ["led", "indicator", "buzzer", "mute", "display", "screen"]
        let lowRiskHA = !tokens.isDisjoint(with: lowRiskTokens)
            || name.contains("night-light")
            || name.contains("child-lock")
            || name.contains("physical-controls-locked")
            || name.contains("auto-off")
        if lowRiskServices.contains(service) || lowRiskHA { return false }

        // A Home Assistant auxiliary switch uses the `switch` domain with a device-specific object
        // id (`bath-heater-ptc`, `dual-plug-socket-2`), so it follows the power hazard table rather
        // than a MIoT property short name. This also keeps a heater switch's off direction direct.
        if service == "switch", let isOn = value?.miotBool {
            return requiresConfirmation(.power(isOn), for: device)
        }

        let category = IntentDeviceCategory(device)
        let selectedMode = (value?.intValue).flatMap { selected in
            facet.options.first { $0.value == selected }?.label
        } ?? value?.stringValue
        if category == .heater {
            if isPower, let isOn = value?.miotBool { return isOn }
            if isMode { return selectedMode?.caseInsensitiveCompare("off") != .orderedSame }
            return true
        }

        let heatingService = ["heater", "ptc", "floor-heat", "heating", "water-heater", "electric-water-heater", "gas-water-heater"]
            .contains(service)
        if isPower, let isOn = value?.miotBool {
            if heatingService { return isOn }
            return requiresConfirmation(.power(isOn), for: device)
        }

        let waterHeater: Bool
        switch device.kind {
        case .appliance(let spec): waterHeater = spec.heats
        case .climate: waterHeater = device.name.contains("热水器")
        default: waterHeater = false
        }
        if isTargetTemperature, let requested = value?.doubleValue,
           heatingService || waterHeater {
            if let current = facet.value?.doubleValue { return requested > current }
            if heatingService { return true }
            return requiresConfirmation(.targetTemperature(requested), for: device)
        }
        if isMode, heatingService || waterHeater {
            return selectedMode?.caseInsensitiveCompare("off") != .orderedSame
        }
        return false
    }

    /// The lock-screen preference guard: off by default would leave every external control path open
    /// after the Mac locks, so the app ships with it on and lets people opt out in Settings (#143).
    public static func isScreenLockBlocked(isLocked: Bool, blockWhileLocked: Bool) -> Bool {
        isLocked && blockWhileLocked
    }

    private static func actionLabel(_ operation: IntentOperation) -> String {
        switch operation {
        case .power(true):
            return L10n.tr("打开", "turn on")
        case .power(false):
            return L10n.tr("关闭", "turn off")
        case .hvacMode(let mode):
            return mode == "off"
                ? L10n.tr("关闭", "turn off")
                : L10n.format("切换到%@", "switch to %@", SmartDevice.localizeHVACMode(mode))
        case .targetTemperature(let celsius):
            return L10n.format("设为 %@", "set to %@", L10n.temperature(celsius))
        case .fanSpeed(let speed):
            return L10n.format("风速调为%@", "set fan speed to %@", IntentReply.fanSpeedLabel(speed))
        case .oscillation(let isOn):
            return isOn ? L10n.tr("开启摇头", "enable oscillation") : L10n.tr("关闭摇头", "disable oscillation")
        default:
            return L10n.tr("执行操作", "perform this action")
        }
    }
}

extension IntentOperation {
    /// Operations that end a hazard instead of starting or intensifying one. Turning a hazardous
    /// plug/heater off, switching a water heater to off, or stopping a vacuum is always allowed.
    var deescalatesHazard: Bool {
        switch self {
        case .power(false):
            return true
        case .hvacMode(let mode):
            return mode.caseInsensitiveCompare("off") == .orderedSame
        default:
            return false
        }
    }
}

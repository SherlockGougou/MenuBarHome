import Foundation

// MARK: - Room & Environment Summary

public struct RoomArea: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var sortOrder: Int

    public init(id: String, name: String, sortOrder: Int = 99) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}

public struct EnvironmentReading: Identifiable, Equatable, Sendable {
    public let id: String
    public var label: String
    public var roomName: String
    public var temperature: Double?
    public var humidity: Double?
    public var battery: Int?

    public init(
        id: String,
        label: String,
        roomName: String,
        temperature: Double?,
        humidity: Double?,
        battery: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.roomName = roomName
        self.temperature = temperature
        self.humidity = humidity
        self.battery = battery
    }
}

// MARK: - Device Specifications (Value Types)

public struct LightSpec: Equatable, Sendable {
    public var entityId: String
    public var isOn: Bool
    public var brightnessPercent: Int?
    public var colorTempKelvin: Int?
    public var minKelvin: Int
    public var maxKelvin: Int
    public var currentEffect: String?
    public var availableEffects: [String]
    public var powerWritable: Bool
    public var brightnessWritable: Bool
    public var colorWritable: Bool

    public init(
        entityId: String,
        isOn: Bool,
        brightnessPercent: Int? = nil,
        colorTempKelvin: Int? = nil,
        minKelvin: Int = 2700,
        maxKelvin: Int = 6500,
        currentEffect: String? = nil,
        availableEffects: [String] = [],
        powerWritable: Bool = true,
        brightnessWritable: Bool = true,
        colorWritable: Bool = true
    ) {
        self.entityId = entityId
        self.isOn = isOn
        self.brightnessPercent = brightnessPercent
        self.colorTempKelvin = colorTempKelvin
        self.minKelvin = minKelvin
        self.maxKelvin = maxKelvin
        self.currentEffect = currentEffect
        self.availableEffects = availableEffects
        self.powerWritable = powerWritable
        self.brightnessWritable = brightnessWritable
        self.colorWritable = colorWritable
    }
}

public struct ClimateSpec: Equatable, Sendable {
    public var entityId: String
    public var isOn: Bool
    public var hvacMode: String
    public var availableModes: [String]
    public var targetTemperature: Double
    public var currentTemperature: Double?
    public var minTemp: Double
    public var maxTemp: Double
    public var step: Double
    public var fanMode: String?
    public var availableFanModes: [String]
    public var swingMode: String?
    public var availableSwingModes: [String]
    public var powerWritable: Bool
    public var temperatureWritable: Bool

    public init(
        entityId: String,
        isOn: Bool,
        hvacMode: String,
        availableModes: [String],
        targetTemperature: Double,
        currentTemperature: Double? = nil,
        minTemp: Double = 16,
        maxTemp: Double = 30,
        step: Double = 1,
        fanMode: String? = nil,
        availableFanModes: [String] = [],
        swingMode: String? = nil,
        availableSwingModes: [String] = [],
        powerWritable: Bool = true,
        temperatureWritable: Bool = true
    ) {
        self.entityId = entityId
        self.isOn = isOn
        self.hvacMode = hvacMode
        self.availableModes = availableModes
        self.targetTemperature = targetTemperature
        self.currentTemperature = currentTemperature
        self.minTemp = minTemp
        self.maxTemp = maxTemp
        self.step = step
        self.fanMode = fanMode
        self.availableFanModes = availableFanModes
        self.swingMode = swingMode
        self.availableSwingModes = availableSwingModes
        self.powerWritable = powerWritable
        self.temperatureWritable = temperatureWritable
    }
}

public struct FanSpec: Equatable, Sendable {
    public var entityId: String
    public var isOn: Bool
    public var percentage: Int?
    public var presetMode: String?
    public var availablePresetModes: [String]
    public var isOscillating: Bool?
    public var pm25Density: Int?
    public var airQuality: String?
    public var temperature: Double?
    public var humidity: Double?
    public var filterLifePercent: Int?
    public var powerWritable: Bool
    public var speedWritable: Bool
    public var swingWritable: Bool

    public init(
        entityId: String,
        isOn: Bool,
        percentage: Int? = nil,
        presetMode: String? = nil,
        availablePresetModes: [String] = [],
        isOscillating: Bool? = nil,
        pm25Density: Int? = nil,
        airQuality: String? = nil,
        temperature: Double? = nil,
        humidity: Double? = nil,
        filterLifePercent: Int? = nil,
        powerWritable: Bool = true,
        speedWritable: Bool = true,
        swingWritable: Bool = true
    ) {
        self.entityId = entityId
        self.isOn = isOn
        self.percentage = percentage
        self.presetMode = presetMode
        self.availablePresetModes = availablePresetModes
        self.isOscillating = isOscillating
        self.pm25Density = pm25Density
        self.airQuality = airQuality
        self.temperature = temperature
        self.humidity = humidity
        self.filterLifePercent = filterLifePercent
        self.powerWritable = powerWritable
        self.speedWritable = speedWritable
        self.swingWritable = swingWritable
    }
}

public struct PlugSpec: Equatable, Sendable {
    public var switchEntityId: String
    public var isOn: Bool
    public var powerWatts: Double?
    public var energyKwh: Double?
    public var childLockEntityId: String?
    public var isChildLocked: Bool
    public var powerWritable: Bool
    /// False for a mains breaker (#265): it meters everything downstream, so adding it to the
    /// home total would count the other plugs twice.
    public var countsInTotalPower: Bool

    public init(
        switchEntityId: String,
        isOn: Bool,
        powerWatts: Double? = nil,
        energyKwh: Double? = nil,
        childLockEntityId: String? = nil,
        isChildLocked: Bool = false,
        powerWritable: Bool = true,
        countsInTotalPower: Bool = true
    ) {
        self.switchEntityId = switchEntityId
        self.isOn = isOn
        self.powerWatts = powerWatts
        self.energyKwh = energyKwh
        self.childLockEntityId = childLockEntityId
        self.isChildLocked = isChildLocked
        self.powerWritable = powerWritable
        self.countsInTotalPower = countsInTotalPower
    }
}

public struct FridgeSpec: Equatable, Sendable {
    public var modeEntityId: String?
    public var currentMode: String
    public var availableModes: [String]
    public var fridgeCurrentTemp: Double?
    public var fridgeTargetTemp: Double
    public var fridgeTargetEntityId: String?
    public var freezerCurrentTemp: Double?
    public var freezerTargetTemp: Double
    public var freezerTargetEntityId: String?

    public init(
        modeEntityId: String?,
        currentMode: String,
        availableModes: [String],
        fridgeCurrentTemp: Double?,
        fridgeTargetTemp: Double,
        fridgeTargetEntityId: String?,
        freezerCurrentTemp: Double?,
        freezerTargetTemp: Double,
        freezerTargetEntityId: String?
    ) {
        self.modeEntityId = modeEntityId
        self.currentMode = currentMode
        self.availableModes = availableModes
        self.fridgeCurrentTemp = fridgeCurrentTemp
        self.fridgeTargetTemp = fridgeTargetTemp
        self.fridgeTargetEntityId = fridgeTargetEntityId
        self.freezerCurrentTemp = freezerCurrentTemp
        self.freezerTargetTemp = freezerTargetTemp
        self.freezerTargetEntityId = freezerTargetEntityId
    }
}

public struct VacuumSpec: Equatable, Sendable {
    public var entityId: String
    public var status: String // "docked", "cleaning", "returning", "paused", "idle"
    public var battery: Int?
    public var modeEntityId: String?
    public var currentMode: String?
    public var availableModes: [String]
    public var actionsWritable: Bool

    public init(
        entityId: String,
        status: String,
        battery: Int? = nil,
        modeEntityId: String? = nil,
        currentMode: String? = nil,
        availableModes: [String] = [],
        actionsWritable: Bool = true
    ) {
        self.entityId = entityId
        self.status = status
        self.battery = battery
        self.modeEntityId = modeEntityId
        self.currentMode = currentMode
        self.availableModes = availableModes
        self.actionsWritable = actionsWritable
    }

    public var isCleaning: Bool {
        status == "cleaning" || status == "on"
    }
}

public struct SpeakerSpec: Equatable, Sendable {
    public var mediaEntityId: String
    public var state: String // "idle", "playing", "paused"
    public var volumePercent: Int
    public var isMuted: Bool
    public var muteSwitchEntityId: String?
    public var sleepModeEntityId: String?
    public var isSleepMode: Bool
    public var ttsNotifyEntityId: String?
    public var directiveNotifyEntityId: String?
    public var playMusicButtonId: String?
    public var stopAlarmButtonId: String?

    public init(
        mediaEntityId: String,
        state: String,
        volumePercent: Int,
        isMuted: Bool = false,
        muteSwitchEntityId: String? = nil,
        sleepModeEntityId: String? = nil,
        isSleepMode: Bool = false,
        ttsNotifyEntityId: String? = nil,
        directiveNotifyEntityId: String? = nil,
        playMusicButtonId: String? = nil,
        stopAlarmButtonId: String? = nil
    ) {
        self.mediaEntityId = mediaEntityId
        self.state = state
        self.volumePercent = volumePercent
        self.isMuted = isMuted
        self.muteSwitchEntityId = muteSwitchEntityId
        self.sleepModeEntityId = sleepModeEntityId
        self.isSleepMode = isSleepMode
        self.ttsNotifyEntityId = ttsNotifyEntityId
        self.directiveNotifyEntityId = directiveNotifyEntityId
        self.playMusicButtonId = playMusicButtonId
        self.stopAlarmButtonId = stopAlarmButtonId
    }
}

public struct TVSpec: Equatable, Sendable {
    public var mediaEntityId: String
    public var state: String
    public var volumePercent: Int
    public var isMuted: Bool
    public var isScreenOff: Bool
    public var isPairingPromptActive: Bool
    public var currentSource: String?
    public var availableSources: [String]
    public var turnOnButtonId: String?

    public init(
        mediaEntityId: String,
        state: String,
        volumePercent: Int,
        isMuted: Bool = false,
        isScreenOff: Bool = false,
        isPairingPromptActive: Bool = false,
        currentSource: String? = nil,
        availableSources: [String] = [],
        turnOnButtonId: String? = nil
    ) {
        self.mediaEntityId = mediaEntityId
        self.state = state
        self.volumePercent = volumePercent
        self.isMuted = isMuted
        self.isScreenOff = isScreenOff
        self.isPairingPromptActive = isPairingPromptActive
        self.currentSource = currentSource
        self.availableSources = availableSources
        self.turnOnButtonId = turnOnButtonId
    }
}

public struct CameraSpec: Equatable, Sendable {
    public var entityId: String
    public var isOn: Bool
    public var nightShot: String?
    public var availableNightShots: [String]
    public var motionDetectionEntityId: String?
    public var isMotionDetectionOn: Bool?
    public var streamEntityId: String?
    public var snapshotPath: String?
    public var powerWritable: Bool

    public init(
        entityId: String,
        isOn: Bool,
        nightShot: String? = nil,
        availableNightShots: [String] = [],
        motionDetectionEntityId: String? = nil,
        isMotionDetectionOn: Bool? = nil,
        streamEntityId: String? = nil,
        snapshotPath: String? = nil,
        powerWritable: Bool = true
    ) {
        self.entityId = entityId
        self.isOn = isOn
        self.nightShot = nightShot
        self.availableNightShots = availableNightShots
        self.motionDetectionEntityId = motionDetectionEntityId
        self.isMotionDetectionOn = isMotionDetectionOn
        self.streamEntityId = streamEntityId
        self.snapshotPath = snapshotPath
        self.powerWritable = powerWritable
    }
}

extension CameraSpec {
    /// True when Home Assistant has no video for this camera (no camera entity and no snapshot)
    /// and the user has no Mi account yet, so signing in to Mi Home is the way to watch it: a
    /// paired Mi copy then drives the card and plays through the local go2rtc Xiaomi bridge.
    public func offersMiSignInForVideo(backend: HomeBackend, hasMiSource: Bool) -> Bool {
        backend == .homeAssistant
            && !hasMiSource
            && (streamEntityId ?? "").isEmpty
            && (snapshotPath ?? "").isEmpty
    }
}

public enum CameraStreamSource: Equatable, Sendable {
    case hls(URL)
    /// Progressive fragmented MP4 (H.264/H.265) decoded natively; `mjpegFallback` is played
    /// if native decoding cannot start (#97).
    case liveMP4(URL, mjpegFallback: URL?)
    case mjpeg(URL)
    case snapshot(URL)
    case demo(deviceId: String)
}

public enum SensorAlertKind: String, CaseIterable, Hashable, Identifiable, Sendable {
    case leak
    case smoke
    case gas
    case contact
    case motion

    public var id: String { rawValue }

    public var enabledByDefault: Bool {
        switch self {
        case .leak, .smoke, .gas: true
        case .contact, .motion: false
        }
    }

    public var colorsMenuBar: Bool {
        switch self {
        case .leak, .smoke, .gas: true
        case .contact, .motion: false
        }
    }

    public var honorsAwayLimit: Bool {
        switch self {
        case .leak, .smoke, .gas: false
        case .contact, .motion: true
        }
    }

    public var notifiesOnFirstSample: Bool {
        switch self {
        case .leak, .smoke, .gas: true
        case .contact, .motion: false
        }
    }

    public var defaultsKey: String { "safety_alert_\(rawValue)_v1" }

    public var settingsTitle: String {
        switch self {
        case .leak: L10n.tr("漏水告警", "Water leak")
        case .smoke: L10n.tr("烟雾告警", "Smoke")
        case .gas: L10n.tr("燃气告警", "Gas")
        case .contact: L10n.tr("门窗开关", "Door and window")
        case .motion: L10n.tr("人体移动", "Motion")
        }
    }

    func notificationTitle(deviceName: String) -> String {
        switch self {
        case .leak: L10n.format("%@ 浸水告警", "%@ Leak", deviceName)
        case .smoke: L10n.format("%@ 烟雾告警", "%@ Smoke", deviceName)
        case .gas: L10n.format("%@ 燃气告警", "%@ Gas", deviceName)
        case .contact: L10n.format("%@ 门窗打开", "%@ Door Open", deviceName)
        case .motion: L10n.format("%@ 有人移动", "%@ Motion", deviceName)
        }
    }
}

public struct SensorObservation: Equatable, Sendable {
    public var sourceId: String
    public var kind: SensorAlertKind
    public var alarming: Bool
    public var reportedAt: Date?

    public init(sourceId: String, kind: SensorAlertKind, alarming: Bool, reportedAt: Date? = nil) {
        self.sourceId = sourceId
        self.kind = kind
        self.alarming = alarming
        self.reportedAt = reportedAt
    }
}

public struct SensorSpec: Equatable, Sendable {
    public var temperature: Double?
    public var humidity: Double?
    public var battery: Int?
    public var statusText: String?
    public var observations: [SensorObservation] = []

    public init(
        temperature: Double? = nil,
        humidity: Double? = nil,
        battery: Int? = nil,
        statusText: String? = nil,
        observations: [SensorObservation] = []
    ) {
        self.temperature = temperature
        self.humidity = humidity
        self.battery = battery
        self.statusText = statusText
        self.observations = observations
    }
}

/// Risk class of a cover, per GLOSSARY `CoverDevice`. An unrecognized source is a window opener,
/// the behaviour every cover had before subtypes.
public enum CoverSubtype: String, Equatable, Sendable {
    case curtain
    case windowOpener = "window-opener"
    case garageDoor = "garage-door"
    case clothesAirer = "clothes-airer"

    /// MIoT service short name → subtype. The service registry decides whether a service becomes
    /// a cover card at all; this table decides its risk class. An unlisted service keeps the
    /// fallback so a new cover never lands in a riskier class by omission.
    private static let miotServiceSubtypes: [String: CoverSubtype] = [
        "curtain": .curtain,
        "window-opener": .windowOpener,
        "airer": .clothesAirer,
    ]

    /// MIoT airers report position as distance lowered (0 at the top). The card shows height, so
    /// reads and writes flip; hass-xiaomi-miot defaults airers to the same reversal (#299).
    public var invertsMiotPosition: Bool { self == .clothesAirer }

    public init(miotServiceShortName: String?) {
        self = Self.miotServiceSubtypes[miotServiceShortName ?? ""] ?? .windowOpener
    }

    /// Maps a Home Assistant `cover.*` entity to its `CoverDevice` risk class (#280).
    /// Explicit `device_class` wins; when absent or unrecognized, falls back to name keywords and
    /// finally to `.windowOpener` (which requires confirmation before opening).
    public init(haDeviceClass: String?, name: String) {
        if let rawClass = haDeviceClass?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !rawClass.isEmpty {
            switch rawClass {
            case "curtain", "blind", "shade", "shutter", "awning", "damper":
                self = .curtain
                return
            case "window":
                self = .windowOpener
                return
            case "garage", "gate", "door":
                self = .garageDoor
                return
            default:
                break
            }
        }
        let lower = name.lowercased()
        if name.contains("帘") || lower.contains("curtain") || lower.contains("blind") {
            self = .curtain
        } else if name.contains("车库") || name.contains("大门")
                    || lower.contains("garage") || lower.contains("gate") {
            self = .garageDoor
        } else if name.contains("窗") || lower.contains("window") {
            self = .windowOpener
        } else {
            self = .windowOpener
        }
    }
}

/// What the motor reports it is doing. A tap stops a moving cover and otherwise moves it.
public enum CoverMotion: String, Equatable, Sendable {
    case stopped
    case opening
    case closing

    /// Nil at rest; the card and drawer both show this label while the motor travels.
    public var localizedLabel: String? { localizedLabel(for: .curtain) }

    /// An airer rises and lowers; it never "opens" (#299).
    public func localizedLabel(for subtype: CoverSubtype) -> String? {
        switch (self, subtype == .clothesAirer) {
        case (.opening, false): L10n.tr("正在打开", "Opening")
        case (.closing, false): L10n.tr("正在关闭", "Closing")
        case (.opening, true): L10n.tr("正在上升", "Rising")
        case (.closing, true): L10n.tr("正在下降", "Lowering")
        case (.stopped, _): nil
        }
    }
}

/// One MIoT `status` value-list word, classified by its letters only. Vendors spell the same
/// travel differently (`Opening` / `Up` / `Rising`) and the released library contains typos such
/// as `Dowm` and `Fallin`, so case, spaces, punctuation and digits are dropped before lookup.
public enum CoverStatusWord: Equatable, Sendable {
    case opening
    case closing
    /// A terminal end-of-travel word (`Open`, `Stop at highest`), not movement.
    case open
    /// A terminal end-of-travel word (`Closed`, `Stop at lowest`), not movement.
    case closed
    /// An explicit rest word (`Stop`, `Pause`, `Idle`, `Calibration`), not movement.
    case stopped

    public init?(_ description: String?) {
        let trimmed = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch trimmed {
        case "打开中", "开启中":
            self = .opening
            return
        case "关闭中":
            self = .closing
            return
        case "已开", "完全打开":
            self = .open
            return
        case "已关", "完全关闭":
            self = .closed
            return
        case "停止", "已停止", "暂停", "空闲":
            self = .stopped
            return
        default:
            break
        }
        let letters = trimmed.lowercased().filter { $0.isASCII && $0.isLetter }
        switch letters {
        case "opening", "up", "uping", "rise", "rising":
            self = .opening
        case "closing", "down", "dowm", "falling", "fallin", "dropping", "downing", "lower":
            self = .closing
        case "open", "opened", "fullyopen", "stopathighest", "stopatupperlimit", "stopupperlimit", "upperlimitstop", "ceiling":
            self = .open
        case "close", "closed", "closeover", "stopatlowest", "stoplowerlimit", "lowerlimitstop", "floor", "lowerlimit":
            self = .closed
        case "stop", "stopped", "pause", "paused", "idle", "calibration", "calibrating",
             "partialopen", "partialclosed", "manual":
            self = .stopped
        default:
            return nil
        }
    }

    public var motion: CoverMotion {
        switch self {
        case .opening: .opening
        case .closing: .closing
        case .open, .closed, .stopped: .stopped
        }
    }
}

/// A cover (GLOSSARY `CoverDevice`). Position is 0 closed … 100 open. Motor words are the spec's
/// own value-list descriptions, so a write never invents a numeric code the device did not publish.
public struct CoverSpec: Equatable, Sendable {
    public var entityId: String
    public var subtype: CoverSubtype
    public var positionPercent: Int?
    /// The current-position reading the device reports (or the target when it has none), before
    /// any travel display substitution.
    public var reportedPositionPercent: Int?
    public var positionWritable: Bool
    public var openDescription: String?
    public var closeDescription: String?
    public var pauseDescription: String?
    public var batteryPercent: Int?
    public var faultText: String?
    public var motion: CoverMotion
    /// True when `motion` came from the target/current difference rather than a `status` word.
    public var motionIsInferred: Bool

    public init(
        entityId: String,
        subtype: CoverSubtype,
        positionPercent: Int? = nil,
        reportedPositionPercent: Int? = nil,
        positionWritable: Bool = false,
        openDescription: String? = nil,
        closeDescription: String? = nil,
        pauseDescription: String? = nil,
        batteryPercent: Int? = nil,
        faultText: String? = nil,
        motion: CoverMotion = .stopped,
        motionIsInferred: Bool = false
    ) {
        self.entityId = entityId
        self.subtype = subtype
        self.positionPercent = positionPercent
        self.reportedPositionPercent = reportedPositionPercent
        self.positionWritable = positionWritable
        self.openDescription = openDescription
        self.closeDescription = closeDescription
        self.pauseDescription = pauseDescription
        self.batteryPercent = batteryPercent
        self.faultText = faultText
        self.motion = motion
        self.motionIsInferred = motionIsInferred
    }

    public var canMove: Bool { openDescription != nil && closeDescription != nil }
    public var isMoving: Bool { motion != .stopped }

    /// A position within two points of either end is parked on that limit. Without this the card
    /// shows a noisy 1% or 99% for a motor the device reports as fully closed or open (#298).
    public static func snappedPosition(_ percent: Int) -> Int {
        if percent <= 2 { return 0 }
        if percent >= 98 { return 100 }
        return percent
    }
}

/// The two no-argument actions the shared appliance card can run. The aliases are the MIoT action
/// short names each action may use across appliance families (#300).
public enum ApplianceActionKind: String, Equatable, Sendable, CaseIterable {
    case start
    case pause

    public var aliases: Set<String> {
        switch self {
        case .start:
            return ["start", "start-heating", "开始"]
        case .pause:
            return ["pause", "暂停"]
        }
    }

    public var title: String {
        switch self {
        case .start: return L10n.tr("开始", "Start")
        case .pause: return L10n.tr("暂停", "Pause")
        }
    }

    static func matching(_ shortName: String) -> ApplianceActionKind? {
        allCases.first { $0.aliases.contains(shortName.lowercased()) }
    }
}

/// One no-argument appliance action addressed on the MIoT service that declares it.
public struct ApplianceAction: Equatable, Sendable {
    public var kind: ApplianceActionKind
    public var entityId: String

    public init(kind: ApplianceActionKind, entityId: String) {
        self.kind = kind
        self.entityId = entityId
    }

    public var title: String { kind.title }
}

/// A shared appliance card (GLOSSARY `ApplianceDevice`). Every control is optional and driven by
/// what the spec publishes: power, mode, target temperature, status, fault, remaining time and
/// no-argument start/pause actions. Nothing here is hard-coded for one appliance family.
public struct ApplianceSpec: Equatable, Sendable {
    public var entityId: String
    public var isOn: Bool
    public var powerPresent: Bool
    public var powerWritable: Bool
    public var currentMode: String?
    public var availableModes: [String]
    public var modeWritable: Bool
    public var targetTemperature: Double?
    public var currentTemperature: Double?
    public var minTemp: Double
    public var maxTemp: Double
    public var step: Double
    public var temperatureWritable: Bool
    public var statusText: String?
    public var faultText: String?
    public var remainingMinutes: Int?
    public var startAction: ApplianceAction?
    public var pauseAction: ApplianceAction?

    public init(
        entityId: String,
        isOn: Bool = false,
        powerPresent: Bool = false,
        powerWritable: Bool = false,
        currentMode: String? = nil,
        availableModes: [String] = [],
        modeWritable: Bool = false,
        targetTemperature: Double? = nil,
        currentTemperature: Double? = nil,
        minTemp: Double = 0,
        maxTemp: Double = 100,
        step: Double = 1,
        temperatureWritable: Bool = false,
        statusText: String? = nil,
        faultText: String? = nil,
        remainingMinutes: Int? = nil,
        startAction: ApplianceAction? = nil,
        pauseAction: ApplianceAction? = nil
    ) {
        self.entityId = entityId
        self.isOn = isOn
        self.powerPresent = powerPresent
        self.powerWritable = powerWritable
        self.currentMode = currentMode
        self.availableModes = availableModes
        self.modeWritable = modeWritable
        self.targetTemperature = targetTemperature
        self.currentTemperature = currentTemperature
        self.minTemp = minTemp
        self.maxTemp = maxTemp
        self.step = step
        self.temperatureWritable = temperatureWritable
        self.statusText = statusText
        self.faultText = faultText
        self.remainingMinutes = remainingMinutes
        self.startAction = startAction
        self.pauseAction = pauseAction
    }
}

public enum DeviceKind: Equatable, Sendable {
    case light(LightSpec)
    case climate(ClimateSpec)
    case fan(FanSpec)
    case plug(PlugSpec)
    case fridge(FridgeSpec)
    case vacuum(VacuumSpec)
    case speaker(SpeakerSpec)
    case tv(TVSpec)
    case camera(CameraSpec)
    case sensor(SensorSpec)
    case cover(CoverSpec)
    case appliance(ApplianceSpec)

    /// Dedicated sensors sort ahead of air purifiers and AC return-air thermistors (#103).
    public var environmentReadingPriority: Int {
        switch self {
        case .sensor: return 0
        case .fan: return 1
        case .climate: return 2
        default: return 3
        }
    }

    public var isCover: Bool {
        if case .cover = self { return true }
        return false
    }

    public var canTogglePower: Bool {
        switch self {
        case .light(let spec): return spec.powerWritable
        case .climate(let spec): return spec.powerWritable
        case .fan(let spec): return spec.powerWritable
        case .plug(let spec): return spec.powerWritable
        case .camera(let spec): return spec.powerWritable
        case .vacuum(let spec): return spec.actionsWritable
        case .tv: return true
        case .speaker, .fridge, .sensor: return false
        case .cover(let spec): return spec.canMove
        case .appliance(let spec): return spec.powerPresent && spec.powerWritable
        }
    }

    public var acceptsControlWrites: Bool {
        switch self {
        case .light(let spec):
            return spec.powerWritable || spec.brightnessWritable || spec.colorWritable || !spec.availableEffects.isEmpty
        case .climate(let spec):
            return spec.powerWritable || spec.temperatureWritable || !spec.availableModes.isEmpty || !spec.availableFanModes.isEmpty
        case .fan(let spec):
            let speed = spec.speedWritable && spec.percentage != nil
            let swing = spec.swingWritable && spec.isOscillating != nil
            return spec.powerWritable || speed || swing || !spec.availablePresetModes.isEmpty
        case .plug(let spec):
            return spec.powerWritable || spec.childLockEntityId != nil
        case .camera(let spec):
            return spec.powerWritable || !spec.availableNightShots.isEmpty || spec.motionDetectionEntityId != nil
        case .vacuum(let spec):
            return spec.actionsWritable
        case .fridge(let spec):
            return spec.modeEntityId != nil || spec.fridgeTargetEntityId != nil || spec.freezerTargetEntityId != nil
        case .speaker, .tv:
            return true
        case .sensor:
            return false
        case .cover(let spec):
            return spec.canMove || spec.positionWritable
        case .appliance(let spec):
            return spec.powerWritable || spec.modeWritable || spec.temperatureWritable
                || spec.startAction != nil || spec.pauseAction != nil
        }
    }
}

// MARK: - Unified SmartDevice

public struct SmartDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var roomId: String
    public var roomName: String
    public var model: String
    public var isOnline: Bool
    public var kind: DeviceKind
    public var isSharedHome: Bool
    /// Set when the device comes from one of several signed-in Mi accounts.
    public var accountId: String?
    /// `12****89` style owner label, so the panel can tell same-named devices apart.
    public var accountLabel: String?

    public init(
        id: String,
        name: String,
        roomId: String,
        roomName: String,
        model: String,
        isOnline: Bool,
        kind: DeviceKind,
        isSharedHome: Bool = false,
        accountId: String? = nil,
        accountLabel: String? = nil
    ) {
        self.id = id
        self.name = name
        self.roomId = roomId
        self.roomName = roomName
        self.model = model
        self.isOnline = isOnline
        self.kind = kind
        self.isSharedHome = isSharedHome
        self.accountId = accountId
        self.accountLabel = accountLabel
    }

    /// Whether this device can be toggled on/off with a single primary click
    public var isPrimaryToggleable: Bool { kind.canTogglePower }

    /// Underlying MIoT `did`s addressed by this card's entity IDs (differs from `id` on split-key
    /// devices whose card `id` is `<parentDid>.s<N>` while commands target `<parentDid>`).
    var miotCommandDids: [String] {
        let entityIds: [String?] = switch kind {
        case .light(let s): [s.entityId]
        case .climate(let s): [s.entityId]
        case .fan(let s): [s.entityId]
        case .plug(let s): [s.switchEntityId, s.childLockEntityId]
        case .fridge(let s): [s.modeEntityId, s.fridgeTargetEntityId, s.freezerTargetEntityId]
        case .vacuum(let s): [s.entityId, s.modeEntityId]
        case .speaker(let s):
            [
                s.mediaEntityId, s.muteSwitchEntityId, s.sleepModeEntityId,
                s.ttsNotifyEntityId, s.directiveNotifyEntityId,
                s.playMusicButtonId, s.stopAlarmButtonId,
            ]
        case .tv(let s): [s.mediaEntityId]
        case .camera(let s): [s.entityId, s.motionDetectionEntityId, s.streamEntityId]
        case .sensor: []
        case .cover(let s): [s.entityId]
        case .appliance(let s): [s.entityId, s.startAction?.entityId, s.pauseAction?.entityId]
        }
        return entityIds.compactMap { id in
            guard let id else { return nil }
            return MiotAddress.parseAction(id)?.did ?? MiotAddress.parse(id)?.did
        }
    }

    /// Whether this device represents a stateless momentary action button (e.g. Home Assistant `button.*` / Wake on LAN, #100).
    public var isMomentaryButton: Bool {
        if case .plug(let s) = kind {
            return s.switchEntityId.hasPrefix("button.")
        }
        return false
    }

    /// Whether this device currently counts as "actively turned on" (lights, AC, heater, fan, plug, vacuum cleaning, TV on)
    public var isActiveOn: Bool {
        guard isOnline else { return false }
        switch kind {
        case .light(let s): return s.isOn
        case .climate(let s): return s.isOn && s.hvacMode != "off"
        case .fan(let s): return s.isOn
        case .plug(let s): return s.isOn
        case .vacuum(let s): return s.isCleaning
        case .speaker(let s): return s.state == "playing"
        case .tv(let s): return s.state != "off" && s.state != "standby"
        case .camera(let s): return s.isOn
        case .fridge, .sensor: return false
        case .cover(let s): return (s.positionPercent ?? 0) > 0
        case .appliance(let s): return s.isOn
        }
    }

    /// GLOSSARY `ActiveDevice`: a cover in the open position is open, not switched on, so it stays
    /// out of the panel and menu-bar counts even though `isActiveOn` reports its position.
    public var isActiveDevice: Bool {
        isActiveOn && !kind.isCover
    }

    /// Power from a confirmed command, keeping brightness and other fields already on `self`.
    func applyingConfirmedPower(from requested: SmartDevice) -> SmartDevice {
        var next = self
        switch (next.kind, requested.kind) {
        case (.light(var spec), .light(let want)):
            spec.isOn = want.isOn
            next.kind = .light(spec)
        case (.climate(var spec), .climate(let want)):
            spec.isOn = want.isOn
            spec.hvacMode = want.hvacMode
            next.kind = .climate(spec)
        case (.fan(var spec), .fan(let want)):
            spec.isOn = want.isOn
            next.kind = .fan(spec)
        case (.plug(var spec), .plug(let want)):
            spec.isOn = want.isOn
            next.kind = .plug(spec)
        case (.camera(var spec), .camera(let want)):
            spec.isOn = want.isOn
            next.kind = .camera(spec)
        case (.vacuum(var spec), .vacuum(let want)):
            spec.status = want.status
            next.kind = .vacuum(spec)
        case (.cover(var spec), .cover(let want)):
            spec.positionPercent = want.positionPercent
            spec.reportedPositionPercent = want.reportedPositionPercent
            spec.motion = want.motion
            spec.motionIsInferred = want.motionIsInferred
            next.kind = .cover(spec)
        case (.tv(var spec), .tv(let want)):
            spec.state = want.state
            spec.isScreenOff = want.isScreenOff
            next.kind = .tv(spec)
        case (.appliance(var spec), .appliance(let want)):
            spec.isOn = want.isOn
            next.kind = .appliance(spec)
        default:
            return requested
        }
        return next
    }

    /// Whether this device has an expandable secondary control drawer
    public var hasDetailDrawer: Bool {
        switch kind {
        case .light(let spec):
            return spec.brightnessWritable || spec.colorWritable || !spec.availableEffects.isEmpty
        case .climate(let spec):
            return spec.temperatureWritable || !spec.availableModes.isEmpty
                || !spec.availableFanModes.isEmpty || !spec.availableSwingModes.isEmpty
        case .fan(let spec):
            let hasReadings = spec.pm25Density != nil || spec.airQuality != nil
                || spec.temperature != nil || spec.humidity != nil || spec.filterLifePercent != nil
            let speed = spec.speedWritable && spec.percentage != nil
            let swing = spec.swingWritable && spec.isOscillating != nil
            return speed || swing || !spec.availablePresetModes.isEmpty || hasReadings
        case .camera(let spec):
            return spec.powerWritable || !spec.availableNightShots.isEmpty || spec.motionDetectionEntityId != nil
        case .vacuum(let spec):
            return spec.actionsWritable
        case .fridge, .speaker, .tv:
            return true
        case .plug(let s):
            return s.powerWatts != nil || s.energyKwh != nil || s.childLockEntityId != nil
        case .sensor:
            return false
        case .cover(let spec):
            return spec.positionWritable || spec.canMove || spec.pauseDescription != nil
                || spec.batteryPercent != nil || spec.faultText != nil
        case .appliance(let spec):
            return (spec.temperatureWritable && spec.targetTemperature != nil) || spec.modeWritable
                || spec.statusText != nil || spec.faultText != nil || spec.remainingMinutes != nil
                || spec.startAction != nil || spec.pauseAction != nil
        }
    }

    /// Ambient temperature / humidity reading exposed by this device for the menu bar and status strip (#103).
    /// Offline devices or devices without a live reading are excluded.
    public var environmentReading: EnvironmentReading? {
        guard isOnline else { return nil }
        switch kind {
        case .sensor(let s):
            guard s.temperature != nil || s.humidity != nil else { return nil }
            let stripped = name.replacingOccurrences(of: "温湿度计", with: "")
                .trimmingCharacters(in: .whitespaces)
            return EnvironmentReading(
                id: id,
                label: stripped.isEmpty ? roomName : stripped,
                roomName: roomName,
                temperature: s.temperature,
                humidity: s.humidity,
                battery: s.battery
            )
        case .fan(let f):
            guard f.temperature != nil || f.humidity != nil else { return nil }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return EnvironmentReading(
                id: id,
                label: trimmed.isEmpty ? roomName : trimmed,
                roomName: roomName,
                temperature: f.temperature,
                humidity: f.humidity
            )
        case .climate(let c):
            guard let temp = c.currentTemperature else { return nil }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return EnvironmentReading(
                id: id,
                label: trimmed.isEmpty ? roomName : trimmed,
                roomName: roomName,
                temperature: temp,
                humidity: nil
            )
        default:
            return nil
        }
    }
}

// MARK: - Scene & QuickAction Domain Types

public struct HomeScene: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var entityId: String
    public var iconName: String

    public init(id: String, name: String, entityId: String, iconName: String = "sparkles") {
        self.id = id
        self.name = name
        self.entityId = entityId
        self.iconName = iconName
    }
}

public enum QuickAction: String, CaseIterable, Identifiable, Equatable, Sendable {
    case lightsOff = "lightsOff"
    case softNightLight = "softNightLight"
    case climateSleepOff = "climateSleepOff"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .lightsOff: return L10n.tr("全屋关灯", "All Lights Off")
        case .softNightLight: return L10n.tr("柔和夜灯", "Soft Night Light")
        case .climateSleepOff: return L10n.tr("关温控风扇", "Sleep Climate Off")
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .lightsOff: return "lightbulb.slash.fill"
        case .softNightLight: return "moon.stars.fill"
        case .climateSleepOff: return "wind.snow"
        }
    }

    /// Quick actions own their visual family explicitly; no symbol parsing.
    public var visualCategory: SceneVisualCategory {
        switch self {
        case .lightsOff: return .light
        case .softNightLight: return .night
        case .climateSleepOff: return .climate
        }
    }
}

/// Scene visual family, one level above colour: models own the semantics, the UI maps it to tints.
public enum SceneVisualCategory: String, Sendable {
    case night
    case climate
    case water
    case heat
    case media
    case light

    /// Keyword map for externally supplied scene icons: Home Assistant sends arbitrary symbol
    /// names, so the family has to be inferred somewhere centralised and testable.
    public init(iconSymbol: String) {
        let symbol = iconSymbol.lowercased()
        if symbol.contains("moon") || symbol.contains("zzz") || symbol.contains("night") {
            self = .night
        } else if symbol.contains("snow") || symbol.contains("wind") || symbol.contains("therm") || symbol.contains("fan") {
            self = .climate
        } else if symbol.contains("drop") || symbol.contains("humid") || symbol.contains("water") {
            self = .water
        } else if symbol.contains("flame") || symbol.contains("heat") {
            self = .heat
        } else if symbol.contains("tv") || symbol.contains("play") || symbol.contains("film")
            || symbol.contains("music") || symbol.contains("speaker") {
            self = .media
        } else {
            self = .light
        }
    }
}

extension HomeScene {
    public var visualCategory: SceneVisualCategory {
        SceneVisualCategory(iconSymbol: iconName)
    }
}

// MARK: - Commands Dispatched Over the Seam

public enum DeviceCommand: Equatable, Sendable {
    case setLightPower(entityId: String, isOn: Bool)
    case setLightBrightness(entityId: String, percent: Int)
    case setLightColorTemp(entityId: String, kelvin: Int)
    case setLightEffect(entityId: String, effect: String)

    case setClimatePower(entityId: String, isOn: Bool, fallbackMode: String)
    case setClimateMode(entityId: String, hvacMode: String)
    case setClimateTemperature(entityId: String, temperature: Double)
    case setClimateFanMode(entityId: String, fanMode: String)
    case setClimateSwingMode(entityId: String, swingMode: String)

    case setFanPower(entityId: String, isOn: Bool)
    case setFanPercentage(entityId: String, percent: Int)
    case setFanPresetMode(entityId: String, presetMode: String)
    case setFanOscillating(entityId: String, oscillating: Bool)

    case setSwitch(entityId: String, isOn: Bool)
    case setSelectOption(entityId: String, option: String)
    case setNumberValue(entityId: String, value: Double)

    case vacuumAction(entityId: String, action: VacuumAction)
    case mediaSetVolume(entityId: String, volumeLevel: Double)
    case mediaSelectSource(entityId: String, source: String)
    case pressButton(entityId: String)
    case sendNotifyMessage(entityId: String, message: String)
    case activateScene(entityId: String)
}

public enum VacuumAction: String, Equatable, Sendable {
    case start = "start"
    case pause = "pause"
    case returnToBase = "return_to_base"
}

// MARK: - Menu Bar Metrics & Safety Alerts

public struct MenuBarMetricOption: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct SafetyAlert: Identifiable, Equatable, Sendable {
    public let id: String
    public let deviceId: String
    public var title: String
    public var body: String
    public var turnOffCommand: DeviceCommand?

    public init(
        id: String,
        deviceId: String,
        title: String,
        body: String,
        turnOffCommand: DeviceCommand? = nil
    ) {
        self.id = id
        self.deviceId = deviceId
        self.title = title
        self.body = body
        self.turnOffCommand = turnOffCommand
    }
}

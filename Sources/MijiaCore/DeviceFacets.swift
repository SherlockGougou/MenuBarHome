import Foundation

/// Where a facet write goes. Xiaomi property writes carry the new value; actions are fired as-is.
/// Home Assistant facets address one entity in its own domain and use that domain's service.
public enum FacetTarget: Equatable, Sendable {
    case property(entityId: String, piid: Int)
    case action(entityId: String)
    case haProperty(entityId: String)
    case haAction(entityId: String)

    /// True for a no-argument action (a MIoT action or a Home Assistant button).
    public var isAction: Bool {
        switch self {
        case .action, .haAction: return true
        case .property, .haProperty: return false
        }
    }
}

/// One row under 更多设置 (#5): a generic facet from `MiotFacetEngine` plus the value the last
/// snapshot carried. The drawer renders it and hands writes back to `HomeStore`.
public struct FacetControl: Identifiable, Equatable, Sendable {
    /// Stable facet id inside one device (`siid.piid` for properties, `siid.aAiid` for actions).
    public var id: String
    public var kind: MiotFacetKind
    /// MIoT short name, kept for localization and for tests.
    public var name: String
    /// Spec description. Often Chinese or English depending on the vendor; the UI may override.
    public var title: String?
    /// Service short name, used to tell same-named facets apart.
    public var serviceName: String
    public var unit: String?
    /// Display scale from a spec comment (`0.01平方米`); readings multiply the raw value by it.
    public var scale: Double?
    public var value: JSONValue?
    public var options: [MiotFacetOption]
    public var range: MiotFacetRange?
    public var isWritable: Bool
    /// False when the facet writes outside the low-risk whitelist in `deviceProfiles.json`.
    public var writesByDefault: Bool
    public var isHighValue: Bool
    public var target: FacetTarget?

    public init(
        id: String,
        kind: MiotFacetKind,
        name: String,
        title: String?,
        serviceName: String,
        unit: String? = nil,
        scale: Double? = nil,
        value: JSONValue? = nil,
        options: [MiotFacetOption] = [],
        range: MiotFacetRange? = nil,
        isWritable: Bool,
        writesByDefault: Bool,
        isHighValue: Bool,
        target: FacetTarget? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.title = title
        self.serviceName = serviceName
        self.unit = unit
        self.scale = scale
        self.value = value
        self.options = options
        self.range = range
        self.isWritable = isWritable
        self.writesByDefault = writesByDefault
        self.isHighValue = isHighValue
        self.target = target
    }

    /// MIoT booleans occasionally arrive as 0/1.
    public var isOn: Bool? { value?.miotBool }

    public var numberValue: Double? { value?.doubleValue }

    public var selectedOption: MiotFacetOption? {
        guard let raw = value?.intValue else { return nil }
        return options.first { $0.value == raw }
    }
}

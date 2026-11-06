import Foundation

/// Data-driven rules for generic MIoT facets (#303).
/// The document is `Resources/deviceProfiles.json`, byte-identical to
/// `windows/src/core/miCloud/deviceProfiles.json`.
public struct DeviceProfiles: Codable, Equatable, Sendable {
    public struct Noise: Codable, Equatable, Sendable {
        public var services: [String]
        public var properties: [String]
    }

    public struct Facets: Codable, Equatable, Sendable {
        /// Upper bound of facets a device marks high value; the rest are secondary.
        public var maxVisible: Int
        /// Device types whose writes stay high risk, mirroring `ModelActionPolicy`'s hazard table.
        public var highRiskTypes: [String]
        public var highValue: [String]
        public var lowRiskWrites: [String]
    }

    public var version: Int
    public var noise: Noise
    public var facets: Facets
    /// Device type → services that may claim it when the type names none of its own services
    /// (#296). Anything not listed stays unsupported instead of being drawn as another device.
    public var fallbackClaims: [String: [String]]

    public static func decode(_ data: Data) throws -> DeviceProfiles {
        try JSONDecoder().decode(DeviceProfiles.self, from: data)
    }

    public static let current: DeviceProfiles = {
        guard let data = bundledData(), let profiles = try? decode(data) else {
            preconditionFailure("deviceProfiles.json is missing from the MijiaCore bundle")
        }
        return profiles
    }()

    /// Bytes of the bundled document, so a test can prove it matches the Windows file.
    static func bundledData() -> Data? {
        var urls: [URL] = []
        if let url = Bundle.module.url(forResource: "deviceProfiles", withExtension: "json", subdirectory: "Resources") {
            urls.append(url)
        }
        if let url = Bundle.module.url(forResource: "deviceProfiles", withExtension: "json") {
            urls.append(url)
        }
        if let root = Bundle.module.resourceURL {
            urls.append(root.appendingPathComponent("Resources/deviceProfiles.json"))
            urls.append(root.appendingPathComponent("deviceProfiles.json"))
        }
        for base in L10n.translationSearchBases {
            urls.append(base.appendingPathComponent("Resources/deviceProfiles.json"))
            urls.append(base.appendingPathComponent("deviceProfiles.json"))
            for name in L10n.resourceDirectoryNames(in: base) {
                let bundle = base.appendingPathComponent(name)
                urls.append(bundle.appendingPathComponent("Resources/deviceProfiles.json"))
                urls.append(bundle.appendingPathComponent("Contents/Resources/Resources/deviceProfiles.json"))
                urls.append(bundle.appendingPathComponent("Contents/Resources/deviceProfiles.json"))
            }
        }
        for url in urls {
            if let data = try? Data(contentsOf: url), !data.isEmpty { return data }
        }
        return nil
    }
}

public enum MiotFacetKind: String, Codable, Equatable, Sendable {
    case toggle
    case select
    case slider
    case reading
    case button
}

/// Hazard of changing the facet. Raw values are shared with the Windows interpreter.
public enum MiotFacetRisk: String, Codable, Equatable, Sendable {
    case low
    case high
}

public struct MiotFacetOption: Codable, Equatable, Sendable {
    public var value: Int
    public var label: String
}

public struct MiotFacetRange: Codable, Equatable, Sendable {
    public var min: Double
    public var max: Double
    public var step: Double
}

public struct MiotFacetArgument: Codable, Equatable, Sendable {
    public var propertyId: Int
    public var name: String
    public var format: String
    public var range: MiotFacetRange?
    public var options: [MiotFacetOption]?
}

/// One generic control synthesized from a writable property, a readable property, or an action.
/// `id` is the stable `siid.piid` key for properties and `siid.aAiid` for actions.
public struct MiotFacet: Codable, Equatable, Sendable {
    public var id: String
    public var kind: MiotFacetKind
    public var serviceId: Int
    public var serviceName: String
    public var propertyId: Int?
    public var actionId: Int?
    public var name: String
    public var title: String?
    public var unit: String?
    public var scale: Double?
    public var range: MiotFacetRange?
    public var options: [MiotFacetOption]?
    public var arguments: [MiotFacetArgument]?
    /// True when the facet can change the device: a writable property or an action.
    public var isWritable: Bool
    public var risk: MiotFacetRisk
    /// Writes stay closed unless the data whitelist marks the facet low risk.
    public var writesByDefault: Bool
    /// High-value facets are the few shown first; the rest are secondary.
    public var highValue: Bool
}

public enum MiotFacetEngine {
    /// Generic facets for one MIoT spec, in spec service/property/action order.
    public static func facets(for spec: MiotDeviceSpec, profiles: DeviceProfiles = .current) -> [MiotFacet] {
        var facets: [MiotFacet] = []
        let deviceType = spec.shortName
        for service in spec.services {
            let serviceName = service.shortName
            guard !matches(serviceName, anyOf: profiles.noise.services) else { continue }
            for property in service.properties
            where !matches(property.shortName, anyOf: profiles.noise.properties) {
                if let facet = propertyFacet(
                    property,
                    service: service,
                    serviceName: serviceName,
                    deviceType: deviceType,
                    profiles: profiles
                ) {
                    facets.append(facet)
                }
            }
            for action in service.actions {
                if let facet = actionFacet(
                    action,
                    service: service,
                    serviceName: serviceName,
                    deviceType: deviceType,
                    profiles: profiles
                ) {
                    facets.append(facet)
                }
            }
        }
        markHighValue(&facets, profiles: profiles)
        return facets
    }

    private static func propertyFacet(
        _ property: MiotProperty,
        service: MiotService,
        serviceName: String,
        deviceType: String,
        profiles: DeviceProfiles
    ) -> MiotFacet? {
        let name = property.shortName
        guard property.format != "string" else { return nil }
        let id = "\(service.iid).\(property.iid)"
        if property.isWritable {
            let kind: MiotFacetKind
            var range: MiotFacetRange?
            var options: [MiotFacetOption]?
            if property.format == "bool" {
                kind = .toggle
            } else if let list = property.valueList, !list.isEmpty {
                kind = .select
                options = facetOptions(list)
            } else if let parsed = facetRange(property.valueRange) {
                kind = .slider
                range = parsed
            } else {
                return nil
            }
            let risk = risk(for: name, deviceType: deviceType, profiles: profiles)
            return MiotFacet(
                id: id,
                kind: kind,
                serviceId: service.iid,
                serviceName: serviceName,
                propertyId: property.iid,
                actionId: nil,
                name: name,
                title: nonEmpty(property.description),
                unit: normalizedUnit(property.unit),
                scale: nil,
                range: range,
                options: options,
                arguments: nil,
                isWritable: true,
                risk: risk,
                writesByDefault: risk == .low,
                highValue: false
            )
        }
        guard property.isReadable else { return nil }
        return MiotFacet(
            id: id,
            kind: .reading,
            serviceId: service.iid,
            serviceName: serviceName,
            propertyId: property.iid,
            actionId: nil,
            name: name,
            title: nonEmpty(property.description),
            unit: normalizedUnit(property.unit),
            scale: explicitScale(property),
            range: nil,
            options: facetOptions(property.valueList ?? []),
            arguments: nil,
            isWritable: false,
            risk: .low,
            writesByDefault: false,
            highValue: false
        )
    }

    private static func actionFacet(
        _ action: MiotAction,
        service: MiotService,
        serviceName: String,
        deviceType: String,
        profiles: DeviceProfiles
    ) -> MiotFacet? {
        var arguments: [MiotFacetArgument] = []
        for inputId in action.inputProperties {
            guard let input = service.properties.first(where: { $0.iid == inputId }),
                  !matches(input.shortName, anyOf: profiles.noise.properties) else { return nil }
            let options = facetOptions(input.valueList ?? [])
            let range = facetRange(input.valueRange)
            guard options != nil || range != nil else { return nil }
            arguments.append(MiotFacetArgument(
                propertyId: input.iid,
                name: input.shortName,
                format: input.format,
                range: range,
                options: options
            ))
        }
        let name = action.shortName
        let risk = risk(for: name, deviceType: deviceType, profiles: profiles)
        return MiotFacet(
            id: "\(service.iid).a\(action.iid)",
            kind: .button,
            serviceId: service.iid,
            serviceName: serviceName,
            propertyId: nil,
            actionId: action.iid,
            name: name,
            title: nonEmpty(action.description),
            unit: nil,
            scale: nil,
            range: nil,
            options: nil,
            arguments: arguments.isEmpty ? nil : arguments,
            isWritable: true,
            risk: risk,
            writesByDefault: risk == .low,
            highValue: false
        )
    }

    private static func markHighValue(_ facets: inout [MiotFacet], profiles: DeviceProfiles) {
        var remaining = max(0, profiles.facets.maxVisible)
        for index in facets.indices where matches(facets[index].name, anyOf: profiles.facets.highValue) {
            guard remaining > 0 else { break }
            facets[index].highValue = true
            remaining -= 1
        }
    }

    private static func risk(for name: String, deviceType: String, profiles: DeviceProfiles) -> MiotFacetRisk {
        if matches(deviceType, anyOf: profiles.facets.highRiskTypes) { return .high }
        return matches(name, anyOf: profiles.facets.lowRiskWrites) ? .low : .high
    }

    private static func facetOptions(_ list: [MiotValueListItem]) -> [MiotFacetOption]? {
        guard !list.isEmpty else { return nil }
        return list.map { MiotFacetOption(value: $0.value, label: $0.description) }
    }

    private static func facetRange(_ raw: [Double]?) -> MiotFacetRange? {
        guard let raw, raw.count >= 2 else { return nil }
        let step = raw.count >= 3 && raw[2] > 0 ? raw[2] : 1
        return MiotFacetRange(min: raw[0], max: raw[1], step: step)
    }

    private static func normalizedUnit(_ raw: String?) -> String? {
        guard let unit = nonEmpty(raw), unit.lowercased() != "none" else { return nil }
        return unit
    }

    private static func nonEmpty(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// `0.01平方米` or `单位0.1升` in a spec comment is an explicit display scale, so the
    /// reading is converted before it is shown. Ambiguous magnitudes never guess a factor.
    private static func explicitScale(_ property: MiotProperty) -> Double? {
        for raw in [property.unit, property.comment] {
            guard let raw else { continue }
            let text = raw
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "：", with: ":")
            if let value = scaleNumber(atStartOf: text) { return value }
            if let marker = text.range(of: "单位") {
                let rest = text[marker.upperBound...]
                let afterColon = rest.hasPrefix(":") ? rest.dropFirst() : rest
                if let value = scaleNumber(atStartOf: String(afterColon)) { return value }
            }
        }
        return nil
    }

    private static func scaleNumber(atStartOf text: String) -> Double? {
        guard text.hasPrefix("0.") else { return nil }
        let digits = text.dropFirst(2).prefix { $0.isNumber }
        guard !digits.isEmpty, let value = Double("0." + String(digits)), value > 0 else { return nil }
        return value
    }

    /// Matches one short name against a noise or display pattern. Only `*` is special.
    static func matches(_ value: String, anyOf patterns: [String]) -> Bool {
        patterns.contains { matches(value, pattern: $0) }
    }

    static func matches(_ value: String, pattern: String) -> Bool {
        let pattern = Array(pattern)
        let value = Array(value)
        var patternIndex = 0
        var valueIndex = 0
        var starIndex = -1
        var starValueIndex = 0
        while valueIndex < value.count {
            if patternIndex < pattern.count, pattern[patternIndex] == value[valueIndex] {
                patternIndex += 1
                valueIndex += 1
            } else if patternIndex < pattern.count, pattern[patternIndex] == "*" {
                starIndex = patternIndex
                starValueIndex = valueIndex
                patternIndex += 1
            } else if starIndex >= 0 {
                patternIndex = starIndex + 1
                starValueIndex += 1
                valueIndex = starValueIndex
            } else {
                return false
            }
        }
        while patternIndex < pattern.count, pattern[patternIndex] == "*" {
            patternIndex += 1
        }
        return patternIndex == pattern.count
    }
}

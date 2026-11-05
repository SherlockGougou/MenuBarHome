import Foundation
import Testing
@testable import MijiaCore

/// Generic facet synthesis (#303): rule cases and the fish tank live in the shared
/// `Tests/Fixtures/miot_facets.json`, which the Windows suite asserts too.
struct MiotFacetsTests {
    private struct RuleCase: Decodable {
        var id: String
        var spec: MiotDeviceSpec
        var expected: [MiotFacet]
    }

    private struct ModelCase: Decodable {
        var model: String
        var expected: [MiotFacet]
    }

    private struct Fixture: Decodable {
        var version: Int
        var cases: [RuleCase]
        var models: [ModelCase]
    }

    private struct CoverageEntry: Codable, Equatable {
        var ids: [String]
        var highValue: [String]
    }

    private struct CoverageGolden: Codable, Equatable {
        var models: [String: CoverageEntry]
    }

    @Test("Every shared rule case matches the hand-written facets")
    func sharedRuleCases() throws {
        let fixture = try loadFixture()
        for ruleCase in fixture.cases {
            let facets = MiotFacetEngine.facets(for: ruleCase.spec)
            #expect(facets == ruleCase.expected, "\(ruleCase.id)")
        }
    }

    @Test("The fish tank produces the shared facets and its high-value set is small")
    func fishbowlFacets() throws {
        let fixture = try loadFixture()
        let specs = try coverageSpecs()
        for modelCase in fixture.models {
            let spec = try #require(specs[modelCase.model], "\(modelCase.model)")
            let facets = MiotFacetEngine.facets(for: spec)
            #expect(facets == modelCase.expected, "\(modelCase.model)")
            let highValue = facets.filter(\.highValue)
            #expect(highValue.count <= 8, "\(modelCase.model)")
            #expect(highValue.count < facets.count, "\(modelCase.model)")
        }
    }

    @Test("High-risk writes stay closed until the data whitelist opens them")
    func highRiskWritesStayClosed() throws {
        let fixture = try loadFixture()
        let ruleCase = try #require(fixture.cases.first { $0.id == "low-risk-writes-are-open-by-default" })
        let facets = MiotFacetEngine.facets(for: ruleCase.spec)
        let on = try #require(facets.first { $0.name == "on" })
        #expect(on.risk == .high)
        #expect(on.writesByDefault == false)
        for name in ["mode", "brightness", "fan-level"] {
            let facet = try #require(facets.first { $0.name == name })
            #expect(facet.risk == .low, "\(name)")
            #expect(facet.writesByDefault, "\(name)")
        }
        let hazardous = try #require(fixture.cases.first {
            $0.id == "hazardous-device-type-keeps-whitelisted-writes-closed"
        })
        let heaterMode = try #require(MiotFacetEngine.facets(for: hazardous.spec).first { $0.name == "mode" })
        #expect(heaterMode.risk == .high)
        #expect(heaterMode.writesByDefault == false)
    }

    @Test("No noise service or property reaches a facet across the coverage fixture")
    func coverageHasNoNoiseFacets() throws {
        let profiles = DeviceProfiles.current
        for (model, spec) in try coverageSpecs() {
            for facet in MiotFacetEngine.facets(for: spec, profiles: profiles) {
                #expect(
                    !MiotFacetEngine.matches(facet.serviceName, anyOf: profiles.noise.services),
                    "\(model) service \(facet.serviceName)"
                )
                #expect(
                    !MiotFacetEngine.matches(facet.name, anyOf: profiles.noise.properties),
                    "\(model) property \(facet.name)"
                )
            }
        }
    }

    @Test("Every facet carries a stable id and constraints that match its kind")
    func coverageFacetsAreWellFormed() throws {
        for (model, spec) in try coverageSpecs() {
            var ids: Set<String> = []
            for facet in MiotFacetEngine.facets(for: spec) {
                #expect(ids.insert(facet.id).inserted, "\(model) duplicate \(facet.id)")
                switch facet.kind {
                case .toggle:
                    #expect(facet.isWritable, "\(model) \(facet.id)")
                    #expect(facet.range == nil && facet.options == nil, "\(model) \(facet.id)")
                case .select:
                    #expect(facet.isWritable, "\(model) \(facet.id)")
                    #expect(facet.options?.isEmpty == false, "\(model) \(facet.id)")
                case .slider:
                    #expect(facet.isWritable, "\(model) \(facet.id)")
                    #expect(facet.range != nil, "\(model) \(facet.id)")
                case .reading:
                    #expect(!facet.isWritable, "\(model) \(facet.id)")
                case .button:
                    #expect(facet.isWritable, "\(model) \(facet.id)")
                    #expect(facet.actionId != nil && facet.propertyId == nil, "\(model) \(facet.id)")
                }
                if let propertyId = facet.propertyId {
                    #expect(facet.id == "\(facet.serviceId).\(propertyId)", "\(model) \(facet.id)")
                    #expect(facet.actionId == nil, "\(model) \(facet.id)")
                }
                if let actionId = facet.actionId {
                    #expect(facet.id == "\(facet.serviceId).a\(actionId)", "\(model) \(facet.id)")
                    #expect(facet.propertyId == nil, "\(model) \(facet.id)")
                }
                #expect(facet.propertyId != nil || facet.actionId != nil, "\(model) \(facet.id)")
            }
        }
    }

    @Test("Facet membership matches the shared coverage golden")
    func coverageGolden() throws {
        var measured = try measureCoverage()
        let goldenURL = try repoFile("Tests/Fixtures/miot_facets_coverage_golden.json")
        if ProcessInfo.processInfo.environment["RECORD_MIOT_FACETS"] == "1" {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try (encoder.encode(measured) + Data("\n".utf8)).write(to: goldenURL)
        }
        let golden = try JSONDecoder().decode(CoverageGolden.self, from: Data(contentsOf: goldenURL))
        for model in Set(golden.models.keys).union(measured.models.keys).sorted()
        where golden.models[model] != measured.models[model] {
            Issue.record("\(model): golden \(String(describing: golden.models[model])), now \(String(describing: measured.models[model]))")
        }
    }

    @Test("The bundled rules are the Windows rules")
    func bundledProfilesMatchWindows() throws {
        let bundled = try #require(DeviceProfiles.bundledData())
        let windows = try Data(contentsOf: repoFile("windows/src/core/miCloud/deviceProfiles.json"))
        #expect(bundled == windows)
    }

    private func loadFixture() throws -> Fixture {
        try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: repoFile("Tests/Fixtures/miot_facets.json")))
    }

    private func coverageSpecs() throws -> [String: MiotDeviceSpec] {
        try JSONDecoder().decode(
            [String: MiotDeviceSpec].self,
            from: Data(contentsOf: repoFile("Tests/Fixtures/miot_coverage_specs.json"))
        )
    }

    private func measureCoverage() throws -> CoverageGolden {
        var models: [String: CoverageEntry] = [:]
        for (model, spec) in try coverageSpecs() {
            let facets = MiotFacetEngine.facets(for: spec)
            models[model] = CoverageEntry(
                ids: facets.map(\.id),
                highValue: facets.filter(\.highValue).map(\.id)
            )
        }
        return CoverageGolden(models: models)
    }
}

private func repoFile(_ relative: String) throws -> URL {
    var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    for _ in 0..<8 {
        let candidate = directory.appendingPathComponent(relative)
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Tests/Fixtures").path) {
            return candidate
        }
        directory.deleteLastPathComponent()
    }
    throw CocoaError(.fileNoSuchFile)
}

import Foundation
import Testing
@testable import MijiaCore

/// #57: URL Scheme parsing and the confirmation gate are pure logic, so a web page cannot smuggle
/// an unparsed parameter or skip the sheet by default.
struct AppURLCommandTests {
    @Test("Toggle link parses the device id")
    func parsesToggle() throws {
        let url = try #require(URL(string: "menumijia://toggle?device=dev_study_ceiling"))
        #expect(AppURLParser.parse(url) == .toggle(deviceId: "dev_study_ceiling"))
    }

    @Test("Scene link percent-decodes the scene name")
    func parsesScene() throws {
        let url = try #require(URL(string: "menumijia://scene?name=%E5%9B%9E%E5%AE%B6%E6%A8%A1%E5%BC%8F"))
        #expect(AppURLParser.parse(url) == .scene(name: "回家模式"))
    }

    @Test("Ask link keeps the sentence and trims surrounding whitespace")
    func parsesAsk() throws {
        let url = try #require(URL(string: "menumijia://ask?text=%20%E6%89%93%E5%BC%80%E4%B9%A6%E6%88%BF%E7%81%AF%20"))
        #expect(AppURLParser.parse(url) == .ask(text: "打开书房灯"))
    }

    @Test("Path-style links are accepted too")
    func parsesPathStyle() throws {
        let url = try #require(URL(string: "menumijia:/toggle?device=light_bed"))
        #expect(AppURLParser.parse(url) == .toggle(deviceId: "light_bed"))
    }

    @Test("Unknown, incomplete, empty, and oversized links are rejected")
    func rejectsMalformedLinks() throws {
        let bad = [
            "https://toggle?device=light_bed",
            "menumijia://toggle",
            "menumijia://toggle?device=",
            "menumijia://toggle?device=%20",
            "menumijia://scene?name=",
            "menumijia://ask?text=",
            "menumijia://unknown?device=light_bed",
            "menumijia://ask?text=" + String(repeating: "a", count: AppURLParser.maximumAskLength + 1)
        ]
        for raw in bad {
            let url = try #require(URL(string: raw), "invalid test URL \(raw)")
            #expect(AppURLParser.parse(url) == nil, "\(raw) should not parse")
        }
    }

    @Test("URL control asks for confirmation by default and only skips it after opt-in")
    func confirmationGate() throws {
        let suite = "test.url.gate.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(URLDirectControl.requiresConfirmation(in: defaults))
        defaults.set(true, forKey: URLDirectControl.allowDirectControlKey)
        #expect(!URLDirectControl.requiresConfirmation(in: defaults))
        #expect(URLDirectControl.requiresConfirmation(allowDirectControl: false))
        #expect(!URLDirectControl.requiresConfirmation(allowDirectControl: true))
    }

    @Test("Envelope parser extracts bridge token and requestId while rejecting oversized metadata")
    func parsesEnvelopeAndBridgeToken() throws {
        let validURL = try #require(
            URL(string: "menumijia://toggle?device=dev_study_ceiling&token=0123456789abcdef0123456789abcdef&id=req-42")
        )
        let envelope = try #require(AppURLParser.parseEnvelope(validURL))
        #expect(envelope.command == .toggle(deviceId: "dev_study_ceiling"))
        #expect(envelope.token == "0123456789abcdef0123456789abcdef")
        #expect(envelope.requestId == "req-42")

        let expectedToken = "0123456789abcdef0123456789abcdef"
        #expect(URLDirectControl.isValidBridgeToken(envelope.token, expectedToken: expectedToken))
        #expect(!URLDirectControl.isValidBridgeToken("wrong-token-12345678", expectedToken: expectedToken))
        #expect(!URLDirectControl.isValidBridgeToken("short", expectedToken: "short"))
        #expect(
            !URLDirectControl.requiresConfirmation(
                allowDirectControl: false,
                providedToken: envelope.token,
                expectedToken: expectedToken
            )
        )
        #expect(
            URLDirectControl.requiresConfirmation(
                allowDirectControl: false,
                providedToken: "invalid-token-0000000000000000",
                expectedToken: expectedToken
            )
        )

        let oversizedToken = String(repeating: "x", count: AppURLParser.maximumTokenLength + 1)
        let badTokenURL = try #require(URL(string: "menumijia://toggle?device=dev_1&token=\(oversizedToken)"))
        #expect(AppURLParser.parseEnvelope(badTokenURL) == nil)
    }

    @Test("BuiltInURLScene resolves quick actions, allOff, and undo identifiers")
    func resolvesBuiltInScenes() {
        #expect(BuiltInURLScene.resolve("lightsOff") == .lightsOff)
        #expect(BuiltInURLScene.resolve("quick:lightsOff") == .lightsOff)
        #expect(BuiltInURLScene.resolve("全屋关灯") == .lightsOff)
        #expect(BuiltInURLScene.resolve("softNightLight") == .softNightLight)
        #expect(BuiltInURLScene.resolve("柔和夜灯") == .softNightLight)
        #expect(BuiltInURLScene.resolve("climateSleepOff") == .climateSleepOff)
        #expect(BuiltInURLScene.resolve("关温控风扇") == .climateSleepOff)
        #expect(BuiltInURLScene.resolve("allOff") == .allOff)
        #expect(BuiltInURLScene.resolve("一键全关") == .allOff)
        #expect(BuiltInURLScene.resolve("undo") == .undo)
        #expect(BuiltInURLScene.resolve("撤销上一步") == .undo)
        #expect(BuiltInURLScene.resolve("unknown_custom_scene") == nil)
    }

    @Test("Raycast integration is off by default; on, exports coalesce, skip unchanged snapshots and write feedback at once; off revokes the token")
    @MainActor
    func raycastSnapshotExportIsCoalescedAndSkipsUnchangedWrites() async throws {
        let suite = "test.raycast.coalesce.\(UUID().uuidString)"
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("raycast-coalesce-\(UUID().uuidString)", isDirectory: true)
        let snapshotFile = tempDir.appendingPathComponent("raycast-snapshot.json", isDirectory: false)
        defer {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: tempDir)
        }
        let lamp = SmartDevice(
            id: "dev_lamp", name: "台灯", roomId: "study", roomName: "书房",
            model: "yeelink.light.lamp4", isOnline: true,
            kind: .light(LightSpec(entityId: "light.lamp", isOn: false))
        )
        let store = HomeStore(
            provider: MockHomeProvider(snapshot: SynthesizedHome(devices: [lamp])),
            defaultsSuiteName: suite
        )
        try await store.waitForInitialSnapshot(timeout: .seconds(5))
        store.raycastSnapshotTestURL = snapshotFile

        // Off by default: nothing is written and there is no token.
        #expect(!store.raycastIntegrationEnabled)
        #expect(store.raycastBridgeToken == nil)
        store.scheduleRaycastSnapshotExport()
        store.exportRaycastSnapshotIfNeeded()
        store.recordRaycastCommandFeedback(requestId: "ignored", command: "toggle", message: "x")
        try await Task.sleep(for: .milliseconds(500))
        #expect(!FileManager.default.fileExists(atPath: snapshotFile.path))

        store.setRaycastIntegration(enabled: true)
        let firstToken = try #require(store.raycastBridgeToken)
        try FileManager.default.removeItem(at: snapshotFile)
        store.lastExportedRaycastSnapshot = nil

        // A burst of changes schedules one export that lands after the quiet period.
        for _ in 0..<5 { store.scheduleRaycastSnapshotExport() }
        #expect(!FileManager.default.fileExists(atPath: snapshotFile.path))
        try await Task.sleep(for: .milliseconds(800))
        let first = try Data(contentsOf: snapshotFile)

        // Nothing changed except the clock: the file is left alone.
        store.exportRaycastSnapshotIfNeeded(now: Date().addingTimeInterval(60))
        #expect(try Data(contentsOf: snapshotFile) == first)

        // Command feedback is written immediately because Raycast is waiting for it.
        store.recordRaycastCommandFeedback(requestId: "req-1", command: "toggle", message: "已打开 台灯")
        let decoded = try JSONDecoder().decode(RaycastSnapshot.self, from: Data(contentsOf: snapshotFile))
        #expect(decoded.lastCommandFeedback?.requestId == "req-1")
        #expect(decoded.bridgeToken == firstToken)

        // Turning it off deletes the file and revokes the token; turning it back on issues a new one.
        store.setRaycastIntegration(enabled: false)
        #expect(!FileManager.default.fileExists(atPath: snapshotFile.path))
        #expect(store.raycastBridgeToken == nil)
        #expect(!URLDirectControl.isValidBridgeToken(firstToken, expectedToken: store.raycastBridgeToken))
        store.setRaycastIntegration(enabled: true)
        #expect(try #require(store.raycastBridgeToken) != firstToken)
    }

    @Test("RaycastSnapshot exports 0600 JSON with capabilities, pinyin, multi-sensor readings, and command feedback")
    @MainActor
    func exportsRaycastSnapshotAndExecutesBuiltInScenes() async throws {
        let suite = "test.raycast.snapshot.\(UUID().uuidString)"
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("raycast-snapshot-test-\(UUID().uuidString)", isDirectory: true)
        let snapshotFile = tempDir.appendingPathComponent("raycast-snapshot.json", isDirectory: false)
        defer {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: tempDir)
        }

        let rooms = [
            RoomArea(id: "living", name: "客厅", sortOrder: 0),
            RoomArea(id: "study", name: "书房", sortOrder: 1),
        ]
        let devices = [
            SmartDevice(
                id: "dev_living_light",
                name: "客厅吸顶灯",
                roomId: "living",
                roomName: "客厅",
                model: "yeelink.light.ceiling",
                isOnline: true,
                kind: .light(LightSpec(
                    entityId: "light.living",
                    isOn: true,
                    brightnessPercent: 80,
                    colorTempKelvin: 4000,
                    minKelvin: 2700,
                    maxKelvin: 6500
                ))
            ),
            SmartDevice(
                id: "dev_study_ac",
                name: "书房空调",
                roomId: "study",
                roomName: "书房",
                model: "xiaomi.aircondition.mc5",
                isOnline: true,
                kind: .climate(ClimateSpec(
                    entityId: "climate.study",
                    isOn: true,
                    hvacMode: "cool",
                    availableModes: ["off", "cool", "heat"],
                    targetTemperature: 25,
                    currentTemperature: 27
                ))
            ),
        ]
        let readings = [
            EnvironmentReading(
                id: "sensor_living_1",
                label: "沙发温湿度计",
                roomName: "客厅",
                temperature: 24.5,
                humidity: 52,
                battery: 90
            ),
            EnvironmentReading(
                id: "sensor_living_2",
                label: "阳台侧温湿度计",
                roomName: "客厅",
                temperature: 26.1,
                humidity: 48,
                battery: 82
            ),
        ]
        let scenes = [
            HomeScene(id: "scene_movie", name: "观影模式", entityId: "scene.movie", iconName: "film.fill")
        ]

        let provider = MockHomeProvider(
            snapshot: SynthesizedHome(
                rooms: rooms,
                devices: devices,
                environmentReadings: readings,
                scenes: scenes
            )
        )
        let store = HomeStore(provider: provider, defaultsSuiteName: suite)
        store.raycastSnapshotTestURL = snapshotFile
        try await store.waitForInitialSnapshot(timeout: .seconds(5))
        store.setRaycastIntegration(enabled: true)
        store.exportRaycastSnapshotIfNeeded()

        // Selecting a single room in the panel must NOT hide other rooms in the Raycast snapshot.
        store.selectRoom("study")
        store.exportRaycastSnapshotIfNeeded()

        let data = try Data(contentsOf: snapshotFile)
        let decoded = try JSONDecoder().decode(RaycastSnapshot.self, from: data)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.bridgeToken.count >= 32)
        #expect(decoded.devices.count == 2)

        let lightItem = try #require(decoded.devices.first(where: { $0.id == "dev_living_light" }))
        let acItem = try #require(decoded.devices.first(where: { $0.id == "dev_study_ac" }))
        #expect(lightItem.capabilities.supportsMoonlight == true)
        #expect(acItem.capabilities.supportsMoonlight == false)
        #expect(acItem.capabilities.temperatureWritable == true)
        #expect(lightItem.pinyinInitials == "ktxdd")

        // Both sensors in the same room keep their distinct IDs.
        #expect(decoded.environmentReadings.map(\.id) == ["sensor_living_1", "sensor_living_2"])
        #expect(decoded.quickActions.map(\.id) == ["lightsOff", "softNightLight", "climateSleepOff", "allOff", "undo"])

        // File permissions must be 0600.
        let attrs = try FileManager.default.attributesOfItem(atPath: snapshotFile.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
        #expect((perms & 0o777) == 0o600)

        // Built-in quick action + undo execution and command feedback persistence.
        let lightsOffOutcome = await store.executeBuiltInURLScene(.lightsOff)
        #expect(!lightsOffOutcome.isError)
        #expect(store.devices.first(where: { $0.id == "dev_living_light" })?.isActiveOn == false)

        let undoOutcome = await store.executeBuiltInURLScene(.undo)
        #expect(!undoOutcome.isError)
        #expect(store.devices.first(where: { $0.id == "dev_living_light" })?.isActiveOn == true)

        store.recordRaycastCommandFeedback(
            requestId: "req-99",
            command: "ask:打开客厅灯",
            message: "已打开 客厅吸顶灯",
            isError: false
        )
        let updatedData = try Data(contentsOf: snapshotFile)
        let updatedSnapshot = try JSONDecoder().decode(RaycastSnapshot.self, from: updatedData)
        #expect(updatedSnapshot.lastCommandFeedback?.requestId == "req-99")
        #expect(updatedSnapshot.lastCommandFeedback?.message == "已打开 客厅吸顶灯")
        #expect(updatedSnapshot.lastCommandFeedback?.isError == false)
    }
}

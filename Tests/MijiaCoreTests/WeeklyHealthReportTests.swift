import Foundation
import Testing
@testable import MijiaCore

private let day: TimeInterval = 86_400
private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func device(
    _ id: String,
    _ name: String,
    room: String = "客厅",
    online: Bool = true,
    kind: DeviceKind
) -> SmartDevice {
    SmartDevice(id: id, name: name, roomId: room, roomName: room, model: "test.\(id)", isOnline: online, kind: kind)
}

/// 14 daily totals, oldest first: the first 7 are last week, the last 7 this week.
private func fortnight(lastWeek: [Double?], thisWeek: [Double?]) -> [EnergyDayTotal] {
    (lastWeek + thisWeek).enumerated().map { offset, kwh in
        EnergyDayTotal(day: now.addingTimeInterval(Double(offset - 13) * day), kwh: kwh ?? 0, isObserved: kwh != nil)
    }
}

private func summary(min: Double, max: Double, average: Double) -> SensorMetricSummary {
    SensorMetricSummary(min: min, max: max, average: average, latest: average, observedCount: 7)
}

/// #182: a weekly, locally computed home health report.
struct WeeklyHealthReportTests {
    @Test("Compares this week's energy with last week and ranks the top consumers")
    func energyComparison() throws {
        let report = WeeklyHealthReport.build(
            devices: [],
            dailyEnergy: fortnight(lastWeek: Array(repeating: 1.0, count: 7), thisWeek: Array(repeating: 1.5, count: 7)),
            energyByDevice: [
                EnergyDeviceTotal(deviceId: "a", name: "热水器插座", kwh: 6),
                EnergyDeviceTotal(deviceId: "b", name: "电脑插座", kwh: 3),
                EnergyDeviceTotal(deviceId: "c", name: "台灯插座", kwh: 1),
                EnergyDeviceTotal(deviceId: "d", name: "路由器插座", kwh: 0.5),
            ],
            climate: [:],
            now: now
        )
        let energy = try #require(report.energy)
        #expect(abs(energy.thisWeekKwh - 10.5) < 1e-9)
        #expect(abs(try #require(energy.lastWeekKwh) - 7) < 1e-9)
        #expect(abs(try #require(energy.changePercent) - 50) < 1e-9)
        #expect(energy.topConsumers.map(\.name) == ["热水器插座", "电脑插座", "台灯插座"])
    }

    @Test("Leaves out the energy section, and the comparison, when no day was measured")
    func energyNeedsObservedDays() throws {
        let none = WeeklyHealthReport.build(
            devices: [],
            dailyEnergy: fortnight(lastWeek: Array(repeating: nil, count: 7), thisWeek: Array(repeating: nil, count: 7)),
            energyByDevice: [],
            climate: [:],
            now: now
        )
        #expect(none.energy == nil)

        // Recording started this week: no invented baseline for last week.
        let fresh = WeeklyHealthReport.build(
            devices: [],
            dailyEnergy: fortnight(lastWeek: Array(repeating: nil, count: 7), thisWeek: [nil, nil, nil, 2, 2, 2, 2]),
            energyByDevice: [],
            climate: [:],
            now: now
        )
        let energy = try #require(fresh.energy)
        #expect(energy.lastWeekKwh == nil)
        #expect(energy.changePercent == nil)
    }

    @Test("Reports each sensor's weekly range and flags humidity and temperature outside the comfort band")
    func climateRanges() throws {
        let devices = [
            device("t1", "温湿度计", room: "卧室", kind: .sensor(SensorSpec(temperature: 24, humidity: 55))),
            device("t2", "温湿度计", room: "卫生间", kind: .sensor(SensorSpec(temperature: 26, humidity: 80))),
        ]
        let report = WeeklyHealthReport.build(
            devices: devices,
            dailyEnergy: [],
            energyByDevice: [],
            climate: [
                "t1": .init(temperature: summary(min: 21, max: 26, average: 23.5), humidity: summary(min: 40, max: 60, average: 50)),
                "t2": .init(temperature: summary(min: 22, max: 31, average: 25), humidity: summary(min: 55, max: 88, average: 72)),
            ],
            now: now
        )
        #expect(report.climate.map(\.roomName) == ["卧室", "卫生间"])
        #expect(report.climate[0].warnings.isEmpty)
        #expect(report.climate[1].warnings == [.tooHumid(88), .tooHot(31)])
    }

    @Test("Lists filters and batteries that are about to run out, lowest first")
    func maintenance() {
        let devices = [
            device("p", "净化器", kind: .fan(FanSpec(entityId: "fan.p", isOn: true, filterLifePercent: 8))),
            device("p2", "新风机", kind: .fan(FanSpec(entityId: "fan.p2", isOn: true, filterLifePercent: 60))),
            device("s", "门磁", room: "玄关", kind: .sensor(SensorSpec(battery: 5))),
            device("s2", "人体传感器", kind: .sensor(SensorSpec(battery: 18))),
            device("s3", "温湿度计", kind: .sensor(SensorSpec(battery: 90))),
            device("s4", "离线门磁", online: false, kind: .sensor(SensorSpec(battery: 3))),
        ]
        let report = WeeklyHealthReport.build(devices: devices, dailyEnergy: [], energyByDevice: [], climate: [:], now: now)
        #expect(report.maintenance.map(\.deviceName) == ["门磁", "净化器", "人体传感器"])
        #expect(report.maintenance.map(\.item) == [.battery(5), .filter(8), .battery(18)])
    }

    @Test("Lists devices that are offline when the report is built")
    func offline() {
        let devices = [
            device("a", "台灯", room: "书房", online: false, kind: .sensor(SensorSpec())),
            device("b", "空调", online: true, kind: .sensor(SensorSpec())),
        ]
        let report = WeeklyHealthReport.build(devices: devices, dailyEnergy: [], energyByDevice: [], climate: [:], now: now)
        #expect(report.offlineDevices == [.init(deviceName: "台灯", roomName: "书房")])
    }

    @Test("Renders Markdown with one section per finding and a one-line notification summary")
    func rendering() {
        let devices = [
            device("s", "门磁", room: "玄关", kind: .sensor(SensorSpec(battery: 5))),
            device("a", "台灯", room: "书房", online: false, kind: .sensor(SensorSpec())),
        ]
        let report = WeeklyHealthReport.build(
            devices: devices,
            dailyEnergy: fortnight(lastWeek: Array(repeating: 1.0, count: 7), thisWeek: Array(repeating: 0.5, count: 7)),
            energyByDevice: [EnergyDeviceTotal(deviceId: "x", name: "电脑插座", kwh: 3.5)],
            climate: [:],
            now: now
        )
        let markdown = report.markdown(language: .chinese)
        #expect(markdown.contains("## 用电"))
        #expect(markdown.contains("3.5 kWh"))
        #expect(markdown.contains("比上周 -50%"))
        #expect(markdown.contains("- 电脑插座：3.5 kWh"))
        #expect(markdown.contains("## 需要更换"))
        #expect(markdown.contains("- 玄关 · 门磁：电池 5%"))
        #expect(markdown.contains("## 离线设备"))
        #expect(markdown.contains("- 书房 · 台灯"))
        #expect(!markdown.contains("## 温湿度"))
        #expect(report.notificationSummary(language: .chinese) == "本周用电 3.5 kWh（比上周 -50%） · 1 台待更换 · 1 台离线")

        let english = report.markdown(language: .english)
        #expect(english.contains("## Energy"))
        #expect(english.contains("- 玄关 · 门磁: battery 5%"))
    }

    @Test("Says the home looks fine when nothing needs attention")
    func allClear() {
        let report = WeeklyHealthReport.build(devices: [], dailyEnergy: [], energyByDevice: [], climate: [:], now: now)
        #expect(report.notificationSummary(language: .chinese) == "本周一切正常")
        #expect(report.markdown(language: .chinese).contains("本周一切正常"))
    }
}

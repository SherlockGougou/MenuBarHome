import Foundation
import MijiaCore
import SwiftUI

// MARK: - Shared Detail Controls (#5)

/// A reading value in the drawer's right column. Shared by the cover battery and generic facets.
struct DetailValueText: View {
    let text: String
    var color: Color = .secondary
    var size: CGFloat = DesignTokens.TypeSize.caption
    var weight: Font.Weight = .medium

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
            .monospacedDigit()
            .lineLimit(1)
    }
}

/// A pill button in a detail drawer. `tint` nil keeps the shared accent colour.
struct DetailPillButton: View {
    let title: String
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(PillActionButtonStyle(tintColor: tint ?? .accentColor))
    }
}

/// The glass slider shared by the cover position row and generic sliders.
struct DetailSliderControl: View {
    let value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let iconName: String
    var iconColor: Color = .secondary
    var trackColors: [Color]
    let formattedValue: String
    let onChange: (Double) -> Void

    var body: some View {
        LiquidGlassSlider(
            value: Binding(get: { value }, set: onChange),
            in: range,
            step: step,
            iconName: iconName,
            iconColor: iconColor,
            trackFill: LinearGradient(
                colors: trackColors,
                startPoint: .leading,
                endPoint: .trailing
            ),
            formattedValue: formattedValue
        )
    }
}

// MARK: - 更多设置

/// Generic drawer rows synthesized from the MIoT spec (#5). The section starts folded, keeps the
/// busiest rows behind a second fold, and explains every write the whitelist keeps closed.
struct DeviceFacetSection: View {
    let device: SmartDevice
    let store: HomeStore
    let accent: Color
    let statusColor: Color

    @State private var isExpanded: Bool
    @State private var showsRest: Bool

    init(
        device: SmartDevice,
        store: HomeStore,
        accent: Color,
        statusColor: Color,
        initiallyExpanded: Bool = false,
        initiallyShowsRest: Bool = false
    ) {
        self.device = device
        self.store = store
        self.accent = accent
        self.statusColor = statusColor
        _isExpanded = State(initialValue: initiallyExpanded)
        _showsRest = State(initialValue: initiallyShowsRest)
    }

    private var controls: [FacetControl] {
        store.deviceFacets[device.id] ?? []
    }

    /// High-value facets first, then the rest in spec order. `sorted` is not stable.
    private var ordered: [FacetControl] {
        let all = controls
        return all.filter(\.isHighValue) + all.filter { !$0.isHighValue }
    }

    private var visibleLimit: Int {
        max(1, DeviceProfiles.current.facets.maxVisible)
    }

    private var visible: [FacetControl] {
        Array(ordered.prefix(visibleLimit))
    }

    private var folded: [FacetControl] {
        Array(ordered.dropFirst(visibleLimit))
    }

    private var duplicateTitles: Set<String> {
        var seen: Set<String> = []
        var repeated: Set<String> = []
        for control in ordered {
            let title = FacetLabel.title(control)
            if !seen.insert(title).inserted { repeated.insert(title) }
        }
        return repeated
    }

    var body: some View {
        if controls.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                header
                if isExpanded {
                    ForEach(visible) { control in
                        row(control)
                    }
                    if !folded.isEmpty {
                        restToggle
                        if showsRest {
                            ForEach(folded) { control in
                                row(control)
                            }
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: DesignTokens.TypeSize.caption, weight: .semibold))
                    .foregroundStyle(statusColor)
                Text(L10n.tr("更多设置", "More Settings"))
                    .font(.system(size: DesignTokens.TypeSize.caption, weight: .semibold))
                Text("\(controls.count)")
                    .font(.system(size: DesignTokens.TypeSize.control, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: DesignTokens.TypeSize.control, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.tr("更多设置", "More Settings")))
        .accessibilityValue(Text(isExpanded
            ? L10n.tr("已展开", "Expanded")
            : L10n.tr("已收起", "Collapsed")))
        .panelHelp(L10n.tr("显示辅助控件", "Show auxiliary controls"))
    }

    private var restToggle: some View {
        Button {
            showsRest.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(L10n.tr(
                    "还有 \(folded.count) 项次要设置",
                    "\(folded.count) more settings"
                ))
                .font(.system(size: DesignTokens.TypeSize.control, weight: .medium))
                .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: DesignTokens.TypeSize.micro, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showsRest ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func row(_ control: FacetControl) -> some View {
        let title = displayTitle(control)
        let enabled = isEnabled(control)
        let reason = disabledReason(control)
        switch control.kind {
        case .toggle:
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: DesignTokens.TypeSize.caption, weight: .medium))
                    if let reason { reasonText(reason) }
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { control.isOn ?? false },
                    set: { store.setFacetValue(device.id, controlId: control.id, value: .bool($0)) }
                ))
                .labelsHidden()
                .accessibilityLabel(Text(title))
                .toggleStyle(.glass)
                .controlSize(.mini)
                .disabled(!enabled)
            }

        case .select:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: DesignTokens.TypeSize.caption, weight: .medium))
                    Spacer(minLength: 8)
                    Picker("", selection: Binding(
                        get: { control.value?.intValue ?? control.options.first?.value ?? 0 },
                        set: { store.setFacetValue(device.id, controlId: control.id, value: .number(Double($0))) }
                    )) {
                        ForEach(control.options, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(Text(title))
                    .pickerStyle(.menu)
                    .fixedSize()
                    .disabled(!enabled)
                }
                if let reason { reasonText(reason) }
            }

        case .slider:
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: DesignTokens.TypeSize.caption, weight: .medium))
                if let range = control.range {
                    DetailSliderControl(
                        value: control.numberValue ?? range.min,
                        range: range.min...range.max,
                        step: range.step > 0 ? range.step : nil,
                        iconName: FacetLabel.icon(control.name),
                        iconColor: statusColor,
                        trackColors: [accent.opacity(0.55), accent.opacity(0.92)],
                        formattedValue: FacetLabel.value(control)
                    ) { newValue in
                        store.setFacetValue(device.id, controlId: control.id, value: .number(newValue))
                    }
                    .disabled(!enabled)
                    .accessibilityLabel(Text(title))
                }
                if let reason { reasonText(reason) }
            }

        case .reading:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: DesignTokens.TypeSize.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                DetailValueText(text: FacetLabel.value(control), color: statusColor)
            }

        case .button:
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    DetailPillButton(title: title, tint: accent) {
                        store.runFacetAction(device.id, controlId: control.id)
                    }
                    .disabled(!enabled)
                    Spacer(minLength: 0)
                }
                if let reason { reasonText(reason) }
            }
        }
    }

    private func displayTitle(_ control: FacetControl) -> String {
        let title = FacetLabel.title(control)
        guard duplicateTitles.contains(title) else { return title }
        return "\(title) · \(FacetLabel.service(control.serviceName))"
    }

    private func isEnabled(_ control: FacetControl) -> Bool {
        guard control.isWritable else { return false }
        return device.isOnline && (control.writesByDefault || store.allowAdvancedFacetWrites)
    }

    private func disabledReason(_ control: FacetControl) -> String? {
        guard control.isWritable, !control.writesByDefault, !store.allowAdvancedFacetWrites else {
            return nil
        }
        return L10n.tr(
            "不在默认写入白名单，可在设置中允许写入",
            "Outside the write whitelist; allow writes in Settings"
        )
    }

    private func reasonText(_ reason: String) -> some View {
        Label(reason, systemImage: "lock.fill")
            .font(.system(size: DesignTokens.TypeSize.micro, weight: .medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Facet labels

enum FacetLabel {
    /// Common MIoT short names. A localized title here beats the spec's vendor description.
    private static let chineseNames: [String: String] = [
        "on": "开关",
        "mode": "模式",
        "fan-level": "风速",
        "fan-speed": "风速",
        "brightness": "亮度",
        "color-temperature": "色温",
        "target-temperature": "目标温度",
        "target-temp": "目标温度",
        "temperature": "温度",
        "relative-humidity": "湿度",
        "pm2.5-density": "PM2.5",
        "battery-level": "电量",
        "fault": "故障",
        "status": "状态",
        "volume": "音量",
        "mute": "静音",
        "motion-detection": "移动侦测",
        "detection-sensitivity": "侦测灵敏度",
        "alarm-interval": "报警间隔",
        "night-shot": "夜视",
        "current-position": "当前位置",
        "target-position": "目标位置",
        "motor-control": "电机控制",
        "motor-reverse": "电机方向",
        "physical-controls-locked": "按键锁",
        "indicator-light": "指示灯",
        "default-power-on-state": "通电默认状态",
        "soft-wind": "柔风",
        "horizontal-swing": "左右摆风",
        "vertical-swing": "上下摆风",
        "heat-level": "加热档位",
        "storage-free-space": "剩余空间",
        "storage-total-space": "总空间",
        "storage-used-space": "已用空间",
        "left-time": "剩余时间",
        "delay-off-time": "延时关闭",
        "work-mode": "工作模式",
        "privacy-mode": "隐私模式",
    ]

    private static let chineseServices: [String: String] = [
        "fan-control": "风扇",
        "environment": "环境",
        "fresh-air": "新风",
        "floor-heat": "地暖",
        "other": "其他",
        "setting": "设置",
        "setmode": "遥控设置",
        "light": "灯光",
        "indicator-light": "指示灯",
        "physical-controls-locked": "按键锁",
        "memory-card-management": "存储卡",
        "motion-detection": "移动侦测",
        "p2p-stream": "视频流",
        "speaker": "扬声器",
        "cockpit-service": "车载服务",
        "air-purifier": "净化器",
        "air-fresh": "新风",
        "custom": "自定义",
        "battery": "电池",
        "vacuum": "扫地机",
        "zone-state-one": "播放分区",
        "device-state": "设备状态",
        "device-control": "按键",
        "play-control": "播放",
        "television": "电视",
        "message-router": "消息",
        "power-consumption": "功耗",
        "ptz-control": "云台",
    ]

    static func title(_ control: FacetControl) -> String {
        if !L10n.isEnglish, let chinese = chineseNames[control.name] {
            return chinese
        }
        let raw = control.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? humanized(control.name) : raw
    }

    static func service(_ name: String) -> String {
        if !L10n.isEnglish, let chinese = chineseServices[name] {
            return chinese
        }
        return humanized(name)
    }

    static func humanized(_ raw: String) -> String {
        let words = raw.replacingOccurrences(of: "-", with: " ")
        guard let first = words.first else { return raw }
        return first.uppercased() + String(words.dropFirst())
    }

    static func value(_ control: FacetControl) -> String {
        if let option = control.selectedOption { return option.label }
        if case .toggle = control.kind {
            return control.isOn == true ? L10n.tr("开", "On") : L10n.tr("关", "Off")
        }
        guard let raw = control.numberValue else {
            if let isOn = control.isOn {
                return isOn ? L10n.tr("开", "On") : L10n.tr("关", "Off")
            }
            if let text = control.value?.stringValue { return text }
            return "—"
        }
        let scaled = raw * (control.scale ?? 1)
        if control.kind == .reading, control.unit?.lowercased() == "celsius" {
            return L10n.temperature(scaled, fractionDigits: 1)
        }
        return number(scaled) + unitSuffix(control.unit)
    }

    private static func number(_ value: Double) -> String {
        if value.rounded() == value, let exact = Int(exactly: value) { return "\(exact)" }
        return String(format: "%.1f", value)
    }

    private static func unitSuffix(_ raw: String?) -> String {
        let unit = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !unit.isEmpty, unit.lowercased() != "none" else { return "" }
        switch unit.lowercased() {
        case "celsius": return " °C"
        case "percentage", "percent": return "%"
        case "ppm": return " ppm"
        case "lux": return " lx"
        case "minutes": return " min"
        case "seconds": return " s"
        case "hour", "hours": return " h"
        default: return " \(unit)"
        }
    }

    static func icon(_ name: String) -> String {
        switch name {
        case "brightness": return "sun.max.fill"
        case "color-temperature": return "thermometer.sun.fill"
        case "target-temperature", "target-temp", "temperature": return "thermometer.medium"
        case "fan-level", "fan-speed": return "wind"
        case "volume": return "speaker.wave.2.fill"
        case "target-position", "current-position": return "window.vertical.open"
        default: return "slider.horizontal.3"
        }
    }
}

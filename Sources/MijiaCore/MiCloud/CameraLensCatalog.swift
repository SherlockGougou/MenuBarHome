import Foundation

/// Models that expose a second lens through go2rtc's Xiaomi `channel` query.
///
/// go2rtc treats every non-zero channel as the second lens. The value itself is not a
/// lens index; it only tells the camera to start its second video stream. Keep this list
/// evidence-based: an unlisted model without a dual-lens name stays single-lens instead of
/// showing a switch that silently returns the same picture.
public enum CameraLensCatalog {
    private static let secondLensModels: Set<String> = [
        "isa.camera.500dh",
        "isa.camera.hlmax",
        "chuangmi.camera.72ac1",
        "xiaomi.camera.082ac1",
    ]

    public static func lenses(for model: String, name: String = "") -> [CameraLens] {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let namedDual = name.contains("双摄") || name.contains("双镜头")
            || name.lowercased().contains("dual")
        guard secondLensModels.contains(normalized) || namedDual else { return [] }
        return [
            CameraLens(role: .main, channel: 0),
            CameraLens(role: .secondary, channel: 1),
        ]
    }
}

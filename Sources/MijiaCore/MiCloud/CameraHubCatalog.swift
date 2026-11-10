import Foundation

/// Battery-camera kits whose camera has no LAN address of its own.
///
/// The hub receives the P2P connection and selects the camera with go2rtc's `subdid`
/// parameter. Keep this mapping explicit: guessing a parent from room or name would attach
/// an unrelated camera to the wrong hub.
public enum CameraHubCatalog {
    private static let cameraToHub: [String: String] = [
        "mxiang.camera.mwc11": "mxiang.camera.mwc10",
    ]

    public static func hubModel(for model: String) -> String? {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return cameraToHub.first { normalized.hasPrefix($0.key) }?.value
    }

    public static func isHub(model: String) -> Bool {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return cameraToHub.values.contains { normalized.hasPrefix($0) }
    }
}

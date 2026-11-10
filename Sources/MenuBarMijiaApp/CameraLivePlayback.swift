import Foundation
import MijiaCore

/// One native P2P playback session. The player and its reconnect loop outlive the SwiftUI
/// surface, so switching to another camera can keep this session warm and reattach it later
/// without renegotiating the camera's single P2P connection.
@MainActor
final class CameraLivePlayback {
    let deviceID: String
    let lensID: String
    let source: CameraStreamSource
    let player: CameraLiveVideoPlayer

    private(set) var hasFrame = false
    private(set) var failure: String?
    private let url: URL
    private let mjpegFallback: URL?
    private var task: Task<Void, Never>?

    var onFirstFrame: (@MainActor () -> Void)?
    var onFallback: (@MainActor (URL) -> Void)?
    var onFailure: (@MainActor (String?) -> Void)?

    init?(deviceID: String, lensID: String, source: CameraStreamSource) {
        guard case .liveMP4(let url, let mjpegFallback, _) = source else { return nil }
        self.deviceID = deviceID
        self.lensID = lensID
        self.source = source
        self.url = url
        self.mjpegFallback = mjpegFallback
        self.player = CameraLiveVideoPlayer()
        player.onFirstFrame = { [weak self] in
            guard let self, self.task != nil else { return }
            self.hasFrame = true
            self.onFirstFrame?()
        }
    }

    func start() {
        guard task == nil else { return }
        task = Task { @MainActor [weak self] in
            var failedAttempts = 0
            while !Task.isCancelled {
                guard let self else { return }
                let watchdog = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(15))
                    guard !Task.isCancelled, let self, !self.hasFrame else { return }
                    self.player.stop()
                }
                let outcome = await self.player.play(url: self.url)
                watchdog.cancel()
                guard !Task.isCancelled else { return }

                if outcome.framesDecoded > 0 {
                    failedAttempts = 0
                    try? await Task.sleep(for: .milliseconds(400))
                    continue
                }

                failedAttempts += 1
                if failedAttempts >= 2, !self.hasFrame, let mjpegFallback = self.mjpegFallback {
                    self.player.stop()
                    self.task = nil
                    self.failure = "mjpeg fallback"
                    self.onFallback?(mjpegFallback)
                    return
                }
                if failedAttempts >= 4 {
                    self.pauseAfterFailure(outcome.failure)
                    return
                }
                try? await Task.sleep(for: .milliseconds(900))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        player.stop()
        hasFrame = false
        failure = nil
    }

    private func pauseAfterFailure(_ detail: String?) {
        task = nil
        player.stop()
        hasFrame = false
        let reason = Self.terminalFailureReason(detail)
        failure = reason
        onFailure?(reason)
    }

    static func terminalFailureReason(_ detail: String?) -> String {
        let trimmed = detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty else { return trimmed }
        return L10n.tr(
            "连续多次未收到画面，请重试",
            "No frames received after repeated attempts; try again"
        )
    }
}

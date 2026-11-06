import AppKit
import Foundation
import MijiaCore

/// Executes `menumijia://` links (#57).
///
/// Web pages can navigate to a custom scheme without a verifiable user gesture, so each control
/// action is shown in an app-modal confirmation sheet unless the user turned on “允许 URL 直控”
/// or the link carries the local `0600` companion `bridgeToken`.
/// The sheet names the device and the exact action (turn on/off, run scene, run command) so the
/// user is never asked to approve an opaque request.
@MainActor
final class URLCommandHandler {
    static let shared = URLCommandHandler()

    private enum Resolved {
        case toggle(SmartDevice)
        case scene(HomeScene)
        case builtInScene(BuiltInURLScene)
        case ask(String)
    }

    private var pendingURLs: [URL] = []
    private var isDraining = false

    /// Test seam replacing modal `NSAlert` confirmation in unit tests.
    var confirmationHandler: ((String) -> Bool)?
    /// Test seam replacing `HotkeyAndNotificationManager.shared.ensureMenuBarExtraWindowVisible()`.
    var windowVisibilityHandler: (() -> Void)?

    init() {}

    func enqueue(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        pendingURLs.append(contentsOf: urls)
        guard !isDraining else { return }
        isDraining = true
        Task { @MainActor [weak self] in
            await self?.drain()
        }
    }

    private func drain() async {
        while !pendingURLs.isEmpty {
            let url = pendingURLs.removeFirst()
            await handle(url)
        }
        isDraining = false
    }

    func handle(_ url: URL, in store: HomeStore = HomeStore.shared) async {
        guard let envelope = AppURLParser.parseEnvelope(url) else {
            let message = L10n.tr("无法识别的控制链接", "Unrecognized control link")
            store.showToast(message, isError: true)
            store.recordRaycastCommandFeedback(
                requestId: nil,
                command: "invalid",
                message: message,
                isError: true
            )
            return
        }

        // A link can be the launch reason; wait briefly for the provider's first snapshot so the
        // confirmation sheet can name the device instead of failing.
        do {
            try await store.waitForInitialSnapshot()
        } catch {
            finish(error.localizedDescription, isError: true, envelope: envelope, store: store)
            return
        }

        guard let resolved = resolve(envelope.command, store: store) else {
            let message = L10n.tr(
                "链接里的设备或场景不存在，或尚未加载",
                "The device or scene in the link is missing or not loaded yet"
            )
            store.showToast(message, isError: true)
            store.recordRaycastCommandFeedback(
                requestId: envelope.requestId,
                command: commandLabel(for: envelope.command),
                message: message,
                isError: true
            )
            return
        }

        if store.isControlBlockedByScreenLock {
            finish(store.screenLockBlockedMessage, isError: true, envelope: envelope, store: store)
            return
        }

        let isTrustedBridge = URLDirectControl.isValidBridgeToken(
            envelope.token,
            expectedToken: store.raycastBridgeToken
        )

        if URLDirectControl.requiresConfirmation(
            in: store.userDefaults,
            providedToken: envelope.token,
            expectedToken: store.raycastBridgeToken
        ) {
            let prompt = description(for: resolved)
            let approved = confirmationHandler?(prompt) ?? confirm(prompt)
            guard approved else {
                store.recordRaycastCommandFeedback(
                    requestId: envelope.requestId,
                    command: commandLabel(for: envelope.command),
                    message: L10n.tr("已取消外部链接执行", "Cancelled external link execution"),
                    isError: true
                )
                return
            }
        }

        // Keep Raycast/Tinycast keyboard focus when invoked with a valid local bridgeToken;
        // only open the menu-bar window upfront for untrusted external links.
        if !isTrustedBridge {
            openMenuBarWindowIfNeeded()
        }
        await execute(resolved, envelope: envelope, isTrustedBridge: isTrustedBridge, store: store)
    }

    private func openMenuBarWindowIfNeeded() {
        if let windowVisibilityHandler {
            windowVisibilityHandler()
        } else {
            HotkeyAndNotificationManager.shared.ensureMenuBarExtraWindowVisible()
        }
    }

    private func resolve(_ command: AppURLCommand, store: HomeStore) -> Resolved? {
        switch command {
        case .toggle(let deviceId):
            // Accept an id (documented) or an exact name for hand-written links. Only devices a
            // single click can control qualify: `togglePrimary` opens the detail drawer for
            // speakers/fridges, and a link must never expand UI instead of controlling something.
            guard let device = store.devices.first(where: {
                ($0.id == deviceId || $0.name == deviceId) && $0.isPrimaryToggleable
            }) else {
                return nil
            }
            return .toggle(device)
        case .scene(let name):
            if name.lowercased().hasPrefix("quick:"),
               let builtIn = BuiltInURLScene.resolve(name) {
                return .builtInScene(builtIn)
            }
            if let scene = store.scenes.first(where: { $0.name == name || $0.id == name }) {
                return .scene(scene)
            }
            if let builtIn = BuiltInURLScene.resolve(name) {
                return .builtInScene(builtIn)
            }
            return nil
        case .ask(let text):
            return .ask(text)
        }
    }

    private func description(for resolved: Resolved) -> String {
        switch resolved {
        case .toggle(let device):
            let verb: String
            if device.isMomentaryButton {
                verb = L10n.tr("触发", "Trigger")
            } else {
                verb = device.isActiveOn
                    ? L10n.tr("关闭", "Turn off")
                    : L10n.tr("打开", "Turn on")
            }
            let room = L10n.displayRoomName(device.roomName)
            return L10n.format(
                "%@「%@」（%@）",
                "%@ \"%@\" (%@)",
                verb,
                device.name,
                room
            )
        case .scene(let scene):
            return L10n.format("触发场景「%@」", "Run scene \"%@\"", scene.name)
        case .builtInScene(let builtIn):
            return L10n.format("执行快捷动作「%@」", "Run quick action \"%@\"", builtIn.displayTitle)
        case .ask(let text):
            return L10n.format("执行指令：「%@」", "Run command: \"%@\"", text)
        }
    }

    /// Returns true when the user approved this one action.
    private func confirm(_ description: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n.tr(
            "允许外部链接控制设备？",
            "Allow an external link to control devices?"
        )
        alert.informativeText = description + "\n\n" + L10n.tr(
            "网页和其它 App 都可以打开这个链接。确认后只执行这一次。",
            "Web pages and other apps can open this link. It runs only once after you confirm."
        )
        alert.alertStyle = .warning
        // Cancel is the default (Return) button so a web-triggered sheet is not approved by a stray
        // keystroke; the user has to choose the second button explicitly.
        alert.addButton(withTitle: L10n.tr("取消", "Cancel"))
        alert.addButton(withTitle: L10n.tr("执行一次", "Run Once"))
        return alert.runModal() == .alertSecondButtonReturn
    }

    private func execute(
        _ resolved: Resolved,
        envelope: AppURLCommandEnvelope,
        isTrustedBridge: Bool,
        store: HomeStore
    ) async {
        switch resolved {
        case .toggle(let snapshot):
            guard let device = store.devices.first(where: { $0.id == snapshot.id }) else {
                let message = L10n.tr("设备已不在面板中", "The device is no longer available")
                finish(message, isError: true, envelope: envelope, store: store)
                return
            }
            guard device.isOnline else {
                finish(
                    L10n.format("%@ 当前离线", "%@ is offline", device.name),
                    isError: true,
                    envelope: envelope,
                    store: store
                )
                return
            }
            // `togglePrimary` flips whatever the device is doing now, so report the result rather
            // than a prediction made before the confirmation sheet appeared.
            let isMomentary = device.isMomentaryButton
            let previousToastId = store.toastNotice?.id
            guard let task = store.togglePrimary(device) else {
                let cancellationOrRejection = (store.toastNotice?.id != previousToastId)
                    ? store.toastNotice?.message
                    : nil
                finish(
                    cancellationOrRejection ?? (
                        isMomentary
                            ? L10n.format("%@ 触发失败", "Failed to trigger %@", device.name)
                            : L10n.format("%@ 响应失败", "%@ failed to respond", device.name)
                    ),
                    isError: true,
                    envelope: envelope,
                    store: store
                )
                return
            }
            guard await task.value == true else {
                finish(
                    isMomentary
                        ? L10n.format("%@ 触发失败", "Failed to trigger %@", device.name)
                        : L10n.format("%@ 响应失败", "%@ failed to respond", device.name),
                    isError: true,
                    envelope: envelope,
                    store: store
                )
                return
            }
            let isOnNow = store.devices.first(where: { $0.id == device.id })?.isActiveOn ?? false
            if isMomentary {
                finish(
                    L10n.format("已触发 %@", "Triggered %@", device.name),
                    envelope: envelope,
                    store: store
                )
                return
            }
            finish(
                isOnNow
                    ? L10n.format("已打开 %@", "Turned on %@", device.name)
                    : L10n.format("已关闭 %@", "Turned off %@", device.name),
                envelope: envelope,
                store: store
            )
        case .scene(let snapshot):
            guard let scene = store.scenes.first(where: { $0.id == snapshot.id }) else {
                let message = L10n.tr("场景已不在列表中", "The scene is no longer available")
                finish(message, isError: true, envelope: envelope, store: store)
                return
            }
            let succeeded = await store.triggerScene(scene).value
            let message = succeeded
                ? L10n.format("已触发场景：%@", "Activated scene: %@", scene.name)
                : L10n.format("场景「%@」执行失败", "Scene \"%@\" failed", scene.name)
            store.recordRaycastCommandFeedback(
                requestId: envelope.requestId,
                command: commandLabel(for: envelope.command),
                message: message,
                isError: !succeeded
            )
            // `triggerScene` already reports success/failure through the store toast; only mirror it
            // to the notification banner so a Raycast/Stream Deck trigger is visible.
            HotkeyAndNotificationManager.shared.deliverExternalActionNotification(
                title: L10n.tr("MenuBarMijia 外部链接", "MenuBarMijia external link"),
                body: message
            )
        case .builtInScene(let builtIn):
            let outcome = await store.executeBuiltInURLScene(builtIn)
            finish(outcome.message, isError: outcome.isError, envelope: envelope, store: store)
        case .ask(let text):
            let direct = await store.executeRaycastDirectCommand(text)
            if direct.handled {
                finish(direct.message, isError: direct.isError, envelope: envelope, store: store)
                return
            }
            let plan = await store.runAssistantCommand(text)
            let state = store.assistantState
            if store.pendingCloudConsent != nil {
                // The consent card lives in the assistant bar; open it so the user can allow the
                // request the link asked for.
                if isTrustedBridge {
                    openMenuBarWindowIfNeeded()
                }
                store.presentAssistantBar()
                finish(
                    L10n.tr(
                        "这条指令需要云端 AI。请在面板里确认后重试。",
                        "This command needs cloud AI. Confirm it in the panel and try again."
                    ),
                    isError: true,
                    envelope: envelope,
                    store: store
                )
            } else if case .awaitingChoice(let reply) = state {
                if isTrustedBridge {
                    openMenuBarWindowIfNeeded()
                }
                store.presentAssistantBar()
                finish(reply, isError: false, envelope: envelope, store: store)
            } else if case .failed(let reason) = state {
                finish(reason, isError: true, envelope: envelope, store: store)
            } else if case .done(let reply) = state, !reply.isEmpty {
                finish(reply, isError: false, envelope: envelope, store: store)
            } else if let plan, !plan.reply.isEmpty {
                finish(plan.reply, isError: false, envelope: envelope, store: store)
            } else {
                switch state {
                case .failed(let reason):
                    finish(reason, isError: true, envelope: envelope, store: store)
                case .done(let reply), .awaitingChoice(let reply):
                    finish(reply, envelope: envelope, store: store)
                case .thinking:
                    finish(L10n.tr("正在执行…", "Working…"), envelope: envelope, store: store)
                case .idle:
                    finish(
                        L10n.tr("没有找到可执行的设备操作", "No matching device actions"),
                        isError: true,
                        envelope: envelope,
                        store: store
                    )
                }
            }
        }
    }

    private func commandLabel(for command: AppURLCommand) -> String {
        switch command {
        case .toggle(let deviceId): return "toggle:\(deviceId)"
        case .scene(let name): return "scene:\(name)"
        case .ask(let text): return "ask:\(text)"
        }
    }

    private func finish(
        _ message: String,
        isError: Bool = false,
        envelope: AppURLCommandEnvelope,
        store: HomeStore
    ) {
        store.showToast(message, isError: isError)
        store.recordRaycastCommandFeedback(
            requestId: envelope.requestId,
            command: commandLabel(for: envelope.command),
            message: message,
            isError: isError
        )
        HotkeyAndNotificationManager.shared.deliverExternalActionNotification(
            title: L10n.tr("MenuBarMijia 外部链接", "MenuBarMijia external link"),
            body: message
        )
    }
}

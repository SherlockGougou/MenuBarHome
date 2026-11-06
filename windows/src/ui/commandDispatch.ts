import type { MenuMijiaWindowsApp } from "./app.js";
import { t } from "../core/i18n.js";
import { HomeAssistantClient, homeAssistantCommand } from "../core/homeAssistant.js";
import { MiCloudClient, MiotCommandMapper, propKeyString } from "../core/miCloudClient.js";
import { readMiotPower, type DeviceCommand } from "../core/models.js";
import { applyCommandToDevices } from "../core/commandEffects.js";

function withReadPower(command: DeviceCommand, isOn: boolean): DeviceCommand {
  switch (command.kind) {
    case "setLightPower":
    case "setClimatePower":
    case "setFanPower":
    case "setSwitch":
      return { ...command, isOn };
    default:
      return command;
  }
}


export async function applyCommand(host: MenuMijiaWindowsApp, command: DeviceCommand, readBackPower = false): Promise<boolean> {
    const sourceRevision = host.sourceRevision;
    try {
      if (host.settings.connectionMode === "homeAssistant") command = homeAssistantCommand(command, host.devices);
      const readPower = await dispatchCloudCommand(host, command, readBackPower);
      if (typeof readPower === "boolean") command = withReadPower(command, readPower);
    } catch (error) {
      if (sourceRevision !== host.sourceRevision) return false;
      host.replyBanner = {
        text: error instanceof Error ? error.message : String(error),
        source: t("控制失败"),
        isError: true,
      };
      host.render();
      return false;
    }
    if (sourceRevision !== host.sourceRevision) return false;
    host.localControlRevision += 1;
    for (const change of applyCommandToDevices(host.devices, command, host.settings.connectionMode)) {
      if (host.cameraLive.activeLiveCameraId !== change.deviceId || host.cameraLive.liveCameraHidden) continue;
      if (change.isOn) {
        host.cameraLive.reconnectCameraLiveView();
      } else {
        host.cameraLive.stopLiveTransport();
        host.cameraLive.liveCameraLoading = false;
      }
    }

    return true;
  }

export async function dispatchCloudCommand(host: MenuMijiaWindowsApp, command: DeviceCommand, readBackPower = false): Promise<boolean | null> {
    const sourceRevision = host.sourceRevision;
    if (host.settings.connectionMode === "demo") return null;
    if (host.settings.connectionMode === "homeAssistant") {
      const client = new HomeAssistantClient(host.settings.haBaseURL, host.settings.haToken);
      await host.endpointSubmission;
      if (sourceRevision !== host.sourceRevision) throw new Error("Connection source changed");
      await client.execute(command);
      return null;
    }
    if (!host.settings.miSession) throw new Error(t("请先扫码登录米家"));
    const session = host.settings.miSession;
    const dev = host.devices.find((d) => {
      const k = d.kind;
      if (k.kind === "plug") return k.switchEntityId === command.entityId || k.childLockEntityId === command.entityId;
      if (k.kind === "camera") return k.entityId === command.entityId || k.motionDetectionEntityId === command.entityId;
      if (k.kind === "fridge") {
        return (
          k.modeEntityId === command.entityId ||
          k.fridgeTargetEntityId === command.entityId ||
          k.freezerTargetEntityId === command.entityId
        );
      }
      if (k.kind === "sensor") return false;
      if (k.kind === "speaker") {
        return [k.mediaEntityId, k.muteSwitchEntityId, k.sleepModeEntityId].includes(command.entityId);
      }
      return k.entityId === command.entityId;
    });
    if (!dev) throw new Error(t("无法找到指令对应的设备"));

    const spec = await host.specResolver.resolve({
      did: dev.id,
      name: dev.name,
      model: dev.model,
      isOnline: dev.isOnline,
      specType: null,
    });
    const mapped = MiotCommandMapper.map(command, spec);
    if (sourceRevision !== host.sourceRevision) throw new Error("Connection source changed");
    const client = new MiCloudClient(session, host.transport);
    if (mapped.kind === "setProps") {
      await client.setProps(mapped.writes);
      if (readBackPower) {
        const power = mapped.writes.find((write) => typeof write.value === "boolean");
        if (power) {
          let read: Map<string, unknown>;
          try {
            read = await client.getProps([power]);
          } catch (error) {
            if (sourceRevision === host.sourceRevision) markCloudValuesStale(host);
            throw error;
          }
          const value = read.get(propKeyString(power));
          const isOn = readMiotPower(value);
          if (isOn === null) {
            // The write may have landed; the old row is no longer a trusted reading.
            if (sourceRevision === host.sourceRevision) markCloudValuesStale(host);
            throw new Error(t("未能读回设备状态"));
          }
          return isOn;
        }
      }
    } else {
      await client.action(mapped.call);
    }
    return null;
  }

export function markCloudValuesStale(host: MenuMijiaWindowsApp): void {
    if (host.settings.connectionMode === "xiaomiCloud" && host.devices.length > 0) {
      host.cloudValuesStale = true;
    }
  }

export function markCloudValuesFresh(host: MenuMijiaWindowsApp): void {
    if (host.settings.connectionMode === "xiaomiCloud") host.cloudValuesStale = false;
  }

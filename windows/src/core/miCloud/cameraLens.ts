import type { CameraLens } from "../models.js";

const secondLensModels = new Set([
  "isa.camera.500dh",
  "isa.camera.hlmax",
  "chuangmi.camera.72ac1",
  "xiaomi.camera.082ac1",
]);

/** Mirrors the macOS CameraLensCatalog so the shared golden corpus catches drift. */
export function cameraLensesFor(model: string, name = ""): readonly CameraLens[] {
  const normalized = model.trim().toLowerCase();
  const namedDual = name.includes("双摄") || name.includes("双镜头") || name.toLowerCase().includes("dual");
  if (!secondLensModels.has(normalized) && !namedDual) return [];
  return [
    { role: "main", channel: 0 },
    { role: "secondary", channel: 1 },
  ];
}

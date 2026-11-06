import deviceProfiles from "./deviceProfiles.json";
import { miotShortName } from "./spec.js";
import type { MiotAction, MiotDeviceSpec, MiotProperty, MiotService, MiotValueListItem } from "./spec.js";

export interface DeviceProfiles {
  readonly version: number;
  readonly noise: {
    readonly services: readonly string[];
    readonly properties: readonly string[];
  };
  readonly facets: {
    readonly maxVisible: number;
    /** Device types whose writes stay high risk, mirroring ModelActionPolicy's hazard table. */
    readonly highRiskTypes: readonly string[];
    readonly highValue: readonly string[];
    readonly lowRiskWrites: readonly string[];
  };
  /**
   * Device type → services that may claim it when the type names none of its own services (#296).
   * Anything not listed stays unsupported instead of being drawn as another device.
   */
  readonly fallbackClaims: Readonly<Record<string, readonly string[]>>;
}

/** The same `deviceProfiles.json` the macOS bundle ships (#303). */
export const DEVICE_PROFILES = deviceProfiles as DeviceProfiles;

/**
 * Whether a device whose type names none of its own services may be drawn from `service` (#296),
 * mirroring `MiotSynthesizer.fallbackAllows` on macOS. A `light` service may still claim light-like
 * types; it must not claim a hood, airer, bath heater or ceiling fan.
 */
export function miotFallbackAllows(deviceType: string, service: string): boolean {
  if (service === "light" && (deviceType.includes("light") || deviceType.includes("lamp"))) return true;
  return DEVICE_PROFILES.fallbackClaims[deviceType]?.includes(service) ?? false;
}

export type MiotFacetKind = "toggle" | "select" | "slider" | "reading" | "button";
export type MiotFacetRisk = "low" | "high";

export interface MiotFacetOption {
  readonly value: number;
  readonly label: string;
}

export interface MiotFacetRange {
  readonly min: number;
  readonly max: number;
  readonly step: number;
}

export interface MiotFacetArgument {
  readonly propertyId: number;
  readonly name: string;
  readonly format: string;
  readonly range?: MiotFacetRange;
  readonly options?: readonly MiotFacetOption[];
}

/**
 * One generic control synthesized from a writable property, a readable property, or an action.
 * `id` is the stable `siid.piid` key for properties and `siid.aAiid` for actions.
 */
export interface MiotFacet {
  readonly id: string;
  readonly kind: MiotFacetKind;
  readonly serviceId: number;
  readonly serviceName: string;
  readonly propertyId?: number;
  readonly actionId?: number;
  readonly name: string;
  readonly title?: string;
  readonly unit?: string;
  readonly scale?: number;
  readonly range?: MiotFacetRange;
  readonly options?: readonly MiotFacetOption[];
  readonly arguments?: readonly MiotFacetArgument[];
  /** True when the facet can change the device: a writable property or an action. */
  readonly isWritable: boolean;
  readonly risk: MiotFacetRisk;
  /** Writes stay closed unless the data whitelist marks the facet low risk. */
  readonly writesByDefault: boolean;
  /** High-value facets are the few shown first; the rest are secondary. */
  readonly highValue: boolean;
}

/** Generic facets for one MIoT spec, in spec service/property/action order. */
export function buildMiotFacets(spec: MiotDeviceSpec, profiles: DeviceProfiles = DEVICE_PROFILES): MiotFacet[] {
  const facets: MiotFacet[] = [];
  const deviceType = miotShortName(spec.type);
  for (const service of spec.services) {
    const serviceName = miotShortName(service.type);
    if (matchesMiotFacetPattern(serviceName, profiles.noise.services)) continue;
    for (const property of service.properties) {
      if (matchesMiotFacetPattern(miotShortName(property.type), profiles.noise.properties)) continue;
      const facet = propertyFacet(property, service, serviceName, deviceType, profiles);
      if (facet) facets.push(facet);
    }
    for (const action of service.actions) {
      const facet = actionFacet(action, service, serviceName, deviceType, profiles);
      if (facet) facets.push(facet);
    }
  }
  let remaining = Math.max(0, profiles.facets.maxVisible);
  for (let index = 0; index < facets.length; index += 1) {
    const facet = facets[index]!;
    if (!matchesMiotFacetPattern(facet.name, profiles.facets.highValue)) continue;
    if (remaining <= 0) break;
    facets[index] = { ...facet, highValue: true };
    remaining -= 1;
  }
  return facets;
}

function propertyFacet(
  property: MiotProperty,
  service: MiotService,
  serviceName: string,
  deviceType: string,
  profiles: DeviceProfiles,
): MiotFacet | null {
  const name = miotShortName(property.type);
  if (property.format === "string") return null;
  const id = `${service.iid}.${property.iid}`;
  const title = nonEmpty(property.description);
  const unit = normalizedUnit(property.unit);
  if (property.access.includes("write")) {
    let kind: MiotFacetKind;
    let range: MiotFacetRange | undefined;
    let options: MiotFacetOption[] | undefined;
    if (property.format === "bool") {
      kind = "toggle";
    } else if (property.valueList && property.valueList.length > 0) {
      kind = "select";
      options = facetOptions(property.valueList);
    } else {
      range = facetRange(property.valueRange);
      if (!range) return null;
      kind = "slider";
    }
    const risk = riskFor(name, deviceType, profiles);
    return {
      id,
      kind,
      serviceId: service.iid,
      serviceName,
      propertyId: property.iid,
      name,
      ...(title ? { title } : {}),
      ...(unit ? { unit } : {}),
      ...(range ? { range } : {}),
      ...(options ? { options } : {}),
      isWritable: true,
      risk,
      writesByDefault: risk === "low",
      highValue: false,
    };
  }
  if (!property.access.includes("read")) return null;
  const options = facetOptions(property.valueList ?? []);
  const scale = explicitScale(property);
  return {
    id,
    kind: "reading",
    serviceId: service.iid,
    serviceName,
    propertyId: property.iid,
    name,
    ...(title ? { title } : {}),
    ...(unit ? { unit } : {}),
    ...(scale !== undefined ? { scale } : {}),
    ...(options ? { options } : {}),
    isWritable: false,
    risk: "low",
    writesByDefault: false,
    highValue: false,
  };
}

function actionFacet(
  action: MiotAction,
  service: MiotService,
  serviceName: string,
  deviceType: string,
  profiles: DeviceProfiles,
): MiotFacet | null {
  const arguments_: MiotFacetArgument[] = [];
  for (const inputId of action.in ?? []) {
    const input = service.properties.find((property) => property.iid === inputId);
    if (!input || matchesMiotFacetPattern(miotShortName(input.type), profiles.noise.properties)) return null;
    const options = facetOptions(input.valueList ?? []);
    const range = facetRange(input.valueRange);
    if (!options && !range) return null;
    arguments_.push({
      propertyId: input.iid,
      name: miotShortName(input.type),
      format: input.format,
      ...(range ? { range } : {}),
      ...(options ? { options } : {}),
    });
  }
  const name = miotShortName(action.type);
  const title = nonEmpty(action.description);
  const risk = riskFor(name, deviceType, profiles);
  return {
    id: `${service.iid}.a${action.iid}`,
    kind: "button",
    serviceId: service.iid,
    serviceName,
    actionId: action.iid,
    name,
    ...(title ? { title } : {}),
    ...(arguments_.length > 0 ? { arguments: arguments_ } : {}),
    isWritable: true,
    risk,
    writesByDefault: risk === "low",
    highValue: false,
  };
}

function riskFor(name: string, deviceType: string, profiles: DeviceProfiles): MiotFacetRisk {
  if (matchesMiotFacetPattern(deviceType, profiles.facets.highRiskTypes)) return "high";
  return matchesMiotFacetPattern(name, profiles.facets.lowRiskWrites) ? "low" : "high";
}

function facetOptions(list: readonly MiotValueListItem[]): MiotFacetOption[] | undefined {
  if (list.length === 0) return undefined;
  return list.map((item) => ({ value: item.value, label: item.description }));
}

function facetRange(raw?: readonly number[]): MiotFacetRange | undefined {
  if (!raw || raw.length < 2) return undefined;
  const [min, max, rawStep] = raw;
  if (min === undefined || max === undefined) return undefined;
  const step = rawStep !== undefined && rawStep > 0 ? rawStep : 1;
  return { min, max, step };
}

function normalizedUnit(raw?: string): string | undefined {
  const unit = nonEmpty(raw);
  if (!unit || unit.toLowerCase() === "none") return undefined;
  return unit;
}

function nonEmpty(raw?: string): string | undefined {
  const trimmed = raw?.trim();
  return trimmed ? trimmed : undefined;
}

/**
 * `0.01平方米` or `单位0.1升` in a spec comment is an explicit display scale, so the reading is
 * converted before it is shown. Ambiguous magnitudes never guess a factor.
 */
function explicitScale(property: MiotProperty): number | undefined {
  for (const raw of [property.unit, property.comment]) {
    if (!raw) continue;
    const text = raw.toLowerCase().replace(/ /g, "").replace(/：/g, ":");
    const direct = scaleNumberAtStart(text);
    if (direct !== undefined) return direct;
    const marker = text.indexOf("单位");
    if (marker >= 0) {
      let rest = text.slice(marker + 2);
      if (rest.startsWith(":")) rest = rest.slice(1);
      const value = scaleNumberAtStart(rest);
      if (value !== undefined) return value;
    }
  }
  return undefined;
}

function scaleNumberAtStart(text: string): number | undefined {
  if (!text.startsWith("0.")) return undefined;
  const match = /^0\.(\d+)/.exec(text);
  if (!match) return undefined;
  const value = Number(`0.${match[1]}`);
  return Number.isFinite(value) && value > 0 ? value : undefined;
}

/** Matches one short name against a noise or display pattern. Only `*` is special. */
export function matchesMiotFacetPattern(value: string, patterns: readonly string[]): boolean {
  return patterns.some((pattern) => matchesPattern(value, pattern));
}

function matchesPattern(value: string, pattern: string): boolean {
  const patternChars = Array.from(pattern);
  const valueChars = Array.from(value);
  let patternIndex = 0;
  let valueIndex = 0;
  let starIndex = -1;
  let starValueIndex = 0;
  while (valueIndex < valueChars.length) {
    if (patternIndex < patternChars.length && patternChars[patternIndex] === valueChars[valueIndex]) {
      patternIndex += 1;
      valueIndex += 1;
    } else if (patternIndex < patternChars.length && patternChars[patternIndex] === "*") {
      starIndex = patternIndex;
      starValueIndex = valueIndex;
      patternIndex += 1;
    } else if (starIndex >= 0) {
      patternIndex = starIndex + 1;
      starValueIndex += 1;
      valueIndex = starValueIndex;
    } else {
      return false;
    }
  }
  while (patternIndex < patternChars.length && patternChars[patternIndex] === "*") {
    patternIndex += 1;
  }
  return patternIndex === patternChars.length;
}

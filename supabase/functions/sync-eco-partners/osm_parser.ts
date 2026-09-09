export type OverpassElement = {
  type?: string;
  id?: string | number;
  lat?: number;
  lon?: number;
  center?: { lat?: number; lon?: number };
  timestamp?: string;
  tags?: Record<string, unknown>;
};

export type CatalogRow = Record<string, unknown> & {
  id: string;
  source_id: string;
  name: string;
  category: "dining" | "transport";
  subtype: string;
  latitude: number;
  longitude: number;
};

const text = (value: unknown): string | null => {
  const result = String(value ?? "").trim();
  return result && result.toLowerCase() !== "null" ? result : null;
};

const positiveInt = (value: unknown): number | null => {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

export function classifyDiet(tags: Record<string, unknown>): "Vegan" | "Vegetarian" | null {
  const vegan = text(tags["diet:vegan"])?.toLowerCase();
  const vegetarian = text(tags["diet:vegetarian"])?.toLowerCase();
  if (["only", "yes"].includes(vegan ?? "")) return "Vegan";
  if (["only", "yes"].includes(vegetarian ?? "")) return "Vegetarian";
  return null;
}

function address(tags: Record<string, unknown>): string {
  const full = text(tags["addr:full"]);
  if (full) return full;
  return [
    text(tags["addr:housenumber"]),
    text(tags["addr:street"]),
    text(tags["addr:suburb"]),
    text(tags["addr:city"]),
    text(tags["addr:postcode"]),
  ].filter(Boolean).join(", ");
}

function chargingDetails(tags: Record<string, unknown>) {
  const connectors = new Map<string, { type: string; count?: number; output?: string }>();
  for (const [key, rawValue] of Object.entries(tags)) {
    if (!key.startsWith("socket:")) continue;
    const [type, detail] = key.slice("socket:".length).split(":");
    if (!type) continue;
    const value = text(rawValue);
    if (!value || value.toLowerCase() === "no") continue;
    const connector = connectors.get(type) ?? { type };
    if (detail === "output") connector.output = value;
    else connector.count = positiveInt(value) ?? undefined;
    connectors.set(type, connector);
  }
  const value = {
    capacity: positiveInt(tags.capacity),
    access: text(tags.access),
    operatorName: text(tags.operator),
    connectors: [...connectors.values()],
  };
  return value.capacity || value.access || value.operatorName || value.connectors.length
    ? value
    : null;
}

function sourceUrl(element: OverpassElement): string {
  return `https://www.openstreetmap.org/${element.type}/${element.id}`;
}

export function parseOverpassElements(elements: OverpassElement[]): CatalogRow[] {
  const rows = new Map<string, CatalogRow>();
  for (const element of elements) {
    const type = text(element.type);
    const elementId = text(element.id);
    const tags = element.tags ?? {};
    const latitude = element.lat ?? element.center?.lat;
    const longitude = element.lon ?? element.center?.lon;
    if (!type || !elementId || !Number.isFinite(latitude) || !Number.isFinite(longitude)) continue;

    const sourceId = `${type}:${elementId}`;
    const id = `osm:${sourceId}`;
    const amenity = text(tags.amenity)?.toLowerCase();
    if (amenity === "charging_station") {
      const operator = text(tags.operator);
      const location = address(tags);
      const name = text(tags.name) ?? (operator ? `${operator} EV charger` : location ? `EV charger near ${location.split(",")[0]}` : "EV charging station");
      rows.set(id, {
        id,
        source_id: sourceId,
        name,
        category: "transport",
        subtype: "EV charging",
        address: location,
        latitude: latitude as number,
        longitude: longitude as number,
        sustainability_label: "Electric vehicle charging",
        evidence: "Listed as an electric vehicle charging station.",
        source_name: "OpenStreetMap contributors",
        source_url: sourceUrl(element),
        source_updated_at: element.timestamp ?? new Date().toISOString(),
        website: text(tags.website),
        charging_details: chargingDetails(tags),
      });
      continue;
    }

    const diet = classifyDiet(tags);
    if (!["restaurant", "cafe"].includes(amenity ?? "") || !diet) continue;
    const name = text(tags.name);
    if (!name) continue;
    rows.set(id, {
      id,
      source_id: sourceId,
      name,
      category: "dining",
      subtype: amenity === "cafe" ? "Cafe" : "Restaurant",
      address: address(tags),
      latitude: latitude as number,
      longitude: longitude as number,
      sustainability_label: `${diet}-friendly dining`,
      evidence: diet === "Vegan"
        ? "Listed as vegan-friendly."
        : "Listed as vegetarian-friendly.",
      source_name: "OpenStreetMap contributors",
      source_url: sourceUrl(element),
      source_updated_at: element.timestamp ?? new Date().toISOString(),
      website: text(tags.website),
      vegan_classification: diet,
    });
  }
  return [...rows.values()];
}

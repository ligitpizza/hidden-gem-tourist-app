const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type PartnerInput = {
  id: string;
  latitude: number;
  longitude: number;
};

type MapillaryRow = {
  id?: string;
  geometry?: { coordinates?: unknown[] };
  captured_at?: number;
  thumb_1024_url?: string;
};

const radiusKm = 0.1;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const token = Deno.env.get("MAPILLARY_ACCESS_TOKEN")?.trim();
  if (!token) {
    return json({ error: "Mapillary is not configured." }, 503);
  }

  let body: { partners?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  if (!Array.isArray(body.partners)) {
    return json({ error: "partners must be an array." }, 400);
  }

  const partners = body.partners
    .slice(0, 24)
    .map(parsePartner)
    .filter((partner): partner is PartnerInput => partner !== null);
  if (partners.length === 0) return json({ images: [] });

  const images = await Promise.all(partners.map((partner) => nearestImage(partner, token)));
  return json({ images: images.filter((image) => image !== null) });
});

function parsePartner(value: unknown): PartnerInput | null {
  if (!value || typeof value !== "object") return null;
  const row = value as Record<string, unknown>;
  const id = typeof row.id === "string" ? row.id.trim() : "";
  const latitude = Number(row.latitude);
  const longitude = Number(row.longitude);
  if (
    !id ||
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) return null;
  return { id, latitude, longitude };
}

async function nearestImage(partner: PartnerInput, token: string) {
  const latitudeDelta = radiusKm / 111.32;
  const longitudeDelta =
    radiusKm / (111.32 * Math.max(Math.cos(partner.latitude * Math.PI / 180), 0.01));
  const bbox = [
    partner.longitude - longitudeDelta,
    partner.latitude - latitudeDelta,
    partner.longitude + longitudeDelta,
    partner.latitude + latitudeDelta,
  ].join(",");
  const url = new URL("https://graph.mapillary.com/images");
  url.searchParams.set("bbox", bbox);
  url.searchParams.set("fields", "id,geometry,captured_at,thumb_1024_url");
  url.searchParams.set("limit", "10");

  try {
    const response = await fetch(url, {
      headers: { Authorization: `OAuth ${token}` },
      signal: AbortSignal.timeout(3500),
    });
    if (!response.ok) return null;
    const payload = await response.json() as { data?: MapillaryRow[] };
    let best: MapillaryRow | null = null;
    let bestDistance = Number.POSITIVE_INFINITY;
    for (const row of payload.data ?? []) {
      const coordinates = row.geometry?.coordinates;
      if (!Array.isArray(coordinates) || coordinates.length < 2) continue;
      const longitude = Number(coordinates[0]);
      const latitude = Number(coordinates[1]);
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) continue;
      const distance = distanceKm(
        partner.latitude,
        partner.longitude,
        latitude,
        longitude,
      );
      if (distance < bestDistance) {
        best = row;
        bestDistance = distance;
      }
    }
    if (!best?.id || !best.thumb_1024_url || bestDistance > radiusKm) return null;
    return {
      id: partner.id,
      imageUrl: best.thumb_1024_url,
      sourceUrl: `https://www.mapillary.com/app/?pKey=${encodeURIComponent(best.id)}&focus=photo`,
      capturedAt: typeof best.captured_at === "number"
        ? new Date(best.captured_at).toISOString()
        : null,
    };
  } catch {
    return null;
  }
}

function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number) {
  const radians = (value: number) => value * Math.PI / 180;
  const dLat = radians(lat2 - lat1);
  const dLon = radians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

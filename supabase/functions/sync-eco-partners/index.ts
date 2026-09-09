import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { cacheMapillaryMetadata, cacheWikimediaMetadata } from "./image_metadata.ts";
import { parseOverpassElements, type OverpassElement } from "./osm_parser.ts";

const mirrors = [
  "https://overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
  "https://overpass.private.coffee/api/interpreter",
];

async function loadState(isoCode: string): Promise<OverpassElement[]> {
  const query = `[out:json][timeout:60];
area["ISO3166-2"="${isoCode}"][boundary="administrative"]->.searchArea;
(
  nwr(area.searchArea)["amenity"~"restaurant|cafe"]["diet:vegan"~"^(yes|only)$",i];
  nwr(area.searchArea)["amenity"~"restaurant|cafe"]["diet:vegetarian"~"^(yes|only)$",i];
  nwr(area.searchArea)["amenity"="charging_station"];
);
out center tags meta;`;
  let lastError: unknown;
  for (const mirror of mirrors) {
    try {
      const response = await fetch(mirror, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded", "user-agent": "HiddenGemTouristApp/1.0 (scheduled Eco Partner sync)" },
        body: new URLSearchParams({ data: query }),
        signal: AbortSignal.timeout(70000),
      });
      if (!response.ok) throw new Error(`${mirror} returned HTTP ${response.status}`);
      const body = await response.json();
      if (!Array.isArray(body?.elements)) throw new Error(`${mirror} returned malformed data`);
      return body.elements as OverpassElement[];
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? new Error("No Overpass mirror was available");
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  const expectedSecret = Deno.env.get("SYNC_ECO_PARTNERS_SECRET");
  if (!expectedSecret || request.headers.get("x-sync-secret") !== expectedSecret) {
    return new Response("Unauthorized", { status: 401 });
  }
  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: regions, error: claimError } = await client.rpc("claim_eco_partner_sync_region");
  if (claimError) return Response.json({ error: claimError.message }, { status: 500 });
  const region = regions?.[0] as { state: string; iso_code: string } | undefined;
  if (!region) return Response.json({ status: "idle" });

  try {
    const elements = await loadState(region.iso_code);
    const parsed = parseOverpassElements(elements);
    const wikimediaRows = await cacheWikimediaMetadata(parsed);
    const rows = await cacheMapillaryMetadata(
      wikimediaRows,
      Deno.env.get("MAPILLARY_ACCESS_TOKEN")?.trim(),
    );
    const { data: count, error: replaceError } = await client.rpc("replace_eco_partner_region", {
      p_source: "osm",
      p_state: region.state,
      p_rows: rows,
    });
    if (replaceError) throw replaceError;
    const { error: statusError } = await client
      .from("eco_partner_sync_regions")
      .update({
        status: "success",
        last_success_at: new Date().toISOString(),
        next_sync_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        error: null,
      })
      .eq("state", region.state);
    if (statusError) throw statusError;
    return Response.json({ status: "success", state: region.state, partners: count });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await client
      .from("eco_partner_sync_regions")
      .update({
        status: "failed",
        next_sync_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        error: message.slice(0, 2000),
      })
      .eq("state", region.state);
    return Response.json({ status: "failed", state: region.state, error: message }, { status: 502 });
  }
});

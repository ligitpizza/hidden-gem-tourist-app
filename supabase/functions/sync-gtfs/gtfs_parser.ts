import { parse } from "npm:csv-parse@5.5.6/sync";
import { unzipSync } from "npm:fflate@0.8.2";

const decoder = new TextDecoder();
const rows = (files: Record<string, Uint8Array>, name: string) =>
  files[name] ? parse(decoder.decode(files[name]), { columns: true, skip_empty_lines: true, bom: true }) : [];

export function transportMode(route: Record<string, string>): string {
  const name = `${route.route_short_name ?? ""} ${route.route_long_name ?? ""}`.toLowerCase();
  if (name.includes("monorail")) return "Monorail";
  if (name.includes("mrt")) return "MRT";
  if (name.includes("lrt")) return "LRT";
  if (name.includes("ktm")) return "KTM";
  if (route.route_type === "0") return "Light rail";
  if (route.route_type === "1" || route.route_type === "2") return "Rail";
  return "Bus";
}

export function parseGtfs(zip: Uint8Array, feedId: string, sourceUrl: string) {
  const files = unzipSync(zip);
  const agencies = rows(files, "agency.txt").map((a: Record<string, string>) => ({ id: `${feedId}:${a.agency_id || "default"}`, feed_id: feedId, agency_id: a.agency_id || "default", name: a.agency_name, url: a.agency_url || null, timezone: a.agency_timezone || null }));
  const stops = rows(files, "stops.txt").filter((s: Record<string, string>) => s.stop_lat && s.stop_lon).map((s: Record<string, string>) => ({ id: `${feedId}:${s.stop_id}`, feed_id: feedId, stop_id: s.stop_id, name: s.stop_name, address: s.stop_desc || "", latitude: Number(s.stop_lat), longitude: Number(s.stop_lon), source_name: "Official Malaysia GTFS", source_url: sourceUrl }));
  const routesRaw = rows(files, "routes.txt") as Record<string, string>[];
  const routes = routesRaw.map(r => ({ id: `${feedId}:${r.route_id}`, feed_id: feedId, route_id: r.route_id, agency_id: r.agency_id || null, short_name: r.route_short_name || null, long_name: r.route_long_name || null, route_type: Number(r.route_type), mode: transportMode(r) }));
  const tripRoutes = new Map((rows(files, "trips.txt") as Record<string, string>[]).map(t => [t.trip_id, t.route_id]));
  const pairs = new Set<string>();
  for (const st of rows(files, "stop_times.txt") as Record<string, string>[]) {
    const route = tripRoutes.get(st.trip_id);
    if (route) pairs.add(`${feedId}:${st.stop_id}\u0000${feedId}:${route}`);
  }
  const stop_routes = [...pairs].map(pair => { const [stop_id, route_id] = pair.split("\u0000"); return { stop_id, route_id }; });
  return { agencies, stops, routes, stop_routes };
}

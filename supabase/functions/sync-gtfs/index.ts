import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { parseGtfs } from "./gtfs_parser.ts";

const feeds = [
  ["ktmb", "https://api.data.gov.my/gtfs-static/ktmb"],
  ...["rapid-rail-kl", "rapid-bus-kl", "rapid-bus-mrtfeeder", "rapid-bus-penang", "rapid-bus-kuantan"].map(c => [`prasarana-${c}`, `https://api.data.gov.my/gtfs-static/prasarana?category=${c}`]),
  ...["mybas-kangar", "mybas-alor-setar", "mybas-kota-bharu", "mybas-kuala-terengganu", "mybas-ipoh", "mybas-seremban-a", "mybas-seremban-b", "mybas-melaka", "mybas-johor", "mybas-kuching"].map(c => [c, `https://api.data.gov.my/gtfs-static/${c}`]),
] as const;

Deno.serve(async req => {
  const secret = Deno.env.get("SYNC_GTFS_SECRET");
  if (!secret || req.headers.get("x-sync-secret") !== secret) return new Response("Unauthorized", { status: 401 });
  const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const results = [];
  for (const [feedId, url] of feeds) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const parsed = parseGtfs(new Uint8Array(await response.arrayBuffer()), feedId, url);
      const { error } = await client.rpc("replace_gtfs_feed", { p_feed_id: feedId, p_source_url: url, p_agencies: parsed.agencies, p_stops: parsed.stops, p_routes: parsed.routes, p_stop_routes: parsed.stop_routes });
      if (error) throw error;
      results.push({ feedId, status: "success", stops: parsed.stops.length });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      await client.from("gtfs_feed_status").upsert({ feed_id: feedId, source_url: url, status: "failed", last_attempt_at: new Date().toISOString(), error: message }, { onConflict: "feed_id" });
      results.push({ feedId, status: "failed", error: message });
    }
  }
  return Response.json({ results });
});

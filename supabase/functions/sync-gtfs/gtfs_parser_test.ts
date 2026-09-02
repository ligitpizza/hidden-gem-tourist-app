import { assertEquals } from "jsr:@std/assert@1";
import { zipSync } from "npm:fflate@0.8.2";
import { parseGtfs, transportMode } from "./gtfs_parser.ts";

Deno.test("prioritises named Malaysian rail modes", () => {
  assertEquals(transportMode({ route_long_name: "KL Monorail Line", route_type: "0" }), "Monorail");
  assertEquals(transportMode({ route_short_name: "MRT Kajang", route_type: "1" }), "MRT");
  assertEquals(transportMode({ route_long_name: "Kelana Jaya LRT", route_type: "1" }), "LRT");
  assertEquals(transportMode({ route_long_name: "KTM Komuter", route_type: "2" }), "KTM");
  assertEquals(transportMode({ route_long_name: "T10", route_type: "3" }), "Bus");
});

Deno.test("uses the stop name as a location when GTFS omits stop_desc", () => {
  const encoder = new TextEncoder();
  const zip = zipSync({
    "stops.txt": encoder.encode(
      "stop_id,stop_name,stop_desc,stop_lat,stop_lon\n1,Bukit Bintang MRT,,3.146,101.711\n",
    ),
  });

  const result = parseGtfs(zip, "test", "https://example.com/feed.zip");

  assertEquals(result.stops[0].address, "Bukit Bintang MRT, Malaysia");
});

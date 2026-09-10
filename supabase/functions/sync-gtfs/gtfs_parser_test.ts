import { assertEquals } from "jsr:@std/assert@1";
import { zipSync } from "npm:fflate@0.8.2";
import { parseGtfs, transportMode } from "./gtfs_parser.ts";

Deno.test("prioritises named Malaysian rail modes", () => {
  assertEquals(
    transportMode({ route_long_name: "KL Monorail Line", route_type: "0" }),
    "Monorail",
  );
  assertEquals(
    transportMode({ route_short_name: "MRT Kajang", route_type: "1" }),
    "MRT",
  );
  assertEquals(
    transportMode({ route_long_name: "Kelana Jaya LRT", route_type: "1" }),
    "LRT",
  );
  assertEquals(
    transportMode({ route_long_name: "KTM Komuter", route_type: "2" }),
    "KTM",
  );
  assertEquals(
    transportMode({ route_long_name: "T10", route_type: "3" }),
    "Bus",
  );
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

Deno.test("omits oversized stop-time route links without losing stops", () => {
  const encoder = new TextEncoder();
  const zip = zipSync({
    "stops.txt": encoder.encode(
      "stop_id,stop_name,stop_desc,stop_lat,stop_lon\n1,Penang bus stop,,5.414,100.329\n",
    ),
    "routes.txt": encoder.encode(
      "route_id,route_short_name,route_long_name,route_type\nr1,101,Penang bus,3\n",
    ),
    "trips.txt": encoder.encode("route_id,trip_id\nr1,t1\n"),
    "stop_times.txt": encoder.encode(
      "trip_id,arrival_time,departure_time,stop_id,stop_sequence\nt1,08:00:00,08:00:00,1,1\n",
    ),
  });

  const result = parseGtfs(
    zip,
    "prasarana-rapid-bus-penang",
    "https://example.com/penang.zip",
    { maxStopTimesBytes: 1 },
  );

  assertEquals(result.stops.length, 1);
  assertEquals(result.routes.length, 1);
  assertEquals(result.stop_routes, []);
  assertEquals(result.stopRoutesOmitted, true);
});

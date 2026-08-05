import { assertEquals } from "jsr:@std/assert@1";
import { transportMode } from "./gtfs_parser.ts";

Deno.test("prioritises named Malaysian rail modes", () => {
  assertEquals(transportMode({ route_long_name: "KL Monorail Line", route_type: "0" }), "Monorail");
  assertEquals(transportMode({ route_short_name: "MRT Kajang", route_type: "1" }), "MRT");
  assertEquals(transportMode({ route_long_name: "Kelana Jaya LRT", route_type: "1" }), "LRT");
  assertEquals(transportMode({ route_long_name: "KTM Komuter", route_type: "2" }), "KTM");
  assertEquals(transportMode({ route_long_name: "T10", route_type: "3" }), "Bus");
});

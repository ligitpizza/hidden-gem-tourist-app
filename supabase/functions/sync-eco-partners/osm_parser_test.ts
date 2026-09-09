import { assertEquals } from "jsr:@std/assert@1";
import { classifyDiet, parseOverpassElements } from "./osm_parser.ts";

Deno.test("classifies explicit vegan and vegetarian tags", () => {
  assertEquals(classifyDiet({ "diet:vegan": "yes" }), "Vegan");
  assertEquals(classifyDiet({ "diet:vegetarian": "only" }), "Vegetarian");
  assertEquals(classifyDiet({ cuisine: "salad" }), null);
});

Deno.test("maps restaurants and chargers to stable catalogue rows", () => {
  const rows = parseOverpassElements([
    {
      type: "node",
      id: 10,
      lat: 3.14,
      lon: 101.7,
      tags: { amenity: "restaurant", name: "Green Table", "diet:vegan": "yes" },
    },
    {
      type: "way",
      id: 20,
      center: { lat: 3.15, lon: 101.71 },
      tags: { amenity: "charging_station", operator: "ChargeCo", capacity: "4", "socket:type2": "2" },
    },
  ]);
  assertEquals(rows.length, 2);
  assertEquals(rows[0].id, "osm:node:10");
  assertEquals(rows[0].category, "dining");
  assertEquals(rows[0].evidence, "Listed as vegan-friendly.");
  assertEquals(rows[1].name, "ChargeCo EV charger");
  assertEquals(rows[1].subtype, "EV charging");
  assertEquals(rows[1].evidence, "Listed as an electric vehicle charging station.");
  assertEquals(rows[1].charging_details, {
    capacity: 4,
    access: null,
    operatorName: "ChargeCo",
    connectors: [{ type: "type2", count: 2 }],
  });
});

Deno.test("ignores malformed and untagged elements", () => {
  assertEquals(parseOverpassElements([
    { type: "node", id: 1, tags: { amenity: "restaurant", "diet:vegan": "yes" } },
    { type: "node", id: 2, lat: 1, lon: 2, tags: { amenity: "restaurant", name: "Ordinary" } },
  ]), []);
});

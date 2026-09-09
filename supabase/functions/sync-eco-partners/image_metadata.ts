import type { CatalogRow } from "./osm_parser.ts";

type WikimediaPage = {
  title?: string;
  missing?: boolean;
  pageimage?: string;
  thumbnail?: { source?: string };
};

const normalize = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();

export async function cacheWikimediaMetadata(rows: CatalogRow[]): Promise<CatalogRow[]> {
  const candidates = rows.filter((row) => row.category === "dining").slice(0, 24);
  if (!candidates.length) return rows;
  try {
    const titleUrl = new URL("https://en.wikipedia.org/w/api.php");
    titleUrl.search = new URLSearchParams({
      action: "query",
      format: "json",
      formatversion: "2",
      redirects: "1",
      titles: candidates.map((row) => row.name.replaceAll("|", " ")).join("|"),
      prop: "pageimages",
      piprop: "thumbnail|name",
      pithumbsize: "1200",
      origin: "*",
    }).toString();
    const titleResponse = await fetch(titleUrl, { signal: AbortSignal.timeout(8000) });
    if (!titleResponse.ok) return rows;
    const titleBody = await titleResponse.json();
    const pages = (titleBody?.query?.pages ?? []) as WikimediaPage[];
    const pagesByTitle = new Map(pages.filter((p) => !p.missing).map((p) => [normalize(p.title ?? ""), p]));
    const fileToRows = new Map<string, CatalogRow[]>();
    const fileTitles: string[] = [];
    for (const row of candidates) {
      const page = pagesByTitle.get(normalize(row.name));
      if (!page?.pageimage || !page.thumbnail?.source) continue;
      const file = page.pageimage.startsWith("File:") ? page.pageimage : `File:${page.pageimage}`;
      const fileKey = normalize(file);
      const values = fileToRows.get(fileKey) ?? [];
      values.push(row);
      fileToRows.set(fileKey, values);
      fileTitles.push(file);
    }
    if (!fileToRows.size) return rows;

    const commonsUrl = new URL("https://commons.wikimedia.org/w/api.php");
    commonsUrl.search = new URLSearchParams({
      action: "query",
      format: "json",
      formatversion: "2",
      titles: fileTitles.join("|"),
      prop: "imageinfo",
      iiprop: "extmetadata|url",
      origin: "*",
    }).toString();
    const commonsResponse = await fetch(commonsUrl, { signal: AbortSignal.timeout(8000) });
    if (!commonsResponse.ok) return rows;
    const commonsBody = await commonsResponse.json();
    const replacements = new Map<string, CatalogRow>();
    for (const page of commonsBody?.query?.pages ?? []) {
      const matches = fileToRows.get(normalize(page.title ?? ""));
      const info = page.imageinfo?.[0];
      const metadata = info?.extmetadata;
      if (!matches || !metadata) continue;
      const artist = String(metadata.Artist?.value ?? "").replace(/<[^>]+>/g, "").trim();
      const license = String(metadata.LicenseShortName?.value ?? "").trim();
      const sourceUrl = String(info.descriptionurl ?? "").trim();
      if (!artist || !license || !sourceUrl) continue;
      for (const row of matches) {
        const wikiPage = pagesByTitle.get(normalize(row.name));
        replacements.set(row.id, {
          ...row,
          image_url: wikiPage?.thumbnail?.source,
          image_source_name: `Photo: ${artist} · ${license} · Wikimedia Commons`,
          image_source_url: sourceUrl,
        });
      }
    }
    return rows.map((row) => replacements.get(row.id) ?? row);
  } catch {
    return rows;
  }
}

type MapillaryRow = {
  id?: string;
  geometry?: { coordinates?: unknown[] };
  captured_at?: number;
  thumb_1024_url?: string;
};

export async function cacheMapillaryMetadata(
  rows: CatalogRow[],
  token: string | undefined,
): Promise<CatalogRow[]> {
  if (!token) return rows;
  const replacements = new Map<string, CatalogRow>();
  const candidates = rows.filter((row) => !row.image_url).slice(0, 16);
  await Promise.all(candidates.map(async (row) => {
    const latitude = Number(row.latitude);
    const longitude = Number(row.longitude);
    const latitudeDelta = 0.1 / 111.32;
    const longitudeDelta = 0.1 / (111.32 * Math.max(Math.cos(latitude * Math.PI / 180), 0.01));
    const url = new URL("https://graph.mapillary.com/images");
    url.searchParams.set("bbox", [
      longitude - longitudeDelta,
      latitude - latitudeDelta,
      longitude + longitudeDelta,
      latitude + latitudeDelta,
    ].join(","));
    url.searchParams.set("fields", "id,geometry,captured_at,thumb_1024_url");
    url.searchParams.set("limit", "10");
    try {
      const response = await fetch(url, {
        headers: { authorization: `OAuth ${token}` },
        signal: AbortSignal.timeout(5000),
      });
      if (!response.ok) return;
      const payload = await response.json() as { data?: MapillaryRow[] };
      let best: MapillaryRow | undefined;
      let bestDistance = Number.POSITIVE_INFINITY;
      for (const image of payload.data ?? []) {
        const coordinates = image.geometry?.coordinates;
        if (!Array.isArray(coordinates) || coordinates.length < 2) continue;
        const candidateDistance = distanceKm(
          latitude,
          longitude,
          Number(coordinates[1]),
          Number(coordinates[0]),
        );
        if (candidateDistance < bestDistance) {
          best = image;
          bestDistance = candidateDistance;
        }
      }
      if (!best?.id || !best.thumb_1024_url || bestDistance > 0.1) return;
      replacements.set(row.id, {
        ...row,
        image_url: best.thumb_1024_url,
        image_source_name: "Nearby street-level image · Mapillary",
        image_source_url: `https://www.mapillary.com/app/?pKey=${encodeURIComponent(best.id)}&focus=photo`,
        image_captured_at: typeof best.captured_at === "number"
          ? new Date(best.captured_at).toISOString()
          : undefined,
      });
    } catch {
      // Image metadata is optional and never fails the partner sync.
    }
  }));
  return rows.map((row) => replacements.get(row.id) ?? row);
}

function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number) {
  const radians = (value: number) => value * Math.PI / 180;
  const dLat = radians(lat2 - lat1);
  const dLon = radians(lon2 - lon1);
  const value = Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
}

import type { CatalogRow } from "./osm_parser.ts";

type WikimediaPage = {
  title?: string;
  missing?: boolean;
  pageimage?: string;
  thumbnail?: { source?: string };
};

const normalize = (value: string) =>
  value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();

export async function cacheWikimediaMetadata(
  rows: CatalogRow[],
): Promise<CatalogRow[]> {
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
    const titleResponse = await fetch(titleUrl, {
      signal: AbortSignal.timeout(8000),
    });
    if (!titleResponse.ok) return rows;
    const titleBody = await titleResponse.json();
    const pages = (titleBody?.query?.pages ?? []) as WikimediaPage[];
    const pagesByTitle = new Map(
      pages.filter((page) => !page.missing).map((page) => [
        normalize(page.title ?? ""),
        page,
      ]),
    );
    const fileToRows = new Map<string, CatalogRow[]>();
    const fileTitles: string[] = [];
    for (const row of candidates) {
      const page = pagesByTitle.get(normalize(row.name));
      if (!page?.pageimage || !page.thumbnail?.source) continue;
      const file = page.pageimage.startsWith("File:")
        ? page.pageimage
        : `File:${page.pageimage}`;
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
    const commonsResponse = await fetch(commonsUrl, {
      signal: AbortSignal.timeout(8000),
    });
    if (!commonsResponse.ok) return rows;
    const commonsBody = await commonsResponse.json();
    const replacements = new Map<string, CatalogRow>();
    for (const page of commonsBody?.query?.pages ?? []) {
      const matches = fileToRows.get(normalize(page.title ?? ""));
      const info = page.imageinfo?.[0];
      const metadata = info?.extmetadata;
      if (!matches || !metadata) continue;
      const artist = String(metadata.Artist?.value ?? "")
        .replace(/<[^>]+>/g, "")
        .trim();
      const license = String(metadata.LicenseShortName?.value ?? "").trim();
      const sourceUrl = String(info.descriptionurl ?? "").trim();
      if (!artist || !license || !sourceUrl) continue;
      for (const row of matches) {
        const wikiPage = pagesByTitle.get(normalize(row.name));
        replacements.set(row.id, {
          ...row,
          image_url: wikiPage?.thumbnail?.source,
          image_source_name:
            `Photo: ${artist} · ${license} · Wikimedia Commons`,
          image_source_url: sourceUrl,
        });
      }
    }
    return rows.map((row) => replacements.get(row.id) ?? row);
  } catch {
    return rows;
  }
}

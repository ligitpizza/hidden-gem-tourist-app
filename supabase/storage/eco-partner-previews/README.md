# Eco Partner transport previews

The `transport/` directory contains all nine upload-ready WebP objects. Each
file is 1200 x 675 and below the bucket's 300 KB limit.

For a Dashboard-only deployment:

1. Open **Storage**, create a public bucket named `eco-partner-previews`, set
   the file limit to 300 KB, and allow `image/webp`. You may skip this step if
   the SQL migration has already created the bucket.
2. Open that bucket, create the `transport` folder, and upload all nine files
   from this repository's `transport/` directory without renaming them.
3. Run `20260909190000_stable_transport_preview_images.sql` in the SQL Editor.
   It safely reuses the bucket, installs the mapping table and trigger, clears
   old street-level metadata, and backfills every active GTFS partner.
4. Redeploy `sync-eco-partners`. Its source no longer requires or calls the
   former street-level image provider.

Application users can read objects because the bucket is public. There is no
client upload policy, so writes remain limited to trusted backend access and
Dashboard administrators.

The images are cropped/compressed derivatives of their linked Wikimedia
Commons source files. Keep the accompanying `ATTRIBUTION.md` with the project.

# Eco Partner previews

This directory contains upload-ready WebP objects for Eco Partner cards:

- `transport/`: 21 operator/mode previews, providing three visual variants
  for each displayed transport mode
- `dining/`: eight plant-friendly dining previews
- `ev/`: eight electric-vehicle charging previews

Every file is 1200 x 675 and below the bucket's 300 KB limit.

For a Dashboard-only deployment:

1. Open **Storage**, create a public bucket named `eco-partner-previews`, set
   the file limit to 300 KB, and allow `image/webp`. You may skip this step if
   the SQL migration has already created the bucket.
2. Open that bucket and create the `transport`, `dining`, and `ev` folders.
   Upload each repository folder's files to the matching Storage folder
   without renaming them.
3. Run `20260909190000_stable_transport_preview_images.sql` in the SQL Editor
   if the transport mapping is not deployed yet.
4. Run `20260910100000_add_dining_ev_preview_images.sql` in the SQL Editor. It
   registers the new photos, assigns one deterministically from each partner
   ID, backfills existing dining/EV rows, and keeps future synced rows mapped.
5. Run `20260910110000_expand_eco_partner_preview_images.sql`. It registers the
   extra photos and redistributes existing partners deterministically across
   three transport-mode or eight dining/EV variants.
6. Redeploy `sync-eco-partners` if the provider-removal update has not already
   been deployed. It no longer contacts any image provider.

Application users can read objects because the bucket is public. There is no
client upload policy, so writes remain limited to trusted backend access and
Dashboard administrators.

The images are cropped/compressed derivatives of their linked Wikimedia
Commons or Pexels source files. Keep the accompanying `ATTRIBUTION.md` with
the project.

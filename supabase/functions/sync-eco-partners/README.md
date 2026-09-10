# Eco Partner synchronisation

`sync-eco-partners` claims one due Malaysian state, fetches dining and EV data
from OpenStreetMap, and atomically replaces that state's OSM catalogue rows. A
failed fetch preserves the last successful rows and is retried after one hour.

Before enabling the ten-minute database schedule:

1. Deploy with JWT verification disabled; requests are authenticated by the
   `x-sync-secret` header.
2. Set the Edge Function secret `SYNC_ECO_PARTNERS_SECRET`.
3. Enable the `pg_cron` and `pg_net` extensions.
4. Create Vault secrets named `eco_partner_sync_url` (the full function URL)
   and `eco_partner_sync_secret` (the same secret value).
5. If `pg_cron` was enabled after the migration, schedule
   `select public.invoke_eco_partner_sync()` with `*/10 * * * *`.

The function uses the standard `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` environment variables supplied by Supabase.

Transport, dining, and EV previews are deterministic licensed images served
from Supabase Storage. They are assigned by database triggers and are not part
of this external data synchronization. The function does not contact an image
provider.

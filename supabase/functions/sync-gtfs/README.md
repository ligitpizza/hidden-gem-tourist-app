# GTFS synchronisation

Deploy `sync-gtfs`, set `SYNC_GTFS_SECRET`, and invoke it daily after Malaysia's
official feeds refresh (for example 04:30 Asia/Kuala_Lumpur). Send the secret in
the `x-sync-secret` header. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are
provided as server-side secrets; neither belongs in the Flutter application.

The ZIP is completely downloaded and parsed before the transactional
`replace_gtfs_feed` RPC runs. A failed feed records its status but preserves its
last successful stop and route dataset.

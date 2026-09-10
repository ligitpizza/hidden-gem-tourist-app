# GTFS synchronisation

Deploy `sync-gtfs`, set `SYNC_GTFS_SECRET`, and invoke it daily after Malaysia's
official feeds refresh (for example 04:30 Asia/Kuala_Lumpur). Send the secret in
the `x-sync-secret` header. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are
provided as server-side secrets; neither belongs in the Flutter application.

The ZIP is completely downloaded and parsed before the transactional
`replace_gtfs_feed` RPC runs. A failed feed records its status but preserves its
last successful stop and route dataset.

Large bus timetables can expand far beyond the Edge Function memory and CPU
limits. When `stop_times.txt` exceeds 8 MB, the parser imports all stops and
route definitions but omits the stop-to-route links. Those stops remain
available in Nearby and state searches and the general public-transit planner
still works; only the optional scheduled-route chips are unavailable for that
feed. Smaller feeds retain their exact route chips.

The function also imports the 16 official state boundaries from the Department
of Statistics Malaysia when the boundary table is empty. Importing the boundary
payload immediately repairs the `state` value of existing GTFS catalogue rows.
Future GTFS replacements assign state by stop coordinates, with feed-name
fallbacks only for feeds that are confined to one state.

When deploying from the Supabase website, run the
`20260909160000_gtfs_transport_state_boundaries.sql` migration in SQL Editor
first, then replace the deployed `sync-gtfs/index.ts` with this version and
invoke it once. The migration must exist before the function can import the
boundaries.

If the Dashboard test invocation is unavailable, enable the `http` database
extension and run the following from SQL Editor to perform the same one-time
boundary import and GTFS state repair without invoking the Edge Function:

```sql
with downloaded as (
  select status, content
  from extensions.http_get(
    'https://raw.githubusercontent.com/dosm-malaysia/data-open/main/datasets/geodata/administrative_1_state.geojson'
  )
)
select public.replace_malaysia_state_boundaries(content::jsonb)
from downloaded
where status = 200;
```

For future Edge Function tests, the value of the `x-sync-secret` request header
must exactly match the `SYNC_GTFS_SECRET` project secret. JWT verification must
also be disabled for this function because it uses the custom secret for
service-to-service authentication.

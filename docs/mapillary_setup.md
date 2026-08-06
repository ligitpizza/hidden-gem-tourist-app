# Mapillary recommendation previews

Mapillary access is proxied through the authenticated Supabase Edge Function
`mapillary-images`. The token must not be included in the Flutter application.

## Supabase setup

1. In the Supabase dashboard, add an Edge Function secret named
   `MAPILLARY_ACCESS_TOKEN` containing the Mapillary client token.
2. Deploy the function:

```powershell
npx supabase functions deploy mapillary-images --project-ref oeelhfvbxtrmvejllwjy --use-api
```

Flutter can then be run normally:

```powershell
flutter run
```

The app sends at most 12 Dining and 12 Transport locations to the function per
recommendation search. The function looks within 100 metres, returns the nearest
available street-level image, and never returns the access token. If no nearby
Mapillary coverage is available, the OSM map preview remains visible.

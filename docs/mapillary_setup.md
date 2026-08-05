# Mapillary transport previews

1. Create a Mapillary developer application and copy its client access token.
2. Run Flutter without committing that token:

```powershell
flutter run -d windows --dart-define=MAPILLARY_ACCESS_TOKEN=YOUR_CLIENT_TOKEN
```

For a release build:

```powershell
flutter build windows --dart-define=MAPILLARY_ACCESS_TOKEN=YOUR_CLIENT_TOKEN
```

The app requests up to 12 transport previews per recommendation search. It
looks within 100 metres, chooses the nearest image, displays its capture year,
and links to Mapillary. When no token or nearby coverage is available, the OSM
map preview remains visible.

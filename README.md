Maps Search v3 - updates:
- No auto-zoom on search/tap (keeps current zoom)
- Safe location detection (timeouts and permission checks)
- Stylized flat blue marker at assets/marker.png
- Works on Web / Android / iOS
- API key inserted (you provided it)

How to run:
1. flutter pub get
2. flutter run -d chrome   # web
3. flutter run -d <device> # Android/iOS

iOS note: add API key initialization in AppDelegate (GMSServices.provideAPIKey and GMSPlacesClient.provideAPIKey)

Security note: Autocomplete and details calls are client-side; consider proxying or restricting API key for production.

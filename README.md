## Feature Updates on the `Maps-Search-v3`:
- No auto-zoom on search/tap (keeps current zoom)
- Safe location detection (timeouts and permission checks)
- Stylized flat blue marker at assets/marker.png
- Works on Web / Android / iOS
- API key inserted (you provided it)

## How to run:
- `flutter pub get`

- `flutter run -d chrome`  (for web-based)

- `flutter run -d <device>` (for Android/iOS-based)

iOS note: add API key initialization in AppDelegate (GMSServices.provideAPIKey and GMSPlacesClient.provideAPIKey)

Security note: Autocomplete and details calls are client-side; consider proxying or restricting API key for production.

Reference(s):

[Google-AI Tech Updates](https://blog.google/technology/ai/google-ai-updates-november-2025/)

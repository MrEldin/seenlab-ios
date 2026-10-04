# Seenlab for iOS

The ASO, SEO and AIO reports of the Seenlab web app (seenlab.io), read-only, on the iPhone.
SwiftUI, iOS 18+. Architecture follows HydrateTap: `Network/`, `Extensions/`, `Modules/<Feature>/{Model,Store,View}`.

- **Strings and knowledge bases** come from the web client. After changing them there, run
  `node scripts/export-ios.mjs` in `seenlab-client`; it rewrites `seenlab/Resources/Locales` and `seenlab/Resources/KB`.
- **API**: `https://api.seenlab.io`. The JWT lives 24 h and is refreshed (GET `auth/refresh`) shortly before it
  runs out or after a 401; only a refused refresh signs the person out.
- **Debug only**: `-apiBase http://localhost:86` points the app at the local Docker API, `-debugToken <jwt>` signs in
  without typing, `-startTab aso|seo|aio|settings` opens a tab. Release builds always use the production API.
- **Privacy manifest**: `seenlab/PrivacyInfo.xcprivacy` (no tracking; email, name and user id for app functionality;
  UserDefaults reason CA92.1). The `seenlab` folder is a synchronized group, so it ships in the bundle automatically.
- Managing projects, keywords, prompts and the account stays on the web; the app links there.

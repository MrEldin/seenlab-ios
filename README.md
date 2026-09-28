# Seenlab for iOS

The ASO, SEO and AIO reports of the Seenlab web app (seenlab.io), read-only, on the iPhone.
SwiftUI, iOS 18+. Architecture follows HydrateTap: `Network/`, `Extensions/`, `Modules/<Feature>/{Model,Store,View}`.

- **Strings and knowledge bases** come from the web client. After changing them there, run
  `node scripts/export-ios.mjs` in `seenlab-client`; it rewrites `seenlab/Resources/Locales` and `seenlab/Resources/KB`.
- **API**: `https://api.seenlab.io`. For the local Docker API, add the launch argument `-apiBase http://localhost:86`.
- **Debug only**: `-debugToken <jwt>` signs in without typing, `-startTab aso|seo|aio|settings` opens a tab.
- Managing projects, keywords, prompts and the account stays on the web; the app links there.

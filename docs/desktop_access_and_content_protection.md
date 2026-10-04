# Desktop/laptop access without handing the question bank to cloners

Written 2026-09-12 after repeated "make it for laptop" feedback mails.

## Where we stand today (honest)

- The AES key ships inside the app, split into 3 string constants in
  `lib/utils/crypto.dart`. The file's own comment says it: deterrence, not a vault.
- The OTA `data.zip` is a **public GitHub release**. Anyone can download the
  encrypted bank today; only the key is "hidden" in the APK.
- Dart AOT snapshots keep string literals readable. Tools like `strings`,
  `reFlutter` or `blutter` recover them in minutes.
- No login, no backend. Firebase is only Crashlytics + Analytics.

So the mobile app is **not** safer than a web app would be. A cloner who wants
the bank can already take it. The real question is how to make *bulk* copying
expensive, on every platform.

## Recommendation: Flutter Web + server-side questions + login

Same Flutter code, `flutter create --platforms=web .`, hosted on Firebase
Hosting. Change one thing: the browser never receives the whole JSON.

| Tier | Who | Gets |
|---|---|---|
| Guest | anyone at questionx.web.app | Browse subjects/years, 1 short test per day, sample questions |
| Logged in (Google sign-in, Firebase Auth, free) | students | Full tests, bookmarks, history synced |
| Mobile app | same login | Everything + offline + PDF export |

### Backend shape (cheapest that works)

- **Storage:** one Firestore doc per question (or per test paper). ~30k docs,
  free tier covers it.
- **Fetch:** a Cloud Function `startTest(exam, filters, length)` returns only
  that test's questions. No list-all endpoint. Answers/solutions come from a
  second call `submitTest` after the user submits.
- **Rate limit:** per-uid counter in Firestore; e.g. 20 tests/day for free
  accounts. Guests keyed by IP + App Check token.
- **App Check** (reCAPTCHA Enterprise on web, Play Integrity on Android) so
  plain `curl` against the function is rejected.
- **Keep PDF export mobile-only** for now. It is the one feature that emits
  clean, complete, copy-ready papers.

### Why this beats the alternatives

1. **Flutter desktop build (macOS/Windows/Linux):** same `.enc` asset, same
   key-in-binary weakness, plus installer/signing pain and no store on Windows.
   Zero protection gain. Only worth it as a stopgap if a backend is off the table.
2. **Canned reply "use an Android emulator":** costs nothing, loses the users
   who wrote in. They will use a competitor's site.
3. **Keep web off entirely:** protects nothing (see "where we stand") and keeps
   the daily feedback mails coming.

### What it does not stop

A logged-in user can still read questions one test at a time and copy them by
hand or with a scripted browser. Rate limiting makes 30k questions take months
and thousands of accounts. That is the ceiling for any content site; the moat
is the curation + diagrams + fixes pipeline, not secrecy.

## Rough effort

| Step | Size |
|---|---|
| Firestore import script from the existing JSON | 1 day |
| `startTest` / `submitTest` Cloud Functions + rate limit | 2 days |
| Firebase Auth (Google) in the Flutter app, web + mobile | 1 day |
| Web build, hide PDF export + OTA sync on web, hosting | 1 day |
| App Check on web + Android | half day |

Mobile keeps working offline from the bundled `.enc` as it does now; only the
web target switches to the server path.

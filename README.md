# Prayer Tracker (iOS)

Private project. SwiftUI app: pick any city, choose a calculation method and Asr rule yourself,
optionally enter your mosque's times, get local reminders, and mark each prayer On time / Late / Missed.
Unmarked prayers stay Unconfirmed.

Status: source only. NOT yet built or tested on a Mac or device. The workflow in
`.github/workflows/build.yml` compiles an unsigned simulator build on GitHub's macOS runner.
Installing on an iPhone needs Apple signing (see below).

Prayer times come automatically from the public Aladhan API (https://aladhan.com, https://api.aladhan.com/v1/calendar) for the chosen city, method and Asr rule. These are calculated prayer-start times, not mosque iqamah. Cached monthly; shows last-updated time; mosque times entered by hand override them. The API's terms of use were not fully reviewed - check before any public release.

## Notes
- The bundle id `com.example.prayertracker.app` is a placeholder; change it when signing.
- Reminders are local notifications on the phone, scheduled 7 days ahead and refreshed when the app opens.
- Data stays on the device (UserDefaults). No account, no server.

## Known limits (read before relying on this)
- Build status (CI run #10, simulator, unsigned): 10 of 10 offline unit tests, 3 of 3 live tests (Aladhan fetch for Coimbatore, MapKit city search, time zone lookup when MapKit has none) and an end-to-end UI test (typed city search, real result, method and Asr chosen by the test, Today shows times) passed. UI screenshots come from synthetic seeded data and are labeled as test data. Not verified: a real device, notification delivery, background behavior.
- Fetch-failure state: a run showed the error message too far down Today and only a generic setup notice at the top. The message now sits at the top of Today. See the latest CI run for its regression result.
- Not installable on an iPhone yet. Installing needs Apple signing (a paid Apple Developer membership, or a Mac with Xcode and a free Apple Account, which gives 7-day profiles).
- Reminders are local notifications scheduled 7 days ahead. They refresh only when the app is opened. No background refresh and no push.
- Times are calculated prayer starts from Aladhan for the chosen method and Asr rule. They are not mosque azaan or iqamah. Hand-entered mosque times override them.
- Aladhan: no written usage terms found on its credits page; a maintainer post cites a limit of about 12 requests per second per IP. No written permission or prohibition was found. Confirm with them before any published or commercial use.
- Marks and settings stay on the device. Unmarked prayers are Unconfirmed, never Missed.

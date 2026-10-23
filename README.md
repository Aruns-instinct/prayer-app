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
- Build status: the unsigned simulator build compiles on GitHub's macOS runner. There are no unit or UI tests yet. Runtime behavior (city search, Aladhan fetch, notifications, marks) is not verified on a device.
- Not installable on an iPhone yet. Installing needs Apple signing (a paid Apple Developer membership, or a Mac with Xcode and a free Apple Account, which gives 7-day profiles).
- Reminders are local notifications scheduled 7 days ahead. They refresh only when the app is opened. No background refresh and no push.
- Times are calculated prayer starts from Aladhan for the chosen method and Asr rule. They are not mosque azaan or iqamah. Hand-entered mosque times override them.
- Aladhan's terms of use for API usage were not found on its credits page. Review them before any release.
- Marks and settings stay on the device. Unmarked prayers are Unconfirmed, never Missed.

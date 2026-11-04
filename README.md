# Expense Tracker: offline, voice-first (Flutter, Android)

This is the "Expense Tracker.xlsx" sheet rebuilt as an Android app. Say *"I spent 40 rs on tea and 300 on a book and 210 on petrol"* and the app saves three separate rows. Everything stays on the phone in an on-device SQLite database. There is no account, backend or cloud.

| Sheet tab | In the app |
|---|---|
| **Expenses** (Date, Amount, Description, Category, Payment Method, Type) | **Expenses** tab: date-range chips (Today / This Week / This Month / This Year / All Time / Custom), plus filters for category, Need/Want and payment method. Search, tap to edit, swipe to delete (with undo) |
| **Dashboard** (week / month / year totals, highest category) | **Dashboard** tab: the same 4 scorecards, a category donut, a Need vs Want donut and a monthly bar chart |
| Export | **Settings → Export to Excel**: builds an `.xlsx` with `Expenses` + `Dashboard` sheets and opens the Android share sheet |
| Your existing data | **Settings → Import from Excel**: pick your current `Expense Tracker.xlsx` and its rows are imported |

## Install it on your phone (no Android Studio needed)

Every push to GitHub builds an APK through GitHub Actions (`.github/workflows/build-apk.yml`).

1. Open the repo on GitHub, go to **Releases**, and open the newest **"Expense Tracker build N"**. You can also use **Actions → Build Android APK → latest run → Artifacts**.
2. On your Android phone, download `ExpenseTracker-buildN.apk` and open it.
3. Allow **"Install unknown apps"** for your browser or Files app when Android asks.
4. Open **Expense Tracker**. On the first mic tap, allow **Microphone**.

## Run from source (USB debugging)

Requirements: Flutter 3.47+ and Android Studio (for the Android SDK).

```bash
flutter pub get
flutter test          # 9 voice-parser tests + 3 UI flow tests
```

On the phone, open Settings → About phone and tap **Build number** 7 times. Then go to Developer options and turn on **USB debugging**, and connect the phone over USB.

```bash
flutter devices       # your phone should be listed
flutter run           # debug build with hot reload
flutter build apk --release   # → build/app/outputs/flutter-apk/app-release.apk
```

## Lock-screen voice logging

1. Go to **Settings → Add "Log Expense" quick tile** (Android 13+ shows a one-tap system prompt). On older Android, swipe down twice, tap ✏️ Edit, and drag **Log Expense** into the active tiles.
2. With the phone locked, swipe down and tap **Log Expense**. A transparent overlay opens over the lock screen and starts listening. When you stop speaking it parses the sentence, saves the rows, vibrates twice, shows what it saved (with **Undo**) and closes itself after 4 seconds.
3. You can also long-press the app icon and choose **Log by voice**.

For **fully offline** speech, open the Google app → Settings → Voice → Offline speech recognition and download **English (India)**. Without that pack, Android's recogniser may need internet. The parsing itself is always offline.

## How the voice parser works

The parser is in `lib/features/voice/parser/expense_parser.dart`. It is pure Dart, rule-based, takes about 0 MB and runs in under a millisecond.

1. **Normalise:** `₹40`, `40rs`, `rs. 40`, `forty rupees`, `1,105`, `2k` all become plain numbers + `rs`.
2. **Split into clauses** on *and / also / then / plus / , ;*
3. **Stitch clauses** so each segment owns exactly one amount. For example, *"i also spent on the petrol"* + *"there i have spent 210 rs"* becomes Petrol ₹210.
4. **Classify** each segment:
   - **Description:** the meaningful words, with fillers removed ("Cab for parents from hotel to home").
   - **Category:** about 200 keywords, and the longest match wins ("table lamp" → Investment, "table" → Utilities).
   - **Type:** the category default (Misc/Entertainment → Want, the rest → Need), overridden by "it was a want/need".
   - **Payment:** cash / card / upi / gpay / phonepe / paytm, default **UPI**. A trailing "paid everything by cash" applies to all items.
   - **Date:** "yesterday" / "day before yesterday", default today.

Before anything is saved in the app, you see the parsed rows and can edit any of them. To teach it new words, add them to `categoryKeywords`.

## Project structure

```
lib/
  main.dart                         main() + quickVoiceMain() (lock-screen entrypoint)
  core/{theme,constants,utils,widgets}
  data/
    models/expense.dart             one sheet row
    db/app_database.dart            sqflite (expenses table)
    repositories/expense_providers.dart   Riverpod state, filters, dashboard stats
  features/
    voice/  parser/, speech_controller.dart, voice_capture_sheet.dart, quick_voice_app.dart
    dashboard/  dashboard_screen.dart, widgets/charts.dart (fl_chart)
    expenses/   expenses_screen.dart, expense_form_sheet.dart
    export/     excel_service.dart (export + import, `excel` package)
    settings/   settings_screen.dart
android/app/src/main/
  AndroidManifest.xml               RECORD_AUDIO, tile service, showWhenLocked activity
  kotlin/.../ExpenseTileService.kt  Quick Settings "Log Expense" tile
  kotlin/.../QuickVoiceActivity.kt  transparent overlay over the lock screen
  kotlin/.../MainActivity.kt        "add tile" prompt, voice-settings shortcut
```

Stack: Flutter · Riverpod · sqflite · speech_to_text · fl_chart · excel · share_plus · path_provider · file_picker.

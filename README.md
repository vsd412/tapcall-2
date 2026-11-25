# TapCall 2

Tap a familiar name or photo to start a WhatsApp video call on Android. A caregiver can add, change, or remove people through **Manage contacts**. Names, numbers, and optional photo thumbnails stay in the app's local storage. The interface follows the phone's language (English, Traditional Chinese, or Simplified Chinese) and text size.

## Open the editable project

Use the [main branch](https://github.com/vsd412/tapcall-2/tree/main) for the source. The [Android preview branch](https://github.com/vsd412/tapcall-2/tree/android-preview) contains the installer. In VS Code choose **Command Palette → Git: Clone**, paste `https://github.com/vsd412/tapcall-2.git`, choose a folder and click **Open**. Sign in to GitHub with an account that has access to this private repository.

| To change | Open | VS Code extension |
| --- | --- | --- |
| Phone screens and contact buttons | [lib/home.dart](lib/home.dart) | Flutter (includes Dart support) |
| Bluetooth connection and button messages | [lib/board.dart](lib/board.dart) | Flutter |
| ESP32 pins and button behavior | [firmware/src/main.cpp](firmware/src/main.cpp) | PlatformIO IDE |

Open the repository root to run Flutter. For PlatformIO, open the **firmware** folder in a second VS Code window. PlatformIO reads [platformio.ini](firmware/platformio.ini) there. Choose **Build** (check mark) to compile without hardware. Choose **Upload** (arrow) with the ESP32-S3-DevKitC-1 connected using a USB data cable.

## First test on Android

1. In Android Studio open **Device Manager**, create a virtual phone with an Android 14 (API 34) image, and press its play button.
2. In VS Code open the repository root. Run `flutter pub get` in its terminal, select the running emulator using **Flutter: Select Device**, then press **F5**.
3. Open **Manage contacts**, add two sample people, close settings and tap a contact. On an emulator without WhatsApp, expect a setup message and a usable contact list. Tap **Connect TapCall board** under **Manage contacts** to exercise Bluetooth permission and the missing-board path.
4. Run `flutter test` for simulated board presses, page changes, alternating taps, failed calls, and contact editing.

## Test the physical buttons

Power the board and enable Bluetooth on the phone. Open **Manage contacts → Connect TapCall board**, allow the Android permission prompt, then close settings. If there are multiple boards in range, choose the device identifier for yours. The three contact buttons select the first, second and third person on the displayed page. The previous and next buttons switch pages. Reconnect through settings after restarting the app or losing the connection.

For a hardware check, add four contacts with consent to test. Verify GPIO 6, 8 and 13 select the correct visible people, GPIO 19 advances to the fourth person, GPIO 14 goes back, and unused slots on the last page do nothing. Try two rapid presses, unplug the board, check that touch still works and reconnect. Verify real call outcomes on a signed-in WhatsApp phone.

The firmware also reports accept, end, SOS, volume and motion using the original board protocol. This Android version only acts on the three contact keys and two page keys while the contact screen is in the foreground. Use WhatsApp's on-screen controls to answer or hang up.

## Calling behavior

1. Install and sign in to WhatsApp or WhatsApp Business. Save the person's number in Android Contacts and let WhatsApp sync it. Add the same number in TapCall. Eight digits are interpreted as a Hong Kong local number. For other regions enter the full international number beginning with +.
2. When asked, allow contact lookup for one-tap video. TapCall searches for one WhatsApp video action with the exact international number and opens that action in its owning WhatsApp client. Contact access is optional.
3. WhatsApp's Android contact actions depend on its version and sync settings. If an action is absent or ambiguous, TapCall offers **Open chat**. The caller can then use WhatsApp's video button. WhatsApp controls the call screen and may ask for confirmation.

No accessibility service, screen scraping, coordinate taps, or background monitoring is used. TapCall 2 installs alongside the original app under its own Android application ID and has a separate contact list.

## Development

Use Flutter 3.35.4 or compatible (Dart 3.9+), Java 17 and an Android SDK. From the repository root:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

For smaller, locally installable test builds, run `flutter build apk --release --split-per-abi`. Pick the APK matching the phone's CPU under `build/app/outputs/flutter-apk/`. These builds use the local Android debug signing key. Configure a production signing key before distribution.

## Implementation

- `lib/contacts.dart` owns local contact records and phone-number normalization.
- `lib/home.dart`, `lib/contact_tile.dart`, and `lib/editor.dart` implement calling and caregiver editing. `lib/words.dart` contains interface translations.
- `lib/calling.dart` defines the provider interface and the WhatsApp bridge. Android resolves the native contact action in `android/app/src/main/kotlin/com/tapcall/two/MainActivity.kt`. Only Android WhatsApp is implemented. An iOS implementation or another calling client needs its own verified launch mechanism.
- `test/calling_test.dart` exercises contact persistence, rapid taps, permission denial and fallback behavior.

The WhatsApp video contact MIME type is an integration detail, not a guaranteed public API. Recheck after WhatsApp updates. The fallback uses [WhatsApp's documented click-to-chat link](https://faq.whatsapp.com/5913398998672934).

## Device verification

On a real Android phone, confirm that one tap reaches the intended person, that an unavailable shortcut offers the correct chat, and that a denied contacts permission still allows chat. Check large system text and TalkBack focus. An emulator can verify Android intent routing with a test receiver; only a signed-in WhatsApp installation and a consenting recipient can verify a real call.

## Dedicated calling phone

On the calling phone, open Android **Settings → Apps → Default apps → Home app** and choose **TapCall 2**. The exact menu name varies by manufacturer. The Home button or Home gesture now opens TapCall. A caregiver can restore the original launcher in the same setting. This is optional and is not kiosk lockdown.

A failure to launch leaves the caller in TapCall. After Android hands off to WhatsApp, WhatsApp owns ringing, connection, errors, and hang-up. If its activity closes back to TapCall, the contact buttons are ready again. If WhatsApp keeps its chat or error screen open, use Home. TapCall does not use a timer to interrupt a call.

To check a new WhatsApp or device version, try back-to-back calls to two consenting contacts, repeated taps on both buttons, a declined call, an unanswered call, loss of network during ringing, and hang-up from each end. Verify the recipient, the number of outgoing attempts, which screen remains, and that Home returns to the contact list.

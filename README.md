# TapCall 2

Tap a familiar name or photo to start a WhatsApp video call on Android. A caregiver can add, change, or remove people through **Manage contacts**. Names, numbers, and optional photo thumbnails stay in the app's local storage. The interface follows the phone's language (English, Traditional Chinese, or Simplified Chinese) and text size.

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

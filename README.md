# Utify

Utify is a YouTube-powered music player for Windows, Android, and the web. It brings search, playback, playlists, lyrics, and a cross-device listening session into one app. You can explore it in Guest mode without signing in; account features require an access code.

[Browse releases](https://github.com/RamiChaaben8/Online_Music_Player/releases) · [Request account access](mailto:rami.chaaben@iit.ens.tn)

## What it can do

- Search and play music from YouTube, with a queue, shuffle, repeat, and lyrics where available.
- Create playlists and save liked tracks. Guest libraries stay on the current device; signed-in libraries sync through Firestore.
- Continue a listening session on another signed-in device. Utify restores remote playback paused and lets you choose when to resume.
- Use local music files and download tracks in the Flutter desktop/mobile app.
- Use friends, presence, playlist collaboration, and listening parties in the Flutter app. The web client includes friends and profile views.
- Choose from multiple themes. The web client saves the selected theme in the browser.

The web and Flutter clients share the Firebase project and Firestore data model, but their features are not identical. Browser file-system and background-audio support is more limited than the desktop/mobile app.

## Try Utify

The simplest way to try the app is to download a build from [GitHub Releases](https://github.com/RamiChaaben8/Online_Music_Player/releases/latest) and choose **Continue as guest** on the sign-in screen. Guest playlists, liked tracks, and playback state are stored locally on that device and do not sync to other devices.

To use account features, request an access code by [contacting Rami](mailto:rami.chaaben@iit.ens.tn). Account creation requires a one-time code.

## Clients and stack

| Client | Main technologies | Notes |
| --- | --- | --- |
| Windows and Android | Flutter, Dart, Riverpod, just_audio, Hive | YouTube search/playback, local music, downloads, and account features |
| Web | React, Vite, Zustand, Firebase | YouTube IFrame playback, browser-local guest library, and Firebase-backed account features |
| Backend | Firebase Auth, Cloud Firestore, Cloud Functions | Shared account/library data; Functions query YouTube InnerTube for web search and related data |
| Lyrics | LRCLIB and YouTube captions | Timed lyrics when available, with plain lyrics as a fallback |

## Run locally

### Flutter app

Install the Flutter SDK (including Dart 3.5 or newer) and the platform tooling for Windows desktop or Android. From the repository root:

```sh
flutter pub get
flutter run
```

Build a release package locally with:

```sh
flutter build windows --release
flutter build apk --release
```

### Web app

Install Node.js and npm, then run:

```sh
cd Utify-web
npm install
npm run dev
```

Vite prints the local development URL (usually `http://localhost:5173`). The web client uses Firebase for sign-in and cloud-backed features. Web search and other deployed backend features require the project's Cloud Functions; the Vite config also provides development proxies for YouTube requests.

### Cloud Functions

The Functions package uses Node.js 20. To install its dependencies and start the Firebase emulators, run from the repository root:

```sh
cd Utify-web/functions
npm install
cd ../..
firebase emulators:start --only auth,firestore,functions
```

## Use your own Firebase project

The checked-in Firebase configuration points to the project's existing Firebase project. For your own deployment, create a Firebase project and register Android and web apps, then replace the project-specific configuration in:

- `android/app/google-services.json`
- `lib/firebase_options.dart`
- `Utify-web/src/firebase.js`

Enable Email/Password sign-in and, if desired, Google sign-in. Set up Firestore and deploy the repository's rules and Functions from the project root:

```sh
firebase login
firebase use <your-project-id>
firebase deploy --only firestore:rules,functions
```

Signup requires a one-time code document in `signupCodes/{CODE}` with `{ "enabled": true }`. Create and distribute codes only to people you intend to grant account access. The signup code is an app-level gate; it is not a substitute for securing Firebase Auth, Firestore rules, or backend services.

## Project layout

```text
lib/                    Flutter app, providers, screens, and services
android/                Android platform project
windows/                Windows desktop runner
Utify-web/src/          React web client
Utify-web/functions/    Firebase Cloud Functions
firestore.rules         Firestore access rules
.github/workflows/      Windows and Android release builds
```

## Configuration and security

Firebase client configuration and Firebase API keys are included in the source because client apps need them. They identify the Firebase project; protect data with Firebase Authentication, Firestore Security Rules, and appropriate API-key restrictions. The checked-in configuration belongs to the existing project, so replace it before deploying your own copy.

Never add service-account keys, private signing keystores, passwords, or other server credentials to the repository. Use GitHub Actions secrets for release signing; without signing secrets, the Android release workflow produces a debug-signed APK.

## Tests

The repository currently contains a placeholder Flutter widget smoke test, not a comprehensive automated test suite.

## License

There is no license file in this repository yet. Contact the author before redistributing or reusing the code beyond trying it locally.

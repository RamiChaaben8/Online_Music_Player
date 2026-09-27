# Utify

Utify is a music player for Windows, Android, and the web. It lets you search YouTube, play tracks, and keep playlists and liked songs. Signed-in users can sync their library and playback between devices.

You can try the app in **Guest mode** without an account. Guest playlists and playback are saved on that device. To create an account, you need a one-time access code. Email [rami.chaaben@iit.ens.tn](mailto:rami.chaaben@iit.ens.tn) to request one.

Download the Windows or Android app from [GitHub Releases](https://github.com/RamiChaaben8/Online_Music_Player/releases).

## Run the Flutter app

Install Flutter and the tools needed for your target platform. From the project folder, run:

```sh
flutter pub get
flutter run
```

To build the desktop or Android version:

```sh
flutter build windows --release
flutter build apk --release
```

## Run the web app

Install Node.js, then run:

```sh
cd Utify-web
npm install
npm run dev
```

Vite will print the local address to open in your browser. Sign-in, cloud playlists, and web search need a Firebase project with the app's Cloud Functions deployed.

## Use your own Firebase project

The Firebase configuration in this repository belongs to the existing Utify project. To run your own backend, create a Firebase project, register Android and web apps, and replace these files with your configuration:

- `android/app/google-services.json`
- `lib/firebase_options.dart`
- `Utify-web/src/firebase.js`

Enable Email/Password sign-in (and Google sign-in if you want it), set up Firestore, then deploy the rules and Functions:

```sh
firebase login
firebase use <your-project-id>
firebase deploy --only firestore:rules,functions
```

Sign-up codes are stored in Firestore as `signupCodes/{CODE}` documents with `{ "enabled": true }`. Create a code for each person you want to invite.

## Tech used

- Flutter and Riverpod for Windows and Android
- React, Vite, and Zustand for the web app
- Firebase Authentication, Firestore, and Cloud Functions
- YouTube for music search and playback; LRCLIB and YouTube captions for lyrics

Firebase client config is included in the source. Do not add service-account files, signing keys, passwords, or other private credentials to the repository.

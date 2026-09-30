# Utify Web

A full-featured web version of the Utify music app — stream audio from YouTube, manage playlists, and sync playback across devices. Built with React + Firebase, deployed on Firebase Hosting.

**Same Firebase project as the Flutter desktop/Android app** (`ytspotify-aa97c`), sharing the same Firestore database, auth, and playlists.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | React 18 + Vite |
| Styling | Tailwind CSS + CSS variables (10 themes) |
| State | Zustand |
| Routing | React Router v6 |
| Backend | Firebase (Auth, Firestore, Hosting, Functions) |
| Audio | YouTube IFrame API |
| Search | Firebase Cloud Functions → InnerTube (no API key) |
| Lyrics | LRCLIB (free, no key) |

---

## Local Development

### 1. Prerequisites

- Node.js 18+ and npm
- Firebase CLI: `npm install -g firebase-tools`

### 2. Install dependencies

```bash
# Web app
cd Utify-web
npm install

# Cloud Functions
cd functions
npm install
cd ..
```

### 3. Run dev server

```bash
cd Utify-web
npm run dev
```

Open [http://localhost:5173](http://localhost:5173)

> **Note:** Search and trending will return mock data in dev mode because Cloud Functions are not running locally. To test Cloud Functions locally, run `firebase emulators:start` in the repo root.

### 4. Run Firebase Emulators (optional, for full local testing)

```bash
# From the repo root (testf/)
firebase emulators:start --only auth,firestore,functions
```

Then in `Utify-web/src/firebase.js`, temporarily connect to emulators:

```js
import { connectFirestoreEmulator } from 'firebase/firestore'
import { connectAuthEmulator } from 'firebase/auth'
import { connectFunctionsEmulator } from 'firebase/functions'

connectAuthEmulator(auth, 'http://localhost:9099')
connectFirestoreEmulator(db, 'localhost', 8080)
connectFunctionsEmulator(functions, 'localhost', 5001)
```

---

## Firebase Setup

The project uses the existing Firebase project **ytspotify-aa97c**.

### Enable Web Auth in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com) → project `ytspotify-aa97c`
2. Authentication → Sign-in method → enable:
   - **Email/Password** ✓ (probably already on)
   - **Google** ✓ (already on)
3. In Google sign-in settings, add `localhost` and your deployed domain to **Authorized domains**

### Enable Firebase Hosting

If hosting hasn't been initialized for the web target yet:

```bash
firebase target:apply hosting utify-web ytspotify-aa97c
```

Or simply deploy — Firebase will create the hosting site automatically.

---

## Build & Deploy

### Build the web app

```bash
cd Utify-web
npm run build
# Output goes to Utify-web/dist/
```

### Deploy everything (hosting + functions + firestore rules)

```bash
# From the repo root (testf/)
firebase login              # first time only
firebase deploy
```

This deploys:
- `hosting` → `Utify-web/dist/` to Firebase Hosting
- `functions` → `Utify-web/functions/` Cloud Functions to `us-central1`
- `firestore:rules` → `firestore.rules`

### Deploy only the web app (no functions)

```bash
firebase deploy --only hosting
```

### Deploy only functions

```bash
firebase deploy --only functions
```

### Deploy only Firestore rules

```bash
firebase deploy --only firestore:rules
```

---

## Project Structure

```
Utify-web/
├── functions/              # Firebase Cloud Functions (InnerTube search)
│   ├── index.js            # searchYouTube + getTrendingMusic
│   └── package.json
├── src/
│   ├── firebase.js         # Firebase app init
│   ├── index.css           # Tailwind + all 10 theme CSS variables
│   ├── main.jsx            # App entry, routing
│   ├── stores/
│   │   ├── authStore.js    # Firebase Auth state
│   │   ├── playerStore.js  # Playback state (queue, position, panels)
│   │   ├── libraryStore.js # Playlists + liked songs (Firestore live)
│   │   └── themeStore.js   # Theme switching (persisted to localStorage)
│   ├── services/
│   │   ├── firestoreService.js   # All Firestore reads/writes
│   │   ├── youtubeService.js     # Calls Cloud Functions
│   │   └── lyricsService.js      # LRCLIB API
│   ├── hooks/
│   │   ├── useYouTubePlayer.js  # IFrame API driver
│   │   └── useSyncSession.js    # Cross-device sync
│   ├── components/
│   │   ├── layout/
│   │   │   ├── AppShell.jsx    # 3-column layout
│   │   │   ├── TopBar.jsx      # Search, nav, profile menu
│   │   │   └── Sidebar.jsx     # Playlists, liked songs
│   │   ├── player/
│   │   │   ├── PlayerBar.jsx   # Bottom 80px controls
│   │   │   ├── NowPlayingPanel.jsx
│   │   │   ├── QueuePanel.jsx
│   │   │   └── LyricsPanel.jsx
│   │   └── sync/
│   │       ├── RemotePlaybackBanner.jsx
│   │       └── OfflineIndicator.jsx
│   └── pages/
│       ├── auth/
│       │   ├── AuthGate.jsx
│       │   ├── LoginPage.jsx
│       │   ├── SignupPage.jsx
│       │   └── ForgotPasswordPage.jsx
│       ├── HomeView.jsx
│       ├── SearchView.jsx
│       ├── PlaylistView.jsx
│       ├── LikedSongsView.jsx
│       ├── FriendsView.jsx
│       ├── FriendProfileView.jsx
│       └── SettingsPage.jsx
├── index.html
├── vite.config.js
└── package.json
```

---

## Features

| Feature | Notes |
|---|---|
| Email/Password auth | Full sign-up, login, forgot password |
| Google Sign-In | Popup flow |
| 3 themes | Green, Red, Verdant Night — persisted |
| YouTube search | Via InnerTube Cloud Function — unlimited, no API key |
| Trending music | InnerTube music charts |
| Audio playback | YouTube IFrame API — play, pause, seek, volume, mute |
| Shuffle & Repeat | Off / Repeat All / Repeat One |
| Queue management | Add, remove, reorder, clear |
| Lyrics | Synced (auto-scroll, click to seek) + plain text via LRCLIB |
| Playlists | Create, rename, delete, reorder songs |
| Liked songs | Like/unlike any track, shown in sidebar |
| Collaborate | Invite other users to edit a playlist |
| Cross-device sync | Playback state synced every 10s; restore on another device |
| Remote playback banner | "Playing on [device] — Continue here?" |
| Offline indicator | Orange banner when network is lost |
| Friends | Send/accept requests, view profiles, see listening status |
| Listen Party | Real-time synchronized playback with friends |

---

## Cross-Device Sync

Mirrors the Flutter app behaviour exactly:

- Firestore `users/{uid}/state/playback` — position written every 10s while playing, immediately on pause/seek/track change
- Firestore `users/{uid}/devices/{deviceId}` — each browser tab registers as a device
- Only the **active device** controls playback
- Opening on a second device shows a banner: **"Playing on Chrome (Web) — Continue here?"**
- Clicking it claims the active device role

---

## Limitations (web vs desktop)

| Feature | Desktop Flutter | Web |
|---|---|---|
| Download songs | ✓ (saves MP3) | ✗ — not possible in browser |
| Local music scan | ✓ (file system) | ✗ — browser sandbox |
| Background audio | ✓ (OS media session) | Limited — tab must be active or use PWA |
| Custom window chrome | ✓ (title bar) | Standard browser frame |

---

## Environment & Secrets

The Firebase config in `src/firebase.js` contains the web API key. This key is **safe to be public** for web apps — it identifies your Firebase project but is protected by Firestore security rules and Firebase Auth. Never commit server-side secrets (service account keys).

For CI/CD, the `firebase.json` and `Utify-web/` directory are all you need. The Firebase API key is not a secret.

## Admin dashboard

The standalone `/admin` page is available only to accounts with the Firebase Authentication custom claim `admin: true` (or `role: "admin"`). On the Spark plan, it reads the existing `publicProfiles` collection directly. Create, edit, and delete controls manage Utify profile documents and username reservations; they do not create or delete Firebase Authentication accounts. The Firestore rules must be deployed to allow only admins to perform those profile-management writes.

This is an Utify profile directory, not a complete Firebase Authentication user export. Accounts without a `publicProfiles/{uid}` document do not appear, and Firebase-only account details such as verified email and last sign-in time are unavailable. Firestore's free quota includes 50,000 reads and 20,000 writes per day for the free database.

Grant the admin claim only from a trusted Firebase Admin SDK environment. For example, using the Admin SDK in a secured script:

```js
await getAuth().setCustomUserClaims('<user-uid>', { admin: true })
```

The account must sign in again (or refresh its ID token) for the new claim to appear. No Cloud Functions deployment is required for this dashboard. After deploying the updated rules, the profile CRUD controls work on the Spark plan:

```sh
firebase deploy --only firestore:rules --project ytspotify-aa97c
```

### One-time signup serial codes

Signup checks a code in `signupCodes/{CODE}` before creating an account, then atomically deletes that code after account creation. To issue a code manually, create a Firestore document in `signupCodes`, use a unique uppercase random code (preferably 16 or more characters) as its document ID, and set `{ "enabled": true }`. A code can be redeemed once. The same Firestore rules deployment above is required.

This is a client-side signup gate. Firebase Auth does not validate the code itself, so it cannot prevent a determined person from creating an Auth account by calling Firebase directly. Do not treat it as a secure admission boundary without a trusted backend.

// src/firebase.js
// Firebase initialization for Utify web app
// Project: ytspotify-aa97c

import { initializeApp } from 'firebase/app'
import { getAuth, GoogleAuthProvider } from 'firebase/auth'
import { initializeFirestore, persistentLocalCache, persistentMultipleTabManager } from 'firebase/firestore'
import { getFunctions } from 'firebase/functions'

const firebaseConfig = {
  apiKey: 'AIzaSyDv9l7X2dHeQTIjCWUVWA_cWTI5wy3QoJc',
  authDomain: 'ytspotify-aa97c.firebaseapp.com',
  projectId: 'ytspotify-aa97c',
  storageBucket: 'ytspotify-aa97c.firebasestorage.app',
  messagingSenderId: '210995583890',
  appId: '1:210995583890:web:24ac64e698e2637ba57f4b',
  measurementId: 'G-46MLBNTJX2',
}

const app = initializeApp(firebaseConfig)

export const auth = getAuth(app)

// Use persistent local cache (multi-tab) — mirrors Flutter's persistenceEnabled: true
// This replaces the deprecated enableIndexedDbPersistence() call.
export const db = initializeFirestore(app, {
  localCache: persistentLocalCache({
    tabManager: persistentMultipleTabManager(),
  }),
})

export const functions = getFunctions(app)
export const googleProvider = new GoogleAuthProvider()

export default app
